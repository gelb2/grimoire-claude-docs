# Sprint Progress — pay-p1-3-retry-policy

> **Sprint ID**: sprint-pay-p1-3-retry-policy
> **세션**: #10_7 (4) PAY-P1-3 (PAYMENT_SYSTEM_PLAN §3-2 세 번째 — 결제 실패 retry 정책, pending payment 24h 재사용 + 만료 cron)
> **Initializer**: grimoire-planner (책 Ch 16 Anthropic 3-에이전트 패턴 — 묶음 II 7회차)
> **작성일**: 2026-05-04
> **단일 진실**: 본 파일이 Generator (server / claude-docs) + Evaluator (qa) 모두의 작업 정본. 모호하면 본 파일 갱신 후 합의.
> **선행 Sprint (PAY-P0 + PAY-P1-1 100% 완료)**:
> - PAY-P0-1 (sprint-pay-p0-1-webhook-event-id-idempotency-progress.md) — server `8c13103` + claude-docs `06de6c6`
> - PAY-P0-2 (sprint-pay-p0-2-payment-reconciliation-cron-progress.md) — server `8e9e02e` + web `849f771` + claude-docs `790e692`
> - PAY-P0-3 (sprint-pay-p0-3-admin-credit-grant-ui-progress.md) — web `af3f04c` + claude-docs `841e704`
> - PAY-P1-1 (sprint-pay-p1-1-refund-atomicity-progress.md) — server `adfcae8` + web `eb64a8b` + claude-docs `2ed585e`
> **사용자 옵션**: 옵션 B 채택 — 24h 이내 동일 productId pending row 재사용 + 만료 cron 정리

---

## 1. 개요

### 1-1. 목표 (한 줄)

`payment.usecase.initiatePayment` 진입 시 **동일 (authorId, productId, status='pending', createdAt > now-24h) Payment row를 재사용**하여 새 row 폭주를 차단한다. Polar Checkout URL은 항상 신규 발급 (Polar SDK 정책 정합), 만료된 pending row는 매일 새벽 4시 cron으로 'expired' 마킹한다.

### 1-2. 규모

server ~2h (PAYMENT_SYSTEM_PLAN §3-2 PAY-P1-3 견적 — usecase 변경 + 신규 cron + spec). claude-docs ~30min (sensor + regression-57 + shared-contracts §14).

### 1-3. 도메인

100% server + claude-docs (web 변경 0건). 기존 Payment 모델 활용 (DB schema 변경 0건).

### 1-4. 외부 검증

- jest spec PASS (server 543→555+)
- eval task `regression-57-payment-retry-reuse` 신설 (eval 55→56 PASS)
- sensor `sensor-payment-retry-reuse` 신설 (회귀 + Generator 산출물 검증)
- dev 환경 `POST /api/payments/initiate` 동일 productId 2회 호출 → 동일 paymentId 반환 + Polar URL 신규 발급 raw curl 검증

### 1-5. 백엔드 인벤토리 (실측)

| 영역 | 위치 | 상태 |
|---|---|---|
| **분기 지점** | `payment.usecase.ts:31-46` (`initiatePayment` 메서드) | ⚠️ 변경 대상 — 진입부에 재사용 게이트 추가 |
| **Payment 모델** | `prisma/schema.prisma:192-204` (id/authorId/productId/amount/credits/externalTransactionId/status/createdAt/completedAt) | ✅ 기존 필드 충분 — schema 변경 0건 |
| **status 값** | 'pending' / 'completed' / 'failed' / 'refunded' / 'expired' (PAY-P0-2에서 'expired' 추가) | ✅ 기존 enum 활용 |
| **Repository** | `prisma-payment.repository.ts:1-152` (create / findByExternalTransactionId / completePaymentAtomically / findPendingPaymentsOlderThan / expirePayment / refundPaymentAtomically) | ⚠️ `findReusablePendingPayment` + `updateExternalTransactionId` 활용 |
| **PAY-P0-2 cron 패턴** | `payment-reconciliation.job.ts` (@Cron 매일 새벽 3시) | ✅ 정합 패턴 차용 — payment-cleanup.job.ts는 새벽 4시로 분리 |
| **Polar SDK** | `polar.adapter.ts` `initiatePayment` 메서드 (Checkout URL 발급) | ✅ 매 호출마다 신규 URL 발급 (Polar 정책 — 같은 externalTransactionId 재발급 불가, Generator §3-3 검증) |

### 1-6. 현재 갭 (PAYMENT_SYSTEM_PLAN §3-2 PAY-P1-3)

> 사용자 결제 실패 후 즉시 재시도 시 매번 새 Payment row 생성 — DB row 폭주 + Polar Checkout URL 폭주 + 외상 row 누적 (PAY-P0-2 cron이 24h 후 expire하지만 사용자 즉시 재시도 케이스 미해결).

**현재 동작**:
1. 사용자가 5,000원 결제 시작 → Payment#1 (pending) 생성 + Polar URL#1 발급
2. 사용자가 결제 페이지 닫음 (포기)
3. 5분 후 사용자 같은 상품 재시도 → Payment#2 (pending) 생성 + Polar URL#2 발급 (DB row 2개 + URL 2개)
4. 24h 동안 무한 반복 → row 수 폭증

**변경 후 동작**:
1. 사용자가 5,000원 결제 시작 → Payment#1 (pending) 생성 + Polar URL#1 발급
2. 사용자가 결제 페이지 닫음
3. 5분 후 사용자 같은 상품 재시도 → **Payment#1 재사용** + Polar URL#2 신규 발급 (URL만 갱신, paymentId 동일)
4. 24h 후 cron이 Payment#1 'expired' 마킹

### 1-7. CERTI_PROJ 차용 결정 (2026-05-04 PAYMENT_SYSTEM_PLAN §3-2 갱신)

- **부적합**: CERTI_PROJ retry는 매월 5일 배치 (구독제 모델). Grimoire는 일회성 결제 + 사용자 즉시 재시도 UX → 다른 구조.
- **차용**: pending payment 만료 cron 패턴은 PAY-P0-2 reconciliation cron과 동일 패턴 정합. CERTI `thermage-batch-api/src/modules/batch/schedules/batch.schedule.ts:17-37` 참조 0건 (외부 인용 금지 정책 — 자체 PAY-P0-2 패턴만 차용).
- **미차용**: CERTI는 webhook 서명 검증 미흡 → Grimoire는 Polar `validateEvent` 캡슐화로 우월. 본 P1-3에서 추가 보강 불필요.

---

## 2. AC (Acceptance Criteria) — 7건, BDD 패턴, Ambiguity ≤ 0.1

각 AC는 **실측 검증 가능한 raw stdout / grep 결과 / spec 결과 / sensor 결과**로 증명. Generator는 본 AC 미충족 시 작업 미완료 박제 (DEV_REPORT.md raw stdout 박제).

### AC-1: pending payment 24h 이내 재사용 (initiatePayment 진입 게이트)

**Given** 사용자 A가 productId=`credits-50` 으로 5분 전 Payment#1 (status='pending', createdAt = now - 5min) 보유
**When** 사용자 A가 동일 productId로 `POST /api/payments/initiate` 재호출
**Then**
- 응답 `paymentId` === Payment#1.id (재사용 확인)
- Payment 테이블 row 수 변동 0 (`SELECT COUNT(*) FROM payments WHERE author_id=A`)
- Payment#1 `externalTransactionId` 신규 갱신 (Polar URL 재발급, Generator §3-3)
- 응답 `paymentUrl` 신규 발급된 URL (Polar SDK 호출 1회)

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
grep -nE "findReusablePendingPayment|reusable_pending" src/application/payment/payment.usecase.ts
grep -nE "findReusablePendingPayment" src/domain/port/outbound/payment-repository.port.ts
grep -nE "findReusablePendingPayment" src/adapter/outbound/persistence/prisma-payment.repository.ts
npx jest -t "재사용|reuse" src/application/payment/payment.usecase.spec.ts 2>&1 | tail -20
```

### AC-2: PaymentRepositoryPort.findReusablePendingPayment 시그니처 + spec

**Given** PaymentRepositoryPort 인터페이스 + PrismaPaymentRepository 구현
**When** `findReusablePendingPayment(authorId, productId, expireSince)` 호출
**Then**
- 반환: 24h 이내 pending row 1건 또는 null
- WHERE 조건: `authorId AND productId AND status='pending' AND createdAt > expireSince`
- ORDER BY: `createdAt DESC` (가장 최근 row 우선)
- LIMIT: 1
- spec ≥4 it 블록 + toHaveBeenCalledWith ≥4건 (더미 assertion 0건)

**검증 명령**:
```bash
grep -nE "findReusablePendingPayment\\(" src/domain/port/outbound/payment-repository.port.ts
grep -nE "findReusablePendingPayment" src/adapter/outbound/persistence/prisma-payment.repository.ts
grep -nE "createdAt: { gt:|gt:.*expireSince" src/adapter/outbound/persistence/prisma-payment.repository.ts
grep -nE "describe\\('PaymentUseCase|describe.*PrismaPaymentRepository" src/application/payment/payment.usecase.spec.ts src/adapter/outbound/persistence/prisma-payment.repository.spec.ts 2>/dev/null
grep -cE "toHaveBeenCalledWith|toHaveBeenCalledTimes" src/application/payment/payment.usecase.spec.ts
```

**기대 raw 출력**:
- port + impl 둘 다 박제
- WHERE 절에 `createdAt: { gt: expireSince }` 또는 동등
- toHaveBeenCalledWith 호출 ≥4건 (정상 재사용 / 24h 초과 / 다른 productId / 다른 authorId)

### AC-3: Polar Checkout URL 재발급 정책

**Given** Payment#1 재사용 결정 + Polar SDK
**When** initiatePayment 내부 paymentGateway.initiatePayment 호출
**Then**
- Polar SDK 호출 정확히 1회 (재사용/신규 분기 모두)
- 새 tradeNo 발급 → `paymentRepo.updateExternalTransactionId(payment#1.id, newTradeNo)` 호출 1회
- 응답 paymentUrl은 신규 URL

**[MUST]** Polar SDK 동작 검증 — Generator는 다음 grep으로 Polar Adapter 호출 정합 검증:
```bash
grep -nE "paymentGateway.initiatePayment" src/application/payment/payment.usecase.ts
grep -nE "updateExternalTransactionId" src/application/payment/payment.usecase.ts
```

기대: `initiatePayment` 호출 1건 + `updateExternalTransactionId` 호출 1건이 재사용/신규 분기 양쪽에서 일관 호출.

**기각 대안**:
- 같은 externalTransactionId 재사용 — Polar SDK 정책 위반 가능 (체크아웃 URL은 expire 후 invalidate). Generator §3-3에서 확정.
- Polar SDK 호출 skip + 캐시된 URL 반환 — 사용자 UX 저하 (URL expire 후 결제 실패) → 기각.

### AC-4: 만료 cron — payment-cleanup.job (매일 새벽 4시)

**Given** Payment#1 (status='pending', createdAt = now - 25h) 존재
**When** `@Cron('0 0 4 * * *')` payment-cleanup.job 발동
**Then**
- Payment#1.status='expired' 마킹 (delete 아닌 soft expire)
- AdminAuditLog 박제: operator='system_cleanup', action='payment_expire', detail JSON에 paymentId/createdAt/elapsedHours
- cron 종료 후 `SELECT COUNT(*) FROM payments WHERE status='expired'` ≥1
- 24h 이내 pending row는 변동 0건

**[MUST]** PAY-P0-2 reconciliation cron과 분리 — 별도 job 클래스 (`payment-cleanup.job.ts`) 신설. 시간대 분리 (PAY-P0-2 새벽 3시 / PAY-P1-3 새벽 4시).

**검증 명령**:
```bash
grep -nE "@Cron.*0 0 4|0 0 4 \\* \\* \\*" src/application/payment/payment-cleanup.job.ts
grep -nE "system_cleanup|payment_expire" src/application/payment/payment-cleanup.job.ts
test -f src/application/payment/payment-cleanup.job.spec.ts
npx jest src/application/payment/payment-cleanup.job.spec.ts 2>&1 | tail -15
```

**기대 raw 출력**:
- Cron 표현식 `0 0 4 * * *` 박제
- AuditLog operator='system_cleanup' + action='payment_expire' 박제
- spec ≥3 it 블록 (정상 만료 / 24h 이내 skip / 동시 실행 race)

### AC-5: 동시 요청 race condition 처리

**Given** 사용자 A가 동일 productId로 동시에 2개 탭에서 `POST /api/payments/initiate` 호출
**When** 두 요청이 거의 동시 도착
**Then**
- 첫 요청 → Payment#1 신규 생성 + Polar URL#1 발급
- 두 번째 요청 → Payment#1 재사용 (findReusablePendingPayment 적중) + Polar URL#2 발급 (URL만 갱신)
- DB row 수 1건 (race 시 2건 생성 시 중복 — 차단 필요)

**구현 옵션** (Generator §3-4 결정):
- 옵션 A: SELECT FOR UPDATE — `findReusablePendingPayment` 트랜잭션 내부 락 (권고)
- 옵션 B: `@@unique([authorId, productId, status])` partial index — Postgres 14+ partial index `WHERE status='pending'` (DB schema 변경 필요)
- 옵션 C: 응용 레벨 lock (Redis 등) — 인프라 의존성 추가

**Initializer 권고**: 옵션 A (트랜잭션 SELECT FOR UPDATE) — DB schema 변경 0건, 인프라 의존성 0. 단 race 발생 시 두 번째 요청은 약간 지연 (ms 단위, 사용자 UX 영향 미미).

**검증 명령**:
```bash
grep -nE "FOR UPDATE|\\\$transaction|prisma.\\\$transaction" src/application/payment/payment.usecase.ts
grep -nE "race|동시|concurrent" src/application/payment/payment.usecase.spec.ts
```

### AC-6: regression-57 + sensor-payment-retry-reuse + eval 55→56 PASS

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire
ls eval/tasks/regression-*.json | wc -l
cat eval/tasks/regression-57-payment-retry-reuse.json | python3 -c "import json,sys;d=json.load(sys.stdin);print(len(d['eval_criteria']))"
ls -la .claude/scripts/sensor-payment-retry-reuse.sh
bash .claude/scripts/sensor-payment-retry-reuse.sh
echo "exit: $?"
bash eval/scripts/eval-runner.sh 2>&1 | tail -10
```

**기대 raw 출력**:
- regression 파일 수 56 (현재 55 — PAY-P1-1 이후)
- regression-57 eval_criteria ≥6건
- sensor 파일 chmod +x + exit 0
- sensor 검증 항목 ≥7건:
  1. `findReusablePendingPayment` port + impl 박제
  2. `payment.usecase.initiatePayment` 진입 재사용 게이트 호출 박제
  3. `payment-cleanup.job.ts` 파일 존재 + @Cron 표현식
  4. spec ≥4 it 블록 + toHaveBeenCalledWith ≥4건
  5. AuditLog operator='system_cleanup' 박제
  6. PAY-P0-2 reconciliation cron과 분리 (별도 클래스 + 별도 시간대)
  7. Polar Checkout URL 재발급 (updateExternalTransactionId 호출 박제)
- eval-runner stdout 마지막 행: `regression: 56/56 PASS (100%)`

### AC-7: shared-contracts §14 PaymentRetryReuse + jest server 543→555+ PASS

**검증 명령**:
```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire
grep -nE "^## 14\\. PaymentRetryReuse" .claude/shared-contracts.md
grep -nE "findReusablePendingPayment|payment-cleanup" .claude/shared-contracts.md
grep -nE "2026-05-04 #10_7 PAY-P1-3" .claude/shared-contracts.md
bash .claude/scripts/sensor-shared-contracts.sh
echo "exit: $?"
cd grimoire-server
npm test 2>&1 | grep -E "Tests:" | tail -1
```

**기대 raw 출력**:
- §14 헤더 박제
- 시그니처 박제 (`findReusablePendingPayment`, `expireSince`, `payment-cleanup.job`)
- 변경 이력 `2026-05-04 #10_7 PAY-P1-3: 신설`
- sensor-shared-contracts.sh exit 0 (drift 0)
- jest stdout: `Tests: 555+ passed` (현재 543 → +12 이상 = 555+)

---

## 3. DB 모델 변동

**변경 0건** — 기존 Payment 모델 + 'expired' status 활용. PAY-P0-2에서 'expired' status 이미 추가됨 (`prisma-payment.repository.ts:65-70` `expirePayment` 활용).

**기각 대안** — `@@unique([authorId, productId, status])` partial index 도입:
- 장점: DB 차원 race 차단
- 단점: schema 변경 1건 + 마이그레이션 + 'pending' status 외 row에는 무의미
- **결론**: 트랜잭션 SELECT FOR UPDATE로 충분 (옵션 A) — schema 변경 0건 우선.

---

## 4. 신설/수정 파일 목록 (예상)

### 4-1. server (15건)

- [ ] `src/domain/port/outbound/payment-repository.port.ts` — `findReusablePendingPayment(authorId, productId, expireSince): Promise<PaymentRecord | null>` 시그니처 추가
- [ ] `src/adapter/outbound/persistence/prisma-payment.repository.ts` — `findReusablePendingPayment` 구현 (WHERE + ORDER BY + LIMIT 1)
- [ ] `src/application/payment/payment.usecase.ts` — `initiatePayment` 진입부 재사용 게이트 추가 (트랜잭션 옵션 A)
- [ ] `src/application/payment/payment.usecase.spec.ts` — 재사용 시나리오 회귀 spec ≥4 it 블록 추가
- [ ] `src/application/payment/payment-cleanup.job.ts` — 신규 cron job 클래스 (@Cron('0 0 4 * * *') + AuditLog operator='system_cleanup' 박제)
- [ ] `src/application/payment/payment-cleanup.job.spec.ts` — 신설 spec ≥3 it 블록 (정상 만료 / 24h 이내 skip / cron 발동)
- [ ] `src/app.module.ts` — PaymentCleanupJob DI 추가 (PaymentReconciliationJob 패턴 정합)
- [ ] `docs/api-contract.md` — `POST /api/payments/initiate` 응답 schema 변경 0건 (paymentId/paymentUrl/tradeNo 동일) + 재사용 정책 주석 추가
- [ ] `docs/data-model.md` — Payment 'expired' status 정책 박제 강화 (PAY-P0-2 + PAY-P1-3 흐름)
- [ ] `SCHEMA.md` — Payment status enum 정책 갱신 (cleanup cron 정책 박제)
- [ ] `INFRASTRUCTURE.md` §9 — payment-cleanup.job cron 표현식 + 시간대 박제 (PAY-P0-2 reconciliation cron과 분리 명시)
- [ ] `MIGRATION.md` — 변경 0건 (DB schema 변경 0건)
- [ ] `TECH_STATUS.md` — Payment 카테고리에 PAY-P1-3 한 줄 박제
- [ ] `CHANGELOG.md` — `[Unreleased]` Added — 결제 실패 retry 정책 + payment-cleanup cron 박제
- [ ] DEV_REPORT.md Server 섹션 §5 — sensor-server / sensor-payment-retry-reuse / jest raw stdout 전문 박제

### 4-2. claude-docs (4건)

- [ ] `.claude/scripts/sensor-payment-retry-reuse.sh` — 신설 (chmod +x, 검증 항목 ≥7건 — AC-6 정본)
- [ ] `eval/tasks/regression-57-payment-retry-reuse.json` — 신설 (eval_criteria ≥6건, AC-1~5 grep 명령 박제)
- [ ] `.claude/shared-contracts.md` §14 — PaymentRetryReuse 인터페이스 박제 + 변경 이력
- [ ] `research/HARNESS_ENGINEERING.md` §14.4 — Sensors 29→30 + sensor-payment-retry-reuse 행 + eval task 55→56 갱신 (drift 0 박제)

### 4-3. web (변경 0건)

- 본 Sprint는 100% server + claude-docs. 클라이언트는 동일 응답 schema (paymentId/paymentUrl/tradeNo) 수신 → web 변경 0건. Generator는 git diff로 web 레포 touch 0건 박제 의무 (§6-3 G9).

---

## 5. 외부 의존성

- **Polar SDK**: `paymentGateway.initiatePayment` 매 호출마다 신규 Checkout URL 발급 (재사용 분기에서도 동일 호출). Generator §3-3에서 SDK 동작 검증 — `polar.adapter.ts` 인스펙트 후 본 progress.md §3-3 갱신 가능.
- **NestJS Schedule**: `@nestjs/schedule` `@Cron` 데코레이터 활용 (PAY-P0-2 동일 의존성). 별도 패키지 추가 0건.
- **환경변수**: 변경 0건 (cron 활성화는 기존 `ENABLE_CRON_JOBS` 환경변수 재활용).
- **Polar 정책**: Checkout URL TTL 정책 — Polar 공식 문서 검증 (researcher 위임 가능). 기본값 24h 가정 → cron 시간 정합.

---

## 6. 검증 게이트

### 6-1. server 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G1 | TypeScript | `cd grimoire-server && npx tsc --noEmit` | 0 errors |
| G2 | Lint | `npm run lint` | 0 errors |
| G3 | jest (전체) | `npm test 2>&1 \| tail -30` | 모든 spec PASS, 회귀 0건, 신규 spec ≥4 + ≥3 it 블록 모두 PASS, Tests: 555+ |
| G4 | Build | `npm run build` | 0 errors |
| G5 | Prisma | `npx prisma generate` | 성공 (schema 변경 0건이므로 migrate diff 불필요) |
| G6 | Cron | `grep -rE "@Cron" src/application/payment/` | reconciliation + cleanup 2건 박제 |

### 6-2. claude-docs 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G7 | sensor 10종 | `for s in sensor-shared-contracts sensor-server sensor-docs-sync sensor-credit-atomicity sensor-payment-idempotency sensor-payment-reconciliation sensor-admin-credit-ui sensor-refund-atomicity sensor-payment-retry-reuse sensor-adversarial-pre-commit; do bash .claude/scripts/$s.sh; done` | 모두 exit 0 |
| G8 | eval | `bash eval/scripts/eval-runner.sh` | regression 56/56 PASS, drift 0 |

### 6-3. web 검증 게이트

| # | 게이트 | 명령 | 기대 |
|---|---|---|---|
| G9 | web 레포 git diff | `cd grimoire-web && git diff --stat develop` | 0 files changed |

---

## 7. 테스트 시나리오

### 7-1. 정상 재사용 시나리오 (jest)

```typescript
it('동일 (authorId, productId)로 24h 이내 pending 재호출 시 paymentId 재사용', async () => {
  mockPaymentRepo.findReusablePendingPayment.mockResolvedValueOnce({
    id: 'p1', authorId: 'a1', productId: 'credits-50', status: 'pending', createdAt: new Date(Date.now() - 5 * 60 * 1000),
  })
  mockPaymentGateway.initiatePayment.mockResolvedValueOnce({ tradeNo: 'new-trade-2', paymentUrl: 'new-url-2' })
  const result = await usecase.initiatePayment('a1', 'credits-50', 'https://return')
  expect(mockPaymentRepo.findReusablePendingPayment).toHaveBeenCalledWith('a1', 'credits-50', expect.any(Date))
  expect(mockPaymentRepo.create).not.toHaveBeenCalled()
  expect(mockPaymentRepo.updateExternalTransactionId).toHaveBeenCalledWith('p1', 'new-trade-2')
  expect(result.paymentId).toBe('p1')
  expect(result.paymentUrl).toBe('new-url-2')
})
```

### 7-2. 24h 초과 시 신규 생성 시나리오

```typescript
it('24h 초과 pending 존재 시 findReusablePendingPayment null 반환 → 신규 생성', async () => {
  mockPaymentRepo.findReusablePendingPayment.mockResolvedValueOnce(null)
  mockPaymentRepo.create.mockResolvedValueOnce({ id: 'p2', ... })
  const result = await usecase.initiatePayment('a1', 'credits-50', 'https://return')
  expect(mockPaymentRepo.create).toHaveBeenCalledTimes(1)
  expect(result.paymentId).toBe('p2')
})
```

### 7-3. 동시 요청 race condition (옵션 A 트랜잭션 검증)

```typescript
it('동시 호출 시 SELECT FOR UPDATE로 두 번째 요청은 Payment#1 재사용', async () => {
  // Promise.all([req1, req2]) 시뮬 + jest.useFakeTimers
  // 첫 요청 → create 1회, 두 번째 → findReusablePendingPayment 적중
  // 검증: create 호출 정확히 1회, paymentId 동일
})
```

### 7-4. payment-cleanup.job 시나리오

```typescript
it('새벽 4시 cron 발동 시 24h 초과 pending row 모두 expired 마킹', async () => {
  mockPaymentRepo.findPendingPaymentsOlderThan.mockResolvedValueOnce([
    { id: 'p1', createdAt: new Date(Date.now() - 25 * 60 * 60 * 1000) },
    { id: 'p2', createdAt: new Date(Date.now() - 30 * 60 * 60 * 1000) },
  ])
  await job.cleanupExpiredPendingPayments()
  expect(mockPaymentRepo.expirePayment).toHaveBeenCalledTimes(2)
  expect(mockAuditLogService.log).toHaveBeenCalledWith('system_cleanup', 'payment_expire', expect.any(String), expect.objectContaining({ elapsedHours: expect.any(Number) }))
})
```

### 7-5. Polar URL 재발급 검증 (수동 — localhost)

1. localhost server 부팅 + 시드 사용자 a1 / 상품 credits-50
2. `curl POST /api/payments/initiate -d '{"productId":"credits-50"}'` → Payment#1 + URL#1
3. 5분 대기 (또는 즉시 재호출)
4. `curl POST /api/payments/initiate -d '{"productId":"credits-50"}'` → 응답 paymentId === Payment#1.id + URL#2 (≠ URL#1)
5. psql: `SELECT id, external_transaction_id, status FROM payments WHERE author_id='a1' AND product_id='credits-50'` → 1 row, externalTransactionId 갱신
6. 24h 후 (또는 cron 수동 발동): `SELECT status FROM payments WHERE id='p1'` → 'expired'

raw 박제 위치: DEV_REPORT.md Server 섹션 §3 + §5 (psql + curl raw).

---

## 8. 거짓말 차단 정책 (사용자 ★)

### 8-1. PAY-P1-1 회고 (eval 55/55 자가 보고 → 실제 52/55 docs drift 검출)

PAY-P1-1에서 server agent가 "eval 55/55"라고 자가 보고했으나 qa Evaluator 직접 Read로 docs drift 3건 검출. 본 sprint progress에 다음 명시:

### 8-2. server agent prompt에 ★ commit/push 절대 금지

- Generator(server agent)는 코드 변경 + DEV_REPORT.md raw stdout 박제까지만.
- commit/push는 메인이 사용자 승인 후 일괄 진행.
- Generator 자율 commit/push 시 즉시 FAIL 박제 (qa Evaluator git log 검증).

### 8-3. spec 더미 assertion 금지

다음 패턴 차단:
- `expect(true).toBe(true)`
- `expect(1+1).toBe(2)`
- `expect(result).toBeTruthy()` (의미 없는 truthy 검증)
- `expect(() => fn()).not.toThrow()` (단순 throw 회피)

**[MUST]** 다음 패턴 강제:
- `toHaveBeenCalledWith({ ... 정확한 인자 ... })`
- `toHaveBeenCalledTimes(N)` (구체 N)
- `expect(result).toEqual({ ... 정확한 객체 ... })`
- `expect(result).toMatchObject({ ... 정확한 부분 객체 ... })`

AC-2 / AC-6 grep 검증으로 자동 차단:
```bash
grep -cE "toHaveBeenCalledWith|toHaveBeenCalledTimes" src/application/payment/payment.usecase.spec.ts
grep -cE "toHaveBeenCalledWith|toHaveBeenCalledTimes" src/application/payment/payment-cleanup.job.spec.ts
```
기대: 합계 ≥7건 (재사용 4 + cleanup 3).

### 8-4. raw stdout DEV_REPORT.md §5 박제 의무

Generator는 다음 raw stdout 전문 박제 의무:
- `bash .claude/scripts/sensor-server.sh 2>&1` 전문
- `bash .claude/scripts/sensor-payment-retry-reuse.sh 2>&1` 전문
- `npm test 2>&1 | tail -50` 전문 (Tests: ... 라인 포함)
- `npx tsc --noEmit 2>&1` 전문
- 통합 §7-5 수동 검증 결과 (curl raw response + psql raw row)

### 8-5. qa Evaluator 독립 재실행 + 직접 Read

qa는 Generator 박제와 별개로:
1. `bash .claude/scripts/sensor-payment-retry-reuse.sh` 직접 재실행 → exit 0 검증
2. `npx jest payment-cleanup.job.spec.ts payment.usecase.spec.ts` 직접 재실행 → 모두 PASS 검증
3. spec 파일 직접 Read → 의미 있는 assertion 검증 (toHaveBeenCalledWith 인자 정합 + toMatchObject 검증)
4. `eval/scripts/eval-runner.sh` 직접 재실행 → 56/56 PASS 검증
5. `git log` 직접 확인 → Generator 자율 commit 흔적 0건

### 8-6. 외부 프로젝트 인용 0건

`grep -rE "CERTI_PROJ|brightmall|thermage|inapi" reports/sprint-pay-p1-3-* grimoire-server/src/ .claude/scripts/sensor-payment-retry-reuse.sh eval/tasks/regression-57-*.json 2>/dev/null | wc -l` → **0건** 강제. PAYMENT_SYSTEM_PLAN.md §3-2 차용 결정 박제 외에 코드/sensor/eval에 외부 프로젝트명 0건.

---

## 9. 멀티에이전트 흐름

```
1. orchestration-decision (사전 — 메인 직접 판단)
   - 본 Sprint는 §0 원가 영향 0건 + 시각 정본 영향 0건 + AI 호출 0건
   - planner Initializer → server Generator → qa Evaluator (병렬: shared-contracts + regression + sensor)

2. planner (Initializer — 본 sprint progress + PLANNER_REPORT 갱신)
   ↓
3. cost-accountant (사전 — ✅ 면제. AI 호출 0건 + 인프라 비용 영향 0건. 본 Sprint는 100% server 트랜잭션 + cron 1건 추가만)
   ↓
4. visual-canon-keeper (사전 — ✅ 면제. 시각 정본 변경 0건. 본 Sprint는 100% 백엔드 + claude-docs. web UI 변경 0건)
   ↓
5. 메인 직접 (병렬 진행)
   - shared-contracts §14 박제
   - regression-57 task 신설
   - sensor-payment-retry-reuse 신설
   ↓
6. grimoire-server (Generator)
   - 본 progress.md §4-1 IN — server 15건 + §6-1 검증 게이트 G1~G6 PASS
   - DEV_REPORT.md Server 섹션 §5 raw stdout 전문 박제
   - ★ commit/push 절대 금지 — 메인 책임 (PAY-P1-1 회고 정합)
   ↓
7. grimoire-qa (Evaluator)
   - AC 7건 raw 채점 (PASS/FAIL 박제)
   - QA_REPORT.md `### sprint-pay-p1-3-retry-policy 통과율` 박제 (목표 7/7 = 100%)
   - dev 환경 재시도 시뮬 실제 검증 (curl raw response + psql payments row 박제)
   - Generator 자율 commit/push 흔적 검증 (git log 확인) — 발견 시 즉시 FAIL 박제
   - eval-runner 56/56 PASS 직접 재실행 검증
   ↓
8. 사용자 (배포 게이트 최종 판정 + commit/push 최종 책임)
   - qa PASS 시 commit + push 진행
   - develop → main per-repo 머지 (server + claude-docs 2 레포 — web 변경 0건이므로 web 머지 의무 0)
   - prod 배포 (`npx prisma generate` — schema 변경 0건이므로 migrate deploy 불필요, Container Apps server만 재배포)
```

---

## 10. shared-contracts §14 PaymentRetryReuse 박제 후보

**[MUST]** claude-docs Generator (또는 메인 직접)는 아래 텍스트 블록을 `.claude/shared-contracts.md` `## 13. RefundPaymentAtomically` 섹션 직후에 박제.

```markdown
## 14. PaymentRetryReuse (server 도메인 — 결제 실패 retry 정책)

**위치**:
- UseCase 변경: `grimoire-server/src/application/payment/payment.usecase.ts` (`initiatePayment` 진입 게이트)
- Cron Job: `grimoire-server/src/application/payment/payment-cleanup.job.ts` (신설 — @Cron 새벽 4시)
- Port (extend): `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (`findReusablePendingPayment` 시그니처 추가)
- Adapter: `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (구현)
- DB 모델: `grimoire-server/prisma/schema.prisma` (변경 0건 — 'expired' status 활용)

**적용**: 사용자가 결제 실패 후 재시도 시 동일 (authorId, productId, status='pending', createdAt > now-24h) Payment row 재사용 + Polar Checkout URL 재발급. 만료된 pending row는 새벽 4시 cron으로 'expired' 마킹.

### 시그니처

```typescript
// PaymentRepositoryPort 확장
findReusablePendingPayment(
  authorId: string,
  productId: string,
  expireSince: Date,    // now - 24h
): Promise<PaymentRecord | null>

// PaymentUseCase.initiatePayment 진입 흐름
async initiatePayment(authorId, productId, returnUrl) {
  const expireSince = new Date(Date.now() - 24 * 60 * 60 * 1000)
  let payment = await this.paymentRepo.findReusablePendingPayment(authorId, productId, expireSince)
  if (!payment) {
    payment = await this.paymentRepo.create({ authorId, productId, ... })
  }
  const result = await this.paymentGateway.initiatePayment({ ... })
  await this.paymentRepo.updateExternalTransactionId(payment.id, result.tradeNo)
  return { paymentId: payment.id, paymentUrl: result.paymentUrl, tradeNo: result.tradeNo }
}

// PaymentCleanupJob (신설)
@Cron('0 0 4 * * *')
async cleanupExpiredPendingPayments(): Promise<void>
```

### 정책

- **재사용 조건**: `authorId AND productId AND status='pending' AND createdAt > now - 24h`
- **재사용 시 Polar URL**: 매 호출마다 신규 발급 (Polar SDK 정책 — 같은 externalTransactionId 재발급 불가)
- **race condition 차단**: 트랜잭션 SELECT FOR UPDATE (옵션 A — DB schema 변경 0건)
- **만료 정책**: 24h 초과 pending row → cron이 'expired' 마킹 (delete 아닌 soft expire)
- **AuditLog**: cron 발동 시 operator='system_cleanup' + action='payment_expire' 박제 (PAY-P0-2 'system_reconciliation' 패턴 정합)
- **PAY-P0-2 cron과 분리**: 별도 클래스(`payment-cleanup.job.ts`) + 별도 시간대(새벽 4시 vs PAY-P0-2 새벽 3시)

### 처리 흐름

1. `payment.usecase.initiatePayment(authorId, productId, returnUrl)` 진입
2. `expireSince = new Date(Date.now() - 24*60*60*1000)`
3. `paymentRepo.findReusablePendingPayment(authorId, productId, expireSince)`
4. 결과 null → `paymentRepo.create({ ... })` 신규 생성
5. 결과 not-null → 재사용 (paymentId 동일)
6. `paymentGateway.initiatePayment({ ... })` Polar SDK 호출 (신규 URL 발급)
7. `paymentRepo.updateExternalTransactionId(payment.id, result.tradeNo)` 갱신
8. return `{ paymentId, paymentUrl, tradeNo }`

### 변경 시 동시 갱신 대상

- `grimoire-server/src/application/payment/payment.usecase.ts` (initiatePayment 진입 게이트)
- `grimoire-server/src/application/payment/payment.usecase.spec.ts` (재사용 시나리오 spec)
- `grimoire-server/src/application/payment/payment-cleanup.job.ts` (신설)
- `grimoire-server/src/application/payment/payment-cleanup.job.spec.ts` (신설)
- `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (findReusablePendingPayment 시그니처)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts` (구현)
- `grimoire-server/src/app.module.ts` (PaymentCleanupJob DI)
- `grimoire-server/docs/api-contract.md` (재사용 정책 주석)
- `grimoire-server/INFRASTRUCTURE.md` §9 (cron 시간대 박제)
- `eval/tasks/regression-57-payment-retry-reuse.json`
- `.claude/scripts/sensor-payment-retry-reuse.sh`

### 변경 이력

- 2026-05-04 #10_7 PAY-P1-3: 신설 — pending payment 24h 재사용 + 만료 cron (PAYMENT_SYSTEM_PLAN §3-2 PAY-P1-3 정합)
```

추가로 shared-contracts.md 마지막 줄 `마지막 업데이트:` 라인을 `2026-05-04 (§14 PaymentRetryReuse 신설)`로 교체.

---

## 11. 사용자 영역 잔존

### 11-1. main 머지 (사용자 책임)

- qa Evaluator PASS 박제 후 메인 또는 사용자가 직접 commit + push
- develop → main per-repo 머지 2 레포:
  - server: `git checkout main && git merge develop` + `git push origin main`
  - claude-docs: `git checkout main && git merge develop` + `git push origin main`
  - web: 변경 0건 → 머지 의무 0

### 11-2. dev 검증 (qa Evaluator + 사용자 협업)

- dev 환경 deploy 후 qa가 webhook 시뮬 + curl raw response + psql raw row 박제 (DEV_REPORT.md §5 + QA_REPORT.md `### sprint-pay-p1-3-retry-policy 통과율`)
- 사용자가 실제 Polar checkout URL 클릭 → 결제 페이지 닫기 → 재시도 → 같은 paymentId 확인 (수동 UX 검증)

### 11-3. prod 배포 (사용자 최종 결정)

- `npx prisma generate` (schema 변경 0건 → migrate deploy 불필요)
- Container Apps server 재배포 (web 변경 0건)
- prod 환경 cron 활성화 검증 (`ENABLE_CRON_JOBS=true` 확인 + 새벽 4시 발동 로그 확인)
- prod 환경 첫 24h 모니터링 (cleanup cron 발동 후 expired row 수 검증)

### 11-4. PAY-P1-3 후속 — 미해결 영역 (사용자 결정)

- **24h 재사용 정책 vs 30분 재사용 정책**: 사용자 명시 — 옵션 B 채택 (24h). 단 운영 후 사용자 피드백 따라 30분/12h 등으로 조정 가능 (환경변수화 가능 — 미래 P2).
- **cleanup cron 시간 정책**: 매일 새벽 4시 (PAY-P0-2 새벽 3시 직후). 운영 후 사용자 피드백 따라 조정 가능.
- **Polar checkout URL TTL**: Polar 공식 정책 검증 (researcher 위임 가능). 24h 미만 시 사용자 UX 영향 검토.
- **PAY-P1-2 (결제 알림 이메일)**: cost-accountant 외부 API 위임 + EMAIL_INTEGRITY_PLAN.md EMAIL-P1-3 흡수. 본 Sprint 완료 후 진입.
- **PAY-P1-4 (Polar Subscription)**: 작업 A (구독제 요금제)와 통합 진행. 본 Sprint 후 핸드오프 가능.

---

## 12. 참조

- `research/PAYMENT_SYSTEM_PLAN.md` §3-2 PAY-P1-3 (line 303-322 — 결제 실패 retry 정책 + CERTI_PROJ 차용 결정 박제)
- `reports/PAYMENT_NEXT_STEPS.md` §3 옵션 B (24h pending 재사용)
- `reports/sprint-pay-p0-1-webhook-event-id-idempotency-progress.md` (선행 1)
- `reports/sprint-pay-p0-2-payment-reconciliation-cron-progress.md` (선행 2 — 'system_reconciliation' operator + cron 패턴 차용)
- `reports/sprint-pay-p0-3-admin-credit-grant-ui-progress.md` (선행 3)
- `reports/sprint-pay-p1-1-refund-atomicity-progress.md` (선행 4 — 'system_refund' operator 패턴 차용 + 거짓말 차단 정책 정합)
- `grimoire-server/src/application/payment/payment.usecase.ts:31-46` (`initiatePayment` 진입 — 변경 대상)
- `grimoire-server/src/adapter/outbound/persistence/prisma-payment.repository.ts:9-19` (`create`/`updateExternalTransactionId`) + `:49-70` (`findPendingPaymentsOlderThan`/`expirePayment` — PAY-P0-2 패턴 차용)
- `grimoire-server/src/domain/port/outbound/payment-repository.port.ts` (확장 대상)
- `grimoire-server/prisma/schema.prisma:192-204` (Payment 모델 — 변경 0건)
- `.claude/shared-contracts.md` §11 PAY-P0-1 + §12 PAY-P0-2 + §13 PAY-P1-1 + §14 PAY-P1-3 (본 Sprint 신설)
- `grimoire-server/CLAUDE.md` §9 결제/크레딧 원자성 + §3 문서 동기화
- `memory/project_session_20260503_3.md §2` (이번 세션 직전 컨텍스트 — PAY-P1-1 완료)
- 책 Ch 16 Anthropic 3-에이전트 (Initializer → Generator → Evaluator) — 묶음 II 7회차
- Memory `feedback_chrome_verify.md` (qa 단계 실측 정합)
- Memory `feedback_no_shortcut_migration.md` (마이그레이션 시 기능 뭉개기 금지)

---

**마지막 업데이트**: 2026-05-04 (PAY-P1-3 Initializer 신설 — pending 24h 재사용 + payment-cleanup cron + AC 7건 + Ambiguity ≤ 0.1 + commit/push 메인 책임 + spec 더미 assertion 금지 + cost/VCK 면제)
