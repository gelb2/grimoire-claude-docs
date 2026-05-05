# Sprint PAY-P2-3 SmsServicePort 캡슐화 (사전 작업) — 정본 (sprint #10_7)

> **유형**: 결제 시스템 PAY-P2-3 사전 작업 — Hexagonal Port 캡슐화 (외부 API 결정 게이트 직전 단계)
> **소요**: ~1.5시간 (자율 진행 완료, 마스터 플랜 §5 정합)
> **외부 API 신규 의존**: 0건 (NullSmsAdapter default — 절대 규정 0-1 정합)
> **종료 조건**: AC-1~AC-5 모두 PASS + 회귀 차단 sensor + shared-contracts §19

---

## §1. 사용자 명시 트랙 진입

- **사용자 명시**: "p2-3 사전 작업 하고" (2026-05-05)
- **마스터 플랜**: `reports/PAY-P2-MASTER-PLAN.md` §5 (P2-3 사전 작업 자율 가능 박제)
- **EmailServicePort 패턴 정합**: `research/EMAIL_INTEGRITY_PLAN.md` §12 + 본 sprint에서 SMS 영역 동일 패턴 적용

---

## §2. AC (Acceptance Criteria) — 5건

### AC-1. SmsServicePort 인터페이스

`grimoire-server/src/domain/port/outbound/sms-service.port.ts`:

```typescript
export type SmsProvider = 'null' | 'kakao' | 'nhn' | 'twilio'
export type PaymentSmsType = 'payment_success' | 'payment_failed' | 'payment_refunded'

export interface SmsServicePort {
  sendPaymentNotification(input): Promise<SmsSendResult>
  sendVerificationCode(input): Promise<SmsSendResult>
  isEnabled(): boolean
  getProviderName(): SmsProvider
}
```

**검증**:
- ✅ 4 메서드 박제
- ✅ SmsProvider 매트릭스 (null/kakao/nhn/twilio)
- ✅ PaymentSmsType ↔ EmailServicePort.PaymentNotificationType 정합 (3 타입)
- ✅ 외부 SDK import 0건 (절대 규정 0-1)

### AC-2. NullSmsAdapter (default)

`grimoire-server/src/adapter/outbound/sms/null-sms.adapter.ts`:

```typescript
@Injectable()
export class NullSmsAdapter implements SmsServicePort {
  // sendPaymentNotification — logger.warn + messageId=null + provider='null'
  // sendVerificationCode — logger.warn + messageId=null + provider='null'
  // isEnabled() => false
  // getProviderName() => 'null'

  // PII 마스킹
  private maskPhone(phone): string  // +821****5678
  private maskCode(code): string    // 1***
}
```

**검증**:
- ✅ 외부 API import 0건 (twilio / @nhncloud / @kakao / aws-sdk 0)
- ✅ PII 마스킹 (전화번호 + 인증코드) 박제
- ✅ logger.warn만 — 실 발송 0건
- ✅ EmailServicePort.NullEmailAdapter 패턴 정합

### AC-3. spec 10 it

`null-sms.adapter.spec.ts`:
1. ✅ isEnabled 항상 false
2. ✅ getProviderName 'null' 반환
3. ✅ sendPaymentNotification type=success — messageId=null
4. ✅ sendPaymentNotification type=failed — messageId=null
5. ✅ sendPaymentNotification type=refunded — messageId=null
6. ✅ sendPaymentNotification PII 마스킹 (전화번호 평문 박제 차단)
7. ✅ sendVerificationCode messageId=null
8. ✅ sendVerificationCode PII 마스킹 (코드 평문 박제 차단)
9. ✅ 짧은 코드 (≤2자) 마스킹 안전망
10. ✅ 짧은 전화번호 (≤4자) 마스킹 안전망

**실행 결과**: 10/10 PASS (jest 591 + 10 = 601 신규 expected)

### AC-4. sensor + regression-63

- `.claude/scripts/sensor-sms-service-port.sh` (8 검증, PASS-only 회귀 차단)
- `eval/tasks/regression-63-sms-service-port.json` (10 criteria)

**검증**: 8/8 PASS

### AC-5. 정본 갱신

- ✅ `.claude/shared-contracts.md` §19 SmsServicePort 신설
- ✅ `reports/PAY-P2-MASTER-PLAN.md` §5 (사전 박제)
- ✅ HARNESS_ENGINEERING.md Sensors §14.4 자동 갱신 (commit 시 자동)

---

## §3. 의도된 OUT (사용자 결정 영역)

| # | 영역 | 의도 |
|---|---|---|
| 1 | **app.module DI 등록** | EmailServicePort와 동일 — provider 결정 후 별도 sprint에서 진입 |
| 2 | **payment.usecase 트리거** | EMAIL-P1-3 + PAY-P2-3 통합 sprint에서 동시 진입 (Email + SMS 동시 알림) |
| 3 | **실 SMS adapter 구현** | KakaoBizmessage / NhnCloud / Twilio — 사용자 명시 후 별도 sprint |
| 4 | **결제 알림 템플릿** | 한국어 SMS 본문 (90~140자 제한) — provider 결정 후 |

---

## §4. 권장 진입 순서 (PAY-P2-3 본격 진입 시점)

```
사용자 명시: "SMS 진입 + KAKAO Bizmessage" (또는 1택)
  ↓
1. KakaoBizmessageAdapter 신설 (외부 SDK 도입)
2. app.module DI factory + env 분기 (SMS_PROVIDER=kakao)
3. payment.usecase에 sendPaymentNotification 트리거 (success / cancel / refund)
4. EmailServicePort 트리거도 동시 진입 (이메일 SaaS 결정 정합 시)
5. SMS 본문 템플릿 + 길이 제한 검증
6. spec + sensor + regression
7. dev 검증 + prod 배포
```

---

## §5. 위험 시나리오

| # | 시나리오 | 현 상태 |
|---|---|---|
| 1 | NullAdapter가 실 발송으로 오인 | ✅ 차단 (isEnabled=false + logger.warn 명시) |
| 2 | 평문 PII 로그 박제 | ✅ 차단 (maskPhone + maskCode + spec 검증) |
| 3 | 외부 SDK 의존 누설 | ✅ 차단 (sensor 외부 import 0건 검증) |
| 4 | provider 결정 전 트리거 호출 | ✅ noop (NullAdapter는 logger.warn만, 실 발송 0건) |
| 5 | EmailServicePort와 인터페이스 drift | ✅ 차단 (PaymentSmsType ↔ PaymentNotificationType 3 타입 sensor 검증) |

---

## §6. 사용자 결정 영역 (PAY-P2-3 본격 진입 게이트)

| # | 항목 | 명령 |
|---|---|---|
| 1 | **SMS provider 결정** | "SMS 진입 — KAKAO" (추천) / "SMS 진입 — NHN" / "SMS 진입 — Twilio" + 외부 API 결정 명시 |
| 2 | **이메일 SaaS 결정 동시 검토** | EmailServicePort와 함께 진입 가능 (트리거 통합 효율) |
| 3 | **EMAIL-P1-3 결제 알림 통합 결정** | Email + SMS 동시 알림 vs 독립 진입 |
| 4 | **SMS 본문 템플릿 작성** | 한국어 90자 이내 (KAKAO 알림톡 제약) — provider 결정 후 |

---

## §7. 검증 명령

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire

# PAY-P2-3 사전 작업 회귀 검증
bash .claude/scripts/sensor-sms-service-port.sh
bash eval/scripts/eval-runner.sh tasks/regression-63-sms-service-port.json

# server jest 601/601 PASS (NullSmsAdapter spec 10 추가)
cd grimoire-server
npx jest src/adapter/outbound/sms/null-sms.adapter.spec.ts

# 외부 SDK import 0건 직접 검증
cd /Users/sokol/Desktop/Git/ProjectGrimoire
grep -rEi "from ['\"](twilio|@nhncloud|@kakao|aws-sdk/client-sns)" \
  grimoire-server/src/adapter/outbound/sms/ \
  grimoire-server/src/domain/port/outbound/sms-service.port.ts
# 기대: 0건

# 다른 sprint 회귀 보존
bash eval/scripts/eval-runner.sh
bash .claude/scripts/sensor-adversarial-pre-commit.sh
```

---

## §8. 정본 정합

- `.claude/shared-contracts.md` §19 SmsServicePort (인터페이스 정본)
- `.claude/shared-contracts.md` §12 EmailServicePort (패턴 차용 원본)
- `reports/PAY-P2-MASTER-PLAN.md` §5 (마스터 플랜)
- `research/EMAIL_INTEGRITY_PLAN.md` §12 (Email 정본 — 패턴 정합)

---

마지막 업데이트: 2026-05-05 PAY-P2-3 사전 작업 자율 진행 완료
승격 원본: 사용자 명시 "p2-3 사전 작업 하고" + EmailServicePort 패턴 정합
