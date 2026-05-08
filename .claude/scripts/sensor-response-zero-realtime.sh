#!/bin/bash
# sensor-response-zero-realtime.sh — 메인 Claude 응답 시점 §0 ZERO-TOLERANCE 위반 검출
#
# 사용자 명시 (2026-05-06): "응답 시점 추정 패턴 차단" — sensor-adversarial P1은 commit 메시지만 검사,
# 응답 텍스트는 무방위 → 본 sensor가 보강.
#
# 검사 영역:
#   1. 응답 텍스트 (UserPromptSubmit / 응답 직후 stdout)
#   2. 추정 키워드 + 직접 명령 출력 동반 0건이면 STOP
#
# 검출 패턴 (책 V1.1 §0 정합):
#   - "추정/추측/아마/가능성/의심/probably/maybe/likely"
#   - "...일 것이다 / ...로 보인다 / ...할 것 같다"
#   - "확인 안 함 / 검증 안 됨 / 미확인"
#
# 직접 명령 출력 동반 검증:
#   응답에 추정 키워드 ≥1건 + 다음 중 1건이라도 동반 = PASS
#   - 명령 실행 결과 ($, >>, exit code)
#   - 직접 검증 데이터 (curl HTTP=, az output, jest test result)
#   - 실측 박제 파일 경로
#
# 신설: 2026-05-06 묶음 LL — Constitution P1 후방위 보강 (응답 시점 검출)

set -uo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: sensor-response-zero-realtime.sh <response-text-file>"
  echo "  또는 stdin으로 응답 텍스트 입력"
  exit 1
fi

RESPONSE_FILE="${1:-/dev/stdin}"

if [ ! -r "$RESPONSE_FILE" ]; then
  echo "❌ 응답 파일 읽기 실패: $RESPONSE_FILE"
  exit 1
fi

# 추정 키워드 검출
GUESS_PATTERNS="추정|추측|아마|가능성|의심|probably|maybe|likely|일 것이다|로 보인다|할 것 같다|확인 안|검증 안|미확인"

# 직접 명령 출력 동반 검증
EVIDENCE_PATTERNS='\$ |>>>|exit code|HTTP=|TIME=|test result|jest|prisma|az containerapp|curl --max-time|/usr/bin/'

GUESS_COUNT=$(grep -cE "$GUESS_PATTERNS" "$RESPONSE_FILE" 2>/dev/null | head -1 | tr -d ' \n')
EVIDENCE_COUNT=$(grep -cE "$EVIDENCE_PATTERNS" "$RESPONSE_FILE" 2>/dev/null | head -1 | tr -d ' \n')

GUESS_COUNT=${GUESS_COUNT:-0}
EVIDENCE_COUNT=${EVIDENCE_COUNT:-0}

echo "=== sensor-response-zero-realtime ==="
echo "추정 키워드 검출: ${GUESS_COUNT}건"
echo "직접 명령 출력 동반: ${EVIDENCE_COUNT}건"
echo ""

if [ "$GUESS_COUNT" -gt 0 ] && [ "$EVIDENCE_COUNT" -eq 0 ]; then
  echo "🚨 STOP — 추정 키워드 ${GUESS_COUNT}건 + 직접 명령 출력 0건 = §0 ZERO-TOLERANCE 위반"
  echo ""
  echo "차단 사유:"
  grep -nE "$GUESS_PATTERNS" "$RESPONSE_FILE" 2>/dev/null | head -5
  echo ""
  echo "조치 (강제):"
  echo "  1. 추정 영역 직접 명령 실행 (curl/az/jest/prisma 등)"
  echo "  2. 출력 박제 후 응답 재작성"
  echo "  3. incident-log.sh response critical self '...' 박제"

  # incident-log 자동 박제
  bash "$(dirname "$0")/incident-log.sh" response critical sensor \
    "응답 시점 §0 위반 검출: 추정 키워드 ${GUESS_COUNT}건, 직접 명령 출력 0건" \
    "응답 재작성 + 직접 명령 출력 동반 강제" 2>/dev/null || true

  exit 2
elif [ "$GUESS_COUNT" -gt 0 ]; then
  echo "⚠️ WARN — 추정 키워드 ${GUESS_COUNT}건 (직접 명령 출력 ${EVIDENCE_COUNT}건 동반, 정합)"
  exit 1
else
  echo "✅ PASS — 추정 키워드 0건"
  exit 0
fi
