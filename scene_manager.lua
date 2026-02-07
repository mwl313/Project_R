--[[
파일명: scene_manager.lua
모듈명: SceneManager

역할:
- 씬 생성/전환/수명주기 관리
- update/draw/입력 이벤트를 현재 씬으로 라우팅
- 씬 로딩 실패/규칙 불일치 시 원인을 숨기지 않고 표시(장기 안정성)

외부에서 사용 가능한 함수:
- SceneManager.new()
- SceneManager:change(sceneName, params)
- SceneManager:update(dt)
- SceneManager:draw()
- SceneManager:onKeyPressed(key, scancode, isrepeat)
- SceneManager:onTextInput(text)
- SceneManager:onTextEdited(text, start, length)
- SceneManager:onMousePressed(x, y, button, istouch, presses)
- SceneManager:onMouseReleased(x, y, button, istouch, presses)
- SceneManager:getCurrent()

주의:
- 씬 이름은 PascalCase + Scene 접미사 (예: LobbyScene)
- 파일 경로는 "scenes/<snake>_scene.lua" 규칙을 따른다.
]]
local SceneManager = {}
SceneManager.__index = SceneManager

local function _safeCall(scene, methodName, ...)
  if not scene then
    return false
  end

  local fn = scene[methodName]
  if type(fn) ~= "function" then
    return false
  end

  return fn(scene, ...)
end

local function _sceneNameToPath(sceneName)
  local snake = sceneName
  snake = string.gsub(snake, "Scene$", "")
  snake = string.gsub(snake, "([a-z0-9])([A-Z])", "%1_%2")
  snake = string.lower(snake)
  return "scenes/" .. snake .. "_scene"
end

local function _tryRequire(path)
  local ok, mod = pcall(require, path)
  if not ok then
    return nil, tostring(mod)
  end
  return mod, ""
end

function SceneManager.new()
  local self = setmetatable({}, SceneManager)

  self._current = nil
  self._currentName = ""
  self._lastError = ""

  return self
end

function SceneManager:getCurrent()
  return self._current
end

function SceneManager:change(sceneName, params)
  if self._current then
    _safeCall(self._current, "onExit")
  end

  local path = _sceneNameToPath(sceneName)
  local SceneClass, err = _tryRequire(path)
  if not SceneClass then
    self._current = nil
    self._currentName = ""
    self._lastError = "씬 로딩 실패: " .. path .. "\n" .. err
    print(self._lastError)
    return false
  end

  if type(SceneClass.new) ~= "function" then
    self._current = nil
    self._currentName = ""
    self._lastError = "씬 new() 누락: " .. path
    print(self._lastError)
    return false
  end

  local newScene = SceneClass.new(params or {})
  newScene.name = sceneName

  self._current = newScene
  self._currentName = sceneName
  self._lastError = ""

  _safeCall(self._current, "onEnter", params or {})

  return true
end

function SceneManager:update(dt)
  _safeCall(self._current, "update", dt)
end

function SceneManager:draw()
  if not self._current then
    love.graphics.setFont(Assets and Assets:getFont("default") or love.graphics.getFont())
    love.graphics.printf(
      "현재 씬이 없습니다.\n\n" .. (self._lastError ~= "" and self._lastError or "마지막 오류: 없음"),
      0,
      120,
      Config and Config.BASE_WIDTH or 1280,
      "center"
    )
    return
  end

  _safeCall(self._current, "draw")
end

function SceneManager:onKeyPressed(key, scancode, isrepeat)
  return _safeCall(self._current, "onKeyPressed", key, scancode, isrepeat) or false
end

function SceneManager:onTextInput(text)
  return _safeCall(self._current, "onTextInput", text) or false
end

function SceneManager:onTextEdited(text, start, length)
  return _safeCall(self._current, "onTextEdited", text, start, length) or false
end

function SceneManager:onMousePressed(x, y, button, istouch, presses)
  return _safeCall(self._current, "onMousePressed", x, y, button, istouch, presses) or false
end

function SceneManager:onMouseReleased(x, y, button, istouch, presses)
  return _safeCall(self._current, "onMouseReleased", x, y, button, istouch, presses) or false
end

return SceneManager
