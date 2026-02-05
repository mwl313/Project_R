--[[
파일명: love2d.lua
모듈명: Love2d

역할:
- EmmyLua용 LÖVE2D API 스텁(자동완성/정적분석 목적)
- love 전역 및 하위 모듈(graphics/window/mouse/event 등) 타입/함수 시그니처 정의

외부에서 사용 가능한 함수:
- (실행용 모듈이 아님: require/return 사용하지 않음)
- love.* 심볼 힌트 제공 전용

주의:
- 이 파일은 런타임에서 실행되지 않는 "에디터 보조용"이다.
- 프로젝트 전역 사용 규칙과 무관하게, LÖVE의 love 전역을 예외적으로 선언한다.
- 필요해질 때마다 사용 중인 love API만 최소 단위로 추가/확장한다.
]]

---@meta

---@class love
love = love or {}

---@class love.graphics
love.graphics = love.graphics or {}

---@class love.window
love.window = love.window or {}

---@class love.mouse
love.mouse = love.mouse or {}

---@class love.event
love.event = love.event or {}

---@class love.system
love.system = love.system or {}

---@class love.timer
love.timer = love.timer or {}

---@class love.filesystem
love.filesystem = love.filesystem or {}

---@class love.Font
local Font = {}

---@alias LoveAlign
---|"left"
---|"center"
---|"right"
local LoveAlign = "left"

---@alias LoveDrawMode
---|"fill"
---|"line"
local LoveDrawMode = "line"

---@alias LoveFilterMode
---|"nearest"
---|"linear"
local LoveFilterMode = "nearest"

---@class LoveWindowFlags
---@field resizable boolean|nil
---@field fullscreen boolean|nil
---@field fullscreentype string|nil
---@field vsync number|nil
---@field msaa number|nil
---@field highdpi boolean|nil
---@field usedpiscale boolean|nil

-- =========================
-- love.graphics
-- =========================

---@param path string
---@param size number|nil
---@return love.Font
function love.graphics.newFont(path, size) return Font end

---@param font love.Font
function love.graphics.setFont(font) end

---@param text string
---@param x number
---@param y number
function love.graphics.print(text, x, y) end

---@param text string
---@param x number
---@param y number
---@param limit number
---@param align LoveAlign|nil
function love.graphics.printf(text, x, y, limit, align) end

---@param mode LoveDrawMode
---@param x number
---@param y number
---@param w number
---@param h number
function love.graphics.rectangle(mode, x, y, w, h) end

---@param r number
---@param g number
---@param b number
---@param a number|nil
function love.graphics.setColor(r, g, b, a) end

---@param min LoveFilterMode
---@param mag LoveFilterMode
function love.graphics.setDefaultFilter(min, mag) end

-- =========================
-- love.window
-- =========================

---@param width number
---@param height number
---@param flags LoveWindowFlags|nil
---@return boolean isSuccess
function love.window.setMode(width, height, flags) return true end

---@param title string
function love.window.setTitle(title) end

-- =========================
-- love.mouse
-- =========================

---@return number x
---@return number y
function love.mouse.getPosition() return 0, 0 end

-- =========================
-- love.event
-- =========================

function love.event.quit() end

-- =========================
-- love.system
-- =========================

---@param text string
function love.system.setClipboardText(text) end

---@return string text
function love.system.getClipboardText() return "" end

-- =========================
-- love.timer
-- =========================

---@return number fps
function love.timer.getFPS() return 60 end

-- =========================
-- love.filesystem
-- =========================

---@param filename string
---@return boolean isSuccess
function love.filesystem.createDirectory(filename) return true end

---@param filename string
---@return boolean isSuccess
function love.filesystem.remove(filename) return true end

---@param filename string
---@return boolean isExists
function love.filesystem.getInfo(filename) return false end
