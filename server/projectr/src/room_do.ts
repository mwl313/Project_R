/**
 * File: room_do.ts
 * Module: RoomDO
 *
 * Responsibilities:
 * - Durable Object authoritative room state
 * - WebSocket session management per room
 * - Room lifecycle rules:
 *   - Host leaves in waiting: close room, other returns to lobby
 *   - Any leave/disconnect during game flow: go to result as forfeit
 * - Chat relay with anti-spam rate limiting
 * - State machine skeleton (waiting -> placing -> reveal -> card_select -> playing -> result)
 *
 * Public exports:
 * - RoomDO class (Durable Object)
 */

import { ClientToServerMessage, PlayerPublic, PlayerSide, RoomSnapshot, ServerToClientMessage } from "./protocol";
import {
  CHAT_RATE_LIMIT_MAX_COUNT,
  CHAT_RATE_LIMIT_WINDOW_MS,
  EndReason,
  HEARTBEAT_INTERVAL_MS,
  MAX_PLAYERS,
  RoomPhase,
  isValidChatText,
  nowMs,
} from "./rules";

interface PlayerRecord {
  side: PlayerSide;
  token: string;
  nickname: string;
  isHost: boolean;
  isConnected: boolean;
  lastSeenMs: number;
  chatWindowStartMs: number;
  chatCountInWindow: number;
}

interface RoomState {
  roomCode: string;
  phase: RoomPhase;
  createdAtMs: number;
  players: PlayerRecord[];
  result?: {
    winnerSide?: PlayerSide;
    reason: EndReason;
  };
}

interface Env {}

function safeJsonParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function isWsUpgrade(request: Request): boolean {
  const upgrade = request.headers.get("Upgrade");
  return upgrade !== null && upgrade.toLowerCase() === "websocket";
}

function toPublicPlayer(p: PlayerRecord): PlayerPublic {
  return {
    side: p.side,
    nickname: p.nickname,
    isHost: p.isHost,
    isConnected: p.isConnected,
  };
}

function createSnapshot(state: RoomState): RoomSnapshot {
  return {
    roomCode: state.roomCode,
    phase: state.phase,
    players: state.players.map(toPublicPlayer),
    serverTimeMs: nowMs(),
    result: state.result ? { ...state.result } : undefined,
  };
}

function findPlayerByToken(state: RoomState, token: string): PlayerRecord | undefined {
  return state.players.find((p) => p.token === token);
}

function otherSide(side: PlayerSide): PlayerSide {
  return side === "p1" ? "p2" : "p1";
}

export class RoomDO {
  private readonly state: DurableObjectState;
  private readonly env: Env;

  private roomState: RoomState | null = null;
  private socketsByToken: Map<string, WebSocket> = new Map();
  private heartbeatTimer: number | null = null;

  public constructor(state: DurableObjectState, env: Env) {
    this.state = state;
    this.env = env;
  }

  public async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/do/init" && request.method === "POST") {
      const payload = await request.json().catch(() => null) as any;
      const roomCode = typeof payload?.roomCode === "string" ? payload.roomCode : "";
      if (!roomCode) return new Response("bad request", { status: 400 });

      await this.loadOrCreate(roomCode);
      await this.persist();
      return this.json({ ok: true, roomCode });
    }

    if (url.pathname === "/do/join" && request.method === "POST") {
      const payload = await request.json().catch(() => null) as any;
      const token = typeof payload?.token === "string" ? payload.token : "";
      const nickname = typeof payload?.nickname === "string" ? payload.nickname : "";
      const roomCode = typeof payload?.roomCode === "string" ? payload.roomCode : "";
      if (!token || !roomCode) return this.json({ ok: false, error: "bad_request" }, 400);

      await this.loadOrCreate(roomCode);

      const joinResult = this.ensurePlayer(token, nickname);
      if (!joinResult.ok) {
        return this.json({ ok: false, error: joinResult.error }, joinResult.status);
      }

      await this.persist();
      return this.json({ ok: true, roomCode, token, yourSide: joinResult.yourSide });
    }

    if (url.pathname === "/ws" && request.method === "GET" && isWsUpgrade(request)) {
      const token = url.searchParams.get("token") || "";
      const roomCode = url.searchParams.get("code") || "";
      if (!token || !roomCode) return new Response("missing token/code", { status: 400 });

      await this.loadOrCreate(roomCode);

      const player = findPlayerByToken(this.roomState!, token);
      if (!player) {
        return new Response("unknown token", { status: 403 });
      }

      const pair = new WebSocketPair();
      const client = pair[0];
      const server = pair[1];

      await this.acceptSocket(server, token);

      return new Response(null, {
        status: 101,
        webSocket: client,
      });
    }

    return new Response("Not Found", { status: 404 });
  }

  private async loadOrCreate(roomCode: string): Promise<void> {
    if (this.roomState) return;

    const saved = (await this.state.storage.get<RoomState>("roomState")) || null;
    if (saved) {
      this.roomState = saved;
      return;
    }

    this.roomState = {
      roomCode,
      phase: RoomPhase.Waiting,
      createdAtMs: nowMs(),
      players: [],
    };
  }

  private ensurePlayer(token: string, nickname: string): { ok: true; yourSide: PlayerSide } | { ok: false; error: string; status: number } {
    const state = this.roomState!;
    const existing = findPlayerByToken(state, token);
    if (existing) {
      existing.nickname = nickname?.trim() ? nickname.trim() : existing.nickname;
      return { ok: true, yourSide: existing.side };
    }

    if (state.players.length >= MAX_PLAYERS) {
      return { ok: false, error: "room_full", status: 409 };
    }

    const side: PlayerSide = state.players.length === 0 ? "p1" : "p2";
    const isHost = side === "p1";

    const record: PlayerRecord = {
      side,
      token,
      nickname: nickname?.trim() ? nickname.trim() : (side === "p1" ? "플레이어1" : "플레이어2"),
      isHost,
      isConnected: false,
      lastSeenMs: nowMs(),
      chatWindowStartMs: 0,
      chatCountInWindow: 0,
    };

    state.players.push(record);
    return { ok: true, yourSide: side };
  }

  private async acceptSocket(ws: WebSocket, token: string): Promise<void> {
    ws.accept();

    const state = this.roomState!;
    const player = findPlayerByToken(state, token);
    if (!player) {
      try {
        ws.send(JSON.stringify({ type: "error", code: "unknown_token", message: "알 수 없는 토큰입니다." } satisfies ServerToClientMessage));
      } catch {}
      try {
        ws.close(1008, "unknown token");
      } catch {}
      return;
    }

    player.isConnected = true;
    player.lastSeenMs = nowMs();

    this.socketsByToken.set(token, ws);
    this.ensureHeartbeat();

    ws.addEventListener("message", (evt) => {
      const text = typeof evt.data === "string" ? evt.data : "";
      this.onSocketMessage(token, text).catch(() => {
        // swallow to avoid crashing DO
      });
    });

    ws.addEventListener("close", () => {
      this.onSocketClosed(token).catch(() => {
        // swallow to avoid crashing DO
      });
    });

    // send hello_ok immediately
    const snapshot = createSnapshot(state);
    const helloOk: ServerToClientMessage = { type: "hello_ok", snapshot, yourSide: player.side, yourToken: token };
    ws.send(JSON.stringify(helloOk));

    this.broadcastSnapshot();
    this.broadcastSystemChat(`${player.nickname}님이 접속했습니다.`);
    await this.persist();
  }

  private async onSocketMessage(token: string, text: string): Promise<void> {
    const state = this.roomState!;
    const player = findPlayerByToken(state, token);
    if (!player) return;

    player.lastSeenMs = nowMs();

    const parsed = safeJsonParse(text);
    if (!parsed || typeof parsed !== "object") {
      this.sendToToken(token, { type: "error", code: "bad_json", message: "잘못된 메시지 형식입니다." });
      return;
    }

    const msg = parsed as ClientToServerMessage;

    switch (msg.type) {
      case "hello": {
        if (typeof msg.nickname === "string" && msg.nickname.trim()) {
          player.nickname = msg.nickname.trim();
        }
        this.sendToToken(token, { type: "snapshot", snapshot: createSnapshot(state) });
        await this.persist();
        return;
      }

      case "chat": {
        const text = typeof msg.text === "string" ? msg.text : "";
        if (!isValidChatText(text)) {
          this.sendToToken(token, { type: "error", code: "chat_invalid", message: "채팅 내용을 확인해 주세요." });
          return;
        }

        if (!this.tryConsumeChatQuota(player)) {
          this.sendToToken(token, { type: "error", code: "chat_rate_limited", message: "채팅을 너무 빠르게 보냈습니다. 잠시 후 다시 시도해 주세요." });
          return;
        }

        this.broadcast({
          type: "chat",
          fromSide: player.side,
          text: text.trim(),
          serverTimeMs: nowMs(),
        });

        await this.persist();
        return;
      }

      case "start_game": {
        if (!player.isHost) {
          this.sendToToken(token, { type: "error", code: "not_host", message: "방장만 게임 시작이 가능합니다." });
          return;
        }

        if (state.phase !== RoomPhase.Waiting) {
          this.sendToToken(token, { type: "error", code: "bad_phase", message: "현재 단계에서는 시작할 수 없습니다." });
          return;
        }

        if (state.players.length < 2) {
          this.sendToToken(token, { type: "error", code: "need_two_players", message: "상대 플레이어가 입장해야 시작할 수 있습니다." });
          return;
        }

        state.phase = RoomPhase.Placing;
        this.broadcastSystemChat("게임을 시작합니다. 알 배치 단계로 이동합니다.");
        this.broadcastSnapshot();
        await this.persist();
        return;
      }

      case "leave_room": {
        await this.handleLeave(player, "normal_leave");
        return;
      }

      // Placeholders for next step: accept but not implemented yet (no crash)
      case "submit_placement":
      case "confirm_reveal_ack":
      case "submit_card_select":
      case "submit_turn": {
        this.sendToToken(token, { type: "error", code: "not_implemented", message: "아직 구현되지 않은 기능입니다." });
        return;
      }

      default: {
        this.sendToToken(token, { type: "error", code: "unknown_message", message: "알 수 없는 메시지입니다." });
        return;
      }
    }
  }

  private async onSocketClosed(token: string): Promise<void> {
    const state = this.roomState!;
    const player = findPlayerByToken(state, token);
    if (player) {
      player.isConnected = false;
      player.lastSeenMs = nowMs();
    }

    this.socketsByToken.delete(token);

    // Disconnection rule:
    // - waiting: if host left -> close room
    // - otherwise: if in any game phase -> forfeit and go result
    if (player) {
      await this.handleDisconnect(player);
    }

    await this.persist();
    this.broadcastSnapshot();
  }

  private async handleLeave(player: PlayerRecord, reason: string): Promise<void> {
    // Explicit leave: close socket if exists
    const ws = this.socketsByToken.get(player.token);
    if (ws) {
      try {
        ws.close(1000, "leave_room");
      } catch {}
    }

    player.isConnected = false;

    await this.handleDisconnect(player);
    await this.persist();
    this.broadcastSnapshot();
  }

  private async handleDisconnect(player: PlayerRecord): Promise<void> {
    const state = this.roomState!;

    if (state.phase === RoomPhase.Waiting) {
      // host leaving before start closes room
      if (player.isHost) {
        this.broadcast({ type: "room_closed", reason: EndReason.HostLeft, message: "방장이 나가서 방이 종료되었습니다." });
        // clear state so future joins won't revive accidentally
        state.result = { reason: EndReason.HostLeft };
        // best-effort: close all sockets
        this.closeAllSockets(EndReason.HostLeft, "방장이 나가서 방이 종료되었습니다.");
        await this.state.storage.deleteAll();
        this.roomState = {
          roomCode: state.roomCode,
          phase: RoomPhase.Waiting,
          createdAtMs: nowMs(),
          players: [],
        };
        return;
      }

      // non-host leaving in waiting: keep room open for host
      this.broadcastSystemChat("상대 플레이어가 나갔습니다. 새로운 유저가 입장할 수 있습니다.");
      // remove the player record to allow new join
      state.players = state.players.filter((p) => p.token !== player.token);
      return;
    }

    // In game flow: forfeit and result
    if (state.phase !== RoomPhase.Result) {
      const winner = state.players.find((p) => p.token !== player.token);
      state.phase = RoomPhase.Result;
      state.result = {
        winnerSide: winner ? winner.side : undefined,
        reason: EndReason.Forfeit,
      };

      this.broadcastSystemChat("기권 처리되었습니다. 결과 화면으로 이동합니다.");
      this.broadcastSnapshot();
    }
  }

  private tryConsumeChatQuota(player: PlayerRecord): boolean {
    const now = nowMs();
    if (player.chatWindowStartMs === 0 || now - player.chatWindowStartMs > CHAT_RATE_LIMIT_WINDOW_MS) {
      player.chatWindowStartMs = now;
      player.chatCountInWindow = 0;
    }

    if (player.chatCountInWindow >= CHAT_RATE_LIMIT_MAX_COUNT) {
      return false;
    }

    player.chatCountInWindow += 1;
    return true;
  }

  private sendToToken(token: string, msg: ServerToClientMessage): void {
    const ws = this.socketsByToken.get(token);
    if (!ws) return;

    try {
      ws.send(JSON.stringify(msg));
    } catch {
      // ignore send errors
    }
  }

  private broadcast(msg: ServerToClientMessage): void {
    const text = JSON.stringify(msg);
    for (const ws of this.socketsByToken.values()) {
      try {
        ws.send(text);
      } catch {
        // ignore
      }
    }
  }

  private broadcastSnapshot(): void {
    const state = this.roomState!;
    this.broadcast({ type: "snapshot", snapshot: createSnapshot(state) });
  }

  private broadcastSystemChat(text: string): void {
    this.broadcast({ type: "chat", fromSide: "system", text, serverTimeMs: nowMs() });
  }

  private closeAllSockets(reason: EndReason, message: string): void {
    for (const ws of this.socketsByToken.values()) {
      try {
        ws.send(JSON.stringify({ type: "room_closed", reason, message } satisfies ServerToClientMessage));
      } catch {}
      try {
        ws.close(1001, "room_closed");
      } catch {}
    }
    this.socketsByToken.clear();
  }

  private ensureHeartbeat(): void {
    if (this.heartbeatTimer !== null) return;

    this.heartbeatTimer = setInterval(() => {
      try {
        this.tickHeartbeat();
      } catch {
        // ignore
      }
    }, HEARTBEAT_INTERVAL_MS) as unknown as number;
  }

  private tickHeartbeat(): void {
    const state = this.roomState;
    if (!state) return;

    const now = nowMs();
    // best-effort ping: Cloudflare WS doesn't expose ping API, so we can send a lightweight snapshot occasionally
    // but keep it minimal to avoid noise; here we do nothing aggressive.
    for (const p of state.players) {
      if (!p.isConnected) continue;
      p.lastSeenMs = now;
    }
  }

  private async persist(): Promise<void> {
    if (!this.roomState) return;
    await this.state.storage.put("roomState", this.roomState);
  }

  private json(data: unknown, status = 200): Response {
    return new Response(JSON.stringify(data), {
      status,
      headers: { "Content-Type": "application/json; charset=utf-8" },
    });
  }
}
