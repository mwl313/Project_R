--[[
파일명: scene_manager.lua
모듈명: SceneManager

역할:
- 씬 생성/전환/업데이트/렌더링
- 현재 씬만 활성화 (스켈레톤)
- 씬 전환 실패/미등록 상태를 "가시화"하여 디버깅 안정성 확보
- 텍스트 입력(onTextInput/onTextEdited) 라우팅 제공

외부에서 사용 가능한 함수:
- SceneManager.new()
- SceneManager:change(sceneName, params)
- SceneManager:update(dt)
- SceneManager:draw()
- SceneManager:onKeyPressed(...)
- SceneManager:onTextInput(text)
- SceneManager:onTextEdited(text, start, length)
- SceneManager:onMousePressed(...)
- SceneManager:onMouseReleased(...)
- SceneManager:getCurrentName()

주의:
- 씬 이름은 PascalCase + Scene 접미사 (예: LobbyScene)
- change 실패를 조용히 무시하지 않고 콘솔/화면에 표시한다.
]]
local SceneManager = {}
SceneManager.__index = SceneManager

local function _safeToString(value)
  if value == nil then
    return "nil"
  end
  return tostring(value)
end

local function _hasMethod(obj, methodName)
  return obj ~= nil and type(obj[methodName]) == "function"
end

function SceneManager.new()
  local self = setmetatable({}, SceneManager)

  self._current = nil
  self._currentName = ""
  self._lastError = ""

  self._scenes = {
    BootScene = require("scenes/boot_scene"),
    LobbyScene = require("scenes/lobby_scene"),
    RoomSearchScene = require("scenes/room_search_scene"),
    WaitingRoomScene = require("scenes/waiting_room_scene"),
    MatchScene = require("scenes/match_scene"),
    ResultScene = require("scenes/result_scene"),
    GameGuideScene = require("scenes/game_guide_scene"),
    SkinChangeScene = require("scenes/skin_change_scene"),
    CreditsScene = require("scenes/credits_scene"),
  }

  return self
end

function SceneManager:getCurrentName()
  if self._currentName and self._currentName ~= "" then
    return self._currentName
  end
  if self._current and self._current.name then
    return self._current.name
  end
  return ""
end

function SceneManager:change(sceneName, params)
  local SceneClass = self._scenes[sceneName]
  if not SceneClass then
    self._lastError = "SceneManager:change 실패 - 등록되지 않은 씬: " .. _safeToString(sceneName)
    print(self._lastError)
    return false
  end

  if type(SceneClass.new) ~= "function" then
    self._lastError = "SceneManager:change 실패 - 씬에 new()가 없음: " .. _safeToString(sceneName)
    print(self._lastError)
    return false
  end

  self._current = SceneClass.new(params or {})
  self._currentName = _safeToString(sceneName)
  self._lastError = ""

  return true
end

function SceneManager:update(dt)
  if not self._current then
    return
  end

  if _hasMethod(self._current, "update") then
    self._current:update(dt)
  end
end

function SceneManager:draw()
  if not self._current then
    -- 장기적 안정성: "검은 화면"일 때 원인을 화면에 표시
    love.graphics.setFont(Assets and Assets:getFont("default") or love.graphics.getFont())
    love.graphics.printf(
      "현재 씬이 없습니다.\n(main.lua에서 SceneManager:change(\"BootScene\")가 실패했을 가능성이 큽니다.)\n\n"
        .. (self._lastError ~= "" and ("마지막 오류:\n" .. self._lastError) or "마지막 오류: 없음"),
      0,
      120,
      Config and (Config.BASE_WIDTH or 1280) or 1280,
      "center"
    )
    return
  end

  if _hasMethod(self._current, "draw") then
    self._current:draw()
  end
end

function SceneManager:onKeyPressed(key, scancode, isrepeat)
  if not self._current then
    return false
  end

  if _hasMethod(self._current, "onKeyPressed") then
    return self._current:onKeyPressed(key, scancode, isrepeat)
  end

  return false
end

function SceneManager:onTextInput(text)
  if not self._current then
    return false
  end

  if _hasMethod(self._current, "onTextInput") then
    return self._current:onTextInput(text)
  end

  return false
end

function SceneManager:onTextEdited(text, start, length)
  if not self._current then
    return false
  end

  if _hasMethod(self._current, "onTextEdited") then
    return self._current:onTextEdited(text, start, length)
  end

  return false
end

function SceneManager:onMousePressed(x, y, button, istouch, presses)
  if not self._current then
    return false
  end

  if _hasMethod(self._current, "onMousePressed") then
    return self._current:onMousePressed(x, y, button, istouch, presses)
  end

  return false
end

function SceneManager:onMouseReleased(x, y, button, istouch, presses)
  if not self._current then
    return false
  end

  if _hasMethod(self._current, "onMouseReleased") then
    return self._current:onMouseReleased(x, y, button, istouch, presses)
  end

  return false
end

return SceneManager
