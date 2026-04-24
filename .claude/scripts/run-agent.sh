#!/bin/bash
# Grimoire 에이전트 래퍼 스크립트
# launchd plist에서 이 스크립트를 호출, 이 스크립트가 claude CLI 실행
# 네트워크 체크 + 재시도 3회 + 로그 보강
#
# 사용법: run-agent.sh <agent-name> <prompt-file> <allowed-tools>
# 예시:   run-agent.sh researcher /path/to/prompt.txt "Read,Write,Edit,Glob,Grep,WebSearch,WebFetch"

set -euo pipefail

AGENT_NAME="${1:?에이전트 이름 필요}"
PROMPT_FILE="${2:?프롬프트 파일 경로 필요}"
ALLOWED_TOOLS="${3:?allowedTools 필요}"

PROJECT_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire"
CLAUDE_BIN="/Users/sokol/.nvm/versions/node/v22.19.0/bin/claude"
LOG_DIR="$PROJECT_DIR/.launchd-logs"
MAX_RETRIES=3
RETRY_DELAY=30

# 로그 디렉토리 보장
mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$AGENT_NAME] $1" >> "$LOG_DIR/$AGENT_NAME.log"
}

# 네트워크 체크: Anthropic API 도메인 DNS 확인
check_network() {
  host api.anthropic.com >/dev/null 2>&1
}

log "=== 에이전트 시작 ==="

# 프롬프트 파일 존재 확인
if [ ! -f "$PROMPT_FILE" ]; then
  log "ERROR: 프롬프트 파일 없음 — $PROMPT_FILE"
  exit 1
fi

PROMPT=$(cat "$PROMPT_FILE")

# 네트워크 체크 + 재시도
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_RETRIES ]; do
  ATTEMPT=$((ATTEMPT + 1))

  if check_network; then
    log "네트워크 OK (시도 $ATTEMPT/$MAX_RETRIES)"
    break
  else
    log "WARN: 네트워크 불가 (시도 $ATTEMPT/$MAX_RETRIES)"
    if [ $ATTEMPT -lt $MAX_RETRIES ]; then
      log "  ${RETRY_DELAY}초 대기 후 재시도..."
      sleep $RETRY_DELAY
    else
      log "ERROR: 네트워크 $MAX_RETRIES회 실패 — 에이전트 실행 포기"
      exit 1
    fi
  fi
done

# Claude CLI 실행
log "claude CLI 실행 시작 (tools: $ALLOWED_TOOLS)"
cd "$PROJECT_DIR"

RESULT=$("$CLAUDE_BIN" -p "$PROMPT" --allowedTools "$ALLOWED_TOOLS" 2>&1) || {
  EXIT_CODE=$?
  log "ERROR: claude CLI 종료코드 $EXIT_CODE"
  log "OUTPUT: $(echo "$RESULT" | head -20)"
  exit $EXIT_CODE
}

# 성공 — 결과 요약 로그
LINES=$(echo "$RESULT" | wc -l)
log "claude CLI 정상 종료 (출력 ${LINES}줄)"
log "=== 에이전트 종료 ==="
