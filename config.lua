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

--Config.SERVER_HTTP_BASE = "https://projectr.pangyostonefist.workers.dev"
--Config.SERVER_WS_BASE = "wss://projectr.pangyostonefist.workers.dev"
-- 로컬 테스트 시엔 상단 두줄 하단 두줄로 변경: 하단은 로컬 상단은 서버
Config.SERVER_HTTP_BASE = "http://127.0.0.1:8787"
Config.SERVER_WS_BASE = "ws://127.0.0.1:8787"

Config.SAVE_IDENTITY = "project_r"
Config.SETTINGS_FILE_NAME = "settings.ini"

-- 기준 해상도(월드 좌표계 기준)
Config.BASE_WIDTH = 1280
Config.BASE_HEIGHT = 720

-- 초기 창모드(항상 1280x720)
Config.WINDOW_WIDTH = 1280
Config.WINDOW_HEIGHT = 720

Config.SETTINGS_BUTTON_X = Config.BASE_WIDTH - 140
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

-- ================================
-- 네트워크(Workers + DO + WebSocket)
-- ================================
Config.NET_WS_URL = "wss://<YOUR_WORKER_DOMAIN>/ws" -- 예: wss://projectr.yourname.workers.dev/ws
Config.NET_CONNECT_TIMEOUT_SEC = 10

-- ================================
-- 보드(임시: 600x600 중앙 고정)
-- ================================
Config.BOARD_SIZE = 600

-- ================================
-- 채팅 레이트리밋(변경 가능)
-- ================================
Config.CHAT_RATE_WINDOW_SEC = 10
Config.CHAT_RATE_MAX_COUNT = 3
Config.CHAT_RATE_COOLDOWN_SEC = 5

-- ================================
-- 스냅샷 동기화(호스트 기준)
-- ================================
Config.SNAPSHOT_SEND_FINAL_ONLY = true

return Config
