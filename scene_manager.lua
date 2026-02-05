--[[
파일명: scene_manager.lua
모듈명: SceneManager

역할:
- 씬 생성/전환/업데이트/렌더링
- 현재 씬만 활성화 (스켈레톤)

외부에서 사용 가능한 함수:
- SceneManager.new()
- SceneManager:change(sceneName, params)
- SceneManager:update(dt)
- SceneManager:draw()
- SceneManager:onKeyPressed(...)
- SceneManager:onMousePressed(...)
- SceneManager:onMouseReleased(...)

주의:
- 씬 이름은 PascalCase + Scene 접미사 (예: LobbyScene)
]]
local SceneManager = {}
SceneManager.__index = SceneManager

function SceneManager.new()
  local self = setmetatable({}, SceneManager)

  self._current = nil
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

function SceneManager:change(sceneName, params)
  local SceneClass = self._scenes[sceneName]
  if not SceneClass then
    return
  end

  self._current = SceneClass.new(params or {})
end

function SceneManager:update(dt)
  if not self._current then
    return
  end

  self._current:update(dt)
end

function SceneManager:draw()
  if not self._current then
    return
  end

  self._current:draw()
end

function SceneManager:onKeyPressed(key, scancode, isrepeat)
  if not self._current then
    return false
  end

  return self._current:onKeyPressed(key, scancode, isrepeat)
end

function SceneManager:onMousePressed(x, y, button, istouch, presses)
  if not self._current then
    return false
  end

  return self._current:onMousePressed(x, y, button, istouch, presses)
end

function SceneManager:onMouseReleased(x, y, button, istouch, presses)
  if not self._current then
    return false
  end

  return self._current:onMouseReleased(x, y, button, istouch, presses)
end

return SceneManager
