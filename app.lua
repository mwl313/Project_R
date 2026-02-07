--[[
파일명: app.lua
모듈명: App

역할:
- 씬/오버레이를 묶어 업데이트/렌더/입력 라우팅
- SettingsManager 로드/저장/적용 관리
- RenderScale 적용(월드 좌표 1280x720 고정 + 스크린 스케일링)
- Overlay 입력 우선 처리 후, SceneManager로 입력 전달
- NetManager 업데이트 및 제공(getNetManager)

외부에서 사용 가능한 함수:
- App.new()
- App:update(dt)
- App:draw()
- App:onKeyPressed(key, scancode, isrepeat)
- App:onTextInput(text)
- App:onTextEdited(text, start, length)
- App:onMousePressed(x, y, button, istouch, presses)
- App:onMouseReleased(x, y, button, istouch, presses)
- App:openNicknamePopup()
- App:openSettingsPopup()
- App:closeOverlay()
- App:getSettingsManager()
- App:getNetManager()

주의:
- Overlay 입력 우선 처리
- 마우스 좌표는 스크린->월드 변환 후 사용(해상도 무관)
- draw는 RenderScale.begin/endDraw 내부에서만 월드 좌표로 렌더
]]
local OverlayManager = require("overlay_manager")
local RenderScale = require("render_scale")
local SettingsManager = require("settings_manager")
local Utils = require("utils")
local NetManager = require("net.net_manager")

local App = {}
App.__index = App

function App.new()
  local self = setmetatable({}, App)

  self._overlayManager = OverlayManager.new()
  self._settingsManager = SettingsManager.new()
  self._renderScale = RenderScale.new()
  self._netManager = NetManager.new()

  self._mouseWorldX = 0
  self._mouseWorldY = 0

  self._settingsManager:load()
  self._settingsManager:applyDisplay()
  self._settingsManager:applyAudio()
  self._settingsManager:applyInput()

  return self
end

function App:update(dt)
  self._renderScale:update()

  local mx, my = love.mouse.getPosition()
  self._mouseWorldX, self._mouseWorldY = self._renderScale:toWorld(mx, my)

  self._netManager:update(dt)
  self._overlayManager:update(dt)
  SceneManager:update(dt)
end

function App:draw()
  self._renderScale:begin()

  SceneManager:draw()

  self:_drawSettingsButtonIfAllowed()
  self._overlayManager:draw()

  self._renderScale:endDraw()
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

function App:onTextInput(text)
  if self._overlayManager:isOpen() then
    local isHandled = self._overlayManager:onTextInput(text)
    if isHandled then
      return true
    end
  end

  return SceneManager:onTextInput(text)
end

function App:onTextEdited(text, start, length)
  if self._overlayManager:isOpen() then
    local isHandled = self._overlayManager:onTextEdited(text, start, length)
    if isHandled then
      return true
    end
  end

  return SceneManager:onTextEdited(text, start, length)
end

function App:onMousePressed(x, y, button, istouch, presses)
  local wx, wy = self._renderScale:toWorld(x, y)

  if self._overlayManager:isOpen() then
    local isHandled = self._overlayManager:onMousePressed(wx, wy, button, istouch, presses)
    if isHandled then
      return true
    end
  end

  if self:_isSettingsAllowedInCurrentScene() then
    if self:_handleSettingsButtonClick(wx, wy, button) then
      return true
    end
  end

  return SceneManager:onMousePressed(wx, wy, button, istouch, presses)
end

function App:onMouseReleased(x, y, button, istouch, presses)
  local wx, wy = self._renderScale:toWorld(x, y)

  if self._overlayManager:isOpen() then
    local isHandled = self._overlayManager:onMouseReleased(wx, wy, button, istouch, presses)
    if isHandled then
      return true
    end
  end

  return SceneManager:onMouseReleased(wx, wy, button, istouch, presses)
end

function App:openNicknamePopup()
  self._overlayManager:open("NicknameOverlay", { settingsManager = self._settingsManager })
end

function App:openSettingsPopup()
  self._overlayManager:open("SettingsOverlay", { settingsManager = self._settingsManager })
end

function App:closeOverlay()
  love.keyboard.setTextInput(false)
  self._overlayManager:close()
end

function App:getSettingsManager()
  return self._settingsManager
end

function App:getNetManager()
  return self._netManager
end

function App:_isSettingsAllowedInCurrentScene()
  local currentName = self:_getCurrentSceneName()
  return currentName == "LobbyScene" or currentName == "WaitingRoomScene" or currentName == "MatchScene"
end

function App:_getCurrentSceneName()
  local currentScene = SceneManager:getCurrent()
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

  local isHovered = Utils.isPointInRect(self._mouseWorldX, self._mouseWorldY, rect.x, rect.y, rect.w, rect.h)
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

  if not self._overlayManager:isOpen() then
    self:openSettingsPopup()
  end

  return true
end

return App
