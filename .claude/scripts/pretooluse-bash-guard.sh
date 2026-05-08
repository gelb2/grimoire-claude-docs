#!/bin/sh
# pretooluse-bash-guard.sh — PreToolUse hook (matcher: Bash)
#
# 동작:
# 1) stdin JSON에서 tool_input.command 추출
# 2) 위험 명령 패턴 매칭 시 exit 2 + stderr 사유 출력 → 도구 실행 차단
# 3) 매칭 없으면 exit 0으로 허용
#
# 차단 대상 (CLAUDE.md §8 절대 금지 + 기타 destructive):
# - git push origin main (직접 push)
# - git push -f / --force (force push)
# - git reset --hard (검증 없이)
# - git push --force-with-lease origin main
# - rm -rf / (루트 삭제)
# - git checkout -- * (전체 파일 복원)
#
# Fowler "PreToolUse hook — regulate before action" 원칙

set +e

INPUT_JSON=$(cat 2>/dev/null)
[ -z "$INPUT_JSON" ] && exit 0

export INPUT_JSON

python3 - <<'PYEOF'
import json
import os
import re
import sys

try:
    payload = json.loads(os.environ.get('INPUT_JSON', '{}'))
except Exception:
    sys.exit(0)

tool_name = payload.get('tool_name', '')
tool_input = payload.get('tool_input') or {}

# Bash 이외 도구는 관심 없음
if tool_name != 'Bash':
    sys.exit(0)

command = tool_input.get('command', '') or ''
if not command:
    sys.exit(0)

# 위험 패턴 정의 (Grimoire 정책 기반)
DANGEROUS = [
    # CLAUDE.md §8 — main 직접 push 절대 금지
    (r'\bgit\s+push\s+(-[a-zA-Z]+\s+)*origin\s+main\b', 'main 브랜치 직접 push는 CLAUDE.md §8 절대 금지 규정 위반입니다. develop→main 머지는 사용자 명시 승인 후에만 가능.'),
    (r'\bgit\s+push\s+.*?--force.*?\s+main\b', 'main에 force push 금지 (CLAUDE.md §8).'),
    (r'\bgit\s+push\s+.*?-f\s+.*?\s+main\b', 'main에 force push 금지.'),

    # destructive 일반
    (r'\bgit\s+reset\s+--hard\b', 'git reset --hard는 작업 내용을 복구 불가로 삭제합니다. 사용자 명시 승인 없으면 차단.'),
    (r'\brm\s+-rf\s+/\s*($|\s)', 'rm -rf / 는 시스템 파괴 명령입니다. 차단.'),
    (r'\brm\s+-rf\s+/\*', 'rm -rf /* 는 시스템 파괴 명령입니다. 차단.'),
    (r'\brm\s+-rf\s+\$HOME\b', '홈 디렉토리 삭제 차단.'),
    (r'\brm\s+-rf\s+~/?\s*($|\s)', '홈 디렉토리 삭제 차단.'),

    # git 저장소 파괴
    (r'\bgit\s+checkout\s+--\s+\.\s*($|\s)', 'git checkout -- . 은 전체 미커밋 변경을 삭제합니다. 차단.'),
    (r'\bgit\s+clean\s+-f(d)?x?\b', 'git clean -f 는 untracked 파일 영구 삭제. 사용자 승인 없으면 차단.'),

    # main push 우회 (HEAD:main / develop:main 등) — 5/8 prod revision 97 사고 후속
    (r'\bgit\s+push\s+(-[a-zA-Z]+\s+)*origin\s+\S+:main\b', 'HEAD:main / develop:main 등 우회 push 차단 — main 머지/배포는 grimoire-infrastructure agent + 사용자 per-repo 명시 영역.'),

    # 인프라 mutation — grimoire-infrastructure agent 위임 강제 (5/8 INFRA-1 사고 + 본 세션 베이비시팅 결함)
    # 사용자 명시 (2026-05-08): "메인은 그냥 시발 아무것도 못 하게 권한 박아버려"
    (r'\b(make|bash\s+scripts/)\s*deploy-(prod|dev|inhouse)', 'deploy-* mutation은 grimoire-infrastructure agent 위임 강제. 메인 직접 = 베이비시팅 (4/18 수동 배포 1차 + 5/8 prod revision 97 사고 박제 정면 위배). Task tool subagent_type=grimoire-infrastructure로 위임 후 진행.'),
    (r'\baz\s+containerapp\s+(update|create|delete|revision\s+activate|revision\s+deactivate|revision\s+copy)\b', 'az containerapp mutation은 grimoire-infrastructure agent + infra-mutation-guard skill 영역. 메인 직접 차단. Task tool subagent_type=grimoire-infrastructure로 위임.'),
    (r'\bgit\s+merge\s+(origin/)?develop\b', 'develop merge는 grimoire-infrastructure agent + 사용자 per-repo 명시 영역. 메인 자율 처리 차단. Task tool subagent_type=grimoire-infrastructure로 위임.'),
    (r'\bnpx\s+prisma\s+migrate\s+(deploy|reset)\b', 'prisma migrate mutation (deploy/reset)은 grimoire-server agent 영역. Task tool subagent_type=grimoire-server로 위임.'),
    (r'\bprisma\s+migrate\s+(deploy|reset)\b', 'prisma migrate mutation은 grimoire-server agent 영역. Task tool subagent_type=grimoire-server로 위임.'),
    (r'\bnpm\s+run\s+db:(migrate|reset|seed|push)', 'DB mutation 명령 (db:migrate/reset/seed/push)은 grimoire-server agent 영역. Task tool subagent_type=grimoire-server로 위임.'),

    # SKIP_INTERACTIVE prod 단독 실행 (사용자 승인 필수)
    # 주석: 이건 정당 사용도 있으므로 경고만, 차단은 아님 (warning으로 처리)
]

WARNINGS = [
    (r'SKIP_INTERACTIVE=1.*make\s+deploy-prod\b', 'SKIP_INTERACTIVE=1 + make deploy-prod는 prod 배포를 사용자 개입 없이 실행합니다. 의도한 바인지 확인하세요.'),
    (r'\baz\s+postgres\s+flexible-server\s+(stop|delete|restart)\b', 'Azure PostgreSQL 서버 중지/삭제/재시작 명령. feedback_verify_before_delete 규칙 참조.'),
]

blocked_reasons = []
matched_patterns = []
for pattern, reason in DANGEROUS:
    if re.search(pattern, command):
        blocked_reasons.append(f"[차단] {reason}\n  pattern: {pattern}\n  command: {command}")
        matched_patterns.append((pattern, reason))

# main-blocked-log 박제 (사용자 검증 raw 자료) — 사용자 명시 2026-05-08 "박아버려"
if blocked_reasons:
    try:
        import datetime
        TS = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
        log_path = os.path.expanduser("/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/state/main-blocked-log.jsonl")
        log_dir = os.path.dirname(log_path)
        if not os.path.exists(log_dir):
            os.makedirs(log_dir, exist_ok=True)
        first_pattern, first_reason = matched_patterns[0]
        # JSON 정합 박제
        record = json.dumps({
            "ts": TS,
            "tool": "Bash",
            "pattern": first_pattern[:120],
            "command": command[:300],
            "reason": first_reason[:200]
        }, ensure_ascii=False)
        with open(log_path, "a") as lf:
            lf.write(record + "\n")
    except Exception:
        pass  # 로깅 실패 박제 차단 박제 영향 박제 X

warning_reasons = []
for pattern, reason in WARNINGS:
    if re.search(pattern, command):
        warning_reasons.append(f"[경고] {reason}")

if blocked_reasons:
    # exit 2 → PreToolUse 차단 (Claude Code 규약)
    # stderr는 Claude에게 feedback으로 전달됨
    print("PreToolUse guard triggered:", file=sys.stderr)
    for r in blocked_reasons:
        print(r, file=sys.stderr)
    if warning_reasons:
        for w in warning_reasons:
            print(w, file=sys.stderr)
    print("\n이 명령은 Grimoire 정책(CLAUDE.md §0/§8)에 위반됩니다. 다른 접근을 취하거나 사용자에게 명시 승인을 받으세요.", file=sys.stderr)
    sys.exit(2)

if warning_reasons:
    # warning은 exit 0이지만 stderr로 전달
    for w in warning_reasons:
        print(w, file=sys.stderr)

sys.exit(0)
PYEOF

exit $?
