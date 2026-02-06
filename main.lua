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
- love.textinput(text)
- love.textedited(text, start, length)
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

  love.filesystem.setIdentity(Config.SAVE_IDENTITY)

  love.window.setMode(Config.WINDOW_WIDTH, Config.WINDOW_HEIGHT, { resizable = false, fullscreen = false })
  love.window.setTitle("알까기 (UI 스켈레톤)")
  love.graphics.setDefaultFilter("nearest", "nearest")

  Assets = AssetsModule.new()
  SceneManager = SceneManagerModule.new()

  App = AppModule.new()

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

function love.textinput(text)
  App:onTextInput(text)
end

function love.textedited(text, start, length)
  App:onTextEdited(text, start, length)
end

function love.mousepressed(x, y, button, istouch, presses)
  App:onMousePressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
  App:onMouseReleased(x, y, button, istouch, presses)
end
