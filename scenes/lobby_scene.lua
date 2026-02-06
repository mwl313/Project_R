--[[
파일명: lobby_scene.lua
모듈명: LobbyScene

역할:
- 메인 로비 UI
- 방 생성/방 찾기/가이드/스킨/크레딧/닉네임 변경/게임 종료 제공
- 방 생성은 서버에서 roomCode 생성 후 대기방으로 이동

외부에서 사용 가능한 함수:
- LobbyScene.new(params)
- LobbyScene:update(dt)
- LobbyScene:draw()
- LobbyScene:onMousePressed(...)
- LobbyScene:onKeyPressed(...)

주의:
- 게임 종료는 버튼이며 즉시 종료(love.event.quit)
- 닉네임 변경은 팝업(Overlay)으로만 처리
]]
local Utils = require("utils")
local HttpClient = require("http_client")

local LobbyScene = {}
LobbyScene.__index = LobbyScene

function LobbyScene.new(params)
  local self = setmetatable({}, LobbyScene)

  self.name = "LobbyScene"

  self._buttons = {
    { key = "createRoom", label = "방 생성", x = 80, y = 160, w = 260, h = 56 },
    { key = "findRoom", label = "방 찾기", x = 80, y = 230, w = 260, h = 56 },
    { key = "nickname", label = "닉네임 변경", x = 80, y = 300, w = 260, h = 56 },
    { key = "guide", label = "게임 가이드", x = 80, y = 370, w = 260, h = 56 },
    { key = "skin", label = "스킨 변경", x = 80, y = 440, w = 260, h = 56 },
    { key = "credits", label = "크레딧", x = 80, y = 510, w = 260, h = 56 },
    { key = "quit", label = "게임 종료", x = 80, y = 580, w = 260, h = 56 },
  }

  self._statusText = ""

  return self
end

function LobbyScene:update(_dt)
  -- 상태 텍스트는 필요 시 유지
end

function LobbyScene:draw()
  local nickname = App:getSettingsManager():getNickname()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.print("안녕하세요 " .. nickname .. "님", 80, 80)

  love.graphics.setFont(Assets:getFont("default"))

  for _, btn in ipairs(self._buttons) do
    local mx, my = love.mouse.getPosition()
    local isHovered = Utils.isPointInRect(mx, my, btn.x, btn.y, btn.w, btn.h)
    Utils.drawButton({ x = btn.x, y = btn.y, w = btn.w, h = btn.h }, btn.label, isHovered)
  end

  if self._statusText ~= "" then
    love.graphics.print(self._statusText, 80, 130)
  end
end

function LobbyScene:onKeyPressed(_key, _scancode, _isrepeat)
  return false
end

function LobbyScene:onMousePressed(x, y, button, _istouch, _presses)
  if button ~= 1 then
    return false
  end

  for _, btn in ipairs(self._buttons) do
    if Utils.isPointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
      self:_handleButton(btn.key)
      return true
    end
  end

  return false
end

function LobbyScene:_handleButton(key)
  if key == "createRoom" then
    self:_createRoomAndGoWaitingRoom()
    return
  end

  if key == "findRoom" then
    SceneManager:change("RoomSearchScene")
    return
  end

  if key == "guide" then
    SceneManager:change("GameGuideScene")
    return
  end

  if key == "skin" then
    SceneManager:change("SkinChangeScene")
    return
  end

  if key == "credits" then
    SceneManager:change("CreditsScene")
    return
  end

  if key == "nickname" then
    App:openNicknamePopup()
    return
  end

  if key == "quit" then
    love.event.quit()
    return
  end
end

function LobbyScene:_createRoomAndGoWaitingRoom()
  self._statusText = "방 생성 중..."

  local url = Config.SERVER_HTTP_BASE .. "/room/create"
  local response, err = HttpClient.postJson(url, {})

  if err then
    self._statusText = "방 생성 실패: " .. tostring(err)
    return
  end

  if not response or not response.roomCode then
    self._statusText = "방 생성 실패: 응답 오류"
    return
  end

  self._statusText = ""
  SceneManager:change("WaitingRoomScene", { isHost = true, roomCode = response.roomCode })
end

return LobbyScene
