--[[
파일명: physics_world.lua
모듈명: PhysicsWorld

역할:
- Love2D Box2D 물리 월드 관리
- 돌(알) 바디 생성/제거
- 발사(임펄스) 적용
- 모든 돌 정지 판정(턴 종료 감지)
- 스냅샷 생성 / 적용
- 보드 밖 탈락 판정(돌 제거)

외부에서 사용 가능한 함수:
- PhysicsWorld.new(boardSize, stoneRadius)
- PhysicsWorld:reset()
- PhysicsWorld:createStones(stones)
- PhysicsWorld:applyShot(stoneIndex, dx, dy, power)
- PhysicsWorld:update(dt)
- PhysicsWorld:isAllSleeping()
- PhysicsWorld:isSleepTimeExceeded()
- PhysicsWorld:buildSnapshot()
- PhysicsWorld:applySnapshot(snapshot)
- PhysicsWorld:getStonePosition(index)
- PhysicsWorld:isStoneAlive(index)

주의:
- 좌표는 "보드 로컬 좌표계(0~boardSize)" 기준
]]
local PhysicsWorld = {}
PhysicsWorld.__index = PhysicsWorld

local VELOCITY_EPS = 5
local SLEEP_TIME_SEC = 0.30
local FORCE_SCALE = 8

function PhysicsWorld.new(boardSize, stoneRadius)
  local self = setmetatable({}, PhysicsWorld)

  self._boardSize = boardSize
  self._stoneRadius = stoneRadius

  self._world = love.physics.newWorld(0, 0, true)
  self._world:setSleepingAllowed(true)

  self._stones = {}
  self._sleepTimer = 0

  return self
end

function PhysicsWorld:reset()
  self._world = love.physics.newWorld(0, 0, true)
  self._world:setSleepingAllowed(true)

  self._stones = {}
  self._sleepTimer = 0
end

function PhysicsWorld:_destroyStone(index)
  local stone = self._stones[index]
  if not stone then
    return
  end

  if stone.body and not stone.body:isDestroyed() then
    stone.body:destroy()
  end

  stone.body = nil
  stone.shape = nil
  stone.fixture = nil
  stone.isAlive = false
end

function PhysicsWorld:_createStoneAt(index, x, y)
  local body = love.physics.newBody(self._world, x, y, "dynamic")
  body:setLinearDamping(2.5)
  body:setAngularDamping(2.5)

  local shape = love.physics.newCircleShape(self._stoneRadius)
  local fixture = love.physics.newFixture(body, shape, 1)

  fixture:setRestitution(0.90)
  fixture:setFriction(0.40)

  self._stones[index] = {
    body = body,
    shape = shape,
    fixture = fixture,
    isAlive = true,
  }
end

function PhysicsWorld:createStones(stones)
  self:reset()

  for i, s in ipairs(stones) do
    self:_createStoneAt(i, s.x, s.y)
  end
end

function PhysicsWorld:applyShot(stoneIndex, dx, dy, power)
  local stone = self._stones[stoneIndex]
  if not stone or not stone.isAlive or not stone.body then
    return
  end

  local len = math.sqrt(dx * dx + dy * dy)
  if len <= 0 then
    return
  end

  local nx = dx / len
  local ny = dy / len

  local fx = nx * power * FORCE_SCALE
  local fy = ny * power * FORCE_SCALE

  stone.body:applyLinearImpulse(fx, fy)
  self._sleepTimer = 0
end

function PhysicsWorld:_isOutOfBoard(x, y)
  -- 기본 룰: "센터가 보드 밖으로 나가면 탈락"
  if x < 0 or x > self._boardSize then
    return true
  end
  if y < 0 or y > self._boardSize then
    return true
  end
  return false
end

function PhysicsWorld:_applyElimination()
  local isAnyEliminated = false

  for i, s in ipairs(self._stones) do
    if s.isAlive and s.body then
      local x, y = s.body:getPosition()
      if self:_isOutOfBoard(x, y) then
        self:_destroyStone(i)
        isAnyEliminated = true
      end
    end
  end

  if isAnyEliminated then
    self._sleepTimer = 0
  end
end

function PhysicsWorld:update(dt)
  self._world:update(dt)
  self:_applyElimination()

  if self:isAllSleeping() then
    self._sleepTimer = self._sleepTimer + dt
  else
    self._sleepTimer = 0
  end
end

function PhysicsWorld:isAllSleeping()
  for _, s in ipairs(self._stones) do
    if s.isAlive and s.body then
      local vx, vy = s.body:getLinearVelocity()
      if math.abs(vx) > VELOCITY_EPS or math.abs(vy) > VELOCITY_EPS then
        return false
      end
    end
  end

  return true
end

function PhysicsWorld:isSleepTimeExceeded()
  return self._sleepTimer >= SLEEP_TIME_SEC
end

function PhysicsWorld:buildSnapshot()
  local snapshot = {}

  for i, s in ipairs(self._stones) do
    if s.isAlive and s.body then
      local x, y = s.body:getPosition()
      snapshot[i] = {
        isAlive = true,
        x = x,
        y = y,
      }
    else
      snapshot[i] = {
        isAlive = false,
      }
    end
  end

  return snapshot
end

function PhysicsWorld:applySnapshot(snapshot)
  if not snapshot then
    return
  end

  for i, data in ipairs(snapshot) do
    if data.isAlive == false then
      self:_destroyStone(i)
    else
      local x = data.x or 0
      local y = data.y or 0

      local stone = self._stones[i]
      if not stone or not stone.isAlive or not stone.body then
        self:_createStoneAt(i, x, y)
      else
        stone.body:setPosition(x, y)
        stone.body:setLinearVelocity(0, 0)
        stone.body:setAngularVelocity(0)
      end
    end
  end

  self._sleepTimer = 0
end

function PhysicsWorld:getStonePosition(index)
  local stone = self._stones[index]
  if not stone or not stone.isAlive or not stone.body then
    return nil, nil
  end

  return stone.body:getPosition()
end

function PhysicsWorld:isStoneAlive(index)
  local stone = self._stones[index]
  if not stone then
    return false
  end
  return stone.isAlive == true
end

return PhysicsWorld
