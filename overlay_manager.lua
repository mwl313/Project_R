--[[
파일명: overlay_manager.lua
모듈명: OverlayManager

역할:
- 팝업(오버레이) 열기/닫기/입력 우선 처리
- 텍스트 입력(textinput) 및 IME 조합(textedited) 전달

외부에서 사용 가능한 함수:
- OverlayManager.new()
- OverlayManager:open(name, params)
- OverlayManager:close()
- OverlayManager:isOpen()
- OverlayManager:update(dt)
- OverlayManager:draw()
- OverlayManager:onKeyPressed(...)
- OverlayManager:onTextInput(text)
- OverlayManager:onTextEdited(text, start, length)
- OverlayManager:onMousePressed(...)
- OverlayManager:onMouseReleased(...)

주의:
- 오버레이가 열려있으면 입력은 오버레이가 우선 처리
]]
local OverlayManager = {}
OverlayManager.__index = OverlayManager

function OverlayManager.new()
  local self = setmetatable({}, OverlayManager)

  self._current = nil
  self._overlays = {
    SettingsOverlay = require("overlays/settings_overlay"),
    NicknameOverlay = require("overlays/nickname_overlay"),
  }

  return self
end

function OverlayManager:open(name, params)
  local OverlayClass = self._overlays[name]
  if not OverlayClass then
    return
  end

  self._current = OverlayClass.new(params or {})
end

function OverlayManager:close()
  self._current = nil
end

function OverlayManager:isOpen()
  return self._current ~= nil
end

function OverlayManager:update(dt)
  if not self._current then
    return
  end

  self._current:update(dt)
end

function OverlayManager:draw()
  if not self._current then
    return
  end

  self._current:draw()
end

function OverlayManager:onKeyPressed(key, scancode, isrepeat)
  if not self._current then
    return false
  end

  return self._current:onKeyPressed(key, scancode, isrepeat)
end

function OverlayManager:onTextInput(text)
  if not self._current then
    return false
  end

  if not self._current.onTextInput then
    return false
  end

  return self._current:onTextInput(text)
end

function OverlayManager:onTextEdited(text, start, length)
  if not self._current then
    return false
  end

  if not self._current.onTextEdited then
    return false
  end

  return self._current:onTextEdited(text, start, length)
end

function OverlayManager:onMousePressed(x, y, button, istouch, presses)
  if not self._current then
    return false
  end

  return self._current:onMousePressed(x, y, button, istouch, presses)
end

function OverlayManager:onMouseReleased(x, y, button, istouch, presses)
  if not self._current then
    return false
  end

  return self._current:onMouseReleased(x, y, button, istouch, presses)
end

return OverlayManager
