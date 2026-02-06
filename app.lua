--[[
파일명: app.lua
모듈명: App

역할:
- 씬/오버레이를 묶어 업데이트/렌더/입력 라우팅
- 환경설정 버튼(우상단 고정) 접근 가능한 씬에서만 표시/동작
- SettingsManager 로드/저장/적용 관리

외부에서 사용 가능한 함수:
- App.new()
- App:update(dt)
- App:draw()
- App:onKeyPressed(...)
- App:onMousePressed(...)
- App:onMouseReleased(...)
- App:openNicknamePopup()
- App:openSettingsPopup()
- App:closeOverlay()
- App:getSettingsManager()

주의:
- Overlay 입력 우선 처리
]]
local OverlayManager = require("overlay_manager")
local Utils = require("utils")
local SettingsManager = require("settings_manager")

local App = {}
App.__index = App

function App.new()
  local self = setmetatable({}, App)

  self._overlayManager = OverlayManager.new()
  self._settingsManager = SettingsManager.new()

  self._mouseX = 0
  self._mouseY = 0

  -- settings.ini 로드 및 초기 적용
  self._settingsManager:load()
  self._settingsManager:applyDisplay()
  self._settingsManager:applyAudio()
  self._settingsManager:applyInput()

  return self
end

function App:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()

  self._overlayManager:update(dt)
  SceneManager:update(dt)
end

function App:draw()
  SceneManager:draw()

  self:_drawSettingsButtonIfAllowed()
  self._overlayManager:draw()
end

function App:onKeyPressed(key, scancode, isrepeat)
  if self._overlayManager:isOpen() then
    local isHandled = self._overlayManager:onKeyPressed(key, scancode, isrepeat)
    if isHandled then
      return true
    end
  end

  return SceneManager:onKeyPressed(key, scancode, isrepeat)
end

function App:onMousePressed(x, y, button, istouch, presses)
  if self._overlayManager:isOpen() then
    local isHandled = self._overlayManager:onMousePressed(x, y, button, istouch, presses)
    if isHandled then
      return true
    end
  end

  if self:_isSettingsAllowedInCurrentScene() then
    if self:_handleSettingsButtonClick(x, y, button) then
      return true
    end
  end

  return SceneManager:onMousePressed(x, y, button, istouch, presses)
end

function App:onMouseReleased(x, y, button, istouch, presses)
  if self._overlayManager:isOpen() then
    local isHandled = self._overlayManager:onMouseReleased(x, y, button, istouch, presses)
    if isHandled then
      return true
    end
  end

  return SceneManager:onMouseReleased(x, y, button, istouch, presses)
end

function App:openNicknamePopup()
  self._overlayManager:open("NicknameOverlay", {})
end

function App:openSettingsPopup()
  self._overlayManager:open("SettingsOverlay", { settingsManager = self._settingsManager })
end

function App:closeOverlay()
  self._overlayManager:close()
end

function App:getSettingsManager()
  return self._settingsManager
end

function App:_isSettingsAllowedInCurrentScene()
  local currentName = self:_getCurrentSceneName()
  return currentName == "LobbyScene" or currentName == "WaitingRoomScene" or currentName == "MatchScene"
end

function App:_getCurrentSceneName()
  local currentScene = SceneManager._current
  if not currentScene then
    return ""
  end

  return currentScene.name or ""
end

function App:_drawSettingsButtonIfAllowed()
  if not self:_isSettingsAllowedInCurrentScene() then
    return
  end

  local rect = {
    x = Config.SETTINGS_BUTTON_X,
    y = Config.SETTINGS_BUTTON_Y,
    w = Config.SETTINGS_BUTTON_W,
    h = Config.SETTINGS_BUTTON_H,
  }

  local isHovered = Utils.isPointInRect(self._mouseX, self._mouseY, rect.x, rect.y, rect.w, rect.h)
  Utils.drawButton(rect, "환경설정", isHovered)
end

function App:_handleSettingsButtonClick(x, y, button)
  if button ~= 1 then
    return false
  end

  local rx, ry, rw, rh = Config.SETTINGS_BUTTON_X, Config.SETTINGS_BUTTON_Y, Config.SETTINGS_BUTTON_W, Config.SETTINGS_BUTTON_H
  if not Utils.isPointInRect(x, y, rx, ry, rw, rh) then
    return false
  end

  -- 환경설정은 토글이 아니라 "열기"로 고정 (이탈 방지: 배경 클릭 닫기 금지)
  if not self._overlayManager:isOpen() then
    self:openSettingsPopup()
  end

  return true
end

return App
