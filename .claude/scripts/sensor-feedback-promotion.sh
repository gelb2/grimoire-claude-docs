#!/usr/bin/env bash
# sensor-feedback-promotion.sh — feedback_*.md 영향력 측정 + skill 승격 후보 식별
#
# 동기 (HARNESS §8.9 v2):
#   - memory/feedback_*.md 파일이 N회 이상 다른 정본/메모리/skill에서 참조되면
#     "사용자가 반복 강조하는 원칙" → skill 승격 가치 있음
#   - 자동 승격은 위험 (사용자 의사 확인 필수) → 본 sensor는 후보만 식별
#   - 정식 승격은 /feedback-to-skill skill (사용자 confirm 강제)
#
# 측정 정의:
#   각 feedback 파일에 대해 다음 위치에서 참조 카운트 합산:
#     1. 다른 memory/*.md 파일 (인덱스 MEMORY.md + 세션 기록)
#     2. /Users/sokol/Desktop/Git/ProjectGrimoire/CLAUDE.md
#     3. PLANNING_GRIMOIRE.md / SYNC_STATUS.md
#     4. docs/*.md (server + web)
#     5. research/*.md
#     6. .claude/skills/*/SKILL.md (이미 일부 흡수된 경우)
#     7. .claude/agents/*.md
#     8. AUTOMATION.md
#
# 임계값:
#   - count ≥ 3: 승격 후보 (PROMOTE)
#   - count = 2: 관찰 (OBSERVE)
#   - count ≤ 1: 단발 피드백 (KEEP)
#
# 신규 면제:
#   - 30일 미만 신규 feedback 파일은 임계값 적용 안 함 (사용 패턴 형성 중)
#   - 2026-04-27 #9 X-4: 90일 → 30일 단축 (메모리 손실 노출 시간 ↓ + 핵심 박제 가속)
#
# 사용:
#   sensor-feedback-promotion.sh                # 전체 스캔 + 후보 출력
#   sensor-feedback-promotion.sh --threshold=5  # 임계값 변경
#   sensor-feedback-promotion.sh --new-days=N   # 신규 면제 기간 변경
#   sensor-feedback-promotion.sh --quiet        # 후보만 stdout

set -u

PROJECT_ROOT="/Users/sokol/Desktop/Git/ProjectGrimoire"
MEMORY_DIR="/Users/sokol/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory"
LOG_DIR="$PROJECT_ROOT/.claude/state"
OUTPUT_FILE="$LOG_DIR/feedback-promotion-candidates.jsonl"

mkdir -p "$LOG_DIR"

THRESHOLD=3
NEW_DAYS=30  # 2026-04-27 #9 X-4: 90 → 30일 단축 (HARNESS §8.9 v2 + 메모리 손실 노출 시간 ↓)
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --threshold=*) THRESHOLD="${arg#--threshold=}" ;;
    --new-days=*) NEW_DAYS="${arg#--new-days=}" ;;
    --quiet) QUIET=1 ;;
  esac
done

[ "$QUIET" -eq 0 ] && echo "=== Feedback Promotion Sensor ($(date +'%H:%M:%S')) ==="
[ "$QUIET" -eq 0 ] && echo "임계값: count ≥ $THRESHOLD → PROMOTE (신규 ${NEW_DAYS}일 미만 면제)"
[ "$QUIET" -eq 0 ] && echo ""

# Python으로 정밀 측정 (bash grep만으론 신규 면제 + 카테고리화 어려움)
python3 << PYEOF
import os, re, glob, json, time
from datetime import datetime

PROJECT_ROOT = "$PROJECT_ROOT"
MEMORY_DIR = "$MEMORY_DIR"
THRESHOLD = $THRESHOLD
NEW_DAYS = $NEW_DAYS

# 1. feedback 파일 목록
feedback_files = sorted(glob.glob(f"{MEMORY_DIR}/feedback_*.md"))

# 2. 검사 대상 위치 (참조 카운트할 파일들)
search_paths = []
search_paths.extend(glob.glob(f"{MEMORY_DIR}/*.md"))         # 다른 메모리
search_paths.extend([f"{PROJECT_ROOT}/CLAUDE.md"])
search_paths.extend([f"{PROJECT_ROOT}/PLANNING_GRIMOIRE.md"])
search_paths.extend([f"{PROJECT_ROOT}/SYNC_STATUS.md"])
search_paths.extend([f"{PROJECT_ROOT}/AUTOMATION.md"])
search_paths.extend(glob.glob(f"{PROJECT_ROOT}/grimoire-server/docs/*.md"))
search_paths.extend(glob.glob(f"{PROJECT_ROOT}/grimoire-web/docs/*.md"))
search_paths.extend(glob.glob(f"{PROJECT_ROOT}/research/*.md"))
search_paths.extend(glob.glob(f"{PROJECT_ROOT}/.claude/skills/*/SKILL.md"))
search_paths.extend(glob.glob(f"{PROJECT_ROOT}/.claude/agents/*.md"))
search_paths.extend(glob.glob(f"{PROJECT_ROOT}/.claude/knowledge/*.md"))

# 검사 대상 본문 일괄 로드 (큰 효율)
contents_cache = {}
for sp in search_paths:
    try:
        with open(sp, encoding='utf-8') as f:
            contents_cache[sp] = f.read()
    except:
        pass

# 3. 각 feedback 파일에 대해 참조 카운트
now = time.time()
candidates_promote = []
candidates_observe = []
candidates_keep = []

for fpath in feedback_files:
    name = os.path.basename(fpath)
    name_no_ext = name[:-3]  # .md 제거
    mtime = os.path.getmtime(fpath)
    age_days = (now - mtime) / 86400

    # 자기 자신 + MEMORY.md 인덱스 제외 (인덱스 1회 참조는 기본)
    count = 0
    references = []
    for sp, content in contents_cache.items():
        if sp == fpath:
            continue
        # 파일명 자체 참조 (확장자 포함/미포함 둘 다 카운트)
        # MEMORY.md의 인덱스는 1회는 기본이므로 빼지만, 다른 메모리/문서 참조는 모두 카운트
        if name in content or name_no_ext in content:
            # MEMORY.md 인덱스는 1회 카운트 (정상)
            if os.path.basename(sp) == 'MEMORY.md':
                count += 1  # 인덱스 1회는 정상이므로 가산
            else:
                count += 1
                references.append(os.path.relpath(sp, PROJECT_ROOT) if sp.startswith(PROJECT_ROOT) else os.path.basename(sp))

    is_new = age_days < NEW_DAYS
    cat = "PROMOTE" if (count >= THRESHOLD and not is_new) else \
          "OBSERVE" if count == THRESHOLD - 1 else \
          "KEEP"

    entry = {
        "file": name,
        "count": count,
        "age_days": round(age_days, 1),
        "is_new": is_new,
        "category": cat,
        "references": references[:5],  # 상위 5건만
    }

    if is_new and count >= THRESHOLD:
        # 신규지만 영향력 큼 — OBSERVE로 강등 (관찰)
        cat = "OBSERVE_NEW"
        entry["category"] = cat
        candidates_observe.append(entry)
    elif cat == "PROMOTE":
        candidates_promote.append(entry)
    elif cat == "OBSERVE":
        candidates_observe.append(entry)
    else:
        candidates_keep.append(entry)

# 4. 결과 출력
print(f"분석 feedback 파일: {len(feedback_files)}")
print(f"검사 대상 위치: {len(search_paths)}")
print()

print(f"=== PROMOTE 후보 ({len(candidates_promote)}건) — count ≥ {THRESHOLD} + 신규 아님 ===")
for e in sorted(candidates_promote, key=lambda x: -x["count"]):
    print(f"  [{e['count']:2d}회] {e['file']} (age {e['age_days']:.1f}d)")
    for r in e["references"]:
        print(f"          ← {r}")

print()
print(f"=== OBSERVE ({len(candidates_observe)}건) ===")
for e in sorted(candidates_observe, key=lambda x: -x["count"])[:10]:
    print(f"  [{e['count']:2d}회] {e['file']} ({e['category']}, age {e['age_days']:.1f}d)")

print()
print(f"=== KEEP (단발) — {len(candidates_keep)}건 ===")
for e in sorted(candidates_keep, key=lambda x: -x["count"])[:5]:
    print(f"  [{e['count']:2d}회] {e['file']} (age {e['age_days']:.1f}d)")

# 5. JSONL 적재 (시계열)
ts = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
output = {
    "ts": ts,
    "threshold": THRESHOLD,
    "new_days": NEW_DAYS,
    "total_feedback": len(feedback_files),
    "promote": len(candidates_promote),
    "observe": len(candidates_observe),
    "keep": len(candidates_keep),
    "promote_details": candidates_promote,
    "observe_details": candidates_observe[:10],
}
with open("$OUTPUT_FILE", "a") as f:
    f.write(json.dumps(output, ensure_ascii=False) + "\n")

print()
print(f"[기록] $OUTPUT_FILE")

# 종합 판정
if len(candidates_promote) > 0:
    print(f"[RESULT] PROMOTE — {len(candidates_promote)}건 승격 후보. /feedback-to-skill skill로 처리 권장")
else:
    print(f"[RESULT] PASS — 승격 후보 없음 (현재 모든 feedback이 단발 또는 신규)")
PYEOF

[ "$QUIET" -eq 0 ] && echo "=== 끝 ==="
exit 0
