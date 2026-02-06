--[[
파일명: render_scale.lua
모듈명: RenderScale

역할:
- 기준 해상도(BASE_WIDTH/BASE_HEIGHT) 기준으로 렌더 스케일 계산
- draw에서 스케일/오프셋 적용(begin/end)
- 입력 좌표를 스크린 -> 월드(기준 좌표)로 변환(toWorld)

외부에서 사용 가능한 함수:
- RenderScale.new()
- RenderScale:update()
- RenderScale:begin()
- RenderScale:endDraw()
- RenderScale:toWorld(screenX, screenY)
- RenderScale:isInViewport(screenX, screenY)

주의:
- 월드 좌표는 항상 "기준 해상도 좌표계(1280x720)"를 의미한다.
]]
local RenderScale = {}
RenderScale.__index = RenderScale

local function clampNumber(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

function RenderScale.new()
  local self = setmetatable({}, RenderScale)

  self._screenW = 0
  self._screenH = 0

  self._scale = 1
  self._offsetX = 0
  self._offsetY = 0

  self._viewportW = 0
  self._viewportH = 0

  self:update()

  return self
end

function RenderScale:update()
  local screenW, screenH = love.graphics.getDimensions()
  if self._screenW == screenW and self._screenH == screenH then
    return
  end

  self._screenW = screenW
  self._screenH = screenH

  local baseW = Config.BASE_WIDTH
  local baseH = Config.BASE_HEIGHT

  local scaleX = screenW / baseW
  local scaleY = screenH / baseH
  self._scale = math.min(scaleX, scaleY)

  self._viewportW = baseW * self._scale
  self._viewportH = baseH * self._scale

  self._offsetX = math.floor((screenW - self._viewportW) / 2)
  self._offsetY = math.floor((screenH - self._viewportH) / 2)
end

function RenderScale:begin()
  self:update()

  love.graphics.push()
  love.graphics.origin()

  love.graphics.translate(self._offsetX, self._offsetY)
  love.graphics.scale(self._scale, self._scale)
end

function RenderScale:endDraw()
  love.graphics.pop()
end

function RenderScale:isInViewport(screenX, screenY)
  self:update()

  local isInsideX = screenX >= self._offsetX and screenX <= (self._offsetX + self._viewportW)
  local isInsideY = screenY >= self._offsetY and screenY <= (self._offsetY + self._viewportH)
  return isInsideX and isInsideY
end

function RenderScale:toWorld(screenX, screenY)
  self:update()

  local localX = (screenX - self._offsetX) / self._scale
  local localY = (screenY - self._offsetY) / self._scale

  local worldX = clampNumber(localX, 0, Config.BASE_WIDTH)
  local worldY = clampNumber(localY, 0, Config.BASE_HEIGHT)

  return worldX, worldY
end

return RenderScale
