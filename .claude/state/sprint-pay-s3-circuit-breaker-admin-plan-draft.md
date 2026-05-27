# 작업 계획: PAY-S3 — Circuit Breaker 운영자 admin UI (writing-plans)

> 작성: 2026-05-23 / grimoire-planner (Initializer 패턴) / **계획 수립 전용 — 코드 변경 0건**
> 근거 정본: `grimoire-server/ADR.md ADR-009`(Polar SDK 호출 경계 Circuit Breaker, PAY-P3-H 종료) §"잔존 영역"
>           + `.claude/shared-contracts.md §27 CircuitBreakerPolicy`(시그니처·상태머신·env 4건·AuditLog 4 action 정본)
>           + `grimoire-server/src/adapter/outbound/circuit-breaker/in-memory-circuit-breaker.adapter.ts`(`forceOpen`/`forceClose` port 메서드 박제됨, **HTTP 노출 0건**)
>           + `.claude/scripts/sensor-circuit-breaker-policy.sh`(10 검증 PASS — 회귀 0 게이트)
>           + `grimoire-server/src/adapter/inbound/http/controller/admin.controller.ts`(JwtAuthGuard+AdminGuard+@Throttle 패턴)
>           + `grimoire-web/src/app/admin/page.tsx`(14탭 admin 패널 구성) + `tabs/PaymentsTab.tsx`/`AccessLogsTab.tsx`(테이블·필터·CSV 패턴)
> 적용 양식: `.claude/skills/writing-plans/SKILL.md`(2~5분 sub-task / [MUST]·[SHOULD]·[NICE] / 위험도 🔴🟡🟢 / 의존 / 검증 게이트)
> 구조 정본: `.claude/state/sprint-cc5-subscription-plan-draft.md`(CC-5 38 sub-task 패턴 — 동일 섹션 구조·포맷)
> 범위: **PAY-S3 (Circuit Breaker 운영자 admin UI, 규모 M)** 단일 sprint. 로직 변경 0 / 새 시각 정본 신설 0 / 마이그레이션 0 (조건부 ≤1건, §10 게이트).

---

## 0. 진행 순서 + 의존 개요

```
PAY-P3-H (Circuit Breaker 자체 prod 적용 완료, ADR-009/§27 박제) ──선행 완료──> PAY-S3
          │
          ├── port 박제 완료: forceOpen / forceClose / getState / getStats (HTTP 노출 0건이 현 결손)
          ├── AuditLog 4 action 박제 완료 (auto 전이 — open/close/half_open_trial/reject)
          └── sensor-circuit-breaker-policy 10/10 PASS (회귀 차단 게이트 활성)

                          ┌── S0 선행: §1 미확인 6건 Read 해소 ────┐
                          │                                       │
        ┌─────────────────┴──────────────────┬───────────────────┐
   Phase A — server               Phase B — web               Phase C — VCK + qa
   (admin endpoint 3 +            (기존 admin 14탭 내           (사슴악마 정본 검증 +
    AuditLog 박제 강화 +           Circuit Breaker 패널 +        qa 8 게이트 +
    @Throttle + DTO + spec)        confirm 다이얼로그 + spec)    shared-contracts §27 갱신)
        │                              │                              │
        └──────────────────────────────┴──────────────────────────────┘
                          sensor-circuit-breaker-policy 회귀 0 게이트 (Phase 전체 종속)
```

- **PAY-P3-H 선행 완료** — 2026-05-15 종결, `04b3f5c`+`71db1ec` server prod rev 108 적용. ADR-009·§27 박제. PAY-S3는 ADR-009 §"잔존 영역" 4번째 항목("관리자 UI (forceOpen/forceClose) — P3-I 별도 sprint 분리, port 인터페이스만 본 sprint 박제") 해소가 본질.
- **port·AuditLog는 이미 박제 — HTTP/UI만 신설** — `in-memory-circuit-breaker.adapter.ts:337-381` `forceOpen`/`forceClose` 구현됨. AuditLog `circuit_breaker.open`/`close`/`half_open_trial`/`reject` 4 action도 박제. **PAY-S3는 port 위에 admin HTTP·web UI 얹는 것뿐 — 새 도메인 로직 0건**.
- **S0 선행 게이트** — port 시그니처·AuditLog action·admin.controller 권한 패턴·기존 admin 탭 배치 정합을 server 착수 전 재실측(추정 금지). 진단·계획 작성 중 5건 확인 완료(C1a~C1e) → S0는 server가 실측 재확인.
- **Phase 분할** — server(Phase A) → web(Phase B) → VCK+qa(Phase C) 순차. Phase A·B 사이 의존 = shared-contracts §27 갱신(server가 endpoint 명세 갱신 → web이 참조). Phase A 단독으로도 머지 가능(curl로 운영 가능 상태). Phase B는 Phase A 머지 후 진입.
- **§0 원가 게이트 불요** — Circuit Breaker는 인프라 가용성 영역, LLM 호출 0건. cost-accountant 게이트 0건. VCK 게이트는 web Phase B에서 필수.

### 예상 총 시간

- PAY-S3: **규모 M** — 본 계획 sub-task 합산 ~6.5~9h.
- sub-task 총 **24개** (S0 6 + Phase A server 9 + Phase B web 6 + Phase C VCK+qa 3).
- **분할 근거**: ≥30분 + **운영 안전 도메인**(파괴적 액션 `forceOpen`/`forceClose` 수동 노출, 사고 시 사용 — 잘못 트리거 시 결제 차단 직결) + 신 endpoint 3건 권한 가드 누락 1건 = SECURITY.md §4 위반 + AuditLog 박제 누락 시 운영자 행위 추적 불가 → sub-task 단위 검증 게이트 + git commit 단위 rollback 필수.

---

## 1. S0 — 선행: port·AuditLog·admin 패턴·web 배치 미확인 6건 현행 해소 (착수 게이트)

> ADR-009 §"잔존 영역" 4번째 항목 + §27 시그니처 — 추정 금지. port 시그니처는 진단·계획 작성 중 5건 확인했으나 server 착수 시점 현행 재실측.

### 1-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| S1a | `CircuitBreakerPort` 시그니처 현행 Read — `circuit-breaker.port.ts` `getState(key)`/`getStats(key)`/`forceOpen(key,reason)`/`forceClose(key,reason)`/`execute(key,fn)` 5 메서드 확정. **port에 trip 메서드 별도 없음, forceOpen이 trip 역할 — admin 엔드포인트는 `forceOpen("manual_trip:{reason}")` 호출로 trip 구현** | [MUST] | 🟢 | 4분 | - | port 5 메서드 시그니처 + trip=forceOpen 매핑 박제 |
| S1b | `InMemoryCircuitBreakerAdapter` `forceOpen`/`forceClose` 동작 Read — adapter `:337-381` 본문 재확인. AuditLog 박제 reason 패턴(`manual_force_open: {reason}` / `manual_force_close: {reason}`) 확정 → admin 호출 시 reason 전달 규약 박제 | [MUST] | 🟢 | 5분 | - | `forceOpen`/`forceClose` reason 박제 규약 박제 |
| S1c | `CircuitBreakerStats` 시그니처 + 응답 DTO 매핑 Read — `circuit-breaker-state.ts` Stats 7 필드(`state`/`failureCount`/`openedAt?`/`halfOpenAt?`/`halfOpenTrialCount`/`halfOpenSuccessCount`/`lastSuccessAt?`/`lastFailureAt?`) 확인. **내부 ID·secret 노출 0건 — 단 circuitKey(`polar:checkouts:create` 등)는 운영 식별자 — 노출 허용**. policy 4 env 값 응답 노출 여부 결정 게이트 | [MUST] | 🟡 | 5분 | - | Stats 7 필드 + circuitKey 노출 정책 + policy 응답 포함 여부 박제 |
| S1d | `AdminController` 권한 패턴 + AuditLogService 시그니처 Read — `admin.controller.ts` `@UseGuards(JwtAuthGuard, AdminGuard)` + `@Throttle({ default: { ttl: 60000, limit: N } })` 패턴 확인. `audit-log.service.ts` `log(adminId, action, targetId?, detail?, beforeState?, afterState?)` 6-arg 시그니처 + §20 beforeState/afterState 규약 확정 | [MUST] | 🟢 | 5분 | - | admin 권한·Throttle·AuditLog 6-arg 패턴 박제 |
| S1e | 기존 admin 14탭 구성 + 배치 결정 Read — `admin/page.tsx` Tab type 16 값(stats/authors/users/works/sanctions/reports/comments/payments/revenue/credits/announcements/featured/themes/access/settings/audit) 확인. **PAY-S3 배치 권고 = "settings" 탭 내 sub-section 또는 "payments" 탭 내 sub-section** — 새 탭 신설 회피(VCK §9-3 정합) → C2a가 최종 결정 | [MUST] | 🟢 | 5분 | - | 기존 14탭 + 배치 후보 2안(settings vs payments) 박제 |
| S1f | AuditLog action 박제 정책 — 수동 trip/reset 시 action 명명 결정. 기존 4 action(`circuit_breaker.open`/`close`/`half_open_trial`/`reject`)는 **adapter 내부 auto + force 모두 박제 중**(`forceOpen` reason="manual_force_open" + open action). admin controller는 **이중 박제 방지** 필요 — controller 박제 0 / adapter 박제 1 (현재 패턴 유지) vs controller 박제 추가(operator_id 별도 강조). **권고: controller 박제 추가 `circuit_breaker.manual_trip` / `circuit_breaker.manual_reset` 2 신 action — adapter의 `circuit_breaker.open`/`close`와 함께 박제(이중 박제 의도적 — operator 행위 박제 강조). beforeState/afterState §20 정합** | [MUST] | 🟡 | 6분 | S1d | controller 신 2 action + adapter 4 action 정합 박제 |

**S0 게이트**: S1a~S1f [MUST] 6건 완료 = port·adapter·admin 패턴·web 14탭·AuditLog 정책 현행 해소 → Phase A 진입 허가. 미확인 잔존 시 본 작업 착수 금지.

---

## 2. sprint 분할 권고 — PAY-S3(M) 단일 sprint 3 Phase

> 사용자 지시 "pay s3 하자" — server+web+VCK+qa 일괄 진행. planner가 단일 sprint vs 분리 권고.

### 2-1. 권고 — **단일 sprint·3 Phase** (server / web / VCK+qa 분할 안 함)

| 案 | 구조 | 장점 | 단점 |
|---|---|---|---|
| 案 ① 분리 — server / web 별도 sprint | server 머지 → web 별도 착수 | sprint 단위 작음, server 단독으로도 curl 운영 가능 | **server 단독 머지는 UI 부재 — 운영자가 curl 못 쓰는 상황에서 무용**. ADR-009 §"잔존 영역" 4번째 항목 = "관리자 UI" 단일 항목 — server+web을 하나로 보는 게 ADR 의도와 정합 |
| **案 ② 단일 sprint·3 Phase (권고)** | Phase A(server) → Phase B(web) → Phase C(VCK+qa) 순차 | shared-contracts §27 단일 commit 갱신, web sprint 별도 일정 회피, ADR-009 §"잔존 영역" 1건 1 sprint로 깨끗하게 닫힘 | sub-task 24개 — Phase 게이트로 분할 진척 관리 |

**권고 — 案 ② (단일 sprint, Phase A·B·C 3 Phase)**. 사유:

1. **ADR-009 §"잔존 영역" 4번째 항목이 "관리자 UI" 단일 단위** — server endpoint와 web UI를 분리하면 ADR 항목 절반만 닫힘. 사용자가 "pay s3 하자" 단일 지시 = ADR 항목 단일 닫힘 기대.
2. **shared-contracts §27 갱신 단일 commit** — Phase A에서 `getState`/`forceOpen`/`forceClose` HTTP 노출 박제 → Phase B web도 동일 commit cycle 안에 정합 검증. 분리하면 §27 갱신 2회(server PR / web PR).
3. **VCK 게이트가 web 종속** — VCK는 web Phase B 완료 후 검수 가능. server만 분리하면 VCK 게이트 자체가 web sprint로 이월 → ADR 항목 미완 상태로 머지.
4. **규모는 Phase 게이트로 관리** — 24 sub-task는 CC-5(38)보다 작음. Phase A 게이트 / Phase B 게이트 / Phase C 게이트로 분할 진척 추적(progress.md).
5. **server 단독 의미 보장** — Phase A 완료 시점에 server만으로도 curl 운영 가능 — UI 부재가 차단 요인 아님(메인이 사고 대응 시 curl로 즉시 가능). 단 사용자 의도는 UI 보장.

> Phase A·B는 git commit 단위 점진 머지 가능 — Phase A 머지 후 web Phase B 진입 권장(shared-contracts §27이 web의 입력).

---

## 3. 마이그레이션 게이트 — 권장 0건 (조건부 ≤1건)

> 사용자 제약 — "마이그레이션 권장 0건. AdminAuditLog 컬럼 확장 불가피 시 ≤1건 + back-fill 안전(`DEFAULT NULL`)."

### 3-1. 판정 — **마이그레이션 0건 (현재 스키마로 충분)**

| 후보 | 현황 | 판정 |
|---|---|---|
| AdminAuditLog 신 action 박제 (`circuit_breaker.manual_trip`/`manual_reset`) | 기존 `admin_audit_logs.action String` 컬럼 — enum 아님, 자유 문자열 | ✅ **마이그레이션 0건** — String 컬럼이라 새 action 값 박제만으로 충분. enum 변환 불요 |
| AdminAuditLog operator_id 박제 | 기존 `admin_audit_logs.adminId String` 컬럼 — `AuditLogService.log(adminId, action, ...)` 1번째 인자가 operator_id 자체. 본 sprint는 `req.user.sub` 전달 | ✅ **컬럼 존재 — 마이그레이션 0건** |
| AdminAuditLog reason 박제 | 기존 `admin_audit_logs.detail Json?` 컬럼 — JSON 안에 `reason: "..."` 박제(adapter의 `forceOpen` 패턴 정합) | ✅ **JSON 컬럼 활용 — 마이그레이션 0건** |
| CircuitBreaker DB 모델 추가 | sensor `sensor-circuit-breaker-policy.sh [10/10]` "schema.prisma circuit breaker 모델 추가 0건 강제 (사용자 5/10 정합 위반)" — **추가 시 sensor FAIL** | ✅ **마이그레이션 절대 0건** — 사용자 5/10 정합 + sensor 회귀 차단 |

→ **PAY-S3 마이그레이션 0건 확정**. 기존 `admin_audit_logs` 스키마(adminId + action + targetId + detail JSON)로 신 action 박제 + operator_id + reason 모두 수용 가능. AuditLogService 6-arg 시그니처가 beforeState/afterState 추가 박제까지 지원(§20 정합).

### 3-2. 조건부 마이그레이션 회피 게이트

- 만약 server 착수 중 "AdminAuditLog detail Json?로 부족하다"는 결손이 발견되면 → planner에게 게이트 회귀(중단). 추가 컬럼 신설 검토.
- 본 계획 작성 시점 판정: 기존 스키마 충분 — Phase A 진행 가능.

---

## 4. graceful 설계 — Circuit Breaker UI는 항시 가용 + 파괴적 액션 확인 게이트

### 4-1. graceful 설계 결정 (Phase A 첫 sub-task에서 명문화)

| 기능 경로 | 동작 |
|---|---|
| `GET /admin/circuit-breaker/state` | **항시 가용** — 호출 비용 0, 운영자가 상시 모니터링 가능. `CircuitBreakerPort.getStats(key)` 호출만 — 외부 API 0 |
| `POST /admin/circuit-breaker/reset` | **확인 게이트 필수** — web 다이얼로그 `confirm("Circuit Breaker {key} 강제 복구 — 확인?")` + reason 텍스트 입력 필수. server는 reason 빈값 시 400 BadRequest |
| `POST /admin/circuit-breaker/trip` | **확인 게이트 필수** — web 다이얼로그 `confirm("⚠️ {key} Circuit Breaker 강제 차단 — 결제 즉시 503 됩니다. 확인?")` + reason 텍스트 필수. server reason 검증 동일 |
| 권한 가드 누락 시 | **401/403** — `JwtAuthGuard` 미통과 401 / `AdminGuard` 미통과 403. spec C8a~C8b 강제 |
| Circuit Breaker port 미주입 시 | **500** — DI 미해결 시 fail-fast. 운영상 발생 0건 (`app.module.ts` 박제됨) |

→ **핵심 원칙**: 조회는 항시 가용, 파괴적 액션은 web confirm + server reason 필수. 운영자가 실수로 trip/reset 호출 시 명확한 게이트.

### 4-2. graceful 구현 패턴

- `POST /admin/circuit-breaker/reset` body — `{ key: string, reason: string }`. reason 빈값/공백만 시 `BadRequestException('Circuit Breaker 수동 복구 시 사유(reason) 필수')` — `admin.controller.ts:175-177` 패턴(`anonymizeAuthor` reason 검증) 차용.
- `POST /admin/circuit-breaker/trip` body — 동일. reason 메시지 한국어 "Circuit Breaker 수동 차단 시 사유(reason) 필수".
- key 화이트리스트 — `polar:checkouts:create`/`polar:checkouts:list` 2값만 허용(`§27` "호출점별 분리 매트릭스" 정합). 그 외 key 입력 시 `BadRequestException('지원하지 않는 Circuit Breaker key')` — 운영자 오타 방어.
- @Throttle — 운영자 호출 빈도 상한. `POST /reset`·`POST /trip`은 `{ ttl: 60000, limit: 5 }`(분당 5회) — `admin.controller.ts:144` `force-delete` 패턴 차용. `GET /state`는 `{ ttl: 60000, limit: 60 }`(분당 60회 — 운영 폴링 허용).

---

## 5. Phase A — server: admin endpoint 3 + DTO + spec + AuditLog 강화

> ADR-009 §"잔존 영역" 4 + §27 시그니처. CircuitBreakerPort는 박제 완료 — admin HTTP 엔드포인트 신설 + AuditLog 박제 강화.

### 5-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C2a | graceful 설계 + 배치 결정 명문화 — 본 계획 §4·§1 S1e를 Phase A 설계 입력으로 박제. admin endpoint 3 신설 위치 = `admin.controller.ts` 신 메서드 3개(별도 controller 분리 안 함 — admin 14탭 권한 패턴 정합) | [MUST] | 🟢 | 4분 | S0 게이트 | §4 graceful 설계 + admin.controller.ts 내 신설 박제 |
| C2b | DTO 설계 — `dto/circuit-breaker.dto.ts` 신설: `CircuitBreakerStateResponseDto`(key·state·failureCount·openedAt?·halfOpenAt?·halfOpenTrialCount·halfOpenSuccessCount·lastSuccessAt?·lastFailureAt?·policy{4 env값}) + `CircuitBreakerActionDto`(key: 'polar:checkouts:create'\|'polar:checkouts:list', reason: string min 1자). 내부 ID 노출 0건 정합(`circuitKey`는 운영 식별자 — 노출 허용 §S1c) | [MUST] | 🟡 | 6분 | C2a | tsc PASS + DTO 정의 박제 |
| C2c | `GET /admin/circuit-breaker/state` 엔드포인트 — `@UseGuards(JwtAuthGuard, AdminGuard)` + `@Throttle({ default: { ttl: 60000, limit: 60 } })`. Query param `key?` — 미지정 시 2 호출점 모두 반환 `{ states: CircuitBreakerStateResponseDto[] }` / 지정 시 단일 state. `CircuitBreakerPort.getStats(key)` 호출 → DTO 매핑. policy 4 env 값(`POLAR_CB_*`)도 응답 포함 — 운영자 정책 가시화 | [MUST] | 🟡 | 7분 | C2b | tsc PASS + 컨트롤러 박제 |
| C2d | `POST /admin/circuit-breaker/reset` 엔드포인트 — `@UseGuards(JwtAuthGuard, AdminGuard)` + `@Throttle({ default: { ttl: 60000, limit: 5 } })`. Body `CircuitBreakerActionDto`. reason 빈값 검증 → 400. key 화이트리스트 검증 → 400. `forceClose(key, "operator:{adminId}:{reason}")` 호출 + AuditLog `circuit_breaker.manual_reset` 박제(operator_id=adminId, reason, beforeState=getStats 전, afterState=getStats 후) | [MUST] | 🔴 | 8분 | C2c | tsc PASS + 컨트롤러 박제 + AuditLog 박제 시그니처 정합 |
| C2e | `POST /admin/circuit-breaker/trip` 엔드포인트 — 동일 패턴 + `forceOpen(key, "operator:{adminId}:{reason}")` 호출 + AuditLog `circuit_breaker.manual_trip` 박제. **⚠️ 파괴적 액션 강조** — 컨트롤러 메서드 주석에 "운영자 수동 차단 — 결제 즉시 503 변환 / 사고 대응·연습 전용" 박제 | [MUST] | 🔴 | 8분 | C2d | tsc PASS + 컨트롤러 박제 + AuditLog 박제 |
| C2f | AdminController DI 추가 — `CircuitBreakerPort` 주입 + `AuditLogService` 주입(기존 또는 신규 — admin.usecase 경유 여부 결정). **권고**: admin.usecase에 `getCircuitBreakerState`/`resetCircuitBreaker`/`tripCircuitBreaker` 3 메서드 신설 → 컨트롤러는 usecase 위임만(Hexagonal application layer 정합) | [MUST] | 🟡 | 6분 | C2e | tsc PASS + DI 박제 + usecase 위임 패턴 정합 |
| C2g | admin.usecase 메서드 spec — `admin.usecase.spec.ts` 보강: `getCircuitBreakerState`(mock CircuitBreakerPort.getStats 호출 검증) + `resetCircuitBreaker`(forceClose 호출 + AuditLog 호출 인자 검증) + `tripCircuitBreaker`(forceOpen 호출 + AuditLog 호출 + beforeState/afterState §20 정합) | [MUST] | 🟡 | 8분 | C2f | `npm test admin.usecase.spec` PASS |
| C2h | admin.controller spec — `admin.controller.spec.ts` 신 3 엔드포인트 검증: ① Guard 미인증 401 ② AdminGuard 비-admin role 403 ③ Throttle 6번째 호출 429 ④ reason 빈값 400 ⑤ key 화이트리스트 외 입력 400 ⑥ 정상 시 DTO 응답 ⑦ 내부 ID 노출 0건 검증(authorId/secret 응답 없음) | [MUST] | 🔴 | 10분 | C2g | `npm test admin.controller.spec` PASS — 7 케이스 |
| C2i | sensor 회귀 0 — `sensor-circuit-breaker-policy.sh` 실행 → 10/10 PASS 유지(본 sprint 변경 0건 정합). 기존 4 action 박제 회귀 0건 검증 + 신 2 action(`manual_trip`/`manual_reset`)은 sensor 검증 외(admin 영역) — 별도 sensor 신설 불요(spec C2h가 검증) | [MUST] | 🟢 | 3분 | C2h | sensor-circuit-breaker-policy 10/10 PASS |

**Phase A 게이트**: C2a~C2i [MUST] 9건 완료 = admin endpoint 3 + AuditLog 신 2 action + spec 7 케이스 → Phase B 진입 허가.

### 5-2. admin endpoint 3 시그니처 (planner 결정 — C2b 산출)

```typescript
// GET /admin/circuit-breaker/state?key=polar:checkouts:create
// 응답: { states: CircuitBreakerStateResponseDto[] } (key 미지정) 또는 단일 DTO
interface CircuitBreakerStateResponseDto {
  key: 'polar:checkouts:create' | 'polar:checkouts:list'
  state: 'closed' | 'open' | 'half_open'
  failureCount: number
  openedAt?: string  // ISO 8601
  halfOpenAt?: string
  halfOpenTrialCount: number
  halfOpenSuccessCount: number
  lastSuccessAt?: string
  lastFailureAt?: string
  policy: {
    failureThreshold: number  // POLAR_CB_FAILURE_THRESHOLD
    cooldownMs: number         // POLAR_CB_COOLDOWN_MS
    halfOpenTrial: number      // POLAR_CB_HALF_OPEN_TRIAL
    resetWindowMs: number      // POLAR_CB_RESET_WINDOW_MS
  }
}

// POST /admin/circuit-breaker/reset
// POST /admin/circuit-breaker/trip
// Body
interface CircuitBreakerActionDto {
  key: 'polar:checkouts:create' | 'polar:checkouts:list'
  reason: string  // min 1자 — BadRequest if empty
}
// 응답: { success: true, beforeState: state, afterState: state }
```

---

## 6. Phase B — web: 기존 admin 14탭 내 Circuit Breaker 패널 + spec

> 새 시각 정본 신설 금지. 기존 admin 14탭(PaymentsTab/SettingsTab 등) 패턴 정합 + 사슴악마 색상 토큰 종속.

### 6-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C3a | 배치 최종 결정 — S1e 후보 2안(settings vs payments) 中 **권고 "settings"** — Circuit Breaker는 인프라/시스템 영역, settings 탭이 정합. payments 탭은 결제 데이터 영역(Polar checkout 목록·환불 등). 사용자/VCK 사전 자문 1줄 — 변경 시 C3b 컴포넌트 위치만 이동(로직 영향 0) | [MUST] | 🟢 | 3분 | Phase A 게이트 | 배치 결정 + VCK 자문 박제 |
| C3b | `CircuitBreakerPanel.tsx` 컴포넌트 신설 — `src/app/admin/tabs/components/CircuitBreakerPanel.tsx`(권장) 또는 `SettingsTab` 내 inline. 상태: 2 호출점(`polar:checkouts:create`/`polar:checkouts:list`) state 폴링 30초 + manual refresh 버튼. 상태 배지: CLOSED=`bg-green-900/50 text-green-400` / OPEN=`bg-red-900/50 text-red-400` / HALF_OPEN=`bg-yellow-900/50 text-yellow-400`(AccessLogsTab ACTION_COLORS 패턴 정합 — 사슴악마 neutral-*/g-* 토큰 종속). 메트릭 표시: failureCount / lastFailureAt / openedAt / policy 4 env값 | [MUST] | 🟡 | 12분 | C3a | tsc PASS + 컴포넌트 박제 |
| C3c | 수동 조작 버튼 + confirm 다이얼로그 — "강제 복구(Reset)"/"강제 차단(Trip)" 버튼 2개. 클릭 시 `window.confirm` + reason 입력 prompt(또는 modal 다이얼로그 — 권고 modal). reason 빈값 시 client-side 차단. **Trip 버튼은 빨간 배경 + "⚠️" 경고 텍스트** — 파괴적 액션 시각 강조. confirm 통과 → `api.adminCircuitBreakerReset(key, reason)`/`Trip(key, reason)` 호출 → 성공 시 panel 자동 refresh | [MUST] | 🔴 | 10분 | C3b | tsc PASS + confirm 다이얼로그 박제 |
| C3d | `api.ts` 신 3 메서드 — `adminGetCircuitBreakerState(key?)` / `adminResetCircuitBreaker(key, reason)` / `adminTripCircuitBreaker(key, reason)`. BFF 프록시 경유(`/api/admin/circuit-breaker/*`) — Next.js `src/app/api/[...path]/route.ts` 패턴 정합, 신 라우트 신설 불요(catchall) | [MUST] | 🟡 | 6분 | C3c | tsc PASS + 3 메서드 박제 |
| C3e | `SettingsTab` 통합 — 기존 `SettingsTab.tsx`에 `<CircuitBreakerPanel />` import + 렌더링. 기존 settings 항목과 시각 분리(섹션 헤더 "결제 인프라 — Circuit Breaker"). 새 tab 신설 0건 정합 | [MUST] | 🟢 | 4분 | C3d | tsc PASS + SettingsTab 통합 |
| C3f | Vitest spec — `CircuitBreakerPanel.test.tsx` 신설: ① 초기 로딩 ② state 표시(3 상태별 배지) ③ Reset 버튼 confirm 다이얼로그 ④ Trip 버튼 ⚠️ 경고 + confirm ⑤ reason 빈값 클라이언트 차단 ⑥ API 호출 mock 검증. 기존 admin tab 테스트 패턴(CreditsTab.test.tsx) 차용 | [MUST] | 🟡 | 10분 | C3e | `npm test CircuitBreakerPanel.test` PASS — 6 케이스 |

**Phase B 게이트**: C3a~C3f [MUST] 6건 완료 = Circuit Breaker UI + confirm 다이얼로그 + Vitest 6 케이스 → Phase C 진입 허가.

### 6-2. 배치 권고 (planner 결정 — C3a 산출)

**권고 — SettingsTab 내 sub-section "결제 인프라"**. 사유:
1. **인프라/시스템 영역** — Circuit Breaker는 결제 데이터(payments 탭 = checkout/refund 목록)가 아니라 가용성 정책 영역 → settings 정합.
2. **새 탭 신설 회피** — TAB_LABELS 16값 유지 = 새 시각 정본 신설 0건 정합(사용자 제약 + VCK).
3. **운영자 사용 빈도 낮음** — 사고·연습 시만 사용 → 14탭 항시 노출 불필요, settings 내 sub-section이 정합.
4. **payments 탭은 결제 데이터 전용** — Polar checkout/환불 목록 등이 차지. Circuit Breaker는 영역이 다름.

> 단 사용자가 "payments 탭이 더 정합"이라 판단 시 컴포넌트 위치만 이동(로직 0 영향) — C3a sub-task에서 사용자/VCK 자문 1줄.

---

## 7. Phase C — VCK + qa + shared-contracts §27 갱신

### 7-1. sub-task 표

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C4a | shared-contracts §27 갱신 — admin endpoint 3 신설 + DTO 2종 + AuditLog 신 2 action(`manual_trip`/`manual_reset`) 박제. §27 "잔존 영역" 4번째 항목 ("관리자 UI") 상태 = "PAY-S3 종료, 본 sprint 박제 완료". 변경 이력 1줄 | [MUST] | 🟡 | 6분 | Phase B 게이트 | `.claude/scripts/sensor-shared-contracts.sh` silent |
| C4b | VCK 게이트 — `grimoire-visual-canon-keeper`에 검수 요청: ① 새 시각 정본 신설 0건 ② `CircuitBreakerPanel` 색상이 사슴악마 토큰 정합(neutral-* + g-*) ③ 기존 admin AccessLogsTab/CreditsTab 패턴 정합 ④ ComingSoonModal/Alert 패턴 미사용(직접 confirm 다이얼로그 신설 가능 여부 — VCK 판정) | [MUST] | 🟡 | 4분 | C4a | VCK PASS — 불일치 0건 |
| C4c | qa 게이트 8건 — `grimoire-qa`에 채점 요청: ① server jest 전체 PASS ② server 커버리지 ≥60% 유지 ③ web vitest 전체 PASS ④ sensor-circuit-breaker-policy 10/10 PASS(회귀 0) ⑤ admin.controller.spec 7 케이스 PASS ⑥ admin.usecase.spec PASS ⑦ CircuitBreakerPanel.test 6 케이스 PASS ⑧ shared-contracts §27 갱신 정합. `reports/sprint-pay-s3-circuit-breaker-admin-progress.md`에 8 게이트 통과율 박제 | [MUST] | 🟢 | 5분 | C4b | qa 8/8 PASS |

**Phase C 게이트**: C4a~C4c [MUST] 3건 완료 = §27 갱신 + VCK PASS + qa 8/8 PASS → 마무리(§8) 진입.

---

## 8. PAY-S3 마무리 — 빌드·문서·sensor

| # | sub-task | 라벨 | 위험 | 시간 | 의존 | 검증 |
|---|---|---|---|---|---|---|
| C5a | 전체 빌드 — `npm run build` 무에러 (server + web) | [MUST] | 🟢 | 3분 | Phase C 게이트 | 종료코드 0 |
| C5b | 문서 일괄 갱신 — `grimoire-server/TECH_STATUS.md`(PAY-S3 완료 + admin endpoint 3 추가) + `grimoire-web/TECH_STATUS.md`(CircuitBreakerPanel 추가) + `docs/api-contract.md`(`GET /admin/circuit-breaker/state`·`POST /reset`·`POST /trip` 3 신설) + `ADR.md ADR-009 잔존 영역` 4번째 항목 = "PAY-S3 종료" 박제 + 루트 `SYNC_STATUS.md` | [MUST] | 🟡 | 6분 | C5a | drift sensor silent |
| C5c | sensor 일괄 — `sensor-circuit-breaker-policy`(필수 회귀 0) + `sensor-shared-contracts` + `sensor-instruction-degradation` + `sensor-agent-priority-labels` + `sensor-agent-interaction` | [SHOULD] | 🟢 | 3분 | C5b | sensor 전부 silent/PASS |

> **§0 원가 게이트 판정**: PAY-S3는 LLM 호출 0건(Circuit Breaker = 인프라 가용성 영역) → cost-accountant 게이트 0건. 신 AI 기능 추가 0건 → §0 마진 검증 불요.

---

## 9. 사용자 결정 게이트 + cost-accountant / VCK 게이트

### 9-1. 사용자 결정 게이트 (PAY-S3 착수 전 확인)

| # | 결정 대상 | 현 상태 | 게이트 판정 |
|---|---|---|---|
| G1 | **신 AuditLog 2 action 추가** (`circuit_breaker.manual_trip`/`manual_reset`) | 기존 4 action은 adapter 박제. 본 sprint는 controller 박제 추가 — 이중 박제 의도적(§1 S1f) | 사용자 확인 — 이중 박제 거부 시 controller AuditLog 0건(adapter만 사용) + reason 박제 강조 패턴 변경 |
| G2 | **배치 = SettingsTab 내 sub-section** | §6-2 권고 = settings. payments 탭 대안 가능 | 사용자/VCK 자문 — 변경 시 C3a 위치만 이동 |
| G3 | **마이그레이션 0건 확정** | §3 판정 — 기존 `admin_audit_logs` 스키마로 충분 | 사용자 확인 — 마이그레이션 0건 (사용자 제약 정합) |

> G1~G3은 **PAY-S3 착수 전 확인**. G1은 운영 감사 정책 영향 — 사용자 결정 필수. G2·G3은 통지/확인 수준.

### 9-2. cost-accountant 게이트 — **불요**

- PAY-S3는 LLM 호출 0건 (Circuit Breaker = 인프라 가용성 영역). cost-accountant 게이트 불요.

### 9-3. visual-canon-keeper(VCK) 게이트 — **필요 (Phase C C4b)**

- web Phase B 신설 컴포넌트(`CircuitBreakerPanel`) — 새 시각 정본 신설 0건 검증 + 사슴악마 색상 토큰 정합 검증 + 기존 admin 탭 패턴 정합 검증 + confirm 다이얼로그 신설 허용 여부 판정.
- 게이트 통과 = Phase C 진입.

---

## 10. AC (Acceptance Criteria) — BDD 8건

> 사용자 요청 "AC (Acceptance Criteria) BDD 8건 권장" — Given/When/Then 표준.

### AC-1 [Phase A — server, MUST]
**Given** 운영자가 admin token으로 인증된 상태에서
**When** `GET /admin/circuit-breaker/state` 호출
**Then** 2 호출점(`polar:checkouts:create`/`polar:checkouts:list`) state 배열을 200 응답으로 반환하고, 각 항목은 state·failureCount·openedAt·halfOpenTrialCount·policy 4값을 포함하며 내부 ID(authorId 등)는 노출 0건이다.

### AC-2 [Phase A — server, MUST]
**Given** 인증되지 않은 익명 요청에서
**When** `GET /admin/circuit-breaker/state` 호출
**Then** 401 Unauthorized 응답이며, 비-admin role 사용자는 동일 호출 시 403 Forbidden이다.

### AC-3 [Phase A — server, MUST]
**Given** 운영자가 `polar:checkouts:create` Circuit Breaker가 CLOSED 상태일 때
**When** `POST /admin/circuit-breaker/trip` body `{key, reason: "사고 대응 — 결제 차단"}` 호출
**Then** 200 응답에 `beforeState='closed', afterState='open'`이 포함되고, `AdminAuditLog`에 `action='circuit_breaker.manual_trip'` + `adminId={operator}` + `detail.reason="사고 대응 — 결제 차단"` 박제되며, 이후 `payment.usecase.initiatePayment` 호출이 `ServiceUnavailableException(503)`을 throw한다.

### AC-4 [Phase A — server, MUST]
**Given** 운영자가 `polar:checkouts:create` Circuit Breaker가 OPEN 상태일 때
**When** `POST /admin/circuit-breaker/reset` body `{key, reason: "수동 복구"}` 호출
**Then** 200 응답에 `beforeState='open', afterState='closed'`가 포함되고, `AdminAuditLog`에 `action='circuit_breaker.manual_reset'` 박제되며, 이후 `payment.usecase.initiatePayment` 호출이 정상 흐름으로 진입한다.

### AC-5 [Phase A — server, MUST]
**Given** 운영자가 reason 빈문자열로
**When** `POST /admin/circuit-breaker/trip` 또는 `/reset` 호출
**Then** 400 BadRequest "Circuit Breaker 수동 차단/복구 시 사유(reason) 필수" 응답이며, AuditLog 박제 0건 + Circuit Breaker 상태 변경 0건이다.

### AC-6 [Phase A — server, MUST]
**Given** 운영자가 key=`polar:checkouts:invalid` (화이트리스트 외)로
**When** `POST /admin/circuit-breaker/trip` 호출
**Then** 400 BadRequest "지원하지 않는 Circuit Breaker key" 응답이며, `CircuitBreakerPort.forceOpen` 호출 0건이다.

### AC-7 [Phase B — web, MUST]
**Given** 관리자가 `/admin` 페이지 SettingsTab 진입 후
**When** Circuit Breaker 패널에서 "강제 차단" 버튼 클릭
**Then** ⚠️ 경고 텍스트와 reason 입력 prompt + confirm 다이얼로그가 노출되고, reason 빈값 입력 시 클라이언트가 API 호출을 차단하며, 정상 reason 입력 시 `POST /admin/circuit-breaker/trip` 호출 후 패널 자동 refresh되어 상태가 OPEN(`bg-red-900/50`) 배지로 표시된다.

### AC-8 [Phase C — VCK + qa, MUST]
**Given** PAY-S3 sprint 종료 시점에
**When** `sensor-circuit-breaker-policy.sh` + `npm test`(server) + `npm test`(web) + VCK 검수 일괄 실행
**Then** sensor 10/10 PASS(회귀 0), server jest 전체 PASS + 커버리지 ≥60%, web vitest CircuitBreakerPanel.test 6/6 PASS, VCK 불일치 0건, shared-contracts §27 갱신 정합 — 8 게이트 모두 통과한다.

---

## 11. 핸드오프

### 11-1. 담당 + 산출물 위치

| 영역 | 담당 | 산출물 위치 | 다음 단계 진입 조건 |
|---|---|---|---|
| §9 사용자 게이트 G1~G3 | **사용자** (planner 경유 확인) | 이중 박제·배치·마이그레이션 결정 | G1~G3 확정 = Phase A 진입 |
| PAY-S3 S0 | grimoire-server | port·adapter·admin 패턴·web 14탭·AuditLog 정책 6건 해소 (progress.md) | S1a~S1f 완료 = Phase A 진입 |
| PAY-S3 Phase A 구현 | grimoire-server (Generator) | admin.controller 3 endpoint + admin.usecase 3 메서드 + DTO + spec + AuditLog 신 2 action 박제 + progress.md 갱신 | C2i sensor 회귀 0 PASS = Phase B 진입 |
| PAY-S3 Phase B 구현 | grimoire-web (Generator) | `CircuitBreakerPanel.tsx` + SettingsTab 통합 + api.ts 3 메서드 + Vitest 6 케이스 | C3f vitest PASS = Phase C 진입 |
| PAY-S3 Phase C VCK | **grimoire-visual-canon-keeper** | 사슴악마 정본 정합 검수 (4 항목) | VCK PASS = qa 채점 진입 |
| PAY-S3 Phase C qa | grimoire-qa (Evaluator) | `QA_REPORT.md` — 8 게이트 통과율 박제 + sprint-progress 채점 | qa 8/8 PASS = 마무리(§8) 진입 |
| PAY-S3 마무리 | grimoire-server + grimoire-web | TECH_STATUS / api-contract / ADR-009 잔존 영역 갱신 + SYNC_STATUS | drift sensor silent = sprint 종결 |

### 11-2. Initializer 산출물 (planner)

- 본 계획 = `.claude/state/sprint-pay-s3-circuit-breaker-admin-plan-draft.md`.
- **`reports/sprint-pay-s3-circuit-breaker-admin-progress.md` 생성 권고** — 본 계획 sub-task 24건 체크리스트 + Phase A/B/C 게이트 + 완료 기준을 progress.md로 박제 → server·web(Generator)이 Read 후 갱신, VCK·qa(Evaluator)가 채점 (책 Ch 16 Initializer→Generator→Evaluator 패턴).
- server / web / VCK / qa에게 본 계획 + progress.md Read 후 작업 핸드오프.

### 11-3. orchestration KPI 박제

- planner(Initializer) → server(Generator Phase A) → web(Generator Phase B) → VCK(Evaluator 시각) → qa(Evaluator 게이트) — 메인 결정 = 본 sprint = ✅ 합치(사용자 단일 지시 "pay s3 하자" + ADR-009 §"잔존 영역" 4번째 항목 단일 닫힘).

---

## 12. 위험·롤백·env·shared-contracts §27 갱신 요약

### 12-1. 위험 매트릭스

| # | 위험 | 영역 | 위험도 | 완화 |
|---|---|---|---|---|
| R1 | **수동 trip 사고 트리거** — 운영자가 실수로 `polar:checkouts:create` trip → 결제 즉시 503 | Phase A C2e + Phase B C3c | 🔴 | confirm 다이얼로그 + reason 필수 + ⚠️ 경고 시각 강조 + Throttle 분당 5회 + AuditLog 박제(operator_id) — 사후 추적 강제 |
| R2 | **권한 가드 누락** — `JwtAuthGuard`/`AdminGuard` 미적용 시 비인증/일반 사용자 접근 | Phase A C2c~C2e | 🔴 | spec C2h ① ② 강제 검증 (401/403 케이스) + SECURITY.md §4 체크리스트 준수 |
| R3 | **AuditLog 박제 누락** — 운영자 수동 행위 추적 불가 시 사후 분석 단절 | Phase A C2d~C2e | 🟡 | spec C2g가 AuditLog 호출 인자 검증(adminId + action + reason + beforeState/afterState §20 정합) |
| R4 | **circuit_breaker port DI 미해결** — `app.module.ts` 박제 누락 시 500 | Phase A C2f | 🟡 | PAY-P3-H에서 이미 박제 완료(`'CircuitBreakerPort' → InMemoryCircuitBreakerAdapter`) — 신규 추가 0건 |
| R5 | **web confirm 다이얼로그 우회** — 사용자가 다이얼로그 캔슬 후 API 호출 직접 만지면 트리거 가능 | Phase B C3c | 🟡 | server reason 빈값 400 + Throttle 5회/분 + admin token 필수 — client confirm은 UX 게이트, server가 강제 |
| R6 | **sensor 회귀** — 신 endpoint 추가가 기존 sensor-circuit-breaker-policy 10 검증에 영향 | Phase A C2i | 🟡 | sensor 10 검증은 port/adapter/AuditLog 4 action/spec ≥12 it 박제만 검사 — admin controller 추가는 무관(회귀 0 정합) |
| R7 | **VCK 거부** — `CircuitBreakerPanel` 색상/배치/confirm 다이얼로그가 사슴악마 정본 불일치 | Phase C C4b | 🟡 | C3b가 AccessLogsTab ACTION_COLORS 패턴 차용 + neutral-*/g-* 토큰 종속 + 새 정본 신설 0건 |

### 12-2. 롤백 전략

- **Phase A 단독 롤백** — server commit revert로 admin endpoint 3 제거. Circuit Breaker 로직(`forceOpen`/`forceClose` port 메서드) 영향 0(PAY-P3-H 영역).
- **Phase B 단독 롤백** — web commit revert로 CircuitBreakerPanel/SettingsTab 통합 제거. server endpoint는 curl로 운영 가능 상태 유지.
- **AuditLog 박제 롤백 0건** — 박제된 AdminAuditLog 행은 운영 데이터 → revert 안 함. 신 action `manual_trip`/`manual_reset` 박제 history 보존.
- **마이그레이션 롤백 0건** — 본 sprint 마이그레이션 0건 → 롤백 불요.

### 12-3. env 변경 요약

- 신 env **0건** — 본 sprint는 기존 `POLAR_CB_FAILURE_THRESHOLD`/`COOLDOWN_MS`/`HALF_OPEN_TRIAL`/`RESET_WINDOW_MS` 4 env 활용(응답 노출만, 신설 0). PAY-P3-H에서 이미 dev/prod 박제.
- `INFRASTRUCTURE.md` 갱신 0건 — env 신설 0건.

### 12-4. shared-contracts §27 갱신 요약 (C4a 산출)

```markdown
## 27. CircuitBreakerPolicy (server 도메인 — Polar SDK 호출 경계 가용성 차단)

### 위치
... 기존 위치 ...
- **HTTP admin (PAY-S3, 2026-05-23 신설)**:
  - `admin.controller.ts` `GET /admin/circuit-breaker/state` / `POST /admin/circuit-breaker/reset` / `POST /admin/circuit-breaker/trip`
  - DTO: `CircuitBreakerStateResponseDto`(state·failureCount·policy 4값) + `CircuitBreakerActionDto`(key·reason)
- spec: ... 기존 ... + `admin.controller.spec.ts`(신 3 endpoint 7 케이스) + `admin.usecase.spec.ts`(신 3 메서드)
- web: `grimoire-web/src/app/admin/tabs/components/CircuitBreakerPanel.tsx`(SettingsTab 내)

### AuditLog action 박제 매트릭스 (PAY-S3 확장)
| action | 영역 | reason 매트릭스 |
|---|---|---|
| `circuit_breaker.open` | (기존) | (기존) |
| `circuit_breaker.close` | (기존) | (기존) |
| `circuit_breaker.half_open_trial` | (기존) | (기존) |
| `circuit_breaker.reject` | (기존) | (기존) |
| **`circuit_breaker.manual_trip`** | admin.controller POST /trip | operator_id + key + reason + beforeState/afterState (§20 정합) |
| **`circuit_breaker.manual_reset`** | admin.controller POST /reset | operator_id + key + reason + beforeState/afterState |

### 잔존 영역 (PAY-S3 종결 후)
- ~~관리자 UI (forceOpen/forceClose)~~ — **PAY-S3 종료 (2026-05-23)**, port 인터페이스 위 HTTP admin + web SettingsTab 박제 완료
- 다중 인스턴스 환경 — in-memory 상태 분리 (Redis 별도 sprint, 잔존)
- 정책 변경 시 Container Apps 재시작 필요 (in-memory 0 초기화, 잔존)
- 호출 빈도 인벤토리 박제 필요 (운영 모니터링 영역, 잔존)

### 변경 이력
- 2026-05-15 #10_8 PAY-P3-H: 신설 ...
- **2026-05-23 PAY-S3: admin UI 박제 — `GET /admin/circuit-breaker/state` + `POST /reset` + `POST /trip` 3 endpoint + `CircuitBreakerPanel` web 컴포넌트(SettingsTab) + AuditLog 신 2 action(`manual_trip`/`manual_reset`). 마이그레이션 0건 + env 신설 0건 + 새 시각 정본 신설 0건. sensor 10/10 회귀 0.**
```

---

## 13. 제약 정합 요약 (사용자 위반 금지 게이트)

| 제약 | 본 계획 정합 |
|---|---|
| 작가 소설 콘텐츠 수정 절대 금지 | 본 sprint는 admin 영역 — 소설 콘텐츠 영향 0건 |
| 시각 정본 사슴악마 — 새 정본 신설 금지 | §6-2 + C3b가 AccessLogsTab 패턴 + neutral-*/g-* 토큰 종속 — VCK C4b 검증 |
| 마이그레이션 권장 0건 | §3 판정 = 마이그레이션 0건 확정 (기존 `admin_audit_logs` 스키마 충분) |
| sensor-circuit-breaker-policy 회귀 0 | C2i + C5c 게이트 — sensor 10/10 PASS 유지 |
| secret/토큰/connection string 노출 0 | DTO C2b 설계 — 내부 ID 노출 0건 / circuitKey는 운영 식별자(노출 허용) / policy 4 env값은 정책 가시화 목적 (값은 임계치 — secret 아님) |
| LLM 호출 0건 | Circuit Breaker = 인프라 가용성 영역 — cost-accountant 게이트 불요 |
