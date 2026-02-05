--[[
파일명: utils.lua
모듈명: Utils

역할:
- UI 그리기/히트테스트 등의 공용 유틸 제공

외부에서 사용 가능한 함수:
- Utils.isPointInRect(x, y, rx, ry, rw, rh)
- Utils.drawButton(rect, label, isHovered)
- Utils.drawPanel(rect, title)

주의:
- UI 스켈레톤 목적: 디자인은 단순하게 유지
]]
local Utils = {}

function Utils.isPointInRect(x, y, rx, ry, rw, rh)
  return x >= rx and x <= (rx + rw) and y >= ry and y <= (ry + rh)
end

function Utils.drawButton(rect, label, isHovered)
  local rx, ry, rw, rh = rect.x, rect.y, rect.w, rect.h

  love.graphics.rectangle("line", rx, ry, rw, rh)
  if isHovered then
    love.graphics.rectangle("line", rx + 2, ry + 2, rw - 4, rh - 4)
  end

  love.graphics.printf(label, rx, ry + math.floor(rh / 2) - 10, rw, "center")
end

function Utils.drawPanel(rect, title)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf(title, rect.x, rect.y + 16, rect.w, "center")
  love.graphics.setFont(Assets:getFont("default"))
end

return Utils
