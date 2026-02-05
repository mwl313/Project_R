--[[
파일명: nickname_overlay.lua
모듈명: NicknameOverlay

역할:
- 닉네임 변경 팝업 UI 스켈레톤
- 실제 텍스트 입력 처리는 추후 구현(지금은 더미)

외부에서 사용 가능한 함수:
- NicknameOverlay.new(params)
- NicknameOverlay:update(dt)
- NicknameOverlay:draw()
- NicknameOverlay:onKeyPressed(...)
- NicknameOverlay:onMousePressed(...)
- NicknameOverlay:onMouseReleased(...)

주의:
- 텍스트 입력은 love.textinput / IME 대응을 나중에 붙임
]]
local Utils = require("utils")

local NicknameOverlay = {}
NicknameOverlay.__index = NicknameOverlay

function NicknameOverlay.new(params)
  local self = setmetatable({}, NicknameOverlay)

  self._rect = { x = 380, y = 220, w = 520, h = 280 }
  self._closeRect = { x = 380 + 520 - 120, y = 220 + 20, w = 90, h = 36 }
  self._saveRect = { x = 380 + 520 - 220, y = 220 + 220, w = 190, h = 40 }

  self._mouseX = 0
  self._mouseY = 0

  return self
end

function NicknameOverlay:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
end

function NicknameOverlay:draw()
  love.graphics.rectangle("fill", 0, 0, Config.WINDOW_WIDTH, Config.WINDOW_HEIGHT)
  love.graphics.setColor(1, 1, 1, 1)

  Utils.drawPanel(self._rect, "닉네임 변경")

  love.graphics.printf("입력 UI는 스켈레톤 단계입니다.\n(추후 텍스트 입력/검증/저장 구현)", self._rect.x + 40, self._rect.y + 90, self._rect.w - 80, "left")

  local isCloseHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._closeRect.x, self._closeRect.y, self._closeRect.w, self._closeRect.h)
  Utils.drawButton({ x = self._closeRect.x, y = self._closeRect.y, w = self._closeRect.w, h = self._closeRect.h }, "닫기", isCloseHovered)

  local isSaveHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._saveRect.x, self._saveRect.y, self._saveRect.w, self._saveRect.h)
  Utils.drawButton({ x = self._saveRect.x, y = self._saveRect.y, w = self._saveRect.w, h = self._saveRect.h }, "저장(더미)", isSaveHovered)
end

function NicknameOverlay:onKeyPressed(key, scancode, isrepeat)
  if key == "escape" then
    App:closeOverlay()
    return true
  end

  return false
end

function NicknameOverlay:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return true
  end

  if Utils.isPointInRect(x, y, self._closeRect.x, self._closeRect.y, self._closeRect.w, self._closeRect.h) then
    App:closeOverlay()
    return true
  end

  if Utils.isPointInRect(x, y, self._saveRect.x, self._saveRect.y, self._saveRect.w, self._saveRect.h) then
    -- 스켈레톤: 저장 로직은 나중에
    App:closeOverlay()
    return true
  end

  if not Utils.isPointInRect(x, y, self._rect.x, self._rect.y, self._rect.w, self._rect.h) then
    App:closeOverlay()
    return true
  end

  return true
end

function NicknameOverlay:onMouseReleased(x, y, button, istouch, presses)
  return true
end

return NicknameOverlay
