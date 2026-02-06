--[[
파일명: waiting_room_scene.lua
모듈명: WaitingRoomScene

역할:
- 대기방 UI(방장/게스트 공용)
- 서버 WebSocket 연결 및 room.join 전송
- room.state / room.joined / room.left / room.closed 수신 처리
- 채팅 송수신(스팸 제한은 서버 룰)

외부에서 사용 가능한 함수:
- WaitingRoomScene.new(params)
- WaitingRoomScene:update(dt)
- WaitingRoomScene:draw()
- WaitingRoomScene:onMousePressed(...)
- WaitingRoomScene:onKeyPressed(...)
- WaitingRoomScene:onTextInput(text)

주의:
- 현재 단계에서는 게임 시작/맵 변경은 UI만 남겨두고, 네트워크는 대기/채팅 중심으로 연결한다.
]]
local Utils = require("utils")

local WaitingRoomScene = {}
WaitingRoomScene.__index = WaitingRoomScene

local function _decodeServerEvent(text)
  if not text or text == "" then
    return nil
  end

  local eventType = string.match(text, "\"type\"%s*:%s*\"([^\"]+)\"")
  if not eventType then
    return nil
  end

  -- payload는 이 단계에서는 간단히 raw로 보관(필요한 값만 패턴으로 추출)
  return {
    type = eventType,
    raw = text,
  }
end

local function _extractJsonString(raw, key)
  return string.match(raw, "\"" .. key .. "\"%s*:%s*\"([^\"]*)\"")
end

local function _extractJsonNumber(raw, key)
  local s = string.match(raw, "\"" .. key .. "\"%s*:%s*(%d+)")
  if not s then
    return nil
  end
  return tonumber(s)
end

function WaitingRoomScene.new(params)
  local self = setmetatable({}, WaitingRoomScene)

  self.name = "WaitingRoomScene"

  self._isHost = params and params.isHost or false
  self._roomCode = params and params.roomCode or ""
  self._statusText = ""
  self._phaseText = "대기 중"

  self._hostPlayerId = ""
  self._guestPlayerId = ""

  self._chatMessages = {}
  self._chatInput = ""
  self._isChatEditing = false

  self._chatRect = { x = 80, y = 360, w = 560, h = 220 }
  self._chatInputRect = { x = 80, y = 600, w = 560, h = 44 }

  self._buttons = {
    { key = "leave", label = "로비로 복귀", x = 680, y = 160, w = 220, h = 56 },
  }

  if self._isHost then
    table.insert(self._buttons, { key = "start", label = "게임 시작(추후)", x = 680, y = 230, w = 220, h = 56 })
  else
    table.insert(self._buttons, { key = "ready", label = "준비(추후)", x = 680, y = 230, w = 220, h = 56 })
  end

  self:_connectIfNeeded()

  return self
end

function WaitingRoomScene:update(_dt)
  -- 네트워크 이벤트 폴링
  while true do
    local ev = App:pollNetEvent()
    if not ev then
      break
    end

    if ev.type == "net.connected" then
      self:_sendJoin()
    elseif ev.type == "net.disconnected" then
      self._statusText = "연결이 종료되었습니다."
    elseif ev.type == "net.message" then
      self:_handleServerMessage(ev.payload.text)
    end
  end
end

function WaitingRoomScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.print("대기방", 80, 80)

  love.graphics.setFont(Assets:getFont("default"))
  love.graphics.print("방 코드: " .. tostring(self._roomCode), 80, 130)
  love.graphics.print("상태: " .. tostring(self._phaseText), 80, 160)

  if self._statusText ~= "" then
    love.graphics.print(self._statusText, 80, 200)
  end

  love.graphics.rectangle("line", self._chatRect.x, self._chatRect.y, self._chatRect.w, self._chatRect.h)
  love.graphics.print("채팅", self._chatRect.x, self._chatRect.y - 28)

  local startY = self._chatRect.y + 12
  local maxLines = 9
  local beginIndex = math.max(1, #self._chatMessages - maxLines + 1)
  local y = startY

  for i = beginIndex, #self._chatMessages do
    love.graphics.print(self._chatMessages[i], self._chatRect.x + 12, y)
    y = y + 22
  end

  love.graphics.rectangle("line", self._chatInputRect.x, self._chatInputRect.y, self._chatInputRect.w, self._chatInputRect.h)
  love.graphics.print(self._chatInput, self._chatInputRect.x + 12, self._chatInputRect.y + 10)

  if self._isChatEditing then
    local caretX = self._chatInputRect.x + 12 + love.graphics.getFont():getWidth(self._chatInput)
    love.graphics.line(caretX, self._chatInputRect.y + 8, caretX, self._chatInputRect.y + self._chatInputRect.h - 8)
  end

  for _, btn in ipairs(self._buttons) do
    local mx, my = love.mouse.getPosition()
    local isHovered = Utils.isPointInRect(mx, my, btn.x, btn.y, btn.w, btn.h)
    Utils.drawButton({ x = btn.x, y = btn.y, w = btn.w, h = btn.h }, btn.label, isHovered)
  end
end

function WaitingRoomScene:onTextInput(text)
  if not self._isChatEditing then
    return false
  end

  -- 채팅은 한글 포함 허용
  self._chatInput = self._chatInput .. tostring(text or "")
  if #self._chatInput > 120 then
    self._chatInput = string.sub(self._chatInput, 1, 120)
  end

  return true
end

function WaitingRoomScene:onKeyPressed(key, _scancode, _isrepeat)
  if self._isChatEditing then
    if key == "backspace" then
      self._chatInput = string.sub(self._chatInput, 1, math.max(0, #self._chatInput - 1))
      return true
    end

    if key == "return" or key == "kpenter" then
      self:_sendChat()
      return true
    end

    if key == "escape" then
      self._isChatEditing = false
      love.keyboard.setTextInput(false)
      return true
    end

    return false
  end

  if key == "escape" then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function WaitingRoomScene:onMousePressed(x, y, button, _istouch, _presses)
  if button ~= 1 then
    return false
  end

  if Utils.isPointInRect(x, y, self._chatInputRect.x, self._chatInputRect.y, self._chatInputRect.w, self._chatInputRect.h) then
    self._isChatEditing = true
    love.keyboard.setTextInput(true)
    return true
  end

  for _, btn in ipairs(self._buttons) do
    if Utils.isPointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
      if btn.key == "leave" then
        self:_disconnectAndGoLobby()
        return true
      end

      if btn.key == "start" then
        self:_appendChatSystem("게임 시작은 후속 구현입니다.")
        return true
      end

      if btn.key == "ready" then
        self:_appendChatSystem("준비 기능은 후속 구현입니다.")
        return true
      end
    end
  end

  return false
end

function WaitingRoomScene:_connectIfNeeded()
  local wsBase = Config.SERVER_WS_BASE
  local wsUrl = wsBase .. "/ws?room=" .. tostring(self._roomCode)

  local netClient = App:getNetClient()
  if netClient:isConnected() then
    -- 이미 연결된 상태면 그대로 사용 (단, 다른 방이면 다음 단계에서 방 전환 처리 필요)
    return
  end

  local ok = netClient:connect(wsUrl)
  if not ok then
    self._statusText = "서버 연결 실패: " .. netClient:getLastError()
  else
    self._statusText = ""
  end
end

function WaitingRoomScene:_sendJoin()
  local settings = App:getSettingsManager()
  local netClient = App:getNetClient()

  local msg = {
    type = "room.join",
    payload = {
      playerId = settings:getPlayerId(),
      nickname = settings:getNickname(),
    },
  }

  netClient:sendJson(msg)
end

function WaitingRoomScene:_sendChat()
  local text = tostring(self._chatInput or "")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")

  if text == "" then
    return
  end

  local netClient = App:getNetClient()
  netClient:sendJson({
    type = "chat.send",
    payload = { text = text },
  })

  self._chatInput = ""
end

function WaitingRoomScene:_handleServerMessage(text)
  local ev = _decodeServerEvent(text)
  if not ev then
    return
  end

  if ev.type == "room.state" then
    self._hostPlayerId = _extractJsonString(ev.raw, "hostPlayerId") or self._hostPlayerId
    self._guestPlayerId = _extractJsonString(ev.raw, "guestPlayerId") or self._guestPlayerId

    local phase = _extractJsonString(ev.raw, "phase")
    if phase and phase ~= "" then
      self._phaseText = phase
    end

    return
  end

  if ev.type == "room.joined" then
    local nickname = _extractJsonString(ev.raw, "nickname") or "플레이어"
    local role = _extractJsonString(ev.raw, "role") or ""
    self:_appendChatSystem(nickname .. "님이 입장했습니다. (" .. role .. ")")
    return
  end

  if ev.type == "room.left" then
    self:_appendChatSystem("상대가 퇴장했습니다.")
    return
  end

  if ev.type == "room.closed" then
    self:_appendChatSystem("방이 종료되었습니다. (방장 이탈)")
    self:_disconnectAndGoLobby()
    return
  end

  if ev.type == "chat.message" then
    local nickname = _extractJsonString(ev.raw, "nickname") or "플레이어"
    local msgText = _extractJsonString(ev.raw, "text") or ""
    self:_appendChatMessage(nickname .. ": " .. msgText)
    return
  end

  if ev.type == "chat.denied" then
    local reason = _extractJsonString(ev.raw, "reason") or "denied"
    self:_appendChatSystem("채팅 전송이 제한되었습니다: " .. reason)
    return
  end

  if ev.type == "match.turnOrder" then
    self:_appendChatSystem("매치가 시작되었습니다. (턴오더 수신)")
    return
  end
end

function WaitingRoomScene:_appendChatMessage(text)
  table.insert(self._chatMessages, tostring(text))
  if #self._chatMessages > 100 then
    table.remove(self._chatMessages, 1)
  end
end

function WaitingRoomScene:_appendChatSystem(text)
  self:_appendChatMessage("[시스템] " .. tostring(text))
end

function WaitingRoomScene:_disconnectAndGoLobby()
  love.keyboard.setTextInput(false)
  self._isChatEditing = false

  App:getNetClient():disconnect()
  SceneManager:change("LobbyScene")
end

return WaitingRoomScene
