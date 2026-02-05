--[[
파일명: room_search_scene.lua
모듈명: RoomSearchScene

역할:
- 방 코드 입력 화면(UI 스켈레톤)
- "입장(더미)" 클릭 시 대기방(게스트)로 이동
- "로비로" 클릭 시 로비로 복귀

외부에서 사용 가능한 함수:
- RoomSearchScene.new(params)
- RoomSearchScene:update(dt)
- RoomSearchScene:draw()
- RoomSearchScene:onKeyPressed(key, scancode, isrepeat)
- RoomSearchScene:onMousePressed(x, y, button, istouch, presses)
- RoomSearchScene:onMouseReleased(x, y, button, istouch, presses)

주의:
- 실제 네트워크/검증은 후속 구현
]]
local Utils = require("utils")

local RoomSearchScene = {}
RoomSearchScene.__index = RoomSearchScene

function RoomSearchScene.new(params)
  local self = setmetatable({}, RoomSearchScene)

  self.name = "RoomSearchScene"

  self._mouseX = 0
  self._mouseY = 0

  self._roomCode = "ABCD-1234"
  self._message = "방 코드를 입력하세요. (스켈레톤)"
  self._hasError = false

  self._inputRect = { x = 80, y = 170, w = 520, h = 52 }
  self._joinRect = { x = 80, y = 250, w = 260, h = 52 }
  self._backRect = { x = 80, y = 320, w = 260, h = 52 }

  return self
end

function RoomSearchScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
end

function RoomSearchScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("방 찾기", 0, 50, Config.WINDOW_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))

  love.graphics.print("방 코드(더미 입력):", 80, 140)
  love.graphics.rectangle("line", self._inputRect.x, self._inputRect.y, self._inputRect.w, self._inputRect.h)
  love.graphics.printf(self._roomCode, self._inputRect.x + 12, self._inputRect.y + 14, self._inputRect.w - 24, "left")

  if self._hasError then
    love.graphics.printf("존재하지 않는 방 코드입니다. (더미)", 80, 230, 900, "left")
  else
    love.graphics.printf(self._message, 80, 230, 900, "left")
  end

  local isJoinHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._joinRect.x, self._joinRect.y, self._joinRect.w, self._joinRect.h)
  Utils.drawButton({ x = self._joinRect.x, y = self._joinRect.y, w = self._joinRect.w, h = self._joinRect.h }, "입장(더미)", isJoinHovered)

  local isBackHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._backRect.x, self._backRect.y, self._backRect.w, self._backRect.h)
  Utils.drawButton({ x = self._backRect.x, y = self._backRect.y, w = self._backRect.w, h = self._backRect.h }, "로비로", isBackHovered)

  love.graphics.setFont(Assets:getFont("small"))
  love.graphics.print("단축키: Enter=입장(더미), Esc=로비", 80, 650)
  love.graphics.setFont(Assets:getFont("default"))
end

function RoomSearchScene:onKeyPressed(key, scancode, isrepeat)
  if key == "return" then
    -- 더미: 항상 성공 처리 → 게스트로 대기방 입장
    SceneManager:change("WaitingRoomScene", { isHost = false })
    return true
  end

  if key == "escape" then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function RoomSearchScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if Utils.isPointInRect(x, y, self._joinRect.x, self._joinRect.y, self._joinRect.w, self._joinRect.h) then
    SceneManager:change("WaitingRoomScene", { isHost = false })
    return true
  end

  if Utils.isPointInRect(x, y, self._backRect.x, self._backRect.y, self._backRect.w, self._backRect.h) then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function RoomSearchScene:onMouseReleased(x, y, button, istouch, presses)
  return false
end

return RoomSearchScene
