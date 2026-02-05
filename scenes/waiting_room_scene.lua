--[[
파일명: waiting_room_scene.lua
모듈명: WaitingRoomScene

역할:
- 대기방 UI(방장/게스트 공용 스켈레톤)
- 방장: 맵 변경/게임 시작
- 게스트: 준비 버튼
- 나가기: 로비 복귀

외부에서 사용 가능한 함수:
- WaitingRoomScene.new(params)
- WaitingRoomScene:update(dt)
- WaitingRoomScene:draw()
- WaitingRoomScene:onMousePressed(...)

주의:
- 멀티 로직은 후속 구현. 지금은 UI만 구성
]]
local Utils = require("utils")

local WaitingRoomScene = {}
WaitingRoomScene.__index = WaitingRoomScene

function WaitingRoomScene.new(params)
  local self = setmetatable({}, WaitingRoomScene)

  self.name = "WaitingRoomScene"
  self._isHost = params.isHost == true

  self._mouseX = 0
  self._mouseY = 0

  self._leaveRect = { x = 80, y = 600, w = 260, h = 52 }

  self._hostButtons = {
    { key = "mapChange", label = "맵 변경(더미)", x = 80, y = 180, w = 260, h = 52 },
    { key = "startGame", label = "게임 시작(더미)", x = 80, y = 250, w = 260, h = 52 },
  }

  self._guestButtons = {
    { key = "ready", label = "준비(더미)", x = 80, y = 180, w = 260, h = 52 },
  }

  return self
end

function WaitingRoomScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
end

function WaitingRoomScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("대기방", 0, 50, Config.WINDOW_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))

  love.graphics.print("방 코드: ABCD-1234 (더미)", 80, 120)
  love.graphics.print("플레이어: 방장 / 상대 (더미)", 80, 150)

  local buttons = self._isHost and self._hostButtons or self._guestButtons
  for _, b in ipairs(buttons) do
    local isHovered = Utils.isPointInRect(self._mouseX, self._mouseY, b.x, b.y, b.w, b.h)
    Utils.drawButton({ x = b.x, y = b.y, w = b.w, h = b.h }, b.label, isHovered)
  end

  local isLeaveHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._leaveRect.x, self._leaveRect.y, self._leaveRect.w, self._leaveRect.h)
  Utils.drawButton({ x = self._leaveRect.x, y = self._leaveRect.y, w = self._leaveRect.w, h = self._leaveRect.h }, "로비로 복귀", isLeaveHovered)
end

function WaitingRoomScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if Utils.isPointInRect(x, y, self._leaveRect.x, self._leaveRect.y, self._leaveRect.w, self._leaveRect.h) then
    SceneManager:change("LobbyScene")
    return true
  end

  local buttons = self._isHost and self._hostButtons or self._guestButtons
  for _, b in ipairs(buttons) do
    if Utils.isPointInRect(x, y, b.x, b.y, b.w, b.h) then
      self:_handleButton(b.key)
      return true
    end
  end

  return false
end

function WaitingRoomScene:_handleButton(key)
  if key == "startGame" then
    SceneManager:change("MatchScene", { fromWaitingRoom = true })
    return
  end
end

function WaitingRoomScene:onKeyPressed(key, scancode, isrepeat)
  return false
end

function WaitingRoomScene:onMouseReleased(x, y, button, istouch, presses)
  return false
end

return WaitingRoomScene
