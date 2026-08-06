# Sprint 계약 Draft — PAY-P2-5 audit retention 정책

> **작성**: 2026-05-10 #10_8 (grimoire-planner Initializer 산출, grimoire-harness 박제)
> **사용자 결정**: 옵션 D = 영구 보존 + 90일 후 PII 마스킹 (5/10 verbatim "d로 하고")
> **순서 결정**: 1순위 (5/10 verbatim "이건 순서대로 하고")
> **검증 정본**: PAYMENT_AUDIT-2026-05-07.md §3 + PAYMENT_SYSTEM_PLAN.md §3-3 P2-3

---

## §0. 한 줄 요약

PAYMENT_AUDIT §3 + 마스터 플랜 §3-3 P2 정합 — 사용자 결정 옵션 D (영구 보존 + PII 마스킹) → (1) 4 모델 (AdminAuditLog/WebhookEvent/WebhookRetryQueue/AccessLog) `maskedAt DateTime?` + `retentionTier String @default("active")` 컬럼 신설 + (2) `audit-mask-helper.ts` 신설 (PII 7 키 자동 검출 + JSON deep masking) + (3) `audit-mask.scheduler.ts` 신설 (`@Cron('0 0 3 * * *')` 매일 03:00 KST) + (4) AuditLogPort `maskRow` + `findRowsToMask` 메서드 + (5) shared-contracts §26 AuditRetentionPolicy 신설 + (6) ADR-008 + sensor-audit-retention-policy.sh + eval regression-70. **삭제 cron 0건 강제** (영구 보존, 사용자 결정 D 정합).

## §0-1. 사용자 결정 박제 (5/10 raw 인용)

- **결정 1 (순서)**: "PAY-P2-5 ... PAY-P3-H ... PAY-P3-D ... USER-SOFT-DELETE ... PAY-P3-E 단계 7~12 ... 이건 순서대로 하고"
- **결정 2 (이메일)**: "이메일은 인터페이스 구현 해놓으면 되잖아" — EmailServicePort 인터페이스만 (5/5 종료 박제 server `b49b6ba`), SaaS 어댑터 사용자 결정 후
- **결정 3 (보존)**: "d로 하고" — 옵션 D = 영구 보존 + 90일 후 PII 마스킹 (삭제 cron 0건 강제)
- **결정 4 (hook 폐기)**: "다 폐기해" — PP-7 + PP-12 + PP-13 size 0 (5/10 22:18 종료)

## §1. 배경 / 문제 영역

- 현재 audit log 보존 정책 부재 (PAYMENT_AUDIT §3 L84-85 "retention 미정의")
- 전자상거래법 5년 보존 의무 → 영구 보존 정합 (옵션 D)
- 개인정보 보호법 마스킹 의무 (사용자 식별자 외 PII 마스킹)
- 4 모델 영향 (AdminAuditLog / WebhookEvent / WebhookRetryQueue / AccessLog)

## §2. 영향 모델 매트릭스 (Prisma schema 직접 Read 박제)

| # | 모델 | line | 신설 컬럼 | 마스킹 영역 (90일 후) | 영구 보존 영역 |
|---|---|---:|---|---|---|
| 1 | AdminAuditLog | L448-460 | `maskedAt DateTime?` + `retentionTier String @default("active")` | detail JSON deep masking | id/adminId/action/targetId/createdAt 보존 |
| 2 | WebhookEvent | L261-273 | 동일 | payload JSON deep masking + errorMessage | id/eventId/source/eventType/status/processedAt 보존 |
| 3 | WebhookRetryQueue | L507-518 | 동일 | payload JSON deep masking + lastError | id/eventId/retryCount/nextRetryAt/createdAt 보존 |
| 4 | AccessLog | L389-404 | 동일 | email/ip/userAgent/detail | id/action/authorId/createdAt 보존 |

## §3. PII 자동 검출 매트릭스 (7 키)

| PII 키 | 마스킹 패턴 | 예시 |
|---|---|---|
| email | `<first>***@<domain>` | `john@example.com` → `j***@example.com` |
| phone | `010-****-****` | `010-1234-5678` → `010-****-****` |
| ipAddress | `<a>.<b>.***.**` | `192.168.1.100` → `192.168.***.**` |
| userAgent | `<browser> (***)` | 전체 UA → `Mozilla/5.0 (***)` |
| passwordHash | `***` | bcrypt → `***` |
| token | `***` | JWT → `***` |
| secret | `***` | API key → `***` |

### §3-1. 보존 키 매트릭스 (마스킹 X 강제)

- id / userId / authorId / adminId / action / createdAt / amount / credits / status / eventId / eventType / source / targetId / retryCount / nextRetryAt / processedAt

### §3-2. JSON deep masking 정책

- 키 매칭 (재귀): PII 키 매트릭스 정합 시 마스킹
- 보수적 패턴: false positive < 5% (보존 키 매트릭스 우선)
- 멱등성: 이미 `***` 인 값 재마스킹 0건

## §4. 작업 분해 (단계 1~9)

### §4-1. 단계 1: dev 90일 경과 row 측정 (server agent + infrastructure agent)
- SQL: `SELECT COUNT(*) FROM "AdminAuditLog" WHERE "createdAt" < NOW() - INTERVAL '90 days'` (4 모델)
- 결과 raw → `.claude/state/pay-p2-5-dev-measure-raw.md`
- 사용자 결정 게이트: 측정 결과 영역 N>0 또는 N=0 영역 사용자 결정

### §4-2. 단계 2: dev 백업 박제 (사용자 결정 후)
- 명시 키워드: `PAY-P2-5 dev 백업 박제 완료`
- pg_dump 4 모델 → `audit_backup_dev_20260510.sql`

### §4-3. 단계 3: schema.prisma + migration.sql + ADR-008
- 4 모델 컬럼 추가 (maskedAt + retentionTier)
- migration.sql: ALTER TABLE 4 + ADD COLUMN 8
- ADR-008 박제 (영구 보존 + 마스킹 정책 결정 근거)

### §4-4. 단계 4: audit-mask-helper.ts + audit-mask.scheduler.ts
- 영역: `grimoire-server/src/adapter/outbound/persistence/audit-mask-helper.ts`
- 영역: `grimoire-server/src/scheduler/audit-mask.scheduler.ts`
- @Cron('0 0 3 * * *') — 매일 03:00 KST
- 90일 경과 + maskedAt IS NULL row → 마스킹 + maskedAt 갱신 + retentionTier=MASKED
- DELETE 호출 0건 강제 (영구 보존)

### §4-5. 단계 5: spec + sensor + eval + shared-contracts §26
- jest server 669 → 682+ (audit-mask-helper.spec.ts 8 it + audit-mask.scheduler.spec.ts 5 it)
- sensor-audit-retention-policy.sh (12 검증)
- eval regression-70 (11 criteria)
- shared-contracts §26 AuditRetentionPolicy 박제

### §4-6. 단계 6: dev migration apply (사용자 명시 영역)
- 명시 키워드: `PAY-P2-5 dev migration 진행`
- `npx prisma migrate deploy`
- 직후 검증: maskedAt + retentionTier 컬럼 확인 + jest 682 PASS

### §4-7. 단계 7: dev cron 직접 호출 검증 (선택)
- 명시 키워드: `PAY-P2-5 dev cron 직접 호출 진행`
- 90일 경과 row 0건 시 noop 정합 검증

### §4-8. 단계 8: dev 24h 자연 누적 검증
- 명시 키워드: `PAY-P2-5 dev 24h 안정성 박제 통과`
- cron 03:00 KST 1회 실행 + logs 박제

### §4-9. 단계 9: prod migration (사용자 명시 영역)
- 명시 키워드: `PAY-P2-5 prod migration 진행`
- prod 90일 경과 row 측정 → 백업 → migration → cron 자연 누적

## §5. AC (Acceptance Criteria, BDD 8건)

1. **AC-1**: AdminAuditLog row 90일 경과 시 자동 마스킹 + 영구 보존 (DELETE 0건)
2. **AC-2**: 마스킹 멱등성 (이미 마스킹된 row 재실행 시 변경 0건)
3. **AC-3**: 영구 보존 (90일 경과 row 삭제 0건, 사용자 결정 D 정합)
4. **AC-4**: PII 자동 검출 + 마스킹 적용 (audit-mask-helper 정합)
5. **AC-5**: AccessLog email + ip + userAgent + detail 마스킹 정합
6. **AC-6**: WebhookEvent + WebhookRetryQueue payload JSON deep masking 정합
7. **AC-7**: cron 실행 실패 시 incident-log 박제 강제
8. **AC-8**: 사용자 식별자 (userId/authorId/adminId) 보존 강제 (audit 본질 정합)

## §6. 검증 매트릭스

- jest server: 669 → **682+ PASS** (회귀 0)
  - `audit-mask-helper.spec.ts` ≥8 it
  - `audit-mask.scheduler.spec.ts` ≥5 it
- eval regression: 69 → **70 PASS** (regression-70-audit-retention-policy 신설, 11 검증)
- sensor: 47 → **48 PASS** (sensor-audit-retention-policy.sh 신설, 12 검증)
- shared-contracts: §1~25 → **§1~26** (AuditRetentionPolicy 신설)

## §7. 위험 분석

- **시나리오 A**: 90일 경과 row 0건 (이상적, dev 환경 가능성 높음)
- **시나리오 B**: 90일 경과 row N>0 (현실적, prod 가능성 ≥ 50%) — cron 실행 시간 검토 (N=100/10K/100K)
- **시나리오 C**: 마스킹 도중 race condition — 90일 경과 row만 정합 (race condition 0건)
- **시나리오 D**: helper false positive — 보존 키 매트릭스 보강 강제 (id/authorId/adminId/action/createdAt/amount/credits 등)

## §8. 사용자 검증 게이트 (10 단계 명시 키워드)

| 단계 | 명시 키워드 |
|---|---|
| 1 | (자동, server agent) 단계 1 dev 측정 |
| 2 | `PAY-P2-5 dev 백업 박제 완료` |
| 3 | `PAY-P2-5 dev migration 진행` |
| 4 | `PAY-P2-5 dev cron 직접 호출 진행` (선택) |
| 5 | `PAY-P2-5 dev 24h 안정성 박제 통과` |
| 6 | `PAY-P2-5 prod 90일 경과 row 측정 진행` |
| 7 | `PAY-P2-5 prod 백업 박제 완료` |
| 8 | `PAY-P2-5 prod 트래픽 영역 검토 통과` |
| 9 | `PAY-P2-5 prod migration 진행` |
| 10 | `claude-docs main 머지 진행` / `server main 머지 진행` |

## §9. 멀티에이전트 위임 매트릭스

| agent | 역할 | 영역 |
|---|---|---|
| grimoire-planner | Initializer | 본 Sprint 계약 |
| grimoire-harness | 박제 | `.claude/state/sprint-pay-p2-5-*` + sensor 신설 |
| grimoire-server | Generator | schema + migration + helper + scheduler + port + adapter + spec |
| grimoire-infrastructure | 협업 | DB measurement (단계 1) + Container Apps Healthy + dev/prod migration apply |
| grimoire-qa | Evaluator | AC 8건 채점 + jest/eval/sensor PASS 검증 |
| cost-accountant | **면제** | 외부 API 추가 0 |
| visual-canon-keeper | **면제** | UI 변경 0 |

## §10. 사용자 결정 영역 (자율 변경 차단)

- **옵션 D 강제 (5/10)**: 영구 보존 + 마스킹, 변경 불가
- **EmailServicePort 인터페이스 영역만 (5/10)**: NullEmailAdapter (logger.warn만, 실제 SaaS 어댑터 0)
- **삭제 cron 0건 강제**: DELETE 호출 0건 (audit-mask.scheduler 영역)
- **prod 진입 영역**: 단계 6~9 사용자 명시 키워드 강제

## §11. ADR-008 박제 (Architecture Decision Record)

- **제목**: audit log 영구 보존 + PII 마스킹 정책
- **상태**: ACCEPTED (2026-05-10 사용자 결정)
- **컨텍스트**: 전자상거래법 5년 + PIPA 마스킹 의무
- **결정**: 영구 보존 + 90일 후 PII 마스킹 (삭제 cron 0건)
- **결과**: audit gap 0 + 법적 정합 + 사용자 식별 보존

## §12. Definition of Done

- [ ] jest server 682+ PASS
- [ ] eval 70 PASS
- [ ] sensor 48 PASS
- [ ] shared-contracts §26 박제
- [ ] AC 8건 PASS
- [ ] incident-log ≥ 2건 박제 (audit_retention_migration_dev 직전 + 직후)
- [ ] DELETE 호출 0건 강제 (audit-mask.scheduler 영역)
- [ ] PII 7 키 박제 + 보존 키 매트릭스 박제
- [ ] dev 24h 자연 누적 검증 PASS

## §13. 영향 매트릭스 (3 레포)

| 레포 | 영향 | 변경 line 추정 |
|---|---|---:|
| grimoire-server | schema + migration + helper + scheduler + port + adapter + spec | ~600 |
| grimoire-web | data-model.md sync | ~30 |
| grimoire-claude-docs | shared-contracts §26 + ADR-008 + sensor + eval task + state | ~400 |

## §14. 의존성 + 후속 작업

- **선행 영역**: PAY-P3-E §7-1 단계 1~6 종료 (5/10), PAY-P2-4 정합 (audit log 6-arg)
- **후속 sprint**: PAY-P3-H Circuit breaker (외부 API 0, 사용자 1~6 순서 2번째)
- **결합 가능**: USER-SOFT-DELETE (마스킹 패턴 재사용)

## §15. shared-contracts §26 AuditRetentionPolicy 인터페이스

```typescript
export interface AuditRetentionPolicy {
  /** 90일 경과 + 미마스킹 row 검색 */
  findRowsToMask(model: AuditModel, beforeDate: Date): Promise<AuditRow[]>;

  /** PII 키 자동 마스킹 (멱등성 강제) */
  maskRow(rowId: string, maskingRules: MaskingRules): Promise<void>;

  /** 마스킹 cron 실행 (매일 03:00 KST) */
  scheduleMaskCron(): Promise<MaskingResult>;

  /** 보존 정책 조회 (영구 + 마스킹 90일) */
  getRetentionTier(rowId: string): Promise<'active' | 'masked' | 'archived'>;
}

export type AuditModel = 'AdminAuditLog' | 'WebhookEvent' | 'WebhookRetryQueue' | 'AccessLog';

export interface MaskingRules {
  piiKeys: ('email' | 'phone' | 'ipAddress' | 'userAgent' | 'passwordHash' | 'token' | 'secret')[];
  preservedKeys: string[];
  jsonDeepMasking: boolean;
}

export interface MaskingResult {
  modelsProcessed: AuditModel[];
  rowsMasked: number;
  rowsSkipped: number;
  errors: { rowId: string; error: string }[];
}
```

## §16. 변경 이력

- 2026-05-10 #10_8: 본 Sprint 계약 Draft 신설 (grimoire-planner Initializer + 메인 직접 박제, PP-7+PP-12+PP-13 size 0 폐기 정합). 사용자 결정 옵션 D (영구 + 마스킹) + 순서 1번째 + EmailServicePort 인터페이스 영역만.

## §17. 정본 참조 (file:line)

- `/Users/sokol/Git/ProjectGrimoire/research/PAYMENT_AUDIT-2026-05-07.md` §3 L84-85 + §4 P2 P0 L120-123
- `/Users/sokol/Git/ProjectGrimoire/research/PAYMENT_SYSTEM_PLAN.md` §3-3 P2-3 L382-389
- `/Users/sokol/Git/ProjectGrimoire/.claude/state/sprint-pay-p3-e-fk-cascade-draft.md` (1234 lines, 17 섹션 정본)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/prisma/schema.prisma` L448-460 (AdminAuditLog) / L261-273 (WebhookEvent) / L507-518 (WebhookRetryQueue) / L389-404 (AccessLog)
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/src/adapter/outbound/persistence/prisma-audit-log.repository.ts` L1-37
- `/Users/sokol/Git/ProjectGrimoire/grimoire-server/src/application/admin/audit-log.service.ts` L23-45 (PAY-P2-4 정합)
- `/Users/sokol/Git/ProjectGrimoire/.claude/shared-contracts.md` §20 L1215-1283 (AdminAuditLog beforeState/afterState)
