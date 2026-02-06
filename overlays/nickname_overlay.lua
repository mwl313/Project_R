--[[
파일명: nickname_overlay.lua
모듈명: NicknameOverlay

역할:
- 닉네임 변경 팝업 UI
- 입력: 한글/영문/숫자만, 2~15글자
- IME 조합(textedited) 표시로 "마지막 글자 안 보임" 문제 해결
- 커서(깜빡임) 표시

외부에서 사용 가능한 함수:
- NicknameOverlay.new(params)
- NicknameOverlay:update(dt)
- NicknameOverlay:draw()
- NicknameOverlay:onKeyPressed(...)
- NicknameOverlay:onTextInput(text)
- NicknameOverlay:onTextEdited(text, start, length)
- NicknameOverlay:onMousePressed(...)
- NicknameOverlay:onMouseReleased(...)

주의:
- 오버레이 바깥 클릭으로 닫히지 않도록(이탈 방지)
]]
local Utils = require("utils")
local utf8 = require("utf8")

local NicknameOverlay = {}
NicknameOverlay.__index = NicknameOverlay

local function _trim(text)
  if not text then
    return ""
  end
  return (string.match(text, "^%s*(.-)%s*$") or "")
end

local function clampNumber(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function _isAllowedNicknameCodepoint(codepoint)
  if codepoint >= 0x30 and codepoint <= 0x39 then
    return true
  end
  if codepoint >= 0x41 and codepoint <= 0x5A then
    return true
  end
  if codepoint >= 0x61 and codepoint <= 0x7A then
    return true
  end

  if codepoint >= 0x1100 and codepoint <= 0x11FF then
    return true
  end
  if codepoint >= 0x3130 and codepoint <= 0x318F then
    return true
  end
  if codepoint >= 0xAC00 and codepoint <= 0xD7A3 then
    return true
  end

  return false
end

local function _filterNickname(text)
  if not text or text == "" then
    return ""
  end

  local buffer = {}
  for _, codepoint in utf8.codes(text) do
    if _isAllowedNicknameCodepoint(codepoint) then
      table.insert(buffer, utf8.char(codepoint))
    end
  end

  return table.concat(buffer)
end

local function _getUtf8Len(text)
  local length = utf8.len(text)
  if not length then
    return 0
  end
  return length
end

function NicknameOverlay.new(params)
  local self = setmetatable({}, NicknameOverlay)

  self._settingsManager = params.settingsManager

  self._mouseX = 0
  self._mouseY = 0

  self._screenW = Config.WINDOW_WIDTH
  self._screenH = Config.WINDOW_HEIGHT

  self._panelW = math.floor(self._screenW * 0.50)
  self._panelH = math.floor(self._screenH * 0.50)
  self._panelX = math.floor((self._screenW - self._panelW) / 2)
  self._panelY = math.floor((self._screenH - self._panelH) / 2)

  self._panelRect = { x = self._panelX, y = self._panelY, w = self._panelW, h = self._panelH }

  self._inputW = math.floor(self._panelW * 0.70)
  self._inputH = 52
  self._inputX = math.floor(self._panelX + (self._panelW - self._inputW) / 2)

  self._buttonW = 180
  self._buttonH = 48
  self._buttonX = math.floor(self._panelX + (self._panelW - self._buttonW) / 2)

  local contentCenterY = math.floor(self._panelY + self._panelH / 2)
  self._inputY = contentCenterY - 40
  self._buttonY = self._inputY + self._inputH + 18

  self._inputRect = { x = self._inputX, y = self._inputY, w = self._inputW, h = self._inputH }
  self._changeRect = { x = self._buttonX, y = self._buttonY, w = self._buttonW, h = self._buttonH }

  self._inputText = ""
  self._errorText = ""
  self._isFocused = true

  -- IME 조합 텍스트(미확정)
  self._imeText = ""
  self._caretTime = 0

  if self._settingsManager then
    self._inputText = self._settingsManager:getNickname()
  end

  love.keyboard.setTextInput(true)

  return self
end

function NicknameOverlay:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
  self._caretTime = self._caretTime + dt
end

function NicknameOverlay:draw()
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, self._screenW, self._screenH)
  love.graphics.setColor(1, 1, 1, 1)

  love.graphics.setColor(0.06, 0.06, 0.06, 0.92)
  love.graphics.rectangle("fill", self._panelX, self._panelY, self._panelW, self._panelH)
  love.graphics.setColor(1, 1, 1, 1)

  love.graphics.setColor(0.20, 0.55, 1.00, 1.00)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", self._panelX, self._panelY, self._panelW, self._panelH)
  love.graphics.setLineWidth(1)
  love.graphics.setColor(1, 1, 1, 1)

  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("닉네임 변경", self._panelX, self._panelY + 16, self._panelW, "center")
  love.graphics.setFont(Assets:getFont("default"))

  love.graphics.setFont(Assets:getFont("small"))
  love.graphics.printf("한글/영문/숫자만 가능 (2~15글자)", self._panelX, self._inputY - 34, self._panelW, "center")
  love.graphics.setFont(Assets:getFont("default"))

  self:_drawInputBox()

  local isChangeHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._changeRect.x, self._changeRect.y, self._changeRect.w, self._changeRect.h)
  Utils.drawButton(self._changeRect, "변경", isChangeHovered)

  if self._errorText ~= "" then
    love.graphics.setColor(1, 0.35, 0.35, 1)
    love.graphics.setFont(Assets:getFont("small"))
    love.graphics.printf(self._errorText, self._panelX + 20, self._changeRect.y + self._changeRect.h + 10, self._panelW - 40, "center")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(Assets:getFont("default"))
  end
end

function NicknameOverlay:onKeyPressed(key, scancode, isrepeat)
  if key == "escape" then
    App:closeOverlay()
    return true
  end

  if key == "return" or key == "kpenter" then
    self:_tryApplyNickname()
    return true
  end

  if key == "backspace" then
    -- 조합 중이면 love.textedited가 갱신되므로 여기선 확정 텍스트만 지움
    if self._imeText ~= "" then
      return true
    end

    self._inputText = self:_removeLastChar(self._inputText)
    self._errorText = ""
    return true
  end

  return true
end

function NicknameOverlay:onTextInput(text)
  if not self._isFocused then
    return true
  end

  -- 확정 입력이 들어오면 조합 문자열은 비움
  self._imeText = ""

  local filtered = _filterNickname(text)
  if filtered == "" then
    return true
  end

  local currentLen = _getUtf8Len(self._inputText)
  local addLen = _getUtf8Len(filtered)

  local maxAdd = 15 - currentLen
  if maxAdd <= 0 then
    return true
  end

  if addLen > maxAdd then
    filtered = self:_takeFirstChars(filtered, maxAdd)
  end

  self._inputText = self._inputText .. filtered
  self._errorText = ""

  return true
end

function NicknameOverlay:onTextEdited(text, start, length)
  if not self._isFocused then
    return true
  end

  -- IME 조합 문자열 표시(미확정)
  local filtered = _filterNickname(text)
  self._imeText = filtered

  return true
end

function NicknameOverlay:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return true
  end

  local isInsidePanel = Utils.isPointInRect(x, y, self._panelRect.x, self._panelRect.y, self._panelRect.w, self._panelRect.h)
  if not isInsidePanel then
    return true
  end

  if Utils.isPointInRect(x, y, self._inputRect.x, self._inputRect.y, self._inputRect.w, self._inputRect.h) then
    self._isFocused = true
    love.keyboard.setTextInput(true)
    self._caretTime = 0
    return true
  end

  if Utils.isPointInRect(x, y, self._changeRect.x, self._changeRect.y, self._changeRect.w, self._changeRect.h) then
    self:_tryApplyNickname()
    return true
  end

  return true
end

function NicknameOverlay:onMouseReleased(x, y, button, istouch, presses)
  return true
end

function NicknameOverlay:_drawInputBox()
  local isHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._inputRect.x, self._inputRect.y, self._inputRect.w, self._inputRect.h)

  if self._isFocused or isHovered then
    love.graphics.setColor(0.20, 0.55, 1.00, 1.00)
  else
    love.graphics.setColor(1, 1, 1, 1)
  end

  love.graphics.rectangle("line", self._inputRect.x, self._inputRect.y, self._inputRect.w, self._inputRect.h)
  love.graphics.setColor(1, 1, 1, 1)

  local font = Assets:getFont("default")
  love.graphics.setFont(font)

  local drawX = self._inputRect.x + 12
  local drawY = self._inputRect.y + 14

  -- 확정 + 조합(미확정) 같이 표시
  local displayText = self._inputText .. self._imeText
  love.graphics.printf(displayText, drawX, drawY, self._inputRect.w - 24, "left")

  -- 커서(깜빡임): 포커스일 때만
  if self._isFocused then
    local isVisible = (math.floor(self._caretTime * 2) % 2) == 0
    if isVisible then
      local caretText = displayText
      local textW = font:getWidth(caretText)

      local caretX = clampNumber(drawX + textW + 2, drawX, self._inputRect.x + self._inputRect.w - 12)
      local caretTop = self._inputRect.y + 10
      local caretBottom = self._inputRect.y + self._inputRect.h - 10

      love.graphics.line(caretX, caretTop, caretX, caretBottom)
    end
  end
end

function NicknameOverlay:_tryApplyNickname()
  if not self._settingsManager then
    self._errorText = "설정 매니저가 없습니다."
    return
  end

  -- 조합 중이면 먼저 확정하도록 유도(간단 처리)
  if self._imeText ~= "" then
    self._errorText = "한글 입력을 확정한 뒤 변경해 주세요."
    return
  end

  local candidate = _trim(self._inputText)
  candidate = _filterNickname(candidate)

  local length = _getUtf8Len(candidate)
  if length < 2 or length > 15 then
    self._errorText = "닉네임은 2~15글자여야 합니다."
    return
  end

  if candidate == "" then
    self._errorText = "닉네임을 입력해 주세요."
    return
  end

  local isOk = self._settingsManager:setNickname(candidate)
  if not isOk then
    self._errorText = "닉네임은 한글/영문/숫자만 가능합니다."
    return
  end

  self._settingsManager:save()
  App:closeOverlay()
end

function NicknameOverlay:_removeLastChar(text)
  local length = _getUtf8Len(text)
  if length <= 0 then
    return ""
  end

  local byteIndex = utf8.offset(text, -1)
  if not byteIndex then
    return ""
  end

  return string.sub(text, 1, byteIndex - 1)
end

function NicknameOverlay:_takeFirstChars(text, count)
  if count <= 0 then
    return ""
  end

  local length = _getUtf8Len(text)
  if count >= length then
    return text
  end

  local byteIndex = utf8.offset(text, count + 1)
  if not byteIndex then
    return text
  end

  return string.sub(text, 1, byteIndex - 1)
end

return NicknameOverlay
