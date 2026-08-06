# Sprint PAY-P2-4 AdminAuditLog 정밀화 강화 — Sprint 계약 (Initializer)

> **유형**: 결제 시스템 PAY-P2-4 — AdminAuditLog detail JSON 표준화 (beforeState / afterState 강제 박제)
> **트리거**: 사용자 명시 2026-05-06 1+2 진행 — "PAY-P2-4 AdminAuditLog 정밀화 강화"
> **소요 추정**: ~2.5시간 (server Generator) + ~30분 (메인 Coordinator + qa Evaluator)
> **외부 API 신규 의존**: 0건 (internal port 시그니처 확장만, 절대 규정 0-1 정합)
> **종료 조건**: AC-1~AC-7 모두 PASS + spec ≥ 6 it (audit-log.service.spec.ts 신설) + sensor-audit-log-before-after PASS + regression-64 PASS + 회귀 보존 (regression 63→64, jest server 601 → ≥ 607)
> **정본 참조**: `research/PAYMENT_SYSTEM_PLAN.md` §3-3 P2-3 (AdminAuditLog 검증 spec + before/after 강화), `reports/PAY-P2-MASTER-PLAN.md`, `.claude/shared-contracts.md` §2 COST_AUDIT + §13 RefundPaymentAtomically

---

## §1. 개요 (책 Ch 16 Initializer)

### 1-1. 목표

현재 `AuditLogService.log(adminId, action, targetId?, detail?)`는 `detail` JSON에 자유 형식으로 키를 박제하고 있습니다. 일부 호출처(예: `admin.usecase.updateAuthor`, `changeRole`, `episode_status_change`)는 `before` / `after` 키로 변경 추적을 하고 있으나, **크레딧 부여/차감/환불** 등 가장 민감한 결제 도메인은 `before` / `after` 박제가 누락되어 있습니다.

PAY-P2-4는 다음 두 가지를 동시에 해결합니다:
1. **인터페이스 표준화** — `auditLog.log()`에 optional `beforeState?` / `afterState?` 인자 추가 (Record<string, unknown>) → detail JSON에 표준 키 강제
2. **결제/크레딧 호출처 박제 강화** — grantCredits / deductCredits / processWebhook(success) / refund-payment.usecase 4 호출처에 잔액 before/after 박제

### 1-2. 도메인

server (단일 레포) — application layer + spec 신설. web 변동 0건. claude-docs는 sensor + regression + shared-contracts 갱신.

### 1-3. 외부 검증

외부 API 0건. Polar SDK / 외부 SaaS 영향 0. DB 스키마 영향 0건 (AdminAuditLog.detail JSON 컬럼은 이미 존재).

### 1-4. 정본 참조

- `research/PAYMENT_SYSTEM_PLAN.md` §3-3 P2-3 — 본 sprint의 정본 권고
- `reports/PAY-P2-MASTER-PLAN.md` (메인 박제) — PAY-P2 전체 트랙 우선순위
- `.claude/shared-contracts.md` §2 COST_AUDIT (변동 0) + §13 RefundPaymentAtomically (PAY-P1-1 회귀 보존 의무)
- `grimoire-server/src/application/admin/audit-log.service.ts` (현재 시그니처)
- `grimoire-server/src/application/admin/admin.usecase.ts:93-101` (grantCredits / deductCredits 현재 박제)
- `grimoire-server/src/application/payment/payment.usecase.ts` (processWebhook success 분기)
- `grimoire-server/src/application/payment/refund-payment.usecase.ts:108-119` (system_refund auditLog 호출)
- `grimoire-server/src/application/admin/admin.usecase.spec.ts:152-159` (현재 grantCredits/deductCredits spec — 단순 toHaveBeenCalledWith)

---

## §2. AC (Acceptance Criteria) — 7건

### AC-1. AuditLogService.log() 시그니처 확장 (BACKWARD COMPATIBLE)

**구현 위치**: `grimoire-server/src/application/admin/audit-log.service.ts`

**변경**:
```typescript
async log(
  adminId: string,
  action: string,
  targetId?: string,
  detail?: Record<string, unknown>,
  beforeState?: Record<string, unknown>,  // 신규 optional
  afterState?: Record<string, unknown>,   // 신규 optional
): Promise<void> {
  const enrichedDetail = {
    ...(detail ?? {}),
    ...(beforeState !== undefined ? { beforeState } : {}),
    ...(afterState !== undefined ? { afterState } : {}),
  }
  await this.auditLogRepo.create(adminId, action, targetId, enrichedDetail)
}
```

**검증 (BDD)**:
- Given: 기존 `log(adminId, action, targetId, detail)` 4-arg 호출처 (`admin.usecase` 22개 + `payment-reconciliation.job` 3개 + `webhook-retry.job` 1개)
- When: PAY-P2-4 시그니처 확장 적용
- Then: 4-arg 호출은 그대로 동작 (beforeState/afterState undefined → detail JSON에 키 미박제) — **회귀 0건**

### AC-2. admin.usecase.grantCredits — 잔액 before/after 박제

**구현 위치**: `grimoire-server/src/application/admin/admin.usecase.ts:93-97`

**변경**:
```typescript
async grantCredits(adminId: string, authorId: string, amount: number, reason: string): Promise<{ credits: number; log: CreditLog }> {
  const author = await this.authorRepo.findById(authorId)
  if (!author) throw new NotFoundException('작가를 찾을 수 없습니다')
  const balanceBefore = author.credits
  const result = await this.creditUseCase.grant(authorId, amount, `admin_grant:${reason}`)
  await this.auditLog.log(
    adminId,
    'credit_grant',
    authorId,
    { amount, reason },
    { credits: balanceBefore },
    { credits: result.credits },
  )
  return result
}
```

**검증 (BDD)**:
- Given: author.credits = 100, amount = 50
- When: grantCredits 호출
- Then: `auditLog.log` 6번째 인자 = `{ credits: 100 }`, 7번째 인자 = `{ credits: 150 }` 박제

### AC-3. admin.usecase.deductCredits — 잔액 before/after 박제

**구현 위치**: `grimoire-server/src/application/admin/admin.usecase.ts:99-103`

**변경**: AC-2와 동일 패턴 (`balanceBefore` 사전 조회 → `auditLog.log`에 두 state 전달).

**검증 (BDD)**:
- Given: author.credits = 100, amount = 30
- When: deductCredits 호출
- Then: `auditLog.log` beforeState = `{ credits: 100 }`, afterState = `{ credits: 70 }` 박제

### AC-4. payment.usecase.processWebhook 'success' 분기 — 잔액 + paymentId 박제

**구현 위치**: `grimoire-server/src/application/payment/payment.usecase.ts` (`completePaymentAtomically` 호출 직후 신규 auditLog 박제)

**변경**: 'success' 분기 처리 완료 시 신규 audit log 호출 박제. 트랜잭션 외부 후행(실패 시 logger.warn).

```typescript
// completePaymentAtomically 호출 후
try {
  await this.auditLog.log(
    'system_payment',
    'payment_completed',
    payment.id,
    { reason: 'polar_webhook_order.completed', externalTransactionId: payment.externalTransactionId },
    { credits: balanceBefore },
    { credits: balanceAfter, paymentId: payment.id, addedCredits: payment.credits },
  )
} catch (e) {
  this.logger.warn(`AuditLog 박제 실패 (success): ${e instanceof Error ? e.message : String(e)}`)
}
```

**검증 (BDD)**:
- Given: webhook order.completed 수신, author.credits 사전 = 50, payment.credits = 100
- When: processWebhook success 분기 처리
- Then: auditLog action = 'payment_completed', operator = 'system_payment', beforeState = `{ credits: 50 }`, afterState = `{ credits: 150, paymentId, addedCredits: 100 }` 박제

### AC-5. refund-payment.usecase — 잔액 + 환수 metadata before/after 갱신 (PAY-P1-1 회귀 차단)

**구현 위치**: `grimoire-server/src/application/payment/refund-payment.usecase.ts:108-119`

**변경**: 현재 단일 `detail` JSON에 모든 정보 박제 → `beforeState` / `afterState` 분리.

```typescript
await this.auditLogService.log(
  'system_refund',
  action,
  paymentId,
  {
    refundedAmount,
    creditsRequested: credits,
    proportionalCredits,
    isPartial,
    reason,
    source,
  },
  { credits: balanceBefore, paymentStatus: 'completed' },
  { credits: balanceBefore - actualDeducted, paymentStatus: isPartial ? 'partially_refunded' : 'refunded', deficitCredits, creditsActuallyDeducted: actualDeducted },
)
```

**의존성**: `paymentRepo.refundPaymentAtomically` 반환 타입에 `balanceBefore` 추가 필요. 또는 호출자가 사전 조회 (단순 패턴 권장).

**검증 (BDD)**:
- Given: PAY-P1-1 spec (refund-payment.usecase.spec.ts) 18 it 모두 PASS 상태
- When: AC-5 적용
- Then: 18 it 모두 PASS 보존 + beforeState/afterState 검증 4 it 신규 추가 (전액 정상 / 전액 deficit / 부분 정상 / 부분 deficit)

### AC-6. audit-log.service.spec.ts 신설 (현재 spec 부재)

**구현 위치**: `grimoire-server/src/application/admin/audit-log.service.spec.ts` (신규)

**필수 it ≥ 6**:

1. **log() 4-arg 호출 시 beforeState/afterState 키 미박제** (BACKWARD COMPATIBILITY)
   - `expect(mockRepo.create).toHaveBeenCalledWith('a1', 'action', 't1', { foo: 'bar' })` (beforeState/afterState 키 없음)

2. **log() 6-arg 호출 시 detail JSON에 beforeState 키 박제**
   - 입력: `log('a1', 'action', 't1', { foo: 'bar' }, { credits: 100 })`
   - `expect(mockRepo.create).toHaveBeenCalledWith('a1', 'action', 't1', { foo: 'bar', beforeState: { credits: 100 } })` (toEqual)

3. **log() 7-arg 호출 시 detail JSON에 beforeState + afterState 동시 박제**
   - 입력: `log('a1', 'action', 't1', { foo: 'bar' }, { credits: 100 }, { credits: 150 })`
   - `expect(mockRepo.create).toHaveBeenCalledWith('a1', 'action', 't1', { foo: 'bar', beforeState: { credits: 100 }, afterState: { credits: 150 } })` (toEqual)

4. **detail이 undefined여도 beforeState/afterState 박제는 동작**
   - 입력: `log('a1', 'action', 't1', undefined, { credits: 100 }, { credits: 150 })`
   - `expect(mockRepo.create).toHaveBeenCalledWith('a1', 'action', 't1', { beforeState: { credits: 100 }, afterState: { credits: 150 } })` (toMatchObject)

5. **beforeState만 박제 (afterState undefined) 시 afterState 키 미박제**
   - 키 누설 차단 검증 (`expect(mockRepo.create.mock.calls[0][3]).not.toHaveProperty('afterState')`)

6. **findAll() 위임 검증**
   - `mockRepo.findAll`이 동일 옵션으로 호출됨 (toHaveBeenCalledWith)

**금지**: `toBeTruthy()` / `not.toThrow()` 단독 사용 — `toHaveBeenCalledWith` / `toEqual` / `toMatchObject` 강제.

### AC-7. sensor-audit-log-before-after + regression-64 신설

**sensor**: `.claude/scripts/sensor-audit-log-before-after.sh` 신설 (PASS-only 회귀 차단)

**검증 항목 (≥ 6)**:
1. `audit-log.service.ts` 시그니처에 `beforeState?: Record<string, unknown>` 박제 검증
2. `audit-log.service.ts` 시그니처에 `afterState?: Record<string, unknown>` 박제 검증
3. `audit-log.service.ts`에 `beforeState !== undefined` spread 패턴 박제 (키 누설 차단)
4. `admin.usecase.ts:grantCredits`에서 `beforeState` 인자 호출 박제
5. `admin.usecase.ts:deductCredits`에서 `beforeState` 인자 호출 박제
6. `payment.usecase.ts`에서 `payment_completed` action 박제 (AC-4)
7. `refund-payment.usecase.ts`에서 6-arg 또는 7-arg `auditLog.log` 호출 박제 (AC-5)
8. `audit-log.service.spec.ts` 파일 존재 + ≥ 6 it 박제

**eval task**: `eval/tasks/regression-64-audit-log-before-after.json` (≥ 8 criteria)

**검증**: sensor 8/8 PASS + regression-64 PASS + eval-runner 전체 회귀 (33 → ≥ 65 task) PASS-only.

---

## §3. DB 모델 변동

**변경 0건** — `AdminAuditLog.detail` JSON 컬럼은 이미 존재. PAY-P2-4는 detail JSON에 표준 키 (`beforeState` / `afterState`)를 강제하는 application 레이어 변경만.

**향후 (별도 sprint)**: detail JSON 양 폭증 시 PostgreSQL JSONB 인덱싱 + audit 데이터 retention 정책 (90일) 검토 — 본 sprint OUT.

---

## §4. 신설/수정 파일 목록

| # | 파일 | 변경 유형 | 비고 |
|---|---|---|---|
| 1 | `grimoire-server/src/application/admin/audit-log.service.ts` | 수정 | log() 시그니처 6-arg 확장 |
| 2 | `grimoire-server/src/application/admin/audit-log.service.spec.ts` | **신설** | ≥ 6 it (AC-6) |
| 3 | `grimoire-server/src/application/admin/admin.usecase.ts` | 수정 | grantCredits + deductCredits 잔액 사전 조회 + 6-arg 호출 |
| 4 | `grimoire-server/src/application/admin/admin.usecase.spec.ts` | 수정 | grantCredits/deductCredits 검증 강화 (toHaveBeenCalledWith → 6-arg + beforeState/afterState 박제 검증) |
| 5 | `grimoire-server/src/application/payment/payment.usecase.ts` | 수정 | success 분기 'payment_completed' auditLog 신규 박제 (트랜잭션 외 후행) |
| 6 | `grimoire-server/src/application/payment/payment.usecase.spec.ts` | 수정 | success 분기 spec에 auditLog 6-arg 호출 검증 추가 |
| 7 | `grimoire-server/src/application/payment/refund-payment.usecase.ts` | 수정 | auditLog 호출을 6-arg → 7-arg로 갱신 (beforeState/afterState 분리) |
| 8 | `grimoire-server/src/application/payment/refund-payment.usecase.spec.ts` | 수정 | 18 it 회귀 보존 + beforeState/afterState 4 it 신규 |
| 9 | `.claude/scripts/sensor-audit-log-before-after.sh` | **신설** | claude-docs (8 검증) |
| 10 | `eval/tasks/regression-64-audit-log-before-after.json` | **신설** | claude-docs (≥ 8 criteria) |
| 11 | `.claude/shared-contracts.md` §20 | **신설** | AuditLogBeforeAfter 인터페이스 박제 |

server: 8 파일 (수정 6 + 신설 2). claude-docs: 3 파일 (모두 신설/추가). web: 0 파일.

---

## §5. 외부 의존성

**외부 API 신규 의존: 0건**. 내부 port 시그니처 확장만. Polar SDK / Resend / SendGrid / Twilio 영향 0건. 절대 규정 0-1 정합.

---

## §6. 검증 게이트 G1~G9

| G | 도메인 | 명령 | 통과 기준 |
|---|---|---|---|
| G1 | TypeScript | `cd grimoire-server && npx tsc --noEmit` | 0 error |
| G2 | Lint | `cd grimoire-server && npm run lint` | 0 error |
| G3 | jest (server) | `cd grimoire-server && npm test -- --runInBand` | 601 + 6(AC-6) + 4(AC-5) + 1(AC-4) + 2(AC-2/3 강화) = ≥ 614 PASS |
| G4 | Build | `cd grimoire-server && npm run build` | 0 error |
| G5 | Prisma | (변동 0건 — 검증 면제) | N/A |
| G6 | sensor 신설 | `bash .claude/scripts/sensor-audit-log-before-after.sh` | 8/8 PASS |
| G7 | sensor 회귀 | `bash .claude/scripts/sensor-adversarial-pre-commit.sh` + 기타 28 sensor | 모두 WARN 0 |
| G8 | eval | `bash eval/scripts/eval-runner.sh` | 65 task PASS-only (33 + regression-64 + 31 기존) — 사실 정합 검증은 메인이 raw stdout 박제 |
| G9 | 외부 인용 0 | `grep -rE "(CERTI_PROJ\|brightmall\|thermage\|inapi\|admin-certilife\|no1-sass)" grimoire-server/src/application/admin/audit-log.service.ts grimoire-server/src/application/admin/audit-log.service.spec.ts` | 0건 |

**메인 직접 검증** (qa Evaluator 위임 전):
- jest 변경 spec 4건 raw stdout 박제 (audit-log + admin + payment + refund)
- sensor 8/8 PASS raw stdout
- regression-64 raw stdout (≥ 8 criteria PASS)

---

## §7. 테스트 시나리오

### 7-1. 정상 grant + before/after 박제
- author.credits = 100 → grantCredits(50) → auditLog.log 6번째 인자 = `{ credits: 100 }`, 7번째 = `{ credits: 150 }`
- 검증: `mockAuditLog.log.mock.calls[0]` 6/7 인자 toEqual

### 7-2. 정상 deduct + before/after 박제
- author.credits = 100 → deductCredits(30) → auditLog.log beforeState = `{ credits: 100 }`, afterState = `{ credits: 70 }`

### 7-3. webhook success + before/after 박제 (AC-4)
- author.credits = 50, payment.credits = 100 → completePaymentAtomically 후 auditLog action='payment_completed', operator='system_payment', beforeState=`{ credits: 50 }`, afterState=`{ credits: 150, paymentId, addedCredits: 100 }`

### 7-4. refund 정상 환수 + before/after 박제 (AC-5)
- author.credits = 100, refund credits = 50 → refundPaymentAtomically 후 auditLog beforeState=`{ credits: 100, paymentStatus: 'completed' }`, afterState=`{ credits: 50, paymentStatus: 'refunded', deficitCredits: 0 }`

### 7-5. refund deficit + before/after 박제 (AC-5 + PAY-P1-1 회귀)
- author.credits = 30, refund credits = 50 → afterState.credits = 0 (max 차감), deficitCredits = 20

### 7-6. 멱등성 (BACKWARD COMPATIBILITY)
- 기존 4-arg 호출 (admin.usecase 22개 위치) → detail JSON에 beforeState/afterState 키 미박제 (회귀 0건)
- 검증: admin.usecase.spec.ts 기존 toHaveBeenCalledWith 검증 모두 PASS 보존

### 7-7. audit-log.service.spec.ts (AC-6)
- ≥ 6 it (3 시나리오 + 4 backward + spread + findAll 위임)

---

## §8. 거짓말 차단 정책 (★ 사용자 강제)

PAY-P1-1+P1-3+EMAIL-P0-3 회고에서 도출된 거짓말 차단 의무:

1. ★ **commit/push 절대 금지** — 본 sprint Generator(server agent)는 commit 0건. 메인이 책임지고 commit (서명 + 회귀 검증 후)
2. ★ **spec 더미 assertion 금지** — `toBeTruthy()` / `not.toThrow()` 단독 금지. **toHaveBeenCalledWith / toEqual / toMatchObject 강제**.
   - AC-6 audit-log.service.spec.ts 6 it 모두 의미 있는 assertion 박제
3. ★ **raw stdout 박제 의무** — DEV_REPORT에 jest + tsc + build + sensor + regression-64 raw stdout (cherry-pick 금지)
4. ★ **qa Evaluator 독립 재실행** — server agent의 자가 보고는 신뢰 0. qa가 직접 jest/sensor/regression 실행 + Read 검증.
5. ★ **외부 프로젝트 인용 0건** — `CERTI_PROJ` / `brightmall` / `thermage` / `inapi` / `admin-certilife` / `no1-sass` / `aws-sdk` 0건. G9 grep으로 차단.
6. ★ **AC-6 audit-log.service.spec.ts ≥ 6 의미 있는 it 강제** — 더미 assertion으로 채우면 차단.
7. ★ **PAY-P1-1 18 it 회귀 보존 의무** — refund-payment.usecase.spec.ts 변경 시 기존 18 it 모두 PASS 보존 (3중 멱등성 + deficit 분기 회귀 0건).

---

## §9. 멀티에이전트 흐름

```
사용자 명시 ("PAY-P2-4 진행")
  ↓
orchestration-decision (메인 직접) — 멀티에이전트 vs 메인 직접 판단
  ↓
planner Initializer (본 문서 박제) — Sprint 계약 + AC 7건 + 검증 게이트 G1~G9
  ↓
cost-accountant 면제 — 외부 API 0건, §0 마진 영향 0
  ↓
visual-canon-keeper 면제 — UI 변동 0건 (server-only sprint)
  ↓
server Generator — AC-1~AC-6 구현 (8 파일 수정/신설), commit 0건, DEV_REPORT raw stdout 박제
  ↓
메인 Coordinator — claude-docs sensor + regression-64 + shared-contracts §20 박제, 회귀 검증 (jest 614+ / sensor 8/8 / regression 65 PASS)
  ↓
qa Evaluator — 독립 재실행 + 직접 Read (audit-log.service.spec.ts 6 it 의미 검증 + payment/refund spec 회귀) + G9 외부 인용 grep
  ↓
메인 commit/push (3 레포 develop) — server `[hash]` + claude-docs `[hash]` (web 변동 0)
  ↓
사용자 영역 — main per-repo 머지 + dev curl 검증 + prod 배포
```

---

## §10. shared-contracts 박제 후보 (§20 신설)

`.claude/shared-contracts.md` §20 신설 — **AuditLogBeforeAfter Convention**:

```markdown
## 20. AdminAuditLog beforeState/afterState Convention (PAY-P2-4, 2026-05-06)

**생산자**: grimoire-server (audit-log.service)
**소비자**: grimoire-web (admin audit log 조회 UI 향후)

### 시그니처 정본

```typescript
async log(
  adminId: string,
  action: string,
  targetId?: string,
  detail?: Record<string, unknown>,
  beforeState?: Record<string, unknown>,
  afterState?: Record<string, unknown>,
): Promise<void>
```

### detail JSON 표준 스키마 (변경 추적 action만)

```json
{
  "amount": 50,            // 액션 metadata
  "reason": "프로모션",
  "beforeState": { "credits": 100 },
  "afterState": { "credits": 150 }
}
```

### action별 표준

| action | beforeState | afterState |
|---|---|---|
| `credit_grant` | `{ credits }` | `{ credits }` |
| `credit_deduct` | `{ credits }` | `{ credits }` |
| `payment_completed` | `{ credits }` | `{ credits, paymentId, addedCredits }` |
| `refund_normal` / `refund_deficit` / `refund_partial` / `refund_partial_deficit` | `{ credits, paymentStatus }` | `{ credits, paymentStatus, deficitCredits, creditsActuallyDeducted }` |

### 변경 이력
- 2026-05-06 PAY-P2-4: 본 §20 신설 (AdminAuditLog detail JSON 표준화)
```

---

## §11. 사용자 영역 잔존

본 sprint 자율 진행 가능 항목 (메인 책임):
- ✅ server 구현 + spec 7 파일
- ✅ claude-docs sensor + regression-64 + shared-contracts §20
- ✅ develop push (server + claude-docs 2 레포)

사용자 명시 영역:
- ❌ main per-repo 머지 (사용자 명시)
- ❌ dev 검증 curl (사용자 명시 또는 메인 자율 검증 후 보고)
- ❌ prod 배포 (사용자 명시)

---

## §12. 위험 영역 + 별도 sprint 권장

| # | 위험 | 영향 | 분리 권고 |
|---|---|---|---|
| 1 | AdminAuditLog 양 폭증 (모든 결제 + 크레딧 액션이 beforeState/afterState 추가 박제) | DB write 사이즈 ~30% 증가 (JSONB) | **PAY-P3 검토** (90일 retention 정책 + JSONB 인덱싱) |
| 2 | 향후 admin.usecase의 22개 호출처 모두 before/after 박제로 마이그레이션 압력 | 단일 sprint OUT (호출처 28개 분량) | 별도 sprint (`PAY-P2-4-MIGRATION`) — 우선순위 낮음 |
| 3 | webhook payment_completed audit 박제 실패 시 webhook 응답 지연 | logger.warn만 — throw 0 | 본 sprint AC-4 catch 블록으로 차단 (트랜잭션 외 후행) |
| 4 | refund-payment.usecase 회귀 (PAY-P1-1 18 it) | 멱등성 3중 + deficit 분기 깨질 위험 | 본 sprint AC-5 spec 회귀 보존 의무 (qa Evaluator 직접 재실행) |
| 5 | balanceBefore 사전 조회 race condition (admin.usecase에서 findById → grant 사이) | findById와 adjustCredits 사이 다른 트랜잭션 영향 가능 | **본 sprint OUT** — 운영 admin 단일 사용자 가정. 별도 sprint (`PAY-P3 admin race`)로 분리 권장 |

---

## §13. 검증 명령 (메인 수동 실행)

```bash
cd /Users/sokol/Git/ProjectGrimoire

# 1. server jest (변경 spec 4건)
cd grimoire-server
npx jest src/application/admin/audit-log.service.spec.ts --runInBand
npx jest src/application/admin/admin.usecase.spec.ts --runInBand
npx jest src/application/payment/payment.usecase.spec.ts --runInBand
npx jest src/application/payment/refund-payment.usecase.spec.ts --runInBand

# 2. server 전체 jest 회귀 (601 → ≥ 614)
npm test -- --runInBand

# 3. sensor 신설 PASS 8/8
cd /Users/sokol/Git/ProjectGrimoire
bash .claude/scripts/sensor-audit-log-before-after.sh

# 4. eval-runner 전체 회귀 (33 → 65 task PASS-only)
bash eval/scripts/eval-runner.sh

# 5. 외부 인용 0건 강제 grep (G9)
grep -rE "(CERTI_PROJ|brightmall|thermage|inapi|admin-certilife|no1-sass|aws-sdk)" \
  grimoire-server/src/application/admin/audit-log.service.ts \
  grimoire-server/src/application/admin/audit-log.service.spec.ts \
  grimoire-server/src/application/payment/payment.usecase.ts \
  grimoire-server/src/application/payment/refund-payment.usecase.ts
# 기대: 0건

# 6. 다른 sprint 회귀 보존 (PAY-P1-1 18 it + PAY-P2-3 NullSmsAdapter 10 it)
cd grimoire-server
npx jest src/application/payment/refund-payment.usecase.spec.ts --runInBand
npx jest src/adapter/outbound/sms/null-sms.adapter.spec.ts --runInBand
```

---

## §14. 정본 정합

- `research/PAYMENT_SYSTEM_PLAN.md` §3-3 P2-3 (정본 권고)
- `reports/PAY-P2-MASTER-PLAN.md` (전체 트랙)
- `.claude/shared-contracts.md` §20 (본 sprint 신설)
- `grimoire-server/src/application/admin/audit-log.service.ts` (수정 정본)
- `grimoire-server/src/application/payment/refund-payment.usecase.ts` (PAY-P1-1 회귀 보존 의무)

---

마지막 업데이트: 2026-05-06 PAY-P2-4 Sprint 계약 박제 (planner Initializer)
승격 원본: 사용자 명시 "1+2 진행 — PAY-P2-4 AdminAuditLog 정밀화 강화"
