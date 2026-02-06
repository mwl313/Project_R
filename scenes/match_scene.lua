--[[
파일명: match_scene.lua
모듈명: MatchScene

역할:
- 매치 진행(서버 연동 + 물리)
  1) 배치(직접): 내 진영(항상 하단)에서 돌 배치(최소 거리/중앙 띠 금지)
  2) 배치 공개: 10초 동안 상대 배치 공개(서버 타이머)
  3) 초능력 분배/선택: 선공 2장 중 1장, 후공 3장 중 2장(겹침 없음, 서버 권위)
  4) 턴 진행: 발사 입력 전송(game.fire) + 수신 시 물리 적용
  5) 턴 종료: 모든 돌 정지 감지 후 호스트가 스냅샷 1회 제출(game.snapshot)
  6) 스냅샷 수신: 호스트 스냅샷 기준으로 양쪽 물리 보정
  7) 탈락 판정: 보드 밖으로 나가면 제거(PhysicsWorld 내에서 처리)

외부에서 사용 가능한 함수:
- MatchScene.new(params)
- MatchScene:update(dt)
- MatchScene:draw()
- MatchScene:onMousePressed(...)
- MatchScene:onMouseReleased(...)
- MatchScene:onMouseMoved(...)
- MatchScene:onKeyPressed(...)

주의:
- sub state flow는 일방통행(뒤로 불가)
- 기권/이탈(네트워크 포함)은 결과 화면으로 이동(서버가 result로 전환)
]]
local Utils = require("utils")
local PhysicsWorld = require("game.physics_world")

local MatchScene = {}
MatchScene.__index = MatchScene

local SUB_STATES = {
  "WaitTurnOrder",
  "Placement",
  "PlacementReveal",
  "AbilitySelect",
  "Gameplay",
}

local function clampNumber(value, minValue, maxValue)
  if value < minValue then
    return minValue
  end
  if value > maxValue then
    return maxValue
  end
  return value
end

local function dist2d(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return math.sqrt(dx * dx + dy * dy)
end

function MatchScene.new(params)
  local self = setmetatable({}, MatchScene)

  self.name = "MatchScene"

  self._mouseX = 0
  self._mouseY = 0

  self._roomCode = params.roomCode or ""

  self._subStateIndex = 1
  self._subStateName = SUB_STATES[self._subStateIndex]

  self._statusText = "서버 상태 대기..."

  self._boardSize = Config.BOARD_SIZE or 600
  self._boardX = math.floor((Config.BASE_WIDTH - self._boardSize) / 2)
  self._boardY = math.floor((Config.BASE_HEIGHT - self._boardSize) / 2)
  self._boardRect = { x = self._boardX, y = self._boardY, w = self._boardSize, h = self._boardSize }

  self._stoneRadius = Config.STONE_RADIUS or 20
  self._stoneGap = Config.STONE_MIN_GAP or 5
  self._minCenterDist = (self._stoneRadius * 2) + self._stoneGap

  self._centerBandPx = Config.CENTER_BAND_PX or self._minCenterDist

  self._stoneCount = Config.PLACEMENT_STONE_COUNT or 7

  self._localPlacements = {}
  self._remotePlacements = nil

  self._isPlacementSubmitted = false
  self._revealTimerSec = 0
  self._revealDurationSec = 10

  self._turnOrder = nil

  self._myPlayerId = ""
  self._myRole = ""
  self._isHost = false

  self._hostPlayerId = ""
  self._guestPlayerId = ""

  self._physics = PhysicsWorld.new(self._boardSize, self._stoneRadius)
  self._hasPhysicsWorld = false
  self._isSimulating = false

  self._myStoneIndexStart = 0
  self._myStoneIndexEnd = 0

  self._isDraggingShot = false
  self._dragStart = { x = 0, y = 0 }
  self._dragNow = { x = 0, y = 0 }
  self._selectedCanonicalStoneIndex = 0

  self._myCards = {}
  self._myPickCount = 0
  self._myChosenCards = {}
  self._isAbilitySent = false

  self._winnerPlayerId = ""
  self._resultReason = ""

  self._buttonRects = {
    submitPlacement = { x = 80, y = 610, w = 260, h = 52 },
    resign = { x = 360, y = 610, w = 260, h = 52 },
  }

  return self
end

function MatchScene:update(dt)
  self._mouseX, self._mouseY = love.mouse.getPosition()

  self:_pumpNetEvents()
  self:_syncFromRoomState()

  if self._subStateName == "PlacementReveal" then
    self._revealTimerSec = self._revealTimerSec + dt
    if self._revealTimerSec >= self._revealDurationSec then
      self:_advanceSubState("AbilitySelect")
    end
  end

  if self._subStateName == "Gameplay" and self._hasPhysicsWorld then
    self._physics:update(dt)

    if self._isSimulating then
      if self._physics:isAllSleeping() and self._physics:isSleepTimeExceeded() then
        self._isSimulating = false

        if self._isHost then
          local state = App:getNetManager():getRoomState()
          if state and state.turnId and state.turnId > 0 then
            local snapshot = self._physics:buildSnapshot()
            App:getNetManager():send("game.snapshot", {
              turnId = state.turnId,
              snapshot = snapshot,
            })
          end
        end
      end
    end
  end
end

function MatchScene:draw()
  love.graphics.setFont(Assets:getFont("title"))
  love.graphics.printf("매치", 0, 20, Config.BASE_WIDTH, "center")
  love.graphics.setFont(Assets:getFont("default"))

  love.graphics.print("상태: " .. self._subStateName, 80, 70)
  love.graphics.print(self._statusText, 80, 100)

  self:_drawBoard()
  self:_drawTopCardArea()
  self:_drawBottomCardArea()
  self:_drawButtons()
end

function MatchScene:onKeyPressed(key)
  if key == "escape" then
    return true
  end

  return false
end

function MatchScene:onMouseMoved(x, y, dx, dy, istouch)
  if self._isDraggingShot then
    self._dragNow.x = x
    self._dragNow.y = y
    return true
  end

  return false
end

function MatchScene:onMousePressed(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if self:_handleButtons(x, y) then
    return true
  end

  if self._subStateName == "Placement" then
    return self:_handlePlacementClick(x, y)
  end

  if self._subStateName == "AbilitySelect" then
    return self:_handleAbilityClick(x, y)
  end

  if self._subStateName == "Gameplay" then
    return self:_handleGameplayMouseDown(x, y)
  end

  return false
end

function MatchScene:onMouseReleased(x, y, button, istouch, presses)
  if button ~= 1 then
    return false
  end

  if self._subStateName == "Gameplay" then
    return self:_handleGameplayMouseUp(x, y)
  end

  return false
end

function MatchScene:_handleButtons(x, y)
  if Utils.isPointInRect(x, y, self._buttonRects.resign.x, self._buttonRects.resign.y, self._buttonRects.resign.w, self._buttonRects.resign.h) then
    App:getNetManager():send("game.resign", {})
    return true
  end

  if self._subStateName == "Placement" and (not self._isPlacementSubmitted) then
    if Utils.isPointInRect(x, y, self._buttonRects.submitPlacement.x, self._buttonRects.submitPlacement.y, self._buttonRects.submitPlacement.w, self._buttonRects.submitPlacement.h) then
      self:_trySubmitPlacement()
      return true
    end
  end

  return false
end

function MatchScene:_drawButtons()
  local mx, my = self._mouseX, self._mouseY

  if self._subStateName == "Placement" then
    local isHovered = Utils.isPointInRect(mx, my, self._buttonRects.submitPlacement.x, self._buttonRects.submitPlacement.y, self._buttonRects.submitPlacement.w, self._buttonRects.submitPlacement.h)
    local label = self._isPlacementSubmitted and "배치 제출됨" or "배치 제출"
    Utils.drawButton(self._buttonRects.submitPlacement, label, isHovered)
  end

  do
    local isHovered = Utils.isPointInRect(mx, my, self._buttonRects.resign.x, self._buttonRects.resign.y, self._buttonRects.resign.w, self._buttonRects.resign.h)
    Utils.drawButton(self._buttonRects.resign, "기권", isHovered)
  end
end

function MatchScene:_drawBoard()
  local bx, by, bw, bh = self._boardRect.x, self._boardRect.y, self._boardRect.w, self._boardRect.h

  love.graphics.rectangle("line", bx, by, bw, bh)

  local midY = by + math.floor(bh / 2)
  love.graphics.line(bx, midY, bx + bw, midY)

  local bandHalf = math.floor(self._centerBandPx / 2)
  love.graphics.rectangle("line", bx, midY - bandHalf, bw, self._centerBandPx)

  love.graphics.print("보드(600x600, 중앙 고정)", bx, by - 22)

  self:_drawStones()
  self:_drawGhostPlacement()
  self:_drawShotDragLine()
end

function MatchScene:_drawStones()
  if self._subStateName == "Gameplay" and self._hasPhysicsWorld then
    self:_drawStonesFromPhysics()
    return
  end

  for i, s in ipairs(self._localPlacements) do
    local sx, sy = self:_boardToScreenFromLocal(s.x, s.y)
    love.graphics.circle("line", sx, sy, self._stoneRadius)
    love.graphics.print(tostring(i), sx - 4, sy - 8)
  end

  if self._subStateName == "PlacementReveal" or self._subStateName == "AbilitySelect" then
    if self._remotePlacements then
      for i, s in ipairs(self._remotePlacements) do
        local sx, sy = self:_boardToScreenFromLocal(s.x, s.y)
        love.graphics.circle("line", sx, sy, self._stoneRadius)
        love.graphics.print("R" .. tostring(i), sx - 12, sy - 8)
      end
    end
  end
end

function MatchScene:_drawStonesFromPhysics()
  local total = self._stoneCount * 2

  for i = 1, total do
    if self._physics:isStoneAlive(i) then
      local lx, ly = self._physics:getStonePosition(i)
      if lx and ly then
        local sx, sy = self:_boardToScreenFromLocal(lx, ly)
        love.graphics.circle("line", sx, sy, self._stoneRadius)

        local label = ""
        if self:_isMyCanonicalStoneIndex(i) then
          label = "M" .. tostring(i)
        else
          label = "R" .. tostring(i)
        end

        love.graphics.print(label, sx - 12, sy - 8)
      end
    end
  end
end

function MatchScene:_drawGhostPlacement()
  if self._subStateName ~= "Placement" then
    return
  end

  if #self._localPlacements >= self._stoneCount then
    return
  end

  local bx, by, bw, bh = self._boardRect.x, self._boardRect.y, self._boardRect.w, self._boardRect.h
  if not Utils.isPointInRect(self._mouseX, self._mouseY, bx, by, bw, bh) then
    return
  end

  local lx, ly = self:_screenToBoardLocal(self._mouseX, self._mouseY)

  local canPlace, reason = self:_canPlaceAt(lx, ly)
  if not canPlace then
    love.graphics.print("배치 불가: " .. reason, 80, 130)
  else
    love.graphics.print("배치 가능: 클릭하여 배치", 80, 130)
  end

  local sx, sy = self:_boardToScreenFromLocal(lx, ly)
  love.graphics.circle("line", sx, sy, self._stoneRadius)
end

function MatchScene:_drawShotDragLine()
  if self._subStateName ~= "Gameplay" then
    return
  end

  if not self._isDraggingShot then
    return
  end

  love.graphics.line(self._dragStart.x, self._dragStart.y, self._dragNow.x, self._dragNow.y)
end

function MatchScene:_drawTopCardArea()
  love.graphics.setFont(Assets:getFont("small"))
  love.graphics.print("상대 카드 영역(표시만)", 80, 150)
  love.graphics.setFont(Assets:getFont("default"))
end

function MatchScene:_drawBottomCardArea()
  local yBase = Config.BASE_HEIGHT - 120

  love.graphics.setFont(Assets:getFont("small"))
  love.graphics.print("내 카드 영역", 80, yBase)

  if self._subStateName == "AbilitySelect" then
    love.graphics.print("카드 선택: " .. tostring(#self._myChosenCards) .. "/" .. tostring(self._myPickCount), 80, yBase + 22)
    self:_drawAbilityCards(80, yBase + 52)
  elseif self._subStateName == "Gameplay" then
    if #self._myChosenCards > 0 then
      love.graphics.print("선택된 카드: " .. table.concat(self._myChosenCards, ", "), 80, yBase + 22)
    else
      love.graphics.print("선택된 카드: 없음", 80, yBase + 22)
    end
  end

  love.graphics.setFont(Assets:getFont("default"))
end

function MatchScene:_drawAbilityCards(x, y)
  local cardW = 90
  local cardH = 44
  local gap = 14

  for i, id in ipairs(self._myCards) do
    local rx = x + (i - 1) * (cardW + gap)
    local ry = y

    love.graphics.rectangle("line", rx, ry, cardW, cardH)

    if self:_isCardChosen(id) then
      love.graphics.rectangle("line", rx + 3, ry + 3, cardW - 6, cardH - 6)
    end

    love.graphics.printf(id, rx, ry + 12, cardW, "center")
  end
end

function MatchScene:_handleAbilityClick(x, y)
  local cardW = 90
  local cardH = 44
  local gap = 14

  local yBase = Config.BASE_HEIGHT - 120
  local cx = 80
  local cy = yBase + 52

  for i, id in ipairs(self._myCards) do
    local rx = cx + (i - 1) * (cardW + gap)
    local ry = cy

    if Utils.isPointInRect(x, y, rx, ry, cardW, cardH) then
      self:_toggleCardChoice(id)
      self:_trySendAbilityPick()
      return true
    end
  end

  return false
end

function MatchScene:_toggleCardChoice(id)
  if self._isAbilitySent then
    return
  end

  if self:_isCardChosen(id) then
    for i = #self._myChosenCards, 1, -1 do
      if self._myChosenCards[i] == id then
        table.remove(self._myChosenCards, i)
      end
    end
    return
  end

  if #self._myChosenCards >= self._myPickCount then
    return
  end

  table.insert(self._myChosenCards, id)
end

function MatchScene:_isCardChosen(id)
  for _, c in ipairs(self._myChosenCards) do
    if c == id then
      return true
    end
  end
  return false
end

function MatchScene:_trySendAbilityPick()
  if self._isAbilitySent then
    return
  end

  if self._myPickCount <= 0 then
    return
  end

  if #self._myChosenCards ~= self._myPickCount then
    return
  end

  App:getNetManager():send("ability.pick", { chosen = self._myChosenCards })
  self._isAbilitySent = true
end

function MatchScene:_handlePlacementClick(x, y)
  if self._isPlacementSubmitted then
    return true
  end

  if #self._localPlacements >= self._stoneCount then
    return true
  end

  local bx, by, bw, bh = self._boardRect.x, self._boardRect.y, self._boardRect.w, self._boardRect.h
  if not Utils.isPointInRect(x, y, bx, by, bw, bh) then
    return false
  end

  local lx, ly = self:_screenToBoardLocal(x, y)
  local canPlace = self:_canPlaceAt(lx, ly)
  if not canPlace then
    return true
  end

  table.insert(self._localPlacements, { x = lx, y = ly })
  return true
end

function MatchScene:_canPlaceAt(lx, ly)
  local r = self._stoneRadius
  local size = self._boardSize

  if lx < r or lx > (size - r) or ly < r or ly > (size - r) then
    return false, "보드 밖"
  end

  local mid = size / 2
  local bandHalf = self._centerBandPx / 2

  if ly <= (mid + bandHalf) then
    return false, "중앙 띠/상대 진영"
  end

  for _, s in ipairs(self._localPlacements) do
    if dist2d(lx, ly, s.x, s.y) < self._minCenterDist then
      return false, "돌이 너무 가까움"
    end
  end

  return true, ""
end

function MatchScene:_trySubmitPlacement()
  if self._isPlacementSubmitted then
    return
  end

  if #self._localPlacements ~= self._stoneCount then
    self._statusText = "돌을 " .. tostring(self._stoneCount) .. "개 모두 배치해야 합니다."
    return
  end

  local stones = {}
  for _, s in ipairs(self._localPlacements) do
    local cx, cy = self:_localToCanonical(s.x, s.y)
    table.insert(stones, { x = cx, y = cy })
  end

  App:getNetManager():send("placement.submit", { stones = stones })
  self._isPlacementSubmitted = true
end

function MatchScene:_handleGameplayMouseDown(x, y)
  local state = App:getNetManager():getRoomState()
  if not state or not state.currentTurnPlayerId then
    return true
  end

  if state.currentTurnPlayerId ~= self._myPlayerId then
    return true
  end

  if not self._hasPhysicsWorld then
    return true
  end

  local bx, by, bw, bh = self._boardRect.x, self._boardRect.y, self._boardRect.w, self._boardRect.h
  if not Utils.isPointInRect(x, y, bx, by, bw, bh) then
    return false
  end

  local lx, ly = self:_screenToBoardLocal(x, y)

  local bestIndex = 0
  local bestDist = 999999

  for i = self._myStoneIndexStart, self._myStoneIndexEnd do
    if self._physics:isStoneAlive(i) then
      local sx, sy = self._physics:getStonePosition(i)
      if sx and sy then
        local d = dist2d(lx, ly, sx, sy)
        if d < bestDist then
          bestDist = d
          bestIndex = i
        end
      end
    end
  end

  if bestIndex == 0 then
    return true
  end

  if bestDist > (self._stoneRadius + 8) then
    return true
  end

  self._selectedCanonicalStoneIndex = bestIndex

  self._isDraggingShot = true
  self._dragStart.x = x
  self._dragStart.y = y
  self._dragNow.x = x
  self._dragNow.y = y

  return true
end

function MatchScene:_handleGameplayMouseUp(x, y)
  if not self._isDraggingShot then
    return false
  end

  self._isDraggingShot = false

  local state = App:getNetManager():getRoomState()
  if not state or state.currentTurnPlayerId ~= self._myPlayerId then
    return true
  end

  if self._selectedCanonicalStoneIndex <= 0 then
    return true
  end

  if not self._physics:isStoneAlive(self._selectedCanonicalStoneIndex) then
    return true
  end

  local dx = self._dragStart.x - x
  local dy = self._dragStart.y - y
  local power = clampNumber(math.sqrt(dx * dx + dy * dy), 0, 300)

  App:getNetManager():send("game.fire", {
    stoneId = tostring(self._selectedCanonicalStoneIndex),
    dx = dx,
    dy = dy,
    power = power,
  })

  return true
end

function MatchScene:_pumpNetEvents()
  local net = App:getNetManager()
  local events = net:popEvents()

  for _, e in ipairs(events) do
    if e.type == "match.turnOrder" then
      self._turnOrder = e.payload
      self:_advanceSubState("Placement")
    end

    if e.type == "placement.reveal" then
      self._revealDurationSec = (e.payload and e.payload.durationSec) or 10
      self._revealTimerSec = 0

      local placements = (e.payload and e.payload.placements) or {}
      self:_buildRevealAndPhysicsFromCanonical(placements)

      self:_advanceSubState("PlacementReveal")
    end

    if e.type == "ability.deal" then
      self._myCards = (e.payload and e.payload.cards) or {}
      self._myPickCount = (e.payload and e.payload.pickCount) or 0
      self._myChosenCards = {}
      self._isAbilitySent = false

      self:_advanceSubState("AbilitySelect")
    end

    if e.type == "ability.locked" then
      self:_advanceSubState("Gameplay")
    end

    if e.type == "game.fire" then
      self:_applyFireEvent(e.payload)
    end

    if e.type == "game.snapshot" then
      if e.payload and e.payload.snapshot then
        if self._hasPhysicsWorld then
          self._physics:applySnapshot(e.payload.snapshot)
        end
        self._isSimulating = false
      end
    end

    if e.type == "result.decided" then
      self._winnerPlayerId = (e.payload and e.payload.winnerPlayerId) or ""
      self._resultReason = (e.payload and e.payload.reason) or ""

      SceneManager:change("ResultScene", {
        winnerPlayerId = self._winnerPlayerId,
        reason = self._resultReason,
        roomCode = self._roomCode,
      })
    end

    if e.type == "room.closed" then
      App:getNetManager():disconnect()
      SceneManager:change("LobbyScene", {})
    end

    if e.type == "room.reset" then
      local state = App:getNetManager():getRoomState()
      local isHost = false
      if state and state.host and state.host.playerId == App:getNetManager():getPlayerId() then
        isHost = true
      end

      SceneManager:change("WaitingRoomScene", { isHost = isHost, roomCode = self._roomCode })
    end
  end
end

function MatchScene:_applyFireEvent(payload)
  if not payload then
    return
  end

  if not self._hasPhysicsWorld then
    return
  end

  local stoneIndex = tonumber(payload.stoneId) or 0
  if stoneIndex <= 0 then
    return
  end

  if not self._physics:isStoneAlive(stoneIndex) then
    return
  end

  local dx = tonumber(payload.dx) or 0
  local dy = tonumber(payload.dy) or 0
  local power = tonumber(payload.power) or 0

  self._physics:applyShot(stoneIndex, dx, dy, power)
  self._isSimulating = true
end

function MatchScene:_syncFromRoomState()
  local net = App:getNetManager()

  self._myPlayerId = net:getPlayerId()
  self._myRole = net:getRole()
  self._isHost = (self._myRole == "host")

  local state = net:getRoomState()
  if not state then
    self._statusText = "서버 상태 수신 대기..."
    return
  end

  if state.host and state.guest then
    if state.host.playerId then
      self._hostPlayerId = state.host.playerId
    end
    if state.guest.playerId then
      self._guestPlayerId = state.guest.playerId
    end
  end

  if state.phase == "result" and state.winnerPlayerId and state.winnerPlayerId ~= "" then
    SceneManager:change("ResultScene", {
      winnerPlayerId = state.winnerPlayerId,
      reason = state.resultReason or "",
      roomCode = self._roomCode,
    })
    return
  end

  if state.turnOrder then
    self._turnOrder = state.turnOrder
  end

  local turnText = ""
  if state.currentTurnPlayerId and state.currentTurnPlayerId ~= "" then
    if state.currentTurnPlayerId == self._myPlayerId then
      turnText = "내 턴"
    else
      turnText = "상대 턴"
    end
  end

  self._statusText = string.format("phase=%s | turnId=%s | %s", tostring(state.phase), tostring(state.turnId or 0), turnText)
end

function MatchScene:_advanceSubState(targetName)
  local currentIndex = self._subStateIndex

  for i, name in ipairs(SUB_STATES) do
    if name == targetName then
      if i < currentIndex then
        return
      end

      self._subStateIndex = i
      self._subStateName = SUB_STATES[self._subStateIndex]
      return
    end
  end
end

function MatchScene:_isGuestPerspective()
  return self._myRole == "guest"
end

function MatchScene:_localToCanonical(lx, ly)
  if not self:_isGuestPerspective() then
    return lx, ly
  end

  local size = self._boardSize
  return (size - lx), (size - ly)
end

function MatchScene:_canonicalToLocal(cx, cy)
  if not self:_isGuestPerspective() then
    return cx, cy
  end

  local size = self._boardSize
  return (size - cx), (size - cy)
end

function MatchScene:_screenToBoardLocal(screenX, screenY)
  local bx, by = self._boardRect.x, self._boardRect.y
  local lx = clampNumber(screenX - bx, 0, self._boardSize)
  local ly = clampNumber(screenY - by, 0, self._boardSize)
  return lx, ly
end

function MatchScene:_boardToScreenFromLocal(lx, ly)
  return self._boardRect.x + lx, self._boardRect.y + ly
end

function MatchScene:_isMyCanonicalStoneIndex(index)
  return index >= self._myStoneIndexStart and index <= self._myStoneIndexEnd
end

function MatchScene:_buildRevealAndPhysicsFromCanonical(placementsMap)
  local hostId = self._hostPlayerId
  local guestId = self._guestPlayerId

  if hostId == "" or guestId == "" then
    for pid, _ in pairs(placementsMap) do
      if hostId == "" then
        hostId = pid
      elseif guestId == "" and pid ~= hostId then
        guestId = pid
      end
    end
  end

  local hostCanonical = placementsMap[hostId] or {}
  local guestCanonical = placementsMap[guestId] or {}

  local myId = self._myPlayerId
  local remoteCanonical = nil
  if myId == hostId then
    remoteCanonical = guestCanonical
  else
    remoteCanonical = hostCanonical
  end

  local remoteLocal = {}
  for _, s in ipairs(remoteCanonical) do
    local cx = tonumber(s.x) or 0
    local cy = tonumber(s.y) or 0
    local lx, ly = self:_canonicalToLocal(cx, cy)
    table.insert(remoteLocal, { x = lx, y = ly })
  end
  self._remotePlacements = remoteLocal

  local stonesLocalForPhysics = {}

  for _, s in ipairs(hostCanonical) do
    local cx = tonumber(s.x) or 0
    local cy = tonumber(s.y) or 0
    local lx, ly = self:_canonicalToLocal(cx, cy)
    table.insert(stonesLocalForPhysics, { x = lx, y = ly })
  end

  for _, s in ipairs(guestCanonical) do
    local cx = tonumber(s.x) or 0
    local cy = tonumber(s.y) or 0
    local lx, ly = self:_canonicalToLocal(cx, cy)
    table.insert(stonesLocalForPhysics, { x = lx, y = ly })
  end

  self._physics:createStones(stonesLocalForPhysics)
  self._hasPhysicsWorld = true
  self._isSimulating = false

  if self._myPlayerId == hostId then
    self._myStoneIndexStart = 1
    self._myStoneIndexEnd = #hostCanonical
  else
    self._myStoneIndexStart = #hostCanonical + 1
    self._myStoneIndexEnd = #hostCanonical + #guestCanonical
  end
end

return MatchScene
