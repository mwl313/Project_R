--[[
파일명: net_client.lua
모듈명: NetClient

역할:
- WebSocket 연결/송수신(텍스트 프레임)
- 서버 메시지(JSON)을 큐로 쌓고, update에서 poll 할 수 있게 제공

외부에서 사용 가능한 함수:
- NetClient.new()
- NetClient:connect(wsUrl)
- NetClient:disconnect()
- NetClient:isConnected()
- NetClient:sendJson(tableValue)
- NetClient:update(dt)
- NetClient:poll()

주의:
- LuaSocket 필요(require('socket'))
- wss(실서버) 사용 시 LuaSec(ssl) 필요(require('ssl'))
- 이 구현은 "텍스트 프레임 중심"의 최소 구현이다. (바이너리/확장/고급 제어는 후속)
]]
local NetClient = {}
NetClient.__index = NetClient

local function _tryRequire(moduleName)
  local ok, mod = pcall(require, moduleName)
  if ok then
    return mod
  end
  return nil
end

local function _encodeJson(tableValue)
  local function encode(value)
    local t = type(value)
    if t == "nil" then
      return "null"
    end
    if t == "number" then
      return tostring(value)
    end
    if t == "boolean" then
      return value and "true" or "false"
    end
    if t == "string" then
      local s = value
      s = s:gsub("\\", "\\\\")
      s = s:gsub("\"", "\\\"")
      s = s:gsub("\n", "\\n")
      s = s:gsub("\r", "\\r")
      s = s:gsub("\t", "\\t")
      return "\"" .. s .. "\""
    end
    if t == "table" then
      local isArray = true
      local maxIndex = 0
      for k, _ in pairs(value) do
        if type(k) ~= "number" then
          isArray = false
          break
        end
        if k > maxIndex then
          maxIndex = k
        end
      end

      if isArray then
        local items = {}
        for i = 1, maxIndex do
          table.insert(items, encode(value[i]))
        end
        return "[" .. table.concat(items, ",") .. "]"
      end

      local items = {}
      for k, v in pairs(value) do
        table.insert(items, encode(tostring(k)) .. ":" .. encode(v))
      end
      return "{" .. table.concat(items, ",") .. "}"
    end

    return "null"
  end

  return encode(tableValue)
end

local function _parseWsUrl(url)
  local protocol, host, path = string.match(url, "^(wss?)://([^/]+)(/.*)$")
  if not protocol then
    protocol, host = string.match(url, "^(wss?)://([^/]+)$")
    path = "/"
  end

  if not protocol or not host then
    return nil
  end

  local hostname, port = string.match(host, "^([^:]+):(%d+)$")
  if hostname then
    port = tonumber(port)
  else
    hostname = host
    port = (protocol == "wss") and 443 or 80
  end

  return {
    protocol = protocol,
    host = hostname,
    port = port,
    path = path,
  }
end

local function _base64Encode(data)
  local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  return ((data:gsub(".", function(x)
    local r, bits = "", x:byte()
    for i = 8, 1, -1 do
      r = r .. (bits % 2^i - bits % 2^(i - 1) > 0 and "1" or "0")
    end
    return r
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(x)
    if #x < 6 then
      return ""
    end
    local c = 0
    for i = 1, 6 do
      c = c + (x:sub(i, i) == "1" and 2^(6 - i) or 0)
    end
    return b:sub(c + 1, c + 1)
  end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

local function _sha1Raw(_)
  -- 최소 구현: Sec-WebSocket-Key 검증을 서버가 강제하지 않는 환경에서도 통과하도록
  -- key는 랜덤 base64로만 생성하고, 서버의 accept 검증은 생략한다.
  -- (Cloudflare Worker/DO는 일반적으로 handshake를 통과시키며, 우리는 최소 구현을 우선한다.)
  return ""
end

local function _makeRandomKey()
  local bytes = {}
  for i = 1, 16 do
    bytes[i] = string.char(love.math.random(0, 255))
  end
  return _base64Encode(table.concat(bytes))
end

local function _maskPayload(payload, maskBytes)
  local out = {}
  for i = 1, #payload do
    local m = maskBytes[((i - 1) % 4) + 1]
    out[i] = string.char(bit.bxor(payload:byte(i), m))
  end
  return table.concat(out)
end

local function _packFrameText(payload)
  -- Client -> Server 프레임은 반드시 마스킹(MASK=1)
  local finOpcode = 0x81 -- FIN=1, opcode=1(text)
  local len = #payload

  local maskKey = { love.math.random(0, 255), love.math.random(0, 255), love.math.random(0, 255), love.math.random(0, 255) }
  local masked = _maskPayload(payload, maskKey)

  local header = { string.char(finOpcode) }

  if len <= 125 then
    table.insert(header, string.char(0x80 + len))
  elseif len <= 65535 then
    table.insert(header, string.char(0x80 + 126))
    table.insert(header, string.char(math.floor(len / 256) % 256))
    table.insert(header, string.char(len % 256))
  else
    -- 이 프로젝트 범위에서는 긴 텍스트는 안 보냄
    table.insert(header, string.char(0x80 + 127))
    for _i = 1, 8 do
      table.insert(header, "\0")
    end
  end

  table.insert(header, string.char(maskKey[1], maskKey[2], maskKey[3], maskKey[4]))
  return table.concat(header) .. masked
end

local function _readBytes(sock, n)
  local data, err, partial = sock:receive(n)
  if data then
    return data
  end
  if partial and #partial > 0 then
    return partial, err
  end
  return nil, err
end

local function _unpackFrame(sock)
  local b1, err1 = _readBytes(sock, 1)
  if not b1 then
    return nil, err1
  end

  local b2, err2 = _readBytes(sock, 1)
  if not b2 then
    return nil, err2
  end

  local byte1 = b1:byte(1)
  local byte2 = b2:byte(1)

  local opcode = bit.band(byte1, 0x0F)
  local isMasked = bit.band(byte2, 0x80) ~= 0
  local len = bit.band(byte2, 0x7F)

  if len == 126 then
    local ext = _readBytes(sock, 2)
    if not ext or #ext < 2 then
      return nil, "short_read"
    end
    len = ext:byte(1) * 256 + ext:byte(2)
  elseif len == 127 then
    -- 이 프로젝트 범위에서는 매우 긴 프레임은 처리 생략(안전상)
    local ext = _readBytes(sock, 8)
    if not ext or #ext < 8 then
      return nil, "short_read"
    end
    return nil, "frame_too_large"
  end

  local mask = nil
  if isMasked then
    local m = _readBytes(sock, 4)
    if not m or #m < 4 then
      return nil, "short_read"
    end
    mask = { m:byte(1), m:byte(2), m:byte(3), m:byte(4) }
  end

  local payload = ""
  if len > 0 then
    local p = _readBytes(sock, len)
    if not p or #p < len then
      return nil, "short_read"
    end
    payload = p
  end

  if isMasked and mask then
    payload = _maskPayload(payload, mask)
  end

  return { opcode = opcode, payload = payload }, nil
end

function NetClient.new()
  local self = setmetatable({}, NetClient)

  self._socket = nil
  self._isConnected = false
  self._error = ""

  self._recvQueue = {}
  self._bufferedEvents = {}

  return self
end

function NetClient:isConnected()
  return self._isConnected
end

function NetClient:getLastError()
  return self._error or ""
end

function NetClient:connect(wsUrl)
  self:disconnect()

  local socket = _tryRequire("socket")
  if not socket then
    self._error = "LuaSocket이 필요합니다(require('socket') 실패)."
    return false
  end

  local ssl = _tryRequire("ssl")

  local info = _parseWsUrl(wsUrl)
  if not info then
    self._error = "잘못된 WS URL입니다."
    return false
  end

  local tcp = assert(socket.tcp())
  tcp:settimeout(8)

  local ok, err = tcp:connect(info.host, info.port)
  if not ok then
    self._error = "connect 실패: " .. tostring(err)
    return false
  end

  local conn = tcp
  if info.protocol == "wss" then
    if not ssl then
      self._error = "WSS 연결을 위해 LuaSec(ssl)이 필요합니다."
      tcp:close()
      return false
    end

    local wrapped, werr = ssl.wrap(tcp, {
      mode = "client",
      protocol = "tlsv1_2",
      verify = "none",
      options = "all",
      server = info.host,
    })
    if not wrapped then
      self._error = "ssl.wrap 실패: " .. tostring(werr)
      tcp:close()
      return false
    end

    local hsOk, hsErr = wrapped:dohandshake()
    if not hsOk then
      self._error = "TLS handshake 실패: " .. tostring(hsErr)
      wrapped:close()
      return false
    end

    conn = wrapped
  end

  -- Handshake
  local key = _makeRandomKey()
  local requestText =
    "GET " .. info.path .. " HTTP/1.1\r\n" ..
    "Host: " .. info.host .. "\r\n" ..
    "Upgrade: websocket\r\n" ..
    "Connection: Upgrade\r\n" ..
    "Sec-WebSocket-Key: " .. key .. "\r\n" ..
    "Sec-WebSocket-Version: 13\r\n" ..
    "\r\n"

  conn:send(requestText)

  -- Read HTTP response header
  local header = ""
  while true do
    local line, herr, partial = conn:receive("*l")
    if line then
      if line == "" then
        break
      end
      header = header .. line .. "\n"
    elseif partial and partial ~= "" then
      header = header .. partial .. "\n"
    end

    if herr and herr ~= "timeout" then
      break
    end
  end

  if not string.find(header, "101") then
    self._error = "WebSocket handshake 실패(101 아님)."
    conn:close()
    return false
  end

  conn:settimeout(0)
  self._socket = conn
  self._isConnected = true
  self._error = ""

  table.insert(self._bufferedEvents, { type = "net.connected", payload = {} })

  return true
end

function NetClient:disconnect()
  if self._socket then
    pcall(function()
      self._socket:close()
    end)
  end

  self._socket = nil
  self._isConnected = false
  self._error = ""
  self._recvQueue = {}
  self._bufferedEvents = {}
end

function NetClient:sendJson(tableValue)
  if not self._isConnected or not self._socket then
    return false
  end

  local text = _encodeJson(tableValue)
  local frame = _packFrameText(text)

  local ok = pcall(function()
    self._socket:send(frame)
  end)

  return ok
end

function NetClient:update(_dt)
  if not self._isConnected or not self._socket then
    return
  end

  -- Non-blocking: read available frames
  while true do
    local frame, err = _unpackFrame(self._socket)
    if not frame then
      if err == "timeout" or err == "wantread" then
        return
      end
      if err == "closed" then
        self._isConnected = false
        table.insert(self._bufferedEvents, { type = "net.disconnected", payload = {} })
        return
      end
      -- no data
      return
    end

    if frame.opcode == 0x1 then
      -- text
      table.insert(self._bufferedEvents, { type = "net.message", payload = { text = frame.payload } })
    elseif frame.opcode == 0x8 then
      -- close
      self._isConnected = false
      table.insert(self._bufferedEvents, { type = "net.disconnected", payload = {} })
      return
    elseif frame.opcode == 0x9 then
      -- ping -> pong (최소 처리)
      -- pong은 opcode 0xA
      -- 여기선 생략(서버가 핑을 강하게 요구하면 후속 강화)
    end
  end
end

function NetClient:poll()
  if #self._bufferedEvents == 0 then
    return nil
  end

  return table.remove(self._bufferedEvents, 1)
end

return NetClient
