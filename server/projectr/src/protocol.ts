/**
 * File: protocol.ts
 * Module: Protocol
 *
 * Responsibilities:
 * - Defines client<->server message shapes for WebSocket
 * - Keeps protocol stable and explicit (no magic strings in logic)
 *
 * Public exports:
 * - ClientToServerMessage, ServerToClientMessage unions
 * - Helper types for room snapshots
 */

import { EndReason, RoomPhase } from "./rules";

export type PlayerSide = "p1" | "p2";

export interface PlayerPublic {
  side: PlayerSide;
  nickname: string;
  isHost: boolean;
  isConnected: boolean;
}

export interface RoomSnapshot {
  roomCode: string;
  phase: RoomPhase;
  players: PlayerPublic[];
  serverTimeMs: number;
  result?: {
    winnerSide?: PlayerSide;
    reason: EndReason;
  };
}

export type ClientToServerMessage =
  | { type: "hello"; token: string; nickname?: string }
  | { type: "chat"; text: string }
  | { type: "start_game" }
  | { type: "leave_room" }
  // placeholders for next steps (Phase 3-2/3-3/3-4/playing)
  | { type: "submit_placement"; placements: unknown }
  | { type: "confirm_reveal_ack" }
  | { type: "submit_card_select"; selected: unknown }
  | { type: "submit_turn"; turn: unknown };

export type ServerToClientMessage =
  | { type: "hello_ok"; snapshot: RoomSnapshot; yourSide: PlayerSide; yourToken: string }
  | { type: "snapshot"; snapshot: RoomSnapshot }
  | { type: "chat"; fromSide: PlayerSide | "system"; text: string; serverTimeMs: number }
  | { type: "error"; code: string; message: string }
  | { type: "room_closed"; reason: EndReason; message: string };
