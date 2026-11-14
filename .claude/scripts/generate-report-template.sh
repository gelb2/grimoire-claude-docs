#!/bin/bash
# generate-report-template.sh — shared-contracts.md 골격 → reports/*.md 자동 생성
#
# 책 Ch 16 멀티 에이전트 shared contracts 패턴 적용.
# 에이전트가 "빈 백지"에서 reports/*.md를 작성하지 않도록 정본 골격을 사전 박제한다.
#
# 사용법:
#   bash .claude/scripts/generate-report-template.sh                    # dry-run (현황 표시)
#   bash .claude/scripts/generate-report-template.sh --apply             # 누락 파일만 생성 (기존 파일 보존)
#   bash .claude/scripts/generate-report-template.sh --apply --force     # 기존 파일도 골격으로 덮어쓰기 (주의)
#   bash .claude/scripts/generate-report-template.sh --report=PLANNER_REPORT --apply
#
# Exit 0 PASS / 1 ERROR / 2 부분실패

set -u

ROOT="/Users/sokol/Git/ProjectGrimoire"
CONTRACTS="$ROOT/.claude/shared-contracts.md"
REPORTS_DIR="$ROOT/reports"
TODAY=$(date "+%Y-%m-%d")

MODE="dry-run"
FORCE=false
ONLY=""

for arg in "$@"; do
  case "$arg" in
    --apply) MODE="apply" ;;
    --force) FORCE=true ;;
    --report=*) ONLY="${arg#--report=}" ;;
    -h|--help)
      sed -n '2,16p' "$0"; exit 0 ;;
    *) echo "❌ 알 수 없는 옵션: $arg"; exit 1 ;;
  esac
done

if [ ! -f "$CONTRACTS" ]; then
  echo "❌ FAIL: shared-contracts.md 없음 — $CONTRACTS"
  exit 1
fi

mkdir -p "$REPORTS_DIR"

echo "=== generate-report-template (mode=$MODE force=$FORCE only=${ONLY:-all}) ==="
echo "정본: $CONTRACTS"
echo "대상: $REPORTS_DIR/"
echo ""

# shared-contracts.md 의 ## N. reports/{NAME}.md 섹션 + ```markdown 블록 파싱
# awk로 모든 (파일명, 골격) 쌍을 NUL 구분으로 출력
# awk가 골격 5개를 임시 디렉토리에 NAME.tpl 파일로 분리 출력 (NUL 손실 회피)
TMP=$(mktemp -d -t harness-tpl)
trap 'rm -rf "$TMP"' EXIT

awk -v out="$TMP" '
  BEGIN { name=""; in_block=0 }
  /^## [0-9]+\. reports\// {
    name=""; in_block=0
    line=$0
    sub(/^.*reports\//, "", line)
    sub(/\.md.*$/, "", line)
    if (line ~ /^[A-Z_]+$/) name=line
    next
  }
  name != "" && /^```markdown[[:space:]]*$/ { in_block=1; next }
  name != "" && in_block && /^```[[:space:]]*$/ {
    in_block=0
    name=""
    next
  }
  in_block && name != "" {
    print $0 >> (out "/" name ".tpl")
  }
' "$CONTRACTS"

TPL_COUNT=$(ls "$TMP"/*.tpl 2>/dev/null | wc -l | tr -d ' ')
if [ "$TPL_COUNT" -eq 0 ]; then
  echo "❌ FAIL: shared-contracts.md 에서 reports/*.md 골격을 추출하지 못함."
  echo "   섹션 형식이 '## N. reports/{NAME}.md ...' + 코드블록 \`\`\`markdown 인지 확인."
  exit 1
fi

CREATED=0
SKIPPED=0
OVERWRITTEN=0
PARTIAL_FAIL=0

for tpl in "$TMP"/*.tpl; do
  name=$(basename "$tpl" .tpl)

  if [ -n "$ONLY" ] && [ "$name" != "$ONLY" ]; then continue; fi

  target="$REPORTS_DIR/${name}.md"
  exists="false"; [ -f "$target" ] && exists="true"
  lines=$(wc -l < "$tpl" | tr -d ' ')

  case "$MODE" in
    dry-run)
      if [ "$exists" = "true" ]; then
        printf "  [SKIP exist]   reports/%s.md (기존 파일, --force 없으면 보존)\n" "$name"
      else
        printf "  [WOULD CREATE] reports/%s.md (%d 줄 골격)\n" "$name" "$lines"
      fi
      ;;
    apply)
      if [ "$exists" = "true" ] && [ "$FORCE" = "false" ]; then
        printf "  [SKIP exist]   reports/%s.md\n" "$name"
        SKIPPED=$((SKIPPED+1))
        continue
      fi
      {
        printf '<!-- AUTO-GENERATED from .claude/shared-contracts.md (책 Ch 16 정본 골격) -->\n'
        printf '<!-- 생성일: %s -->\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
        printf '<!-- 본 파일 수정 후 인터페이스 변경 시 shared-contracts.md 먼저 갱신할 것 -->\n\n'
        sed "s/YYYY-MM-DD/$TODAY/g" "$tpl"
      } > "$target"
      if [ $? -eq 0 ]; then
        if [ "$exists" = "true" ]; then
          printf "  [OVERWRITE]    reports/%s.md (%d 줄)\n" "$name" "$lines"
          OVERWRITTEN=$((OVERWRITTEN+1))
        else
          printf "  [CREATE]       reports/%s.md (%d 줄)\n" "$name" "$lines"
          CREATED=$((CREATED+1))
        fi
      else
        printf "  [FAIL write]   reports/%s.md\n" "$name"
        PARTIAL_FAIL=$((PARTIAL_FAIL+1))
      fi
      ;;
  esac
done

echo ""
echo "── 종합 ──"
case "$MODE" in
  dry-run)
    echo "dry-run 모드 — 실제 변경 없음. 적용하려면 --apply 추가."
    ;;
  apply)
    echo "생성: $CREATED / 덮어쓰기: $OVERWRITTEN / 보존(skip): $SKIPPED / 실패: $PARTIAL_FAIL"
    if [ "$PARTIAL_FAIL" -gt 0 ]; then exit 2; fi
    ;;
esac

exit 0
