--[[
파일명: lobby_scene.lua
모듈명: LobbyScene

역할:
- 로비 UI(방 생성/방 찾기/닉네임 변경/가이드/스킨/크레딧/게임 종료)
- 서버 HTTP(/room/create)로 방 생성 처리
- 성공 시 WaitingRoomScene으로 이동(호스트, wsUrl 포함)

외부에서 사용 가능한 함수:
- LobbyScene.new(params)
- LobbyScene:update(dt)
- LobbyScene:draw()
- LobbyScene:onMousePressed(...)
- LobbyScene:onKeyPressed(...)
- LobbyScene:onTextInput(text)

주의:
- 버튼/화면 배치는 “정상 동작하던 로비(버튼/씬 전환)” 기준을 유지한다.
- 서버 응답은 문자열(JSON) 또는 테이블일 수 있으므로 둘 다 안전하게 처리한다.
- WaitingRoomScene 이동 시 wsUrl을 반드시 전달한다.
]]
local Utils = require("utils")
local HttpClient = require("http_client")

local LobbyScene = {}
LobbyScene.__index = LobbyScene

local function _asString(v)
  if v == nil then
    return ""
  end
  if type(v) == "string" then
    return v
  end
  return tostring(v)
end

local function _extractFieldAsString(resp, key)
  if resp == nil then
    return ""
  end

  if type(resp) == "table" then
    local v = resp[key]
    return _asString(v)
  end

  local raw = _asString(resp)
  return string.match(raw, "\"" .. key .. "\"%s*:%s*\"([^\"]*)\"") or ""
end

local function _extractFieldAsBool(resp, key)
  if resp == nil then
    return false
  end

  if type(resp) == "table" then
    return resp[key] == true
  end

  local raw = _asString(resp)
  return string.match(raw, "\"" .. key .. "\"%s*:%s*true") ~= nil
end

function LobbyScene.new(_params)
  local self = setmetatable({}, LobbyScene)

  self.name = "LobbyScene"

  self._statusText = ""

  -- ※ 이 버튼 배치/구성은 “버튼/화면이 멀쩡했던 버전(lobby_scene2)”을 유지
  self._buttons = {
    { key = "createRoom", label = "방 생성", x = 80, y = 160, w = 200, h = 45 },
    { key = "findRoom", label = "방 찾기", x = 80, y = 230, w = 200, h = 45 },
    { key = "changeName", label = "닉네임 변경", x = 80, y = 300, w = 200, h = 45 },
    { key = "gameGuide", label = "게임 가이드", x = 80, y = 370, w = 200, h = 45 },
    { key = "skin", label = "스킨 변경", x = 80, y = 440, w = 200, h = 45 },
    { key = "credits", label = "크레딧", x = 80, y = 510, w = 200, h = 45 },
    { key = "exit", label = "게임 종료", x = 80, y = 580, w = 200, h = 45 },
  }

  return self
end

function LobbyScene:update(_dt)
end

function LobbyScene:draw()
  local nickname = "플레이어"
  if App and App.getSettingsManager then
    nickname = App:getSettingsManager():getNickname()
  end

  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.print("안녕하세요 " .. tostring(nickname) .. "님", 80, 80)

  love.graphics.setFont(Assets:getFont("default"))
  if self._statusText ~= "" then
    love.graphics.print(self._statusText, 80, 120)
  end

  for _, btn in ipairs(self._buttons) do
    -- draw는 RenderScale.begin() 내부에서 호출되므로 “월드 좌표” 기준이 맞다.
    -- hover는 참고용 UI이므로 기존 방식 유지(클릭 판정은 App에서 월드좌표로 변환되어 정확히 들어옴)
    local mx, my = love.mouse.getPosition()
    local isHovered = Utils.isPointInRect(mx, my, btn.x, btn.y, btn.w, btn.h)
    Utils.drawButton({ x = btn.x, y = btn.y, w = btn.w, h = btn.h }, btn.label, isHovered)
  end
end

function LobbyScene:onMousePressed(x, y, button, _istouch, _presses)
  if button ~= 1 then
    return false
  end

  for _, btn in ipairs(self._buttons) do
    if Utils.isPointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
      if btn.key == "createRoom" then
        self:_handleCreateRoom()
        return true
      end

      if btn.key == "findRoom" then
        self._statusText = ""
        SceneManager:change("RoomSearchScene")
        return true
      end

      if btn.key == "changeName" then
        self._statusText = ""
        if App and App.openNicknamePopup then
          App:openNicknamePopup()
        else
          self._statusText = "닉네임 변경을 열 수 없습니다(App 연동 확인 필요)."
        end
        return true
      end

      if btn.key == "gameGuide" then
        self._statusText = ""
        SceneManager:change("GameGuideScene")
        return true
      end

      if btn.key == "skin" then
        self._statusText = ""
        SceneManager:change("SkinChangeScene")
        return true
      end

      if btn.key == "credits" then
        self._statusText = ""
        SceneManager:change("CreditsScene")
        return true
      end

      if btn.key == "exit" then
        love.event.quit()
        return true
      end
    end
  end

  return false
end

function LobbyScene:onKeyPressed(key, _scancode, _isrepeat)
  if key == "escape" then
    return true
  end
  return false
end

function LobbyScene:onTextInput(_text)
  return false
end

function LobbyScene:_handleCreateRoom()
  local url = Config.SERVER_HTTP_BASE .. "/room/create"

  local resp, err = HttpClient.postJson(url, {})
  if not resp then
    self._statusText = "방 생성 실패: " .. tostring(err or "응답 오류")
    return
  end

  local ok = _extractFieldAsBool(resp, "ok")
  if not ok then
    local errorCode = _extractFieldAsString(resp, "error")
    if errorCode ~= "" then
      self._statusText = "방 생성 실패: " .. errorCode
    else
      self._statusText = "방 생성 실패: ok=false"
    end
    return
  end

  local roomCode = _extractFieldAsString(resp, "roomCode")
  local wsUrl = _extractFieldAsString(resp, "wsUrl")

  if roomCode == "" or wsUrl == "" then
    self._statusText = "방 생성 실패: wsUrl/roomCode 누락"
    return
  end

  self._statusText = ""
  SceneManager:change("WaitingRoomScene", {
    isHost = true,
    roomCode = roomCode,
    wsUrl = wsUrl,
  })
end

return LobbyScene
