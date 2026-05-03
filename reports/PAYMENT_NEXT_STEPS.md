# PAYMENT_NEXT_STEPS — 결제 시스템 진행 현황 + 다음 단계 계획 (2026-05-04 #10_7)

> **트리거**: 사용자 명시 — "어디까지 구현했고 다음엔 뭘 해야 하는지 전수검사 + 계획"
> **정본 참조**: `research/PAYMENT_SYSTEM_PLAN.md` (12 섹션, P0/P1/P2/P3 분류)
> **세션 진행 박제**: `memory/project_session_20260503_2.md §PAY-P0-1/2/3`

---

## 0. 한 줄 결론

**PAY-P0 (운영 안전망 3건) 100% 완료** — develop push 완료, dev 배포 + main 머지는 사용자 영역. **PAY-P1 4건 (~10h)** 다음 권고. 옵션 분기점은 §3 박제.

---

## 1. 진행 현황 (실측 — git log 기준)

### 1-1. 완료 (3 레포 develop 박제 + push)

| 항목 | server | web | claude-docs |
|------|--------|-----|-------------|
| **PAY-P0-1** webhook event_id 멱등성 | `8c13103` | `9c4b409` (docs sync) | `86f7487` + `06de6c6` (drift) |
| **PAY-P0-2** PG↔DB 정합성 검증 cron | `8e9e02e` | `849f771` (docs sync) | `790e692` |
| **PAY-P0-3** 운영자 수동 크레딧 UI | (변경 0) | `af3f04c` | `841e704` |
| **hook 보강** (사용자 지적 후) | `1f43b05` | `dd3717b` | (pre-commit 기존 박제) |

### 1-2. 인벤토리 변동
- Sensors **25 → 28** (+3): `sensor-payment-idempotency` / `sensor-payment-reconciliation` / `sensor-admin-credit-ui`
- Eval regression **51 → 54** (+3 회귀 차단)
- shared-contracts **§1~10 → §1~12** (+2 인터페이스: WebhookEventIdempotency + PaymentReconciliation)
- jest server: 494 → **532** (+38 신규 spec)
- vitest web: 125 → **140** (+15 신규 spec)
- DB 모델: WebhookEvent + ReconciliationCheckpoint (2 테이블 신설)
- pre-commit/pre-push hook: 3 레포 모두 sensor-adversarial 자동 발동 강제

### 1-3. 검증 결과 (commit 기준)
- jest server 532/532 PASS
- vitest web 140/140 PASS
- eval-runner 54/54 PASS (가중점수 1.0)
- sensor-adversarial 16~17 PASS / 2~3 WARN ACCEPTABLE / 0 FAIL (시점별)
- pre-push hook 3 레포 모두 통과

### 1-4. 외부 프로젝트 정보 leak (2026-05-04 추가 점검)
- **leak 0건 확인** — server/web 코드/주석/마이그레이션/CHANGELOG 정리 완료 (별도 commit 예정)
- 외부 인용은 `research/PAYMENT_SYSTEM_PLAN.md`에만 의도된 file:line 인용 박제 (claude-docs 정본)

---

## 2. 사용자 영역 (PAY-P0 잔존)

### 2-1. main per-repo 머지 (사용자 명시 후)
- "claude-docs main 머지" / "server main 머지" / "web main 머지" 형식
- 현재 상태: 3 레포 모두 develop만 push, main 미머지

### 2-2. dev 환경 검증 (배포 후 사용자 직접 확인)
| 항목 | 검증 방법 |
|------|---------|
| PAY-P0-1 webhook 멱등성 | dev에 `PUBLIC_API_BASE_URL` env 추가 + Polar 측 동일 event_id 두 번 전송 시뮬 (Polar dashboard 또는 stub) |
| PAY-P0-2 PG↔DB cron | Container Apps 로그 `[PaymentReconciliationJob] 시작 ... 완료` 1회 박제 (cron 10분 후) |
| PAY-P0-3 admin UI | admin 화면 클릭 (검색 → 선택 → amount+reason → confirm → toast + DB credit_logs row 박제) |

### 2-3. prod 배포
```bash
# server
cd grimoire-server
npx prisma migrate deploy   # webhook_events + reconciliation_checkpoints 무중단 추가
make deploy-prod
# web
cd grimoire-web
make deploy-prod
```

---

## 3. 다음 단계 옵션 (사용자 결정)

### 옵션 A — PAY-P1 진입 (운영 안정 보강, ~10h)

**PAY-P1-1: Refund 정밀 처리 (~2h)** ← 가장 시급
- 현재 갭: webhook에서 status='refunded' 마킹만, 크레딧 환수 트랜잭션 부재 → 환불 시 사용자가 크레딧 그대로 보유 (적자 위험)
- 산출물: `refund-payment.usecase.ts` + `RefundLog` 모델 + spec + sensor-refund-atomicity
- 멀티에이전트: planner + server + qa (cost-accountant/VCK 면제)

**PAY-P1-2: 결제 알림 이메일 (~3h)**
- 외부 API (Resend / SendGrid / Postmark) 도입 필요 → **cost-accountant 사전 위임 필수**
- 산출물: `email.service.ts` + 결제 성공/실패/환불 템플릿 3종 + payment.usecase 분기
- 사용자 결정: 외부 API 선택 + 월 ₩50K 한도 박제 적용

**PAY-P1-3: 결제 실패 retry 정책 (~2h)**
- 현재 갭: 사용자 재시도 시 새 Payment row 폭주 (orphan pending 누적)
- 산출물: 24h 이내 같은 (authorId, productId, status='pending') 재사용 + 만료 cron (`payment-cleanup.job.ts`)
- 멀티에이전트: planner + server + qa

**PAY-P1-4: Polar Subscription Product (작업 A 결합, ~5~8h)**
- 작업 A (구독제 요금제)와 통합 진행 — 기획 단계 (researcher + cost-accountant + planner) 선행 필수
- 사용자 결정 영역 (등급 구조 + 가격 + DB 스키마)

### 옵션 B — 핸드오버 시퀀스 작업 D/E (~3~4h)

**작업 D: 작품별 테마 배정 UI (P2-#16, ~2h)**
- 도메인: web only (서버 API 이미 존재)
- 발동: planner + visual-canon-keeper + web + qa

**작업 E: 4-12 조회수 급락 원인 조사 (P1-#6, ~1~2h)**
- 도메인: server (DB + 운영 로그)
- 발동: production-bug-triage skill + server + qa
- 사용자 협력: Azure / DB 자격 증명

### 옵션 C — main 머지 정리 + 휴식

3 레포 main 머지 (per-repo 명시) + dev 환경 검증 + prod 배포 → 사용자 휴식

### 옵션 D — 작업 A (구독제 요금제, ~5~8h)

큰 작업. 기획 단계 (researcher + cost-accountant + planner Draft) → 사용자 승인 → 구현 (server + web + qa) → 시스템 전체 발동

---

## 4. 권고 우선순위 (PAYMENT_SYSTEM_PLAN.md §8-2 정합)

### 권고 옵션 B (운영 안정 우선) → 그러나 사용자가 PAY-P0 이미 완료시켰음

따라서 현재 시점:
1. **PAY-P1-1 (Refund 환수 트랜잭션)** ← 즉시 시급 (적자 위험 차단)
2. **작업 D + E** (핸드오버 시퀀스 마무리, ~3~4h)
3. **PAY-P1-2 + PAY-P1-3** (운영 안정 보강)
4. **작업 A + PAY-P1-4** (구독제 요금제 통합 — 큰 작업)
5. **PAY-P2** (장기 안정성)

---

## 5. 권고 (메인 의견)

**즉시 진행 권고**: **PAY-P1-1 Refund 정밀 처리** (~2h)
- 가장 시급한 갭 (적자 위험 차단)
- 외부 API 무관 (cost-accountant 면제)
- PAY-P0와 동일 패턴 (planner → server → qa) — 검증 흐름 정합

**대안**: 사용자가 휴식 우선시 시 → main 머지 정리 + 휴식

---

## 6. 사용자 결정 대기

| 결정 | 선택지 |
|------|--------|
| 다음 트랙 | PAY-P1-1 / 작업 D / 작업 E / main 머지 / 휴식 |
| PAY-P1-2 외부 API | Resend / SendGrid / Postmark / 보류 |
| 작업 A 진입 시점 | 즉시 / PAY-P1 후 / 보류 |
| dev 검증 시점 | 즉시 / 사용자 자율 |

---

## 7. 변경 이력

- 2026-05-04 #10_7: 본 문서 신설 — PAY-P0 100% 종료 + 다음 단계 4 옵션 + 메인 권고 박제. CERTI_PROJ leak 4건 제거 commit 별도.
