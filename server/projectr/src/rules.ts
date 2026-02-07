/**
 * File: rules.ts
 * Module: Rules
 *
 * Responsibilities:
 * - Server-side constants and validation helpers
 * - Room/game state enums (authoritative)
 * - Chat anti-spam parameters (tunable)
 *
 * Public exports:
 * - ROOM_CODE_LENGTH
 * - ROOM_CODE_ALPHABET
 * - MAX_PLAYERS
 * - CHAT_RATE_LIMIT_* constants
 * - RoomPhase, EndReason
 * - clampInt, nowMs
 * - isValidRoomCode, normalizeRoomCode
 */

export const ROOM_CODE_LENGTH = 5;
export const ROOM_CODE_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

export const MAX_PLAYERS = 2;

export const CHAT_RATE_LIMIT_WINDOW_MS = 6_000; // 6 seconds
export const CHAT_RATE_LIMIT_MAX_COUNT = 3; // max messages per window
export const CHAT_TEXT_MAX_LEN = 120;

export const HEARTBEAT_INTERVAL_MS = 15_000;

export enum RoomPhase {
  Waiting = "waiting",
  Placing = "placing",
  Reveal = "reveal",
  CardSelect = "card_select",
  Playing = "playing",
  Result = "result",
}

export enum EndReason {
  Normal = "normal",
  Forfeit = "forfeit",
  HostLeft = "host_left",
  Error = "error",
}

export function nowMs(): number {
  return Date.now();
}

export function clampInt(value: number, minValue: number, maxValue: number): number {
  if (!Number.isFinite(value)) return minValue;
  if (value < minValue) return minValue;
  if (value > maxValue) return maxValue;
  return Math.floor(value);
}

export function normalizeRoomCode(input: string): string {
  return (input || "").trim().toUpperCase();
}

export function isValidRoomCode(input: string): boolean {
  const code = normalizeRoomCode(input);
  if (code.length !== ROOM_CODE_LENGTH) return false;

  for (let i = 0; i < code.length; i++) {
    if (!ROOM_CODE_ALPHABET.includes(code[i])) return false;
  }
  return true;
}

export function isValidChatText(text: string): boolean {
  const trimmed = (text || "").trim();
  if (trimmed.length === 0) return false;
  if (trimmed.length > CHAT_TEXT_MAX_LEN) return false;
  return true;
}
