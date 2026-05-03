# HANDOVER — 2026-05-03 #10_6 (묶음 II 종료 + B/C/D/E + A 시연 시퀀스) → 다음 세션

> **작성자**: 2026-05-03 로컬 세션 (Claude, #10_6 — DD/EE/FF/GG/HH/II 묶음 일괄 자율 진행)
> **수신자**: 다음 세션 (로컬 또는 리모트 채팅방)
> **검증 명령**: `cd /Users/sokol/Desktop/Git/ProjectGrimoire && git log --oneline -10 && bash eval/scripts/eval-runner.sh && bash .claude/scripts/sensor-adversarial-pre-commit.sh`
>
> **핵심**: 사용자 지시 — **B → C → D → E 4건 자율 진행**, **A는 마지막** (구독제 요금제 + 코드/DB 기획 변동 동반)

---

## 🚨 0. 절대 준수 사항 (사용자 명시 결정 — 보존)

### 0-1. 외부 Anthropic API 신규 의존 영구 보류 (2026-04-30)
> "앤스로픽 외부 api를 쓰는 방향으로의 하네스엔지니어링, 에이전트 고도화는 나중 과제로 좀 미루고 싶다"

**금지 카테고리** (Claude Code 구독 외 종량제 API):
- LLM-as-Judge 실제 SDK 연동 (grade-llm.py는 stub 그대로 유지)
- **에이전트별 모델 티어링 (Opus/Sonnet/Haiku 분리)** — 사용자 보류 결정 우선
- Agent teams experimental
- 책 Ch 17 협업 패턴

사용자가 다시 "진행" 명시할 때까지 손대지 않는다.

### 0-2. CLAUDE.md §0 ZERO-TOLERANCE
- 추정 보고 절대 금지 (직접 명령 검증)
- 정책·PRD 강제 종속

### 0-3. 한국어 존댓말 필수 (Constitution P10 + sensor 자동 검증)

### 0-4. main 머지 정책 (.githooks/AGENTS.md §1)
- **3 레포 모두 develop → main 머지는 사용자 per-repo 명시 승인 필요**
- 이전 세션에서 "메인 머지 진행" 일반 표현은 **per-repo 명시 부족**으로 시스템 가드 deny 발생
- 사용자가 "claude-docs main 머지" / "server main 머지" 등 **레포 명시 후 진행**

---

## 📊 1. 현재 시스템 인벤토리 (2026-05-03 #10_6 묶음 II 종료 시점)

| 항목 | 수량 | 비고 |
|------|------|------|
| Skills | 24 | dispatching-parallel-agents + requesting-code-review (묶음 EE) 포함 |
| Sensors | 25 | sensor-adversarial-pre-commit (P17 정밀화) + sensor-orch-ratio (META_PASS) 보강 |
| Knowledge 정본 | 8 (README 제외) | build-to-delete-policy.md (묶음 II) 포함 |
| Constitution Principles | **19** | OWASP LLM Top 10 P17/P18/P19 통합 (묶음 CC) |
| Eval tasks (regression) | 49 | 100% PASS 안정 |
| Eval tasks (EDD 추가) | 3 (총 52) | 96.15% PASS 안정 (3 runs 동일) |
| Eval 점수 가중치 | TaskFlow 5차원 | 묶음 II 도입 (functional 40 + code 20 + perf 15 + security 15 + ux 10) |
| Agents | 7 | planner Initializer 역할 명시 (묶음 II) |
| Hooks | 9 이벤트 14 스크립트 | |

**최근 커밋**:
- claude-docs `c10cc25` (2026-05-03) — 시연 데모 후보 14건 조사 보고서
- claude-docs `a248927` (2026-05-03) — 묶음 II 자율 적용 6건
- grimoire-server `71a96d3` main (2026-05-03) — P17 LLM Prompt Injection 방어 (Bundle FF)

---

## 🎯 1.5. 진행 현황 (2026-05-04 04:50 기준 — 채팅방 폭파 예방 박제)

### ✅ 완료 (3 레포 develop push 완료)
- 작업 B (테마 에디터 preset name 자동 동기) — web `3682081`
- 작업 C (publishTheme bakedCssUrl 절대 URL) — server `ff493dd` + web `70ca832`
- PAY-P0-1 webhook event_id 멱등성 — server `8c13103` + claude-docs `06de6c6`
- PAY-P0-2 PG↔DB 정합성 cron — server `8e9e02e` + web `849f771` + claude-docs `790e692`
- PAY-P0-3 운영자 수동 크레딧 UI — web `af3f04c` + claude-docs `841e704`
- commit hook 자동화 보강 — server `1f43b05` + web `dd3717b` + claude-docs `43c1728`
- CERTI_PROJ 외부 leak 제거 — server `b67233c`
- 결제 전수검사 + 다음 계획 박제 — `reports/PAYMENT_NEXT_STEPS.md` (claude-docs `43c1728`)

### ⏳ 진행 중 (사용자 명시 옵션 A)
- **PAY-P1-1 Refund 정밀 처리** (~2h) — 채팅방 폭파 예방용 박제: `memory/project_session_20260503_3.md §2`
- 핵심 갭: webhook 'cancel' 분기에서 status='refunded' 마킹만, 크레딧 환수 트랜잭션 부재 → 적자 위험
- 산출물 후보: `refund-payment.usecase.ts` + `RefundLog` 모델 + spec + sensor-refund-atomicity + regression-55 + shared-contracts §13
- 멀티에이전트: planner Initializer → server Generator → qa Evaluator (cost-accountant/VCK 면제)

### 🚀 다음 트랙 (PAY-P1-1 후)
1. PAY-P1-2 결제 알림 이메일 (cost-accountant 외부 API 위임 필수)
2. PAY-P1-3 결제 실패 retry 정책
3. 작업 D (작품별 테마 배정 UI) + E (조회수 급락 조사)
4. PAY-P2 (부분 환불 / DLQ / audit 강화 / SMS)
5. 작업 A + PAY-P1-4 (구독제 요금제 통합, 큰 작업)

### 📦 사용자 영역 잔존 (PAY-P0)
- main per-repo 머지 (3 레포)
- dev 환경 검증 (PUBLIC_API_BASE_URL env + Container Apps 로그 + admin 화면 클릭)
- prod 배포 (`npx prisma migrate deploy` + `make deploy-prod`)

---

## 🎯 2. 사용자 명시 작업 시퀀스 (B → C → D → E → A)

> **사용자 의도**: 우리 하네스 + 에이전트 + 레드팀 시스템 전체를 실제 ProjectGrimoire 작업으로 한번 쭉 발동시켜 본다.
>
> **순서 결정 (사용자 명시 2026-05-03)**: B → C → D → E 먼저, A는 모두 끝나고 마지막 (기획 변동 동반).
> **진행 현황 갱신 (2026-05-04)**: B + C 완료 → 결제 전수검사 + PAY-P0 3건 우선 진행 → 사용자 옵션 A로 **PAY-P1-1 진입**. D/E는 PAY-P1 후.

### 2-1. 작업 B — 테마 에디터 preset 변경 시 name 자동 동기 UX (P2-#10)

- **규모**: ~1~1.5h
- **도메인**: web only
- **발동 시스템**:
  - `orchestration-decision` skill (위임 가치 매트릭스)
  - `planner` Initializer (Sprint 계약 — 묶음 II 신규)
  - **`visual-canon-keeper`** ★ 핵심 발동 (사슴악마 정본 + 테마 에디터 검수)
  - `web` 에이전트 (Generator)
  - `qa` 에이전트 (Evaluator)
  - `verification-before-completion` skill
  - `socratic-self-critique` skill
  - `requesting-code-review` skill (묶음 EE 신규)
  - sensor-adversarial-pre-commit (P2 사슴악마 시각 정본 검증)
- **현황**: PLANNING_GRIMOIRE.md "테마 에디터 preset 변경 시 사용자가 name 필드를 수정 안 했으면 자동으로 preset의 기본 name으로 동기화"
- **예상 산출물**:
  - `grimoire-web/src/features/theme-editor/` 컴포넌트 수정
  - `grimoire-web/src/features/theme-editor/__tests__/*.spec.ts` 추가
  - `reports/sprint-theme-editor-name-sync-progress.md` (Initializer 패턴 시연)
- **검증**:
  - sensor-web 3/3 PASS
  - visual-canon-keeper 검수 PASS (VISUAL_CANON_REPORT)
  - sensor-adversarial-pre-commit P2 PASS
  - eval task 신규 1건 추가 (regression 49→50)
- **commit + 머지**: feature/theme-editor-name-sync → develop → (사용자 명시 시) main

### 2-2. 작업 C — publishTheme bakedCssUrl 무효 처리 (P1-#7)

- **규모**: ~1.5~2h
- **도메인**: server (DB 마이그레이션 가능) + web (CSS URL 절대 경로 처리)
- **발동 시스템**:
  - `planner` Initializer
  - **`server`** 에이전트 (Prisma 마이그레이션 + UseCase 변경)
  - **`web`** 에이전트 (bakedCssUrl 절대 경로 fetch 처리)
  - `qa` 에이전트
  - `cost-accountant` (Blob 업로드 비용 영향 검증)
  - sensor-adversarial-pre-commit (P3 작가 콘텐츠 보호 — 테마 영향)
  - sensor-shared-contracts (server↔web 인터페이스 정합)
- **현황**: 현재 publishTheme이 상대 경로 bakedCssUrl 박제 → 환경 전환 시 무효
- **예상 산출물**:
  - `grimoire-server/src/application/theme/publish-theme.usecase.ts` 갱신
  - `grimoire-server/prisma/migrations/YYYYMMDD_xxxxxx_baked_css_url_absolute/`
  - `grimoire-web/src/widgets/theme-loader/` 절대 URL fetch 처리
  - `grimoire-server/docs/data-model.md` 갱신
- **검증**:
  - sensor-server 4/4 PASS
  - sensor-web 3/3 PASS
  - sensor-docs-sync PASS
  - 마이그레이션 rollback 테스트 (MIGRATION.md §5 절차)
- **commit + 머지**: feature/baked-css-url-absolute → develop → (사용자 명시 시) main

### 2-3. 작업 D — 작품별 테마 배정 UI (P2-#16, api 있음)

- **규모**: ~2h
- **도메인**: web only (서버 API는 이미 존재)
- **발동 시스템**:
  - `planner` Initializer
  - **`visual-canon-keeper`** (테마 배정 UI 시각 검수)
  - `web` 에이전트
  - `qa` 에이전트
  - `requesting-code-review` skill
- **현황**: `grimoire-web/src/shared/api.ts`에 `assignThemeToWork` 등 API 있으나 대시보드 UI 없음
- **예상 산출물**:
  - `grimoire-web/src/features/work-theme-assign/` 신설
  - `grimoire-web/src/app/dashboard/works/[workId]/theme/page.tsx` 신설
  - 테스트 + visual-canon-keeper 검수
- **검증**:
  - sensor-web 3/3 PASS
  - visual-canon-keeper PASS
  - eval task 신규 1건 추가

### 2-4. 작업 E — 4월 12일 이후 조회수 급락 원인 조사 (P1-#6)

- **규모**: ~1~2h (조사형)
- **도메인**: server (DB + 로그 조사) + 운영 데이터 분석
- **발동 시스템**:
  - **`production-bug-triage`** skill ★ 전용 발동 (실측 + 추정 금지)
  - `verification-before-completion` skill (실측 증거 강제)
  - `server` 에이전트 (DB 쿼리 + UseCase 추적)
  - `qa` 에이전트 (재검증)
  - sensor-adversarial-pre-commit P1 (§0 ZERO-TOLERANCE — 추정 패턴 0건)
- **현황**: 4월 12일 이후 조회수 카운트 급락 — `incrementDailyView` UseCase 장애 가능성
- **조사 절차** (production-bug-triage skill 정합):
  1. **DB 실측**: `psql` 또는 prisma studio로 daily_views 테이블 일자별 카운트 추출
  2. **코드 경로**: `grimoire-server/src/application/stats/increment-daily-view.usecase.ts` git log 추적
  3. **운영 로그**: Azure Container Apps logs (`az containerapp logs show`)
  4. **수치 근거 확보**: 4-11 vs 4-12 vs 5-3 일자별 카운트 비교
  5. **원인 가설 → 코드 수정 또는 인프라 복구**
- **예상 산출물**:
  - `reports/INCIDENT_view_count_drop_20260412.md` 신설
  - 원인 발견 시 server 코드 수정 + 마이그레이션 (필요 시)
  - eval task 신규 1건 (회귀 차단)
- **검증**:
  - 운영 데이터 회복 확인 (Chrome 또는 curl로 실제 조회수 응답 검증)
  - sensor-adversarial-pre-commit P1 ZERO-TOLERANCE 통과
  - sensor-server 회귀 통과

### 2-5. 작업 A — AI 채팅 1턴 크레딧 차감 + 구독제 요금제 기획 (P1-#8 확장)

> **⚠️ 사용자 명시 (2026-05-03)**: A는 단순 1턴 차감 아님 — **구독제 요금제 구성 + 코드/DB 기획 수립 먼저** 필요. B/C/D/E 모두 끝난 다음에 진행.

- **규모**: ~5~8h (기획 + 구현 + 검증)
- **도메인**: planning + cost-accountant + server (chat + credit + plan + payment) + web (요금제 UI)
- **발동 시스템 (시연 의도 — 시스템 전체 발동)**:
  - **`writing-plans`** skill ★ (큰 작업 분할)
  - **`planner`** Initializer (★ 기획 Draft 신설)
  - **`researcher`** ★ (경쟁사 구독제 비교 — 한줄/네이버 시리즈/카카오페이지/Wattpad)
  - **`cost-accountant`** ★★ (마진 ≥3배 검증 + ai-cost-table.md 갱신 + 구독 등급별 시뮬)
  - **`visual-canon-keeper`** (요금제 UI 시각 검수)
  - **`server`** 에이전트 (Plan 모델 확장 + Credit usecase + Chat usecase + Payment usecase)
  - **`web`** 에이전트 (요금제 페이지 + 채팅 크레딧 잔여 표시)
  - **`qa`** 에이전트 (Sprint 계약 채점)
  - **`socratic-self-critique`** skill (14 질문 + Ambiguity ≤ 0.2)
  - **`requesting-code-review`** skill (12 항목 체크리스트)
  - **레드팀 발동**:
    - P4 §0 원가 (cost-accountant 게이트)
    - P16 결제 원자성 (Payment + Credit + CreditLog $transaction)
    - **P17 LLM Prompt Injection** (이미 chat.usecase에 적용됨 — Bundle FF)
    - P18 LLM Output Encoding (응답 마스킹)
    - P19 Sensitive Info Disclosure (잔여 크레딧 응답 PII 검증)
- **사용자 결정 요건 (자율 진행 X)**:
  1. **구독 요금제 등급 구조** (예: Free / Plus / Pro / Enterprise) — 가격 + 포함 크레딧 + 월/연
  2. **AI 채팅 1턴 크레딧 비용** (Sonnet 4.6 기반 마진 ≥3배 충족 값)
  3. **시맨틱 캐시 히트 시 할인 정책** (P1-#9와 연동)
  4. **Polar 결제 연동 방식** (구독은 Polar Subscription Product 사용 — 현재 일회성 결제만)
  5. **DB 스키마 확장** (Subscription / SubscriptionPlan / SubscriptionLog 테이블)
  6. **기존 일회성 결제 사용자 마이그레이션** (사용자 결정 영역)
- **기획 단계 산출물 (구현 전)**:
  - `PLANNING_GRIMOIRE.md` 새 섹션 (구독제 요금제 — Draft, 사용자 승인 후 정식)
  - `reports/SUBSCRIPTION_RESEARCH.md` (researcher 위임 결과 — 경쟁사 구독제 5종 비교)
  - `reports/SUBSCRIPTION_COST_AUDIT.md` (cost-accountant — 등급별 마진 시뮬)
  - `reports/SUBSCRIPTION_PLAN_DRAFT.md` (planner — 기획 Draft)
- **구현 단계 산출물 (사용자 승인 후)**:
  - `grimoire-server/prisma/schema.prisma` (Subscription 모델 + SubscriptionPlan enum 확장)
  - `grimoire-server/prisma/migrations/YYYYMMDD_xxxxxx_subscription_model/`
  - `grimoire-server/src/domain/model/subscription.ts` 신설
  - `grimoire-server/src/application/subscription/` 디렉토리 신설
  - `grimoire-server/src/application/chat/chat.usecase.ts` 크레딧 차감 + 환불 분기
  - `grimoire-server/src/application/payment/payment.usecase.ts` Polar Subscription webhook 처리
  - `grimoire-web/src/features/subscription/` 페이지 신설
  - `grimoire-web/src/widgets/credit-balance/` 잔여 표시
- **검증**:
  - 480/480 server jest + 신규 subscription spec
  - sensor-credit-atomicity PASS (P16 결제 원자성)
  - sensor-cost-margin PASS (구독제 모든 등급 ≥3배 마진)
  - sensor-adversarial-pre-commit 19 principles 모두 PASS
  - EDD eval 회귀 차단 (regression 50→51 등)
  - Chrome 시각 검증 (claude-in-chrome MCP 또는 사용자 직접)

---

## 🛠️ 3. 발동 절차 (모든 작업 공통 — 우리 시스템 정합)

```
[Step 1] 작업 시작 전
  → orchestration-decision skill (위임 가치 매트릭스)
  → §15.7 매트릭스로 메인 직접 vs subagent 위임 결정

[Step 2] 기획 (planner Initializer — 묶음 II 신규)
  → planner 에이전트 호출 (Task tool)
  → reports/sprint-{name}-progress.md 생성 (Sprint 계약)
  → reports/PLANNER_REPORT.md 작성

[Step 3] 외부 검증 게이트 (필요 시)
  → AI 기능 → cost-accountant (마진 ≥3배)
  → 시각 영향 → visual-canon-keeper (사슴악마 정본)
  → 시장 조사 → researcher (경쟁사 + AI 가격)

[Step 4] 구현 (Generator — server/web)
  → server 또는 web 에이전트 호출
  → progress.md 읽고 미완 기능 구현 → progress.md 갱신

[Step 5] 회귀 검증
  → verification-before-completion skill (실측 증거 강제)
  → sensor-server / sensor-web / sensor-docs-sync
  → eval-runner.sh (regression + EDD)

[Step 6] 적대적 검증 (commit 직전)
  → sensor-adversarial-pre-commit (19 principles)
  → socratic-self-critique skill (14 질문 + Ambiguity ≤ 0.2)
  → requesting-code-review skill (12 항목 체크리스트)

[Step 7] 평가 (Evaluator — qa)
  → qa 에이전트 호출
  → reports/QA_REPORT.md 작성 (Sprint 계약 채점 포함)

[Step 8] commit + 머지
  → feature/{name} → develop (.githooks/pre-commit 자동 검증)
  → develop → main (사용자 per-repo 명시 승인 후)

[Step 9] 메모리 박제 (Stop hook 강제)
  → memory/project_session_YYYYMMDD*.md
  → memory/MEMORY.md 인덱스 갱신
  → memory/project_remaining_tasks.md 현행화
```

---

## 🚦 4. 검증 게이트 (commit 직전 자동 차단)

`.githooks/pre-commit` 자동 발동:
1. `update-harness-inventory --apply` (NEW-5)
2. `instructions-drift-check.sh` (exit 0 강제)
3. `eval-precommit.sh` (regression-tolerance 0.05)
4. `sensor-adversarial-pre-commit.sh` (19 principles, FAIL 0건 강제)

**현재 검증 결과 (#10_6 묶음 II 종료)**:
- regression eval 49/49 PASS (1.0)
- EDD eval 50/52 PASS (0.9615) × 3 runs 동일
- TaskFlow 가중 점수 0.9932
- 19 Principles 17 PASS / 2 WARN / 0 FAIL
- 자가진단 활성 6/6 PASS (Q1 META_PASS 인식)
- knowledge drift 0건
- feedback PROMOTE 6→0건 (모두 absorbed 마크)

---

## 📁 5. 핵심 정본 위치

| 정본 | 위치 |
|------|------|
| 절대 규정 | `CLAUDE.md` (73줄) + `PLANNING_GRIMOIRE.md` |
| 하네스 | `.claude/AGENTS.md` |
| 문서 동기화 | `docs/AGENTS.md` |
| Git/CI | `.githooks/AGENTS.md` |
| 7 에이전트 인터페이스 | `.claude/shared-contracts.md` |
| 책 학습 결과 | `.claude/knowledge/book-harness-engineering-completion.md` |
| Red-Team Constitution | `.claude/knowledge/red-team-constitution.md` (19 principles) |
| Build-to-Delete 정책 | `.claude/knowledge/build-to-delete-policy.md` (묶음 II 신규) |
| 위임 가치 매트릭스 | `research/HARNESS_FIELD_PATTERNS_4.md` §15.7 |
| 적대적 검증 | `research/HARNESS_ADVERSARIAL_VERIFICATION.md` |
| 시연 후보 (참고) | `reports/SHOWCASE_DEMO_CANDIDATES.md` |
| 본 묶음 검수 | `reports/inspection-20260503-bundle-hh.md` |

---

## ⚠️ 6. 주의사항 (이전 세션 반복 방지)

### 6-1. main 머지는 per-repo 명시 승인
- "메인 머지 진행" 일반 표현은 시스템 가드 deny 발생 (이전 세션 경험)
- 사용자에게 **"claude-docs main 머지" / "server main 머지" / "web main 머지"** 형태로 명시 요청

### 6-2. 외부 Anthropic API 신규 의존 0건
- 모든 사전 검토 시 anthropic SDK import 금지 (현재 stub 유지)
- 모델 티어링 / agent teams / LLM-as-Judge 실 SDK 호출 금지

### 6-3. 작가 본문 수정/인용/로깅 금지
- 본문 변환/요약/저장 패턴 sensor-adversarial-pre-commit P3 검출

### 6-4. flaky test 인식
- `grimoire-server/src/lib/hwp-parser.spec.ts` (Zip Bomb 50MB 테스트) 가끔 timeout
- 단독 재실행 (`npx jest src/lib/hwp-parser.spec.ts`) 시 PASS

### 6-5. EDD 96.15% 2 fail은 정상 baseline
- `edd-sample-001` (LLM-as-Judge 시연) 외부 Anthropic API 보류로 의도 차단됨
- 회귀 신호 아님 — 무시 가능

---

## 🎬 7. 다음 세션 시작 시 첫 명령

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire

# 1. 현재 상태 확인
git -C grimoire-server log --oneline -5
git -C grimoire-web log --oneline -5
git log --oneline -5

# 2. 시스템 인벤토리 검증
bash .claude/scripts/sensor-adversarial-pre-commit.sh
bash .claude/scripts/sensor-harness-self-diagnose.sh
bash eval/scripts/eval-runner.sh

# 3. 본 핸드오버 Read
cat HANDOVER_NEXT_SESSION.md  # 본 파일

# 4. 작업 시작 (B 추천 — 가장 작고 visual-canon-keeper 시연)
```

---

## 📝 8. 권장 진행 순서 (사용자 명시 정합)

```
세션 1 (1~1.5h): 작업 B (테마 에디터 preset name 자동 동기)
  → visual-canon-keeper 시연 + Sprint 계약 패턴 첫 적용

세션 2 (1.5~2h): 작업 C (publishTheme bakedCssUrl 무효 처리)
  → server + web 동시 변경 + 마이그레이션 시연

세션 3 (2h): 작업 D (작품별 테마 배정 UI)
  → web only + visual-canon-keeper 두 번째 시연

세션 4 (1~2h): 작업 E (4-12일 조회수 급락 원인 조사)
  → production-bug-triage skill 전용 발동 + 운영 데이터 분석

세션 5~ (5~8h): 작업 A (AI 채팅 + 구독제 요금제)
  → 기획 단계 (researcher + cost-accountant + planner) 먼저
  → 사용자 승인 후 구현 단계 (server + web + qa)
  → 시스템 전체 발동 (모든 sensor + 모든 skill + 모든 agent)
```

---

## 🤝 9. 사용자 협력 요청 사항

### 9-1. 즉시 답변 필요 (작업 진행 중)
- 작업 B/C/D/E 각각 commit 후 develop → main 머지 명시 (per-repo)
- 작업 E에서 운영 데이터 접근 필요 시 Azure 또는 DB 자격 증명 확인

### 9-2. 작업 A 시작 전 결정 필요
- 구독 등급 구조 (예: Free / Plus / Pro / Enterprise — 사용자 결정)
- 구독 가격대 (월 / 연 — 사용자 결정)
- AI 채팅 1턴 크레딧 비용 (cost-accountant 시뮬 후 사용자 승인)
- Polar Subscription Product 도입 여부 (현재 일회성만)
- 기존 일회성 결제 사용자 마이그레이션 정책

---

## 변경 이력
- 2026-05-03 #10_6 묶음 II 종료: 본 핸드오버 신설
- B/C/D/E + A 시퀀스 명시 (사용자 2026-05-03 결정)
- A는 구독제 요금제 + 코드/DB 기획 변동 동반 (사용자 추가 요구)
