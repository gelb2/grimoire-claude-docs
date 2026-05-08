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
- 2026-05-05 #10_7 (6): §11 이메일 SaaS 결정 사유 박제 + §12 EmailServicePort 캡슐화 인터페이스 설계 + §13 EMAIL-P0-3 slug 로그인 마이그레이션 + 백필 계획 추가. EmailServicePort + NullAdapter stub 박제 (외부 API 신규 의존 0건 강제, 결정 후 ResendAdapter/SesAdapter 분기).

---

## 11. 이메일 SaaS 결정 사유 (사용자 결정 영역, 2026-05-05 추가)

### 11-1. 결정 게이트

본 결정은 **사용자 절대 규정 0-1 (외부 Anthropic API 신규 의존 영구 보류)** 영역과 충돌 가능성:
- 0-1 정책 원문: "외부 **Anthropic** API 신규 의존 영구 보류"
- 이메일 SaaS는 Anthropic 외 카테고리 → 엄격 해석 시 면제
- 사용자 의도가 "외부 종량제 API 일반 보류"이면 동일 정책 적용 → **사용자 명시적 결정 권장**

### 11-2. 4 SaaS 비교 + 추정 비용

| 서비스 | 무료 한도 | 유료 (소규모) | 특징 | Grimoire 적합도 |
|---|---|---|---|---|
| **AWS SES** | 200통/일 (EC2 발신 시) | $0.10/1000통 (≈ ₩140/1000) | 가장 저렴, 직접 운영, deliverability 우수 | ★★★★★ |
| **Resend** | 100통/일 (3K/월) | $20/월 50K (≈ ₩28K) | 가장 간결, React Email 통합, MoR | ★★★★ |
| **SendGrid (Twilio)** | 100통/일 (3K/월) | $19.95/월 50K | 한국어 템플릿 풍부, 운영 안정 | ★★★ |
| **Postmark** | 100통/월 | $15/월 10K (≈ ₩21K) | deliverability 1위, 트랜잭션 특화 | ★★★ |
| **NHN Cloud (Toast)** | 1000통/월 | 건당 ₩15-30 | 한국 호스팅, KISA 인증 | ★★ (소규모 비싸) |

### 11-3. Grimoire 운영 규모 추정

| 발송 영역 | 일 추정 (가입 100명/일 가정) |
|---|---|
| 가입 인증 메일 | ~100통 |
| 비번 초기화 | ~30통 |
| 결제 성공/실패/환불 (PAY-P1-2 흡수) | ~50통 |
| **합계** | **~180통/일 = ~5400통/월** |

→ 무료 한도 (Resend/SendGrid 100통/일) **초과** → 유료 진입 또는 AWS SES 직접 운영.

### 11-4. 비용 시뮬

| 시나리오 | 월 비용 | 마진 영향 (가입 100명/월 = 결제 추정 30건) |
|---|---|---|
| **AWS SES** (5K/월) | **~$0.50 ≈ ₩700** | 결제 1건당 ~₩23 (무시 가능) |
| **Resend Pro** (50K/월) | $20 ≈ ₩28K | 결제 1건당 ~₩930 |
| **NHN Cloud** (5K/월) | ~₩100K | 결제 1건당 ~₩3,300 (❌ 비싸) |
| **Postmark** (10K/월) | $15 ≈ ₩21K | 결제 1건당 ~₩700 |

### 11-5. 추천 (사용자 결정 권장 영역)

1. **1순위: AWS SES** — 비용 최저 + Hexagonal 어댑터 분리 + Azure Container Apps 정합 (Container Apps에서 SES 호출 가능)
2. **2순위: Resend** — 간결성 + React Email 템플릿 통합
3. **3순위: NullAdapter (외부 API 0건)** — 결정 보류 시 토큰만 발급, 발송은 logger.warn (개발 환경 정합)

### 11-6. 결정 후 진입 영역

사용자가 1택 결정 후:
- cost-accountant 위임 → `docs/ai-cost-table.md` 갱신 + 마진 ≥3배 검증 (§0 게이트)
- ResendAdapter / SesAdapter 본격 구현 (현재는 stub)
- EMAIL-P1-1 (이메일 인증 시스템) 진입 가능
- EMAIL-P1-3 (결제 이메일 알림 = PAY-P1-2 흡수) 진입 가능

---

## 12. EmailServicePort 캡슐화 인터페이스 설계 (2026-05-05 추가)

### 12-1. 설계 원칙

> **Provider 변경 비파괴 (Hexagonal)** — 사용자가 Resend / SES / Postmark 어느 것을 골라도 application layer 코드 변경 0건.

- `EmailServicePort` 도메인 인터페이스 (외부 SDK 의존 0건)
- `NullEmailAdapter` (default — 외부 API 0, logger.warn만)
- `ResendEmailAdapter` (외부 API stub — SDK 의존, 사용자 결정 후 활성화)
- `SesEmailAdapter` (외부 API stub — AWS SDK 의존, 사용자 결정 후 활성화)
- env `EMAIL_PROVIDER=null|resend|ses` 분기 (app.module DI)

### 12-2. 인터페이스 시그니처

```typescript
// grimoire-server/src/domain/port/outbound/email-service.port.ts
export interface EmailServicePort {
  /** 이메일 인증 토큰 발송 (가입/이메일 변경 시 호출) */
  sendVerificationEmail(input: {
    to: string;
    token: string;
    displayName?: string;
    expireAt: Date;
  }): Promise<{ messageId: string | null; provider: string }>

  /** 비밀번호 초기화 토큰 발송 */
  sendPasswordResetEmail(input: {
    to: string;
    token: string;
    displayName?: string;
    expireAt: Date;
  }): Promise<{ messageId: string | null; provider: string }>

  /** 결제 알림 (성공/실패/환불) — PAY-P1-2 흡수 */
  sendPaymentNotification(input: {
    to: string;
    type: 'payment_success' | 'payment_failed' | 'payment_refunded';
    displayName?: string;
    payload: Record<string, unknown>; // amount/credits/refundedAmount 등 type별 필드
  }): Promise<{ messageId: string | null; provider: string }>

  /** Provider 활성화 여부 (env 미박제 시 false → NullAdapter) */
  isEnabled(): boolean

  /** Provider 식별자 (로그/감사용) */
  getProviderName(): 'null' | 'resend' | 'ses' | 'sendgrid' | 'postmark'
}
```

### 12-3. 어댑터 매트릭스

| Adapter | 외부 API | isEnabled | 비용 | 활성화 조건 |
|---|---|---|---|---|
| NullEmailAdapter | 0건 (logger.warn만) | false | 0 | EMAIL_PROVIDER 미박제 또는 'null' |
| ResendEmailAdapter | Resend SDK | RESEND_API_KEY 박제 시 true | $20/월 50K | EMAIL_PROVIDER='resend' + 사용자 결정 |
| SesEmailAdapter | AWS SDK (@aws-sdk/client-ses) | AWS_ACCESS_KEY_ID + AWS_REGION 박제 시 true | ~$0.50/월 5K | EMAIL_PROVIDER='ses' + 사용자 결정 |
| SendgridEmailAdapter | (보류) | — | — | — |
| PostmarkEmailAdapter | (보류) | — | — | — |

### 12-4. DI 분기 (app.module.ts)

```typescript
{
  provide: 'EmailServicePort',
  useFactory: (config: ConfigService) => {
    const provider = config.get<string>('EMAIL_PROVIDER', 'null')
    switch (provider) {
      case 'resend': return new ResendEmailAdapter(config.get('RESEND_API_KEY'))
      case 'ses':    return new SesEmailAdapter(config.get('AWS_REGION'))
      case 'null':
      default:       return new NullEmailAdapter()
    }
  },
  inject: [ConfigService],
}
```

### 12-5. UseCase 호출 흐름 (provider 무관)

```typescript
// EmailVerificationUseCase
async request(authorId: string) {
  const token = randomUUID()
  const expireAt = new Date(Date.now() + 24 * 60 * 60 * 1000) // 24h
  await this.emailVerificationRepo.create({ authorId, token, expireAt })
  const author = await this.authorRepo.findById(authorId)

  // EmailServicePort 호출 — provider 무관
  const result = await this.emailService.sendVerificationEmail({
    to: author.email,
    token,
    displayName: author.name,
    expireAt,
  })

  this.logger.log(`Email sent — provider=${result.provider} messageId=${result.messageId}`)
}
```

→ Resend/SES 변경 시 위 코드 변경 0건. DI provide만 갱신.

### 12-6. 박제 위치

- `domain/port/outbound/email-service.port.ts` — 본 sprint에서 신설
- `adapter/outbound/email/null-email.adapter.ts` — 본 sprint 신설 (default)
- `adapter/outbound/email/resend-email.adapter.ts` — stub (사용자 결정 후 활성화)
- `adapter/outbound/email/ses-email.adapter.ts` — stub (사용자 결정 후 활성화)
- `app.module.ts` — DI factory 분기
- `.env.example` — `EMAIL_PROVIDER=null` (default)

---

## 13. EMAIL-P0-3 slug 로그인 마이그레이션 + 백필 계획 (2026-05-05 추가)

### 13-1. 배경

사용자 명시 (2026-05-05): 현재 로그인/회원가입은 `deerdevil@grimoire.app` 같은 가짜 이메일 박제. **앞으로 slug (`deerdevil`) + 비밀번호로 로그인/회원가입 가능**하도록 변경. 영향 영역 + 마이그레이션 무중단 + 백필 정합 보장.

### 13-2. 정밀 분석 결과 (Explore subagent 2026-05-05)

#### 8 영역별 file:line 표

| # | 영역 | file:line | 현재 동작 | Email 의존 | Slug 의존 |
|---|---|---|---|---|---|
| 1-DTO | LoginDto | `auth.dto.ts:21-28` | email + password 필수 | ✅ 강함 | ❌ |
| 1-UseCase | login() | `auth.usecase.ts:68-82` | `login({ email, password })` → `findByEmail` | ✅ 강함 | ❌ |
| 1-JWT | payload | `auth.usecase.ts:193-195` | `{ sub: author.id, slug, role }` | ⚠️ slug 포함 | ✅ 포함 |
| 1-Controller | logging | `auth.controller.ts:103,98,107` | AccessLog(action, email, authorId) | ✅ email 기록 | ❌ |
| 2-Signup DTO | RegisterDto | `auth.dto.ts:3-19` | email + password + name + slug 필수 | ✅ 필수 | ✅ 필수 |
| 2-Signup UseCase | signup() | `auth.usecase.ts:26-58` | findByEmail unique + findBySlug unique + signupHistory(email) | ✅ KEY | ✅ 강함 |
| 2-Signup Limit | SignupHistory | `auth.usecase.ts:38,58` | providerId=email (2회 제한) | ✅ KEY | ❌ |
| 3-Schema | Author | `schema.prisma:11-29` | email @unique + slug @unique + id @id (UUID) | ✅ | ✅ |
| 3-Schema | RefreshToken | `schema.prisma:347` | authorId FK (Author.id) | ❌ | ❌ |
| 3-Schema | SocialAccount | `schema.prisma:107` | authorId FK + providerId @unique | ❌ | ❌ |
| 3-Schema | SignupHistory | `schema.prisma:120-126` | providerId @id (email or OAuth sub) | ✅ KEY | ❌ |
| 4-Guard | JwtAuthGuard | `jwt-auth.guard.ts:12-30` | Bearer + HttpOnly cookie + verify | 토큰만 의존 | ❌ |
| 4-Guard | request.user | `authenticated-request.ts:4-8` | `JwtPayload { sub, slug, email, role }` | ✅ 포함 | ✅ 포함 |
| 4-Logic | UseCase 호출 | 다수 controller | `req.user.sub` 100% 사용 | ❌ | ❌ |
| 5-OAuth | Google verify | `auth.usecase.ts:86-93` | OAuth2Client.verifyIdToken → payload.email + payload.sub | ✅ 추출 | ❌ |
| 5-OAuth | 자동 링크 | `auth.usecase.ts:100` | `findByEmail(payload.email)` 적중 시 자동 링크 | ✅ KEY 정책 | ❌ |
| 5-OAuth | slug 자동 생성 | `auth.usecase.ts:110` | `email.split('@')[0]` + 충돌 시 4자리 난수 | ✅ 유도 | ✅ 자동 |
| 6-Web Login | login form | `login/page.tsx:54-62` | `<input type="email">` placeholder="your@email.com" | ✅ 이메일만 | ❌ |
| 6-Web Login | submit | `login/page.tsx:28,67` | `login(email, password, recaptcha)` | ✅ | ❌ |
| 6-Web Register | form | `register/page.tsx:57-92` | email + password + name + slug 모두 필수 | ✅ | ✅ |
| 6-Web Register | slug 자동 | `register/page.tsx:22-25` | name → auto-slug (lowercase + replace) | ❌ | ✅ 유도 |
| 6-API | api.ts login | `lib/api.ts:35-40` | `login({ email, password })` | ✅ | ❌ |
| 6-API | api.ts register | `lib/api.ts:28-33` | `register({ email, password, name, slug })` | ✅ | ✅ |
| 7-PwReset | (미구현) | — | **❌ 비밀번호 초기화 코드 0건** (changePassword만) | — | — |
| 8-Test | jest auth | `auth.usecase.spec.ts:85-119` | `login({ email, password })` 만 spec | ✅ | ❌ |
| 8-Test | e2e auth | `e2e/auth.spec.ts:34-45` | `placeholder("your@email.com")` 의존 (이미 EMAIL-P0-1에서 broken 정리) | ✅ | ❌ |

#### 핵심 발견 (정합)

- ✅ **DB 스키마는 이미 완비**: `email @unique` + `slug @unique` 둘 다 박제. 백필 SQL 0건 (Phase 1 검증 쿼리만).
- ✅ **JWT payload에 slug 이미 포함**: 변경 0건 (Phase 1~3 무관).
- ✅ **AuthGuard 이후 백엔드 로직 100% authorId (sub) 기반**: 변경 0건.
- ⚠️ **OAuth 자동 링크 정책 (auth.usecase.ts:100)**: slug 도입 후에도 `findByEmail` 의존 — 이메일 일치 시 다른 사용자 계정 인수 위험 (별도 보안 검토 필요).
- ⚠️ **SignupHistory providerId=email**: 2회 제한 정책. slug 도입 시 email + slug 양쪽 검증 또는 정책 결정 필요.
- ⚠️ **비밀번호 초기화 미구현**: EMAIL-P1-1 진입 시 신설 (이메일 발송 의존 → 외부 API 결정 필요).

### 13-3. 마이그레이션 3 Phase (Explore 결과 정합 확정)

#### Phase 1: API 후향호환 (server 도메인, ~3h)

**목표**: email/slug 둘 다 로그인 수용 (옵션 1택). 기존 클라이언트 변경 0건 (email 로그인 정상 동작).

**산출물**:
- `auth.dto.ts` LoginDto 확장 — `@IsOptional() email?` + `@IsOptional() slug?` + `password` (custom validator: email XOR slug 1택 강제)
- `auth.usecase.ts` `login(input)` 시그니처 변경 — `findByEmail(email) ?? findBySlug(slug)` 분기
- `author-repository.port.ts` + `prisma-author.repository.ts` `findByEmailOrSlug(identifier)` 추가 (선택, 또는 분기 유지)
- `access-log.service.ts` slug 식별자 박제 (logging 영역)
- jest spec — slug 로그인 4 it 추가 (정상 / 미존재 slug / 비번 불일치 / email XOR slug 검증)
- `docs/api-contract.md` POST /auth/login 갱신

**호환성**:
- ✅ 후향 호환 (email 로그인 그대로 동작)
- ✅ DB schema 변경 0건
- ✅ 클라이언트 변경 0건

#### Phase 2: 클라이언트 점진 전환 (web 도메인, ~3h)

**목표**: 로그인 폼 입력칸 1개로 통합 — "이메일 또는 슬러그" 자동 판별.

**산출물**:
- `grimoire-web/src/app/login/page.tsx` — input label/placeholder 변경 + 자동 판별 로직 (정규식 `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`)
- `lib/api.ts` `login()` 시그니처 — `{ email?: string; slug?: string; password }` 양쪽 수용
- `features/auth/AuthProvider.tsx` `login(emailOrSlug, password, ...)` 시그니처
- `e2e/auth.spec.ts` — slug 로그인 e2e 1 it 추가
- `e2e/dashboard.spec.ts` — 환경변수 `E2E_AUTHOR_SLUG` 추가 (또는 기존 EMAIL과 양립)
- `.env.example` `E2E_AUTHOR_SLUG=deerdevil` 추가
- `docs/SCREENS.md` 로그인 페이지 갱신

**호환성**:
- ✅ 백엔드 Phase 1 정합 (자동 판별로 어느 쪽이든 호출 가능)
- ✅ 사용자가 이메일/슬러그 어느 쪽 입력해도 로그인 성공

#### Phase 3 (선택): email 입력 deprecate

> **사용자 결정 영역** — Phase 1 + Phase 2 정합 후 1개월 충분 검증 후 결정. 본 sprint OUT.

### 13-4. 영향 받는 파일 전수 표 (Explore 결과 정합)

#### server (~16~20 파일)

| # | 파일 | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|---|
| 1 | `adapter/inbound/http/dto/auth.dto.ts` | ✅ LoginDto 확장 | — | ✅ slug 필수화 |
| 2 | `adapter/inbound/http/controller/auth.controller.ts` | ✅ logging slug 포함 | — | — |
| 3 | `application/auth/auth.usecase.ts` | ✅ login() 분기 | — | ✅ findByEmail 제거 |
| 4 | `domain/port/outbound/author-repository.port.ts` | ⚠️ findByEmailOrSlug 추가 (선택) | — | — |
| 5 | `adapter/outbound/persistence/prisma-author.repository.ts` | ⚠️ findByEmailOrSlug 구현 (선택) | — | — |
| 6 | `application/auth/access-log.service.ts` | ✅ slug 식별자 박제 | — | — |
| 7 | `application/auth/auth.usecase.spec.ts` | ✅ slug 로그인 4 it 추가 | — | ✅ findByEmail 회귀 제거 |
| 8 | `application/auth/auth-security.spec.ts` | ✅ slug 보안 시나리오 | — | — |
| 9 | `application/admin/admin.controller.ts` | ⚠️ admin login slug 옵션 (선택) | — | — |
| 10 | `application/admin/admin.usecase.ts` | ⚠️ admin slug 로그인 (선택) | — | — |
| 11 | `domain/port/outbound/email-service.port.ts` | ✅ EMAIL-P1-1 진입 후 활용 | — | — |
| 12 | `adapter/outbound/email/null-email.adapter.ts` | ✅ EMAIL-P1-1 진입 후 활용 | — | — |
| 13~16 | jest spec 추가 / docs/api-contract.md / docs/data-model.md | ✅ | — | — |

#### web (~6~8 파일)

| # | 파일 | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|---|
| 1 | `src/app/login/page.tsx` | — | ✅ input 통합 + 자동 판별 | — |
| 2 | `src/app/register/page.tsx` | — | ⚠️ slug 안내 강화 (옵션) | — |
| 3 | `src/lib/api.ts` | — | ✅ login 시그니처 확장 | ✅ email 제거 |
| 4 | `src/features/auth/AuthProvider.tsx` | — | ✅ login 시그니처 갱신 | — |
| 5 | `src/types/api.ts` | — | ⚠️ LoginRequest 타입 갱신 | — |
| 6 | `e2e/auth.spec.ts` | — | ✅ slug 로그인 1 it 추가 | — |
| 7 | `e2e/dashboard.spec.ts` | — | ✅ E2E_AUTHOR_SLUG 환경변수 | — |
| 8 | `.env.example` | — | ✅ E2E_AUTHOR_SLUG 추가 | — |

### 13-5. 위험 영역 (Explore 결과 4건)

| # | 위험 | 현재 코드 | 마이그레이션 대응 |
|---|---|---|---|
| 1 | **OAuth 동일 이메일 자동 링크 (보안)** | `auth.usecase.ts:112-122` 강화안 A 적용 (sprint #10_7 트랙 F) — `email_verified === false` 차단 게이트 | ✅ **1단계 해소** (2026-05-05 트랙 F 강화안 A). RFC 6819 §5.1.1 / OWASP A07:2021 부분 완화. shared-contracts §16 OAuthEmailVerification + sensor-oauth-email-verification + regression-60 박제. 강화안 B(명시 동의 UI) / C(이메일 인증 발송 — EMAIL-P1-1 의존)는 별도 sprint. |
| 2 | **SignupHistory 2회 제한 (정책)** | `auth.usecase.ts:38,58` providerId=email | 📝 **검토 종료** (2026-05-05 트랙 G). slug 통합 제한(강화안 A) / IP fingerprint(B) / TTL unlock(C) 3안 박제. 정본: `reports/sprint-signup-history-slug-review-progress.md`. 채택은 사용자 결정 영역. |
| 3 | **RefreshToken / SocialAccount FK** | `schema.prisma:347,107` authorId 기반 | 영향 0건 — 변경 불필요 |
| 4 | **비밀번호 초기화 미구현** | (코드 0건) | EMAIL-P1-1 진입 시 신설 (외부 API 결정 후) |

### 13-6. 백필 SQL (검증 쿼리만)

운영 DB 박제 row 모두 email + slug @unique 정합 가정. **백필 SQL 0건** 추정 (검증 쿼리로 사후 확인).

```sql
-- 본 검증 쿼리는 사용자 영역 (dev/prod 직접 실행)
SELECT COUNT(*) FROM authors WHERE email IS NULL;       -- 기대: 0
SELECT COUNT(*) FROM authors WHERE slug IS NULL;        -- 기대: 0
SELECT email, COUNT(*) FROM authors GROUP BY email HAVING COUNT(*) > 1;  -- 기대: 0 row
SELECT slug, COUNT(*) FROM authors GROUP BY slug HAVING COUNT(*) > 1;    -- 기대: 0 row

-- SignupHistory providerId 분포
SELECT
  SUM(CASE WHEN provider_id LIKE '%@%' THEN 1 ELSE 0 END) AS email_based,
  SUM(CASE WHEN provider_id NOT LIKE '%@%' THEN 1 ELSE 0 END) AS oauth_based
FROM signup_history;
```

→ EMAIL-P0-2 운영 DB 가짜 이메일 12~15 row 정리 SQL과 함께 사용자 1회 실행 권장.

### 13-7. EMAIL-P0-3 진입 게이트

1. ✅ Explore subagent 결과 도착 → §13-2/§13-3/§13-4/§13-5 정밀 갱신 완료
2. ✅ EmailServicePort 캡슐화 인터페이스 + NullEmailAdapter + spec 박제 완료 (provider 변경 비파괴 강제)
3. ⏳ planner Initializer 위임 → Sprint 계약 + AC 7건+ BDD
4. ⏸ **사용자 승인 게이트** (~6h Phase 1 + Phase 2 통합 sprint, 다중 도메인) → 승인 후 server agent + web agent + qa Evaluator 위임
5. 메인 commit/push 책임

### 13-8. 사용자 영역 잔존 (EMAIL-P0-3 + 인접)

- EMAIL-P0-2 운영 DB SQL 백필 (가짜 이메일 12~15 row 정리)
- §13-6 검증 SQL 1회 실행 (백필 0건 검증)
- §11 외부 API 결정 (Resend / SES / Postmark / NHN)
- §13-5 위험 영역 #1 (OAuth 자동 링크) 별도 보안 sprint 결정

### 13-3. 마이그레이션 3 Phase (무중단 호환)

**Phase 1**: API에 `identifier` 인자 도입 (email 또는 slug 둘 다 수용)
- `LoginDto { identifier: string; password: string }` (기존 email → identifier 명칭 변경)
- `auth.usecase.login(identifier, password)` — `findByEmail(identifier) ?? findBySlug(identifier)` 분기
- 응답 schema 동일 (breaking change 0)
- jest spec 갱신 + 회귀 차단

**Phase 2**: 클라이언트 slug 로그인으로 점진 전환
- `grimoire-web/src/app/login/page.tsx` — input label "이메일" → "이메일 또는 슬러그"
- `grimoire-web/src/app/register/page.tsx` — slug 박제 강조 (이메일은 옵션)
- 비번 초기화 흐름 진입 시 이메일 의존 (token 발송 매개체) — 이건 EMAIL-P1-1 인증 시스템 영역

**Phase 3** (선택): email 인자 deprecate
- 사용자가 모든 클라이언트 slug 전환 후 결정
- 기존 운영 사용자 데이터 영향 0건 보장

### 13-4. DB 백필 영향 (현재 추정)

- `Author.slug @unique` 박제 가정 (Explore 도착 후 확인)
- 모든 운영 row에 slug 박제됨 (회원가입 시 slug 필수 박제 가정)
- slug 누락 row 0건 추정 — 백필 SQL 0건 가능성 높음 (Explore 검증 후 확정)
- email 의존 부수 테이블 (refresh_tokens / social_accounts) → author_id FK이므로 영향 0

### 13-5. EMAIL-P0-2 운영 DB SQL 백필 (사용자 영역, §2-1 박제 영역과 연계)

slug 로그인 도입 후에도 EMAIL-P0-2 (가짜 `@grimoire.app` 12~15 row 정리)는 **여전히 필요**:
- 가짜 이메일 row를 삭제하면 slug 'deerdevil' / 'lee-gwangsu' 등 정합 가능
- 또는 가짜 이메일 row의 email 필드만 NULL 허용 (schema 변경) — Phase 1에서 결정

### 13-6. 영향 받는 파일 추정 (Explore 결과 도착 후 정밀 갱신)

server (~10 파일):
- `application/auth/auth.usecase.ts` (login/signup 시그니처)
- `adapter/inbound/http/dto/login.dto.ts` / `signup.dto.ts`
- `adapter/inbound/http/controller/auth.controller.ts`
- `domain/port/outbound/author-repository.port.ts` (`findBySlug` 시그니처 박제 확인)
- `adapter/outbound/persistence/prisma-author.repository.ts`
- `application/auth/jwt.strategy.ts`
- jest spec 4~6 파일

web (~5 파일):
- `src/app/login/page.tsx`
- `src/app/register/page.tsx`
- `src/features/auth/use-auth.ts`
- `src/lib/api.ts` (login/signup API 호출)
- vitest/e2e spec 2~3 파일

### 13-7. 위험 영역

- **OAuth Google 동일 이메일 자동 링크** (auth.usecase.ts:100) — slug 로그인 도입 시 OAuth 사용자 slug 자동 생성 정책 검토 필요
- **SignupHistory 2회 제한** (auth.usecase.ts:38) — 이메일 기반? slug 기반? 이메일+slug 양쪽? Explore 결과로 확인
- **refresh_tokens** — author_id FK이므로 영향 0 (확인 필요)
- **JwtStrategy payload** — sub=authorId 가정 (변경 0). email 박제 시 갱신 필요

### 13-8. EMAIL-P0-3 진입 게이트

1. Explore subagent 결과 도착 → §13-2 + §13-6 정밀 갱신
2. planner Initializer 위임 → Sprint 계약 + AC 7건+ BDD
3. 사용자 승인 (큰 작업 ~5-8h, 다중 도메인) → server agent + web agent + qa Evaluator 위임
4. 메인 commit/push 책임

### 13-9. 사용자 영역 잔존

- EMAIL-P0-2 운영 DB SQL 백필 (12~15 row 정리)
- EMAIL-P1-1/P1-3 외부 API 결정 (§11 결정 게이트)

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
