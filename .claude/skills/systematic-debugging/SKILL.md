---
name: systematic-debugging
description: 복잡한 회귀(다중 원인 후보 / 재현 어려움 / production-bug-triage 1차 실측만으로 root cause 도달 못 함)에서 발동하는 가설 분리·변수 분리·root cause 도달 메타 절차. obra/superpowers (168k stars MIT) systematic-debugging 차용 + ProjectGrimoire 도메인 적용 (한국어 + Hexagonal/FSD 도메인 인지). production-bug-triage(증상→실측 1차)의 후속 절차.
allowed-tools: Read, Bash, Grep, Glob, Edit, Write
disable-model-invocation: true
effort: high
triggers:
  - "원인이 뭐"
  - "왜 안 되"
  - "이상하게"
  - "가끔"
  - "재현 어려"
  - "여러 곳"
  - "근본 원인"
  - "root cause"
  - "복잡한 버그"
  - "디버깅 막힘"
---

# Systematic Debugging — 다중 가설 + 변수 분리 + Root Cause 도달

> **trigger-mode**: keyword + user-invocation (disable-model-invocation:true). paths 미적용 — 디버깅 키워드 + 사용자 명시 호출.

## 동기 (HARNESS §10 Phase 4 P2 신설)

**production-bug-triage**는 사용자 증상 보고 시 **1차 실측 절차** (curl→코드→수치 3단계). 단 이건 단일 가설 흐름.

복잡한 회귀(예: 2026-04-19_4 세션의 AI 분석 fetch aborted — BFF/server abortableRace/SDK 3 후보)에서는:
- 증상이 여러 단계 거쳐 나타남
- 단일 변수 변경으로 재현 불가
- 1차 실측만으로 root cause 도달 못 함

본 skill은 production-bug-triage **후속 절차**:
- 가설 분리 (3~5개)
- 변수 분리 (단일 변수만 변경)
- 실측 검증
- root cause 도달 → 회귀 차단

> obra/superpowers (168k stars, MIT, v5.0.7) `systematic-debugging` 패턴 차용 + Grimoire 도메인 적용 (한국어, Hexagonal/FSD 인지).

## 발동 조건

다음 중 1개 이상:
1. **production-bug-triage 1차 실측 후 root cause 미도달** (sensor PASS인데 사용자 증상 재발)
2. **다중 도메인 영향** (server + web + DB + Anthropic API 등 2+ 후보)
3. **재현 어려운 회귀** (특정 조건 / 가끔 / 환경별 차이)
4. **트리거 키워드 매칭** (사용자 메시지에 "근본 원인" / "왜 안 되" / "복잡한 버그" 등)

## 절차 (5 단계 — 한 단계씩 박제하며 진행)

### Step 1. 증상 명확화

각 항목 빠짐없이:
- **재현 절차**: 사용자가 한 행동의 정확한 순서 (예: "/dashboard/analysis 진입 → 분석 시작 → 30초 후 cancel 클릭")
- **기대**: 정상 시 어떻게 동작해야 하는가
- **실제**: 증상 (에러 메시지 / 시간 / 로그 / 스크린샷)
- **차이**: 기대 vs 실제의 정확한 차이 (모호하면 더 구체화)
- **빈도**: 항상 / 가끔 / 특정 조건만

```markdown
## 증상 박제
- 재현: ...
- 기대: ...
- 실제: ...
- 차이: ...
- 빈도: ...
- 환경: dev / prod / 로컬 (어디서 발생)
```

### Step 2. 가설 생성 (3~5개)

**단일 가설 종속 금지**. 가능한 원인 3~5개 나열:

```markdown
## 가설
1. **H1**: BFF 프록시 timeout (예: /api/analysis 30초 한도)
2. **H2**: server abortableRace가 cancel 신호 swallow
3. **H3**: Anthropic SDK signal 미전달 → 백그라운드 토큰 낭비
4. **H4**: client AbortController가 fetch 호출 시점에 미생성
5. **H5**: 환경변수 미설정 (e.g. ANTHROPIC_API_KEY 만료)
```

각 가설에 **검증 가능한 실측 명령** 1개 매핑:
- H1 → curl로 /api/analysis 직접 호출 (timeout 측정)
- H2 → server log에서 abortableRace 분기 확인
- H3 → Anthropic dashboard 토큰 사용량 (cancel 후 이어서 사용 시)
- H4 → 브라우저 DevTools Network에서 abort 시점 확인
- H5 → server env 검증 (`az containerapp show ... env`)

### Step 3. 변수 분리 + 실측

**한 번에 단일 변수만 변경**. 혼합 변경 금지:

```markdown
## 변수 분리 검증
- 시도 1: H1 검증 — curl /api/analysis 직접 (BFF 우회)
  - 결과: 30초 timeout 발생 → H1 부분 PASS (재현됨)
  - 단 cancel 시점 분기 미확인 → H2 후속 필요

- 시도 2: H2 검증 — server log에서 abortableRace 메시지 grep
  - 결과: cancel 메시지 0건 → H2 PASS (cancel 미작동)
  ...
```

**금지**:
- 여러 변수 동시 변경 (어느 게 효과 있었는지 모름)
- 추측으로 fix 적용 (CLAUDE.md §0 위반)

### Step 4. Root Cause 도달

가설 검증 결과 누적 → 단일 root cause 식별:

```markdown
## Root Cause
- 검증된 가설: H2 + H3 (server abortableRace는 작동하지만 Anthropic SDK signal 미전달)
- 1차 원인: askClaude() options에 signal 누락
- 2차 원인 (없으면 생략): -
- 회귀 가능성: SDK 호출 추가 시 signal 전달 누락 패턴
```

### Step 5. 회귀 차단 (재발 방지 박제)

root cause 박제 + 회귀 차단 메커니즘:

```markdown
## 회귀 차단
1. 코드 fix: askClaude options에 signal 추가
2. spec 보강: signal 미전달 시 throw or warning
3. sensor 신설 또는 보강: sensor-credit-atomicity / sensor-secret-leak 등 기존 sensor 강화
4. memory 박제: feedback_*.md 또는 research §10 Phase 4 후속 박제
```

## 절대 금지 사항

### [MUST NOT] 단일 가설 종속
- "아마 X 때문일 것이다" 추측 후 단일 가설 검증 → 다른 4개 가설 미검증
- CLAUDE.md §0 ZERO-TOLERANCE 위반

### [MUST NOT] 여러 변수 동시 변경
- 변수 A 변경 + 변수 B 변경 동시 → 어느 게 효과 있었는지 모름
- 단일 변수 → 측정 → 다음 단계 강제

### [MUST NOT] 1차 실측 없이 systematic-debugging 진입
- production-bug-triage가 먼저. 1차 실측 후 root cause 미도달 시 본 skill로 escalation
- 1차 실측 스킵 = 가설 5개 모두 추측 = §0 위반

### [MUST NOT] 회귀 차단 박제 없이 종료
- root cause 도달했어도 재발 방지 메커니즘 없으면 다음 세션 재발
- sensor 보강 또는 spec 박제 필수

## ProjectGrimoire 적용 사례

### 좋은 사례 (예상)

#### 사례 1: AI 분석 fetch aborted (2026-04-19_4 세션)
- 증상: cancel 후 토큰 사용 계속 (운영 비용 ↑)
- 가설 5개:
  - H1 BFF timeout / H2 server abortableRace / H3 SDK signal / H4 client controller / H5 env
- 검증: H2 + H3 (server는 cancel 처리하지만 SDK는 signal 미전달)
- root cause: askClaude options에 signal 누락
- 회귀 차단: spec 5건 추가 + N (SDK signal 전파) 작업으로 영구 해소

#### 사례 2: 분석/베스트 §0 FAIL 위험 (2026-04-26 #9)
- 증상: cost-margin sensor에서 베스트 안전배수 3.14× WARN
- 가설 4개:
  - H1 단가 인상 / H2 모델 다운그레이드 (Haiku) / H3 크레딧 인상 / H4 패키지 리네이밍
- 검증: H3 (크레딧 4 인상)이 모든 시뮬에서 PASS 회복
- root cause: F2 결정의 3 크레딧이 Sonnet 시뮬에서 약점
- 회귀 차단: ANALYSIS_CREDIT_COST 4 박제 + sensor 메시지 강화

### 나쁜 사례 (예방 대상)

- "아마 cold start 때문일 것"이라고 추측 후 코드 변경 → 실제 원인은 BFF timeout
- BFF + server + SDK 동시 변경 → 어느 fix가 효과 있었는지 모름

## production-bug-triage와 차이

| 축 | production-bug-triage | systematic-debugging |
|---|---|---|
| **트리거** | 사용자 증상 보고 (단순) | 1차 실측 후 root cause 미도달 (복잡) |
| **본질** | 실측 강제 (curl→코드→수치) | 가설 분리 + 변수 분리 + root cause |
| **단계** | 3 단계 (실측) | 5 단계 (증상→가설→변수→root cause→회귀 차단) |
| **출력** | 증상 + 1차 원인 후보 | root cause + 재발 방지 박제 |
| **시간** | ~10분 | ~30~60분 |

→ **production-bug-triage 후속 절차**. 통합 X, 분리 운영.

## 관련 정본
- `.claude/skills/production-bug-triage/SKILL.md` — 1차 절차
- `.claude/skills/verification-before-completion/SKILL.md` — Step 5 회귀 차단 후 검증 게이트
- `research/HARNESS_ENGINEERING.md` §10 Phase 4 — 디버깅 강화
- `research/HARNESS_ENGINEERING.md` §16 — 패턴 1 (오케스트레이션 분리) — 복잡 디버깅 시 subagent 위임 가치 ↑
- obra/superpowers (168k stars, MIT, v5.0.7) — 차용 원본
- CLAUDE.md §0 — 상태 추정 금지

---

마지막 업데이트: 2026-04-27
승격 원본: obra/superpowers (MIT) systematic-debugging
적용 영역: ProjectGrimoire 도메인 (한국어 + Hexagonal/FSD + sensor 통합)
