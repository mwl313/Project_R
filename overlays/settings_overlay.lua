--[[
파일명: settings_overlay.lua
모듈명: SettingsOverlay

역할:
- 환경설정 팝업 UI
- 디스플레이 프리셋(창모드 고정 1280x720 + 전체화면 3종)
- 볼륨(BGM/SFX), 마우스 감도 슬라이더
- 저장/취소 버튼
- settings.ini 저장 및 적용

외부에서 사용 가능한 함수:
- SettingsOverlay.new(params)
- SettingsOverlay:update(dt)
- SettingsOverlay:draw()
- SettingsOverlay:onKeyPressed(...)
- SettingsOverlay:onMousePressed(...)
- SettingsOverlay:onMouseReleased(...)

주의:
- 오버레이 바깥 클릭으로 닫히지 않도록(이탈 방지)
- 디스플레이 변경은 저장 버튼에서만 반영
]]
local Utils = require("utils")

local SettingsOverlay = {}
SettingsOverlay.__index = SettingsOverlay

local function clampNumber(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function roundNumber(value)
  return math.floor(value + 0.5)
end

function SettingsOverlay.new(params)
  local self = setmetatable({}, SettingsOverlay)

  self._settingsManager = params.settingsManager

  self._mouseX = 0
  self._mouseY = 0

  local screenW, screenH = love.graphics.getDimensions()
  self._screenW = screenW
  self._screenH = screenH

  self._panelW = math.floor(screenW * Config.OVERLAY_PANEL_SCALE)
  self._panelH = math.floor(screenH * Config.OVERLAY_PANEL_SCALE)
  self._panelX = math.floor((screenW - self._panelW) / 2)
  self._panelY = math.floor((screenH - self._panelH) / 2)

  self._panelRect = { x = self._panelX, y = self._panelY, w = self._panelW, h = self._panelH }

  self._contentW = math.floor(self._panelW * 0.80)
  self._contentX = math.floor(self._panelX + (self._panelW - self._contentW) / 2)

  self._labelW = math.floor(self._contentW * 0.30)
  self._controlW = math.floor(self._contentW * 0.55)
  self._valueW = self._contentW - self._labelW - self._controlW

  self._labelX = self._contentX
  self._controlX = self._labelX + self._labelW
  self._valueX = self._controlX + self._controlW

  self._rowH = 56
  self._rowGap = 16
  self._rowCount = 4

  local rowsTotalH = self._rowCount * self._rowH + (self._rowCount - 1) * self._rowGap
  self._rowsStartY = math.floor(self._panelY + (self._panelH - rowsTotalH) / 2)

  self._titleY = self._panelY + 16

  self._buttonsY = self._panelY + self._panelH - 84
  self._buttonW = 160
  self._buttonH = 48
  self._buttonGap = 16

  self._saveRect = {
    x = self._panelX + self._panelW - (self._buttonW * 2 + self._buttonGap) - 24,
    y = self._buttonsY,
    w = self._buttonW,
    h = self._buttonH,
  }

  self._cancelRect = {
    x = self._saveRect.x + self._buttonW + self._buttonGap,
    y = self._buttonsY,
    w = self._buttonW,
    h = self._buttonH,
  }

  self._pending = self._settingsManager:copyAppliedAsPending()

  self._draggingSliderKey = nil

  return self
end

function SettingsOverlay:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
end

function SettingsOverlay:draw()
  -- 뒤 화면 보이도록 딤 처리
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, self._screenW, self._screenH)
  love.graphics.setColor(1, 1, 1, 1)

  -- 패널 본문
  love.graphics.setColor(0.06, 0.06, 0.06, 0.92)
  love.graphics.rectangle("fill", self._panelX, self._panelY, self._panelW, self._panelH)
  love.graphics.setColor(1, 1, 1, 1)

  -- 파란색 border
  love.graphics.setColor(0.20, 0.55, 1.00, 1.00)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", self._panelX, self._panelY, self._panelW, self._panelH)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, 1)

  -- 제목
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("환경설정", self._panelX, self._titleY, self._panelW, "center")
  love.graphics.setFont(Assets:getFont("default"))

  -- 행 렌더
  self:_drawDisplayRow(1)
  self:_drawSliderRow(2, "BGM 볼륨", "bgmVolumePercent", self._pending.bgmVolumePercent)
  self:_drawSliderRow(3, "SFX 볼륨", "sfxVolumePercent", self._pending.sfxVolumePercent)
  self:_drawSliderRow(4, "마우스 감도", "mouseSensitivityPercent", self._pending.mouseSensitivityPercent)

  -- 저장/취소 버튼
  local isSaveHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._saveRect.x, self._saveRect.y, self._saveRect.w, self._saveRect.h)
  Utils.drawButton(self._saveRect, "저장", isSaveHovered)

  local isCancelHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._cancelRect.x, self._cancelRect.y, self._cancelRect.w, self._cancelRect.h)
  Utils.drawButton(self._cancelRect, "취소", isCancelHovered)

  -- 저장 위치 표시(디버깅용)
  love.graphics.setFont(Assets:getFont("small"))
  local saveDir = self._settingsManager:getSaveDirectory()
  local line = "설정 파일 위치: " .. saveDir .. "/" .. Config.SETTINGS_FILE_NAME
  love.graphics.printf(line, self._panelX + 24, self._panelY + self._panelH - 30, self._panelW - 48, "left")
  love.graphics.setFont(Assets:getFont("default"))
end

function SettingsOverlay:onKeyPressed(key, scancode, isrepeat)
  -- 이탈 방지 우선: Esc는 "취소"로만 동작
  if key == "escape" then
    App:closeOverlay()
    return true
  end

  if key == "left" then
    self:_moveDisplayPreset(-1)
    return true
  end

  if key == "right" then
    self:_moveDisplayPreset(1)
    return true
  end

  return false
end

function SettingsOverlay:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return true
  end

  -- 버튼 처리
  if Utils.isPointInRect(x, y, self._saveRect.x, self._saveRect.y, self._saveRect.w, self._saveRect.h) then
    self:_handleSave()
    return true
  end

  if Utils.isPointInRect(x, y, self._cancelRect.x, self._cancelRect.y, self._cancelRect.w, self._cancelRect.h) then
    App:closeOverlay()
    return true
  end

  -- 패널 내부 클릭만 허용(바깥 클릭으로 닫히지 않음)
  local isInsidePanel = Utils.isPointInRect(x, y, self._panelRect.x, self._panelRect.y, self._panelRect.w, self._panelRect.h)
  if not isInsidePanel then
    return true
  end

  -- 디스플레이 프리셋 좌우 버튼
  if self:_handleDisplayRowClick(x, y) then
    return true
  end

  -- 슬라이더 클릭 점프 + 드래그 시작
  local sliderKey = self:_hitTestSlider(x, y)
  if sliderKey then
    self._draggingSliderKey = sliderKey
    self:_setSliderByMouse(sliderKey, x)
    return true
  end

  return true
end

function SettingsOverlay:onMouseReleased(x, y, button, istouch, presses)
  if button == 1 then
    self._draggingSliderKey = nil
    return true
  end

  return true
end

function SettingsOverlay:_handleSave()
  -- pending -> applied 커밋
  self._settingsManager:commitPending(self._pending)

  -- 적용(해상도/전체화면은 저장 시점에만)
  self._settingsManager:applyDisplay()
  self._settingsManager:applyAudio()
  self._settingsManager:applyInput()

  -- 저장
  self._settingsManager:save()

  -- 환경설정 닫기
  App:closeOverlay()
end

function SettingsOverlay:_rowY(rowIndex)
  return self._rowsStartY + (rowIndex - 1) * (self._rowH + self._rowGap)
end

function SettingsOverlay:_drawDisplayRow(rowIndex)
  local y = self:_rowY(rowIndex)

  -- 라벨
  love.graphics.printf("화면 설정", self._labelX, y + 14, self._labelW, "left")

  -- 컨트롤 영역: 좌/우 버튼 + 현재 선택 라벨
  local controlRect = { x = self._controlX, y = y, w = self._controlW, h = self._rowH }

  local arrowW = 44
  local leftRect = { x = controlRect.x, y = controlRect.y + 8, w = arrowW, h = controlRect.h - 16 }
  local rightRect = { x = controlRect.x + controlRect.w - arrowW, y = controlRect.y + 8, w = arrowW, h = controlRect.h - 16 }
  local labelRect = { x = leftRect.x + leftRect.w + 8, y = controlRect.y + 8, w = controlRect.w - (arrowW * 2 + 16), h = controlRect.h - 16 }

  local isLeftHovered = Utils.isPointInRect(self._mouseX, self._mouseY, leftRect.x, leftRect.y, leftRect.w, leftRect.h)
  Utils.drawButton(leftRect, "<", isLeftHovered)

  local isRightHovered = Utils.isPointInRect(self._mouseX, self._mouseY, rightRect.x, rightRect.y, rightRect.w, rightRect.h)
  Utils.drawButton(rightRect, ">", isRightHovered)

  love.graphics.rectangle("line", labelRect.x, labelRect.y, labelRect.w, labelRect.h)
  local preset = Config.DISPLAY_PRESETS[self._pending.displayPresetIndex]
  love.graphics.printf(preset.label, labelRect.x + 8, labelRect.y + 12, labelRect.w - 16, "center")

  -- 우측 value 칼럼은 비움(퍼센트 없음)
end

function SettingsOverlay:_handleDisplayRowClick(x, y)
  local rowY = self:_rowY(1)
  local controlX = self._controlX
  local controlY = rowY
  local controlW = self._controlW
  local controlH = self._rowH

  local arrowW = 44
  local leftRect = { x = controlX, y = controlY + 8, w = arrowW, h = controlH - 16 }
  local rightRect = { x = controlX + controlW - arrowW, y = controlY + 8, w = arrowW, h = controlH - 16 }

  if Utils.isPointInRect(x, y, leftRect.x, leftRect.y, leftRect.w, leftRect.h) then
    self:_moveDisplayPreset(-1)
    return true
  end

  if Utils.isPointInRect(x, y, rightRect.x, rightRect.y, rightRect.w, rightRect.h) then
    self:_moveDisplayPreset(1)
    return true
  end

  return false
end

function SettingsOverlay:_moveDisplayPreset(direction)
  local nextIndex = self._pending.displayPresetIndex + direction
  if nextIndex < 1 then
    nextIndex = #Config.DISPLAY_PRESETS
  end
  if nextIndex > #Config.DISPLAY_PRESETS then
    nextIndex = 1
  end

  self._pending.displayPresetIndex = nextIndex
end

function SettingsOverlay:_drawSliderRow(rowIndex, label, sliderKey, percentValue)
  local y = self:_rowY(rowIndex)

  -- 라벨
  love.graphics.printf(label, self._labelX, y + 14, self._labelW, "left")

  -- 슬라이더 컨트롤
  local sliderRect = self:_getSliderRectForRow(rowIndex)
  self:_drawSlider(sliderRect, percentValue)

  -- 우측 % 텍스트
  local percentText = tostring(percentValue) .. "%"
  love.graphics.printf(percentText, self._valueX, y + 14, self._valueW, "left")
end

function SettingsOverlay:_getSliderRectForRow(rowIndex)
  local y = self:_rowY(rowIndex)

  local sliderX = self._controlX
  local sliderY = y + 16
  local sliderW = self._controlW
  local sliderH = self._rowH - 32

  return { x = sliderX, y = sliderY, w = sliderW, h = sliderH }
end

function SettingsOverlay:_drawSlider(rect, percentValue)
  -- 트랙
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h)

  -- 채움
  local fillW = math.floor(rect.w * (percentValue / 100))
  love.graphics.rectangle("line", rect.x + 2, rect.y + 2, math.max(0, fillW - 4), rect.h - 4)

  -- 손잡이
  local thumbX = rect.x + fillW
  local thumbW = 10
  local thumbRect = {
    x = clampNumber(thumbX - math.floor(thumbW / 2), rect.x, rect.x + rect.w - thumbW),
    y = rect.y - 4,
    w = thumbW,
    h = rect.h + 8,
  }

  love.graphics.rectangle("line", thumbRect.x, thumbRect.y, thumbRect.w, thumbRect.h)
end

function SettingsOverlay:_hitTestSlider(x, y)
  local bgmRect = self:_getSliderRectForRow(2)
  if Utils.isPointInRect(x, y, bgmRect.x, bgmRect.y, bgmRect.w, bgmRect.h) then
    return "bgmVolumePercent"
  end

  local sfxRect = self:_getSliderRectForRow(3)
  if Utils.isPointInRect(x, y, sfxRect.x, sfxRect.y, sfxRect.w, sfxRect.h) then
    return "sfxVolumePercent"
  end

  local sensRect = self:_getSliderRectForRow(4)
  if Utils.isPointInRect(x, y, sensRect.x, sensRect.y, sensRect.w, sensRect.h) then
    return "mouseSensitivityPercent"
  end

  return nil
end

function SettingsOverlay:_setSliderByMouse(sliderKey, mouseX)
  local rowIndex = 2
  if sliderKey == "sfxVolumePercent" then
    rowIndex = 3
  end
  if sliderKey == "mouseSensitivityPercent" then
    rowIndex = 4
  end

  local rect = self:_getSliderRectForRow(rowIndex)
  local t = (mouseX - rect.x) / rect.w
  t = clampNumber(t, 0, 1)

  local percentValue = clampNumber(roundNumber(t * 100), 0, 100)
  self._pending[sliderKey] = percentValue
end

function SettingsOverlay:onMouseMoved(x, y, dx, dy, istouch)
  -- LÖVE 콜백에 연결하지 않았더라도, update에서 dragging 처리 가능.
  -- 현재 구조에서는 update에서 직접 처리하지 않으므로, 드래그는 mousepressed 후
  -- onMousePressed에서 시작되며, 아래 로직을 위해 update에서 확인한다.
end

function SettingsOverlay:_updateDragging()
  if not self._draggingSliderKey then
    return
  end

  self:_setSliderByMouse(self._draggingSliderKey, self._mouseX)
end

-- update에서 드래그 반영
local originalUpdate = SettingsOverlay.update
function SettingsOverlay:update(dt)
  originalUpdate(self, dt)
  self:_updateDragging()
end

return SettingsOverlay
