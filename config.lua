--[[
파일명: config.lua
모듈명: Config

역할:
- 프로젝트 전역 설정 상수 정의

외부에서 사용 가능한 함수:
- (없음)

주의:
- 상수는 UPPER_SNAKE_CASE만 사용
]]
local Config = {}

Config.SAVE_IDENTITY = "project_r"
Config.SETTINGS_FILE_NAME = "settings.ini"

Config.WINDOW_WIDTH = 1280
Config.WINDOW_HEIGHT = 720

Config.SETTINGS_BUTTON_X = Config.WINDOW_WIDTH - 140
Config.SETTINGS_BUTTON_Y = 16
Config.SETTINGS_BUTTON_W = 124
Config.SETTINGS_BUTTON_H = 40

Config.DEFAULT_FONT_PATH = "assets/fonts/NotoSansKR-Regular.ttf"
Config.DEFAULT_FONT_SIZE = 22
Config.SMALL_FONT_SIZE = 18
Config.TITLE_FONT_SIZE = 32

Config.OVERLAY_PANEL_SCALE = 0.70

Config.DISPLAY_PRESETS = {
  { key = "Window_1280x720", label = "창모드 (1280×720)", isFullscreen = false, width = 1280, height = 720 },
  { key = "Fullscreen_1280x720", label = "전체화면 1280×720", isFullscreen = true, width = 1280, height = 720 },
  { key = "Fullscreen_1600x900", label = "전체화면 1600×900", isFullscreen = true, width = 1600, height = 900 },
  { key = "Fullscreen_1920x1080", label = "전체화면 1920×1080", isFullscreen = true, width = 1920, height = 1080 },
}

return Config
