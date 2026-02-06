--[[
파일명: main.lua
모듈명: (entry)

역할:
- LÖVE 콜백 진입점
- 전역(App/Assets/Config/SceneManager) 초기화
- 씬/오버레이 업데이트 및 렌더링 위임

외부에서 사용 가능한 함수:
- love.load()
- love.update(dt)
- love.draw()
- love.keypressed(key, scancode, isrepeat)
- love.mousepressed(x, y, button, istouch, presses)
- love.mousereleased(x, y, button, istouch, presses)

주의:
- 전역은 App/Assets/Config/SceneManager만 사용
]]
local AppModule = require("app")
local AssetsModule = require("assets")
local ConfigModule = require("config")
local SceneManagerModule = require("scene_manager")

function love.load()
  Config = ConfigModule

  -- 저장 폴더명(project_r) 고정 (settings.ini 포함)
  love.filesystem.setIdentity(Config.SAVE_IDENTITY)

  -- 기본 세팅(초기 윈도우: 1280x720)
  love.window.setMode(Config.WINDOW_WIDTH, Config.WINDOW_HEIGHT, { resizable = false, fullscreen = false })
  love.window.setTitle("알까기 (UI 스켈레톤)")
  love.graphics.setDefaultFilter("nearest", "nearest")

  Assets = AssetsModule.new()
  SceneManager = SceneManagerModule.new()

  App = AppModule.new()

  -- 폰트 로드 (한글 깨짐 방지)
  Assets:loadFonts()

  SceneManager:change("BootScene")
end

function love.update(dt)
  App:update(dt)
end

function love.draw()
  App:draw()
end

function love.keypressed(key, scancode, isrepeat)
  App:onKeyPressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button, istouch, presses)
  App:onMousePressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
  App:onMouseReleased(x, y, button, istouch, presses)
end
