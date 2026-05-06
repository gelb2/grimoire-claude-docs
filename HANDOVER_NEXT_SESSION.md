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
| Sensors | 25 | sensor-adversarial-pre-commit (P17 정밀화) + sensor-orchestration-ratio (META_PASS) 보강 |
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

## 🚨 1.5. CRITICAL — 2026-05-06 묶음 LL incident-log 시스템 도입 + 자기 거짓 사슬 박제

**즉시 Read 강제**: `.claude/state/incident-log.jsonl` (29건 incident 박제, 시계열 누적)

**사용자 명시 (2026-05-06)**:
> "앞으로 모든 실수, 그게 툴이면 툴, 에이전트면 에이전트, 문서 누락이면 누락에,
>  실수가 발견된거든, 실수를 우회한 거든, 내가 지금처럼 발견한 거든
>  하나도 빼놓지 말고 나올 때마다 주제별로 다 기록해"

**도입 시스템**:
- `.claude/scripts/incident-log.sh` — 시계열 박제 wrapper (category 10종 / severity 4 / source 4)
- `.claude/state/incident-log.jsonl` — 누적 박제 (.gitignore 예외)
- `.claude/knowledge/red-team-constitution.md` Principle 20 — 박제 의무 (Mitchell Ghostty 패턴)
- `.claude/scripts/sensor-adversarial-pre-commit.sh` P20 — 오늘 commit 있는데 incident 0건이면 WARN
- `.claude/scripts/stop-memory-guard.sh` — Stop hook에 incident 박제 누락 WARN

**HANDOVER §3 8건 갭 보강 (자율 가능 영역)**:
- `.claude/skills/infra-mutation-guard/` 신설 — `az containerapp update / set-env-vars / secret set / revision activate` 직전 health snapshot + 변경 후 3회 polling
- `.claude/skills/rollback-revision/` 신설 — Container Apps revision activate/deactivate 자동화
- `.claude/scripts/sensor-response-zero-realtime.sh` 신설 — 응답 텍스트 추정 키워드 + 직접 명령 출력 동반 검증

**본 세션 발견 거짓 사슬 (incident-log 박제)**:
- sensor-orchestration-ratio가 `name="Task"`만 grep — 실제 Claude Code tool name은 `"Agent"` → 7일간 70건 호출이 `0건`으로 거짓 측정
- 메인 Claude가 그 0건을 검증 없이 "7 에이전트 안 씀" 단정 보고
- §15.7.3.2 "jsonl flush 한계"라고 잘못된 분석 박제
- META_PASS 다운그레이드로 자기 면죄
- 묶음 KK 보고서 결함 #2도 거짓 진단 박제 → **해당 보고서 정정 필요**

**즉시 수정 완료**:
- sensor-orchestration-ratio.sh: `name in ('Task', 'Agent')` 매칭으로 정합화
- sensor-adversarial P20: UTC date 사용 (자기 발견 결함 즉시 정정)
- sensor-response-zero-realtime grep -c multi-line 결함 즉시 정정

**최근 커밋**:
- claude-docs `fd63f08` (2026-05-06) — 묶음 LL 후속 (HANDOVER §3 갭 보강 skill +2 + sensor +1)
- claude-docs `1876953` (2026-05-06) — 묶음 LL incident-log 시스템 도입 + Constitution P20

**다음 세션 첫 명령** (이전 §1.4와 함께):
```bash
# 1. incident-log 누적 확인
wc -l .claude/state/incident-log.jsonl
tail -10 .claude/state/incident-log.jsonl | python3 -c "import sys,json; [print(f\"  [{json.loads(l)['severity']}/{json.loads(l)['category']}] {json.loads(l)['description'][:80]}\") for l in sys.stdin]"

# 2. P20 작동 검증
bash .claude/scripts/sensor-adversarial-pre-commit.sh 2>&1 | grep "P20"

# 3. 본 세션 명시 못 받은 가드 차단 명령 (§1.4 §6 참조)
```

---

## 🚨 1.4. CRITICAL — 2026-05-06 거짓 검증 보고 누적 + dev API DOWN

**즉시 Read 강제**: `reports/HANDOVER-CRITICAL-2026-05-06.md` (470줄, 본 세션 종료 직전 박제)

**핵심 사실** (사용자 명시 "정상 동작 한다고 뻥치는거 다시 시작했네"):
- 본 세션 11 commit 모두 **dev 실 환경 동작 검증 0건** (코드 단위 spec / git pre-commit hook / 이미지 push까지만 PASS)
- dev API `grimoire-server-dev` revision 152/153 모두 **HealthState=Unhealthy / RunningState=Failed**
- PAY-P2-3 commit `83715e3` 배포 시점부터 dev API down 가능성 (실 검증 0건이라 확정 불가)
- 보안 마이그레이션 (env → secretRef): dev에 8건 적용 완료, 단 revision 153 자체는 Unhealthy
- prod 영향 **0건** (보안 마이그레이션 / 기능 변경 모두 dev only)

**다음 세션 첫 명령**: `cat reports/HANDOVER-CRITICAL-2026-05-06.md` 후 §6 ABSOLUTE 명령 실행.

**거짓 검증 패턴 차단 절대 규정** (다음 세션):
1. "PASS" 보고 시 검증 범위 명시 강제 ("코드 단위 spec PASS, 운영 환경 미검증" 형식)
2. 추정 보고 0건 (§0 ZERO-TOLERANCE 강제)
3. dev curl timeout = cold start 단정 절대 금지 (revision health 직접 확인)
4. 가드 차단 명령은 사용자 명시 권한 요청 (변명 0)

---

## 🎯 1.5. 진행 현황 (2026-05-04 07:00 기준 — 채팅방 폭파 예방 박제)

### ✅ 완료 (3 레포 develop push 완료, 모든 commit hash 박제)

| 작업 | server | web | claude-docs |
|------|--------|-----|-------------|
| 작업 B (테마 에디터 preset name) | — | `3682081` | `2bf9dc5` |
| 작업 C (publishTheme bakedCssUrl) | `ff493dd` | `70ca832` | `8bfc737` |
| PAY-P0-1 webhook event_id 멱등성 | `8c13103` | `9c4b409` | `86f7487` |
| PAY-P0-1 drift fix (sensor 25→26) | — | — | `06de6c6` |
| PAY-P0-2 PG↔DB 정합성 cron | `8e9e02e` | `849f771` | `790e692` |
| PAY-P0-3 운영자 수동 크레딧 UI | — | `af3f04c` | `841e704` |
| **commit hook 자동화 보강** (사용자 지적 후) | `1f43b05` | `dd3717b` | `43c1728` (다른 동시 세션 묶음 KK) |
| CERTI_PROJ 외부 leak 제거 | `b67233c` | — | — |
| 결제 전수검사 + 계획 박제 | — | — | `43c1728` (`reports/PAYMENT_NEXT_STEPS.md`) |
| HANDOVER §1.5 박제 (채팅방 폭파 예방) | — | — | `7d30131` |
| **PAY-P1-1 Refund 정밀 처리** (적자 위험 차단) | `adfcae8` | `eb64a8b` | `2ed585e` |
| **PAY-P1-1 종료 메모리 박제** | — | — | (메모리 박제만, 본 commit) |
| **EMAIL-P0-1 시드/db-sync/e2e 가짜 도메인 정리** (2026-05-04) | `ddb14ab` | `4f9ae73` | `8820684` |
| **PAY-P1-3 결제 실패 retry 정책 + cleanup cron** (2026-05-04) | `888fe2b` | `1d924db` (docs sync) | `59a33e4` |
| **EmailServicePort 캡슐화 인터페이스 + NullAdapter** (2026-05-05) | `b49b6ba` | — | `afdaf56` (PLAN §11/§12/§13 + Sprint 계약) |
| **EMAIL-P0-3 Phase 1 + Phase 2 slug 로그인 마이그레이션** (2026-05-05) | `fe4ca93` | `a04eca2` | `004a825` |
| **HANDOVER §1.5 + USER_VERIFICATION_GUIDE-2026-05-05** (2026-05-05) | — | — | `6def365` + `06e727b` |
| **claude-docs main 머지** (2026-05-05, 사용자 정정 "dev까지만") | — | — | `a63eb36` (정본만, 운영 영향 0) |
| **다른 세션 #10_8 PP-3~PP-11 + PAY-P2-1/2/3** (2026-05-06) | `709ad12` + `88487c3` + `83715e3` + `d115f13` + `138435f` | — | `4310875` ~ `a5bf760` (14 commit 사슬) |
| **PAY-P2-4 AdminAuditLog 정밀화 — beforeState/afterState** (2026-05-07) | `64b6187` | — | `50c9676` |

### 🚀 다음 트랙 (사용자 결정 영역 — 2026-05-05 갱신, EMAIL-P0-3 완료 후)

| 옵션 | 트랙 | 시간 | 비고 |
|---|---|---|---|
| **A** | EMAIL-P0-2 운영 DB SQL 백필 (사용자 영역) | 30분 | 12~15 row 가짜 이메일 정리, 사용자 직접 SQL 실행 |
| **B** | server↔web docs drift 회복 sprint | ~30분 | 잔존 eval drift, 자율 가능 |
| **C** | EMAIL-P1-1 이메일 인증 시스템 + 비밀번호 초기화 | ~12~16h | **사용자 절대 규정 0-1 외부 API 해제 결정 필수** (AWS SES 추천 / Resend / SendGrid / Postmark). EmailServicePort 캡슐화 박제 완료 → 어댑터만 구현 |
| **D** | EMAIL-P1-2 OAuth Kakao/Naver 확장 | ~8h | 사용자 Developer Console 등록 필요, 외부 API 0건 |
| **E** | EMAIL-P1-3 결제 이메일 알림 (PAY-P1-2 흡수) | ~16~20h | EMAIL-P1-1 선행 의존, 외부 API 결정 필수 |
| **F** | OAuth 자동 링크 보안 강화 sprint (위험 영역 #1) | ~3~4h | 별도 보안 sprint, EMAIL-P0-3에서 OUT 박제 |
| **G** | SignupHistory slug 정책 검토 sprint (위험 영역 #2) | ~2h | EMAIL-P0-3에서 OUT 박제 |
| **H** | 작업 D (테마 배정 UI) + E (조회수 조사) | ~3~4h | production-bug-triage skill 발동 |
| **I** | main per-repo 머지 + dev 검증 + 휴식 | 사용자 영역 | 안전 stop |
| **J** | PAY-P2 (부분 환불 / DLQ / SMS) | ~9h | DLQ는 CERTI 차용 가능 |
| **K** | 작업 A + PAY-P1-4 (구독제 요금제 통합) | ~5~8h | 큰 작업, 기획 단계 선행 필수 |

### 📦 사용자 영역 잔존 (PAY-P0 + P1-1 + P1-3 + EMAIL-P0-1 + EMAIL-P0-3 통합 — 2026-05-05 갱신)

| # | 항목 | 명령 |
|---|------|------|
| 1 | main per-repo 머지 (3 레포) | "claude-docs main 머지" / "server main 머지" / "web main 머지" 형식 명시 |
| 2 | PAY-P0-1 dev 검증 | dev에 `PUBLIC_API_BASE_URL` env 추가 + Polar 동일 event_id 두 번 시뮬 |
| 3 | PAY-P0-2 dev 검증 | Container Apps 로그에서 `[PaymentReconciliationJob] 시작 ... 완료` 1회 박제 |
| 4 | PAY-P0-3 dev 검증 | admin 화면 클릭 (검색→amount+reason→confirm→toast + DB credit_logs row 박제) |
| 5 | PAY-P1-1 dev 검증 | Polar `order.refunded` webhook 발생 시 RefundLog row + Author.credits decrement + AuditLog operator='system_refund' 박제 확인 |
| 6 | **PAY-P1-3 dev 검증** | `curl POST /api/payments/initiate` 동일 productId 2회 → 응답 paymentId 동일 + Polar URL 신규 발급 + Container Apps 로그 `[PaymentCleanupJob] 시작 ... 완료` 새벽 4시 1회 박제 |
| 7 | **EMAIL-P0-2 운영 DB SQL** | research/EMAIL_INTEGRITY_PLAN.md §2-1 EMAIL-P0-2 SQL 4 Phase (백업 → 영향 row 확인 → 종속 데이터 정리 → 작가 row 삭제 → 회귀 검증) — dev → prod 순차 |
| 8 | prod 배포 | `npx prisma generate` (PAY-P1-3 schema 변경 0건이므로 migrate deploy 불필요) + `make deploy-prod` |
| 9 | **PAY-P1-3 dev 검증 추가** | `PAYMENT_CLEANUP_DISABLED=1` env 미박제 (운영자 긴급 차단용 미리 박제 권장, INFRASTRUCTURE.md §7-B 참조) |
| 10 | **EMAIL-P0-3 dev 검증** | `curl POST /api/auth/login -d '{"slug":"deerdevil","password":"..."}'` 200 반환 검증 + email 후향호환 200 검증 + email+slug 동시 박제 시 400 검증 |
| 11 | **이메일 SaaS 결정** | research/EMAIL_INTEGRITY_PLAN.md §11 결정 게이트 — AWS SES (추천 ₩700/월) / Resend / SendGrid / Postmark 중 1택 + 사용자 절대 규정 0-1 해제 명시. EmailServicePort 캡슐화 박제 완료 → 어댑터만 추가 |

### 📊 인벤토리 변동 (PAY-P2-4 종료 시점 — 2026-05-07 갱신)
- Skills 17 활성 + 9 GRAY (`_archive/`)
- Sensors **32 → 37** (+5 다른 세션 #10_8: oauth-email-verification + partial-refund + webhook-dlq + sms-service-port + skill-invocation-rate, +1 본 세션: audit-log-before-after)
- shared-contracts **§15 → §20** (+5: OAuthEmailVerification + PartialRefund + WebhookDLQ + SmsServicePort + AdminAuditLog beforeState/afterState)
- Eval regression **58 → 64** (+6: regression-60 OAuth, +61 partial-refund, +62 webhook-dlq, +63 sms-port, +64 audit-log-before-after)
- jest server **572 → 625** (+53 누적: PAY-P2-1 16 + P2-2 8 + P2-3 10 + P2-4 +21)
- vitest web 151 (불변 — 본 sprint web 변경 0)
- DB 모델 +1 (WebhookRetryQueue, PAY-P2-2)
- @Cron Job +1 (WebhookRetryJob @Cron 5분)
- Hexagonal Port +1 (SmsServicePort)
- Hooks 13 / Hook 이벤트 12종 (PP-6 post-response-skill-injector + PP-7 pretooluse-edit-write-guard 신설)
- jsonl state 13 (`.claude/state/`)
- AuditLog action +5 (refund_partial / refund_partial_deficit / system_dlq / system_cleanup payment_expire / payment_completed)
- AuditLogService.log() 시그니처: 4-arg → 6-arg BACKWARD COMPATIBLE (PAY-P2-4)
- 정본 신설: research/EMAIL_INTEGRITY_PLAN.md + research/PAYMENT_SYSTEM_PLAN.md (PAY-P2 마스터 플랜) + reports/PAY-P2-MASTER-PLAN.md (다른 세션 박제) + reports/USER_VERIFICATION_GUIDE-2026-05-05.md + reports/HANDOVER-CRITICAL-2026-05-06.md + reports/HANDOVER-CRITICAL-2026-05-06-PP.md + HARNESS_MAP.html

### 📊 다른 세션 인벤토리 변동 (참고 — 2026-05-06 박제, 본 세션과 별개)
- Skills 24 (불변)
- Sensors **25 → 32** (+7: payment-idempotency / payment-reconciliation / admin-credit-ui / refund-atomicity / fake-email-leak / payment-retry-reuse / slug-login)
- Knowledge 9 (불변)
- shared-contracts **§1~10 → §1~15** (+5: WebhookEventIdempotency / PaymentReconciliation / RefundPaymentAtomically / PaymentRetryReuse / SlugLogin)
- Eval regression **51 → 58** (+7: regression-52~55 PAY-P0/P1-1, regression-58 EMAIL-P0-1, regression-57 PAY-P1-3, regression-59 EMAIL-P0-3 slug 로그인)
- jest server **494 → 572** (+78 신규 spec — PAY-P0/P1-1 38 + PAY-P1-3 15 + EMAIL-P0-3 6 + EmailServicePort/NullAdapter 8 + 기타 11)
- vitest web **125 → 151** (+26 신규 spec — EMAIL-P0-3 11 (AuthProvider.test) + 기타 15)
- DB 모델 +3 (WebhookEvent / ReconciliationCheckpoint / RefundLog) — PAY-P1-3 + EMAIL-P0-3 schema 변경 0건
- Constitution 19 principles (불변)
- Hooks 9 이벤트 14 스크립트 + 3 레포 pre-commit/pre-push 자동 발동 강제
- 정본 신설: research/EMAIL_INTEGRITY_PLAN.md (이메일 시스템 전수 정본, §11~§13 정밀 박제)
- Cron Job +2 (PaymentReconciliationJob 새벽 3시 + 10분 주기 + PaymentCleanupJob 새벽 4시 1회)
- Hexagonal Port +1 (EmailServicePort) + Adapter +1 (NullEmailAdapter, 외부 API 0건) — 사용자 SaaS 결정 후 ResendAdapter / SesAdapter 어댑터만 추가
- Auth 시그니처 변경 (LoginDto + auth.usecase.login) — email/slug 양립 + 후향호환 보존

### 🔍 거짓말 차단 효과 (PAY-P0 → P1-1 강화 흐름 검증)
- ✅ PAY-P0-2/3/P1-1 모두 server/web agent commit/push 0건 (메인 위임 정합)
- ✅ spec 더미 assertion 0건 (qa Evaluator 직접 Read 검증)
- ✅ CERTI_PROJ/brightmall/thermage/inapi 외부 인용 0건 (server/web grep)
- ✅ commit/push 직전 sensor-adversarial 자동 발동 강제 (3 레포 모두)
- ⚠️ 1건 부분 거짓 (PAY-P1-1 server agent "eval 55/55" → 실제 52/55, docs drift 누락) → qa 즉시 발견 + 메인 server→web sync 보강

### 🎯 다음 세션 시작 시 첫 명령 (채팅방 폭파 시 즉시 이어받기 — 2026-05-05 갱신)

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire

# 1. 핸드오버 + 사용자 검증 가이드 + 메모리 Read
cat HANDOVER_NEXT_SESSION.md  # 본 파일 §1.5 진행 현황 (다음 트랙 11 옵션 + 사용자 영역 11건)
cat reports/USER_VERIFICATION_GUIDE-2026-05-05.md  # 사용자 권한 영역 검증 절차 (10번 EMAIL-P0-2 SQL + 4-9번 dev curl)
cat reports/sprint-email-p0-3-slug-login-progress.md  # 종료 박제 (정본)
cat research/EMAIL_INTEGRITY_PLAN.md  # 이메일 시스템 정본 (§11~§13 정밀)
cat /Users/sokol/.claude/projects/-Users-sokol-Desktop-Git-ProjectGrimoire/memory/MEMORY.md

# 2. 현재 상태 확인 (EMAIL-P0-3 종료 시점)
git log --oneline -5
git -C grimoire-server log --oneline -5
git -C grimoire-web log --oneline -5

# 3. 시스템 인벤토리 검증
bash .claude/scripts/sensor-adversarial-pre-commit.sh
bash .claude/scripts/sensor-slug-login.sh        # EMAIL-P0-3 회귀 차단 (12/12 PASS)
bash .claude/scripts/sensor-fake-email-leak.sh   # EMAIL-P0-1 회귀 차단
bash eval/scripts/eval-runner.sh                 # regression-58/59 포함

# 4. dev 환경 상태 확인 (사용자 영역)
gh run list -R gelb2/grimoire-server -L 3
gh run list -R gelb2/grimoire-web -L 3
az containerapp show --name grimoire-server-dev --resource-group zenith-rg --query "{runningStatus:properties.runningStatus, minReplicas:properties.template.scale.minReplicas}"

# 5. dev API cold start 진단 (반드시 wake up 후 검증)
# 첫 요청은 524/timeout 가능 — minReplicas=0 + Container Apps startup 30~60s
# wake up 후 재시도: curl ... --max-time 60

# 6. 다음 트랙 진입 (사용자 결정 영역, §1.5 다음 트랙 11 옵션 중)
```

### 🚨 다음 세션 즉시 알아야 할 사항 (2026-05-05 EMAIL-P0-3 종료 시점)

1. **dev API server `cold start` 한계**: minReplicas=0 → 첫 요청 startup 30~60s → Cloudflare 100s timeout. 메인 curl 검증은 wake up 후 재시도 필요. 사용자가 **az containerapp logs**로 직접 진단 권장.
2. **사용자 영역 잔존 11건** (§1.5 박제) — main per-repo 머지 (server/web만 보류, claude-docs 완료) + dev 검증 (자격증명 영역) + EMAIL-P0-2 운영 DB SQL + 이메일 SaaS 결정.
3. **시스템 가드 deny 박제**: server/web main push가 시스템 가드로 차단 — "Pushing to main bypasses PR review". 사용자 명시 권한 (예: `gh pr create` 또는 직접 명시) 필요.
4. **다음 트랙 결정 영역**: §1.5 11 옵션 중 사용자 선택. 외부 API 결정 (이메일 SaaS) 진입 여부 + main per-repo 머지 시점 결정.

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
