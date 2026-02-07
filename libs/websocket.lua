--[[
파일명: libs/websocket.lua
모듈명: WebSocket

역할:
- LÖVE(LuaJIT) 환경에서 동작하는 경량 WebSocket 클라이언트
- net/ws_client.lua가 기대하는 API 제공:
  - local ws = WebSocket.connect(url)
  - ws:on("open"/"message"/"close"/"error", fn)
  - ws:send(text), ws:close(), ws:update(dt)

주의:
- ws:// (로컬) 용도로 우선 지원
- wss:// 는 LuaSec(ssl) + CA 설정이 필요하므로, 추후 필요 시 확장
- LuaSocket(require("socket")) 필요
]]

local socket = require("socket")

local WebSocket = {}

local EVENT_OPEN = "open"
local EVENT_MESSAGE = "message"
local EVENT_CLOSE = "close"
local EVENT_ERROR = "error"

local function _isString(v)
  return type(v) == "string"
end

local function _startsWith(s, prefix)
  return string.sub(s, 1, #prefix) == prefix
end

local function _trim(s)
  if not s then
    return ""
  end
  return (string.match(s, "^%s*(.-)%s*$") or "")
end

local function _parseUrl(url)
  -- ws://host:port/path?query
  if not _isString(url) then
    return nil
  end

  local scheme, rest = string.match(url, "^(%a[%w+.-]*)://(.+)$")
  if not scheme or not rest then
    return nil
  end

  local hostPort, path = string.match(rest, "^([^/]+)(/.*)$")
  if not hostPort then
    hostPort = rest
    path = "/"
  end

  local host, portStr = string.match(hostPort, "^([^:]+):(%d+)$")
  if not host then
    host = hostPort
    portStr = nil
  end

  local port = tonumber(portStr)
  if scheme == "ws" then
    port = port or 80
  elseif scheme == "wss" then
    port = port or 443
  else
    return nil
  end

  return {
    scheme = scheme,
    host = host,
    port = port,
    path = path,
  }
end

local function _randomKeyBytes(n)
  local t = {}
  for i = 1, n do
    t[i] = string.char(math.random(0, 255))
  end
  return table.concat(t)
end

local function _base64Encode(data)
  local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local bytes = { string.byte(data, 1, #data) }
  local pad = (3 - (#bytes % 3)) % 3

  for _ = 1, pad do
    table.insert(bytes, 0)
  end

  local out = {}
  for i = 1, #bytes, 3 do
    local n = bytes[i] * 65536 + bytes[i + 1] * 256 + bytes[i + 2]
    local c1 = math.floor(n / 262144) % 64
    local c2 = math.floor(n / 4096) % 64
    local c3 = math.floor(n / 64) % 64
    local c4 = n % 64

    table.insert(out, string.sub(b, c1 + 1, c1 + 1))
    table.insert(out, string.sub(b, c2 + 1, c2 + 1))
    table.insert(out, string.sub(b, c3 + 1, c3 + 1))
    table.insert(out, string.sub(b, c4 + 1, c4 + 1))
  end

  if pad > 0 then
    out[#out] = "="
    if pad == 2 then
      out[#out - 1] = "="
    end
  end

  return table.concat(out)
end

local function _sha1(msg)
  -- SHA1 (pure Lua) - LuaJIT bit library expected
  local bit = require("bit")
  local band = bit.band
  local bor = bit.bor
  local bxor = bit.bxor
  local bnot = bit.bnot
  local lshift = bit.lshift
  local rshift = bit.rshift
  local rol = bit.rol

  local function u32(n)
    return band(n, 0xffffffff)
  end

  local ml = #msg * 8

  msg = msg .. string.char(0x80)
  local padLen = (56 - (#msg % 64)) % 64
  msg = msg .. string.rep(string.char(0), padLen)

  local function _u32ToBytes(n)
    return string.char(
      band(rshift(n, 24), 0xff),
      band(rshift(n, 16), 0xff),
      band(rshift(n, 8), 0xff),
      band(n, 0xff)
    )
  end

  local hi = math.floor(ml / 0x100000000)
  local lo = ml % 0x100000000
  msg = msg .. _u32ToBytes(hi) .. _u32ToBytes(lo)

  local h0 = 0x67452301
  local h1 = 0xEFCDAB89
  local h2 = 0x98BADCFE
  local h3 = 0x10325476
  local h4 = 0xC3D2E1F0

  for chunkStart = 1, #msg, 64 do
    local w = {}

    for i = 0, 15 do
      local s = chunkStart + i * 4
      local b1, b2, b3, b4 = string.byte(msg, s, s + 3)
      w[i] = u32(b1 * 16777216 + b2 * 65536 + b3 * 256 + b4)
    end

    for i = 16, 79 do
      w[i] = rol(bxor(bxor(bxor(w[i - 3], w[i - 8]), w[i - 14]), w[i - 16]), 1)
    end

    local a, b, c, d, e = h0, h1, h2, h3, h4

    for i = 0, 79 do
      local f, k
      if i <= 19 then
        f = bor(band(b, c), band(bnot(b), d))
        k = 0x5A827999
      elseif i <= 39 then
        f = bxor(b, bxor(c, d))
        k = 0x6ED9EBA1
      elseif i <= 59 then
        f = bor(bor(band(b, c), band(b, d)), band(c, d))
        k = 0x8F1BBCDC
      else
        f = bxor(b, bxor(c, d))
        k = 0xCA62C1D6
      end

      local temp = u32(rol(a, 5) + f + e + k + w[i])
      e = d
      d = c
      c = u32(rol(b, 30))
      b = a
      a = temp
    end

    h0 = u32(h0 + a)
    h1 = u32(h1 + b)
    h2 = u32(h2 + c)
    h3 = u32(h3 + d)
    h4 = u32(h4 + e)
  end

  local function _hex(n)
    return string.format("%08x", n)
  end

  return _hex(h0) .. _hex(h1) .. _hex(h2) .. _hex(h3) .. _hex(h4)
end

local function _sha1Binary(msg)
  local hex = _sha1(msg)
  local out = {}
  for i = 1, #hex, 2 do
    local byte = tonumber(string.sub(hex, i, i + 1), 16)
    table.insert(out, string.char(byte))
  end
  return table.concat(out)
end

local function _buildAcceptKey(secWebSocketKey)
  local GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
  local bin = _sha1Binary(secWebSocketKey .. GUID)
  return _base64Encode(bin)
end

local function _packFrame(opcode, payloadText)
  -- client->server must MASK
  local bit = require("bit")
  local band = bit.band
  local bor = bit.bor
  local bxor = bit.bxor
  local rshift = bit.rshift

  local payload = payloadText or ""
  local payloadLen = #payload

  local finOpcode = bor(0x80, band(opcode, 0x0f)) -- FIN=1
  local maskBit = 0x80

  local header = { string.char(finOpcode) }

  if payloadLen < 126 then
    table.insert(header, string.char(bor(maskBit, payloadLen)))
  elseif payloadLen < 65536 then
    table.insert(header, string.char(bor(maskBit, 126)))
    table.insert(header, string.char(band(rshift(payloadLen, 8), 0xff)))
    table.insert(header, string.char(band(payloadLen, 0xff)))
  else
    -- 64-bit length (we only support up to 2^32-1 here safely)
    table.insert(header, string.char(bor(maskBit, 127)))
    local hi = 0
    local lo = payloadLen
    table.insert(header, string.char(0))
    table.insert(header, string.char(0))
    table.insert(header, string.char(0))
    table.insert(header, string.char(0))
    table.insert(header, string.char(band(rshift(lo, 24), 0xff)))
    table.insert(header, string.char(band(rshift(lo, 16), 0xff)))
    table.insert(header, string.char(band(rshift(lo, 8), 0xff)))
    table.insert(header, string.char(band(lo, 0xff)))
  end

  local maskKey = _randomKeyBytes(4)
  table.insert(header, maskKey)

  local mk = { string.byte(maskKey, 1, 4) }
  local masked = {}
  for i = 1, payloadLen do
    local b = string.byte(payload, i)
    local m = mk[((i - 1) % 4) + 1]
    masked[i] = string.char(bxor(b, m))
  end

  return table.concat(header) .. table.concat(masked)
end

local function _readLine(sock)
  local line, err = sock:receive("*l")
  if not line then
    return nil, err
  end
  return line
end

local function _readHttpResponse(sock)
  local statusLine, err = _readLine(sock)
  if not statusLine then
    return nil, err
  end

  local headers = {}
  while true do
    local line, err2 = _readLine(sock)
    if not line then
      return nil, err2
    end
    if line == "" then
      break
    end

    local k, v = string.match(line, "^([^:]+)%s*:%s*(.*)$")
    if k and v then
      headers[string.lower(_trim(k))] = _trim(v)
    end
  end

  return {
    statusLine = statusLine,
    headers = headers,
  }
end

local function _parseFrame(buffer)
  -- returns: frameTable or nil if incomplete
  local bit = require("bit")
  local band = bit.band
  local bor = bit.bor
  local lshift = bit.lshift

  if #buffer < 2 then
    return nil, buffer
  end

  local b1 = string.byte(buffer, 1)
  local b2 = string.byte(buffer, 2)

  local fin = band(b1, 0x80) ~= 0
  local opcode = band(b1, 0x0f)
  local masked = band(b2, 0x80) ~= 0
  local len7 = band(b2, 0x7f)

  local idx = 3
  local payloadLen = nil

  if len7 < 126 then
    payloadLen = len7
  elseif len7 == 126 then
    if #buffer < idx + 1 then
      return nil, buffer
    end
    local b3 = string.byte(buffer, idx)
    local b4 = string.byte(buffer, idx + 1)
    payloadLen = b3 * 256 + b4
    idx = idx + 2
  else
    if #buffer < idx + 7 then
      return nil, buffer
    end
    -- ignore high 32 bits
    local b7 = string.byte(buffer, idx + 4)
    local b8 = string.byte(buffer, idx + 5)
    local b9 = string.byte(buffer, idx + 6)
    local b10 = string.byte(buffer, idx + 7)
    payloadLen = b7 * 16777216 + b8 * 65536 + b9 * 256 + b10
    idx = idx + 8
  end

  local maskKey = nil
  if masked then
    if #buffer < idx + 3 then
      return nil, buffer
    end
    maskKey = { string.byte(buffer, idx, idx + 3) }
    idx = idx + 4
  end

  if #buffer < idx + payloadLen - 1 then
    return nil, buffer
  end

  local payload = string.sub(buffer, idx, idx + payloadLen - 1)
  local rest = string.sub(buffer, idx + payloadLen)

  if masked and maskKey then
    local bit2 = require("bit")
    local bxor = bit2.bxor
    local out = {}
    for i = 1, #payload do
      local b = string.byte(payload, i)
      local m = maskKey[((i - 1) % 4) + 1]
      out[i] = string.char(bxor(b, m))
    end
    payload = table.concat(out)
  end

  return {
    fin = fin,
    opcode = opcode,
    payload = payload,
  }, rest
end

local Ws = {}
Ws.__index = Ws

function Ws:on(eventName, fn)
  if not self._handlers[eventName] then
    self._handlers[eventName] = {}
  end
  table.insert(self._handlers[eventName], fn)
  return self
end

function Ws:_emit(eventName, ...)
  local list = self._handlers[eventName]
  if not list then
    return
  end
  for _, fn in ipairs(list) do
    pcall(fn, ...)
  end
end

function Ws:send(text)
  if not self._sock or self._state ~= "open" then
    return false
  end
  local frame = _packFrame(0x1, tostring(text))
  self._sock:send(frame)
  return true
end

function Ws:close()
  if not self._sock then
    return
  end

  if self._state == "open" then
    local frame = _packFrame(0x8, "")
    pcall(function()
      self._sock:send(frame)
    end)
  end

  pcall(function()
    self._sock:close()
  end)

  self._sock = nil
  self._state = "closed"
  self:_emit(EVENT_CLOSE)
end

function Ws:update(_dt)
  if not self._sock then
    return
  end

  if self._state ~= "open" then
    return
  end

  while true do
    local chunk, err, partial = self._sock:receive(4096)
    local data = chunk or partial

    if data and #data > 0 then
      self._rxBuffer = self._rxBuffer .. data
      while true do
        local frame
        frame, self._rxBuffer = _parseFrame(self._rxBuffer)
        if not frame then
          break
        end

        if frame.opcode == 0x1 then
          self:_emit(EVENT_MESSAGE, frame.payload)
        elseif frame.opcode == 0x8 then
          self:close()
          return
        elseif frame.opcode == 0x9 then
          -- ping -> pong
          local pong = _packFrame(0xA, frame.payload or "")
          pcall(function()
            self._sock:send(pong)
          end)
        end
      end
    end

    if err == "timeout" then
      break
    end

    if err and err ~= "" then
      self._state = "error"
      self:_emit(EVENT_ERROR)
      self:close()
      break
    end
  end
end

function WebSocket.connect(url)
  local parsed = _parseUrl(url)
  if not parsed then
    local ws = setmetatable({
      _handlers = {},
      _sock = nil,
      _state = "error",
      _rxBuffer = "",
    }, Ws)
    ws:_emit(EVENT_ERROR)
    return ws
  end

  if parsed.scheme ~= "ws" then
    -- 현재 단계: ws 로컬 우선. (wss는 추후 확장)
    local ws = setmetatable({
      _handlers = {},
      _sock = nil,
      _state = "error",
      _rxBuffer = "",
    }, Ws)
    ws:_emit(EVENT_ERROR)
    return ws
  end

  local tcp = socket.tcp()
  tcp:settimeout(3)

  local ok, err = tcp:connect(parsed.host, parsed.port)
  if not ok then
    local ws = setmetatable({
      _handlers = {},
      _sock = nil,
      _state = "error",
      _rxBuffer = "",
    }, Ws)
    ws:_emit(EVENT_ERROR)
    return ws
  end

  tcp:settimeout(0) -- non-blocking

  local key = _base64Encode(_randomKeyBytes(16))

  local req = {}
  table.insert(req, "GET " .. parsed.path .. " HTTP/1.1")
  table.insert(req, "Host: " .. parsed.host .. ":" .. tostring(parsed.port))
  table.insert(req, "Upgrade: websocket")
  table.insert(req, "Connection: Upgrade")
  table.insert(req, "Sec-WebSocket-Key: " .. key)
  table.insert(req, "Sec-WebSocket-Version: 13")
  table.insert(req, "\r\n")

  tcp:settimeout(3)
  tcp:send(table.concat(req, "\r\n"))

  local resp, err2 = _readHttpResponse(tcp)
  if not resp then
    tcp:close()
    local ws = setmetatable({
      _handlers = {},
      _sock = nil,
      _state = "error",
      _rxBuffer = "",
    }, Ws)
    ws:_emit(EVENT_ERROR)
    return ws
  end

  local accept = resp.headers["sec-websocket-accept"] or ""
  local expected = _buildAcceptKey(key)

  if not string.find(resp.statusLine, "101", 1, true) or accept ~= expected then
    tcp:close()
    local ws = setmetatable({
      _handlers = {},
      _sock = nil,
      _state = "error",
      _rxBuffer = "",
    }, Ws)
    ws:_emit(EVENT_ERROR)
    return ws
  end

  tcp:settimeout(0)

  local ws = setmetatable({
    _handlers = {},
    _sock = tcp,
    _state = "open",
    _rxBuffer = "",
  }, Ws)

  -- connect 직후 open 이벤트
  ws:_emit(EVENT_OPEN)

  return ws
end

return WebSocket
