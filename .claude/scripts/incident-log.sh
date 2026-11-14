#!/bin/bash
# incident-log.sh — 시스템 실수/우회/발견 시계열 박제 (Mitchell Ghostty 패턴)
#
# 사용자 명시 (2026-05-06): "앞으로 모든 실수, 그게 툴이면 툴, 에이전트면 에이전트, 문서 누락이면 누락에,
# 실수가 발견된거든, 실수를 우회한 거든, 내가 지금처럼 발견한 거든 하나도 빼놓지 말고 나올 때마다 주제별로 다 기록해"
#
# 책 V1.1 정합:
#   - Mitchell Hashimoto Ghostty: "실수마다 규칙 1줄"
#   - Cuneiform Chat (Bikash Das): "팀의 기억"
#   - Anthropic Constitutional AI: 자기-비판 루프 결과 박제
#   - 책 Ch 23 안티패턴 #5 "하네스 부패" 방어
#
# 사용:
#   bash incident-log.sh <category> <severity> <source> <description> [resolution]
#
# Category (주제별):
#   tool        — 도구 결함 (sensor / hook / script)
#   agent       — 에이전트 호출 / 위임 결함
#   sensor      — sensor 측정 결함 (false negative / positive)
#   hook        — hook 발동 / 누락 / 충돌
#   skill       — skill 트리거 / paths 결함
#   doc         — 문서 누락 / 정본 동기화 누락
#   infra       — Azure / DB / 환경변수 / prod 영역
#   response    — 메인 Claude 응답 (거짓/추정/§0 위반)
#   workflow    — 작업 절차 우회 / 누락
#   security    — 보안 결함
#
# Severity:
#   info        — 발견만, 영향 작음
#   warn        — 잠재 영향, 보강 권장
#   error       — 실제 영향 발생, 즉시 수정 필요
#   critical    — §0 위반 / 보안 / 운영 영향 큰 결함
#
# Source:
#   user        — 사용자가 발견
#   sensor      — sensor가 자동 발견
#   self        — 메인 Claude 자가 발견
#   remote      — 다른 리모트 세션 발견
#
# Exit:
#   0 박제 성공 / 1 인자 부족 / 2 잘못된 카테고리/severity

set -uo pipefail

INCIDENT_LOG="/Users/sokol/Git/ProjectGrimoire/.claude/state/incident-log.jsonl"

if [ "$#" -lt 4 ]; then
  echo "Usage: incident-log.sh <category> <severity> <source> <description> [resolution]"
  echo "  category: tool|agent|sensor|hook|skill|doc|infra|response|workflow|security"
  echo "  severity: info|warn|error|critical"
  echo "  source: user|sensor|self|remote"
  exit 1
fi

CATEGORY="$1"
SEVERITY="$2"
SOURCE="$3"
DESCRIPTION="$4"
RESOLUTION="${5:-pending}"

# 카테고리 검증
case "$CATEGORY" in
  tool|agent|sensor|hook|skill|doc|infra|response|workflow|security) ;;
  *) echo "❌ 잘못된 category: $CATEGORY"; exit 2 ;;
esac

# severity 검증
case "$SEVERITY" in
  info|warn|error|critical) ;;
  *) echo "❌ 잘못된 severity: $SEVERITY"; exit 2 ;;
esac

# source 검증
case "$SOURCE" in
  user|sensor|self|remote) ;;
  *) echo "❌ 잘못된 source: $SOURCE"; exit 2 ;;
esac

mkdir -p "$(dirname "$INCIDENT_LOG")"

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_ID=$(basename "$(ls -t "$HOME/.claude/projects/-Users-sokol-Git-ProjectGrimoire/"*.jsonl 2>/dev/null | head -1)" .jsonl 2>/dev/null || echo "unknown")

# DESCRIPTION + RESOLUTION JSON-escape
DESC_ESC=$(echo "$DESCRIPTION" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read().rstrip()))')
RES_ESC=$(echo "$RESOLUTION" | python3 -c 'import sys, json; print(json.dumps(sys.stdin.read().rstrip()))')

printf '{"ts":"%s","category":"%s","severity":"%s","source":"%s","session":"%s","description":%s,"resolution":%s}\n' \
  "$TS" "$CATEGORY" "$SEVERITY" "$SOURCE" "$SESSION_ID" "$DESC_ESC" "$RES_ESC" \
  >> "$INCIDENT_LOG"

echo "✅ incident 박제: [$SEVERITY/$CATEGORY/$SOURCE] $DESCRIPTION"
echo "   파일: $INCIDENT_LOG"
