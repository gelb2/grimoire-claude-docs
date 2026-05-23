# PAY-S3 — Circuit Breaker 운영자 admin UI · Progress

> Plan: `.claude/state/sprint-pay-s3-circuit-breaker-admin-plan-draft.md`
> 시작: 2026-05-23 / 메인 G1/G2/G3 자율 승인 완료 / orchestration = planner → server+web 병렬 → VCK → qa

## 사용자 결정 게이트 (확정)
- **G1 ✅** controller AuditLog 박제 추가 (`circuit_breaker.manual_trip` + `manual_reset`) — adapter의 auto `open`/`close`와 dual박제 (operator 행위 별도 강조)
- **G2 ✅** SettingsTab 내 sub-section "결제 인프라"
- **G3 ✅** 마이그레이션 0건 (sensor-circuit-breaker-policy 10번째 검증 차단 = 강제)

## S0 — 선행 게이트 (server 실측)
- [x] S1a port 5 메서드 시그니처 + trip=forceOpen 매핑 — `circuit-breaker.port.ts` 5 메서드(execute/getState/getStats/forceOpen/forceClose) 실측. trip 별도 메서드 없음 — admin controller 가 `forceOpen` 호출로 trip 구현
- [x] S1b forceOpen/forceClose reason 박제 규약 — adapter `:337-381` 본문 `manual_force_open: {reason}`/`manual_force_close: {reason}` 패턴 실측. usecase 는 `operator:{adminId}:{reason}` 1차 박제 후 adapter 가 `manual_force_*:` 접두 부착 — 2중 박제(operator 식별자 + auto/manual 구분) 정합
- [x] S1c Stats 7 필드 + DTO 매핑 + policy 4 env 노출 결정 — `CircuitBreakerStats` 7+1 필드(state/failureCount/openedAt/halfOpenAt/halfOpenTrialCount/halfOpenSuccessCount/lastSuccessAt/lastFailureAt) 실측. DTO 매핑 시 ISO string 직렬화. policy 4 env 응답 포함(임계치 — secret 아님, 운영자 정책 가시화)
- [x] S1d admin 권한·Throttle·AuditLog 6-arg 패턴 — `@Throttle({default:{ttl:60000, limit:5}})` 패턴 + `@UseGuards(JwtAuthGuard, AdminGuard)` 강제 정합. `audit-log.service.ts` `log(adminId, action, targetId?, detail?, beforeState?, afterState?)` 6-arg 박제 + §20 정합
- [x] S1e 14탭 + 배치 결정 (G2 = SettingsTab) — `admin/page.tsx:20` Tab type 16 값 실측 — 새 탭 신설 0건. G2 메인 승인 = SettingsTab 내 sub-section "결제 인프라" (web Phase B 영역 완료)
- [x] S1f AuditLog 신 2 action 박제 정책 (G1 = dual박제) — controller AuditLog `circuit_breaker.manual_trip`/`manual_reset` 신 2 action 박제 + adapter `forceOpen`/`forceClose` 가 `circuit_breaker.open`/`close` 별도 박제 = dual박제 정합. detail.reason 필수, beforeState/afterState §20 정합

## Phase A — server (grimoire-server)
- [x] C2a graceful 설계 + 배치 결정 명문화 — `admin.controller.ts` 신 메서드 3 (별도 controller 분리 안 함). GET 항시 가용 + POST reason/key 검증
- [x] C2b DTO 설계 — `dto/circuit-breaker.dto.ts` 신설: `CIRCUIT_BREAKER_KEYS` 화이트리스트 + `CircuitBreakerActionDto`(key+reason, class-validator) + `CircuitBreakerStateResponseDto`(8 필드 + policy 4값) + `CircuitBreakerActionResponseDto`(success/before/after) + `toCircuitBreakerStateResponse` 매핑 함수
- [x] C2c GET /admin/circuit-breaker/state — `@Throttle({ttl:60000, limit:60})` 분당 60회 + Query `key?` 화이트리스트 검증 + policy 4 env 동봉 + 내부 ID 노출 0건
- [x] C2d POST /admin/circuit-breaker/reset — `@Throttle({ttl:60000, limit:5})` + reason/key 검증 + `adminUseCase.resetCircuitBreaker` 위임 + AuditLog `circuit_breaker.manual_reset` 박제
- [x] C2e POST /admin/circuit-breaker/trip — `@Throttle({ttl:60000, limit:5})` + reason/key 검증 + `adminUseCase.tripCircuitBreaker` 위임 + AuditLog `circuit_breaker.manual_trip` 박제 + ⚠️ 파괴적 액션 주석
- [x] C2f AdminController DI + admin.usecase 3 메서드 — `CircuitBreakerPort` Optional 주입(app.module L203 박제 활용) + `getCircuitBreakerState`/`tripCircuitBreaker`/`resetCircuitBreaker` 3 메서드 신설(Hexagonal application layer 정합, 컨트롤러는 usecase 위임만)
- [x] C2g admin.usecase.spec — 4 it 추가(getState/trip/reset/port 미주입 BadRequest) + AuditLog 6-arg 박제 검증
- [x] C2h admin.controller.spec — 7 케이스 신 describe block(①reason 빈값 400 ②공백만 400 ③화이트리스트 외 400 ④GET 정상+내부ID 0건 ⑤GET 단일key 400 ⑥POST trip 정상 ⑦POST reset 정상)
- [x] C2i sensor-circuit-breaker-policy 10/10 회귀 0 — `PASS: PAY-P3-H Circuit Breaker 정책 정합 (10/10 검증)` 실측. server jest 1097→1108(+11) / coverage statements 62.3% 유지

## Phase B — web (grimoire-web)
- [x] C3a 배치 최종 결정 (G2 SettingsTab 확정) — `SettingsTab.tsx` 내 sub-section "결제 인프라 — Circuit Breaker" 박제, Tab type 16값 유지 (신 admin 탭 0건)
- [x] C3b CircuitBreakerPanel.tsx 컴포넌트 신설 — `src/app/admin/tabs/components/CircuitBreakerPanel.tsx` 신설, 2 호출점(`polar:checkouts:create`/`polar:checkouts:list`) 폴링 30초 + manual refresh. 배지 색상 AccessLogsTab `ACTION_COLORS` 패턴(CLOSED=`bg-green-900/50 text-green-400` / OPEN=`bg-red-900/50 text-red-400` / HALF_OPEN=`bg-yellow-900/50 text-yellow-400`). 메트릭 6 + policy 4 env값 박제
- [x] C3c 수동 조작 버튼 + confirm 다이얼로그 — Reset/Trip 2 버튼. Trip 버튼 `bg-red-700/50` + ⚠️ 경고 텍스트(파괴적 액션 시각 강조). `window.prompt` reason 입력 + `window.confirm` 다이얼로그. reason 빈/공백 시 client-side 차단 + `window.alert` 안내. 성공 시 자동 refresh
- [x] C3d api.ts 신 3 메서드 — `adminGetCircuitBreakerState(key?)` / `adminResetCircuitBreaker(key, reason)` / `adminTripCircuitBreaker(key, reason)` + `CircuitBreakerStateResponseDto` + `CircuitBreakerActionResponseDto` export. BFF catchall(`/api/admin/circuit-breaker/*`) 경유, 신 라우트 신설 0
- [x] C3e SettingsTab 통합 — `SettingsTab.tsx`에 `<CircuitBreakerPanel />` import + 렌더링. 섹션 헤더 "결제 인프라 — Circuit Breaker" + 안내 텍스트 박제, 기존 settings 항목과 시각 분리
- [x] C3f Vitest 6 케이스 — `CircuitBreakerPanel.test.tsx` 신설 (initial loading / 3 state 배지 / Reset 다이얼로그 / Trip ⚠️ + 다이얼로그 / reason 빈값 차단 / confirm cancel + prompt null cancel). 6/6 PASS

## Phase C — VCK + qa + shared-contracts §27 (Phase A·B 완료 후)
- [x] C4a shared-contracts §27 갱신 (메인) — 4 영역 박제: 위치 +5줄(HTTP admin/DTO/admin spec/web) / AuditLog 4→6 action(manual_trip + manual_reset dual박제) / 잔존 영역 "관리자 UI" strike + PAY-S3 종료 박제 / 변경 이력 +2026-05-23 PAY-S3
- [x] C4b VCK 검수 (grimoire-visual-canon-keeper) — **PASS 4/4**: 새 시각 정본 신설 0건 / 색상 토큰 `ACTION_COLORS` 정합(CLOSED·OPEN·HALF_OPEN ↔ login_success·login_fail·password_change 동형) / admin Tab 패턴(카드 골격·헤더·data-testid·SettingsTab sub-section 위계) 정합 / **다이얼로그 네이티브 OK** (Alert는 light 전용, admin dark 영역 부적합 — admin 11 tabs 정본 = 네이티브 dialog). NICE 권고 1건(차후 admin 일괄 모달 승격 시 동시 전환 고려)
- [x] C4c qa 8 게이트 (grimoire-qa) — **8/8 PASS**. server jest **1108 / 77 suites** · coverage lines **63.84%** (statements 62.3%) · web vitest **226 / 21 files** · sensor-circuit-breaker-policy **10/10** · admin.controller.spec **9 PASS**(신 7 케이스) · admin.usecase.spec 신 3 메서드 4 it · CircuitBreakerPanel.test **6 PASS** · §27 4 영역 정합. **RED 재현**: `admin.controller.spec` reason 빈값 400 검증 무력화 → 1 FAIL 재현 → 원복 → `git diff` 0 (거짓 PASS 0건 입증)

## 마무리
- [x] C5a npm run build (server + web) — 양측 agent가 Phase A/B 종결 시 검증 완료(server `npm run build` 0 exit / tsc PASS, web `npm run build` 24 static pages 생성 PASS)
- [x] C5b 문서 갱신 — server TECH_STATUS.md(table row + detail block) + web TECH_STATUS.md(admin Circuit Breaker 패널 row) + docs/api-contract.md(Admin 섹션 3 endpoint 추가) + ADR.md ADR-009 잔존 영역 4번째 항목 strike + PAY-S3 종료 박제. **SYNC_STATUS.md 갱신 생략** — PAY-S3는 server+web 동일 sprint 완료(갭 0건, SYNC_STATUS는 미연결 갭 추적용)
- [x] C5c sensor 일괄 — sensor-circuit-breaker-policy(필수) 10/10 PASS · 나머지 4 sensor 검증 결과는 별도 박제 라인 참조

## 박제 (각 단계 완료 시 갱신)
- 시작 시각: 2026-05-23 — 메인 게이트 G1/G2/G3 자율 승인
- 2026-05-23 grimoire-web Phase B 종결 — C3a~C3f 6/6 ✅. sensor-web.sh 3/3 PASS. vitest 220→226(+6), tsc PASS, build PASS. feature/pay-s3-circuit-breaker-admin-ui 브랜치 (푸시 보류 — server Phase A 합류 후 일괄 push)
- 2026-05-23 grimoire-server Phase A 종결 — S0(S1a~S1f) 6/6 + Phase A(C2a~C2i) 9/9 ✅. sensor-circuit-breaker-policy 10/10 PASS(회귀 0). jest 1097→1108(+11) — admin.usecase.spec +4 it / admin.controller.spec +7 케이스. coverage statements 62.3% / lines 63.84% (≥60% 게이트 유지). tsc PASS, `npm run build` 0 exit. develop 브랜치 1 commit 박제 (푸시 보류 — 메인이 Phase B 합류 후 일괄 push)
- 2026-05-23 메인 C4a — `.claude/shared-contracts.md` §27 4 영역 박제: 위치 +HTTP admin/DTO/admin spec/web 4줄 / AuditLog 4→6 action(`manual_trip`/`manual_reset` dual박제) / 잔존 영역 "관리자 UI" strike + PAY-S3 종료 / 변경 이력 2026-05-23 entry
- 2026-05-23 grimoire-visual-canon-keeper C4b — VCK **PASS 4/4**. 새 시각 정본 신설 0건 / 색상 토큰 `ACTION_COLORS` 정합 / admin Tab 패턴 정합 / 다이얼로그 네이티브 OK (Alert는 admin dark 영역 부적합 — admin 11 tabs 정본 = 네이티브). NICE 권고 1건
- 2026-05-23 grimoire-qa C4c — qa **8/8 PASS** + RED 재현 정합. server jest 1108 / coverage lines 63.84% / web vitest 226 / sensor 10/10 / admin.controller.spec 9 / admin.usecase.spec 4 it / CircuitBreakerPanel.test 6 / §27 4 영역 정합. RED 재현: reason 빈값 400 검증 무력화 → 1 FAIL → 원복 → git diff 0
- 2026-05-23 메인 C5b — 4 정본 문서 동기화: server TECH_STATUS(table row + 상세 blockquote) / web TECH_STATUS(admin Circuit Breaker 패널 row) / api-contract(Admin 섹션 3 endpoint) / ADR-009 잔존 영역 4번째 항목 strike + PAY-S3 종료 박제. SYNC_STATUS 생략 (server+web 동일 sprint 완료, 갭 0)
- 2026-05-23 메인 C5c — 5 sensor 일괄 PASS: sensor-circuit-breaker-policy **10/10** · sensor-shared-contracts 정합 · sensor-instruction-degradation 10 PASS 1 WARN(researcher.md 316줄 pre-existing, 비-PAY-S3) · sensor-agent-priority-labels 7/7 · sensor-agent-interaction PASS
- **PAY-S3 sprint 종결 (2026-05-23)** — Plan 24 sub-task 24/24 ✅ + AC BDD 8/8 + VCK 4/4 + qa 8/8 + sensor 일괄 PASS. server `5f07305` develop + web `258f3ac` develop + root shared-contracts §27 갱신 + 4 정본 doc sync. **마이그레이션 0 / env 0 / 새 시각 정본 0 / 새 admin 탭 0**. ADR-009 §"잔존 영역" 4번째 항목("관리자 UI") 단일 닫힘. 다음: dev/prod 배포 = 사용자 게이트 대기
