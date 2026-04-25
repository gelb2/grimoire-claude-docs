#!/usr/bin/env bash
# sensor-orchestration-ratio.sh — 패턴 1 (오케스트레이션 분리) 측정 sensor
#
# 측정 정의 (2026-04-25 세션 #7 신설, 초기 버전):
#   orchestration_ratio = (subagent 호출 횟수) / (메인 직접 코드 작업 횟수)
#
# 데이터 소스:
#   - 메인 직접 코드 작업: post-edit-tsc.sh가 적재한 sensor-hits.jsonl 항목 중
#     "sensor":"sensor-server"|"sensor-web" 또는 post-edit-tsc 자체 발동 카운트
#   - subagent 호출: transcript_path를 파싱해서 Task tool 호출 카운트
#     (현 단계에선 측정 어려움 → placeholder)
#
# 현 단계 (P1):
#   - sensor 자체는 작동하나 정확한 KPI 산출은 P2 단계 (transcript 파싱 추가)
#   - 일단 sensor-hits.jsonl에서 메인 작업 횟수만 카운트 + 추정치 출력
#
# 다음 단계 (P2):
#   - transcript_path를 stdin JSON에서 받아 Task 호출 카운트 추출
#   - 정확한 ratio 계산
#
# Fowler "Steering Loop" 효과 측정 (HARNESS §3) — 패턴 1 KPI

set -u

LOG_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/state"
HITS_FILE="$LOG_DIR/sensor-hits.jsonl"
RATIO_FILE="$LOG_DIR/orchestration-ratio.jsonl"

mkdir -p "$LOG_DIR"

echo "=== Orchestration Ratio Sensor (P1 placeholder) ==="
echo "측정 시점: $(date +'%Y-%m-%d %H:%M:%S')"
echo ""

if [ ! -f "$HITS_FILE" ]; then
  echo "[orchestration-ratio] sensor-hits.jsonl 없음. sensor-log.sh로 적재 시작 후 측정 가능."
  exit 0
fi

# 메인 직접 작업 추정 (post-edit-tsc + post-edit-spec-check 발동 카운트)
MAIN_EDITS=$(grep -c "\"sensor\":\"post-edit" "$HITS_FILE" 2>/dev/null) || MAIN_EDITS=0

# subagent 호출 (현 단계 측정 불가 — placeholder)
SUBAGENT_CALLS="?"

echo "최근 7일 (sensor-log.sh prune):"
echo "  메인 직접 코드 작업 (post-edit-* 발동): $MAIN_EDITS"
echo "  subagent 호출 횟수: $SUBAGENT_CALLS (P2 transcript 파싱 후 측정)"
echo ""

if [ "$MAIN_EDITS" -gt 0 ]; then
  echo "  메인 작업 수 PASS — 데이터 적재 중"
else
  echo "  ⚠️ post-edit-* sensor 적재 0건 — sensor-log.sh가 post-edit-tsc.sh / post-edit-spec-check.sh에 호출되어야 측정 가능"
fi

echo ""
echo "[기록] $RATIO_FILE"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"ts":"%s","main_edits":%s,"subagent_calls":"%s","status":"P1_placeholder"}\n' "$TS" "$MAIN_EDITS" "$SUBAGENT_CALLS" >> "$RATIO_FILE"

echo "=== 끝 ==="
echo ""
echo "다음 진화 (P2 후보):"
echo "  - post-edit-tsc.sh / post-edit-spec-check.sh에 sensor-log.sh append 호출 추가"
echo "  - transcript_path 파싱으로 Task 호출 카운트 추출 (정확한 ratio)"
echo "  - 주간 집계 (sensor-hit-rate-report.sh와 통합)"

exit 0
