#!/usr/bin/env bash
# sensor-loop-detection.sh — 같은 파일 반복 수정 (둠 루프) 자동 검출 (책 Ch 21 정본)
#
# 동기 (책 Ch 21 Correct 기둥 + Ch 23 안티패턴 #6 비용 블랙홀 방어):
#   - LangChain LoopDetectionMiddleware: MAX_EDITS_PER_FILE = 5 (책 정본 임계)
#   - 같은 파일 5회 초과 수정 = 가설 분리 실패 / 단일 변수 변경 위반
#   - systematic-debugging skill로 escalation 유도
#
# 데이터: .claude/state/loop-detection.jsonl (loop-detection-tracker.sh 박제)
#
# 검사:
#   - 오늘(today) 파일별 Edit/Write 횟수
#   - 5회 초과 파일 식별 → WARN (단일)
#   - 1개 파일 ≥ 10회 → FAIL (둠 루프 명백)
#   - 3개 파일 ≥ 5회 동시 → FAIL (다중 가설 종속 의심)
#
# Exit 0 PASS / 1 WARN / 2 FAIL

set +u

ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
LOG_FILE="$ROOT/.claude/state/loop-detection.jsonl"
TODAY=$(date -u +"%Y-%m-%d")

echo "=== sensor-loop-detection (책 Ch 21 LangChain MAX_EDITS_PER_FILE=5) ==="
echo ""

if [ ! -s "$LOG_FILE" ]; then
  echo "✅ PASS: loop-detection.jsonl 비어있음 (Edit 박제 0건)"
  bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-loop-detection" "PASS" "no-data" 2>/dev/null || true
  exit 0
fi

python3 <<PYEOF
import json
from collections import defaultdict

LOG = '$LOG_FILE'
TODAY = '$TODAY'
counts = defaultdict(int)

with open(LOG) as f:
    for line in f:
        try:
            obj = json.loads(line)
            if obj.get('date') != TODAY:
                continue
            counts[obj['file']] += 1
        except Exception:
            pass

if not counts:
    print(f"✅ PASS: 오늘({TODAY}) Edit 박제 0건")
    exit(0)

# 임계값별 분류
warn_files = [(f, c) for f, c in counts.items() if 5 <= c < 10]
critical_files = [(f, c) for f, c in counts.items() if c >= 10]
total_files = len(counts)
total_edits = sum(counts.values())

print(f"오늘 Edit/Write 통계: {total_files} 파일 / {total_edits} 회")

# Top 5
top5 = sorted(counts.items(), key=lambda x: -x[1])[:5]
print(f"\n── Top 5 (편집 횟수) ──")
for f, c in top5:
    fname = f.replace('/Users/sokol/Desktop/Git/ProjectGrimoire/', '')
    if c >= 10:
        print(f"  ❌ {c:3d}회  {fname}  (≥10 둠 루프 명백)")
    elif c >= 5:
        print(f"  ⚠️  {c:3d}회  {fname}  (5회 초과 — 가설 분리 권장)")
    else:
        print(f"  ✅ {c:3d}회  {fname}")

# 판정
print()
if critical_files:
    print(f"❌ FAIL: {len(critical_files)} 파일 ≥ 10회 (둠 루프 명백 — systematic-debugging skill 발동)")
    exit(2)
elif len(warn_files) >= 3:
    print(f"❌ FAIL: {len(warn_files)} 파일 동시 ≥ 5회 (다중 가설 종속 의심)")
    exit(2)
elif warn_files:
    print(f"⚠️ WARN: {len(warn_files)} 파일 5회 초과 (가설 분리 권장)")
    exit(1)
else:
    print(f"✅ PASS: 모든 파일 ≤ 4회 (책 Ch 21 정합)")
    exit(0)
PYEOF
RC=$?

# sensor-log 박제
case "$RC" in
  0) TAG="PASS" ;;
  1) TAG="WARN" ;;
  *) TAG="FAIL" ;;
esac
bash "$ROOT/.claude/scripts/sensor-log.sh" "sensor-loop-detection" "$TAG" "RC=$RC" 2>/dev/null || true
exit $RC
