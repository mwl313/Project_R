--[[
파일명: lobby_scene.lua
모듈명: LobbyScene

역할:
- 메인 로비 UI
- 방 생성/방 찾기/가이드/스킨/크레딧/닉네임 변경/게임 종료 제공

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

local LobbyScene = {}
LobbyScene.__index = LobbyScene

function LobbyScene.new(params)
  local self = setmetatable({}, LobbyScene)

  self.name = "LobbyScene"

  self._mouseX = 0
  self._mouseY = 0

  self._buttons = {
    { key = "createRoom", label = "방 생성", x = 80, y = 140, w = 260, h = 52 },
    { key = "findRoom", label = "방 찾기", x = 80, y = 210, w = 260, h = 52 },
    { key = "guide", label = "게임 설명", x = 80, y = 280, w = 260, h = 52 },
    { key = "skin", label = "스킨 변경", x = 80, y = 350, w = 260, h = 52 },
    { key = "credits", label = "제작자 & 버전", x = 80, y = 420, w = 260, h = 52 },
    { key = "nickname", label = "닉네임 변경", x = 80, y = 490, w = 260, h = 52 },
    { key = "quit", label = "게임 종료", x = 80, y = 560, w = 260, h = 52 },
  }

  return self
end

function LobbyScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()
end

function LobbyScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("로비", 0, 50, Config.WINDOW_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))

  for _, b in ipairs(self._buttons) do
    local isHovered = Utils.isPointInRect(self._mouseX, self._mouseY, b.x, b.y, b.w, b.h)
    Utils.drawButton({ x = b.x, y = b.y, w = b.w, h = b.h }, b.label, isHovered)
  end

  love.graphics.setFont(Assets:getFont("small"))
  love.graphics.print("※ 환경설정 버튼은 우상단 고정(로비/대기방/매치에서 접근 가능)", 80, 640)
  love.graphics.setFont(Assets:getFont("default"))
end

function LobbyScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  for _, b in ipairs(self._buttons) do
    if Utils.isPointInRect(x, y, b.x, b.y, b.w, b.h) then
      self:_handleButton(b.key)
      return true
    end
  end

  return false
end

function LobbyScene:_handleButton(key)
  if key == "createRoom" then
    SceneManager:change("WaitingRoomScene", { isHost = true })
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

function LobbyScene:onKeyPressed(key, scancode, isrepeat)
  return false
end

function LobbyScene:onMouseReleased(x, y, button, istouch, presses)
  return false
end

return LobbyScene
