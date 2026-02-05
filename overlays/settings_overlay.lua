--[[
파일명: settings_overlay.lua
모듈명: SettingsOverlay

역할:
- 환경설정 팝업 UI 스켈레톤
- ESC 또는 닫기 버튼으로 종료

외부에서 사용 가능한 함수:
- SettingsOverlay.new(params)
- SettingsOverlay:update(dt)
- SettingsOverlay:draw()
- SettingsOverlay:onKeyPressed(...)
- SettingsOverlay:onMousePressed(...)
- SettingsOverlay:onMouseReleased(...)

주의:
- 실제 옵션 저장/적용은 후속 구현
]]
local Utils = require("utils")

local SettingsOverlay = {}
SettingsOverlay.__index = SettingsOverlay

function SettingsOverlay.new(params)
  local self = setmetatable({}, SettingsOverlay)

  self._rect = { x = 340, y = 150, w = 600, h = 420 }
  self._closeRect = { x = 340 + 600 - 120, y = 150 + 20, w = 90, h = 36 }

  self._mouseX = 0
  self._mouseY = 0

  return self
end

function SettingsOverlay:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
end

function SettingsOverlay:draw()
  love.graphics.rectangle("fill", 0, 0, Config.WINDOW_WIDTH, Config.WINDOW_HEIGHT)
  love.graphics.setColor(1, 1, 1, 1)

  Utils.drawPanel(self._rect, "환경설정")

  love.graphics.setFont(Assets:getFont("default"))
  love.graphics.printf("※ 실제 옵션 적용은 추후 구현합니다.", self._rect.x, self._rect.y + 90, self._rect.w, "center")

  local isHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._closeRect.x, self._closeRect.y, self._closeRect.w, self._closeRect.h)
  Utils.drawButton({ x = self._closeRect.x, y = self._closeRect.y, w = self._closeRect.w, h = self._closeRect.h }, "닫기", isHovered)
end

function SettingsOverlay:onKeyPressed(key, scancode, isrepeat)
  if key == "escape" then
    App:closeOverlay()
    return true
  end

  return false
end

function SettingsOverlay:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return true
  end

  if Utils.isPointInRect(x, y, self._closeRect.x, self._closeRect.y, self._closeRect.w, self._closeRect.h) then
    App:closeOverlay()
    return true
  end

  -- 팝업 바깥 클릭 시 닫기(선택)
  if not Utils.isPointInRect(x, y, self._rect.x, self._rect.y, self._rect.w, self._rect.h) then
    App:closeOverlay()
    return true
  end

  return true
end

function SettingsOverlay:onMouseReleased(x, y, button, istouch, presses)
  return true
end

return SettingsOverlay
