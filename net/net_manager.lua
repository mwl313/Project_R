--[[
파일명: net/net_manager.lua
모듈명: NetManager

역할:
- 서버(WebSocket) 연결/메시지 송수신 관리
- roomState 캐싱
- 이벤트 큐(events) 제공 (씬이 폴링하여 처리)
- 서버 프로토콜이 다르더라도(hello/snapshot/chat vs room.*) 씬이 기대하는 이벤트로 변환

외부에서 사용 가능한 함수:
- NetManager.new()
- NetManager:update(dt)
- NetManager:connect(params)
- NetManager:disconnect()
- NetManager:isConnected()
- NetManager:send(typeName, payload)
- NetManager:getRoomState()
- NetManager:getPlayerId()
- NetManager:getRole()
- NetManager:getRoomCode()
- NetManager:popEvents()

주의:
- room.state는 캐시하고, 그 외 메시지는 이벤트 큐로 전달한다.
- wsUrl(상대경로)이 내려오면 Config.SERVER_WS_BASE가 필요하다.
- 호환 목적상 connect 직후 hello + room.join을 모두 전송한다.
]]
local WsClient = require("net/ws_client")
local Utils = require("utils")

local NetManager = {}
NetManager.__index = NetManager

local function _startsWith(text, prefix)
  if not text or not prefix then
    return false
  end
  return string.sub(text, 1, #prefix) == prefix
end

local function _buildWsUrl(params)
  local wsUrl = params.wsUrl or ""
  if wsUrl ~= "" then
    if _startsWith(wsUrl, "ws://") or _startsWith(wsUrl, "wss://") then
      return wsUrl
    end

    if _startsWith(wsUrl, "/") then
      local base = Config.SERVER_WS_BASE or ""
      if base == "" then
        return ""
      end
      return base .. wsUrl
    end

    local base2 = Config.SERVER_WS_BASE or ""
    if base2 ~= "" then
      return base2 .. "/" .. wsUrl
    end

    return wsUrl
  end

  local roomCode = params.roomCode or ""
  local url = Config.NET_WS_URL or ""
  if url == "" then
    return ""
  end

  if roomCode ~= "" then
    url = url .. "?code=" .. roomCode
  end

  return url
end

local function _normalizeOutboundType(typeName)
  if typeName == "chat.send" then
    return "chat"
  end

  if typeName == "room.join" then
    return "hello"
  end

  return typeName
end

local function _wrapOutboundPayload(typeName, payload, nickname)
  local p = payload or {}

  if typeName == "hello" then
    if p.nickname == nil then
      p.nickname = nickname or "플레이어1"
    end
    return p
  end

  if typeName == "chat" then
    if p.text == nil and payload and payload.text ~= nil then
      p.text = payload.text
    end
    return p
  end

  return p
end

local function _toSceneEventType(serverType)
  if serverType == "hello_ok" then
    return "room.joined"
  end

  if serverType == "snapshot" then
    return "room.state"
  end

  if serverType == "chat" then
    return "chat.message"
  end

  if serverType == "chat_denied" then
    return "chat.denied"
  end

  if serverType == "room_closed" then
    return "room.closed"
  end

  if serverType == "left" then
    return "room.left"
  end

  if serverType == "turn_order" or serverType == "match.turnOrder" then
    return "match.turnOrder"
  end

  return serverType
end

local function _normalizeInboundPayload(serverType, payload)
  local p = payload or {}

  if serverType == "hello_ok" then
    return {
      playerId = p.playerId or p.id or "",
      role = p.role or "",
      roomCode = p.roomCode or p.code or "",
      nickname = p.nickname or "",
    }
  end

  if serverType == "snapshot" then
    -- 서버 구현에 따라 payload가 {hostPlayerId, guestPlayerId, phase} 형태일 수도 있고,
    -- 더 깊은 구조일 수도 있다. 씬이 기대하는 키는 최대한 그대로 유지한다.
    return p
  end

  if serverType == "chat" then
    return {
      nickname = p.nickname or p.from or "플레이어",
      text = p.text or "",
    }
  end

  if serverType == "chat_denied" then
    return {
      reason = p.reason or "denied",
    }
  end

  return p
end

function NetManager.new()
  local self = setmetatable({}, NetManager)

  self._ws = nil
  self._isConnected = false

  self._roomCode = ""
  self._playerId = ""
  self._role = ""

  self._roomState = nil

  self._nickname = "플레이어1"

  self._inbox = {}
  self._events = {}

  return self
end

function NetManager:update(dt)
  if not self._ws then
    return
  end

  self._ws:update(dt)

  while true do
    local raw = table.remove(self._inbox, 1)
    if not raw then
      break
    end

    self:_handleRawMessage(raw)
  end
end

function NetManager:connect(params)
  local nickname = params and params.nickname or "플레이어1"
  self._nickname = nickname

  self:disconnect()

  local url = _buildWsUrl(params or {})
  if url == "" then
    table.insert(self._events, { type = "net.error", payload = { reason = "ws_url_empty" } })
    return false
  end

  self._ws = WsClient.new({
    url = url,
    onOpen = function()
      self._isConnected = true

      -- 호환 목적: 서버가 hello 기반이든 room.join 기반이든 붙도록 둘 다 보낸다.
      self:send("hello", { nickname = self._nickname })
      self:send("room.join", { nickname = self._nickname })
    end,
    onMessage = function(text)
      table.insert(self._inbox, text)
    end,
    onClose = function()
      self._isConnected = false
      table.insert(self._events, { type = "net.closed", payload = {} })
    end,
    onError = function()
      self._isConnected = false
      table.insert(self._events, { type = "net.error", payload = {} })
    end,
  })

  return true
end

function NetManager:disconnect()
  if self._ws then
    self._ws:close()
  end

  self._ws = nil
  self._isConnected = false

  self._roomCode = ""
  self._playerId = ""
  self._role = ""
  self._roomState = nil

  self._inbox = {}
  self._events = {}
end

function NetManager:isConnected()
  return self._isConnected
end

function NetManager:send(typeName, payload)
  if not self._ws or not self._isConnected then
    return false
  end

  local normalizedType = _normalizeOutboundType(typeName)
  local normalizedPayload = _wrapOutboundPayload(normalizedType, payload, self._nickname)

  local msg = {
    type = normalizedType,
    payload = normalizedPayload,
  }

  self._ws:sendJson(msg)
  return true
end

function NetManager:getRoomState()
  return self._roomState
end

function NetManager:getPlayerId()
  return self._playerId
end

function NetManager:getRole()
  return self._role
end

function NetManager:getRoomCode()
  return self._roomCode
end

function NetManager:popEvents()
  local events = self._events
  self._events = {}
  return events
end

function NetManager:_handleRawMessage(text)
  local ok, msg = pcall(function()
    return Utils.decodeJson(text)
  end)

  if not ok or not msg or not msg.type then
    return
  end

  local sceneType = _toSceneEventType(msg.type)
  local payload = _normalizeInboundPayload(msg.type, msg.payload)

  if sceneType == "room.joined" then
    self._playerId = payload.playerId or ""
    self._role = payload.role or ""
    if payload.roomCode and payload.roomCode ~= "" then
      self._roomCode = payload.roomCode
    end

    table.insert(self._events, { type = "room.joined", payload = payload })
    return
  end

  if sceneType == "room.state" then
    self._roomState = payload
    if payload and payload.roomCode and payload.roomCode ~= "" then
      self._roomCode = payload.roomCode
    end
    table.insert(self._events, { type = "room.state", payload = payload })
    return
  end

  if sceneType == "chat.message" then
    table.insert(self._events, { type = "chat.message", payload = payload })
    return
  end

  if sceneType == "chat.denied" then
    table.insert(self._events, { type = "chat.denied", payload = payload })
    return
  end

  if sceneType == "room.closed" then
    table.insert(self._events, { type = "room.closed", payload = payload })
    return
  end

  if sceneType == "room.left" then
    table.insert(self._events, { type = "room.left", payload = payload })
    return
  end

  if sceneType == "match.turnOrder" then
    table.insert(self._events, { type = "match.turnOrder", payload = payload })
    return
  end

  table.insert(self._events, { type = tostring(sceneType), payload = payload })
end

return NetManager
