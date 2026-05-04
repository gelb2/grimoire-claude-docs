# EMAIL_INTEGRITY_PLAN — 이메일 시스템 정합화 계획 (2026-05-04 #10_7)

> **계기**: 사용자 지적 (2026-05-04) — 이전 Claude가 사용자 이메일을 `@grimoire.app` (실존하지 않는 도메인)으로 마음대로 박제. DB 스키마부터 정리 + 백필 + 인증/소셜로그인 정책 전수검사 후 결제 프로세스 고도화와 통합 진행.
>
> **정본 위치**: 본 파일이 이메일 시스템 전수 정본. PAYMENT_SYSTEM_PLAN.md의 PAY-P1-2 (결제 알림 이메일)는 본 정본 EMAIL-P1-1 (이메일 인증) 완료 후 진입 의존성.

---

## 0. TL;DR — 핵심 결론

1. **`@grimoire.app` 박제 11개 위치 약 40회 출현** — 시드 스크립트 4개 + E2E 픽스처 2개 + 문서 4곳 + 운영 DB 추정 12~15 row.
2. **이메일 인증 (verification) 시스템 전무** — Author.email @unique 제약만 있음, emailVerified 필드 없음, 가입 즉시 활성.
3. **OAuth Google만 구현** — Kakao/Naver 미구현. provider 이메일 미제공 시 처리 없음.
4. **결제 영역 이메일 알림 전무** — 결제 성공/실패/환불 통보 부재. PAY-P1-2 정의되어 있으나 EMAIL-P1-1 인증 시스템 선행 필수.
5. **운영 DB SQL 직접 실행은 사용자 영역** — destructive action (12~15 row 삭제)이므로 자동화 금지. 코드 자율 진행은 시드 스크립트 + E2E 픽스처 + 문서 정리까지.

---

## 1. 현재 갭 정밀 인벤토리 (전수검사 결과)

### 1-1. `@grimoire.app` 박제 위치 11개 (Explore 위임 결과 박제)

| 파일 | 라인 | 박제 | 구분 | 영향 | 정리 방식 |
|------|------|------|------|------|----------|
| grimoire-server/scripts/seed-all.ts | 98 | `deerdevil@grimoire.app` | (a) 시드 | 운영 DB | 자율 치환 |
| grimoire-server/scripts/seed-all.ts | 111~146 | 10명 작가 `*@grimoire.app` | (a) 시드 | 운영 DB | 자율 치환 |
| grimoire-server/scripts/seed-themes.ts | 76, 112, 138, 164, 190, 216, 242, 268, 294, 320, 346 | 작가별 이메일 | (a) 시드 | 운영 DB | 자율 치환 |
| grimoire-server/scripts/seed-more-classics.ts | 49, 156, 370, 587, 672, 743, 814, 921, 992 | 작가별 이메일 | (a) 시드 | 운영 DB | 자율 치환 |
| grimoire-server/scripts/seed-deerdevil.ts | 126, 140 | `deerdevil@grimoire.app` | (a) 시드 | 운영 DB | 자율 치환 |
| grimoire-server/scripts/db-sync.ts | 17 | 도메인 예시 | (c) 문서 | 문서 | 자율 치환 |
| grimoire-server/TODO.md | 37 | `test@grimoire.app` 언급 | (c) 문서 | 문서 | 자율 정리 |
| grimoire-server/HANDOVER.md | 64, 104, 208 | `deerdevil@grimoire.app` 회귀 사례 | (c) 문서 | 문서 | 자율 정리 |
| grimoire-web/e2e/dashboard.spec.ts | 12, 23, 35, 47 | `deerdevil@grimoire.app` | (b) E2E | 테스트 | 자율 환경변수화 |
| grimoire-web/e2e/auth.spec.ts | 43 | `test@grimoire.app` | (b) E2E | 테스트 | 자율 환경변수화 |
| grimoire-web/TODO.md | 17 | `test@grimoire.app` 언급 | (c) 문서 | 문서 | 자율 정리 |

**합계**:
- (a) 시드 35회 → **운영 DB 약 12~15명 작가 row 박제 추정** (사용자 영역 SQL 정리)
- (b) E2E 5회 → 테스트 픽스처 환경변수화 (자율)
- (c) 문서 4곳 → 자율 정리

### 1-2. 회원가입/소셜로그인/이메일 인증 정책 갭 5건

| # | 영역 | 현재 | 갭 | 권장 | 우선순위 |
|---|------|------|----|------|---------|
| 1 | 회원가입 이메일 검증 | 중복만 체크 | 형식 validation 없음 (RFC 5321) | DTO `@IsEmail()` + Regex 추가 | P1 |
| 2 | 이메일 인증 (verification) | **없음** | 가입 즉시 활성 | EmailVerification 모델 신설 + 토큰 발송 | **P1 필수** |
| 3 | OAuth provider 확장 | Google만 (`auth.usecase.ts` payload.email) | Kakao/Naver 미구현 + provider 이메일 미제공 시 처리 부재 | Kakao/Naver 콜백 추가 + 미제공 prompt | P1 |
| 4 | 이메일 도메인 차단 | 없음 | disposable 도메인 (test.com 등) 허용 | 블랙리스트 또는 화이트리스트 | P2 |
| 5 | 동일 이메일 일반/OAuth 중복 | 자동 링크 (auth.usecase.ts:100) | ✅ 정상 | 유지 | — |

### 1-3. 결제 영역 이메일 사용처 5 시점

| 시점 | 현재 | 갭 | 정본 참조 |
|------|------|-----|----------|
| 결제 시작 (POST /payments/initiate) | customEmail metadata 미전달 | 사용자 이메일 Polar Checkout으로 전달 안 함 | PaymentUseCase:31-46 |
| 결제 성공 (webhook success) | 영수증/확인 메일 없음 | 결제 성공 알림 발송 부재 | PaymentUseCase:95-98 |
| 결제 실패 (webhook failed/error) | 실패 알림 없음 | retry 안내 메일 부재 | PaymentUseCase:100-112 |
| 환불 (webhook refunded) | RefundLog 박제만 (PAY-P1-1 완료) | 환불 확인 메일 부재 | PAY-P1-1 RefundLog |
| 크레딧 부여 (admin grant) | AdminAuditLog 박제만 | 사용자 통보 없음 | admin.usecase.ts |

→ PAY-P1-2 (결제 알림 이메일)는 **EMAIL-P1-1 (이메일 인증) + 외부 API 결정 + 사용자 절대 규정 0-1 해제 후 진입**.

---

## 2. 우선순위별 구현 계획

### 2-1. EMAIL-P0 (즉시, 코드 자율 + 사용자 SQL)

#### EMAIL-P0-1: 시드 스크립트 + 문서 + E2E 픽스처 정리 (자율 영역)

**목표**: 코드 박제에서 `@grimoire.app` 0건 강제. 다시 seed 실행 시 DB 재오염 방지.

**산출물**:
- `grimoire-server/scripts/seed-all.ts` 11회 치환 → `test-{slug}@example.com` 패턴 (RFC 2606 reserved)
- `grimoire-server/scripts/seed-themes.ts` 11회 치환
- `grimoire-server/scripts/seed-more-classics.ts` 9회 치환
- `grimoire-server/scripts/seed-deerdevil.ts` 2회 치환
- `grimoire-server/scripts/db-sync.ts:17` 예시 변경
- `grimoire-server/TODO.md`, `HANDOVER.md` 문서 정리
- `grimoire-web/e2e/dashboard.spec.ts` + `auth.spec.ts` `process.env.E2E_AUTHOR_EMAIL` 환경변수화
- `grimoire-web/TODO.md` 문서 정리
- `.env.example` 양 레포 `E2E_AUTHOR_EMAIL=test-deerdevil@example.com` 추가
- `eval/tasks/regression-58-no-grimoire-app-leak.json` 신설 (sensor 회귀 차단)
- `.claude/scripts/sensor-fake-email-leak.sh` 신설 (`grep -rn '@grimoire\.app' grimoire-server/scripts grimoire-web/e2e` → 0건 강제)

**검증 게이트**:
- `grep -rn '@grimoire\.app' grimoire-server grimoire-web` → 0건 (또는 의도된 문서 박제만)
- jest seed unit 또는 dry-run PASS
- E2E 환경변수 주입 검증

**규모**: ~1.5h (multi-edit + sensor 신설)

#### EMAIL-P0-2: 운영 DB 백필 SQL (사용자 영역)

> **사용자 영역**: destructive action (12~15 row 삭제)이므로 메인 Claude 자율 진행 금지. SQL 박제만 박제.

**산출물 (SQL 안내문, 사용자 직접 실행)**:
```sql
-- 1단계: 백업 (필수)
CREATE TABLE authors_backup_20260505 AS
  SELECT * FROM authors WHERE email LIKE '%@grimoire.app%';

-- 2단계: 영향 row 확인
SELECT id, slug, email FROM authors WHERE email LIKE '%@grimoire.app%';

-- 3단계: 종속 데이터 정리 (FK cascade 정의 시 자동, 미정의 시 수동)
DELETE FROM refresh_tokens WHERE author_id IN (SELECT id FROM authors WHERE email LIKE '%@grimoire.app%');
DELETE FROM social_accounts WHERE author_id IN (SELECT id FROM authors WHERE email LIKE '%@grimoire.app%');
-- (Episode/Theme/Work 등은 사용자가 보존 결정 — 향후 deerdevil 재가입 시 데이터 이관 정책)

-- 4단계: 작가 row 삭제
DELETE FROM authors WHERE email LIKE '%@grimoire.app%';

-- 5단계: 회귀 검증
SELECT COUNT(*) FROM authors WHERE email LIKE '%@grimoire.app%';  -- 0 강제
```

**환경**: dev → production 순차 실행 (사용자 절대 규정 + .githooks/AGENTS.md §1)

**규모**: 사용자 30분 (백업 + dry-run + 실행 + 회귀)

### 2-2. EMAIL-P1 (단기, ~3 sprint)

#### EMAIL-P1-1: 이메일 인증 시스템 (회원가입 시점)

**목표**: 가입 후 이메일 인증 토큰 링크 발송. 인증 미완 사용자는 결제/소셜 활동 권한 제한 (정책 결정).

**산출물**:
- DB: `EmailVerification { id, authorId, token(@unique), expireAt, verifiedAt, createdAt }`
- DB: `Author.emailVerified Boolean @default(false)` + `emailVerifiedAt DateTime?`
- 마이그레이션: `add_email_verification` (기존 row는 `emailVerified=true` default — 운영 충돌 회피)
- `application/auth/email-verification.usecase.ts` 신설 (request + verify)
- `auth.usecase.ts` 가입 시점에 `emailVerificationUseCase.request()` 호출
- 토큰 만료: 24h
- 외부 API: 이메일 발송 (사용자 절대 규정 0-1 충돌 — Resend/SendGrid/Postmark 결정 영역) — **EMAIL-P1-3과 통합**
- spec: 토큰 발급 + 만료 + 검증 + 재발송 검증

**검증 게이트**:
- jest spec PASS
- eval task `regression-59-email-verification`
- sensor-email-verification (인증 미완 → 권한 제한 검증)

**규모**: ~12~16h (사용자 절대 규정 0-1 해제 + 외부 API 결정 후 진입)

**의존**: EMAIL-P1-3 외부 API 결정 (Resend/SendGrid/Postmark)

#### EMAIL-P1-2: OAuth Kakao/Naver 확장

**목표**: 한국 사용자 대다수 (Kakao/Naver 점유율 > 60%) OAuth 로그인 지원.

**산출물**:
- `adapter/inbound/auth/oauth/kakao.controller.ts` 신설
- `adapter/inbound/auth/oauth/naver.controller.ts` 신설
- `auth.usecase.ts` provider별 분기 추가
- provider 이메일 미제공 시: 사용자 입력 prompt + EmailVerification 강제
- 환경변수: `KAKAO_CLIENT_ID/SECRET`, `NAVER_CLIENT_ID/SECRET` (KakaoDeveloper + NaverDeveloper 콘솔 등록 필요)
- spec: provider별 mock callback + email merge 검증

**검증 게이트**:
- jest spec PASS
- eval task `regression-60-oauth-kakao-naver`
- BFF 프록시 정합 (P14)

**규모**: ~8h

**의존**: 사용자 영역 (Kakao/Naver Developer Console 등록)

#### EMAIL-P1-3: 결제 이메일 알림 (PAY-P1-2 흡수)

**목표**: 결제 성공/실패/환불 시 사용자 이메일 통보. EMAIL-P1-1 인증 시스템과 동일 외부 API 활용.

**산출물**:
- 외부 API 결정 (사용자 절대 규정 0-1 해제 영역):
  - Resend ($0/100일 무료, $20/월 50K) — 가장 간결, React Email 통합
  - SendGrid ($19.95/월 50K) — 한국어 템플릿 검증 풍부
  - Postmark ($15/월 10K) — 트랜잭션 메일 특화 (deliverability 최고)
  - 추천: **Resend** (cost-accountant 위임 후 마진 영향 검증)
- `application/notification/email.service.ts` 신설 (template + send 분리)
- 템플릿 5종: 인증 / 결제 성공 / 결제 실패 / 환불 / 가입 환영
- `payment.usecase.processWebhook` + refund-payment.usecase에서 이메일 큐 push
- 큐 처리: NestJS @Cron 또는 Bull (CERTI_PROJ DLQ 패턴 차용 후보)
- spec: mock 이메일 서비스 + 큐 처리 + 실패 retry 검증

**검증 게이트**:
- jest spec PASS
- cost-accountant: 월 비용 / 마진 영향 검증 (§0 게이트)
- eval task `regression-61-payment-email-notification`

**규모**: ~16~20h

**의존**: 사용자 절대 규정 0-1 해제 + 외부 API 사용자 결정

### 2-3. EMAIL-P2 (장기)

#### EMAIL-P2-1: Disposable 도메인 차단

**목표**: 임시 메일 (test.com, 10minutemail.com 등) 가입 차단. 스팸 계정 방지.

**산출물**:
- `application/auth/email-domain-validator.ts` 신설
- 블랙리스트 (npm `disposable-email-domains` 활용 또는 자체 DB)
- `auth.usecase.signup` validate 호출

**규모**: ~4h

#### EMAIL-P2-2: Bounce Webhook 처리

**목표**: 이메일 발송 실패 (반송) 처리. 잘못된 이메일 주소 자동 비활성화.

**산출물**:
- 이메일 SaaS의 bounce webhook endpoint 박제
- `Author.emailStatus enum('active', 'bounced', 'complained')` 컬럼 추가
- bounce 후 EmailVerification 재요청 권유

**규모**: ~6h

**의존**: EMAIL-P1-3 외부 API 결정

---

## 3. 권장 새 DB 모델

```prisma
model Author {
  // ... 기존 필드
  email             String   @unique
  emailVerified     Boolean  @default(false) @map("email_verified")
  emailVerifiedAt   DateTime? @map("email_verified_at") @db.Timestamptz(3)
  emailStatus       String   @default("active") @map("email_status")  // active | bounced | complained
  emailVerifications EmailVerification[]

  @@index([emailVerified])
  @@index([emailStatus])
}

model EmailVerification {
  id          String   @id @default(uuid())
  authorId    String   @map("author_id")
  token       String   @unique
  expireAt    DateTime @map("expire_at") @db.Timestamptz(3)
  verifiedAt  DateTime? @map("verified_at") @db.Timestamptz(3)
  createdAt   DateTime @default(now()) @map("created_at") @db.Timestamptz(3)
  author      Author   @relation(fields: [authorId], references: [id], onDelete: Cascade)

  @@index([authorId])
  @@index([expireAt])
  @@map("email_verifications")
}
```

마이그레이션 무중단:
- 기존 row `emailVerified=true` default (운영 충돌 회피, 사용자 영역 SQL과 동시 진행)
- EMAIL-P0-2 백필 SQL 후 실행

---

## 4. 권장 검증 게이트 (sensor 신설)

| Sensor | 목적 | 발동 |
|--------|------|------|
| sensor-fake-email-leak | `@grimoire.app` 코드 박제 0건 강제 | pre-commit + pre-push |
| sensor-email-verification | 인증 미완 사용자 권한 제한 회귀 차단 | pre-commit + 정기 |
| sensor-email-domain-validation | DTO 형식 + 블랙리스트 회귀 차단 | pre-commit + 정기 |
| sensor-payment-email-notification | 결제 webhook 이메일 큐 push 회귀 차단 | pre-commit + 정기 |

---

## 5. cost-accountant 사전 검증 항목 (§0 게이트)

| 항목 | 비용 추정 (예) | 마진 영향 |
|------|--------------|----------|
| Resend Pro ($20/월 50K 메일) | $20/월 + Polar 5% | AI 호출 1회당 추가 마진 영향 거의 0 |
| SendGrid ($19.95/월 50K) | 비슷 | 비슷 |
| Postmark ($15/월 10K) | 더 저렴 (소규모 적합) | 비슷 |

→ **EMAIL-P1-3 진입 전 cost-accountant 위임 필수** (`docs/ai-cost-table.md` 갱신 + 마진 ≥3배 검증).

---

## 6. 사용자 영역 (자율 진행 금지)

1. **EMAIL-P0-2 운영 DB SQL 직접 실행** — destructive (12~15 row 삭제). dev → production 순차.
2. **EMAIL-P1-3 외부 API 결정** — 사용자 절대 규정 0-1 (외부 Anthropic API 신규 의존 영구 보류) 영향. 이메일 SaaS는 Anthropic 외이지만 동일 정책 적용 가능. 사용자 명시적 해제 필요.
3. **EMAIL-P1-2 OAuth Console 등록** — Kakao/Naver Developer Console 박제 + redirect URI 등록 (사용자 계정).
4. **이메일 인증 정책 결정** — 인증 미완 사용자 권한 제한 범위 (결제 차단? 작품 게시 차단? 단순 경고?).

---

## 7. 메인 자율 진행 가능 항목 (사용자 명시 없이)

1. **EMAIL-P0-1**: 시드 스크립트 + E2E 픽스처 + 문서 정리 + sensor-fake-email-leak 신설 + regression-58 — 코드 자율.
2. **EMAIL-P1-1 DB 모델 + 마이그레이션 + UseCase + spec** (외부 API 호출 stub 처리) — 코드 자율, 외부 API 통합만 사용자 결정.
3. **EMAIL-P2-1 Disposable 도메인 차단** — npm 패키지 + validator + spec, 외부 API 0.

---

## 8. 결제 시스템과의 통합 게이트

| 항목 | 의존 | 진입 게이트 |
|------|------|----------|
| PAY-P1-3 결제 실패 retry | 독립 | 즉시 가능 (외부 API 0) |
| PAY-P1-2 결제 알림 이메일 | EMAIL-P1-1 + EMAIL-P1-3 외부 API 결정 | 외부 API 사용자 결정 후 |
| PAY-P1-1 환불 이메일 통보 (확장) | EMAIL-P1-3 | 외부 API 사용자 결정 후 |
| PAY-P0-3 운영자 수동 지급 통보 (확장) | EMAIL-P1-3 | 외부 API 사용자 결정 후 |

---

## 9. 변경 이력

- 2026-05-04 #10_7 (5): 본 plan 신설. CERTI_PROJ 추가 리서치 (Explore) + 이메일 갭 전수검사 (Explore) 결과 박제. EMAIL-P0/P1/P2 우선순위 + 11 위치 표 + 백필 4 Phase + Sprint 분할 + cost-accountant 게이트 박제.

---

## 10. 참조 (Grimoire 현재 코드)

- `grimoire-server/prisma/schema.prisma:15` — Author.email @unique 제약
- `grimoire-server/src/application/auth/auth.usecase.ts` — 회원가입 + OAuth callback
- `grimoire-server/src/application/auth/auth.usecase.ts:38-41` — SignupHistory 2회 제한
- `grimoire-server/src/application/auth/auth.usecase.ts:100` — 일반 가입 후 OAuth 자동 링크
- `grimoire-server/src/application/payment/payment.usecase.ts:31-46` — initiatePayment (이메일 metadata 미전달)
- `grimoire-server/src/application/payment/payment.usecase.ts:95-98` — webhook success (이메일 알림 없음)
- `grimoire-server/scripts/seed-all.ts:98-156` — 가짜 이메일 시드 박제
- `grimoire-web/src/app/(auth)/signup/page.tsx` — 가입 폼 (이메일 검증 추가 진입점)
- `grimoire-web/e2e/dashboard.spec.ts:12-47` + `auth.spec.ts:43` — E2E 픽스처
