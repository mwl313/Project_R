--[[
파일명: result_scene.lua
모듈명: ResultScene

역할:
- 게임 결과 확인 화면
- 재대결: 양쪽 모두 선택 시 대기방으로 이동
- 로비로: 한쪽이라도 로비를 누르면 둘 다 로비로 이동(스켈레톤은 즉시 로비 이동)

외부에서 사용 가능한 함수:
- ResultScene.new(params)
- ResultScene:update(dt)
- ResultScene:draw()
- ResultScene:onKeyPressed(key, scancode, isrepeat)
- ResultScene:onMousePressed(x, y, button, istouch, presses)
- ResultScene:onMouseReleased(x, y, button, istouch, presses)

주의:
- 멀티 투표 동기화는 후속 구현
- 스켈레톤에서는 "양쪽 재대결"을 시뮬레이션하기 위해 P1/P2 토글 버튼 제공
]]
local Utils = require("utils")

local ResultScene = {}
ResultScene.__index = ResultScene

function ResultScene.new(params)
  local self = setmetatable({}, ResultScene)

  self.name = "ResultScene"

  self._mouseX = 0
  self._mouseY = 0

  self._reason = params.reason or "알 수 없음"
  self._resultText = params.resultText or "결과(더미)"

  self._p1WantsRematch = false
  self._p2WantsRematch = false

  self._p1ToggleRect = { x = 80, y = 260, w = 320, h = 52 }
  self._p2ToggleRect = { x = 420, y = 260, w = 320, h = 52 }

  self._rematchRect = { x = 80, y = 360, w = 260, h = 52 }
  self._toLobbyRect = { x = 360, y = 360, w = 260, h = 52 }

  return self
end

function ResultScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
end

function ResultScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("게임 결과", 0, 50, Config.WINDOW_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))

  love.graphics.print("종료 사유: " .. self._reason, 80, 130)
  love.graphics.print("결과: " .. self._resultText, 80, 160)

  love.graphics.print("재대결 투표(스켈레톤):", 80, 230)

  local p1Label = self._p1WantsRematch and "P1: 재대결 O" or "P1: 재대결 X"
  local p2Label = self._p2WantsRematch and "P2: 재대결 O" or "P2: 재대결 X"

  local isP1Hovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._p1ToggleRect.x, self._p1ToggleRect.y, self._p1ToggleRect.w, self._p1ToggleRect.h)
  Utils.drawButton({ x = self._p1ToggleRect.x, y = self._p1ToggleRect.y, w = self._p1ToggleRect.w, h = self._p1ToggleRect.h }, p1Label, isP1Hovered)

  local isP2Hovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._p2ToggleRect.x, self._p2ToggleRect.y, self._p2ToggleRect.w, self._p2ToggleRect.h)
  Utils.drawButton({ x = self._p2ToggleRect.x, y = self._p2ToggleRect.y, w = self._p2ToggleRect.w, h = self._p2ToggleRect.h }, p2Label, isP2Hovered)

  local isRematchHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._rematchRect.x, self._rematchRect.y, self._rematchRect.w, self._rematchRect.h)
  Utils.drawButton({ x = self._rematchRect.x, y = self._rematchRect.y, w = self._rematchRect.w, h = self._rematchRect.h }, "재대결", isRematchHovered)

  local isLobbyHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._toLobbyRect.x, self._toLobbyRect.y, self._toLobbyRect.w, self._toLobbyRect.h)
  Utils.drawButton({ x = self._toLobbyRect.x, y = self._toLobbyRect.y, w = self._toLobbyRect.w, h = self._toLobbyRect.h }, "로비로 돌아가기", isLobbyHovered)

  love.graphics.setFont(Assets:getFont("small"))
  love.graphics.print("단축키: 1=P1 토글, 2=P2 토글, R=재대결, L=로비", 80, 650)
  love.graphics.setFont(Assets:getFont("default"))
end

function ResultScene:onKeyPressed(key, scancode, isrepeat)
  if key == "1" then
    self._p1WantsRematch = not self._p1WantsRematch
    return true
  end

  if key == "2" then
    self._p2WantsRematch = not self._p2WantsRematch
    return true
  end

  if key == "r" then
    self:_handleRematch()
    return true
  end

  if key == "l" or key == "escape" then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function ResultScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if Utils.isPointInRect(x, y, self._p1ToggleRect.x, self._p1ToggleRect.y, self._p1ToggleRect.w, self._p1ToggleRect.h) then
    self._p1WantsRematch = not self._p1WantsRematch
    return true
  end

  if Utils.isPointInRect(x, y, self._p2ToggleRect.x, self._p2ToggleRect.y, self._p2ToggleRect.w, self._p2ToggleRect.w, self._p2ToggleRect.h) then
    self._p2WantsRematch = not self._p2WantsRematch
    return true
  end

  if Utils.isPointInRect(x, y, self._rematchRect.x, self._rematchRect.y, self._rematchRect.w, self._rematchRect.h) then
    self:_handleRematch()
    return true
  end

  if Utils.isPointInRect(x, y, self._toLobbyRect.x, self._toLobbyRect.y, self._toLobbyRect.w, self._toLobbyRect.h) then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function ResultScene:onMouseReleased(x, y, button, istouch, presses)
  return false
end

function ResultScene:_handleRematch()
  -- 규칙: 양쪽 모두 재대결이면 대기방으로, 아니면 둘 다 로비로
  if self._p1WantsRematch and self._p2WantsRematch then
    SceneManager:change("WaitingRoomScene", { isHost = true })
    return
  end

  SceneManager:change("LobbyScene")
end

return ResultScene
