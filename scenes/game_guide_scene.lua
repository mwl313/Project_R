--[[
파일명: game_guide_scene.lua
모듈명: GameGuideScene

역할:
- 게임 설명 화면(현재 버전: 빈 페이지 진입만 구현)
- 로비로 복귀 제공

외부에서 사용 가능한 함수:
- GameGuideScene.new(params)
- GameGuideScene:update(dt)
- GameGuideScene:draw()
- GameGuideScene:onKeyPressed(key, scancode, isrepeat)
- GameGuideScene:onMousePressed(x, y, button, istouch, presses)
- GameGuideScene:onMouseReleased(x, y, button, istouch, presses)

주의:
- 내용은 추후 채워넣음
]]
local Utils = require("utils")

local GameGuideScene = {}
GameGuideScene.__index = GameGuideScene

function GameGuideScene.new(params)
  local self = setmetatable({}, GameGuideScene)

  self.name = "GameGuideScene"

  self._mouseX = 0
  self._mouseY = 0

  self._backRect = { x = 80, y = 600, w = 260, h = 52 }

  return self
end

function GameGuideScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
end

function GameGuideScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("게임 설명", 0, 50, Config.WINDOW_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))

  love.graphics.printf("현재 버전에서는 빈 페이지 진입만 구현합니다.\n(추후: 규칙/초능력/맵 리스트 안내)", 80, 160, 1000, "left")

  local isBackHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._backRect.x, self._backRect.y, self._backRect.w, self._backRect.h)
  Utils.drawButton({ x = self._backRect.x, y = self._backRect.y, w = self._backRect.w, h = self._backRect.h }, "로비로", isBackHovered)

  love.graphics.setFont(Assets:getFont("small"))
  love.graphics.print("단축키: Esc=로비", 80, 650)
  love.graphics.setFont(Assets:getFont("default"))
end

function GameGuideScene:onKeyPressed(key, scancode, isrepeat)
  if key == "escape" then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function GameGuideScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if Utils.isPointInRect(x, y, self._backRect.x, self._backRect.y, self._backRect.w, self._backRect.h) then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function GameGuideScene:onMouseReleased(x, y, button, istouch, presses)
  return false
end

return GameGuideScene
