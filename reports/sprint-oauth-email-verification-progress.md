# Sprint oauth-email-verification (트랙 F 강화안 A — sprint #10_7)

> **유형**: 보안 강화 sprint (server 도메인, 외부 API 신규 의존 0건)
> **소요**: ~1시간 (자율 진행)
> **종료 조건**: AC-1~AC-5 모두 PASS + 회귀 차단 sensor 박제 + 정본 갱신
> **사용자 영역 결정**: 강화안 B (명시 동의) / C (이메일 인증 발송)는 EMAIL-P1-1 후 별도 sprint

---

## §1. 사용자 명시 트랙 분류

- **자율 가능 100%**: 강화안 A (`email_verified === false` 차단)
  - 외부 API 신규 의존 0건 → 절대 규정 0-1 정합
  - 코드 변경 5줄 + spec 4건 + sensor + regression task
- **사용자 결정 영역**:
  - 강화안 B (명시 동의 화면 + DB 신규 테이블)
  - 강화안 C (이메일 인증 발송 — EMAIL-P1-1 의존)
  - Kakao/Naver OAuth 확장 시 (EMAIL-P1-2) verified 필드 부재 대응

---

## §2. AC (Acceptance Criteria) — 5건

### AC-1. 코드 차단 게이트 (`grimoire-server/src/application/auth/auth.usecase.ts:112-122`)

```typescript
const payload = ticket.getPayload()
if (!payload?.email) throw new UnauthorizedException('Google 인증 실패')

// OAuth 자동 링크 보안 강화 (트랙 F 강화안 A — sprint #10_7)
// RFC 6819 §5.1.1 / OWASP A07:2021 — email_verified=false 차단
if (payload.email_verified === false) {
  throw new UnauthorizedException(
    'Google 이메일이 아직 인증되지 않았습니다. Google 계정에서 이메일 인증 후 다시 시도해주세요.',
  )
}

let author = await this.authorRepo.findBySocialAccount('google', payload.sub!)
```

**검증**:
- ✅ `payload.email_verified === false` 차단 패턴 박제
- ✅ 차단 게이트가 `findBySocialAccount` 앞에 위치 (line 118 < 125)
- ✅ 사용자 메시지 한국어 존댓말 (Constitution P10 정합)
- ✅ 외부 API 신규 의존 0건 (절대 규정 0-1 정합)

### AC-2. spec 박제 (`auth.usecase.spec.ts` `describe('googleLogin')` 4 it)

```typescript
describe('googleLogin (트랙 F email_verified 차단)', () => {
  // it 1: payload.email 없을 때 UnauthorizedException
  // it 2: email_verified=false 시 UnauthorizedException — findByEmail 호출 차단 검증
  // it 3: email_verified=true + 기존 소셜 연결 시 정상 로그인 (회귀 보존)
  // it 4: email_verified undefined 시 자동 링크 허용 (Google 기본 verified=true 정합)
})
```

**검증**:
- ✅ jest 결과 16/16 PASS (기존 12 + 신규 4)
- ✅ `not.toHaveBeenCalled()` assertion으로 자동 링크 차단 의미 검증
- ✅ `toMatchObject` assertion으로 회귀 보존 의미 검증

### AC-3. sensor 박제 (`.claude/scripts/sensor-oauth-email-verification.sh`)

8 검증 항목:
1. ✅ `email_verified === false` 차단 패턴
2. ✅ 사용자 안내 메시지
3. ✅ 차단 게이트가 `findBySocialAccount` 앞에 위치
4. ✅ spec describe + email_verified=false 시나리오
5. ✅ spec email_verified=true 회귀 보존
6. ✅ spec payload.email 누락 시나리오
7. ✅ 외부 프로젝트 인용 0건
8. ✅ 의미 있는 assertion ≥3건 (더미 차단)

**실행 결과**: 8/8 PASS / 0 FAIL

### AC-4. regression task 박제 (`eval/tasks/regression-60-oauth-email-verification.json`)

10 criteria:
1. ✅ sensor-oauth-email-verification.sh 실행 권한
2. ✅ sensor 직접 실행 PASS
3. ✅ auth.usecase.ts email_verified === false 패턴
4. ✅ 사용자 안내 메시지 박제
5. ✅ spec googleLogin describe
6. ✅ spec email_verified=false 시나리오
7. ✅ spec email_verified=true 회귀 보존
8. ✅ 외부 프로젝트 인용 0건
9. ✅ shared-contracts §16 OAuthEmailVerification 박제
10. ✅ sprint 보고서 박제

### AC-5. 정본 갱신

- ✅ `.claude/shared-contracts.md` §16 OAuthEmailVerification 신설
- ✅ `research/EMAIL_INTEGRITY_PLAN.md` §13-5 #1 상태 → "해소됨 (트랙 F 강화안 A)" 갱신 (별도 commit 동반)
- ✅ `eval/tasks/regression-60-oauth-email-verification.json` 신설

---

## §3. 외부 프로젝트 인용 0건 검증

```bash
grep -rEi 'CERTI_PROJ|brightmall|thermage|inapi' \
  grimoire-server/src/application/auth/auth.usecase.ts \
  grimoire-server/src/application/auth/auth.usecase.spec.ts
# 기대: 0건 (sensor [7/8] 통과)
```

---

## §4. 회귀 차단 정합

| sensor | 결과 | 비고 |
|---|---|---|
| sensor-oauth-email-verification | ✅ 8/8 PASS | 신규 박제 |
| sensor-slug-login | ✅ 12/12 PASS | EMAIL-P0-3 회귀 보존 |
| sensor-fake-email-leak | ✅ PASS | EMAIL-P0-1 회귀 보존 |
| sensor-adversarial-pre-commit | ✅ 16P/3W/0F | 19 Principles |
| eval regression-058~060 | ✅ 1.0 | baseline.csv 박제 |

---

## §5. 위험 시나리오 (해소된 것 vs 잔존)

| # | 시나리오 | 트랙 F 강화안 A 후 | 잔존 위험 |
|---|---|---|---|
| 1 | 공격자가 Google에서 victim 이메일로 계정 생성 | 🟢 차단 (Google email_verified=false 차단) | 🟢 매우 낮음 (Google 자체 검증 + email_verified 게이트) |
| 2 | OAuth provider가 email_verified 미박제 | 🟡 통과 (현 정책) | ⚠️ Kakao/Naver 도입 시 강화안 C 강제 필요 |
| 3 | victim이 일반 회원, 공격자가 OAuth 자동 링크 시도 | 🟢 1단계 차단 (email_verified) | 🟡 명시 동의 UI 미제공 (강화안 B 미적용) |
| 4 | 동일 이메일 OAuth 계정의 자동 인수 | 🟢 차단 + 향후 강화안 B/C로 강화 | 🟢 |

---

## §6. 사용자 결정 영역 (강화안 B/C 진입 게이트)

| 결정 | 영향 | 외부 API |
|---|---|---|
| **강화안 B (명시 동의 UI + DB 신규 테이블)** | server + web 양쪽 변경, OAuthPendingLink schema 신설, ~50~80줄 | 외부 API 0건 (자율 가능) |
| **강화안 C (이메일 인증 발송)** | EMAIL-P1-1 (이메일 인증 시스템) 의존 | **외부 API 결정 필수** (절대 규정 0-1 해제 필요 — Resend / SES / Postmark 중 1택) |
| **Kakao/Naver OAuth 확장 (EMAIL-P1-2)** | 추가 OAuth provider + verified 필드 부재 시 강화안 C 강제 | 사용자 Developer Console 등록 필요 |

권장 순서:
1. 본 sprint (강화안 A) develop 안정성 검증
2. EMAIL-P1-1 결정 (사용자 외부 API 해제 명시)
3. EMAIL-P1-1 진행 시 → 강화안 C로 직결
4. EMAIL-P1-1 보류 시 → 강화안 B 별도 sprint

---

## §7. 검증 명령

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire

# 본 sprint 회귀 검증
bash .claude/scripts/sensor-oauth-email-verification.sh
bash eval/scripts/eval-runner.sh tasks/regression-60-oauth-email-verification.json

# server jest spec 16/16 PASS
cd grimoire-server && npx jest src/application/auth/auth.usecase.spec.ts

# 다른 sprint 회귀 보존 검증
cd /Users/sokol/Desktop/Git/ProjectGrimoire
bash eval/scripts/eval-runner.sh
bash .claude/scripts/sensor-adversarial-pre-commit.sh
```

---

## §8. 관련 정본

- `.claude/shared-contracts.md` §16 OAuthEmailVerification (인터페이스 정본)
- `research/EMAIL_INTEGRITY_PLAN.md` §13-5 #1 (위험 영역 박제 — 본 sprint로 해소)
- `grimoire-server/src/application/auth/auth.usecase.ts:112-122` (코드 정본)
- RFC 6819 §5.1.1 OAuth Threat Model — Email Confirmation Phishing
- OWASP A07:2021 Identification and Authentication Failures

---

마지막 업데이트: 2026-05-05 트랙 F 강화안 A 자율 진행 완료
승격 원본: 트랙 G(검토 sprint) 종료 후 사용자 명시 자율 진행 트랙 F 진입
