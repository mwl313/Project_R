--[[
파일명: app.lua
모듈명: App

역할:
- 씬/오버레이를 묶어 업데이트/렌더/입력 라우팅
- SettingsManager 로드/저장/적용 관리
- NetClient(WS) 업데이트 및 이벤트 큐 관리
- 서버 기반 방 생성/참가 흐름 지원

외부에서 사용 가능한 함수:
- App.new()
- App:update(dt)
- App:draw()
- App:onKeyPressed(...)
- App:onTextInput(text)
- App:onTextEdited(text, start, length)
- App:onMousePressed(...)
- App:onMouseReleased(...)
- App:openNicknamePopup()
- App:openSettingsPopup()
- App:closeOverlay()
- App:getSettingsManager()
- App:getNetClient()
- App:pollNetEvent()

주의:
- Overlay 입력 우선 처리
]]
local OverlayManager = require("overlay_manager")
local Utils = require("utils")
local SettingsManager = require("settings_manager")
local NetClient = require("net_client")

local App = {}
App.__index = App

function App.new()
  local self = setmetatable({}, App)

  self._overlayManager = OverlayManager.new()
  self._settingsManager = SettingsManager.new()
  self._netClient = NetClient.new()

  self._mouseX = 0
  self._mouseY = 0

  self._settingsManager:load()
  self._settingsManager:applyDisplay()
  self._settingsManager:applyAudio()
  self._settingsManager:applyInput()

  -- playerId는 load 과정에서 없으면 생성되며, 여기서 확정적으로 확보
  self._settingsManager:getPlayerId()

  return self
end

function App:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()

  self._overlayManager:update(dt)

  self._netClient:update(dt)

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

function App:getNetClient()
  return self._netClient
end

function App:pollNetEvent()
  return self._netClient:poll()
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

  if not self._overlayManager:isOpen() then
    self:openSettingsPopup()
  end

  return true
end

return App
