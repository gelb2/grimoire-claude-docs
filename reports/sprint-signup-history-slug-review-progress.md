# Sprint signup-history-slug-review (트랙 G — 검토 sprint)

> **유형**: 검토 sprint (코드 변경 0건, 박제만)
> **소요**: ~30분 (자율 진행, 책 Ch 23 자가진단 정합)
> **종료 조건**: 강화안 3가지 권장 + 사용자 결정 영역 명시

---

## §1. 사용자 명시 트랙 분류

- **자율 가능 100%**: 검토 + 위험 시나리오 분석 + 강화안 권장
- **사용자 결정 영역**: 어느 강화안을 채택할지 + DB schema 변경 + 백필 SQL

본 sprint는 분석/박제만 진행하고 채택 코드 변경은 사용자 명시 후 별도 sprint.

---

## §2. 현황 (코드 박제 검증)

### §2-1. SignupHistory 모델 (`grimoire-server/prisma/schema.prisma:120-126`)

```prisma
model SignupHistory {
  providerId    String   @id @map("provider_id")
  firstSignupAt DateTime @default(now()) @map("first_signup_at") @db.Timestamptz(3)
  signupCount   Int      @default(1) @map("signup_count")
  @@map("signup_history")
}
```

**핵심 사실**:
- `providerId` 컬럼 1개 (PK) — 이메일 또는 OAuth `sub`을 혼합 박제
- `slug` 컬럼 **0건** — slug 변경/재사용 추적 불가
- FK 관계 0건 — Author와 비정규화 (탈퇴 후에도 남음)
- 인덱스 0건 — `@id`만

### §2-2. 사용처 (`auth.usecase.ts`)

| Line | 호출 | 정책 |
|------|------|------|
| L38 | `findByProviderId(input.email)` | 일반 회원가입 시 email 기반 2회 제한 |
| L58 | `upsert(input.email)` | 회원가입 후 email 기반 박제 |
| L124 | `findByProviderId(payload.sub)` | OAuth 신규 가입 시 sub 기반 2회 제한 |
| L143 | `upsert(payload.sub)` | OAuth 가입 후 sub 기반 박제 |

**현 정책**: `signupCount >= 2` 도달 시 차단. providerId 키는 email 또는 OAuth sub.

---

## §3. 위험 시나리오 4건

| # | 시나리오 | 현 동작 | 위험도 | 영향 |
|---|---------|---------|--------|------|
| 1 | slug 변경 시 SignupHistory 미갱신 | slug는 추적 0건 | 🟡 중 | 이전 slug로 회원가입 가능 (재사용) |
| 2 | 탈퇴 후 slug 재사용 | Author 삭제되어도 SignupHistory 잔존 | 🟢 낮 | 의도된 동작 (이메일 잠금 유지) |
| 3 | **email↔slug 로그인 전환 후 재가입 공백** ★ | providerId=email 기반 제한만 박제 | 🟠 높 | EMAIL-P0-3 신규 도입 후 정책 공백 |
| 4 | OAuth 자동 링크 (별도 트랙 F) | `findByEmail(payload.email)` 일치 시 자동 연결 | 🔴 최고 | 다른 사용자 계정 인수 위험 |

**핵심 발견**:
- 시나리오 #3이 가장 시급 — EMAIL-P0-3 (slug 로그인) 신규 도입 후 등장한 공백
- 시나리오 #4는 트랙 F (OAuth 자동 링크 보안)에서 처리

---

## §4. 권장 강화안 (3가지, 사용자 결정 영역)

### §4-1. 강화안 A: SignupHistory.slug 컬럼 추가 + 통합 재가입 제한

**목적**: slug 변경/재사용 추적 + email↔slug 양쪽 재가입 전환 방지 (시나리오 #1 + #3 해소)

**변경**:
- Prisma migration: `add_slug_to_signup_history`
  ```prisma
  model SignupHistory {
    providerId    String   @id @map("provider_id")
    slug          String?  @map("slug")           // 신규
    firstSignupAt DateTime @default(now())
    signupCount   Int      @default(1)
    @@index([slug])                                // 신규
    @@map("signup_history")
  }
  ```
- `auth.usecase.ts`:
  ```typescript
  // L38 변경
  const emailHistory = await this.signupHistoryRepo.findByProviderId(input.email)
  const slugHistory  = await this.signupHistoryRepo.findBySlug(input.slug)
  if ((emailHistory?.signupCount >= 2) || (slugHistory?.signupCount >= 2)) {
    throw new BadRequestException('이 이메일 또는 슬러그로는 더 이상 가입할 수 없습니다')
  }
  // L58 변경
  await this.signupHistoryRepo.upsertEmailAndSlug(input.email, input.slug)
  ```
- spec 신설: signup-history.repository.spec / register slug 통합 제한 spec

**규모**: ~3h
**사용자 결정 영역**:
- DB schema 변경 (마이그레이션)
- 운영 백필 SQL: 기존 SignupHistory row의 slug 컬럼 백필 (Author.slug 조인)
- 정책: `signupCount >= 2` 임계 유지 vs 강화

### §4-2. 강화안 B: IP/Device Fingerprint 박제

**목적**: email+slug 위장을 넘어 동일 기기/IP 폭주 가입 방지

**변경**:
- Prisma migration: `add_device_columns_to_signup_history`
  ```prisma
  model SignupHistory {
    // ... 기존
    ipAddress    String?  @map("ip_address")
    userAgent    String?  @map("user_agent")
    deviceHash   String?  @map("device_hash")
  }
  ```
- controller: extractClientInfo + fingerprint 계산
- repository: upsertWithDevice 시그니처

**규모**: ~5h
**사용자 결정 영역**:
- 외부 fingerprinting SDK (FingerprintJS 등) 도입 여부 (절대 규정 0-1 외부 API와 충돌 가능)
- 또는 자체 fingerprint (UA + IP hash) 기반 박제
- 개인정보 보호 정책 (GDPR / 한국 PIPA) 검토

### §4-3. 강화안 C: TTL unlock 정책

**목적**: 일정 기간 후 재가입 제한 자동 해제 (운영 친화적)

**변경**:
- Prisma migration: `add_unlock_at_to_signup_history`
  ```prisma
  model SignupHistory {
    // ... 기존
    unlockAt DateTime? @map("unlock_at") @db.Timestamptz(3)  // null = 영구 제한
  }
  ```
- `auth.usecase.ts`:
  ```typescript
  const isLocked = signupHistory && signupHistory.signupCount >= 2 &&
                   (!signupHistory.unlockAt || signupHistory.unlockAt > new Date())
  if (isLocked) throw BadRequestException('재가입 가능할 때까지 대기')
  ```

**규모**: ~2h
**사용자 결정 영역**:
- 자동 unlock 기간 (24h / 7d / 30d / 영구)
- 운영자 수동 unlock UI (admin tab 확장)

---

## §5. 권장 채택 우선순위

| 순위 | 강화안 | 시급도 | 채택 시점 |
|---|---|---|---|
| 1 | **A (slug 통합 제한)** | 🟠 높음 | EMAIL-P0-3 후속 sprint 1순위 |
| 2 | **C (TTL unlock)** | 🟡 중간 | A 채택 후 별도 sprint |
| 3 | B (IP fingerprint) | 🟢 낮음 | 운영 데이터 수집 후 결정 |

**근거**:
- A는 EMAIL-P0-3 도입 후 발생한 정책 공백 즉시 해소
- C는 운영 시 사용자 문의 폭증 시 운영자 부담 경감
- B는 외부 SDK 의존 위험 + GDPR 검토 동반 → 후순위

---

## §6. 사용자 결정 명령 (트랙 G 종료 시점)

다음 중 1택:

| 명령 | 효과 |
|------|------|
| **"강화안 A 진입"** | slug 통합 제한 sprint 진입 (~3h, 자율) — DB migration + repository + spec |
| **"강화안 C 진입"** | TTL unlock sprint 진입 (~2h, 자율) — 자동 unlock 24h 기준 |
| **"강화안 B 진입"** | IP fingerprint sprint 진입 (외부 SDK 결정 필수, 사용자 영역) |
| **"검토만 박제"** | 본 sprint 종료 + 다른 트랙 진입 (F / H / J' 등) |

---

## §7. 회귀 차단 계획 (강화안 A 채택 시 박제 예정)

- **신규 sensor**: `sensor-signup-history-slug-tracking.sh`
  - SignupHistory.slug 컬럼 박제 검증
  - findBySlug + findByProviderId 분기 코드 박제
  - upsertEmailAndSlug 시그니처 박제
- **eval task**: `regression-60-signup-history-slug-tracking.json` (10 criteria)
- **shared-contracts**: §16 SignupHistorySlugTracking 신설
- **회귀 임계**: 1.0 (정합)

---

## §8. 검증 명령

```bash
# 본 sprint 종료 검증
cd /Users/sokol/Git/ProjectGrimoire
ls reports/sprint-signup-history-slug-review-progress.md  # 본 보고서
grep -n "providerId" grimoire-server/prisma/schema.prisma  # L120-126 SignupHistory 모델
grep -n "findByProviderId\|signupCount" grimoire-server/src/application/auth/auth.usecase.ts
```

---

## §9. 정본 정합

- `research/EMAIL_INTEGRITY_PLAN.md` §13-5 위험 영역 #2 — **본 보고서로 해소**
- `HANDOVER_NEXT_SESSION.md` §1.5 다음 트랙 G — **검토 종료 박제**

---

마지막 업데이트: 2026-05-05 트랙 G 자율 진행
승격 원본: 트랙 1-A/B/C (sensor-log 통합) 후 사용자 명시 자율 진행 트랙 G 진입
