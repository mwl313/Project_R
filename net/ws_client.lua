--[[
파일명: ws_client.lua
모듈명: WsClient

역할:
- WebSocket 라이브러리 어댑터
- NetManager가 사용하는 공통 인터페이스 제공

외부에서 사용 가능한 함수:
- WsClient.new(params)
- WsClient:update(dt)
- WsClient:sendJson(table)
- WsClient:close()

주의:
- 프로젝트에 libs/websocket.lua(또는 동등 API)가 필요하다.
- 이 파일은 라이브러리 교체를 쉽게 하기 위한 래퍼이다.
]]
local WsClient = {}
WsClient.__index = WsClient

function WsClient.new(params)
  local self = setmetatable({}, WsClient)

  self._url = params.url
  self._onOpen = params.onOpen
  self._onMessage = params.onMessage
  self._onClose = params.onClose
  self._onError = params.onError

  -- 아래 모듈은 사용자가 추가해야 함.
  -- 기대 API:
  -- local ws = WebSocket.connect(url)
  -- ws:on("open", fn), ws:on("message", fn(text)), ws:on("close", fn), ws:on("error", fn)
  -- ws:send(text), ws:close(), ws:update(dt)
  local WebSocket = require("libs/websocket")

  self._ws = WebSocket.connect(self._url)

  self._ws:on("open", function()
    if self._onOpen then
      self._onOpen()
    end
  end)

  self._ws:on("message", function(text)
    if self._onMessage then
      self._onMessage(text)
    end
  end)

  self._ws:on("close", function()
    if self._onClose then
      self._onClose()
    end
  end)

  self._ws:on("error", function()
    if self._onError then
      self._onError()
    end
  end)

  return self
end

function WsClient:update(dt)
  if self._ws and self._ws.update then
    self._ws:update(dt)
  end
end

function WsClient:sendJson(obj)
  if not self._ws then
    return false
  end

  local text = Utils.encodeJson(obj)
  self._ws:send(text)
  return true
end

function WsClient:close()
  if self._ws and self._ws.close then
    self._ws:close()
  end
end

return WsClient
