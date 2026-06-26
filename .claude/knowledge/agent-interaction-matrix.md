---
name: 7 핵심 도메인 에이전트 핸드오프 매트릭스 (§8.8 — 전체 10 중 7 핵심 기준, 3 메타 별도)
description: planner / researcher / cost-accountant / visual-canon-keeper / server / web / qa 간 상호 호출 규칙·산출물 파일·트리거·금지 조합. agent-system.md(역할 개요)의 보완 정본.
type: project
created: 2026-04-26
related:
  - agent-system.md
  - sensors.md
  - .claude/prompts/README.md
  - AUTOMATION.md §1
---

# Agent Interaction Matrix — 7 핵심 도메인 7×7 핸드오프 정본

> **범위 (2026-06-26 정합)**: 본 매트릭스는 **7 핵심 도메인 에이전트** 기준이다. 전체 에이전트는 **10개** (7 핵심 + 3 메타: infrastructure / harness / verifier). 3 메타 에이전트는 도메인 작업 흐름(기획→구현→검증)의 트리거 대상이 아니라 시스템 운영 주체이므로 본 매트릭스에서 제외하고 `agent-system.md` §3에서 별도 명시한다.
>
> agent-system.md가 **역할 분담 개요**라면, 본 문서는 **상호 호출 규칙·산출물·금지 조합**을 정밀 명시한다.
> Fowler "Requisite Variety" + sshh.io "explicit handoff" 원칙 적용.
>
> **2026-04-30 #10 갱신**: 산출물 형식(reports/*.md)은 모두 `.claude/shared-contracts.md` 정본을 따른다 (책 Ch 16). 본 문서는 **호출 규칙**만 명시하고, **형식**은 shared-contracts에서 관리.

## 1. 표기 규약

- **✅ 허용**: 정상 호출 가능 + 산출물 파일 명시
- **(간접)**: 직접 호출 안 함, planner/qa 경유
- **❌ 금지**: 호출 시 위반 (사유 명시)
- **self**: 자기 자신 (의미 없음)

## 2. 핸드오프 매트릭스

| FROM \ TO | planner | researcher | cost-accountant | visual-canon-keeper | server | web | qa |
|---|---|---|---|---|---|---|---|
| **사용자** | ✅ 요구사항 (기획 시작) | ✅ 직접 조사 요청 | ❌ (planner 경유) | ❌ (planner 경유) | ❌ (planner 경유) | ❌ (planner 경유) | ✅ 전수검사 직접 요청 |
| **planner** | self | ✅ 시장 조사 (PLANNER_REPORT 추가 조사 필요 명시) | ✅ AI 기능 마진 검증 | ✅ 시각 컴포넌트 검수 | ✅ 구현 위임 (PLANNER_REPORT.server 섹션) | ✅ 구현 위임 (PLANNER_REPORT.web 섹션) | (간접 — qa는 server/web 경유) |
| **researcher** | ✅ 조사 결과 (SWEEP_REPORT) | self | ✅ AI 가격 변동 알림 (COST_ALERT) | ❌ (시각 정본은 내부 정의) | ❌ | ❌ | ❌ |
| **cost-accountant** | ✅ 승인/거절 (COST_AUDIT_REPORT) | ❌ (역방향) | self | ❌ | (간접 — server가 COST_AUDIT 참조) | (간접 — web가 COST_AUDIT 참조) | ✅ 배포 게이트 (COST_AUDIT의 CRITICAL) |
| **visual-canon-keeper** | ✅ 검수 결과 (VISUAL_CANON_REPORT) | ❌ | ❌ | self | (간접 — server가 테마 생성 변경 시) | ✅ 검수 결과 (VISUAL_CANON_REPORT.PASS/CONDITIONAL/FAIL) | ✅ 배포 게이트 (VISUAL_CANON CRITICAL) |
| **server** | ❌ (역방향) | ❌ | (간접) | (간접) | self | ✅ docs 정본 동기화 (api-contract / data-model / glossary / environments / ai-analysis-spec / TERMS / PRIVACY) | ✅ DEV_REPORT.server + sensor-server.sh raw |
| **web** | ❌ (역방향) | ❌ | (간접) | (간접) | ✅ design-tokens / theme-spec 정본 동기화 | self | ✅ DEV_REPORT.web + sensor-web.sh raw + Playwright 결과 |
| **qa** | ✅ 회귀 항목 (QA_REPORT.regressions) | ❌ | ❌ | ❌ | ✅ 회귀 fix 요청 (QA_REPORT.server) | ✅ 회귀 fix 요청 (QA_REPORT.web) | self |

## 3. 산출물 파일 정합 (`reports/`)

| 산출자 | 파일 | 소비자 |
|---|---|---|
| researcher | `reports/SWEEP_REPORT.md` | planner / cost-accountant |
| researcher | `reports/AI_COST_MONITOR.md` | cost-accountant (매일) |
| researcher | `reports/COST_ALERT.md` (이벤트 발생 시에만) | cost-accountant (즉시) |
| cost-accountant | `reports/COST_AUDIT_REPORT.md` | planner / server / web / qa |
| visual-canon-keeper | `reports/VISUAL_CANON_REPORT.md` | planner / web / qa |
| planner | `reports/PLANNER_REPORT.md` | server / web (server 섹션 + web 섹션 분리) |
| server + web | `reports/DEV_REPORT.md` (server 섹션 + web 섹션) | qa |
| qa | `reports/QA_REPORT.md` | 사용자 (배포 게이트 판정) |
| (옵션) researcher | `reports/SWEEP_REPORT.md` 기반 | planner |
| (옵션) 시스템 | `reports/INCIDENT_*.md` (장애 발생 시) | qa / server / web |

## 4. 핵심 트리거 규칙

### 4-1. AI 기능 신설 시 (필수 흐름)
```
planner → cost-accountant → 승인(COST_AUDIT_REPORT) → planner → server/web → qa
```
- cost-accountant 승인 없는 AI 기능 구현 시 PLANNING §0 위반 = 사용자 즉시 에스컬레이션
- 마진 ≥3배 미충족 시 cost-accountant가 거절 → planner가 기획 재설계

### 4-2. 시각 컴포넌트 신설 시 (필수 흐름)
```
planner → visual-canon-keeper → 검수(VISUAL_CANON_REPORT.PASS) → planner → web → qa
```
- VCK 검수 없는 새 시각 컴포넌트 = CLAUDE.md §1 위반
- VCK CRITICAL 0건 될 때까지 web은 신규 시각 작업 보류

### 4-3. 결제 / Polar 변경 시 (필수 흐름)
```
planner → cost-accountant (마진 영향 검증) → server (구현) → qa (sensor-credit-atomicity 강제)
```
- sensor-credit-atomicity FAIL 시 qa는 머지 차단

### 4-4. 마이그레이션 / DB 스키마 변경 시
```
server → docs/data-model.md + SCHEMA.md 동시 갱신 → web 복사 → qa (sensor-docs-sync 강제)
```
- 코드 + 문서 같은 커밋 강제 (CLAUDE.md §6)

### 4-5. 가격 변동 감지 시 (자동 트리거)
```
researcher (매일 sweep) → AI_COST_MONITOR.md 갱신 → 변동 감지 시 COST_ALERT.md 생성 → cost-accountant 즉시 호출 → COST_AUDIT_REPORT 재산정 → 마진 <50% 하락 시 사용자 에스컬레이션
```

## 5. 금지 조합 (위반 시 즉시 중단)

| 조합 | 사유 | 위반 시 결과 |
|---|---|---|
| server → ai-cost-table.md 직접 수정 | cost-accountant 단독 관리 | PLANNING §0 위반 |
| server → design-tokens.md 직접 수정 | web 정본 | docs-sync FAIL |
| web → api-contract.md / data-model.md 직접 수정 | server 정본 | docs-sync FAIL |
| 임의 에이전트 → ACCOUNTS.md 참조 | 시크릿 노출 위험 | 보안 회수 |
| 임의 에이전트 → 작가 본문 인용/로깅 | 작가 콘텐츠 보호 | 즉시 차단 |
| qa → 코드 수정 | qa는 검증 전담 | 역할 위반 |
| 사용자 → 직접 server/web 호출 (planner 우회) | 핸드오프 추적 누락 | 권장 안 함 (긴급 시만 허용) |

## 6. 호출 비용 회피 — 메인 Claude 직접 처리 조건

CLAUDE.md §14.2 규칙 + Pattern 1 (orchestration 분리):

다음 경우는 **에이전트 spawn 없이 메인 Claude가 직접 처리**:
- 문서·메모리·`.claude/` 설정 변경 (조율 자체)
- 단순 grep/실측·sanity 명령 (Bash 1~3개 수준)
- 사용자가 "직접 해" 명시 지시
- 작업 크기가 ~15초 미만이라 spawn 비용이 작업보다 큰 경우

근거: `research/HARNESS_FIELD_PATTERNS_4.md` §15.1 패턴 1, `research/HARNESS_ENGINEERING.md` §16 채택 결정.

## 7. 시간대 (launchd 자율 실행 — ⛔ 영구 비활성)

> **2026-04-26 #9 사용자 결정**: launchd 자율 실행 **무기한 보류**. 모든 에이전트는 on-demand (Task tool) 호출 영구 정착.
> 아래 시간대는 **참조용 보존** (재고 자체 무기한 미정).

| 시각 (KST) | 에이전트 | 작업 |
|---|---|---|
| 18:04 | researcher | Daily Discovery + Sweep + AI 가격 모니터링 |
| 19:08 | cost-accountant | 원가 감사 |
| 20:11 | planner | 기획 Draft |
| 21:14 | visual-canon-keeper | 정본 diff 감사 |
| 22:17 | server + web (병렬) | DEV_REPORT 작성 |
| 23:21 | qa | 전수검사 |

> **on-demand 정착 운영**: 사용자 요청 시 또는 메인 Claude가 §15.7 위임 가치 매트릭스에 따라 Task tool로 호출.
> AUTOMATION.md §2 + research/HARNESS_ENGINEERING.md §14.7 참조.

## 8. 매트릭스 변경 시 갱신 절차

본 문서 변경 시:
1. `agent-system.md` (역할 분담 개요) 동시 갱신
2. `AUTOMATION.md` §1 에이전트 인벤토리 동시 갱신
3. `research/HARNESS_ENGINEERING.md` §8.8 / §9.4 / §14.1 갱신
4. drift sensor (`instructions-drift-check.sh`) 재실행하여 silent 확인

## 관련 정본
- `.claude/knowledge/agent-system.md` — 역할 분담 개요
- `.claude/knowledge/sensors.md` — 센서 인벤토리
- `.claude/prompts/README.md` — 프롬프트 ↔ 에이전트 1:1 매핑
- `AUTOMATION.md` §1 — 에이전트 인벤토리
- `research/HARNESS_ENGINEERING.md` §8.8 / §9.4 / §14.1
- `CLAUDE.md` §14.2 — 메인 Claude 오케스트레이션 규칙

마지막 업데이트: 2026-04-26
