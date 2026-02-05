--[[
파일명: skin_change_scene.lua
모듈명: SkinChangeScene

역할:
- 스킨 변경 화면(현재 버전: 빈 페이지 진입만 구현)
- 로비로 복귀 제공

외부에서 사용 가능한 함수:
- SkinChangeScene.new(params)
- SkinChangeScene:update(dt)
- SkinChangeScene:draw()
- SkinChangeScene:onKeyPressed(key, scancode, isrepeat)
- SkinChangeScene:onMousePressed(x, y, button, istouch, presses)
- SkinChangeScene:onMouseReleased(x, y, button, istouch, presses)

주의:
- 실제 스킨 적용/저장 로직은 후속 구현
]]
local Utils = require("utils")

local SkinChangeScene = {}
SkinChangeScene.__index = SkinChangeScene

function SkinChangeScene.new(params)
  local self = setmetatable({}, SkinChangeScene)

  self.name = "SkinChangeScene"

  self._mouseX = 0
  self._mouseY = 0

  self._backRect = { x = 80, y = 600, w = 260, h = 52 }

  return self
end

function SkinChangeScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
end

function SkinChangeScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("스킨 변경", 0, 50, Config.WINDOW_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))

  love.graphics.printf("현재 버전에서는 빈 페이지 진입만 구현합니다.\n(추후: 배경/알/카드 디자인 변경 UI)", 80, 160, 1000, "left")

  local isBackHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._backRect.x, self._backRect.y, self._backRect.w, self._backRect.h)
  Utils.drawButton({ x = self._backRect.x, y = self._backRect.y, w = self._backRect.w, h = self._backRect.h }, "로비로", isBackHovered)

  love.graphics.setFont(Assets:getFont("small"))
  love.graphics.print("단축키: Esc=로비", 80, 650)
  love.graphics.setFont(Assets:getFont("default"))
end

function SkinChangeScene:onKeyPressed(key, scancode, isrepeat)
  if key == "escape" then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function SkinChangeScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if Utils.isPointInRect(x, y, self._backRect.x, self._backRect.y, self._backRect.w, self._backRect.h) then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function SkinChangeScene:onMouseReleased(x, y, button, istouch, presses)
  return false
end

return SkinChangeScene
