#!/bin/bash
# sensor-skill-invocation-rate.sh — Skill 자율 호출률 측정 (묶음 OO-3)
#
# 사용자 명시 (2026-05-06): Skill 24건 박제만, 메인 자율 호출 거의 0건 결함 측정.
#
# 측정:
#   1. 7일간 jsonl에서 Skill 도구 호출 횟수
#   2. UserPromptSubmit hook이 키워드 매칭으로 자동 호출한 skill 횟수 (별도 박제 가치)
#   3. 박제된 skill 수 vs 실제 호출된 skill 수 비교
#
# Skill 호출 패턴 (Claude Code jsonl):
#   - 메시지 안 "Skill" tool_use (메인 또는 사용자 명시)
#   - skill 이름은 input.skill 필드
#
# 임계 (Fowler "Steering Loop" 정합):
#   - 호출률 ≥ 0.30: PASS (24 skill 中 8건 이상 활용)
#   - 0.10 ≤ 호출률 < 0.30: WARN (활용 부족)
#   - 호출률 < 0.10: FAIL (박제만 + 자율 호출 X)

set -uo pipefail

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
SKILLS_DIR="$ROOT/.claude/skills"
JSONL_DIR="$HOME/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire"
LOG_FILE="$ROOT/.claude/state/skill-invocation-rate.jsonl"

mkdir -p "$(dirname "$LOG_FILE")"

# 박제된 skill 수 (현역만 — _archive/ 제외, 묶음 PP-3 정합)
TOTAL_SKILLS=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d ! -name "_archive" 2>/dev/null | wc -l | tr -d ' ')

# 7일간 Skill tool_use 추적
RESULT=$(python3 <<PYEOF
import json, glob, os, time
from collections import Counter

JSONL_DIR = "$JSONL_DIR"
cutoff = time.time() - 7 * 86400

invoked_skills = Counter()
total_calls = 0

for fpath in glob.glob(f"{JSONL_DIR}/*.jsonl"):
    if os.path.getmtime(fpath) < cutoff:
        continue
    try:
        with open(fpath) as f:
            for line in f:
                try: obj = json.loads(line)
                except: continue
                msg = obj.get('message', {})
                if not isinstance(msg, dict): continue
                if msg.get('role') != 'assistant': continue
                content = msg.get('content', [])
                if not isinstance(content, list): continue
                for c in content:
                    if not isinstance(c, dict): continue
                    if c.get('type') == 'tool_use' and c.get('name') == 'Skill':
                        total_calls += 1
                        skill = c.get('input', {}).get('skill', 'unknown')
                        invoked_skills[skill] += 1
    except: pass

print(f"TOTAL_CALLS|{total_calls}")
print(f"UNIQUE_SKILLS|{len(invoked_skills)}")
for s, c in invoked_skills.most_common(10):
    print(f"SKILL|{s}|{c}")
PYEOF
)

TOTAL_CALLS=$(echo "$RESULT" | grep "^TOTAL_CALLS|" | cut -d'|' -f2)
UNIQUE_SKILLS=$(echo "$RESULT" | grep "^UNIQUE_SKILLS|" | cut -d'|' -f2)

echo "=== sensor-skill-invocation-rate (묶음 OO-3) ==="
echo "박제된 skill: $TOTAL_SKILLS"
echo "7일간 호출: $TOTAL_CALLS회"
echo "활용된 unique skill: $UNIQUE_SKILLS / $TOTAL_SKILLS"
echo ""

if [ "$TOTAL_SKILLS" -gt 0 ]; then
  RATE=$(python3 -c "print(round($UNIQUE_SKILLS / $TOTAL_SKILLS, 4))")
else
  RATE="0.0"
fi

echo "활용률: $RATE"
echo ""

if [ "$UNIQUE_SKILLS" -gt 0 ]; then
  echo "Top skill 호출:"
  echo "$RESULT" | grep "^SKILL|" | head -10 | while IFS='|' read -r _ s c; do
    echo "  $s: $c회"
  done
  echo ""
fi

# JSONL 박제
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '{"ts":"%s","total_skills":%s,"total_calls":%s,"unique_skills":%s,"rate":%s}\n' \
  "$TS" "$TOTAL_SKILLS" "${TOTAL_CALLS:-0}" "${UNIQUE_SKILLS:-0}" "$RATE" \
  >> "$LOG_FILE"

# 임계 판정
if python3 -c "exit(0 if $RATE >= 0.30 else 1)" 2>/dev/null; then
  echo "[RESULT] PASS — Skill 활용률 $RATE ≥ 0.30"
  EXIT=0
elif python3 -c "exit(0 if $RATE >= 0.10 else 1)" 2>/dev/null; then
  echo "[RESULT] WARN — Skill 활용률 $RATE < 0.30 (24 skill 中 < 30% 활용)"
  EXIT=1
else
  echo "[RESULT] FAIL — Skill 활용률 $RATE < 0.10 (박제만 + 자율 호출 X)"
  echo "  → 메인 자율 skill 호출 편향 누적. UserPromptSubmit hook 키워드 매칭 강화 권장"
  EXIT=2
fi

# sensor-log 박제
if [ -x "$ROOT/.claude/scripts/sensor-log.sh" ]; then
  TAG="PASS"
  [ "$EXIT" -eq 1 ] && TAG="WARN"
  [ "$EXIT" -eq 2 ] && TAG="FAIL"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-skill-invocation-rate" "$TAG" "rate=$RATE total=$TOTAL_SKILLS invoked=$UNIQUE_SKILLS" 2>/dev/null || true
fi

exit $EXIT
