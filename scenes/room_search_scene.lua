--[[
파일명: room_search_scene.lua
모듈명: RoomSearchScene

역할:
- 방 코드 입력(IME 포함) UI 제공
- 엔터/버튼 클릭으로 방 참가 시도 트리거

외부에서 사용 가능한 함수:
- RoomSearchScene.new(params)
- RoomSearchScene:update(dt)
- RoomSearchScene:draw()
- RoomSearchScene:onKeyPressed(key, scancode, isrepeat)
- RoomSearchScene:onTextInput(text)
- RoomSearchScene:onTextEdited(text, start, length)
- RoomSearchScene:onMousePressed(x, y, button, istouch, presses)

주의:
- 이 씬은 "입력 안정성"에 초점을 둔다(서버 연동은 1곳만 연결하면 됨)
- _로 시작하는 필드/함수는 내부 전용
]]
local Utils = require("utils")

local RoomSearchScene = {}
RoomSearchScene.__index = RoomSearchScene

local function _trim(text)
  if not text then
    return ""
  end
  return (string.match(text, "^%s*(.-)%s*$") or "")
end

local function _clampCodeChar(ch)
  -- 방 코드는 서버에서 생성(예: NQJ63)되므로: 영문/숫자만 허용(대문자화)
  local byte = string.byte(ch)
  if not byte then
    return ""
  end

  if byte >= 48 and byte <= 57 then
    return ch
  end

  if byte >= 65 and byte <= 90 then
    return ch
  end

  if byte >= 97 and byte <= 122 then
    return string.upper(ch)
  end

  return ""
end

local function _filterRoomCode(text)
  if not text or text == "" then
    return ""
  end

  local buffer = {}
  for i = 1, #text do
    local ch = string.sub(text, i, i)
    local filtered = _clampCodeChar(ch)
    if filtered ~= "" then
      table.insert(buffer, filtered)
    end
  end

  return table.concat(buffer)
end

function RoomSearchScene.new(params)
  local self = setmetatable({}, RoomSearchScene)

  self.name = "RoomSearchScene"

  self._mouseX = 0
  self._mouseY = 0

  self._titleY = 80
  self._panelX = 0
  self._panelY = 0
  self._panelW = 560
  self._panelH = 260

  self._inputRect = { x = 0, y = 0, w = 420, h = 56 }
  self._joinRect = { x = 0, y = 0, w = 180, h = 56 }
  self._backRect = { x = 0, y = 0, w = 180, h = 56 }

  self._roomCode = ""
  self._imeText = ""
  self._isFocused = true

  self._blinkSec = 0
  self._isCaretOn = true

  self._errorText = ""

  self:_recalcLayout()

  -- 텍스트 입력 시작(IME 포함)
  love.keyboard.setTextInput(true)

  return self
end

function RoomSearchScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()

  self._blinkSec = self._blinkSec + dt
  if self._blinkSec >= 0.5 then
    self._blinkSec = 0
    self._isCaretOn = not self._isCaretOn
  end
end

function RoomSearchScene:draw()
  self:_recalcLayout()

  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("방 찾기", 0, self._titleY, Config.BASE_WIDTH, "center")

  love.graphics.setFont(Assets:getFont("default"))

  -- 패널
  love.graphics.rectangle("line", self._panelX, self._panelY, self._panelW, self._panelH)

  local hint = "방 코드를 입력하세요 (예: NQJ63)"
  love.graphics.print(hint, self._panelX + 40, self._panelY + 46)

  -- 입력 박스
  love.graphics.rectangle("line", self._inputRect.x, self._inputRect.y, self._inputRect.w, self._inputRect.h)

  local displayText = self._roomCode
  if self._imeText ~= "" then
    displayText = self._roomCode .. self._imeText
  end

  if displayText == "" then
    love.graphics.print("코드 입력...", self._inputRect.x + 14, self._inputRect.y + 14)
  else
    love.graphics.print(displayText, self._inputRect.x + 14, self._inputRect.y + 14)
  end

  -- 커서(캐럿)
  if self._isFocused and self._isCaretOn then
    local textW = love.graphics.getFont():getWidth(displayText)
    local caretX = self._inputRect.x + 14 + textW + 2
    local caretY1 = self._inputRect.y + 12
    local caretY2 = self._inputRect.y + self._inputRect.h - 12
    love.graphics.line(caretX, caretY1, caretX, caretY2)
  end

  -- 버튼
  local isJoinHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._joinRect.x, self._joinRect.y, self._joinRect.w, self._joinRect.h)
  Utils.drawButton(self._joinRect, "참가", isJoinHovered)

  local isBackHovered = Utils.isPointInRect(self._mouseX, self._mouseY, self._backRect.x, self._backRect.y, self._backRect.w, self._backRect.h)
  Utils.drawButton(self._backRect, "로비로", isBackHovered)

  if self._errorText ~= "" then
    love.graphics.print(self._errorText, self._panelX + 40, self._panelY + 210)
  end
end

function RoomSearchScene:onKeyPressed(key, scancode, isrepeat)
  if key == "escape" then
    love.keyboard.setTextInput(false)
    SceneManager:change("LobbyScene")
    return true
  end

  if key == "backspace" then
    if self._imeText ~= "" then
      -- 조합 중이면 삭제는 IME가 처리하므로 여기서는 유지
      return true
    end

    local len = #self._roomCode
    if len > 0 then
      self._roomCode = string.sub(self._roomCode, 1, len - 1)
    end
    return true
  end

  if key == "return" or key == "kpenter" then
    self:_tryJoin()
    return true
  end

  return false
end

function RoomSearchScene:onTextInput(text)
  if not self._isFocused then
    return false
  end

  if self._imeText ~= "" then
    -- IME 조합 중에는 textinput이 섞일 수 있어 안전하게 무시
    return true
  end

  local filtered = _filterRoomCode(text)
  if filtered ~= "" then
    self._roomCode = _filterRoomCode(self._roomCode .. filtered)
  end

  return true
end

function RoomSearchScene:onTextEdited(text, start, length)
  if not self._isFocused then
    return false
  end

  -- IME 조합 문자열(미확정) 표시용
  self._imeText = _filterRoomCode(text)
  return true
end

function RoomSearchScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if Utils.isPointInRect(x, y, self._inputRect.x, self._inputRect.y, self._inputRect.w, self._inputRect.h) then
    self._isFocused = true
    love.keyboard.setTextInput(true)
    return true
  end

  self._isFocused = false

  if Utils.isPointInRect(x, y, self._joinRect.x, self._joinRect.y, self._joinRect.w, self._joinRect.h) then
    self:_tryJoin()
    return true
  end

  if Utils.isPointInRect(x, y, self._backRect.x, self._backRect.y, self._backRect.w, self._backRect.h) then
    love.keyboard.setTextInput(false)
    SceneManager:change("LobbyScene")
    return true
  end

  return false
end

function RoomSearchScene:_tryJoin()
  local code = _trim(self._roomCode)
  code = _filterRoomCode(code)

  if code == "" then
    self._errorText = "방 코드를 입력해 주세요."
    return
  end

  if self._imeText ~= "" then
    self._errorText = "한/영 조합이 끝난 뒤 참가해 주세요."
    return
  end

  self._errorText = ""

  -- ============================================
  -- 여기 1줄만, 당신의 실제 “방 참가” 함수명으로 연결하면 됩니다.
  -- 예시(권장): App:joinRoomByCode(code)
  -- ============================================
  if App.joinRoomByCode then
    App:joinRoomByCode(code)
    return
  end

  -- 연결 함수가 아직 없다면 일단 대기방으로 이동(디버깅용)
  SceneManager:change("WaitingRoomScene", { roomCode = code, isHost = false })
end

function RoomSearchScene:_recalcLayout()
  local w = Config.BASE_WIDTH
  local h = Config.BASE_HEIGHT

  self._panelX = math.floor((w - self._panelW) / 2)
  self._panelY = math.floor((h - self._panelH) / 2)

  self._inputRect.x = self._panelX + 40
  self._inputRect.y = self._panelY + 86

  self._joinRect.x = self._panelX + self._panelW - 40 - self._joinRect.w
  self._joinRect.y = self._panelY + 156

  self._backRect.x = self._panelX + 40
  self._backRect.y = self._panelY + 156
end

return RoomSearchScene
