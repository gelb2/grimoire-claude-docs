# 하네스 / 에이전트 구현상황 전수검사 (2026-05-30)

> 방법: **A**(인벤토리+Hook정합) = 메인 직접 실측 / **B**(센서·스킬·에이전트·라우팅) + **C**(settings·셀프테스트·드리프트) = grimoire-harness 감사 / 전 주장 **grimoire-verifier 독립 재실측**(작업≠검증). 이번 패스 **하네스 무변경**(감사 only). 상세 raw: `HARNESS_AUDIT_B_*.md`, `HARNESS_AUDIT_C_*.md`.

## 0. 종합 판정

| 영역 | 상태 | 근거 |
|---|---|---|
| Hook ↔ Script 정합 | ✅ **건강** | 10 이벤트/17 등록 스크립트 전부 실존·실행가능·비스텁. 죽은 등록 0/빈 가드 0 (bb57841 재발 없음) |
| 카운트 정합 | ✅ | sensor 57(det56+log1)/skill 26+archive9/agent 10/red-team 20/hooks 10·17 — 전부 실측 일치 |
| 셀프테스트 | ✅ | selftest PASS(FIRE_OK3/FAIL0)·adversarial FAIL0·redteam-gate 정상·memory-freshness PASS |
| 자기잠금(2026-05-29) | ✅ 재발 없음 | `permissions.deny` 키 부재, allow 11(인프라 화이트리스트), settings 편집 가능 |
| bash-guard 수정 유지 | ✅ | a4097fb(merge-base 오탐)·2a71978(경로정규화/&>/gcloud) 전건 유지 |
| 구문(bash -n) | ✅ | sensor 57/57 + 전 hook 0 FAIL |
| **센서 배선** | 🔴 **구조 결함** | 57개 중 자동 실행 8개뿐, **38/56 detector 고아**(정책 회귀 자동포착 경로 0). 중앙 디스패처 부재 |
| **드리프트 감지기** | 🔴 **고장(F-2)** | instructions-drift-check가 hooks 비교 코드 부재(데드 변수) → 문서 drift 누적 미감지 |
| **레드팀 게이트 출력** | 🟠 조용한 부패(F-1) | adversarial-pre-commit 정수비교 버그, stderr 누출(판정엔 무해) |
| 문서 드리프트 | 🟠 | HARNESS_ENGINEERING §14: agents 7→10, hooks 9·12→10·17, 표제 skills/sensors "17", red-team "16" |
| 라우팅 PP-7 | 🟠 | 불일치 4건(reports/ 라우팅 부재 등) |

**한 줄**: 하네스 **골격은 건강**(정합·게이트·보안 PASS)하나, **3대 구조 약점** — ①센서 대량 미배선(자동 정책검증 사실상 8개만) ②드리프트 감지기 자체 고장으로 문서 stale 누적 ③레드팀 핵심 센서 출력 부패.

## 1. 인벤토리 (S0, 메인 직접 실측)
- `.claude/scripts/` **86개 전부 .sh**: sensor-57 / pretooluse-4 / post-4 / posttooluse-1 / stop-1 / subagent-1 / check-1 / skill-1 / generate-2 / instructions-1 / loop-1 / user-1 / pre-1 / statusline-1
- skills **27 디렉터리** = 활성 **26**(전부 SKILL.md) + `_archive` 1(아카이브 9). 드리프트 아님
- agents **10**: cost-accountant/harness/infrastructure/planner/qa/researcher/server/verifier/visual-canon-keeper/web (외래 에이전트 0)
- settings.json hook **10 이벤트**: InstructionsLoaded/PostToolBatch/PostToolUse/PostToolUseFailure/PreCompact/PreToolUse/SessionStart/Stop/SubagentStop/UserPromptSubmit

## 2. Hook 정합 (S1, 메인 직접 실측 + verifier)
- 등록 17 스크립트 전부 실존+실행가능+비스텁. **죽은 등록 0 / 빈 가드 0 / 비실행 0**
- 미등록 비센서 12개 분류: `incident-log`·`pretooluse-main-whitelist`(hook가 호출=정상) / `statusline`(statusLine config) / `deploy-all`·`deploy-prod`·`update-harness-inventory`·`generate-skill-graph`·`orchestration-classify`·`run-agent`(AUTOMATION.md 수동도구=정상) / **`cost-tracker`·`adversarial-retry-handler`·`red-team-data-collector` = 문서참조만·런타임 미배선**(red-team-data-collector는 호출 skill이 _archive)

## 3. 결함 — 실재 버그 3건 (verifier 격리 재현 확인, 오경보 아님)
- **F-1** `sensor-adversarial-pre-commit.sh:249-252` — `grep -c ... || echo 0`가 0매칭 시 `0\n0` 멀티라인 생성 → `[ "0\n0" -eq 0 ]` = `integer expression expected` stderr 누출 + "박제 0\n0건" 출력 오염. 판정은 우연히 else(PASS)로 흘러 무해하나, **레드팀 핵심 게이트가 조용히 부패한 출력**. `${VAR:-0}`는 빈값만 방어(멀티라인 불가)
- **F-2** `instructions-drift-check.sh:72-76` — `hook_events` 추출 후 **이후 등장 0회 = 데드 변수**. 주석엔 "Hooks vs settings keys 비교" 의도 있으나 코드 부재 → 실행해도 무출력 exit0. **이것이 §14 hooks 드리프트가 자동 미감지된 직접 원인**
- **F-3** `sensor-instruction-degradation.sh:80-82` — 에이전트 수 **"7" 하드코딩** + 7개만 순회 → 실측 10 중 harness/infrastructure/verifier **3개 길이검사 누락**

## 4. 드리프트 — 문서 (verifier 확인)
`research/HARNESS_ENGINEERING.md` §14 (드리프트 정본 문서가 자기 stale):
- L711 Agents "7" → 실측 10 (+3)
- L756 Hooks "9 이벤트 12 스크립트" → 실측 10/17 (+1/+5, F-2로 자동 미감지)
- L26 표제 Skills "17"/Sensors "17" → 26/57 (본문 §14.2/14.4는 정합, **표제만 내부모순**)
- L793 red-team "16 principles" → 20 / "7×7 핸드오프"도 옛값
- (Skills26·Sensors57·Knowledge9·red-team20 본문 정합)
- 추가(Pass B): 6개 문서 "7/6 에이전트" stale, `sensors-overview` SKILL "14 sensors(2026-04-30)" stale

## 5. 미배선 — BUILT but NOT WIRED (Pass B + verifier 표본 4/4)
- **센서 57 중 자동 hook 체인 실행 = 8종**(adversarial/cost-margin/shared-contracts/instruction-degradation/secret-leak/credit-atomicity/red-team-source-whitelist/orchestration-ratio)
- **고아 38/56 detector** — hook/디스패처/skill/agent 어디서도 자동 미실행. 결제 12종 + 크레딧/채팅/감사 도메인이 삼중 미배선 → **정책 회귀 자동 포착 0**
  - 단 성격상 자동부적합 정상분(EXISTENCE 32/EXTERNAL 14/STUB 3) 일부 포함 — B 정직 재해석
  - **근본: 중앙 디스패처 부재**(PostToolBatch가 일괄 호출하지 않음)
- verifier 표본(sms-service-port/slug-login/webhook-dlq/chat-charge-tier) 4/4 고아 확인 → "38/56" 방향성 신뢰

## 6. 라우팅 PP-7 불일치 4건 (Pass B)
1. `harness.md §6-2`가 옛 EXPECTED_AGENT 포맷 기술(현 `pretooluse-main-whitelist.sh` 코드와 불일치)
2. **reports/ 경로 라우팅 부재** — QA/PLANNER/COST/VISUAL 산출물을 메인이 직접 작성 가능(가드 미반영)
3. 6개 문서 "7/6 에이전트" stale(신설 infra/harness/verifier 미반영)
4. Edit/Write 라우팅 미등재 에이전트 6(역할/리포트형 — verifier 읽기전용은 설계상 정상)

## 7. 라이브 발견 (감사 중 실제 발생)
- **bash-guard substring 오탐(deploy 판본)**: 메인의 **순수 읽기전용 grep** 명령이 인자에 `deploy-all.sh` 문자열을 포함했다는 이유로 "변경성 deploy 명령"으로 차단됨. 2026-05-30 메모리의 push/merge/commit 자연어 오탐과 동류. 가드는 정상 작동하나 read-only 명령 오차단 트레이드오프 존재(우회: 트리거어 회피)

## 8. 수정 제안 (적용 안 함 — 승인 후 grimoire-harness 위임)
| # | 대상 | 작업 | 위험 |
|---|---|---|---|
| P1 | F-2 `instructions-drift-check.sh` | hooks 비교 로직 구현(데드 변수 활성화) — drift 자동감지 복구 | 낮음 |
| P1 | F-1 `sensor-adversarial-pre-commit.sh:249` | `grep -c` 멀티라인 → `$(... | head -1)` 또는 `tr -d` 정규화 | 낮음 |
| P1 | F-3 `sensor-instruction-degradation.sh:80` | 하드코딩 "7" → agents/*.md 동적 카운트(10) | 낮음 |
| P2 | `HARNESS_ENGINEERING.md §14` | agents 7→10, hooks 9·12→10·17, 표제 17→26/57, red-team 16→20 정정 + 6개 문서 stale | 낮음 |
| P3 | 센서 38 고아 | 중앙 디스패처(PostToolBatch 일괄) 설계 or 도메인별 배선 — **설계 결정 필요** | 중간 |
| P3 | PP-7 reports/ 라우팅 | edit-write-guard에 reports/ 경로별 에이전트 라우팅 추가 | 중간 |
| P4 | 미배선 스크립트 3 | cost-tracker/adversarial-retry-handler/red-team-data-collector 배선 또는 정리 | 중간 |
| P4 | bash-guard deploy 오탐 | 읽기전용 grep/jq 화이트리스트 정교화(substring 한계 완화) | 중간 |
