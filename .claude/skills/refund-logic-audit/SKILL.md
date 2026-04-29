---
name: refund-logic-audit
description: 웹 UI에 추가된 환불 관련 문구("자동 환불", "환불됩니다", "크레딧 반환" 등)가 실제 서버 환불 로직(processRefund/refundCredit/abortableRace catch 블록)과 정합한지 grep + 코드 트레이싱으로 감사. UI 거짓말 차단.
argument-hint: "[선택: 검사할 문구 또는 키워드, 미입력 시 표준 환불 패턴 4종 자동 검사]"
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
effort: medium
paths:
  - "grimoire-server/src/application/analysis/**/*.ts"
  - "grimoire-server/src/application/payment/**/*.ts"
  - "grimoire-web/src/app/dashboard/analysis/**/*.tsx"
---

> **2026-04-25 세션 #7**: `.claude/commands/refund-logic-audit.md`에서 마이그레이션. Anthropic 공식 권장 ("Custom commands have been merged into skills"). `disable-model-invocation: true`로 사용자 명시 호출만 허용 (`/refund-logic-audit`).

# Refund Logic Audit — 환불 UI 문구와 서버 로직 정합성 감사

당신은 ProjectGrimoire의 환불 로직 감사관입니다. 이 슬래시 커맨드는 다음을 강제합니다:

> **사용자 시그널**: 2026-04-19 세션 #4에서 Claude가 AI 분석 화면에 "자동 환불됩니다" UI 문구를 추가했으나, 서버 측 abort 처리에서는 환불 분기가 호출되지 않아 사용자에게 거짓말한 사례 발생. 이 명령은 그 재발을 차단합니다.

## 입력
- `$ARGUMENTS`: 검사할 키워드 (예: "자동 환불", "환불됩니다"). 미입력 시 기본 4종 패턴 검사.

## 절차 (모두 실측 기반, 추정 금지)

### Step 1. 웹 측 환불 관련 UI 문구 grep

```bash
# 사용자 인자가 있으면 그 키워드로, 없으면 기본 4종 패턴
KEYWORDS="${ARGUMENTS:-자동 환불|환불됩니다|크레딧 반환|크레딧이 반환}"

cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web
grep -rEn "$KEYWORDS" src --include="*.ts" --include="*.tsx" | head -30
```

각 매칭 위치를 **파일:라인** 형식으로 기록.

### Step 2. 서버 측 환불 로직 grep

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
echo "=== processRefund / refundCredit 호출 ==="
grep -rEn "processRefund|refundCredit|reverseCredit|환불" src --include="*.ts" | grep -v ".spec.ts" | head -30

echo "=== abortableRace catch 블록 환불 분기 ==="
grep -rEn -B2 -A8 "catch.*Error" src/application --include="*.ts" | grep -B5 "refund\|환불\|Refund" | head -40

echo "=== analysis usecase 환불 처리 ==="
grep -n "refund\|environment" src/application/analysis/novel-analysis.usecase.ts 2>/dev/null | head -10
```

### Step 3. 정합성 판정

각 UI 문구에 대해:

1. **약속하는 행동**을 추출 (예: "자동 환불됨" = "abort/실패 시 크레딧이 자동으로 사용자에게 돌아감")
2. **서버 측 대응 코드 존재 여부** 확인:
   - `processRefund` / `refundCredit` 호출 여부
   - 호출이 어떤 조건에서 트리거되는지 (catch 블록? abort signal? finally?)
   - 트랜잭션 원자성 보장 여부 (`$transaction`)
3. **GAP 분석**:
   - UI는 환불을 약속하나 서버는 환불 분기 없음 → **CRITICAL 거짓말**
   - 서버는 일부 케이스만 환불 → **PARTIAL 부분 거짓말** (UI에서 한정 명시 필요)
   - UI 약속과 서버 구현이 일치 → PASS

### Step 4. 리포트 양식

```markdown
## Refund Logic Audit Report — YYYY-MM-DD

### 검사 키워드
- $ARGUMENTS (또는 기본 4종)

### 웹 UI 매칭 N건
| 파일:라인 | 문구 | 약속 행동 |
|---|---|---|

### 서버 환불 로직 N건
| 파일:라인 | 함수 | 트리거 조건 |
|---|---|---|

### 정합성 판정
| UI 약속 | 서버 대응 | 판정 |
|---|---|---|

### CRITICAL 발견 (있다면)
- (UI는 약속하나 서버 미구현인 항목)
- 권고: UI 문구 정정 또는 서버 로직 추가

### 참조
- 2026-04-19 세션 #4 (`memory/project_session_20260419_4.md`)
- abortableRace 패턴: `grimoire-server/src/lib/abort.ts`
- 결제 원자성 정책: `grimoire-server/SECURITY.md §3`
```

## 절대 금지 사항

- **[MUST NOT]** grep 실측 없이 "정합성 OK"라고 보고
- **[MUST NOT]** 서버 코드 한 곳만 보고 "환불 보장됨" 단정 — abort/timeout/exception 3가지 경로 모두 확인
- **[MUST NOT]** UI 문구를 임의로 수정 — 권고만. 수정은 사용자 또는 web 에이전트가 결정

## 자동 발동 후보 (향후)

이 슬래시 커맨드는 현재 **수동 호출** 전용. 향후 PostToolUse hook에서 `grimoire-web/src/**/*.tsx` Edit 결과에 환불 키워드 추가 감지 시 본 audit를 자동 트리거하는 방안 가능 (Phase 2 후속).

---

마지막 업데이트: 2026-04-25
