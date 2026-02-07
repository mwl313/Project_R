--[[
파일명: room_search_scene.lua
모듈명: RoomSearchScene

역할:
- 방 코드 입력 UI
- 서버 HTTP(/room/join)로 참가 처리
- 성공 시 WaitingRoomScene으로 이동

외부에서 사용 가능한 함수:
- RoomSearchScene.new(params)
- RoomSearchScene:update(dt)
- RoomSearchScene:draw()
- RoomSearchScene:onMousePressed(...)
- RoomSearchScene:onKeyPressed(...)
- RoomSearchScene:onTextInput(text)

주의:
- 이 씬은 “방 참가”에만 집중한다. (로비 UI는 유지)
]]
local Utils = require("utils")
local HttpClient = require("http_client")

local RoomSearchScene = {}
RoomSearchScene.__index = RoomSearchScene

local function _trim(text)
  if not text then
    return ""
  end
  return (string.match(text, "^%s*(.-)%s*$") or "")
end

local function _extractJsonString(raw, key)
  if not raw then
    return ""
  end
  return string.match(raw, "\"" .. key .. "\"%s*:%s*\"([^\"]*)\"") or ""
end

function RoomSearchScene.new(_params)
  local self = setmetatable({}, RoomSearchScene)

  self.name = "RoomSearchScene"

  self._statusText = ""

  self._roomCode = ""
  self._isEditing = false

  self._inputRect = { x = 260, y = 260, w = 360, h = 52 }

  self._buttons = {
    { key = "join", label = "참가", x = 260, y = 330, w = 170, h = 56 },
    { key = "back", label = "뒤로", x = 450, y = 330, w = 170, h = 56 },
  }

  return self
end

function RoomSearchScene:update(_dt)
end

function RoomSearchScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.print("방 참가", 260, 170)

  love.graphics.setFont(Assets:getFont("default"))
  love.graphics.print("방 코드를 입력하세요", 260, 220)

  love.graphics.rectangle("line", self._inputRect.x, self._inputRect.y, self._inputRect.w, self._inputRect.h)
  love.graphics.print(self._roomCode, self._inputRect.x + 12, self._inputRect.y + 14)

  if self._isEditing then
    local caretX = self._inputRect.x + 12 + love.graphics.getFont():getWidth(self._roomCode)
    love.graphics.line(caretX, self._inputRect.y + 10, caretX, self._inputRect.y + self._inputRect.h - 10)
  end

  if self._statusText ~= "" then
    love.graphics.print(self._statusText, 260, 410)
  end

  for _, btn in ipairs(self._buttons) do
    local mx, my = love.mouse.getPosition()
    local isHovered = Utils.isPointInRect(mx, my, btn.x, btn.y, btn.w, btn.h)
    Utils.drawButton({ x = btn.x, y = btn.y, w = btn.w, h = btn.h }, btn.label, isHovered)
  end
end

function RoomSearchScene:onTextInput(text)
  if not self._isEditing then
    return false
  end

  local t = tostring(text or "")
  if t == "" then
    return true
  end

  self._roomCode = self._roomCode .. t
  if #self._roomCode > 12 then
    self._roomCode = string.sub(self._roomCode, 1, 12)
  end

  return true
end

function RoomSearchScene:onKeyPressed(key, _scancode, _isrepeat)
  if self._isEditing then
    if key == "backspace" then
      self._roomCode = string.sub(self._roomCode, 1, math.max(0, #self._roomCode - 1))
      return true
    end

    if key == "return" or key == "kpenter" then
      self:_tryJoin()
      return true
    end

    if key == "escape" then
      self._isEditing = false
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

function RoomSearchScene:onMousePressed(x, y, button, _istouch, _presses)
  if button ~= 1 then
    return false
  end

  if Utils.isPointInRect(x, y, self._inputRect.x, self._inputRect.y, self._inputRect.w, self._inputRect.h) then
    self._isEditing = true
    love.keyboard.setTextInput(true)
    return true
  end

  for _, btn in ipairs(self._buttons) do
    if Utils.isPointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
      if btn.key == "back" then
        love.keyboard.setTextInput(false)
        SceneManager:change("LobbyScene")
        return true
      end

      if btn.key == "join" then
        self:_tryJoin()
        return true
      end
    end
  end

  return false
end

function RoomSearchScene:_tryJoin()
  local roomCode = _trim(self._roomCode)
  if roomCode == "" then
    self._statusText = "방 코드를 입력해주세요."
    return
  end

  local url = Config.SERVER_HTTP_BASE .. "/room/join"
  local nickname = App:getSettingsManager():getNickname()

  local body, err = HttpClient.postJson(url, { roomCode = roomCode, nickname = nickname })
  if not body then
    self._statusText = "참가 실패: " .. tostring(err)
    return
  end

  local ok = string.match(body, "\"ok\"%s*:%s*true") ~= nil
  if not ok then
    self._statusText = "참가 실패: 서버 응답 오류"
    return
  end

  local joinedRoomCode = _extractJsonString(body, "roomCode")
  local wsUrl = _extractJsonString(body, "wsUrl")

  if joinedRoomCode == "" or wsUrl == "" then
    self._statusText = "참가 실패: wsUrl/roomCode 누락"
    return
  end

  love.keyboard.setTextInput(false)
  SceneManager:change("WaitingRoomScene", {
    isHost = false,
    roomCode = joinedRoomCode,
    wsUrl = wsUrl,
  })
end

return RoomSearchScene
