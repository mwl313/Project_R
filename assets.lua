--[[
파일명: assets.lua
모듈명: Assets

역할:
- 폰트/이미지/사운드 등 리소스 로드 및 제공
- 한글 폰트 기본 적용

외부에서 사용 가능한 함수:
- Assets.new()
- Assets:loadFonts()
- Assets:getFont(name)

주의:
- 폰트 파일이 없으면 한글이 깨질 수 있음
]]
local Assets = {}
Assets.__index = Assets

function Assets.new()
  local self = setmetatable({}, Assets)

  self._fonts = {}

  return self
end

function Assets:loadFonts()
  self._fonts.default = love.graphics.newFont(Config.DEFAULT_FONT_PATH, Config.DEFAULT_FONT_SIZE)
  self._fonts.small = love.graphics.newFont(Config.DEFAULT_FONT_PATH, Config.SMALL_FONT_SIZE)
  self._fonts.title = love.graphics.newFont(Config.DEFAULT_FONT_PATH, Config.TITLE_FONT_SIZE)

  love.graphics.setFont(self._fonts.default)
end

function Assets:getFont(name)
  return self._fonts[name] or self._fonts.default
end

return Assets
