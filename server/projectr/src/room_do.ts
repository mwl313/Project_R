/**
 * 파일명: room_do.ts
 * 모듈명: RoomDO
 *
 * 역할:
 * - Durable Object 1개 = 게임 방 1개
 * - WebSocket 연결 수락 및 세션 관리
 * - 호스트/게스트 배정
 * - 채팅/게임 이벤트 브로드캐스트
 *
 * 외부에서 사용 가능한 항목:
 * - RoomDO (class)
 *
 * 주의:
 * - 이 단계는 "서버 골격"이다.
 * - 서버 권위 게임 로직은 다음 단계에서 강화한다.
 */

import { RULES } from "./rules";
import { buildServerEvent, parseClientMessage, type ClientMessage } from "./protocol";

type Env = {
  ROOM: DurableObjectNamespace;
};

type PlayerRole = "host" | "guest" | "spectator";

type PlayerSession = {
  playerId: string;
  nickname: string;
  role: PlayerRole;
  ws: WebSocket;

  chatWindowStartMs: number;
  chatCountInWindow: number;
};

type RoomState = {
  roomCode: string;
  hostPlayerId: string;
  guestPlayerId: string;
  phase: "waiting" | "match" | "result";
  turnId: number;
  currentTurnPlayerId: string;
};

export class RoomDO {
  private readonly _state: DurableObjectState;
  private readonly _env: Env;

  private _roomCode: string;
  private _sessions: Map<WebSocket, PlayerSession>;
  private _stateCache: RoomState;

  public constructor(state: DurableObjectState, env: Env) {
    this._state = state;
    this._env = env;

    this._roomCode = "";
    this._sessions = new Map();

    this._stateCache = {
      roomCode: "",
      hostPlayerId: "",
      guestPlayerId: "",
      phase: "waiting",
      turnId: 0,
      currentTurnPlayerId: "",
    };
  }

  public async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/ws") {
      return this._handleWebSocketUpgrade(request);
    }

    if (url.pathname === "/health") {
      return new Response("ok");
    }

    return new Response("not found", { status: 404 });
  }

  private async _handleWebSocketUpgrade(request: Request): Promise<Response> {
    const upgrade = request.headers.get("Upgrade");
    if (!upgrade || upgrade.toLowerCase() !== "websocket") {
      return new Response("expected websocket", { status: 400 });
    }

    const url = new URL(request.url);
    const roomCode = url.searchParams.get("room") || "";
    if (!roomCode) {
      return new Response("missing room", { status: 400 });
    }

    this._roomCode = roomCode;
    this._stateCache.roomCode = roomCode;

    const pair = new WebSocketPair();
    const client = pair[0];
    const server = pair[1];

    server.accept();
    this._attachSocketHandlers(server);

    // 접속 직후 현재 방 상태 전달
    this._send(server, "room.state", this._buildRoomStatePayload());

    return new Response(null, { status: 101, webSocket: client });
  }

  private _attachSocketHandlers(ws: WebSocket): void {
    ws.addEventListener("message", (evt: MessageEvent) => {
      const text = typeof evt.data === "string" ? evt.data : "";
      this._onSocketMessage(ws, text);
    });

    ws.addEventListener("close", () => {
      this._onSocketClosed(ws);
    });

    ws.addEventListener("error", () => {
      this._onSocketClosed(ws);
    });
  }

  private _onSocketMessage(ws: WebSocket, text: string): void {
    const msg = parseClientMessage(text);
    if (!msg) {
      this._send(ws, "error", { message: "invalid_message" });
      return;
    }

    if (msg.type === "room.join") {
      this._handleJoin(ws, msg);
      return;
    }

    const session = this._sessions.get(ws);
    if (!session) {
      this._send(ws, "error", { message: "not_joined" });
      return;
    }

    switch (msg.type) {
      case "chat.send":
        this._handleChatSend(session, msg);
        return;

      case "placement.submit":
      case "ability.pick":
      case "game.fire":
      case "game.snapshot":
      case "game.resign":
        this._broadcast(msg.type, { playerId: session.playerId, ...msg.payload });
        return;

      default:
        this._send(ws, "error", { message: "unknown_type" });
        return;
    }
  }

  private _handleJoin(ws: WebSocket, msg: Extract<ClientMessage, { type: "room.join" }>): void {
    const playerId = msg.payload.playerId?.trim();
    if (!playerId) {
      this._send(ws, "error", { message: "missing_player_id" });
      return;
    }

    const nickname = msg.payload.nickname?.trim() || "플레이어";
    const role = this._assignRole(playerId);

    const session: PlayerSession = {
      playerId,
      nickname,
      role,
      ws,
      chatWindowStartMs: 0,
      chatCountInWindow: 0,
    };

    this._sessions.set(ws, session);

    this._broadcast("room.joined", {
      playerId,
      nickname,
      role,
    });

    this._broadcast("room.state", this._buildRoomStatePayload());
  }

  private _assignRole(playerId: string): PlayerRole {
    if (!this._stateCache.hostPlayerId) {
      this._stateCache.hostPlayerId = playerId;
      return "host";
    }

    if (!this._stateCache.guestPlayerId && this._stateCache.hostPlayerId !== playerId) {
      this._stateCache.guestPlayerId = playerId;
      this._stateCache.phase = "match";
      this._stateCache.turnId = 1;
      this._stateCache.currentTurnPlayerId = this._stateCache.hostPlayerId;

      this._broadcast("match.turnOrder", {
        firstPlayerId: this._stateCache.hostPlayerId,
        secondPlayerId: this._stateCache.guestPlayerId,
      });

      return "guest";
    }

    return "spectator";
  }

  private _handleChatSend(
    session: PlayerSession,
    msg: Extract<ClientMessage, { type: "chat.send" }>
  ): void {
    const text = msg.payload.text?.trim();
    if (!text) {
      return;
    }

    if (text.length > RULES.chat.maxChars) {
      this._send(session.ws, "chat.denied", { reason: "too_long" });
      return;
    }

    const now = Date.now();
    if (session.chatWindowStartMs === 0 || now - session.chatWindowStartMs > RULES.chat.windowMs) {
      session.chatWindowStartMs = now;
      session.chatCountInWindow = 0;
    }

    session.chatCountInWindow += 1;
    if (session.chatCountInWindow > RULES.chat.maxMessagesPerWindow) {
      this._send(session.ws, "chat.denied", { reason: "rate_limited" });
      return;
    }

    this._broadcast("chat.message", {
      playerId: session.playerId,
      nickname: session.nickname,
      text,
      ts: now,
    });
  }

  private _onSocketClosed(ws: WebSocket): void {
    const session = this._sessions.get(ws);
    this._sessions.delete(ws);

    if (!session) {
      return;
    }

    const wasHost = this._stateCache.hostPlayerId === session.playerId;
    const wasGuest = this._stateCache.guestPlayerId === session.playerId;

    this._broadcast("room.left", { playerId: session.playerId });

    if (wasHost) {
      this._broadcast("room.closed", { reason: "host_left" });
      this._resetRoomState();
      return;
    }

    if (wasGuest) {
      this._stateCache.guestPlayerId = "";
      this._stateCache.phase = "waiting";
      this._stateCache.turnId = 0;
      this._stateCache.currentTurnPlayerId = "";
      this._broadcast("room.state", this._buildRoomStatePayload());
    }
  }

  private _resetRoomState(): void {
    this._stateCache.hostPlayerId = "";
    this._stateCache.guestPlayerId = "";
    this._stateCache.phase = "waiting";
    this._stateCache.turnId = 0;
    this._stateCache.currentTurnPlayerId = "";
  }

  private _buildRoomStatePayload(): unknown {
    return { ...this._stateCache };
  }

  private _send(ws: WebSocket, type: string, payload?: unknown): void {
    ws.send(JSON.stringify(buildServerEvent(type, payload)));
  }

  private _broadcast(type: string, payload?: unknown): void {
    const text = JSON.stringify(buildServerEvent(type, payload));
    for (const [ws] of this._sessions) {
      try {
        ws.send(text);
      } catch {
        /* ignore */
      }
    }
  }
}
