--[[
파일명: credits_scene.lua
모듈명: CreditsScene

역할:
- 제작자 & 버전 화면(UI 스켈레톤)
- 디스코드/메일 복사 버튼(현재는 더미)
- 로비로 복귀 제공

외부에서 사용 가능한 함수:
- CreditsScene.new(params)
- CreditsScene:update(dt)
- CreditsScene:draw()
- CreditsScene:onKeyPressed(key, scancode, isrepeat)
- CreditsScene:onMousePressed(x, y, button, istouch, presses)
- CreditsScene:onMouseReleased(x, y, button, istouch, presses)

주의:
- 실제 클립보드 복사는 love.system.setClipboardText로 후속 구현 가능
]]
local Utils = require("utils")

local CreditsScene = {}
CreditsScene.__index = CreditsScene

function CreditsScene.new(params)
  local self = setmetatable({}, CreditsScene)

  self.name = "CreditsScene"

  self._mouseX = 0
  self._mouseY = 0

  self._backRect = { x = 80, y = 600, w = 260, h = 52 }
  self._copyDiscordRect = { x = 520, y = 230, w = 140, h = 40 }
  self._copyEmailRect = { x = 520, y = 290, w = 140, h = 40 }

  self._discord = "Discord: (더미) alggaki-dev"
  self._email = "Email: (더미) dev@example.com"
  self._version = "버전: 0.0.0 (스켈레톤)"
  self._releaseDate = "릴리즈: 2026-02-05 (더미)"

  self._toastTimerSec = 0
  self._toastText = ""

  return self
end

function CreditsScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()

  if self._toastTimerSec > 0 then
    self._toastTimerSec = math.max(0, self._toastTimerSec - dt)
    if self._toastTimerSec == 0 then
      self._toastText = ""
    end
  end
end

function CreditsScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("제작자 & 버전", 0, 50, Config.WINDOW_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))

  love.graphics.print(self._version, 80, 140)
  love.graphics.print(self._releaseDate, 80, 170)

  love.graphics.print(self._discord, 80, 240)
  local isDiscordHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._copyDiscordRect.x, self._copyDiscordRect.y, self._copyDiscordRect.w, self._copyDiscordRect.h)
  Utils.drawButton({ x = self._copyDiscordRect.x, y = self._copyDiscordRect.y, w = self._copyDiscordRect.w, h = self._copyDiscordRect.h }, "복사(더미)", isDiscordHovered)

  love.graphics.print(self._email, 80, 300)
  local isEmailHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._copyEmailRect.x, self._copyEmailRect.y, self._copyEmailRect.w, self._copyEmailRect.h)
  Utils.drawButton({ x = self._copyEmailRect.x, y = self._copyEmailRect.y, w = self._copyEmailRect.w, h = self._copyEmailRect.h }, "복사(더미)", isEmailHovered)

  if self._toastText ~= "" then
    love.graphics.setFont(Assets:getFont("small"))
    love.graphics.print(self._toastText, 80, 360)
    love.graphics.setFont(Assets:getFont("default"))
  end

  local isBackHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._backRect.x, self._backRect.y, self._backRect.w, self._backRect.h)
  Utils.drawButton({ x = self._backRect.x, y = self._backRect.y, w = self._backRect.w, h = self._backRect.h }, "로비로", isBackHovered)

  love.graphics.setFont(Assets:getFont("small"))
  love.graphics.print("단축키: Esc=로비", 80, 650)
  love.graphics.setFont(Assets:getFont("default"))
end

function CreditsScene:onKeyPressed(key, scancode, isrepeat)
  if key == "escape" then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function CreditsScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if Utils.isPointInRect(x, y, self._copyDiscordRect.x, self._copyDiscordRect.y, self._copyDiscordRect.w, self._copyDiscordRect.h) then
    self:_showToast("디스코드 복사됨(더미)")
    return true
  end

  if Utils.isPointInRect(x, y, self._copyEmailRect.x, self._copyEmailRect.y, self._copyEmailRect.w, self._copyEmailRect.h) then
    self:_showToast("메일 복사됨(더미)")
    return true
  end

  if Utils.isPointInRect(x, y, self._backRect.x, self._backRect.y, self._backRect.w, self._backRect.h) then
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function CreditsScene:onMouseReleased(x, y, button, istouch, presses)
  return false
end

function CreditsScene:_showToast(text)
  self._toastText = text
  self._toastTimerSec = 1.2
end

return CreditsScene
