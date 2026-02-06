--[[
파일명: net_manager.lua
모듈명: NetManager

역할:
- 서버(WebSocket) 연결/메시지 송수신 관리
- roomState 캐싱
- 이벤트 큐(events) 제공 (씬이 폴링하여 처리)

외부에서 사용 가능한 함수:
- NetManager.new()
- NetManager:update(dt)
- NetManager:connect(params)
- NetManager:disconnect()
- NetManager:isConnected()
- NetManager:send(type, payload)
- NetManager:getRoomState()
- NetManager:getPlayerId()
- NetManager:getRole()
- NetManager:getRoomCode()
- NetManager:popEvents()

주의:
- room.state는 캐시하고, 그 외 메시지는 이벤트 큐로 전달한다.
]]
local WsClient = require("net/ws_client")

local NetManager = {}
NetManager.__index = NetManager

function NetManager.new()
  local self = setmetatable({}, NetManager)

  self._ws = nil
  self._isConnected = false

  self._roomCode = ""
  self._playerId = ""
  self._role = ""

  self._roomState = nil

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
  local roomCode = params.roomCode or ""
  local nickname = params.nickname or "플레이어1"

  self:disconnect()

  local url = Config.NET_WS_URL
  if roomCode ~= "" then
    url = url .. "?code=" .. roomCode
  end

  self._ws = WsClient.new({
    url = url,
    onOpen = function()
      self._isConnected = true
      self:send("room.join", { nickname = nickname })
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

  local msg = {
    type = typeName,
    payload = payload or {},
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

  if msg.type == "room.hello" then
    if msg.payload and msg.payload.roomCode then
      self._roomCode = msg.payload.roomCode
    end
    return
  end

  if msg.type == "room.joined" then
    self._playerId = msg.payload.playerId or ""
    self._role = msg.payload.role or ""
    self._roomCode = msg.payload.roomCode or self._roomCode
    table.insert(self._events, msg)
    return
  end

  if msg.type == "room.state" then
    self._roomState = msg.payload
    if msg.payload and msg.payload.roomCode then
      self._roomCode = msg.payload.roomCode
    end
    return
  end

  table.insert(self._events, msg)
end

return NetManager
