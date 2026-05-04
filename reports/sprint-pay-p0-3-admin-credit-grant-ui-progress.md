# Sprint Progress — pay-p0-3-admin-credit-grant-ui

> **Sprint ID**: sprint-pay-p0-3-admin-credit-grant-ui
> **세션**: #10_7 PAY-P0-3 (PAYMENT_SYSTEM_PLAN §3-1 세 번째 항목 — 운영자 수동 지급 web UI)
> **Initializer**: grimoire-planner (책 Ch 16 Anthropic 3-에이전트 패턴 — 묶음 II 5회차)
> **작성일**: 2026-05-03
> **단일 진실**: 본 파일이 Generator (web / claude-docs) + Evaluator (qa) 모두의 작업 정본. 모호하면 본 파일 갱신 후 합의.
> **선행 Sprint**:
> - PAY-P0-1 (sprint-pay-p0-1-webhook-event-id-idempotency-progress.md) — 산출물 체크리스트 [x] 박제 완료 (server `8c13103` + claude-docs `06de6c6`)
> - PAY-P0-2 (sprint-pay-p0-2-payment-reconciliation-cron-progress.md) — server 산출물 체크리스트 [x] 박제 완료 (server + claude-docs develop push 완료)

---

## 0. Goal — 한 줄

운영자가 curl/DB 직접 조작 없이 **관리자 패널 web UI**에서 사용자 검색 → 잔액 표시 → 금액·사유 입력 → 멀티콘펌 → 크레딧 지급/차감 처리. **사람 실수 위험 0건**. 백엔드 API (`POST /admin/credits/grant` + `POST /admin/credits/deduct`) + AdminAuditLog 자동 박제는 **이미 존재** → web UI만 신설.

---

## 1. 배경 (메인 사전 파악 — 실측 박제)

### 1-1. 현재 갭 (PAYMENT_SYSTEM_PLAN §1-5 #3)

> **운영자 web UI 부재** — `/admin/credits/grant` 백엔드 API만 존재, 웹 화면 없음. 운영자가 curl 또는 DB 직접 조작 → 사람 실수 위험. **운영 안정성 핵심**.

PAY-P0-1 (webhook event_id 멱등성) + PAY-P0-2 (PG↔DB 정합성 cron)은 **자동 보정 채널**을 확보하지만, **운영자가 의도적으로 보상/지급/차감해야 하는 케이스**(CS 보상, 이벤트 지급, 오지급 회수 등)는 여전히 백엔드 API 직접 호출에 의존. 운영자가 휴먼 에러로 amount/authorId/reason을 잘못 입력하면 즉시 사용자 피해 발생.

### 1-2. 백엔드 인벤토리 (실측 — 본 Sprint 변경 0건)

| 영역 | 위치 | 상태 |
|---|---|---|
| Controller | `grimoire-server/src/adapter/inbound/http/controller/admin.controller.ts` (`POST /admin/credits/grant` + `POST /admin/credits/deduct`) | ✅ 존재 |
| UseCase | `grimoire-server/src/application/admin/admin.usecase.ts` (`grantCredits` + `deductCredits` + `auditLog.log` 자동 호출) | ✅ 존재 |
| AuditLog | `grimoire-server/src/application/admin/audit-log.service.ts` + `prisma-audit-log.repository.ts` | ✅ 존재 (operator + action + targetId + detail JSON) |
| Repo | `grimoire-server/src/adapter/outbound/persistence/prisma-credit.repository.ts` (`adjustCredits`) | ✅ 존재 |
| Throttle | `@Throttle({ ttl: 60000, limit: 5 })` mutation | ✅ 적용 |

**결론**: 본 Sprint는 **server 변경 0건** + **web UI 신설**. claude-docs는 sensor + eval task만 갱신.

### 1-3. web 인벤토리 (실측)

| 영역 | 위치 | 상태 |
|---|---|---|
| API client (grant) | `grimoire-web/src/lib/api.ts:541` `adminGrantCredits(authorId, amount, reason)` | ✅ 존재 (BFF 프록시 자동 — fetch는 `/admin/credits/grant`) |
| API client (deduct) | `grimoire-web/src/lib/api.ts:545` `adminDeductCredits(authorId, amount, reason)` | ✅ 존재 |
| API client (logs) | `grimoire-web/src/lib/api.ts:549` `adminGetCreditLogs(authorId?)` | ✅ 존재 |
| API client (search) | `grimoire-web/src/lib/api.ts:324` `searchAuthors(query)` | ✅ 존재 |
| 관리자 메인 | `grimoire-web/src/app/admin/page.tsx` (347줄 — 14 tab 등록 + Tab union 타입) | ⚠️ CreditsTab 미등록 |
| 관리자 tabs | `grimoire-web/src/app/admin/tabs/*.tsx` (11건 — Access/Announcements/Comments/Featured/Payments/Reports/Revenue/Sanctions/Settings/Themes/Works) | ⚠️ CreditsTab 부재 |
| Tab union 타입 | `Tab = 'stats' \| 'authors' \| 'works' \| ... \| 'audit'` (page.tsx:18) | ⚠️ `'credits'` 미포함 |
| TAB_LABELS map | `page.tsx:20-25` | ⚠️ `credits: '크레딧'` 미포함 |

**결론**: 본 Sprint는 web 1 신설 (CreditsTab) + 1 변경 (admin/page.tsx — Tab union + TAB_LABELS + 렌더링 분기) + 1 spec 신설 + claude-docs sensor/eval.

### 1-4. 시각 정본 검증 (visual-canon-keeper 사전 검수 가이드)

**관리자 패널 = neutral-* 색상 영역** (작가 공간 g-* CSS 토큰 침범 금지). PaymentsTab.tsx 패턴 정합 박제:

- `bg-neutral-900 / bg-neutral-800 / border-neutral-700 / border-neutral-800 / text-neutral-300 / text-neutral-400 / text-neutral-500 / text-white`
- `rounded-lg / rounded-xl / px-3 py-2 / text-sm`
- 상태 색 (status badge): `bg-green-900/50 text-green-400` (success) / `bg-yellow-900/50 text-yellow-400` (pending) / `bg-red-900/50 text-red-400` (error)
- 모달: 페이지 중앙 fixed + `bg-black/70 backdrop-blur` overlay 권고 (작가 공간 침범 0건 — `dialog` element 또는 inline modal)
- 작가 g-* 토큰 (g-bg, g-fg, g-accent 등) 사용 0건 박제

### 1-5. 실측 grep (Generator 출발점)

```bash
$ grep -nE 'adminGrantCredits|adminDeductCredits|adminGetCreditLogs' grimoire-web/src/lib/api.ts
541:  async adminGrantCredits(authorId: string, amount: number, reason: string) {
545:  async adminDeductCredits(authorId: string, amount: number, reason: string) {
549:  async adminGetCreditLogs(authorId?: string) {

$ grep -nE 'CreditsTab' grimoire-web/src/app/admin/page.tsx
(0건 — 미등록)

$ ls grimoire-web/src/app/admin/tabs/
AccessLogsTab.tsx  AnnouncementsTab.tsx  CommentsTab.tsx  FeaturedTab.tsx
PaymentsTab.tsx    ReportsTab.tsx        RevenueTab.tsx   SanctionsTab.tsx
SettingsTab.tsx    ThemesTab.tsx         WorksTab.tsx
(11 파일 — CreditsTab.tsx 부재)
```

---

## 2. Scope

### 2-1. IN

| 항목 | 영역 | 파일 (예상 경로) |
|---|---|---|
| **CreditsTab 컴포넌트 신설** | web | `grimoire-web/src/app/admin/tabs/CreditsTab.tsx` (사용자 검색 + 잔액 표시 + grant/deduct 분기 + 멀티콘펌 모달 + 결과 토스트 + 최근 로그 미리보기) |
| **CreditsTab vitest spec** | web | `grimoire-web/src/app/admin/tabs/CreditsTab.spec.tsx` (검색 → 선택 → 금액 입력 → 사유 입력 → 모달 → 확인 → API 호출 + 토스트 + 최근 로그 갱신 시나리오) |
| admin/page.tsx — Tab union 확장 | web | `grimoire-web/src/app/admin/page.tsx` (`'credits'` 추가 + TAB_LABELS `credits: '크레딧'` + import + 렌더링 분기) |
| 타입 정의 (있다면) | web | (CreditsTab 내부 또는 `grimoire-web/src/lib/types.ts` — local interface 권고, 글로벌 타입 신설 0건) |
| sensor 신설 | claude-docs | `.claude/scripts/sensor-admin-credit-ui.sh` (CreditsTab 핵심 grep 7건 — 사용자 검색/잔액/모달/grant/deduct/spec/page.tsx 등록) |
| eval regression | claude-docs | `eval/tasks/regression-54-admin-credit-ui.json` (eval_criteria ≥6건) |
| shared-contracts §13 (선택) | claude-docs | `.claude/shared-contracts.md` §13 — AdminCreditOperation 인터페이스 박제 (선택 — 백엔드 시그니처 그대로 활용이라 신설 효익 낮음. Generator가 §11/§12 후행 박제 시 권고 정도) |

### 2-2. OUT

- **server 변경 0건** — 백엔드 API 그대로 활용. controller/usecase/repo 변경 0건. AuditLog 인프라 활용 (operator=admin user.id + action=`grant_credits`/`deduct_credits` 기존 박제 그대로).
- **신규 RBAC 도입** — 현재 단일 admin role. cs-admin/read-only 분리는 P3 (PAYMENT_SYSTEM_PLAN §2-2 #4 권고).
- **CreditsTab 내부 일괄 지급(bulk grant)** — 본 Sprint는 1:1 단일 사용자 지급만. 일괄 지급은 P1.
- **결제 이력 모달 + 상세 영수증** — PaymentsTab 영역 (이미 존재). 본 Sprint는 크레딧 영역만.
- **이메일 알림 (사용자에게 "크레딧 지급되었습니다" 통보)** — PAY-P1-2 (결제 알림 sprint).
- **CSV import (대량 지급)** — P1.
- **before/after balance 박제** — 백엔드 AuditLog detail JSON에 추가하는 것은 P2 (PAYMENT_SYSTEM_PLAN §2-2 #3). 본 Sprint는 UI에서 조회한 잔액 표시만.
- **server 외 레포 (server)** — 본 Sprint는 100% web + claude-docs (sensor + eval). server 변경 0건 박제 의무 (Generator git diff로 server 레포 touch 0건 박제).

---

## 3. 결정 사항 (Initializer 최종)

### 3-1. UI 흐름 정본

```
[관리자 메인] /admin
  └─ Tab "크레딧" 클릭
      ↓
[CreditsTab]
  ┌─────────────────────────────────────┐
  │ [1] 사용자 검색                      │
  │   <input placeholder="이름/이메일"/>  │
  │   <button>검색</button>              │
  │   → searchAuthors(query) 호출        │
  │   → 결과 list (id/name/email/role)  │
  │   → 한 명 클릭 → 선택 상태           │
  ├─────────────────────────────────────┤
  │ [2] 선택된 사용자 정보               │
  │   id: xxx / name: xxx               │
  │   email: xxx / 현재 잔액: N 크레딧   │
  │   (잔액은 adminGetAuthor 또는        │
  │    adminGetCreditLogs로 표시)        │
  ├─────────────────────────────────────┤
  │ [3] 지급/차감 입력                   │
  │   <select>                          │
  │     <option value="grant">지급</option>│
  │     <option value="deduct">차감</option>│
  │   </select>                         │
  │   <input type="number" min="1"/>    │
  │   <textarea placeholder="사유 (필수)"/>│
  │   <button>실행</button>              │
  ├─────────────────────────────────────┤
  │ [4] 멀티콘펌 모달                    │
  │   "사용자 X에게 +N 크레딧을           │
  │    [지급]하시겠습니까?                │
  │    사유: ___"                        │
  │   <button>취소</button>              │
  │   <button class="bg-red-600">       │
  │     확인 (실행)                      │
  │   </button>                          │
  │   → adminGrantCredits 또는           │
  │     adminDeductCredits 호출         │
  │   → 성공 시 토스트 + 최근 로그 갱신  │
  │   → 실패 시 에러 토스트              │
  ├─────────────────────────────────────┤
  │ [5] 최근 크레딧 로그 (선택 사용자)   │
  │   <table>                           │
  │     <th>시각/금액/사유/operator</th> │
  │   </table>                          │
  │   → adminGetCreditLogs(authorId)    │
  └─────────────────────────────────────┘
```

### 3-2. grant/deduct 분기 정책

**[MUST]** 운영자가 amount 입력 시 항상 **양수**로 입력. grant/deduct는 select로 분리.
- `mode === 'grant'` → `api.adminGrantCredits(authorId, amount, reason)` (양수 amount)
- `mode === 'deduct'` → `api.adminDeductCredits(authorId, amount, reason)` (양수 amount — 백엔드가 차감 처리)

**기각 대안**:
- 부호로 grant/deduct 분기 (음수 = deduct) — UX 모호 + 입력 실수 위험. 기각.

### 3-3. 멀티콘펌 모달 정책

**[MUST]** 모달 띄울 때 **요약 박제 필수** — 사용자 ID + 이름 + 현재 잔액 + 지급/차감 + 금액 + 사유 + 예상 잔액(after).

```
"홍길동 (hong@example.com, ID: abc12345...)
 현재 잔액: 100 크레딧
 → +50 지급 (사유: 이벤트 보상)
 → 처리 후 잔액: 150 크레딧

 정말 실행하시겠습니까?
 [취소]  [확인 (실행)]"
```

**[MUST]** 확인 버튼은 `bg-red-600 hover:bg-red-700` (위험 작업 강조)
**[MUST]** 모달 띄우는 동안 [실행] 버튼 disabled (race 차단)
**[MUST]** API 호출 진행 중 모달 내부 [확인] 버튼도 disabled + 스피너 (idempotency via UI state — `useThrottle.ts:33-47` 패턴 차용 가능)

### 3-4. 토스트 정책

- 성공: `"크레딧 N개 지급 완료"` 또는 `"크레딧 N개 차감 완료"` (3초 자동 제거)
- 실패: `"실패: {error.message}"` (5초 자동 제거 + 빨강)
- 토스트 라이브러리: 이미 사용 중인 `react-hot-toast` 또는 `sonner` 또는 자체 stores/toast 권고. Generator가 admin 영역 기존 패턴(다른 Tab grep) 확인 후 동일 패턴 사용.

**Generator 확인 grep**:
```bash
grep -rnE "from 'react-hot-toast'|from 'sonner'|useToast" grimoire-web/src/app/admin/
```

토스트 라이브러리 미사용 시 신설 0건 — `alert()` 또는 inline `<div>` (CreditsTab 내부 state) 권고. 의존성 추가 0건.

### 3-5. 잔액 조회 방법

**[옵션 A — 채택]**: `adminGetAuthor(authorId)` API client에 `credits` 필드 포함 시 활용. (서버 admin.controller.ts 시그니처 확인 후 결정)

**[옵션 B — fallback]**: `adminGetCreditLogs(authorId)` 응답을 합산 — 부정확 가능 (signed sum 정확도). **권고하지 않음**.

**[옵션 C — fallback 2]**: 백엔드에 `GET /admin/authors/:id/balance` 신설 — server 변경 발생. **본 Sprint OUT** (Scope 위반).

**Generator 결정**:
1. `grimoire-server/src/adapter/inbound/http/controller/admin.controller.ts` grep `getAuthor`/`credits` 박제
2. 옵션 A 가능 시 채택 → CreditsTab에서 `api.adminGetAuthor(authorId)` 호출 (또는 `searchAuthors` 응답에 credits 포함 시 그대로 활용)
3. 옵션 A 불가 시 본 progress.md §3-5 갱신 후 사용자 결정

### 3-6. 라우팅 정책

- 본 Sprint는 **별도 route 신설 0건** — `/admin?tab=credits` URL 쿼리 미도입 (다른 tab도 미적용 — page.tsx state-only).
- 향후 deep-link 필요 시 P2.

### 3-7. 권한 체크 정책

- `/admin/*` 페이지 접근은 이미 `admin/page.tsx:36-43`에서 role 체크 (admin만 통과).
- CreditsTab 내부에서 추가 권한 체크 0건 (Tab 자체가 admin 한정).
- **백엔드 가드**: admin.controller.ts `@Roles(Role.ADMIN)` 또는 동등 데코레이터 박제 확인 (server agent 정합 — 본 Sprint OUT).

---

## 4. Acceptance Criteria (AC) — 6건, Ambiguity ≤ 0.1

각 AC는 **실측 검증 가능한 raw stdout / grep 결과 / vitest 결과**로 증명. Generator는 본 AC를 충족하지 못하면 작업 미완료 박제 (DEV_REPORT.md에 raw stdout 박제).

### AC-1: CreditsTab 컴포넌트 신설 (검색 + 잔액 + 입력 + 모달 + 토스트 + 로그)

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web
test -f src/app/admin/tabs/CreditsTab.tsx
grep -nE 'export function CreditsTab|export default function CreditsTab' src/app/admin/tabs/CreditsTab.tsx
grep -nE 'searchAuthors' src/app/admin/tabs/CreditsTab.tsx
grep -nE 'placeholder.*사유|placeholder.*reason' src/app/admin/tabs/CreditsTab.tsx
grep -nE 'adminGetCreditLogs' src/app/admin/tabs/CreditsTab.tsx
```

**기대 raw 출력**:
- 파일 존재
- `export function CreditsTab` 또는 `export default function CreditsTab` 1건
- `api.searchAuthors(` 호출 1건 이상
- 사유 입력 placeholder 박제 1건
- `api.adminGetCreditLogs(` 호출 1건 이상 (선택 사용자 최근 로그 표시)

### AC-2: api.adminGrantCredits / adminDeductCredits 호출 분기 (mode select + 양수 amount)

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web
grep -nE 'adminGrantCredits|adminDeductCredits' src/app/admin/tabs/CreditsTab.tsx
grep -nE "'grant'|'deduct'|mode === 'grant'|mode === 'deduct'" src/app/admin/tabs/CreditsTab.tsx
grep -nE "type=.number.|min=.1." src/app/admin/tabs/CreditsTab.tsx
```

**기대 raw 출력**:
- `api.adminGrantCredits(` + `api.adminDeductCredits(` 둘 다 1건 이상
- mode 분기 박제 (`'grant'` / `'deduct'` 문자열 비교)
- amount input은 type="number" min="1" (음수/0 차단)

### AC-3: vitest spec — 검색 → 선택 → 입력 → 모달 → 확인 → API + 토스트 검증

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web
test -f src/app/admin/tabs/CreditsTab.spec.tsx
grep -nE "describe\\(.CreditsTab|it\\(|test\\(" src/app/admin/tabs/CreditsTab.spec.tsx
grep -nE 'adminGrantCredits|adminDeductCredits' src/app/admin/tabs/CreditsTab.spec.tsx
grep -nE 'searchAuthors' src/app/admin/tabs/CreditsTab.spec.tsx
grep -nE '확인|모달|confirm|modal' src/app/admin/tabs/CreditsTab.spec.tsx
npm test -- CreditsTab 2>&1 | tail -20
```

**기대 raw 출력**:
- spec 파일 존재
- `describe('CreditsTab', ...)` 1건
- `it`/`test` 블록 ≥4건:
  - it-1: 검색 → 결과 표시 (`searchAuthors` mock 호출)
  - it-2: 사용자 선택 → 잔액 표시 + 최근 로그 호출
  - it-3: 금액 + 사유 입력 → 실행 버튼 클릭 → 모달 표시
  - it-4: 모달 [확인] 클릭 → `adminGrantCredits` 1회 호출 + 토스트 박제 (또는 deduct 분기)
  - (선택) it-5: 모달 [취소] 클릭 → API 호출 0회
  - (선택) it-6: amount=0 또는 reason 빈값 → 실행 버튼 disabled
- vitest stdout `Test Files X passed` (1 + 기존 spec) + 회귀 0건

### AC-4: admin/page.tsx Tab 등록 + active state + import

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web
grep -nE "import.*CreditsTab.*from.*tabs/CreditsTab" src/app/admin/page.tsx
grep -nE "type Tab = .*'credits'" src/app/admin/page.tsx
grep -nE "credits:\\s*'크레딧'" src/app/admin/page.tsx
grep -nE "tab === 'credits'.*<CreditsTab" src/app/admin/page.tsx
```

**기대 raw 출력**:
- import 1건: `import { CreditsTab } from './tabs/CreditsTab'`
- Tab union에 `'credits'` 포함
- TAB_LABELS에 `credits: '크레딧'` 포함
- 렌더링 분기 1건: `{tab === 'credits' && <CreditsTab />}`

### AC-5: visual-canon-keeper 사전 검수 PASS (admin neutral-* 영역 정합, 작가 g-* 침범 0건)

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-web
grep -nE 'g-bg|g-fg|g-accent|var\\(--g-' src/app/admin/tabs/CreditsTab.tsx
grep -nE 'bg-neutral-|border-neutral-|text-neutral-|text-white|bg-red-600' src/app/admin/tabs/CreditsTab.tsx
grep -nE 'dangerouslySetInnerHTML' src/app/admin/tabs/CreditsTab.tsx
```

**기대 raw 출력**:
- `g-*` 작가 토큰 사용 0건 (3 grep 모두 결과 0건)
- `bg-neutral-*` / `border-neutral-*` / `text-neutral-*` / `text-white` / `bg-red-600` (위험 액션) 박제 ≥5건
- `dangerouslySetInnerHTML` 사용 0건 (XSS 차단)

### AC-6: regression-54 + sensor-admin-credit-ui.sh 신설 + eval 53→54 PASS

**검증 명령**:
```bash
cat /Users/sokol/Desktop/Git/ProjectGrimoire/eval/tasks/regression-54-admin-credit-ui.json
ls /Users/sokol/Desktop/Git/ProjectGrimoire/eval/tasks/regression-*.json | wc -l
ls -la /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-admin-credit-ui.sh
bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/sensor-admin-credit-ui.sh
echo "exit code: $?"
bash /Users/sokol/Desktop/Git/ProjectGrimoire/eval/scripts/eval-runner.sh 2>&1 | tail -10
```

**기대 raw 출력**:
- regression-54 JSON 존재 + eval_criteria ≥6건 (AC-1~5 grep 명령 박제)
- `ls regression-*.json | wc -l` 결과 54 (현재 53)
- sensor 파일 존재 + chmod +x
- 직접 실행 시 PASS (exit 0) — 검증 항목 ≥7건:
  1. `CreditsTab.tsx` 파일 존재
  2. `searchAuthors` 호출 박제
  3. `adminGrantCredits` + `adminDeductCredits` 둘 다 박제
  4. `admin/page.tsx`에 CreditsTab import 박제
  5. Tab union에 `'credits'` 포함
  6. `CreditsTab.spec.tsx` 파일 존재
  7. g-* 작가 토큰 사용 0건 박제
- eval-runner stdout 마지막 행: `regression: 54/54 PASS (100%)` 또는 동등

---

## 5. Test Plan

### 5-1. 단위 테스트 (vitest + @testing-library/react)

| spec 파일 | 신규 it 블록 |
|---|---|
| `CreditsTab.spec.tsx` (신설) | (a) 검색 input → searchAuthors 호출 + 결과 list 렌더링 (b) 사용자 row 클릭 → 선택 상태 + adminGetCreditLogs 호출 (c) amount=0 또는 reason 빈값 → 실행 버튼 disabled (d) 정상 입력 → 실행 클릭 → 모달 표시 + summary 박제 (e) 모달 [취소] → 모달 닫힘 + API 호출 0회 (f) 모달 [확인] (mode=grant) → adminGrantCredits 1회 호출 + 토스트 (g) 모달 [확인] (mode=deduct) → adminDeductCredits 1회 호출 + 토스트 (h) API 실패 시 에러 토스트 박제 |

mock 패턴 (Generator 참고):
```typescript
import { vi } from 'vitest'
import { api } from '@/lib/api'

vi.mock('@/lib/api', () => ({
  api: {
    searchAuthors: vi.fn(),
    adminGrantCredits: vi.fn(),
    adminDeductCredits: vi.fn(),
    adminGetCreditLogs: vi.fn(),
  },
}))
```

### 5-2. 통합 테스트 — 수동 (localhost)

`reports/sprint-pay-p0-3-admin-credit-grant-ui-progress.md` Generator 단계에서:
1. localhost server (3000) + web (3001) 동시 부팅
2. admin 로그인 (관리자 시드 계정)
3. /admin → "크레딧" tab 클릭
4. 검색 → 시드 사용자 선택 → 잔액 박제 확인
5. 지급 mode + amount=10 + reason="테스트 보상" → 실행 → 모달 확인 → 확인 버튼 → 토스트 + DB 박제 확인 (psql `SELECT * FROM credit_logs ORDER BY created_at DESC LIMIT 1`)
6. AdminAuditLog 박제 확인 (psql `SELECT * FROM admin_audit_logs ORDER BY created_at DESC LIMIT 1` — operator + action='grant_credits' + targetId + detail JSON)
7. 차감 mode + amount=5 → 동일 흐름 검증

**raw 박제 위치**: DEV_REPORT.md Web 섹션 §3 구현 결과 + §5 sensor 결과 (psql SELECT 결과 전문 + Chrome DevTools 스크린샷 또는 console.log 박제)

### 5-3. sensor 회귀

- `sensor-credit-atomicity` PASS 유지 (FAIL 회귀 시 즉시 차단 — server 변경 0건이므로 영향 0)
- `sensor-payment-idempotency` (PAY-P0-1) PASS 유지
- `sensor-payment-reconciliation` (PAY-P0-2) PASS 유지
- `sensor-admin-credit-ui` (신설) PASS
- `sensor-shared-contracts` drift 0 (§13 신설 시 mtime 갱신, 미신설 시 변경 0)
- `sensor-web` PASS (`npm test` + `npx tsc --noEmit` 0 errors)
- `sensor-docs-sync` PASS
- `sensor-adversarial-pre-commit` PASS

### 5-4. eval 회귀

- regression-52 (PAY-P0-1) PASS 유지
- regression-53 (PAY-P0-2) PASS 유지
- regression-54 (본 Sprint 신설) PASS
- regression 53→54 / EDD 21~33 모두 PASS (drift 0)

---

## 6. 검증 게이트 (Generator → Evaluator 핸드오프 전 필수 통과)

### 6-1. web 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G1 | TypeScript | `npx tsc --noEmit` | 0 errors |
| G2 | Lint | `npm run lint` | 0 errors |
| G3 | vitest (전체) | `npm test 2>&1 \| tail -20` | 모든 spec PASS, 회귀 0건 |
| G4 | Build | `npm run build` | 0 errors |
| G5 | E2E (선택) | `npm run test:e2e -- --grep credit` | (E2E 신설 미포함 시 SKIP) |

### 6-2. claude-docs 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G6 | sensor 8종 | `for s in sensor-shared-contracts sensor-web sensor-docs-sync sensor-credit-atomicity sensor-payment-idempotency sensor-payment-reconciliation sensor-admin-credit-ui sensor-adversarial-pre-commit; do bash .claude/scripts/$s.sh; done` | 모두 exit 0 (PASS) |
| G7 | eval | `bash eval/scripts/eval-runner.sh` | regression 54/54 PASS, drift 0 |

### 6-3. server 검증 게이트 (변경 0건 박제)

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G8 | server 레포 git diff | `cd grimoire-server && git diff --stat develop` | 0 files changed (본 Sprint server touch 0건) |

### 6-4. Evaluator (qa) 채점 항목

- AC 6건 각각 PASS/FAIL 판정 (raw stdout 박제)
- DEV_REPORT.md `Web 섹션 §5 센서 결과` raw stdout 전문 박제 여부
- QA_REPORT.md `### sprint-pay-p0-3-admin-credit-grant-ui 통과율` 박제 (목표 6/6 = 100%)
- dev 환경 배포 후 admin /admin 접속 → "크레딧" tab 동작 검증 (Chrome 실제 확인 — Memory `feedback_chrome_verify.md` 정합)
- 통합 테스트 §5-2 결과 박제 (psql credit_logs + admin_audit_logs row)

---

## 7. 산출물 체크리스트

### 7-1. web 산출물

- [x] `src/app/admin/tabs/CreditsTab.tsx` — 신설 (검색 + 잔액 + 입력 + confirm() 멀티콘펌 + sonner toast + neutral-* 토큰 + helper text). VCK AA-1~7 모두 준수.
- [x] `src/app/admin/tabs/CreditsTab.test.tsx` — 신설 7 it 블록 (vitest config의 `.test.tsx` 컨벤션 정합. 사용자 명시 "더미 spec 0건" — toHaveBeenCalledWith / mock.calls[0] / waitFor 모두 실제 함수 호출 검증).
- [x] `src/app/admin/page.tsx` — Tab union에 `'credits'` 추가, `TAB_LABELS.credits`, `import { CreditsTab }`, `tab === 'credits' && <CreditsTab />`. 기존 인라인 `function CreditsTab` 제거.
- [x] DEV_REPORT.md Web 섹션 — sensor-web raw stdout + sensor-admin-credit-ui raw stdout + eval-runner raw stdout 박제 (본 메시지 §"raw stdout 박제"에 전문). 통합 §5-2 수동 검증(localhost psql)은 qa 단계 위임 (Generator 단계 제약).
- [x] `TECH_STATUS.md` (web 레포) — Admin 카테고리에 PAY-P0-3 한 줄 박제.
- [x] `CHANGELOG.md` (web 레포) — `[Unreleased]` 최상단에 Added — 운영자 수동 크레딧 지급/차감 web UI (PAY-P0-3) 박제 (Added/server 변경 0건/검증 결과).
- [x] `SCREENS.md` (web 레포) — `/admin` 행에 15 탭 + 크레딧 탭(`tabs/CreditsTab.tsx`) + 4 API 박제.
- [ ] (선택) `DESIGN.md` (web 레포) — 본 Sprint는 confirm() 사용(커스텀 모달 0건) → DESIGN.md 모달 섹션 변경 불필요.

### 7-2. claude-docs 산출물

- [x] `.claude/scripts/sensor-admin-credit-ui.sh` — 신설 (chmod +x, 검증 항목 10건 — AC-6 정본 7건 + 추가 3건). 첫 실측 PASS 10/10.
- [x] `eval/tasks/regression-54-admin-credit-grant-ui.json` — 메인이 사전 신설 (eval_criteria 8건). Generator 단계에서 모두 PASS 검증.
- [x] `research/HARNESS_ENGINEERING.md` §14.4 갱신 — Sensors 27 → 28 + sensor-admin-credit-ui.sh 행 추가 (regression-006 sensor count drift 해소).
- [ ] (선택) `.claude/shared-contracts.md` §13 — AdminCreditOperation 인터페이스 박제 — 백엔드 시그니처 재사용이라 효익 낮음. **미박제 (선택 항목, scope §1-2 결론과 정합)**.
- [ ] PLANNING_GRIMOIRE.md — PAY-P0-3 완료 마크 — 사용자 승인 필요. Initializer 권고만.

### 7-3. server 변경 없음

- 본 Sprint는 100% web + claude-docs. server 변경 0건. Generator는 git diff로 server 레포 touch 0건 박제 의무 (§6-3 G8).

---

## 8. 위험 / 롤백 정책

### 8-1. 위험 항목

| # | 위험 | 영향 | 완화 |
|---|---|---|---|
| R1 | 운영자가 amount 또는 authorId 잘못 입력 | 사용자 피해 (크레딧 오지급/오차감) | 멀티콘펌 모달 — 사용자 ID + 이름 + 현재 잔액 + 처리 후 예상 잔액 박제 후 [확인] 버튼. + AuditLog 자동 박제로 추적 가능 (server 인프라). |
| R2 | 모달 [확인] 더블 클릭 race | 같은 작업 2회 처리 → 2배 금액 | 모달 내부 [확인] 버튼은 클릭 시 즉시 disabled (state) + 스피너. API 응답 후 모달 닫힘. |
| R3 | searchAuthors 결과에 credits 필드 부재 | 잔액 표시 불가 → 옵션 A 폴백 필요 | Generator §3-5 결정 흐름 따라 옵션 A → 옵션 B → 옵션 C 순서 시도. 옵션 A 가능 시 즉시 채택. |
| R4 | 작가 g-* 토큰 누수 (CreditsTab에서 g-bg 등 사용) | 작가 공간 시각 정본 침범 | sensor-admin-credit-ui에서 grep 검증 + AC-5에서 raw 박제 |
| R5 | adminGetCreditLogs 응답 무거움 (전체 로그) | 페이지 응답 지연 | API client에 `?limit=20` 또는 페이지네이션 추가 권고 (server 변경 필요 시 본 Sprint OUT — Generator가 필요시 본 progress.md 갱신 후 사용자 결정). 임시: 클라이언트에서 `.slice(0, 20)` 박제. |
| R6 | Tab 추가로 admin/page.tsx 14→15 건 — 가로 스크롤 발생 | 작은 화면에서 UX 저하 | 기존 `overflow-x-auto` (page.tsx:56) 그대로 활용 — 영향 0. |
| R7 | vitest spec에서 모달 동작 mock 어려움 | 테스트 미통과 | @testing-library/react `userEvent.click` + `findByRole('dialog')` 패턴 권고. dialog 미사용 시 inline div + role="dialog" aria-modal="true" 박제. |

### 8-2. 롤백 정책

- **코드 차원**: CreditsTab import + Tab union에서 `'credits'` 제거 + 렌더링 분기 제거 → web 1 commit revert.
- **DB 차원**: 본 Sprint는 schema 변경 0건 → 롤백 의무 0.
- **운영 차원**: PAY-P0-3 미배포 상태로 롤백 시 운영자는 기존 백엔드 API 직접 호출 또는 PAY-P0-2 cron 자동 보정 활용 (CS 보상 등은 일시적으로 백엔드 직접 호출).

### 8-3. 사전 백업 권장

- 본 Sprint는 schema 변경 0건 → 백업 의무 0.
- 단 운영자가 dev 환경에서 처음 사용할 때 시드 사용자에게 grant/deduct 수동 테스트 후 prod 배포 권고.

---

## 9. shared-contracts §13 신설 안 (선택 — claude-docs Generator 박제 정본)

**[NICE]** claude-docs Generator는 아래 텍스트 블록을 `.claude/shared-contracts.md` `## 12. PaymentReconciliation` 섹션 직후에 박제 (선택 — 효익 낮음. 시간 여유 시):

```text
{HASH}{HASH} 13. AdminCreditOperation (운영자 수동 지급 — web UI 신설)

**위치**:
- web Component: `grimoire-web/src/app/admin/tabs/CreditsTab.tsx`
- web spec: `grimoire-web/src/app/admin/tabs/CreditsTab.spec.tsx`
- web API client: `grimoire-web/src/lib/api.ts:541-552` (adminGrantCredits / adminDeductCredits / adminGetCreditLogs)
- server Controller: `grimoire-server/src/adapter/inbound/http/controller/admin.controller.ts` (POST /admin/credits/grant, POST /admin/credits/deduct, GET /admin/credits/logs) — **변경 0건**
- server UseCase: `grimoire-server/src/application/admin/admin.usecase.ts` (grantCredits + deductCredits + auditLog 자동 호출) — **변경 0건**

**적용**: 관리자 패널 web UI에서 사용자 검색 → 잔액 표시 → grant/deduct 분기 → 멀티콘펌 모달 → API 호출 → AuditLog 자동 박제. **사람 실수 위험 0건**.

{HASH}{HASH}{HASH} 시그니처 (web 기준 — 신규 인터페이스 0건, 기존 api.ts 재사용)

```typescript
api.searchAuthors(query: string): Promise<Array<{ id; name; email; role; credits? }>>
api.adminGrantCredits(authorId: string, amount: number, reason: string): Promise<unknown>
api.adminDeductCredits(authorId: string, amount: number, reason: string): Promise<unknown>
api.adminGetCreditLogs(authorId?: string): Promise<unknown[]>
```

{HASH}{HASH}{HASH} 정책

- amount는 항상 양수. mode select로 grant/deduct 분기.
- 멀티콘펌 모달 — 사용자 ID + 이름 + 현재 잔액 + 처리 후 예상 잔액 + 사유 박제 후 확인.
- 모달 [확인] 더블 클릭 차단: 클릭 시 즉시 disabled + 스피너.
- AuditLog는 server admin.usecase가 자동 박제 (operator=admin user.id, action=grant_credits|deduct_credits, targetId=authorId, detail={ amount, reason }).
- 작가 공간 g-* 토큰 사용 0건 (관리자 = neutral-* 영역).

{HASH}{HASH}{HASH} 변경 이력
- 2026-05-03 PAY-P0-3: AdminCreditOperation 인터페이스 박제 (운영자 수동 지급 web UI 신설, 백엔드 API 재사용, server 변경 0건)
```

추가로 shared-contracts.md 마지막 줄 `마지막 업데이트:` 라인을 `2026-05-03 (§13 AdminCreditOperation 신설)`로 교체.

---

## 10. HANDOFF Chain

```
planner (Initializer — 본 sprint progress + PLANNER_REPORT 갱신 완료)
  ↓
cost-accountant (사전 — ✅ 면제. AI 호출 0건 + 인프라 비용 영향 0건. 본 Sprint는 100% web UI + 기존 백엔드 API 재사용.)
  ↓
visual-canon-keeper (사전 — ✅ 검수 필요. 관리자 패널 = neutral-* 영역, 작가 g-* 침범 0건 보장. PaymentsTab 패턴 정합 박제.)
  ↓
grimoire-web (Generator)
  - 본 progress.md §2 IN — web 4건 (CreditsTab + spec + page.tsx 변경 + 문서) + §7-1 산출물 체크리스트 완수
  - DEV_REPORT.md Web 섹션 §5 raw stdout 전문 박제
  - 검증 게이트 G1~G4 모두 PASS
  ↓ (병렬 가능)
grimoire-claude-docs (Generator) — 메인 또는 planner 직접 박제
  - sensor-admin-credit-ui.sh + regression-54 신설 (선택: shared-contracts §13)
  - 검증 게이트 G6 + G7 PASS
  ↓
grimoire-qa (Evaluator)
  - AC 6건 raw 채점 (PASS/FAIL 박제)
  - QA_REPORT.md `### sprint-pay-p0-3-admin-credit-grant-ui 통과율` 박제
  - dev 환경 Chrome 실제 검증 (admin /admin → 크레딧 tab 동작) + psql credit_logs + admin_audit_logs raw row
  ↓
사용자 (배포 게이트 최종 판정)
  - qa PASS 시 develop → main per-repo 머지 (web + claude-docs 2 레포)
  - prod 배포 (Container Apps 재배포 — schema 변경 0건이므로 무중단)
```

- **next agent**: visual-canon-keeper (사전 검수) → grimoire-web + grimoire-claude-docs (병렬) → grimoire-qa
- **마감**: 본 세션 종료 전 dev 머지 (사용자 명시 — "PAY-P0 3건 dev까지 진행 + 머지")
- **단일 진실**: 본 progress.md (Generator/Evaluator 모두 본 파일 Read 후 작업, 모호하면 본 파일 갱신 후 합의)
- **server 변경 0건 박제**: Generator git diff 결과 박제 (§6-3 G8) — 본 Sprint Scope 보장 핵심

---

## 11. 참조

- `research/PAYMENT_SYSTEM_PLAN.md` §3-1 PAY-P0-3 + §1-5 #3 (운영자 web UI 부재 갭)
- `reports/sprint-pay-p0-1-webhook-event-id-idempotency-progress.md` (선행 Sprint 1 — server `8c13103` + claude-docs `06de6c6`)
- `reports/sprint-pay-p0-2-payment-reconciliation-cron-progress.md` (선행 Sprint 2 — server + claude-docs develop push 완료)
- `grimoire-web/src/lib/api.ts:541-552` (adminGrantCredits / adminDeductCredits / adminGetCreditLogs — 본 Sprint 활용)
- `grimoire-web/src/lib/api.ts:324` (searchAuthors — 사용자 검색 활용)
- `grimoire-web/src/app/admin/page.tsx` (admin 메인 — Tab union 변경 대상)
- `grimoire-web/src/app/admin/tabs/PaymentsTab.tsx` (시각 정본 패턴 차용 — neutral-* 색상 체계)
- `grimoire-server/src/adapter/inbound/http/controller/admin.controller.ts` (백엔드 — 변경 0건)
- `grimoire-server/src/application/admin/admin.usecase.ts` (백엔드 — 변경 0건, AuditLog 자동 박제 활용)
- `grimoire-web/CLAUDE.md` §2 BFF 프록시 + 보안 체크리스트
- `.claude/shared-contracts.md` §11 (PAY-P0-1) + §12 (PAY-P0-2) + §13 (본 Sprint 선택 신설)
- 책 Ch 16 Anthropic 3-에이전트 (Initializer → Generator → Evaluator) — 묶음 II 5회차
- Memory `feedback_chrome_verify.md` (Chrome 실제 확인 의무 — qa 단계 정합)
- Memory `feedback_visual_canon.md` (시각적 정본은 사슴악마 — 작가 g-* 토큰. 본 Sprint는 admin neutral-* 영역이므로 침범 0건 박제 의무)

---

**마지막 업데이트**: 2026-05-03 (Initializer 신설 — server 변경 0건 박제, visual-canon-keeper 사전 검수 게이트, AC 6건 + Ambiguity ≤ 0.1)
