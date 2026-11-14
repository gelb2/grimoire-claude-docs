#!/usr/bin/env bash
# sensor-log.sh — sensor 실행 결과를 jsonl로 적재 (hit-rate 측정 인프라)
#
# 사용 (2가지 모드):
#   bash sensor-log.sh <sensor-name> <exit-code> [<extra>]    # exit code 모드 (0=PASS / 1=FAIL / 2=WARN)
#   bash sensor-log.sh <sensor-name> <PASS|WARN|FAIL> [<extra>]  # 명시 result 모드 (2026-05-02 H8 추가)
#
# 사유 (H8): 일부 sensor는 exit code 컨벤션이 다름 (1=WARN, 2=FAIL — agent-priority-labels / eval-trend 등).
# 명시 result 모드를 사용하면 exit code 매핑 충돌을 회피. 기존 호출자 (sensor-cost-margin / sensor-deploy-drift)는 호환.
#
# 예:
#   bash sensor-log.sh sensor-secret-leak 0 "FAIL=0 WARN=0"      # exit 0 → PASS
#   bash sensor-log.sh sensor-eval-trend WARN "회귀 30%"          # 명시 WARN
#
# 적재 위치:
#   .claude/state/sensor-hits.jsonl (한 줄 1 이벤트)
#
# 집계는 별도 (sensor-hit-rate-report.sh 또는 jq 조합)

set -u

NAME="${1:-unknown}"
EXIT_CODE="${2:-?}"
EXTRA="${3:-}"

LOG_DIR="/Users/sokol/Git/ProjectGrimoire/.claude/state"
LOG_FILE="$LOG_DIR/sensor-hits.jsonl"

mkdir -p "$LOG_DIR"

# 7일 TTL prune (LRU): 7일 이전 라인만 보존된 새 파일로 교체
#
# 2026-06-01 수정 (P0 근본원인): 기존 awk 3-인자 match($0, re, arr) 는 GNU awk(gawk) 전용 확장으로
# macOS 기본 /usr/bin/awk(BSD awk)에서 syntax error → exit 2 → 빈 TMP 생성 + `&&` 단락으로 mv 미실행
# → .tmp.<PID> 빈 파일 무한 누적(25k+) + prune 영구 미작동(jsonl 무한증가). 두 결함의 단일 근본원인.
# 수정: ① 2-인자 match()+substr 로 BSD awk 호환(gawk 의존 제거) ② `&&` 단락 제거(prune 항상 적용)
#       ③ EXIT trap 으로 어떤 경로(awk 실패/중단/시그널)로도 TMP 잔존 방지.
if [ -f "$LOG_FILE" ]; then
  CUTOFF=$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "7 days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  if [ -n "$CUTOFF" ]; then
    TMP="$LOG_FILE.tmp.$$"
    # 재발 방지 가드: 정상/비정상 종료 어느 쪽이든 TMP 가 남지 않도록 EXIT 시 정리.
    trap 'rm -f "$TMP" 2>/dev/null' EXIT
    # BSD awk 호환: 2-인자 match() 가 RSTART/RLENGTH 설정 → substr 로 ts 값 추출.
    #   매치 패턴 "ts":"<value>" 에서 앞 6글자('"ts":"')와 뒤 1글자('"') 를 제외해 value 만 취득.
    if awk -v c="$CUTOFF" '
      {
        if (match($0, /"ts":"[^"]+"/)) {
          ts = substr($0, RSTART + 6, RLENGTH - 7)
          if (ts >= c) print
        }
      }
    ' "$LOG_FILE" > "$TMP" 2>/dev/null; then
      # awk 성공 시에만 교체 (실패 시 원본 보존 — 데이터 유실 방지). mv 성공하면 TMP 소멸.
      mv "$TMP" "$LOG_FILE"
    fi
    # mv 후 TMP 가 원본으로 이동했어도, 또는 awk 실패로 TMP 가 남았어도 trap 이 잔존분 정리.
  fi
fi

# 새 이벤트 append
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
case "$EXIT_CODE" in
  PASS|WARN|FAIL|UNKNOWN)  # 명시 result 모드 (H8)
    RESULT="$EXIT_CODE"
    EXIT_CODE_NUM="null"  # JSON null (exit code 미상)
    ;;
  0) RESULT="PASS"; EXIT_CODE_NUM="$EXIT_CODE" ;;
  1) RESULT="FAIL"; EXIT_CODE_NUM="$EXIT_CODE" ;;
  2) RESULT="WARN"; EXIT_CODE_NUM="$EXIT_CODE" ;;
  *)
    # 숫자가 아니면 null + UNKNOWN
    if [ "$EXIT_CODE" = "?" ] || ! [ "$EXIT_CODE" -eq "$EXIT_CODE" ] 2>/dev/null; then
      RESULT="UNKNOWN"; EXIT_CODE_NUM="null"
    else
      RESULT="UNKNOWN"; EXIT_CODE_NUM="$EXIT_CODE"
    fi
    ;;
esac
EXIT_CODE="$EXIT_CODE_NUM"

# extra 이스케이프: JSON 유효성을 위해 백슬래시 → 탭/CR(제어문자) → 큰따옴표 순서로 처리.
# 2026-06-01: 기존엔 백슬래시/큰따옴표만 처리해 호출자가 extra 에 탭(\t)을 넘기면 raw 제어문자가
# 섞여 깨진 JSON 라인이 적재됐음(예: sensor-red-team-source-whitelist). 탭/CR 을 추가 escape.
EXTRA_ESCAPED=$(printf '%s' "$EXTRA" | sed 's/\\/\\\\/g; s/	/\\t/g; s/'"$(printf '\r')"'/\\r/g; s/"/\\"/g')

printf '{"ts":"%s","sensor":"%s","exit":%s,"result":"%s","extra":"%s"}\n' \
  "$TS" "$NAME" "$EXIT_CODE" "$RESULT" "$EXTRA_ESCAPED" >> "$LOG_FILE"

exit 0
