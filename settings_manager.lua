--[[
파일명: settings_manager.lua
모듈명: SettingsManager

역할:
- 환경설정 값의 로드/검증/저장(settings.ini)
- 디스플레이(창모드 고정 1280x720 + 전체화면 3종) 적용
- 볼륨(BGM/SFX), 마우스 감도 값 관리

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

주의:
- 해상도/전체화면은 "저장" 시점에만 applyDisplay로 반영하는 설계를 권장
]]
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

local function parseKeyValueLines(text)
  local result = {}

  if not text or text == "" then
    return result
  end

  for line in string.gmatch(text, "([^\r\n]+)") do
    local trimmed = string.match(line, "^%s*(.-)%s*$")
    if trimmed ~= "" and string.sub(trimmed, 1, 1) ~= "#" then
      local key, value = string.match(trimmed, "^([^=]+)=(.*)$")
      if key and value then
        key = string.match(key, "^%s*(.-)%s*$")
        value = string.match(value, "^%s*(.-)%s*$")
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
    table.insert(lines, key .. "=" .. tostring(value))
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

function SettingsManager.new()
  local self = setmetatable({}, SettingsManager)

  self._applied = {
    displayPresetIndex = 1,
    bgmVolumePercent = 70,
    sfxVolumePercent = 70,
    mouseSensitivityPercent = 50,
  }

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
end

function SettingsManager:save()
  local preset = Config.DISPLAY_PRESETS[self._applied.displayPresetIndex]

  local map = {
    _order = {
      "displayPresetKey",
      "bgmVolumePercent",
      "sfxVolumePercent",
      "mouseSensitivityPercent",
    },
    displayPresetKey = preset.key,
    bgmVolumePercent = self._applied.bgmVolumePercent,
    sfxVolumePercent = self._applied.sfxVolumePercent,
    mouseSensitivityPercent = self._applied.mouseSensitivityPercent,
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
  -- 지금은 값만 유지하며, 추후 setVolume 적용 지점을 이 함수에 연결하면 됨.
end

function SettingsManager:applyInput()
  -- 스켈레톤 단계:
  -- 마우스 감도는 조준/드래그 계산 시
  -- "스크린→월드 변환 이후 벡터"에 곱하는 형태로 반영 권장.
end

function SettingsManager:getSaveDirectory()
  return love.filesystem.getSaveDirectory()
end

return SettingsManager
