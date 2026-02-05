--[[
파일명: match_scene.lua
모듈명: MatchScene

역할:
- 매치 단일 씬(UI 스켈레톤)
- Sub-State Flow를 일방통행으로 진행(뒤로가기 없음)
- 기권/이탈(더미) 발생 시 ResultScene으로 이동

외부에서 사용 가능한 함수:
- MatchScene.new(params)
- MatchScene:update(dt)
- MatchScene:draw()
- MatchScene:onKeyPressed(key, scancode, isrepeat)
- MatchScene:onMousePressed(x, y, button, istouch, presses)
- MatchScene:onMouseReleased(x, y, button, istouch, presses)

주의:
- 실제 물리/턴/네트워크는 후속 구현
]]
local Utils = require("utils")

local MatchScene = {}
MatchScene.__index = MatchScene

local SUB_STATES = {
  "DecideTurnOrder",
  "PlacementSelect",
  "PlacementReveal",
  "AbilitySelect",
  "Gameplay",
}

function MatchScene.new(params)
  local self = setmetatable({}, MatchScene)

  self.name = "MatchScene"

  self._mouseX = 0
  self._mouseY = 0

  self._subStateIndex = 1
  self._subStateName = SUB_STATES[self._subStateIndex]

  self._nextRect = { x = 80, y = 580, w = 260, h = 52 }
  self._surrenderRect = { x = 360, y = 580, w = 260, h = 52 }
  self._disconnectRect = { x = 640, y = 580, w = 340, h = 52 }

  self._turnInfo = "현재: 스켈레톤 진행"
  self._elapsedSec = 0

  return self
end

function MatchScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
  self._elapsedSec = self._elapsedSec + dt
end

function MatchScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("매치", 0, 30, Config.WINDOW_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))

  love.graphics.print("Sub-State(일방통행): " .. self._subStateName, 80, 110)
  love.graphics.print("설명: 아래 '다음 단계'로 순서대로만 진행됩니다.", 80, 140)

  love.graphics.print("보드/기물/카드 UI는 추후 구현(현재는 스켈레톤)", 80, 210)
  love.graphics.print("타이머(더미): " .. string.format("%.1f", self._elapsedSec) .. "초", 80, 240)

  local isNextHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._nextRect.x, self._nextRect.y, self._nextRect.w, self._nextRect.h)
  Utils.drawButton({ x = self._nextRect.x, y = self._nextRect.y, w = self._nextRect.w, h = self._nextRect.h }, "다음 단계", isNextHovered)

  local isSurrenderHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._surrenderRect.x, self._surrenderRect.y, self._surrenderRect.w, self._surrenderRect.h)
  Utils.drawButton({ x = self._surrenderRect.x, y = self._surrenderRect.y, w = self._surrenderRect.w, h = self._surrenderRect.h }, "기권(더미)", isSurrenderHovered)

  local isDisconnectHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._disconnectRect.x, self._disconnectRect.y, self._disconnectRect.w, self._disconnectRect.h)
  Utils.drawButton({ x = self._disconnectRect.x, y = self._disconnectRect.y, w = self._disconnectRect.w, h = self._disconnectRect.h }, "상대 이탈/튕김(더미)", isDisconnectHovered)

  love.graphics.setFont(Assets:getFont("small"))
  love.graphics.print("단축키: Space=다음 단계, Q=기권, D=상대 이탈(더미)", 80, 650)
  love.graphics.setFont(Assets:getFont("default"))
end

function MatchScene:onKeyPressed(key, scancode, isrepeat)
  if key == "space" then
    self:_goNext()
    return true
  end

  if key == "q" then
    self:_goResult("기권", "플레이어2 승리(더미)")
    return true
  end

  if key == "d" then
    self:_goResult("상대 이탈", "플레이어1 승리(더미)")
    return true
  end

  return false
end

function MatchScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if Utils.isPointInRect(x, y, self._nextRect.x, self._nextRect.y, self._nextRect.w, self._nextRect.h) then
    self:_goNext()
    return true
  end

  if Utils.isPointInRect(x, y, self._surrenderRect.x, self._surrenderRect.y, self._surrenderRect.w, self._surrenderRect.h) then
    self:_goResult("기권", "플레이어2 승리(더미)")
    return true
  end

  if Utils.isPointInRect(x, y, self._disconnectRect.x, self._disconnectRect.y, self._disconnectRect.w, self._disconnectRect.h) then
    self:_goResult("상대 이탈", "플레이어1 승리(더미)")
    return true
  end

  return false
end

function MatchScene:onMouseReleased(x, y, button, istouch, presses)
  return false
end

function MatchScene:_goNext()
  if self._subStateIndex < #SUB_STATES then
    self._subStateIndex = self._subStateIndex + 1
    self._subStateName = SUB_STATES[self._subStateIndex]
    return
  end

  -- Gameplay 다음은 결과로 (일방통행)
  self:_goResult("정상 종료", "승패 미결정(더미)")
end

function MatchScene:_goResult(reason, resultText)
  SceneManager:change("ResultScene", {
    reason = reason,
    resultText = resultText,
  })
end

return MatchScene
