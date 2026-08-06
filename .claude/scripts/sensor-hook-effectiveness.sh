#!/bin/bash
# sensor-hook-effectiveness.sh — 자동 강제 hook 누적 효과 측정 (PP-8-1, server #10)
#
# 컨텍스트 (PP-3~PP-7 누적):
#   - PP-6 post-response-skill-injector (Stop hook, autonomous skill 메인 응답 매칭)
#     → .claude/state/post-response-skill-trigger.jsonl 박제
#   - PP-7 pretooluse-edit-write-guard (PreToolUse Edit/Write 자동 차단 + agent 위임 강제)
#     → .claude/state/edit-write-violation.jsonl 박제
#
# 사용자 명시: "베이비시팅 X 진짜 하네스" — 자동 hook이 사용자 명시 없이 작동.
# 그러나 hook이 실제로 작동하는지 측정 sensor 부재 → 본 sensor 신설.
#
# 측정 (3개 jsonl 7일 추이):
#   1. edit-write-violation.jsonl — PP-7 hook reject/통과 횟수
#   2. post-response-skill-trigger.jsonl — PP-6 Stop hook 매칭 횟수 (skill별)
#   3. incident-log.jsonl (category=hook) — hook 신설/수정/장애 박제 횟수
#
# 임계 (sensor-skill-invocation-rate 정합 패턴):
#   - PASS: edit-write-violation 7일 ≥ 1 AND post-response-skill-trigger 7일 ≥ 5
#   - WARN: 둘 중 1개만 충족 OR 7일 0건이지만 jsonl 자체는 정상
#   - FAIL: jsonl 파일 missing OR 14일 연속 0건

set -uo pipefail

ROOT="/Users/sokol/Git/ProjectGrimoire"
STATE_DIR="$ROOT/.claude/state"
EW_FILE="$STATE_DIR/edit-write-violation.jsonl"
PR_FILE="$STATE_DIR/post-response-skill-trigger.jsonl"
INC_FILE="$STATE_DIR/incident-log.jsonl"
LOG_FILE="$STATE_DIR/hook-effectiveness.jsonl"

mkdir -p "$STATE_DIR"

# 파일 존재 확인 (FAIL 조건 1)
MISSING=""
for f in "$EW_FILE" "$PR_FILE" "$INC_FILE"; do
  [ -f "$f" ] || MISSING="$MISSING $(basename "$f")"
done

echo "=== sensor-hook-effectiveness (PP-8-1, server #10) ==="

if [ -n "$MISSING" ]; then
  echo "[RESULT] FAIL — jsonl 파일 missing:$MISSING"
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  printf '{"ts":"%s","status":"FAIL","reason":"missing_jsonl","missing":"%s"}\n' \
    "$TS" "$MISSING" >> "$LOG_FILE"
  if [ -x "$ROOT/.claude/scripts/sensor-log.sh" ]; then
    bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-hook-effectiveness" "FAIL" "missing=$MISSING" 2>/dev/null || true
  fi
  exit 2
fi

# 7일/14일 카운트 (python ts ISO8601 파싱)
RESULT=$(python3 <<'PYEOF'
import json, time, os
from collections import Counter
from datetime import datetime, timezone

STATE = "/Users/sokol/Git/ProjectGrimoire/.claude/state"
now = time.time()
cut7 = now - 7 * 86400
cut14 = now - 14 * 86400

def parse_ts(s):
    try:
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        return datetime.fromisoformat(s).timestamp()
    except Exception:
        return 0

def load(name):
    p = os.path.join(STATE, name)
    rows = []
    try:
        with open(p) as f:
            for line in f:
                line = line.strip()
                if not line: continue
                try:
                    rows.append(json.loads(line))
                except: pass
    except: pass
    return rows

ew = load("edit-write-violation.jsonl")
pr = load("post-response-skill-trigger.jsonl")
inc = load("incident-log.jsonl")

ew7 = [r for r in ew if parse_ts(r.get("ts","")) >= cut7]
ew14 = [r for r in ew if parse_ts(r.get("ts","")) >= cut14]
pr7 = [r for r in pr if parse_ts(r.get("ts","")) >= cut7]
pr14 = [r for r in pr if parse_ts(r.get("ts","")) >= cut14]
inc_hook7 = [r for r in inc if r.get("category") == "hook" and parse_ts(r.get("ts","")) >= cut7]

# skill별 분포 (PR 7일)
skill_counter = Counter()
for r in pr7:
    for s in r.get("triggered_skills", []) or []:
        skill_counter[s] += 1

print(f"EW7|{len(ew7)}")
print(f"EW14|{len(ew14)}")
print(f"PR7|{len(pr7)}")
print(f"PR14|{len(pr14)}")
print(f"INC_HOOK7|{len(inc_hook7)}")
for s, c in skill_counter.most_common(10):
    print(f"SKILL|{s}|{c}")
PYEOF
)

EW7=$(echo "$RESULT" | grep "^EW7|" | cut -d'|' -f2)
EW14=$(echo "$RESULT" | grep "^EW14|" | cut -d'|' -f2)
PR7=$(echo "$RESULT" | grep "^PR7|" | cut -d'|' -f2)
PR14=$(echo "$RESULT" | grep "^PR14|" | cut -d'|' -f2)
INC_HOOK7=$(echo "$RESULT" | grep "^INC_HOOK7|" | cut -d'|' -f2)

EW7=${EW7:-0}; EW14=${EW14:-0}; PR7=${PR7:-0}; PR14=${PR14:-0}; INC_HOOK7=${INC_HOOK7:-0}

echo "edit-write-violation     7일: ${EW7}건  / 14일: ${EW14}건"
echo "post-response-skill-trig 7일: ${PR7}건  / 14일: ${PR14}건"
echo "incident-log (hook)      7일: ${INC_HOOK7}건"
echo ""

if [ "$PR7" -gt 0 ]; then
  echo "Top skill 매칭 (PP-6 Stop hook, 7일):"
  echo "$RESULT" | grep "^SKILL|" | while IFS='|' read -r _ s c; do
    echo "  $s: ${c}회"
  done
  echo ""
fi

# 임계 판정
EW_OK=0; PR_OK=0
[ "$EW7" -ge 1 ] && EW_OK=1
[ "$PR7" -ge 5 ] && PR_OK=1

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TAG="PASS"; EXIT=0; REASON=""

if [ "$EW_OK" -eq 1 ] && [ "$PR_OK" -eq 1 ]; then
  echo "[RESULT] PASS — PP-7 reject ${EW7}건 + PP-6 매칭 ${PR7}건 (자동 hook 작동 확인)"
elif [ "$EW14" -eq 0 ] && [ "$PR14" -eq 0 ]; then
  TAG="FAIL"; EXIT=2; REASON="14일 연속 0건"
  echo "[RESULT] FAIL — 14일 연속 0건 (hook 죽었을 가능성, settings.json 확인 권장)"
else
  TAG="WARN"; EXIT=1; REASON="부분 충족"
  echo "[RESULT] WARN — 부분 충족 (EW7=${EW7}/≥1, PR7=${PR7}/≥5). hook 정상이나 호출 빈도 부족"
fi

# JSONL 박제
printf '{"ts":"%s","status":"%s","ew7":%s,"ew14":%s,"pr7":%s,"pr14":%s,"inc_hook7":%s,"reason":"%s"}\n' \
  "$TS" "$TAG" "$EW7" "$EW14" "$PR7" "$PR14" "$INC_HOOK7" "$REASON" \
  >> "$LOG_FILE"

# sensor-log 박제
if [ -x "$ROOT/.claude/scripts/sensor-log.sh" ]; then
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-hook-effectiveness" "$TAG" \
    "ew7=$EW7 pr7=$PR7 inc_hook7=$INC_HOOK7" 2>/dev/null || true
fi

exit $EXIT
