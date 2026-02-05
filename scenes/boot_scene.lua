--[[
파일명: boot_scene.lua
모듈명: BootScene

역할:
- 부트 화면(로딩/초기화 연출 등)
- 짧게 표시 후 로비로 이동

외부에서 사용 가능한 함수:
- BootScene.new(params)
- BootScene:update(dt)
- BootScene:draw()

주의:
- 스켈레톤: 0.5초 후 자동 이동
]]
local BootScene = {}
BootScene.__index = BootScene

function BootScene.new(params)
  local self = setmetatable({}, BootScene)

  self.name = "BootScene"
  self._timerSec = 0
  self._durationSec = 0.5

  return self
end

function BootScene:update(dt)
  self._timerSec = self._timerSec + dt
  if self._timerSec >= self._durationSec then
    SceneManager:change("LobbyScene")
  end
end

function BootScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("로딩 중...", 0, 300, Config.WINDOW_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))
end

function BootScene:onKeyPressed(key, scancode, isrepeat)
  return false
end

function BootScene:onMousePressed(x, y, button, istouch, presses)
  return false
end

function BootScene:onMouseReleased(x, y, button, istouch, presses)
  return false
end

return BootScene
