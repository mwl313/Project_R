--[[
파일명: room_search_scene.lua
모듈명: RoomSearchScene

역할:
- 방 코드 입력 화면
- "입장" 클릭 시 대기방(게스트)로 이동
- "로비로" 클릭 시 로비로 복귀

외부에서 사용 가능한 함수:
- RoomSearchScene.new(params)
- RoomSearchScene:update(dt)
- RoomSearchScene:draw()
- RoomSearchScene:onKeyPressed(key, scancode, isrepeat)
- RoomSearchScene:onTextInput(text)
- RoomSearchScene:onMousePressed(x, y, button, istouch, presses)

주의:
- 실제 WS 연결/room.join은 WaitingRoomScene에서 수행
]]
local Utils = require("utils")

local RoomSearchScene = {}
RoomSearchScene.__index = RoomSearchScene

function RoomSearchScene.new(_params)
  local self = setmetatable({}, RoomSearchScene)

  self.name = "RoomSearchScene"

  self._input = ""
  self._isEditing = true
  self._statusText = ""

  self._inputRect = { x = 80, y = 200, w = 420, h = 56 }

  self._buttons = {
    { key = "enter", label = "입장", x = 80, y = 280, w = 200, h = 56 },
    { key = "back", label = "로비로", x = 300, y = 280, w = 200, h = 56 },
  }

  love.keyboard.setTextInput(true)

  return self
end

function RoomSearchScene:update(_dt)
end

function RoomSearchScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.print("방 코드 입력", 80, 120)

  love.graphics.setFont(Assets:getFont("default"))

  -- input box
  love.graphics.rectangle("line", self._inputRect.x, self._inputRect.y, self._inputRect.w, self._inputRect.h)
  love.graphics.print(self._input, self._inputRect.x + 12, self._inputRect.y + 14)

  if self._statusText ~= "" then
    love.graphics.print(self._statusText, 80, 360)
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

  -- 방 코드는 서버에서 생성한 대문자+숫자이므로 여기서는 간단히 필터링(대문자/숫자)
  local upper = string.upper(text)
  upper = string.gsub(upper, "[^A-Z0-9]", "")
  self._input = self._input .. upper

  if #self._input > 12 then
    self._input = string.sub(self._input, 1, 12)
  end

  return true
end

function RoomSearchScene:onKeyPressed(key, _scancode, _isrepeat)
  if key == "backspace" then
    self._input = string.sub(self._input, 1, math.max(0, #self._input - 1))
    return true
  end

  if key == "return" or key == "kpenter" then
    self:_enterRoom()
    return true
  end

  if key == "escape" then
    love.keyboard.setTextInput(false)
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
      if btn.key == "enter" then
        self:_enterRoom()
        return true
      end
      if btn.key == "back" then
        love.keyboard.setTextInput(false)
        SceneManager:change("LobbyScene")
        return true
      end
    end
  end

  return false
end

function RoomSearchScene:_enterRoom()
  local code = string.upper(self._input or "")
  code = string.gsub(code, "%s+", "")

  if code == "" then
    self._statusText = "방 코드를 입력해 주세요."
    return
  end

  love.keyboard.setTextInput(false)
  SceneManager:change("WaitingRoomScene", { isHost = false, roomCode = code })
end

return RoomSearchScene
