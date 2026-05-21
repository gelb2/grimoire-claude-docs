# Sprint CC-4 Phase 1 Progress — 폐기 정리 (구 메서드 제거 + 신·구 분열 해소)

> 작성: 2026-05-21 / grimoire-server (Generator) / **Phase 1 종결 박제**
> 계획 정본: `.claude/state/sprint-cc4-postcleanup-plan-draft.md` (옵션 Z — 3 Phase 분할 권고)
> 범위: Phase 1만 (코드 + spec + 문서 한정 — 마이그레이션 0건). Phase 2(컬럼 rename) / Phase 3(`Author.credits` DROP + `CreditLog` 폐기) = 별도 sprint.

---

## 0. 종합 판정

- **PASS** — Phase 1 완료 게이트 5개 전부 통과.
- jest 1059 → 1063 (+4 it) / build PASS / docker build PASS / 커버리지 61.74%/63.33%(lines) ≥60% 게이트 충족.
- 구 메서드 제거 증명 + 신·구 분열 해소 증명 = 모두 PASS.
- 코드 변경 + 문서 동기화 = 같은 커밋 단위 (예정).

## 1. S0 — 현행 재실측 결과 (구 호출처 file:line)

### S0a — admin·discovery 구 `creditRepo` 직접 호출 (CC-4 P1 대상)

```
src/application/admin/admin.usecase.ts:35       this.creditRepo.sumNegativeAmounts()
src/application/admin/admin.usecase.ts:177      this.creditRepo.findLogsByAuthorId(authorId)
src/application/discovery/discovery.usecase.ts:66  this.creditRepo.getGiftRanking(limit)
```

전부 L2c/L2e/L2a 에서 신 시스템 위임으로 전환 완료.

### S0b — `getGiftRanking` 호출 사슬

- `credit.usecase:174~178` — `ledger.getGiftRanking(limit)` 위임 + ledger null 시 폴백 (CC-3 H3c)
- `discovery.usecase:66` — `creditRepo.getGiftRanking` 직접 호출 (L2a 대상 = 신·구 분열 핵심)
- `credit.controller:25` — `creditUseCase.getGiftRanking` 호출 (이미 신 위임 경유)

### S0c — `Payment.credits` / `RefundLog.credits`/`deficitCredits` 사용처 (Phase 2 입력값)

- `Payment.credits` 사용처 다수 (`payment.usecase`/`payment-reconciliation.job`/`prisma-payment.repository`/spec) — 의미는 이미 pt 단위로 재해석(CC-2a). **컬럼 물리 rename = Phase 2 영역, 본 sprint 미작업.**
- `RefundLog.deficitCredits` 사용처 (`prisma-payment.repository`/spec/email/sms adapter) — 의미는 "이 환불 1건이 유발한 외상 pt 기여분"(CC-2b 재해석). **Phase 2 영역, 본 sprint 미작업.**

### S0d — `Author.credits` 읽기/쓰기 전수 (Phase 3 입력값)

- `auth.controller:48` — `author.credits` 응답 직렬화 (Phase 3 DROP 시 응답 형태 변경 필요)
- `refund-payment.usecase:124-125` — `author.credits ?? 0` (Phase 3 직전 정리 대상)
- `credit-migration.ts:54,58` — 디노미 환산 (Phase 3 직전 정리)
- `auth-security.spec` / `prisma-payment.repository.spec` / `prisma-credit.repository.ts` 등 spec 영역 — Phase 3 정리.
- **본 Phase 1 에서 새 코드 본문 추가 0건** — Phase 3 DROP 안전성 입력값으로 박제.

### S0e — `CreditLog` 사용처 전수 (Phase 3 입력값)

- `schema.prisma:55,154` — Author 관계 + 모델 정의 (Phase 3 DROP TABLE 대상)
- `prisma-credit.repository.ts` — `findLogsByAuthorId`/`getGiftRanking` 본문 잔존 (Phase 3 폐기 예정 — 폴백 경로용)
- `prisma-payment.repository.ts` — 직접 사용 0건 (구 메서드 제거 시 `tx.creditLog.create` 호출 삭제됨)
- `prisma-fk-cascade.spec.ts` — Restrict 8건 박제 정합 검증 (Phase 3 후 정리)

## 2. 구 메서드 제거 결과 (P1a~P1h)

| 메서드 | 시그니처 제거 위치 | 본문 제거 위치 | 호출처 0건 증명 |
|---|---|---|---|
| `CreditUseCase.grant` | `credit.usecase.ts` (메서드 삭제, 약 25줄) | 동일 | `grep "CreditUseCase.grant" src --exclude="*.spec.ts"` = 주석 매치만 |
| `CreditUseCase.deduct` | 동일 | 동일 | 동일 |
| `CreditUseCase.getBalance` | 동일 | 동일 | 동일 |
| `CreditRepositoryPort.adjustCredits` | `credit-repository.port.ts` (시그니처 제거, port 3 메서드 → 2 메서드) | `prisma-credit.repository.ts` (본문 + giftTransfer 본문 일괄 제거, 약 80줄) | `grep "adjustCredits" src --exclude="*.spec.ts"` = 주석 매치만 |
| `CreditRepositoryPort.giftTransfer` | 동일 | 동일 | 동일 |
| `CreditRepositoryPort.sumNegativeAmounts` | 동일 | 동일 | 동일 |
| `PaymentRepositoryPort.completePaymentAtomically` | `payment-repository.port.ts` (시그니처 제거) | `prisma-payment.repository.ts` (본문 제거, 약 18줄) | `grep "completePaymentAtomically" src --exclude="*.spec.ts"` = 주석/payment-status type 명만 매치 |
| `PaymentRepositoryPort.refundPaymentAtomically` | 동일 | 본문 제거, 약 107줄 | 동일 (`refundPaymentAtomically` 메서드 호출 0건) |

부가:
- `CreditReason` enum 폐기 (`credit.ts`) — 호출처 0건 확인 후 제거. `CreditLedger.reason` 자유 문자열로 대체.
- `NovelAnalysisUseCase` `adjustCredits` 폴백 제거 — `chargePoints` 미주입 시 명시적 `BadRequest`(P1h).

## 3. 신·구 분열 해소 결과 (L2a~L2f)

| 변경 | 위치 | 변경 후 |
|---|---|---|
| L2a — discovery 신 위임 | `discovery.usecase.ts:66` | `this.creditUseCase.getGiftRanking(limit)` (CC-3 ledger 위임 재사용 → 신 선물 자동 인식) |
| L2b — discovery spec 갱신 | `discovery.usecase.spec.ts:30` | mockCreditUseCase 로 교체 |
| L2c — admin sumSpendByAuthor 신설 | `credit-ledger.port.ts` | `sumSpendByAuthor(authorId?: string | null): Promise<number>` — 절대값 반환 |
| L2d — sumSpendByAuthor 구현 | `prisma-credit-ledger.repository.ts` | `creditLedger.aggregate({_sum, where: { type: 'spend', ...authorId }})` |
| L2e — admin getAllCreditLogs 위임 | `admin.usecase.ts:185` | `this.ledger.findByAuthor(authorId, 100)` (신 CreditLedgerEntry[] 반환) |
| L2f — admin spec 갱신 | `admin.usecase.spec.ts` | mockCreditRepo 제거 + mockLedger 에 sumSpendByAuthor/findByAuthor 추가 |

추가 DI 정리:
- `AdminUseCase` 생성자에서 `creditRepo` 인자 제거 (구 `(authorRepo, workRepo, creditRepo, adminRepo, grantPoints, ledger, auditLog)` → 신 `(authorRepo, workRepo, adminRepo, grantPoints, ledger, auditLog)`)
- `SocialUseCase` 생성자에서 `creditRepo` 인자 제거 + 구 `giftTransfer` 폴백 코드 삭제
- `DiscoveryUseCase` 생성자 `creditRepo` → `creditUseCase` 전환
- `NovelAnalysisUseCase` 생성자에서 `creditRepo` 인자 제거 (P1h 완결)

## 4. 통합 spec 신설 (I1a/I1b)

- `credit-rollover-source-ledger-integration.spec.ts` 끝에 **`CC-4 Phase 1 통합 — 구 메서드 제거 + admin·discovery 신·구 분열 해소`** describe 신설 (4 it):
  - `I1b L2c — AdminUseCase.getStats 가 ledger.sumSpendByAuthor 위임 (신 ledger 통계 반영)`
  - `I1b L2e — AdminUseCase.getAllCreditLogs 가 ledger.findByAuthor 위임 (신 4 출처 entry 반환)`
  - `I1b L2a — CC-2b 신 선물(source="gift")이 CreditUseCase.getGiftRanking 위임으로 인식됨`
  - `구 메서드 제거 정합 — PaymentRepositoryPort / CreditRepositoryPort 에 구 시그니처 0건` (컴파일 타임 박제)

## 5. 빌드 / jest / 커버리지

- `npx tsc --noEmit` — 무에러
- `npm run build` (`nest build`) — 통과
- `npm test` — **75 suites / 1063 tests PASS** (1059 → 1063, +4 it)
- 커버리지: **61.74% statements / 63.33% lines** — 게이트 ≥60% 충족 (server)
- `docker build -t grimoire-server-cc4-test .` — 통과

## 6. 완료 게이트 PASS/FAIL

| 게이트 | 결과 |
|---|---|
| Gate 1: `npm run build` 무에러 | ✅ PASS |
| Gate 2: `npm test` 전체 PASS + 커버리지 ≥60% | ✅ PASS (1063 tests / 61.74% stmts / 63.33% lines) |
| Gate 3: `shared-contracts.md` §13/§30 + `TECH_STATUS.md` + `docs/api-contract.md` 갱신 | ✅ PASS |
| 구 메서드 제거 증명: src 본문 호출 0건 | ✅ PASS — `grep "creditRepo\.\(giftTransfer\|adjustCredits\|sumNegativeAmounts\)\|completePaymentAtomically\|refundPaymentAtomically\|CreditUseCase\.\(grant\|deduct\|getBalance\)\b" src/ --include="*.ts" --exclude="*.spec.ts"` 결과 = 주석 매치만 (코드 본문 0건) |
| 신·구 분열 해소 증명: admin/discovery `creditRepo` 호출 0건 | ✅ PASS — `grep "creditRepo\." src/application/{admin,discovery} --exclude="*.spec.ts"` 결과 = 주석 4건만 |

## 7. Phase 2 / Phase 3 이월 항목

### Phase 2 (별도 sprint — Phase 1 머지 + 운영 박제 ≥1 sprint 후)

- `Payment.credits` Int 컬럼 → `Payment.points` rename (의미 재해석은 이미 CC-2a 박제 / 물리 rename 만 잔존)
- `RefundLog.credits`·`deficitCredits` 컬럼 의미 박제 강화 (rename 은 명명 충돌 우려로 보존 권고)
- 마이그레이션 작은 1건 + 코드 변수명 일괄 정리

### Phase 3 (별도 sprint — Phase 1·2 머지 + 운영 박제 ≥1 sprint 후)

- `Author.credits` Int 컬럼 DROP
- `CreditLog` 테이블 폐기 + `prisma-credit.repository.ts` 파일 삭제 + `CreditRepositoryPort` interface 삭제
- `auth.controller:48` 응답에서 `author.credits` 제거 (`/auth/me` 응답 변경 — web 핸드오프)
- `refund-payment.usecase:124-125`/`credit-migration.ts:54,58` 잔존 코드 정리
- 마이그레이션 큰 1건 (DROP 2건 + Cascade FK 정합)

### CC-5 / 후속 sprint 별도 영역 (CC-4 범위 외)

- HIGH-1 案 B (`Author.plan` 정본 이행 + 읽기 13곳 → `MembershipPlanPort.getPlan` 위임) — 별도 sprint 권고 (Case C — `.claude/state/sprint-cc4-postcleanup-plan-draft.md` §2 결정)
- `MembershipPlanPort.getPlan` HTTP 노출 — CC-5 PAY-P1-4 구독 도메인 응집
- PAY-P1-4 Polar 구독 결제 연동 — CC-5
- sensor 7종 hook 등록 — harness agent 영역

## 8. 발견 사항

- `prisma-credit.repository`는 Phase 3 까지 잔존 — `findLogsByAuthorId`/`getGiftRanking` 2종 폴백 경로만 노출. `credit.usecase`에 ledger 가 항상 주입(`CreditLedgerPort`)되는 운영 환경에서는 폴백 호출 0건이지만, port/repository 모두 Phase 3 폐기.
- `CreditReason` enum 폐기 결과 = `signup_bonus`/`first_work_bonus`/`gift_sent:..`/`admin_grant:..` 등 reason 문자열은 신 시스템에서 자유 문자열로 사용 중. shared-contracts §30 합의 prefix 규약은 유지.
- `payment-charge-credit-integration.spec.ts` C7d 통합 (구 `completePaymentAtomically` 미연동 감지)은 port 시그니처 제거로 컴파일 타임 박제로 대체.
- `Payment.credits` rename 은 `Author.deficitPoints`와 명명 충돌 가능성 검토 필요 — Phase 2 결정 게이트에서 사용자 협의.

## 9. 핸드오프

- **grimoire-qa** — DEV_REPORT.md + 본 progress 박제 + sensor 일괄 대조 (sensor 7종 hook 등록은 harness 영역, 본 sprint 외)
- **grimoire-web** — docs sync only (api-contract `/api/discover/authors/most-gifted` + `/api/admin/credits/logs` 변경 박제). 코드 변경은 web 영향 0건 (응답 모델 = CC-3 박제와 동일).
- **harness agent** — sensor 7종(`sensor-credit-overhaul-recalc.sh` 등) settings.json hook 등록 권고 핸드오프 (별도 영역).
