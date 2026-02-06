/**
 * 파일명: protocol.ts
 * 모듈명: Protocol
 *
 * 역할:
 * - 클라이언트 ↔ 서버 간 메시지 타입 정의
 * - JSON 파싱 및 최소 검증
 *
 * 외부에서 사용 가능한 함수:
 * - parseClientMessage(text)
 * - buildServerEvent(type, payload)
 *
 * 주의:
 * - 이 단계에서는 "가벼운 검증"만 수행한다.
 */

export type ClientMessage =
  | { type: "room.join"; payload: { playerId: string; nickname: string } }
  | { type: "chat.send"; payload: { text: string } }
  | { type: "placement.submit"; payload: { stones: Array<{ x: number; y: number }> } }
  | { type: "ability.pick"; payload: { chosen: string[] } }
  | { type: "game.fire"; payload: { stoneId: string; dx: number; dy: number; power: number } }
  | { type: "game.snapshot"; payload: { turnId: number; snapshot: unknown } }
  | { type: "game.resign"; payload: Record<string, never> };

export type ServerEvent = {
  type: string;
  payload?: unknown;
};

export function buildServerEvent(type: string, payload?: unknown): ServerEvent {
  return { type, payload };
}

export function parseClientMessage(text: string): ClientMessage | null {
  if (!text) {
    return null;
  }

  let obj: unknown;
  try {
    obj = JSON.parse(text);
  } catch {
    return null;
  }

  if (!obj || typeof obj !== "object") {
    return null;
  }

  const msg = obj as { type?: unknown };
  if (typeof msg.type !== "string") {
    return null;
  }

  return obj as ClientMessage;
}
