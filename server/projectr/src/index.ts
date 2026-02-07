/**
 * File: index.ts
 * Module: WorkerEntrypoint
 *
 * Responsibilities:
 * - HTTP routing (create/join/health)
 * - WebSocket upgrade routing to Durable Object instance
 * - Room code generation (server-generated, sent to client)
 *
 * Endpoints:
 * - GET  /health
 * - POST /room/create   -> { roomCode, token, wsUrl }
 * - POST /room/join     -> { roomCode, token, wsUrl }
 * - GET  /ws?code=XXXXX&token=YYYY  (WS upgrade, forwarded to DO)
 */

import { RoomDO } from "./room_do";
import { ROOM_CODE_ALPHABET, ROOM_CODE_LENGTH, isValidRoomCode, normalizeRoomCode } from "./rules";

export interface Env {
  ROOM: DurableObjectNamespace<RoomDO>;
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function randomToken(): string {
  const buf = new Uint8Array(16);
  crypto.getRandomValues(buf);
  return Array.from(buf).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function randomRoomCode(): string {
  const buf = new Uint8Array(ROOM_CODE_LENGTH);
  crypto.getRandomValues(buf);

  let code = "";
  for (let i = 0; i < ROOM_CODE_LENGTH; i++) {
    const idx = buf[i] % ROOM_CODE_ALPHABET.length;
    code += ROOM_CODE_ALPHABET[idx];
  }
  return code;
}

function isWsUpgrade(request: Request): boolean {
  const upgrade = request.headers.get("Upgrade");
  return upgrade !== null && upgrade.toLowerCase() === "websocket";
}

export { RoomDO };

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true });
    }

    if (request.method === "POST" && url.pathname === "/room/create") {
      // Create: generate roomCode and token
      // Note: collisions are extremely unlikely; if you want strict uniqueness, loop + check can be added later.
      const roomCode = randomRoomCode();
      const token = randomToken();

      const id = env.ROOM.idFromName(roomCode);
      const stub = env.ROOM.get(id);

      // initialize DO storage
      await stub.fetch("https://do/do/init", {
        method: "POST",
        body: JSON.stringify({ roomCode }),
        headers: { "Content-Type": "application/json" },
      });

      // pre-join so DO registers p1/host
      await stub.fetch("https://do/do/join", {
        method: "POST",
        body: JSON.stringify({ roomCode, token, nickname: "" }),
        headers: { "Content-Type": "application/json" },
      });

      const wsUrl = `/ws?code=${encodeURIComponent(roomCode)}&token=${encodeURIComponent(token)}`;
      return json({ ok: true, roomCode, token, wsUrl });
    }

    if (request.method === "POST" && url.pathname === "/room/join") {
      const payload = (await request.json().catch(() => null)) as any;
      const codeRaw = typeof payload?.roomCode === "string" ? payload.roomCode : "";
      const nickname = typeof payload?.nickname === "string" ? payload.nickname : "";

      const roomCode = normalizeRoomCode(codeRaw);
      if (!isValidRoomCode(roomCode)) {
        return json({ ok: false, error: "invalid_room_code" }, 400);
      }

      const token = randomToken();

      const id = env.ROOM.idFromName(roomCode);
      const stub = env.ROOM.get(id);

      const joinRes = await stub.fetch("https://do/do/join", {
        method: "POST",
        body: JSON.stringify({ roomCode, token, nickname }),
        headers: { "Content-Type": "application/json" },
      });

      if (!joinRes.ok) {
        const body = await joinRes.text();
        return new Response(body, { status: joinRes.status });
      }

      const wsUrl = `/ws?code=${encodeURIComponent(roomCode)}&token=${encodeURIComponent(token)}`;
      return json({ ok: true, roomCode, token, wsUrl });
    }

    if (request.method === "GET" && url.pathname === "/ws" && isWsUpgrade(request)) {
      // Forward WS upgrade to DO (per room code)
      const codeRaw = url.searchParams.get("code") || "";
      const token = url.searchParams.get("token") || "";
      const roomCode = normalizeRoomCode(codeRaw);

      if (!token || !isValidRoomCode(roomCode)) {
        return new Response("bad ws params", { status: 400 });
      }

      const id = env.ROOM.idFromName(roomCode);
      const stub = env.ROOM.get(id);

      return stub.fetch(request);
    }

    return new Response("Not Found", { status: 404 });
  },
};
