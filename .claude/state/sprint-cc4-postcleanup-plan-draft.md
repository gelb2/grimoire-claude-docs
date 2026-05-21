# 작업 계획: CC-4 폐기 정리 — 구 메서드 제거 + 신·구 분열 해소 + 컬럼 의미 정합 / rename + DROP (writing-plans)

> 작성: 2026-05-21 / grimoire-planner (Initializer 패턴) / **계획 수립 전용 — 코드 변경 0건**
> 근거 정본: `reports/CREDIT_CORE_DIAGNOSIS.md` §2-3 폐기 의존 그래프 / §5-A 案 A·B / §5-B HIGH-3 / §8 sprint 분할표 CC-4 행 / §10 미확인
>           + `.claude/state/sprint-cc1-pay-s1-plan-draft.md` + `sprint-cc2a-charge-wiring-plan-draft.md` + `sprint-cc2b-gift-refund-wiring-plan-draft.md` + `sprint-cc3-rollover-source-ledger-plan-draft.md`
>           + `.claude/shared-contracts.md` §13 RefundPaymentAtomically(line 2380~) / §30 CreditOverhaul(line 2391~)
>           + `reports/sprint-cc{1,2a,2b,3}-progress.md` 직전 박제 + `memory/project_session_20260521.md` (prod rev 103 + V Phase 적용 박제)
> 적용 양식: `.claude/skills/writing-plans/SKILL.md` (2~5분 sub-task / [MUST]·[SHOULD]·[NICE] / 위험도 🔴🟡🟢 / 의존 / rollback / 검증 게이트)
> 구조 정본: CC-1·CC-2a·CC-2b·CC-3 계획과 동일 섹션 구조·포맷.
> 범위: **CC-4 폐기 정리만** — CC-5 PAY-P1-4 Polar 구독은 범위 외 (착수 직전 상세화 원칙). HIGH-1 案 B는 §6 사용자 게이트 분기 — Phase 1·2 範圍 내 vs CC-5 이월 결정 종속.

---

## 0. 진행 순서 + 의존 개요 + sprint 분할 권고

```
CC-1 (적립 비결제 — 완료·qa검증)        ──선행 완료──┐
CC-2a (충전 결제 — 완료·qa검증)         ──선행 완료──┤
CC-2b (선물·환불 결제 — 완료·qa검증)    ──선행 완료──┤
CC-3 (이월 + 원장 단일화 — 완료·qa검증) ──선행 완료──┤
V Phase 마이그레이션 dev/prod apply ──선행 완료(5/21)┘
                                                       │
                                                       ↓
                                        CC-4 폐기 정리 (3 Phase 권고)
                                          ├─ Phase 1: 코드 제거 + 신·구 분열 해소 (마이그레이션 0) — 회귀 안전망 1차
                                          ├─ Phase 2: 컬럼 의미 정합 + (옵션) rename (마이그레이션 작은 1건)
                                          └─ Phase 3: Author.credits DROP + CreditLog 폐기 (큰 마이그레이션 — 1 sprint 유예 후)
```

- **CC-1·CC-2a·CC-2b·CC-3 완전 종결** — 적립 8경로(T1~T8) 전부 신 `CreditLedger` 이행, CRITICAL-1/2·HIGH-1(案 A)·HIGH-3·이중 외상 통합·C-6 해소. V Phase 마이그레이션 5/21 prod rev 103 적용 정합(SUM 105,000 / credit_ledgers 15 / membership_plans 13 / reconciliation 11/11). 잔존 = **폐기 정리** (구 메서드/컬럼/테이블 + 신·구 분열 잔존).
- **3단계 분할 권고 — 옵션 Z** (다음 §0-2 분할 권고案 비교).
- **S0 선행 게이트** — 진단 §10 미확인 + 본 sprint 직접 코드 5건(① admin·discovery `creditRepo` 직접 호출 file:line ② `getGiftRanking` 호출 사슬 + 신 위임 정합 검증 ③ `Payment.credits`/`RefundLog.credits`/`.deficitCredits` 사용처 grep ④ `Author.credits` 읽기/쓰기 전수 grep ⑤ `CreditLog` 사용처 전수 grep)을 **S0 sub-task에서 Read로 해소**한 뒤 본 작업 진입.
- **사용자 결정 게이트 1건** — HIGH-1 案 B를 CC-4에 포함할지 / CC-5와 묶을지 / 별도 sprint로 이월할지 (§6 case A·B·C).

### 0-1. 예상 총 시간

- CC-4 전체: **규모 L** — Phase 1 ~M(4~5h) + Phase 2 ~S~M(2~3h) + Phase 3 ~M(3~4h) = 합산 ~9~12h.
- sub-task 총 **42개** (Phase 1: S0 5 + 코드 제거 8 + 신·구 분열 해소 6 + 통합 spec·마무리 5 = 24 / Phase 2: 컬럼 의미 정합 4 + rename 마이그레이션 3 + 마무리 4 = 11 / Phase 3: DROP 마이그레이션 5 + 폐기 검증 2 + 마무리 3 = 10. + HIGH-1 案 B 분기: Phase 1 +7~10).
- **분할 근거**: ≥30분 + **§2-3 폐기 의존 그래프**가 단일 sprint 불가 — `Author.credits` DROP 전 적립·차감 신 경로 + `CreditLog` 의존 메서드 폐기 + 컬럼 의미 정합이 선행 필요. 1줄 실수가 "운영 prod에서 Author.credits 컬럼 사라졌는데 코드는 여전히 읽음" / "RefundLog.credits 의미 충돌" / "admin·discovery가 신 선물 못 봄"으로 직결 → Phase별 git tag + 마이그레이션 백업 의무.

### 0-2. sprint 분할 권고案 비교 (옵션 X·Y·Z)

| 옵션 | 구조 | 마이그레이션 | 회귀 위험 | 권고 |
|---|---|---|---|---|
| 옵션 X (단일) | 1 sprint에 코드 제거 + 컬럼 rename + 테이블 DROP 일괄 | 큰 1회 (DROP 2건 + rename 3건) | **최대** — DROP 직전 코드가 컬럼 미사용 100% 검증 불가. Cursor 반면교사(`Author.credits` DROP 직전 회귀 잔존) | ❌ 비권고 |
| 옵션 Y (2단계) | Phase 1 = 코드 제거 + 컬럼 의미 정합. Phase 2 = rename + DROP + CreditLog 폐기 | 작은 1건(rename) + 큰 1건(DROP) | 중간 — 코드 제거 후 즉시 DROP 시 회귀 검증 ~24h 부족 | 차선 |
| **옵션 Z (3단계) — 권고** | Phase 1 = 코드 제거 + 신·구 분열 해소(마이그레이션 0). Phase 2 = 컬럼 의미 + rename(작은 마이그레이션 1건). Phase 3 = DROP + CreditLog 폐기(큰 마이그레이션) | 0 + 작은 1건 + 큰 1건 | **최소** — Phase 1·2 머지 후 ≥1 sprint 유예 → Phase 3에서 DROP. 회귀 박제 시간 확보 | ✅ 권고 |

**권고 — 옵션 Z (3 Phase 분할)**. 사유:

1. **Cursor 반면교사**(schema.prisma L24 명시 "1 sprint 유예 후 별도 sprint 에서 제거 — 롤백 안전망, §8-6") — `Author.credits` DROP 직전 사용처 0건 검증이 ≥1 sprint 운영 박제 필요. Phase 1·2 머지 후 prod 회귀 박제 → Phase 3 DROP.
2. **마이그레이션 안전성** — Phase 2(rename) + Phase 3(DROP)을 별 sprint로 두면 각 마이그레이션 단위로 pg_dump 백업 + 검증 SQL + 롤백 단위가 명확.
3. **Phase 1 단독으로도 가치** — 구 메서드 호출처 0건 검증 + admin·discovery 신 선물 인식 + getGiftRanking 분열 해소로 **운영 회계 정합 즉시 회복** (Phase 2·3 없이도 prod 안전).
4. **HIGH-1 案 B 분리 게이트** — §6 사용자 결정으로 Phase 1에 포함할지 CC-5/별도로 이월할지 분기 (案 B는 작업 큼 — 단독 sprint 분할도 가능).
5. **Phase 2 옵션** — `Payment.credits`/`RefundLog.credits`·`deficitCredits` 물리 rename은 사용자 결정 종속. **의미 재해석만으로도 정합**(현재 코드가 이미 pt 의미로 사용 — shared-contracts §30 박제). rename은 가독성·문서 정합 보강 — Phase 2에서 결정 게이트 추가 가능.

> ⚠️ 메인 결정 = **옵션 Z 채택 + Phase 1 즉시 착수 / Phase 2·3는 Phase 1 머지 + ≥1 sprint 유예 후 별도 계획**. 본 계획은 Phase 1을 상세 분해 + Phase 2·3는 골격(sub-task 표·게이트만) — 착수 직전 상세화 원칙.

---

## 1. S0 — 선행: §10 미확인 + CC-4 직접 코드 현행 해소 (착수 게이트)

> CREDIT_CORE_DIAGNOSIS §10 + §2-3 — 추정 금지. 본 sub-task로 폐기 대상 코드 현행을 Read 해소한 뒤 Phase 1 진입.
> ⚠️ 본 계획 작성 중 grep으로 호출처를 부분 확인했으나(§14 참조), CC-1~CC-3 머지 + V Phase 마이그레이션 적용 이후 변동 가능성 존재 → S0가 **현행 재실측**.

### 1-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| S0a | admin·discovery 구 `creditRepo` 직접 호출 grep 재실측 — `grep -rn "this\.creditRepo\.(sumNegativeAmounts\|findLogsByAuthorId\|getGiftRanking\|adjustCredits)" src/application/{admin,discovery,credit}` 결과 정확한 file:line 박제. 본 계획 작성 중 grep: ① `admin.usecase:35` `sumNegativeAmounts()` ② `admin.usecase:177` `findLogsByAuthorId(authorId)` ③ `discovery.usecase:66` `getGiftRanking(limit)`. 신·구 분열 해소(L2) 대상 목록 = S0a 결과 | [MUST] | 🟢 | 5분 | CC-3 prod 적용 완료(5/21) | admin·discovery `creditRepo` 호출처 file:line 표 확정 (L2 분기 입력) |
| S0b | `getGiftRanking` 호출 사슬 + 신 위임 정합 검증 — `credit.usecase:174~178` `getGiftRanking`이 ledger 주입 시 `ledger.getGiftRanking` / 미주입 시 `creditRepo.getGiftRanking` 분기. `discovery.usecase:66`이 `creditRepo`만 직접 호출(useCase 미경유) → 신 ledger 미인식 위험. CC-3 H3c가 `CreditUseCase.getGiftRanking`는 위임했으나 `DiscoveryUseCase`는 `creditRepo` 직접 호출 잔존. 동일 신·구 분열 잔존 = L2의 핵심 해소 대상 | [MUST] | 🟢 | 5분 | S0a | `getGiftRanking` 호출 사슬 박제 + discovery 신·구 분열 잔존 확인 |
| S0c | `Payment.credits` / `RefundLog.credits` / `RefundLog.deficitCredits` 사용처 grep — `grep -rn "Payment\.credits\|payment\.credits\|RefundLog\.credits\|RefundLog\.deficitCredits\|deficitCredits" src` 결과 file:line 박제. 본 계획 작성 중 grep: payment.usecase ~6건(`.credits`) + refund-payment.usecase ~2건 + prisma-payment.repository ~8건(`deficitCredits`/`credits`) + spec ~다수. **컬럼 의미는 이미 pt 단위로 재해석** (shared-contracts §30 + 코드 주석 박제) → Phase 2 rename 대상은 컬럼 자체 + 코드 주석 + 변수명 | [MUST] | 🟢 | 6분 | - | `Payment.credits` 등 사용처 file:line + 의미 재해석 박제 확정 (Phase 2 입력) |
| S0d | `Author.credits` 읽기/쓰기 전수 grep — `grep -rn "author\.credits\|Author\.credits\|\.credits\b" src` 중 `Author` 도메인 컬럼 한정 결과 박제. 본 계획 작성 중 grep: credit.usecase.spec/social.usecase.spec/admin.usecase.spec/audit-log.service.spec 등 **spec 다수** + refund-payment.usecase:124-125 (`author.credits ?? 0`) + credit.usecase:46-65 (구 `deduct`/`grant`/`getBalance` 본문) + 기타 모델/마이그레이션. Phase 3 DROP 안전성 입력 — 코드에서 `Author.credits` 직접 사용처 0건 검증 필요 | [MUST] | 🟢 | 7분 | - | `Author.credits` 읽기/쓰기 전수 박제 — Phase 1 코드 제거 대상 + Phase 3 DROP 안전성 검증 입력 |
| S0e | `CreditLog` 사용처 전수 grep — `grep -rn "CreditLog\|credit_log\|creditLog" src prisma` 결과 박제. 본 계획 작성 중 grep: ① `schema.prisma:55,154` Author 관계 + 모델 정의 ② `prisma-credit.repository` `getGiftRanking`/`findLogsByAuthorId`/`sumNegativeAmounts`/`adjustCredits` 본문이 `CreditLog` 의존 ③ `credit.usecase` 구 4 메서드 + spec ④ admin·discovery·social·analysis spec mock. Phase 3 테이블 폐기 안전성 입력 — `prisma-credit.repository` 메서드 제거 시 모든 호출처 사전 제거 필요 | [MUST] | 🟢 | 7분 | - | `CreditLog` 사용처 전수 박제 — Phase 3 테이블 폐기 안전성 입력 |

**S0 게이트**: S0a~S0e [MUST] 5건 완료 = §10 미확인 + CC-4 직접 코드 현행 해소 → §6 사용자 결정 게이트 진입 허가. 미확인 잔존 시 본 작업 착수 금지.

> 진단 §10 미확인 중 CC-4 직접 관련 = S0a/S0b/S0e(admin·discovery + getGiftRanking 분열 + CreditLog 의존). 나머지(dev plan 분포 = V Phase 마이그레이션 적용 5/21 완료로 해소 / sensor hook = harness / Polar KYC = CC-5)는 CC-4 범위 외.

---

## 2. §6 사용자 결정 게이트 — HIGH-1 案 B를 CC-4에 포함할지 분기

> CREDIT_CORE_DIAGNOSIS §5-A 案 B (CC-3에서 案 A 채택, 案 B는 "CC-5/후속 옵션"으로 이월 박제 — sprint-cc3-progress.md "CC-3 미해소 잔존"). CC-3에서 案 A로 `Author.plan` 정본 유지 + `MembershipPlan.tier` 미러(`changeTier` 양측 동기) 박제됐으나, 案 B(`tier` 정본화 + `Author.plan` `[DEPRECATED]` + 읽기 13곳 이행)는 미해소. **사용자 결정** = CC-4 Phase 1에 포함 vs CC-5와 묶음 vs 별도 sprint 이월.

### 2-1. 게이트 내용

- **결정 대상** — HIGH-1 案 B 진행 시점:
  - **Case A** — CC-4 Phase 1 포함: theme-slot.usecase 5건 + generate-theme.usecase 3건 + get-theme.usecase 2건 + plan.usecase 2건 + admin.usecase 3건 = **13곳 이행 + DI 5건 + spec 7건** (CC-3 S0a 박제). Phase 1 sub-task +7~10 추가, 시간 +3~5h. CC-4 sprint 비대.
  - **Case B** — CC-5 PAY-P1-4와 묶음: Polar 구독 결제 연동 sprint에 자연 응집 (`changeTier` 활성화 시점). 但 CC-5 sprint도 비대(진단 §7-2 1~7 + 案 B 추가).
  - **Case C** — 별도 sprint 이월: HIGH-1 案 B 단독 sprint (`Author.plan` 읽기 13곳 + DI + spec + `Author.plan` `[DEPRECATED]`). 규모 M. CC-5와 병렬 가능.

### 2-2. 게이트 판정 권고

| 시나리오 | 처리 | 권고 |
|---|---|---|
| Case A (CC-4 포함) | Phase 1에 H2a~H2g 7 sub-task 추가 | CC-4 sprint 부담 +3~5h |
| Case B (CC-5와 묶음) | CC-5 PAY-P1-4 계획에 案 B 추가 — `changeTier` HTTP 노출 + `Author.plan` 읽기 13곳 이행 동시 진행 | 구독 도메인 응집 — 권고도 가능 |
| **Case C (별도 sprint — 권고)** | CC-4 머지 후 별도 sprint(예: `HIGH-1-CASE-B`) — `MembershipPlanPort.getPlan` HTTP 노출 + 읽기 이행 + `Author.plan` `[DEPRECATED]`. CC-5와 병렬 진행 가능 | **권고** — 案 A로 운영 정합 안정, 案 B는 단독 sprint 분리로 회귀 위험 최소. CC-4 폐기 정리 본질에 집중 |

**권고 — Case C (별도 sprint 이월)**. 사유:

1. **CC-3가 案 A로 운영 안정화 완료** — `Author.plan` 정본 유지 + `changeTier` 양측 동기(ADR-014 박제). 운영 정합 즉시 위험 0건 — 案 B는 가독성·단일 정본 보강이지 안전성 직결 아님.
2. **CC-4 본질 분리** — CC-4 = 폐기 정리(구 메서드 + 컬럼 + 테이블). 案 B = 정본 이행 — 성격 다름. 묶으면 CC-4 sprint 비대 + 회귀 진단 분산.
3. **CC-5도 sprint 비대 회피** — PAY-P1-4 구독 webhook 7 sub-task(진단 §7-2)에 案 B 13곳 추가 시 CC-5도 비대.
4. **별도 sprint = 회귀 위험 최소** — `Author.plan` 읽기 13곳 이행은 작업 명확(grep + 위임 + spec) — 단독 sprint면 진단·구현·QA 한 단위로 박제.

> ⚠️ 본 계획 §3~§5(Phase 1·2·3 sub-task 표)는 **Case C 권고 가정**. 사용자 Case A 채택 시 §3-2에 H2a~H2g 7 sub-task 추가 (CC-3 §4-2 案 B 구조 정합).

---

## 3. Phase 1 — 코드 제거 + 신·구 분열 해소 (마이그레이션 0 — 회귀 안전망 1차)

> 범위: ① 호출처 0건 검증된 구 메서드 코드 제거 (CreditUseCase.grant/deduct/gift + creditRepo.giftTransfer + paymentRepo.completePaymentAtomically/refundPaymentAtomically). ② admin·discovery의 구 `creditRepo` 직접 호출 → 신 `CreditLedgerPort` 위임 이행. ③ `CreditReason` enum 정리 + sensor 핸드오프 + shared-contracts/docs 갱신.
> 마이그레이션 0건 — 코드 변경만. Phase 2·3 머지 전 회귀 박제 안전망 1차.

### 3-1. 구 메서드 코드 제거 (sub-task 표)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| P1a | `CreditUseCase.grant`/`deduct`/`getBalance` 삭제 — `credit.usecase.ts:37~66` 3 메서드 본문 + 시그니처 제거. `CreditUseCase`는 `getPointBalance`/`gift`/`getGiftRanking`/`getLogs` 4 메서드만 남김 (전부 신 시스템 위임). `CreditRepositoryPort` DI는 `getGiftRanking`/`getLogs` 폴백 유지 위해 잔존 (Phase 3 폐기) | [MUST] | 🟡 | 5분 | S0 게이트 | tsc PASS + `credit.usecase.ts` `deduct`/`grant`/`getBalance` 메서드 grep 0건 |
| P1b | `credit.usecase.spec.ts` 갱신 — 구 `deduct`/`grant`/`getBalance` 단위 검증 제거. 잔존 4 메서드(`getPointBalance`/`gift`/`getGiftRanking`/`getLogs`) spec 유지 | [MUST] | 🟡 | 5분 | P1a | `npm test credit.usecase.spec` PASS |
| P1c | `prisma-credit.repository.giftTransfer` 삭제 — CC-2b 이후 호출처 0건(`credit.usecase.gift` → `ledger.transfer` 이행, S0b 확인). 메서드 본문 + `CreditRepositoryPort.giftTransfer` 시그니처 제거. `prisma-credit.repository.spec.ts` 해당 단위 검증도 제거 | [MUST] | 🟡 | 5분 | P1a | tsc PASS + `giftTransfer` grep — port + repository 0건 |
| P1d | `prisma-payment.repository.completePaymentAtomically` 삭제 — CC-2a 이후 호출처 0건(`payment.usecase` → `completePaymentWithPoints` + `payment-reconciliation.job` → `completePaymentWithPoints` 이행). 메서드 본문 + `PaymentRepositoryPort.completePaymentAtomically` 시그니처 제거. spec 단위 검증 제거 | [MUST] | 🟡 | 6분 | P1c | tsc PASS + `completePaymentAtomically` grep — port + repository 0건 (spec 잔존은 신 메서드 단위) |
| P1e | `prisma-payment.repository.refundPaymentAtomically` 삭제 — CC-2b 이후 호출처 0건(`refund-payment.usecase` → `refundPaymentWithPoints` 이행). 메서드 본문 + `PaymentRepositoryPort.refundPaymentAtomically` 시그니처 제거. spec 단위 검증 제거. **PAY-P1-1/P2-1/P3-A 회귀 검증은 `refundPaymentWithPoints` spec 으로 이미 이식** (CC-2b §5 C6f 박제) | [MUST] | 🟡 | 6분 | P1d | tsc PASS + `refundPaymentAtomically` grep — port + repository 0건 (spec 잔존은 신 메서드) |
| P1f | spec mock 정리 — `auth-security.spec.ts`/`social.usecase.spec.ts`/`discovery.usecase.spec.ts` 등에서 `mockCreditRepo.giftTransfer` mock 항목 제거(잔존 항목 `adjustCredits`/`findLogsByAuthorId`/`getGiftRanking`/`sumNegativeAmounts`는 P3 admin·discovery 이행 후 정리). `payment.usecase.spec.ts:412` `mockCreditUseCase.grant not.toHaveBeenCalled` 등 구 메서드 mock 제거 | [MUST] | 🟡 | 6분 | P1e | `npm test` 전체 PASS — mock 정리 후 spec 회귀 0건 |
| P1g | `CreditReason` enum 정리 — `domain/model/config.ts`(또는 위치)의 구 `SIGNUP_BONUS`/`FIRST_WORK_BONUS`/`NOVEL_ANALYSIS` enum 값과 신 `reason` 문자열(`'signup_bonus'`/`'first_work_bonus'`/`'gift_sent:..'`/`'admin_grant:..'` 등) 정합 — 매핑 박제 또는 enum 제거. CC-1~CC-2b 이후 신 `reason`은 문자열 직접 사용 → enum 호출처 0건이면 enum 제거 | [SHOULD] | 🟡 | 5분 | P1b | tsc PASS + 호출처 0건 검증 |
| P1h | `prisma-credit.repository.adjustCredits` 검토 — `credit-repository.port` 정의 + repository 본문 + `prisma-credit.repository` 잔존. CC-1 이후 호출처 = `novel-analysis.usecase:132,152`(아직 구 경로 분기 — `chargePoints` 미주입 시 폴백) + `credit.usecase` 구 메서드(P1a 제거 후 0건). novel-analysis의 폴백을 Phase 3 즉시 제거 또는 Phase 1 즉시 제거 결정 — **`chargePoints` 항상 주입됨 검증** 후 P1h에서 폴백 제거 권고. Phase 1 결정 종속 — chargePoints 주입 보장 시 즉시 제거, 아니면 Phase 3 이월 | [SHOULD] | 🟡 | 5분 | P1a,S0e | tsc PASS + `chargePoints` 항상 주입 검증 + 폴백 제거 시 `adjustCredits` 호출처 0건 |

### 3-2. 신·구 분열 해소 (sub-task 표)

> CC-3가 `credit.usecase`의 `getGiftRanking`/`getLogs`를 ledger 위임으로 이행했으나, **admin.usecase**(sumNegativeAmounts/findLogsByAuthorId)와 **discovery.usecase**(getGiftRanking 직접 호출)는 잔존. CC-2b가 박은 신 선물을 `/discovery/most-gifted-authors` HTTP가 인식 못 함 — 운영 회계 정합 갭.

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| L2a | `discovery.usecase:66` `creditRepo.getGiftRanking` → `creditUseCase.getGiftRanking` 위임으로 이행 — `CreditUseCase`가 ledger 위임 또는 폴백 분기를 이미 함(CC-3 H3c 박제, `credit.usecase.ts:174~178`). `DiscoveryUseCase`가 `CreditUseCase` DI 추가 + `creditRepo` 의존 제거. **신 선물(`source='gift'`)이 `/discovery/most-gifted-authors`에 반영됨** | [MUST] | 🟡 | 7분 | S0a,S0b | tsc PASS + `discovery.usecase.ts`에서 `creditRepo.getGiftRanking` grep 0건 + `creditUseCase.getGiftRanking` 호출 ≥1 |
| L2b | `discovery.usecase.spec.ts` 갱신 — `mockCreditRepo` mock 제거(또는 잔존 항목만) + `mockCreditUseCase.getGiftRanking` mock 추가. 신 선물 집계 결과 검증 | [MUST] | 🟡 | 5분 | L2a | `npm test discovery.usecase.spec` PASS |
| L2c | `admin.usecase:35` `creditRepo.sumNegativeAmounts()` 이행 — 두 案 분기: ① 案 (i) `CreditLedgerPort`에 `sumSpendByAuthor(authorId?: string)` 신설 (CreditLedger `type='spend'` _sum) — 신 시스템 통합. ② 案 (ii) `admin.usecase.getStats` 구현을 `CreditLedger groupBy({_sum: amount, where: {type: 'spend'}})` 직접 — port 미추가. 권고 = 案 (i) (port 추상화). CC-3 H3a 패턴 정합 | [MUST] | 🟡 | 7분 | S0a | tsc PASS + 案 (i) `CreditLedgerPort.sumSpendByAuthor` 정의 + 호출 |
| L2d | `prisma-credit-ledger.repository.sumSpendByAuthor` 구현 — `creditLedger.aggregate({_sum: {amount}, where: {type: 'spend'}})` 형태. 음수 합 → `Math.abs` 반환 (구 sumNegativeAmounts 동등성) | [MUST] | 🟡 | 6분 | L2c | tsc PASS + 단위 spec 통과 |
| L2e | `admin.usecase:177` `creditRepo.findLogsByAuthorId(authorId)` 이행 — `CreditUseCase.getLogs`(CC-3 위임 완료, `credit.usecase.ts:190~195`)를 admin.usecase가 DI 받아 호출. 또는 직접 `CreditLedgerPort.findByAuthor(authorId, limit)` 호출. 권고 = `CreditUseCase` 경유 (단일 진입점) | [MUST] | 🟡 | 6분 | L2c | tsc PASS + `admin.usecase.ts`에서 `creditRepo.findLogsByAuthorId`/`sumNegativeAmounts` grep 0건 |
| L2f | `admin.usecase.spec.ts` 갱신 — `mockCreditRepo` mock 제거 + 신 mock(`CreditUseCase` 또는 `CreditLedgerPort`) 추가. `getStats`/`getAllCreditLogs` 단위 검증 갱신 (CC-3 패턴 정합) | [MUST] | 🟡 | 7분 | L2e | `npm test admin.usecase.spec` PASS + `admin.controller.spec.ts` 회귀 PASS |

### 3-3. 통합 spec + Phase 1 마무리 (sub-task 표)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| I1a | Phase 1 통합 spec 신설 또는 기존 확장 — `credit-postcleanup-integration.spec.ts` 류 또는 CC-3 통합 spec(`credit-rollover-source-ledger-integration.spec.ts`) 확장. ① 구 메서드 제거 후 신 시스템 단독 작동(채팅 사후 차감 + 분석 차감 + 환불 + 선물 + 충전 전부 정상) ② admin·discovery 신 선물 집계 인식 통합 케이스 | [MUST] | 🟡 | 8분 | L2f | 파일 생성 또는 확장 + tsc PASS |
| I1b | 신·구 분열 해소 통합 케이스 — ① CC-2b 신 선물 박제 후 `DiscoveryUseCase` 통한 `/discovery/most-gifted-authors` 호출 → 신 선물 집계됨 검증. ② `AdminUseCase.getStats` 호출 → `sumSpendByAuthor` 신 ledger 집계 정합 검증. ③ `AdminUseCase.getAllCreditLogs` 호출 → 신 ledger 위임 결과 반환 검증 | [MUST] | 🟡 | 7분 | I1a | 해당 it PASS — admin·discovery 신·구 분열 해소 통합 증명 |
| F1a | 전체 빌드 — `npm run build` 무에러 | [MUST] | 🟢 | 3분 | I1b | 종료코드 0 |
| F1b | 전체 테스트 — `npm test` 통과, server 커버리지 **≥60%** 유지 | [MUST] | 🟢 | 5분 | F1a | jest 전체 PASS, 커버리지 게이트 통과 |
| F1c | `shared-contracts.md` §13 + §30 갱신 — §30 `CreditLedgerPort.sumSpendByAuthor` 신설 + §13 `refundPaymentAtomically` deprecated → 제거 박제 + 변경 이력 1줄씩. ⚠️ §13/§30 인터페이스 정본 → 미갱신 시 다른 agent 통합 단계 깨짐 | [MUST] | 🟡 | 6분 | F1b | `.claude/scripts/sensor-shared-contracts.sh` silent |
| F1d | `grimoire-server/TECH_STATUS.md` + `docs/data-model.md`(`Author.credits` `[DEPRECATED]` 잔존 명시 + `CreditLog` 폐기 예정 명시) + `docs/api-contract.md`(`GET /discovery/most-gifted-authors` 신 선물 인식 박제) + `SCHEMA.md` 갱신 — Phase 1 완료(구 메서드 제거 + 신·구 분열 해소) 박제. `docs-sync` drift sensor silent | [MUST] | 🟡 | 6분 | F1c | drift sensor silent |
| F1e | sensor 일괄 — `sensor-shared-contracts` / `-instruction-degradation` / `-agent-priority-labels` / `-agent-interaction` + `sensor-credit-source-accounting.sh` / `-credit-overhaul-recalc.sh`(존재 시) 실행 | [SHOULD] | 🟢 | 3분 | F1d | sensor 전부 silent/PASS |
| F1f | **sensor 7종 hook 등록 권고 핸드오프** — `.claude/scripts/sensor-credit-overhaul-recalc.sh` / `-denomination.sh` / `-source-accounting.sh` / `-subscription-pool-no-rollover.sh` / `-chat-charge-tier.sh` / `-credit-atomicity.sh` / `-admin-credit-ui.sh` settings.json hook 등록 = **harness 영역** (server sprint 외) → DEV_REPORT.md에 명시 핸드오프 박제 (CC-3 S1a 패턴 정합) | [SHOULD] | 🟢 | 3분 | F1e | 핸드오프 박제 명시 |

> **원가 게이트 판정 (F1 단계 박제)**: Phase 1은 **신규 AI 기능 추가 0건** — 구 메서드 제거 + 신·구 분열 해소. AI 모델 호출 0건, `CREDIT_PRODUCTS` 무변경, 차감 N 무변경. §0 직결값을 건드리지 않음. **cost-accountant 마진 검증 게이트 불요** — CC-3와 동일.

> **visual-canon-keeper 게이트 판정**: Phase 1은 **UI 변경 0건** — server 도메인 한정. visual-canon-keeper 검수 **불요**.

---

## 4. Phase 2 — 컬럼 의미 정합 + (옵션) rename (작은 마이그레이션 1건) — 골격

> 범위: ① `Payment.credits` (= pt 의미) → 컬럼명 `points` rename + 마이그레이션. ② `RefundLog.credits` / `deficitCredits` (= pt 의미) → 가능 시 의미·이름 정합. ③ 부수 정리 — 컬럼 주석 정합 + shared-contracts/docs 갱신.
> 작은 마이그레이션 1건 — Phase 1 머지 + ≥1 sprint 운영 박제 후 착수. **본 계획은 골격만** — 착수 직전 상세화.

### 4-1. 결정 게이트 (Phase 2 착수 전 사용자 결정)

| 항목 | 옵션 | 권고 |
|---|---|---|
| `Payment.credits` rename | (a) `points` 물리 rename + 마이그레이션 / (b) 의미 재해석 유지 + 주석 보강만 | (a) 권고 — pt 의미 정합. 단 사용자 결정 |
| `RefundLog.credits` rename | (a) `refundedPoints`/`recoveredPoints` 류 + 마이그레이션 / (b) 의미 재해석 유지 | (b) 권고 — 컬럼명이 회계 식별자(KRW × pt) — rename 시 web 영향 검증 필요 |
| `RefundLog.deficitCredits` rename | (a) `deficitPoints` 류 + 마이그레이션 / (b) 의미 재해석 유지 | (b) 권고 — `Author.deficitPoints`와 명명 충돌 가능 |

### 4-2. sub-task 골격 (착수 직전 상세화)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 |
|---|---|---|---|---|---|
| P2a | Phase 2 사용자 결정 게이트 확정 — rename 대상 선택 (P1 머지 + 회귀 박제 ≥1 sprint 후) | [MUST] | 🟢 | (사용자) | Phase 1 완료 |
| P2b | 마이그레이션 SQL 작성 — `ALTER TABLE payments RENAME COLUMN credits TO points` 등 — Prisma `migrate dev` 새 마이그레이션 | [MUST] | 🔴 | 7분 | P2a |
| P2c | `schema.prisma` 갱신 — `Payment.credits Int` → `Payment.points Int @map("points")` + 영향 컬럼 갱신 | [MUST] | 🟡 | 5분 | P2b |
| P2d | 코드 변수명 일괄 정리 — `payment.credits` → `payment.points` 전수 변경 (~20곳 추정) + spec/repository/usecase | [MUST] | 🟡 | 15분 | P2c |
| P2e | `RefundLog.deficitCredits` 코드 주석 의미 박제 — Phase 2 (b) 권고 시 컬럼 보존 + 주석 정합 강화 | [MUST] | 🟡 | 5분 | P2d |
| P2f | dev 마이그레이션 apply + 검증 + prod apply (사용자 키워드 게이트 `Payment.credits rename dev/prod migration 진행`) | [MUST] | 🔴 | (사용자 협력) | P2e |
| P2g | 마무리 — 빌드/테스트/문서/sensor (F1a~F1e 정합) | [MUST] | 🟡 | 15분 | P2f |

> Phase 2 마이그레이션 안전성 — 작은 변경(rename 1~3 컬럼). pg_dump 백업 의무 + 검증 SQL(`SELECT COUNT(*), SUM(points) FROM payments` 마이그레이션 전후 일치) + Phase 1 코드 변경 후 회귀 spec ≥1 sprint 운영 안정성 확보 후 진행. 롤백 = `RENAME COLUMN points TO credits` 역방향.

---

## 5. Phase 3 — Author.credits DROP + CreditLog 폐기 (큰 마이그레이션) — 골격

> 범위: ① `Author.credits Int` 컬럼 DROP + 관련 인덱스/제약. ② `CreditLog` 테이블 폐기 (`prisma-credit.repository` 메서드 잔존 제거 + 테이블 DROP). ③ Author.creditLogs 관계 제거.
> 큰 마이그레이션 — Phase 1·2 머지 + ≥1 sprint 운영 박제 후 착수. **본 계획은 골격만** — 착수 직전 상세화.

### 5-1. Phase 3 사전 검증 게이트 (DROP 전 필수)

| 검증 | 통과 기준 |
|---|---|
| `Author.credits` 직접 사용처 0건 | `grep -rn "author\.credits\|Author\.credits" src` — spec/comment 제외 코드 본문 0건. **prod 운영 박제 ≥1 sprint** 후. (현재 잔존: refund-payment.usecase:124-125 `author.credits ?? 0` — Phase 1 P1a 이후 제거 필요) |
| `CreditLog` 직접 사용처 0건 | `grep -rn "CreditLog\|credit_log" src --include="*.ts" --exclude="*.spec.ts"` — model + 마이그레이션 외 코드 0건. `prisma-credit.repository` 전체 메서드 잔존 제거 후 |
| Phase 1 sensor 회귀 안정 | sensor-credit-* 7종 silent 박제 |
| Phase 2 마이그레이션 prod 안정 | rename 마이그레이션 적용 + dev/prod 회귀 박제 ≥1 sprint |

### 5-2. sub-task 골격 (착수 직전 상세화)

| # | sub-task | 라벨 | 위험 | 시간 | 의존 |
|---|---|---|---|---|---|
| P3a | Phase 3 사전 검증 게이트 (§5-1) 통과 확인 | [MUST] | 🟢 | 10분 | Phase 1·2 머지 + 운영 안정성 박제 |
| P3b | `prisma-credit.repository` 메서드 전체 제거 — `adjustCredits`/`findLogsByAuthorId`/`getGiftRanking`/`sumNegativeAmounts` (Phase 1 L2 이행 후 호출처 0건 + novel-analysis 폴백 제거 후). 파일 자체 삭제 가능 검토 | [MUST] | 🟡 | 7분 | P3a |
| P3c | `CreditRepositoryPort` 정의 제거 — `domain/port/outbound/credit-repository.port.ts` 삭제. 모든 DI 등록 제거 (`app.module.ts`). spec mock 제거 | [MUST] | 🟡 | 7분 | P3b |
| P3d | 마이그레이션 SQL 작성 — `ALTER TABLE authors DROP COLUMN credits` + `DROP TABLE credit_logs` + `Author.creditLogs` 관계 제거 (`schema.prisma`) | [MUST] | 🔴 | 8분 | P3c |
| P3e | dev 마이그레이션 apply + 검증 SQL (`SELECT credits FROM authors LIMIT 1` → 에러 확인 / `SELECT * FROM credit_logs LIMIT 1` → 에러 확인) | [MUST] | 🔴 | (사용자 협력) | P3d |
| P3f | refund-payment.usecase:124-125 `author.credits ?? 0` 등 잔존 코드 정리 — Phase 1에서 누락된 잔존 `credits` 참조 제거 (Phase 3 직전 발견 시) | [MUST] | 🟡 | 5분 | P3a |
| P3g | prod 마이그레이션 apply (사용자 키워드 게이트 `Author.credits DROP + CreditLog 폐기 prod migration 진행`) + 사후 검증 | [MUST] | 🔴 | (사용자 협력) | P3e,P3f |
| P3h | 마무리 — 빌드/테스트/문서/sensor (F1a~F1e 정합) | [MUST] | 🟡 | 15분 | P3g |
| P3i | shared-contracts §30 변경 이력 박제 — `Author.credits` DROP + `CreditLog` 폐기 명시 + `CreditRepositoryPort` 제거 명시 | [MUST] | 🟡 | 4분 | P3h |
| P3j | web develop → main 머지 (docs sync only, 코드 변경 0) — Phase 3 prod 적용 후 동기화 (5/21 prod 배포 박제 + 본 sprint 변경 이력 누적) | [SHOULD] | 🟢 | (web agent) | P3i |

> Phase 3 마이그레이션 안전성 — 큰 변경(DROP 2건 + Cascade FK). pg_dump 백업 의무 + 검증 SQL + 사전 검증 게이트 (§5-1) 통과 의무 + **롤백은 백업 복원만**(DROP은 비가역). Phase 1·2 머지 + 운영 박제 ≥1 sprint 후 진행 — Cursor 반면교사 정합.

---

## 6. 사용자 결정 게이트 요약

본 계획의 사용자 결정 게이트는 **1건** (§2 — HIGH-1 案 B 처리). Phase 2 결정(rename 대상)은 Phase 1 머지 후 별도 결정 단위.

| 게이트 | 결정 대상 | 권고 |
|---|---|---|
| §6 (Phase 1 진입 전) | HIGH-1 案 B를 CC-4 Phase 1 포함(Case A) / CC-5 묶음(Case B) / 별도 sprint(Case C) | **Case C (별도 sprint 이월)** |
| (Phase 2 진입 전, 별도) | `Payment.credits` rename / `RefundLog.credits`·`deficitCredits` rename 여부 | `Payment.credits` (a) rename / `RefundLog` (b) 의미 유지 |

> Case A 채택 시 Phase 1 sub-task +7~10 (H2a~H2g — CC-3 §4-2 案 B 구조 정합). 시간 +3~5h. CC-4 sprint 비대.

---

## 7. cost-accountant / visual-canon-keeper 게이트

### 7-1. cost-accountant 게이트 — **불요**

CC-4 전체(Phase 1·2·3)는 **신규 AI 기능 추가 0건**. 구 메서드 제거 + 신·구 분열 해소 + 컬럼 의미 정합 + 컬럼/테이블 폐기. AI 모델 호출 0건, `CREDIT_PRODUCTS` 무변경, 차감 N 무변경. §0 직결값을 건드리지 않음 — CC-1·CC-2b·CC-3와 동일 판정.

### 7-2. visual-canon-keeper 게이트 — **불요**

CC-4는 **server 도메인 한정** — UI 변경 0건. 시각 정본(사슴악마) 영향 0건. web 핸드오프 1건(`GET /credits/logs` 응답 변경은 CC-3에서 이미 박제 + Phase 1 admin·discovery 변경은 API 응답 형태 동일) — web docs 동기화만 (Phase 3 P3j).

---

## 8. 핸드오프

### 8-1. 담당 + 산출물 위치

| 영역 | 담당 | 산출물 위치 | 다음 단계 진입 조건 |
|---|---|---|---|
| §6 사용자 게이트 (HIGH-1 案 B 처리) | **사용자** (planner 경유 확인) | Case A/B/C 결정 박제 | Case C(권고) = Phase 1 즉시 진행 / Case A = Phase 1 + H2a~H2g 7 sub-task 추가 / Case B = CC-5 묶음 |
| CC-4 Phase 1 S0 | grimoire-server | §10 미확인 + 폐기 대상 코드 현행 해소 결과 박제 (progress.md) | S0a~S0e 완료 = Phase 1 구현 진입 |
| CC-4 Phase 1 구현 (P1·L2·I1·F1) | grimoire-server (Generator) | Port/usecase/repository 코드 + spec + progress.md 갱신 | F1f 마무리 (sensor 등록 권고 박제) |
| CC-4 Phase 1 채점 | grimoire-qa (Evaluator) | `QA_REPORT.md` — sprint-progress 통과율 박제 + **신·구 분열 해소 통과율 박제** | Phase 1 머지 |
| Phase 2 (P2a~P2g) | 별도 sprint — 착수 직전 상세화 | Phase 1 머지 + 운영 박제 ≥1 sprint 후 |
| Phase 3 (P3a~P3j) | 별도 sprint — 착수 직전 상세화 | Phase 1·2 머지 + 운영 박제 ≥1 sprint 후 |
| sensor 7종 hook 등록 | grimoire-harness agent (별도) | sensor 7종 settings.json hook 등록 | Phase 1 머지 후 |
| HIGH-1 案 B 별도 sprint (Case C 시) | grimoire-server / planner | 별도 sprint(예: `HIGH-1-CASE-B`) 계획 신설 + 실행 | Phase 1 머지 후 또는 병렬 |
| web develop → main 머지 | grimoire-web | docs sync only (코드 변경 0) | Phase 3 prod 적용 후 (P3j) |

### 8-2. Initializer 산출물 (planner)

- 본 계획 = `.claude/state/sprint-cc4-postcleanup-plan-draft.md`.
- **`reports/sprint-cc4-postcleanup-phase1-progress.md` 생성 권고** — Phase 1 sub-task 24건(Case C 권고 시) 체크리스트 + 완료 기준 + **신·구 분열 해소 종결 증명 항목**을 progress.md로 박제 → server(Generator)가 Read 후 갱신, qa(Evaluator)가 채점 (책 Ch 16 Initializer→Generator→Evaluator 패턴).
- Phase 2·3 progress는 각 sprint 착수 직전 별도 생성.
- server / qa에게 본 계획 + progress.md Read 후 작업 핸드오프.

### 8-3. 원가 영향 + 시각 검수 + web 핸드오프 플래그

- CC-4 전체는 **신규 AI 기능 추가 0건** — cost-accountant 마진 검증 게이트 **불요** (§7-1).
- 시각 검수(visual-canon-keeper) **불요** — server 도메인 한정 (§7-2).
- **web 핸드오프 1건** (Phase 3 후) — docs sync (data-model.md + api-contract.md). 코드 변경 0건. P3j 실행.
- **harness 핸드오프 1건** (Phase 1 F1f) — sensor 7종 settings.json hook 등록 권고 박제.

### 8-4. CC-5·후속 sprint로 이월되는 범위 (CC-4 범위 외 — 명시)

| 항목 | 진단 근거 | 이월 sprint |
|---|---|---|
| HIGH-1 案 B (`Author.plan` 읽기 13곳 → `MembershipPlanPort.getPlan` + `Author.plan` `[DEPRECATED]`) | §5-A 案 B | Case C(권고) 시 별도 sprint / Case A 시 Phase 1 / Case B 시 CC-5 |
| `MembershipPlanPort.getPlan` HTTP 노출 (`GET /membership` 등) | §7 + 진단 §10 | CC-5 PAY-P1-4 (구독 도메인 응집) |
| PAY-P1-4 Polar 구독 결제 연동 (`subscription.*` webhook + `changeTier` 활성화 + 구독 시작/멤버십 조회 엔드포인트) | §7 | CC-5 |
| sensor 7종 hook 등록 | LOW-1 / §10 | harness agent |

> ⚠️ **CC-4 Phase 1 완료 후 잔존 결함**: HIGH-1 案 B 미적용 시 `Author.plan` 정본 의존 코드 13곳 잔존 (案 A로 안전 동기). `prisma-credit.repository` 메서드 잔존 (Phase 3에서 제거). `Author.credits` 컬럼 잔존 (Phase 3 DROP). `CreditLog` 테이블 잔존 (Phase 3 폐기). **Phase 1 단독 머지 시점에서도 운영 안전성 100% 확보** (구 메서드 호출처 0건 + 신·구 분열 해소 완료) — Phase 2·3은 정합·청결 보강.

---

## 9. 종합 게이트 — CC-4 Phase 1 완료 선언 조건 + 신·구 분열 해소 종결 증명

### Phase 1 완료 선언

- **§6 사용자 게이트**: HIGH-1 案 B 처리 결정 완료 (Case C 권고 채택 또는 Case A 시 H2a~H2g 7 sub-task 추가).
- **S0 게이트**: S0a~S0e [MUST] 5건 완료 (§10 미확인 + 폐기 대상 코드 현행 해소).
- **본 작업 [MUST]**: P1a~P1f + (P1g·P1h SHOULD) + L2a~L2f + I1a~I1b + F1a~F1d — 전부 통과. ([SHOULD] P1g·P1h·F1e·F1f 실패는 회고만.)
- **검증 게이트** (writing-plans Gate 1·2·3):
  - Gate 1 (빌드): F1a `npm run build` 무에러.
  - Gate 2 (테스트): F1b `npm test` 전체 PASS + 커버리지 ≥60%. **통합 spec(I1)이 핵심** — 구 메서드 제거 후 신 시스템 단독 작동 + admin·discovery 신·구 분열 해소를 통합으로 증명.
  - Gate 3 (문서/sensor): F1c~e — shared-contracts §13/§30 + TECH_STATUS + api-contract + data-model + SCHEMA 갱신 + sensor silent.

### 신·구 분열 해소 종결 증명 (Phase 1 종결 게이트 — 가장 중요)

Phase 1은 폐기 정리의 1차 안전망 + 신·구 분열 해소 — 완료 시 다음 박제:

| 결함 | 증명 방법 |
|---|---|
| **구 메서드 제거** | ① `grep -rn "CreditUseCase\.grant\|CreditUseCase\.deduct\|CreditUseCase\.getBalance\|creditRepo\.giftTransfer\|completePaymentAtomically\|refundPaymentAtomically" src --include="*.ts" --exclude="*.spec.ts"` **0건** ② tsc PASS + 호출처 0건 검증 |
| **admin·discovery 신·구 분열** | ① `grep -rn "creditRepo\.(sumNegativeAmounts\|findLogsByAuthorId\|getGiftRanking)" src/application/{admin,discovery}` **0건** ② 통합 spec I1b PASS — admin·discovery가 신 ledger 위임 결과 정상 반환 박제 ③ `/discovery/most-gifted-authors` HTTP가 CC-2b 신 선물(`source='gift'`) 인식 정합 |
| **sensor 7종 hook 등록 권고 핸드오프** | DEV_REPORT.md 또는 PLANNER_REPORT.md에 명시 박제 (harness agent로 전달) |

→ **신·구 분열 해소 종결 선언 조건**: 위 3건 전부 증명 + 통합 spec I1a/I1b PASS = "CC-4 Phase 1 — 구 메서드 제거 + 신·구 분열 해소 완료. 신 시스템 단독 작동 검증". qa(Evaluator)가 QA_REPORT.md에 종결 통과율 박제.

### Phase 2·3 종결 게이트 (별도 sprint — 골격)

- **Phase 2 종결**: `Payment.credits` rename 마이그레이션 dev/prod apply 정합 + 변수명 일괄 정리 + 회귀 spec PASS.
- **Phase 3 종결**: `Author.credits` 컬럼 사용처 0건 + `CreditLog` 테이블 사용처 0건 + DROP 마이그레이션 dev/prod apply 정합 + 회귀 spec PASS + web develop→main 머지.
- **CC-4 전체 종결**: Phase 1·2·3 머지 + 운영 박제 ≥1 sprint 후 = 크레딧 개편 코어 5 sprint (PAY-S1 + CC-1 + CC-2a + CC-2b + CC-3 + CC-4) 완전 종결.

### CC-4 미해소 잔존 (범위 외 — 명시)

- HIGH-1 案 B 이행 = Case A 채택 시 Phase 1 / 그 외 별도 sprint.
- CC-5 PAY-P1-4 Polar 구독 연동 = 별도 sprint (CC-3 §4-2 案 A 후속).
- sensor 7종 hook 등록 = harness 영역.
- **CC-4 Phase 1 완료 = 운영 회계 정합 즉시 위험 0건** — 신·구 분열 해소 완료. Phase 2·3은 정합·청결 보강.

---

## 10. rollback 단위

- 각 sub-task는 git commit 단위 — P1·L2·I1·F1 별 commit 권장. 실패 시 해당 commit revert.
- **Phase 1** (코드 변경만): tsc/jest 실패 = 즉시 해당 commit 단위 롤백. DB 스키마 비변경 → 백업 불요.
- **Phase 2** (작은 마이그레이션): pg_dump 백업 필수. dev apply → 회귀 1주 → prod apply. 실패 시 rename 역방향 마이그레이션 또는 백업 복원.
- **Phase 3** (큰 마이그레이션): pg_dump 백업 필수. DROP은 비가역 → 백업 복원만 롤백 가능. 사전 검증 게이트 §5-1 통과 의무.
- HIGH-1 Case A 시: H2a~H2g commit 단위 별도 — Case C로 회귀 시 H2 commits 일괄 revert.

---

## 11. 변경 이력

- 2026-05-21: 본 계획 신설. CC-4 폐기 정리(S0 5 + Phase 1 구 메서드 제거 8 + 신·구 분열 해소 6 + 통합 spec 2 + 마무리 7 = 24 sub-task / Phase 2 골격 7 / Phase 3 골격 10 = 총 42 sub-task — Case A 채택 시 H2a~H2g 7 추가) writing-plans 양식 분해. 분할 권고 = **옵션 Z (3 Phase)** — Phase 1 즉시 착수(마이그레이션 0) / Phase 2 작은 rename(P1 머지 + ≥1 sprint 후) / Phase 3 DROP + CreditLog 폐기(P1·P2 머지 + ≥1 sprint 후 — Cursor 반면교사). HIGH-1 案 B 권고 = **Case C (별도 sprint 이월)** — Phase 1 후 또는 CC-5와 병렬. 사용자 결정 게이트 1건(§6 HIGH-1 案 B). cost-accountant 게이트 불요 (신규 AI 0건). visual-canon-keeper 불요 (server 한정). web 핸드오프 1건(Phase 3 P3j docs sync). harness 핸드오프 1건(F1f sensor 7종 hook 등록). 코드 변경 0건 — 계획 수립 전용.

---

## 12. 미확인 / 추정 금지 명시

| 항목 | 상태 | 해소 시점 |
|---|---|---|
| admin·discovery 구 `creditRepo` 호출처 file:line | **확인** — 본 계획 작성 중 grep(`admin.usecase:35,177` + `discovery.usecase:66`). S0a 현행 재실측 | S0a |
| `getGiftRanking` 호출 사슬 + 신 위임 정합 | **확인** — 본 계획 작성 중 Read(`credit.usecase:174~178` ledger 위임 / `discovery.usecase:66` `creditRepo` 직접 호출 잔존). S0b 현행 재실측 | S0b |
| `Payment.credits` / `RefundLog.credits`·`deficitCredits` 사용처 | **부분 확인** — 본 계획 작성 중 grep으로 다수 file:line + 코드 주석에서 이미 pt 의미 재해석 박제 확인 (shared-contracts §30). S0c 전수 재실측 | S0c |
| `Author.credits` 읽기/쓰기 전수 | **부분 확인** — 본 계획 작성 중 grep으로 spec 다수 + refund-payment.usecase:124-125 + credit.usecase:46-65 구 메서드. S0d 전수 재실측 | S0d |
| `CreditLog` 사용처 전수 | **부분 확인** — 본 계획 작성 중 grep으로 schema.prisma + prisma-credit.repository + credit.usecase + spec 다수. S0e 전수 재실측 | S0e |
| HIGH-1 案 B Case A/B/C 결정 | **사용자 결정 대기** — §2 게이트, Case C 권고 | §6 게이트 (Phase 1 착수 전) |
| `Payment.credits` / `RefundLog.credits`·`deficitCredits` rename 결정 | **사용자 결정 대기** — §4-1 게이트, `Payment.credits` (a) rename 권고 / `RefundLog` (b) 의미 유지 권고 | Phase 2 착수 전 |
| novel-analysis.usecase의 `adjustCredits` 폴백 제거 가능 여부 (chargePoints 항상 주입) | **미확인** — P1h sub-task에서 chargePoints 주입 보장 검증 | P1h |
| sub-task 시간 추산 | 상대 추산 — 실측 아님. 본 계획은 분해 단위, 실제 시간은 server 실행 시 확정 | — |

> 본 계획은 코드 변경 0건 — 순수 계획 수립. 모든 file:line은 CREDIT_CORE_DIAGNOSIS 진단 리포트 + CC-1~CC-3 progress + 본 계획 작성 중 실제 Read(`credit.usecase.ts`/`admin.usecase.ts`/`schema.prisma`/`shared-contracts.md §30`) + grep(`creditRepo\.*` / `Payment\.credits` / `Author\.credits` / `CreditLog`) 기반. 미확인은 §12에 명시 — 추정 0건.
