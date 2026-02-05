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
  -- 기본 세팅
  love.window.setMode(ConfigModule.WINDOW_WIDTH, ConfigModule.WINDOW_HEIGHT, { resizable = false })
  love.window.setTitle("알까기 (UI 스켈레톤)")
  love.graphics.setDefaultFilter("nearest", "nearest")

  -- 전역 초기화 (허용 전역만 사용)
  Config = ConfigModule
  Assets = AssetsModule.new()
  SceneManager = SceneManagerModule.new()

  App = AppModule.new()

  -- 폰트 로드 (한글 깨짐 방지)
  Assets:loadFonts()

  -- 부트 → 로비로 자연 전환(스켈레톤)
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
