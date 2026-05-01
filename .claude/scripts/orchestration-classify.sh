#!/bin/bash
# orchestration-classify.sh — 작업 시작 시 자가 분류 자동 박제 (2026-05-02 묶음 O NEW-17)
#
# 동기 (HARNESS_FIELD_PATTERNS_4.md §15.7.4):
#   메인 Claude는 작업 시작 전 위임 매트릭스로 자가 분류해야 한다.
#   본 스크립트는 분류 결과를 jsonl로 자동 박제 (수동 메모리 박제 대체).
#   sensor-orchestration-ratio가 jsonl 합치율 측정.
#
# 사용:
#   bash .claude/scripts/orchestration-classify.sh \
#     --task "<작업명>" \
#     --time "<예상 시간 ex 30m / 1h / 2h>" \
#     --domain "<single .claude/ | single server | multi server+web | research/ ...>" \
#     --decision "<main | grimoire-server | grimoire-web | grimoire-qa | ...>" \
#     [--reason "<매트릭스 행 근거>"]
#
# 적재 위치:
#   .claude/state/orchestration-classifications.jsonl (한 줄 1 분류)
#
# Exit 0 PASS / 1 ERROR

set -u

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
STATE="$ROOT/.claude/state"
LOG="$STATE/orchestration-classifications.jsonl"

mkdir -p "$STATE"

TASK=""
TIME=""
DOMAIN=""
DECISION=""
REASON=""

while [ $# -gt 0 ]; do
  case "$1" in
    --task) TASK="$2"; shift 2 ;;
    --time) TIME="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --decision) DECISION="$2"; shift 2 ;;
    --reason) REASON="$2"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "❌ 알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

if [ -z "$TASK" ] || [ -z "$TIME" ] || [ -z "$DOMAIN" ] || [ -z "$DECISION" ]; then
  echo "❌ 필수: --task, --time, --domain, --decision"
  exit 1
fi

# 매트릭스 자가 합치 평가 (간단 휴리스틱 — §15.7.1)
EXPECTED="main"
case "$DOMAIN" in
  *"multi"*|*"server+web"*) EXPECTED="grimoire-server+grimoire-web" ;;
  *"single server"*)
    case "$TIME" in
      *"2h"*|*"3h"*|*"4h"*|*"5h"*|*"6h"*|*"7h"*|*"8h"*) EXPECTED="grimoire-server" ;;
      *) EXPECTED="main (조건부)" ;;
    esac
    ;;
  *"single web"*)
    case "$TIME" in
      *"2h"*|*"3h"*|*"4h"*|*"5h"*|*"6h"*|*"7h"*|*"8h"*) EXPECTED="grimoire-web" ;;
      *) EXPECTED="main (조건부)" ;;
    esac
    ;;
  *".claude/"*|*"docs/"*|*"research/"*|*"memory"*|*".githooks/"*) EXPECTED="main" ;;
  *) EXPECTED="main (default)" ;;
esac

# 합치 판정
MATCH="✅"
if [[ "$EXPECTED" != *"$DECISION"* ]] && [[ "$DECISION" != *"$EXPECTED"* ]]; then
  # 일부 패턴 (main vs main (조건부))은 호환
  case "$EXPECTED" in
    "main"|"main (조건부)"|"main (default)")
      [ "$DECISION" = "main" ] && MATCH="✅" || MATCH="⚠️"
      ;;
    *) MATCH="⚠️" ;;
  esac
fi

# JSON 박제 (BSD 호환, jq 없이)
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TASK_E=$(printf '%s' "$TASK" | sed 's/\\/\\\\/g; s/"/\\"/g')
TIME_E=$(printf '%s' "$TIME" | sed 's/"/\\"/g')
DOMAIN_E=$(printf '%s' "$DOMAIN" | sed 's/"/\\"/g')
DECISION_E=$(printf '%s' "$DECISION" | sed 's/"/\\"/g')
EXPECTED_E=$(printf '%s' "$EXPECTED" | sed 's/"/\\"/g')
REASON_E=$(printf '%s' "$REASON" | sed 's/\\/\\\\/g; s/"/\\"/g')

printf '{"ts":"%s","task":"%s","time":"%s","domain":"%s","decision":"%s","expected":"%s","match":"%s","reason":"%s"}\n' \
  "$TS" "$TASK_E" "$TIME_E" "$DOMAIN_E" "$DECISION_E" "$EXPECTED_E" "$MATCH" "$REASON_E" >> "$LOG"

# stdout
echo "$MATCH 자가 분류: $TASK ($TIME / $DOMAIN) → $DECISION (기대: $EXPECTED)"
[ -n "$REASON" ] && echo "   근거: $REASON"
echo "   적재: $LOG"

# sensor-log 박제 (sensor-hits.jsonl)
SLOG="$(dirname "$0")/sensor-log.sh"
[ -x "$SLOG" ] && bash "$SLOG" "orchestration-classify" PASS "task=$TASK match=$MATCH" 2>/dev/null || true

exit 0
