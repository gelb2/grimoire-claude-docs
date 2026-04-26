#!/usr/bin/env bash
# posttooluse-failure-handler.sh — PostToolUseFailure hook (HARNESS Phase 4 #5 F2)
#
# 동작 (Claude Code 공식 명세):
#   - 도구 호출 실패 시 자동 발동
#   - stdin: JSON {tool_name, tool_input, tool_use_id, error, is_interrupt, duration_ms}
#   - stdout: JSON {decision: "block"|"continue", additionalContext: "재시도 안내..."}
#   - 자동 재시도는 미지원 — additionalContext로 Claude에게 신호만 전달
#
# 정책 (사용자 안전 정책 준수):
#   - Claude_in_Chrome MCP 실패 시: 1회 재시도 신호 (3초 대기 권장 박제)
#   - reCAPTCHA 의심 단어 (recaptcha/captcha/bot/robot) 발견 시: 즉시 사용자 알림
#     (CLAUDE.md §0 "reCAPTCHA 때문에 테스트 스킵 금지" + 봇 차단 우회 방지)
#   - prod 도메인 (grimoire-book.com) 실패 시: 자동 재시도 안 함 (사용자 직접 검증 권장)
#   - 기타 도구 실패: 정보만 적재 (추가 액션 없음)

set +u

LOG_DIR="/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/state"
mkdir -p "$LOG_DIR"

INPUT_JSON=$(cat 2>/dev/null)
[ -z "$INPUT_JSON" ] && exit 0

export INPUT_JSON

python3 <<'PYEOF'
import json, os, sys
from datetime import datetime

try:
    payload = json.loads(os.environ.get('INPUT_JSON', '{}'))
except Exception:
    sys.exit(0)

tool_name = payload.get('tool_name', 'unknown')
tool_input = payload.get('tool_input', {})
error = payload.get('error', '') or ''
duration_ms = payload.get('duration_ms', 0)
is_interrupt = payload.get('is_interrupt', False)

# 1. 적재 (모든 실패 박제)
ts = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
entry = {
    'ts': ts,
    'tool': tool_name,
    'error': error[:200] if error else '',
    'duration_ms': duration_ms,
    'is_interrupt': is_interrupt,
}
LOG_FILE = '/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/state/tool-failures.jsonl'
try:
    with open(LOG_FILE, 'a') as f:
        f.write(json.dumps(entry, ensure_ascii=False) + '\n')
except Exception:
    pass

# 사용자 인터럽트는 처리 안 함
if is_interrupt:
    sys.exit(0)

# Chrome MCP 실패 처리
is_chrome_mcp = (
    tool_name.startswith('mcp__Claude_in_Chrome__') or
    'claude_in_chrome' in tool_name.lower()
)

if is_chrome_mcp:
    # reCAPTCHA / 봇 차단 의심 단어 검출
    risk_keywords = ['recaptcha', 'captcha', 'bot detect', 'robot check', 'are you human', 'unverified']
    error_lower = error.lower()
    has_bot_risk = any(kw in error_lower for kw in risk_keywords)

    # prod 도메인 검출
    target_url = ''
    if isinstance(tool_input, dict):
        target_url = str(tool_input.get('url', ''))
    is_prod = (
        'grimoire-book.com' in target_url and
        'dev.grimoire' not in target_url and
        'dev-api' not in target_url
    )

    if has_bot_risk:
        msg = ('⚠️ Chrome MCP 실패 (' + tool_name + '): reCAPTCHA/봇 차단 의심 키워드 감지. '
               'CLAUDE.md §0 정책 — 자동 재시도 안 함. 사용자 직접 통과 필요. '
               'error: ' + error[:120])
        print(json.dumps({
            'decision': 'block',
            'reason': msg,
            'additionalContext': msg
        }))
        sys.exit(0)

    if is_prod:
        msg = ('⚠️ Chrome MCP prod 도메인 (' + target_url + ') 실패. '
               '자동 재시도 안 함. 사용자 직접 검증 권장. '
               'error: ' + error[:120])
        print(json.dumps({
            'decision': 'block',
            'reason': msg,
            'additionalContext': msg
        }))
        sys.exit(0)

    # dev 또는 일반 환경 → 1회 재시도 신호
    msg = ('Chrome MCP 1회 실패 (' + tool_name + '). 3초 대기 후 1회 재시도 권장 '
           '(claude-in-chrome-recovery skill 절차 적용). error: ' + error[:120])
    print(json.dumps({
        'additionalContext': msg
    }))
    sys.exit(0)

# Chrome 외 도구 실패: 적재만, 추가 액션 없음
sys.exit(0)
PYEOF

exit 0
