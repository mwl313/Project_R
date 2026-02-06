--[[
파일명: http_client.lua
모듈명: HttpClient

역할:
- 서버 HTTP 요청(현재: POST /room/create)
- LuaSocket 기반(선택: LuaSec)
- 로컬 dev(http) + 실서버(https) 지원

외부에서 사용 가능한 함수:
- HttpClient.postJson(url, bodyTable)

주의:
- LÖVE 기본에는 LuaSocket/LuaSec가 포함되지 않을 수 있다.
- 의존성이 없다면 require 단계에서 에러가 발생한다.
]]
local HttpClient = {}
HttpClient.__index = HttpClient

local function _tryRequire(moduleName)
  local ok, mod = pcall(require, moduleName)
  if ok then
    return mod
  end
  return nil
end

local function _encodeJson(tableValue)
  -- 최소 구현: 서버와 주고받는 범위만 커버(문자열/숫자/불리언/객체/배열)
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

local function _decodeJson(text)
  -- 현재 단계에서는 서버 응답 { "roomCode": "ABCDE" } 정도만 파싱하면 되므로
  -- 매우 제한적으로 처리한다.
  -- 안정적 파서가 필요하면 다음 단계에서 json 라이브러리로 교체.
  if not text or text == "" then
    return nil
  end

  local roomCode = string.match(text, "\"roomCode\"%s*:%s*\"([^\"]+)\"")
  if roomCode then
    return { roomCode = roomCode }
  end

  return nil
end

local function _parseUrl(url)
  local protocol, host, path = string.match(url, "^(https?)://([^/]+)(/.*)$")
  if not protocol then
    protocol, host = string.match(url, "^(https?)://([^/]+)$")
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
    port = (protocol == "https") and 443 or 80
  end

  return {
    protocol = protocol,
    host = hostname,
    port = port,
    path = path,
  }
end

function HttpClient.postJson(url, bodyTable)
  local socket = _tryRequire("socket")
  if not socket then
    return nil, "LuaSocket이 필요합니다(require('socket') 실패)."
  end

  local ssl = _tryRequire("ssl")
  local httpsParams = _parseUrl(url)
  if not httpsParams then
    return nil, "잘못된 URL입니다."
  end

  local tcp = assert(socket.tcp())
  tcp:settimeout(10)

  local ok, err = tcp:connect(httpsParams.host, httpsParams.port)
  if not ok then
    return nil, "connect 실패: " .. tostring(err)
  end

  local conn = tcp
  if httpsParams.protocol == "https" then
    if not ssl then
      return nil, "HTTPS 요청을 위해 LuaSec(ssl)이 필요합니다."
    end

    local wrapped, werr = ssl.wrap(tcp, {
      mode = "client",
      protocol = "tlsv1_2",
      verify = "none",
      options = "all",
      server = httpsParams.host,
    })
    if not wrapped then
      return nil, "ssl.wrap 실패: " .. tostring(werr)
    end

    local hsOk, hsErr = wrapped:dohandshake()
    if not hsOk then
      return nil, "TLS handshake 실패: " .. tostring(hsErr)
    end

    conn = wrapped
  end

  local bodyText = _encodeJson(bodyTable or {})
  local requestText =
    "POST " .. httpsParams.path .. " HTTP/1.1\r\n" ..
    "Host: " .. httpsParams.host .. "\r\n" ..
    "Content-Type: application/json\r\n" ..
    "Content-Length: " .. tostring(#bodyText) .. "\r\n" ..
    "Connection: close\r\n" ..
    "\r\n" ..
    bodyText

  conn:send(requestText)

  local chunks = {}
  while true do
    local chunk, cerr, partial = conn:receive(1024)
    if chunk and chunk ~= "" then
      table.insert(chunks, chunk)
    elseif partial and partial ~= "" then
      table.insert(chunks, partial)
    end

    if cerr == "closed" then
      break
    end

    if cerr and cerr ~= "timeout" and cerr ~= "closed" then
      break
    end
  end

  conn:close()

  local raw = table.concat(chunks)
  local body = string.match(raw, "\r\n\r\n(.*)$") or ""
  return _decodeJson(body), nil
end

return HttpClient
