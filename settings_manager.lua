--[[
파일명: settings_manager.lua
모듈명: SettingsManager

역할:
- 환경설정 값의 로드/검증/저장(settings.ini)
- 디스플레이(창모드 고정 1280x720 + 전체화면 3종) 적용
- 볼륨(BGM/SFX), 마우스 감도 값 관리
- 닉네임(한글/영문/숫자만, 2~15글자) 저장/로드

외부에서 사용 가능한 함수:
- SettingsManager.new()
- SettingsManager:load()
- SettingsManager:save()
- SettingsManager:applyDisplay()
- SettingsManager:applyAudio()
- SettingsManager:applyInput()
- SettingsManager:getApplied()
- SettingsManager:copyAppliedAsPending()
- SettingsManager:commitPending(pending)
- SettingsManager:getNickname()
- SettingsManager:setNickname(nickname)
- SettingsManager:getSaveDirectory()

주의:
- 해상도/전체화면은 "저장" 시점에만 applyDisplay로 반영 권장
]]
local utf8 = require("utf8")
local SettingsManager = {}
SettingsManager.__index = SettingsManager

local function clampNumber(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function _trim(text)
  if not text then
    return ""
  end
  return (string.match(text, "^%s*(.-)%s*$") or "")
end

local function parseKeyValueLines(text)
  local result = {}

  if not text or text == "" then
    return result
  end

  for line in string.gmatch(text, "([^\r\n]+)") do
    local trimmed = _trim(line)
    if trimmed ~= "" and string.sub(trimmed, 1, 1) ~= "#" then
      local key, value = string.match(trimmed, "^([^=]+)=(.*)$")
      if key and value then
        key = _trim(key)
        value = _trim(value)
        result[key] = value
      end
    end
  end

  return result
end

local function serializeKeyValueLines(map)
  local lines = {}

  table.insert(lines, "# project_r settings.ini")
  table.insert(lines, "# 저장 위치는 love.filesystem.getSaveDirectory() 기준입니다.")
  table.insert(lines, "")

  for _, key in ipairs(map._order) do
    local value = map[key]
    table.insert(lines, key .. "=" .. tostring(value or ""))
  end

  table.insert(lines, "")
  return table.concat(lines, "\n")
end

local function findPresetIndexByKey(key)
  for i, preset in ipairs(Config.DISPLAY_PRESETS) do
    if preset.key == key then
      return i
    end
  end
  return 1
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

  -- Hangul Jamo
  if codepoint >= 0x1100 and codepoint <= 0x11FF then
    return true
  end
  -- Hangul Compatibility Jamo
  if codepoint >= 0x3130 and codepoint <= 0x318F then
    return true
  end
  -- Hangul Syllables
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

local function _isValidNickname(text)
  local filtered = _filterNickname(text)
  if filtered ~= text then
    return false
  end

  local length = _getUtf8Len(text)
  return length >= 2 and length <= 15
end

function SettingsManager.new()
  local self = setmetatable({}, SettingsManager)

  self._applied = {
    displayPresetIndex = 1,
    bgmVolumePercent = 70,
    sfxVolumePercent = 70,
    mouseSensitivityPercent = 50,
  }

  self._nickname = "플레이어1"

  return self
end

function SettingsManager:getApplied()
  return self._applied
end

function SettingsManager:copyAppliedAsPending()
  return {
    displayPresetIndex = self._applied.displayPresetIndex,
    bgmVolumePercent = self._applied.bgmVolumePercent,
    sfxVolumePercent = self._applied.sfxVolumePercent,
    mouseSensitivityPercent = self._applied.mouseSensitivityPercent,
  }
end

function SettingsManager:commitPending(pending)
  self._applied.displayPresetIndex = clampNumber(pending.displayPresetIndex, 1, #Config.DISPLAY_PRESETS)
  self._applied.bgmVolumePercent = clampNumber(pending.bgmVolumePercent, 0, 100)
  self._applied.sfxVolumePercent = clampNumber(pending.sfxVolumePercent, 0, 100)
  self._applied.mouseSensitivityPercent = clampNumber(pending.mouseSensitivityPercent, 0, 100)
end

function SettingsManager:getNickname()
  if self._nickname and self._nickname ~= "" then
    return self._nickname
  end
  return "플레이어1"
end

function SettingsManager:setNickname(nickname)
  local trimmed = _trim(nickname)
  if _isValidNickname(trimmed) then
    self._nickname = trimmed
    return true
  end

  return false
end

function SettingsManager:load()
  local path = Config.SETTINGS_FILE_NAME
  local isExists = love.filesystem.getInfo(path) ~= nil

  if not isExists then
    return
  end

  local content = love.filesystem.read(path)
  local map = parseKeyValueLines(content)

  local presetKey = map.displayPresetKey
  if presetKey then
    self._applied.displayPresetIndex = findPresetIndexByKey(presetKey)
  end

  if map.bgmVolumePercent then
    self._applied.bgmVolumePercent = clampNumber(tonumber(map.bgmVolumePercent) or self._applied.bgmVolumePercent, 0, 100)
  end

  if map.sfxVolumePercent then
    self._applied.sfxVolumePercent = clampNumber(tonumber(map.sfxVolumePercent) or self._applied.sfxVolumePercent, 0, 100)
  end

  if map.mouseSensitivityPercent then
    self._applied.mouseSensitivityPercent = clampNumber(tonumber(map.mouseSensitivityPercent) or self._applied.mouseSensitivityPercent, 0, 100)
  end

  if map.nickname then
    local trimmed = _trim(map.nickname)
    if _isValidNickname(trimmed) then
      self._nickname = trimmed
    else
      self._nickname = "플레이어1"
    end
  end
end

function SettingsManager:save()
  local preset = Config.DISPLAY_PRESETS[self._applied.displayPresetIndex]

  local map = {
    _order = {
      "displayPresetKey",
      "bgmVolumePercent",
      "sfxVolumePercent",
      "mouseSensitivityPercent",
      "nickname",
    },
    displayPresetKey = preset.key,
    bgmVolumePercent = self._applied.bgmVolumePercent,
    sfxVolumePercent = self._applied.sfxVolumePercent,
    mouseSensitivityPercent = self._applied.mouseSensitivityPercent,
    nickname = self:getNickname(),
  }

  local text = serializeKeyValueLines(map)
  love.filesystem.write(Config.SETTINGS_FILE_NAME, text)
end

function SettingsManager:applyDisplay()
  local preset = Config.DISPLAY_PRESETS[self._applied.displayPresetIndex]

  local flags = {
    fullscreen = preset.isFullscreen,
    resizable = false,
  }

  love.window.setMode(preset.width, preset.height, flags)
end

function SettingsManager:applyAudio()
  -- 스켈레톤 단계:
  -- 실제로 AudioManager가 생기면 여기서 master/bgm/sfx 볼륨을 적용하도록 연결
end

function SettingsManager:applyInput()
  -- 스켈레톤 단계:
  -- 마우스 감도는 추후 조준/드래그 계산에서 반영
end

function SettingsManager:getSaveDirectory()
  return love.filesystem.getSaveDirectory()
end

return SettingsManager
