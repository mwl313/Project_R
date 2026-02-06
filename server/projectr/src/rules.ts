/**
 * 파일명: rules.ts
 * 모듈명: Rules
 *
 * 역할:
 * - 서버 공통 룰/상수 정의
 * - 채팅 스팸 방지 등 서버 정책 관리
 *
 * 외부에서 사용 가능한 항목:
 * - RULES
 *
 * 주의:
 * - 모든 수치는 나중에 쉽게 조정 가능해야 한다.
 */

export const RULES = {
  chat: {
    windowMs: 3000,
    maxMessagesPerWindow: 3,
    maxChars: 120,
  },
} as const;
