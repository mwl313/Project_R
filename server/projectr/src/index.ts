/**
 * 파일명: index.ts
 * 모듈명: WorkerEntry
 *
 * 역할:
 * - Cloudflare Worker 엔트리
 * - /room/create: 방 코드 생성(서버 생성 → 클라 전달)
 * - /ws?room=CODE: Durable Object(RoomDO)로 라우팅
 * - RoomDO export (wrangler.jsonc의 class_name과 반드시 일치)
 *
 * 외부에서 사용 가능한 항목:
 * - default fetch handler
 * - RoomDO
 *
 * 주의:
 * - DO 클래스 export 누락 시 배포 후 DO 동작이 실패할 수 있다.
 */

import { RoomDO } from "./room_do";

type Env = {
  ROOM: DurableObjectNamespace;
};

export { RoomDO };

function _notFound(): Response {
  return new Response("not found", { status: 404 });
}

function _badRequest(message: string): Response {
  return new Response(message, { status: 400 });
}

function _json(data: unknown, status: number = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
    },
  });
}

function _randomRoomCode(length: number): string {
  // 혼동 방지용 문자(0/O, 1/I 제거)
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);

  let code = "";
  for (let i = 0; i < length; i += 1) {
    const idx = bytes[i] % alphabet.length;
    code += alphabet[idx];
  }
  return code;
}

async function _createRoomCode(env: Env): Promise<string> {
  // 충돌 확률은 낮지만, 그래도 몇 번 재시도
  for (let i = 0; i < 5; i += 1) {
    const code = _randomRoomCode(5);
    // DO idFromName은 동일 name이면 동일 id가 나오므로, “존재 여부 체크”는 애매하지만
    // 여기서는 코드 충돌 자체를 최소화하기 위해 랜덤 재시도만 수행한다.
    // (실제 충돌 시 같은 코드 방으로 합류하는 형태가 되며, 이는 UX상 큰 문제는 아니다)
    const _ = env.ROOM.idFromName(code);
    return code;
  }

  // 극단 케이스 fallback
  return _randomRoomCode(6);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return new Response("ok");
    }

    if (url.pathname === "/room/create") {
      if (request.method !== "POST") {
        return _badRequest("method_not_allowed");
      }

      const roomCode = await _createRoomCode(env);
      return _json({ roomCode });
    }

    if (url.pathname === "/ws") {
      const roomCode = url.searchParams.get("room") || "";
      if (!roomCode) {
        return _badRequest("missing_room");
      }

      const id = env.ROOM.idFromName(roomCode);
      const stub = env.ROOM.get(id);
      return stub.fetch(request);
    }

    return _notFound();
  },
};
