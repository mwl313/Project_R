--[[
파일명: result_scene.lua
모듈명: ResultScene

역할:
- 게임 결과 확인 화면(서버 result)
- 재대결 / 로비 복귀 투표 전송
  - 둘 다 재대결: 대기방으로 이동
  - 한 명이라도 로비: 둘 다 로비로 이동(방 종료)

외부에서 사용 가능한 함수:
- ResultScene.new(params)
- ResultScene:update(dt)
- ResultScene:draw()
- ResultScene:onMousePressed(...)

주의:
- sub state flow에서는 뒤로가기 없음(결과 화면도 동일)
]]
local Utils = require("utils")

local ResultScene = {}
ResultScene.__index = ResultScene

function ResultScene.new(params)
  local self = setmetatable({}, ResultScene)

  self.name = "ResultScene"

  self._mouseX = 0
  self._mouseY = 0

  self._winnerPlayerId = params.winnerPlayerId or ""
  self._reason = params.reason or ""
  self._roomCode = params.roomCode or ""

  self._statusText = "투표를 선택하세요"

  self._voteSent = false
  self._myChoice = ""

  self._rematchRect = { x = 360, y = 420, w = 260, h = 56 }
  self._lobbyRect = { x = 660, y = 420, w = 260, h = 56 }

  return self
end

function ResultScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()

  local net = App:getNetManager()
  local events = net:popEvents()

  for _, e in ipairs(events) do
    if e.type == "room.reset" then
      local state = net:getRoomState()
      local isHost = false
      if state and state.host and state.host.playerId == net:getPlayerId() then
        isHost = true
      end

      SceneManager:change("WaitingRoomScene", { isHost = isHost, roomCode = self._roomCode })
      return
    end

    if e.type == "room.closed" then
      net:disconnect()
      SceneManager:change("LobbyScene", {})
      return
    end
  end
end

function ResultScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("게임 결과", 0, 40, Config.BASE_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))

  love.graphics.print("승자: " .. (self._winnerPlayerId ~= "" and self._winnerPlayerId or "알 수 없음"), 360, 160)
  love.graphics.print("사유: " .. (self._reason ~= "" and self._reason or "-"), 360, 190)

  love.graphics.print(self._statusText, 360, 240)

  local mx, my = self._mouseX, self._mouseY

  local hoverA = Utils.isPointInRect(mx, my, self._rematchRect.x, self._rematchRect.y, self._rematchRect.w, self._rematchRect.h)
  local hoverB = Utils.isPointInRect(mx, my, self._lobbyRect.x, self._lobbyRect.y, self._lobbyRect.w, self._lobbyRect.h)

  Utils.drawButton(self._rematchRect, self._voteSent and "재대결(전송됨)" or "재대결", hoverA)
  Utils.drawButton(self._lobbyRect, self._voteSent and "로비로(전송됨)" or "로비로 돌아가기", hoverB)

  if self._voteSent then
    love.graphics.print("내 선택: " .. self._myChoice .. " (상대 선택 대기 중일 수 있음)", 360, 500)
  end
end

function ResultScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if self._voteSent then
    return true
  end

  if Utils.isPointInRect(x, y, self._rematchRect.x, self._rematchRect.y, self._rematchRect.w, self._rematchRect.h) then
    self:_sendVote("rematch")
    return true
  end

  if Utils.isPointInRect(x, y, self._lobbyRect.x, self._lobbyRect.y, self._lobbyRect.w, self._lobbyRect.h) then
    self:_sendVote("lobby")
    return true
  end

  return false
end

function ResultScene:_sendVote(choice)
  local net = App:getNetManager()
  net:send("result.vote", { choice = choice })

  self._voteSent = true
  self._myChoice = choice
  self._statusText = "투표 전송됨. 결과 처리 중..."
end

return ResultScene
