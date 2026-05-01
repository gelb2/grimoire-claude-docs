---
name: orchestration-decision
description: 새 작업 시작 전 "메인 Claude 직접 vs subagent 위임" 결정을 §15.7 위임 가치 매트릭스로 자동 분류한다. 작업 분해 / 다중 도메인 / cost-accountant·VCK·qa 외부 검증 필요 시 자동 발동. 책 Ch 16 멀티 에이전트 패턴 1 KPI 추적용.
allowed-tools: Read
disable-model-invocation: false
triggers:
  - "이 작업"
  - "다음 단계"
  - "어떻게 진행"
  - "직접 할까"
  - "위임할까"
  - "subagent"
  - "에이전트로"
  - "분할"
  - "오케스트레이션"
  - "메인 직접"
effort: low
# trigger-mode: keyword (triggers field) — paths 미적용, 작업 분해 키워드 기반
---

# Orchestration Decision — 메인 직접 vs subagent 위임 자동 분류

> **근거**: `research/HARNESS_FIELD_PATTERNS_4.md` §15.7 위임 가치 가이드라인 (2026-04-26 #9 신설). sensor-orchestration-ratio jsonl 사후 측정의 **사전 가이드** 역할. 패턴 1 KPI 추적용.

## 언제 발동하는가

다음 상황 1개 이상:

1. 새 작업 시작 전 (사용자 요청 또는 메인 Claude 자체 분류)
2. 작업 분해(sub-task 분할) 직전
3. cost-accountant / visual-canon-keeper / qa 외부 검증 필요 시
4. 다중 도메인 (server + web 동시) 작업 식별 시
5. 작업 시간 ≥ 1시간 예상 시

## 결정 매트릭스 (§15.7.1)

| 작업 특성 | 메인 직접 | subagent 위임 |
|---|---|---|
| **시간** ≤ 30분 | ✅ (spawn 오버헤드 > 작업) | ❌ |
| **시간** 30분 ~ 1시간 (단일 도메인) | ✅ 조건부 | ⚠️ 다중 도메인 시 |
| **시간** ≥ 1시간 + 다중 도메인 | ❌ (컨텍스트 폭주) | ✅ |
| **시간** ≥ 2시간 단일 도메인 | ⚠️ (컨텍스트 부담) | ✅ (격리 가치) |
| **도메인** 단일 (.claude/) | ✅ | ❌ |
| **도메인** 단일 (server only) | ⚠️ | ✅ grimoire-server |
| **도메인** 단일 (web only) | ⚠️ | ✅ grimoire-web |
| **도메인** 다중 (server + web) | ❌ | ✅ 병렬 |
| **검증 단계** (qa) | ❌ (자가 검증 신뢰성 ↓) | ✅ qa 독립 재실행 |
| **메모리/문서/.claude 설정** | ✅ (조율 자체) | ❌ |
| **단순 grep/실측** (Bash 1~3개) | ✅ | ❌ |
| **사용자 "직접 해" 명시** | ✅ | ❌ |
| **반복 sub-task 병렬화 가능** | ❌ (순차 비효율) | ✅ |
| **외부 검증 필요 (보안/원가/시각)** | ❌ | ✅ cost-accountant / VCK / qa |

## 핸드오프 비용 임계 (§15.7.2)

subagent 위임 비용:
- Spawn ~15초 + 컨텍스트 전달 2~5K + 결과 반환 1~3K + 메인 재인수 2~5K
- **총 ≈ 30초 + 5~13K 토큰**

작업 자체 비용 ≥ 위 임계 × 3 일 때 위임 가치:
- **시간**: ≥ 1시간 권장
- **토큰**: ≥ 30K (다중 파일 + 다중 도메인) 권장

## 결정 트리 (실전 가이드)

```
1. 사용자 명시 ("직접 해" / "에이전트한테 시켜")?
   → 사용자 의도 종속 (그대로 따름)

2. 작업 ≤ 30분 AND 단일 도메인?
   → 메인 직접 (spawn 오버헤드 > 작업)

3. 외부 검증(보안/원가/시각/qa) 필요?
   → cost-accountant / visual-canon-keeper / qa 위임 강제

4. 다중 도메인 (server + web)?
   → grimoire-server + grimoire-web 병렬 위임

5. 단일 도메인 + 작업 ≥ 1시간?
   → 해당 도메인 에이전트 위임 (grimoire-server / web / planner / researcher)

6. 메모리 / 문서 / .claude/ 설정 변경?
   → 메인 직접 (조율 자체)
```

## 작업 시작 시 자가 분류 박제

작업 시작 전 다음 형식으로 분류 박제 (사용자에게 보고 또는 내부 메모):

```
작업: {이름}
예상 시간: {N분 또는 N시간}
도메인: {single .claude/ | single server | single web | multi server+web | research/ | docs/}
외부 검증 필요: {None | cost-accountant | VCK | qa | 다중}
결정: {메인 직접 | subagent 위임 → grimoire-{name}}
근거: {매트릭스 행 N + 핸드오프 비용 ×3 임계 충족/미충족}
```

## 위임 결정 시 다음 단계

`Task` tool 호출 (Claude Code 내장 `Agent` tool):

```
Agent(
  subagent_type="grimoire-server",  # 또는 web / planner / cost-accountant / VCK / qa / researcher
  description="...",
  prompt="..."
)
```

- prompt에는 작업 컨텍스트 + 산출물 위치(`reports/{NAME}_REPORT.md`) + 검증 게이트(`sensor-*.sh`) 명시
- raw 결과 박제 의무: `.claude/AGENTS.md §1` 서브에이전트 리포트 박제 규칙 준수

## 박제 의무 (KPI 추적)

§15.7.3 형식으로 결정 결과 박제:

| 작업 | 시간 | 도메인 | 적합 결정 (매트릭스) | 실제 결정 | 합치 |
|---|---|---|---|---|---|
| {이름} | {N} | {도메인} | {적합} | {실제} | ✅/❌ |

박제 위치 (택1):
- 세션 메모리 `memory/project_session_YYYYMMDD_N.md`
- `reports/PLANNER_REPORT.md` (planner 위임 시)
- `reports/QA_REPORT.md` (qa 위임 시)

## 사후 측정 (sensor-orchestration-ratio)

- `.claude/scripts/sensor-orchestration-ratio.sh` — 매주 실행
- jsonl 파싱: 메인 Bash·Edit 횟수 vs Task tool 호출 횟수
- 목표 합치율 ≥ 80% 유지 (§15.7.4)
- 위임 가치 있는데 메인 직접 처리한 케이스 0% 향함

## 가이드라인 자체 진화 (§15.7.5)

본 가이드라인은 **운영 데이터로 진화**:
- 케이스 100건 도달 시 임계값 재검토
- 패턴 1 KPI 0.0 → 0.20 도달 시 가이드라인 1차 진화
- ProjectGrimoire 1인 운영 + 짧은 작업 빈도 패턴 → 다인 팀과 다를 수 있음

## 반례 박제

가이드라인과 다른 결정을 한 경우 사유를 함께 박제:
- 예: "단일 도메인 30분 작업 → 매트릭스는 메인 직접. 단 cost-accountant 마진 사전 검증이 필요해 위임 결정"
- 위치: 세션 메모리 또는 sensor-hits.jsonl

## 관련 정본
- `research/HARNESS_FIELD_PATTERNS_4.md` §15.7 — 위임 가치 가이드라인 정본
- `.claude/AGENTS.md` §2.2 — 메인 Claude 오케스트레이션 규칙
- `.claude/knowledge/agent-interaction-matrix.md` — 7×7 핸드오프 매트릭스
- `.claude/scripts/sensor-orchestration-ratio.sh` — 사후 측정
- `.claude/shared-contracts.md` — 인터페이스 정본
