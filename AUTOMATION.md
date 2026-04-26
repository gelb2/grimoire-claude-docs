# AUTOMATION.md — Grimoire 멀티 에이전트 운영 문서

> 2026-04-15 도입. projectZenith 패턴 차용 + Grimoire 고유 역할(cost-accountant, visual-canon-keeper).
> 에이전트·Skills·Sensors·Hooks 변경 시 이 문서도 반드시 갱신.
>
> **2026-04-26 현행화** — Skills 10 / Sensors 9 / Hooks 8 이벤트 11 스크립트 / Prompts server·web 분리 / launchd 비활성 사실 박제 / agent-interaction-matrix 신설.

---

## 0. 프롬프트 엔지니어링 정본 — 모든 에이전트 작업 전 필수 Read (역할별 차등)

> 루트 CLAUDE.md §15 규칙. 에이전트는 자기 역할에 해당하는 정본만 Read하고 시작한다.

| 에이전트 | GMP-v2.2 | prd-generation | vibe-coding |
|---------|:---:|:---:|:---:|
| planner | ✅ | ✅ | ✅ |
| researcher | ✅ | — | — |
| cost-accountant | — | — | — |
| visual-canon-keeper | — | — | — |
| server | — | — | ✅ |
| web | — | — | ✅ |
| qa | ✅ | — | ✅ |

정본 위치:
- `prompt-engineering/GMP-v2.2.md` — XML 태그, 이중 앵커, Chain-of-Verification, 우선순위 라벨([MUST]/[SHOULD]/[NICE])
- `prompt-engineering/prd-generation-prompt-gmp2.md` — 도메인검증→기능설계→기술설계 핸드오프 (planner 전용)
- `prompt-engineering/vibe-coding-unified-guide.md` — Phase 0~5, 레이어 구조, 게이트 체크, 작업 프롬프트 11종

적용 방식: 각 에이전트가 생성하는 모든 출력물(보고서, 기획 Draft, 코드 주석, 커밋 메시지)에 위 원칙 반영.

---

## 1. 에이전트 인벤토리 (7개)

| 에이전트 | 파일 | 역할 | 도구 | 모델 |
|---------|------|------|------|------|
| researcher | `.claude/agents/grimoire-researcher.md` | 경쟁사 + AI 가격 모니터링 | Read/Write/Edit/Glob/Grep/WebSearch/WebFetch | opus |
| cost-accountant | `.claude/agents/grimoire-cost-accountant.md` | PLANNING §0 원가 마진 검증 **(Grimoire 고유)** | +Bash | opus |
| planner | `.claude/agents/grimoire-planner.md` | 기획 Draft + 원가 게이트 트리거 | Read/Write/Edit/Glob/Grep | opus |
| visual-canon-keeper | `.claude/agents/grimoire-visual-canon-keeper.md` | 사슴악마 정본 수호 + 디자이너 **(Grimoire 고유)** | +Bash | opus |
| server | `.claude/agents/grimoire-server.md` | NestJS 백엔드 개발 | +Bash | opus |
| web | `.claude/agents/grimoire-web.md` | Next.js 프론트엔드 개발 | +Bash | opus |
| qa | `.claude/agents/grimoire-qa.md` | 전수검사 + 배포 게이트 | +Bash | opus |

> **핸드오프 매트릭스**: `.claude/knowledge/agent-interaction-matrix.md` 참조 (7×7 상호 호출 규칙·산출물·금지 조합).

### 1.1 Prompts 매핑 (자율 실행 / on-demand 호출용 — 7개 .txt)

| 에이전트 | 프롬프트 파일 | 비고 |
|---|---|---|
| planner | `.claude/prompts/planner.txt` | |
| researcher | `.claude/prompts/researcher.txt` | |
| cost-accountant | `.claude/prompts/cost-accountant.txt` | |
| visual-canon-keeper | `.claude/prompts/visual-canon-keeper.txt` | |
| **server** | **`.claude/prompts/server.txt`** ← 2026-04-26 신설 | NestJS 백엔드 단독 (이전: developers.txt 통합) |
| **web** | **`.claude/prompts/web.txt`** ← 2026-04-26 신설 | Next.js 프론트엔드 단독 (이전: developers.txt 통합) |
| qa | `.claude/prompts/qa.txt` | server + web 통합 검증 (양쪽 통합 책임이라 분리 안 함) |

> 이전 `developers.txt`는 `server.txt` + `web.txt`로 분리됨 (research/HARNESS_ENGINEERING.md §9.4 P0 해소).

---

## 1.5. Skills 인벤토리 (13개 — 2026-04-27 기준)

> Skill은 트리거 키워드 또는 사용자 명시 호출(`/skill-name`)로 발동. agent와 달리 도구 호출 단위.

| Skill | 발동 방식 | 용도 |
|---|---|---|
| `claude-in-chrome-recovery` | 키워드 | Chrome MCP 실패 시 3회 재시도 프로토콜 |
| `deploy-precheck` | 명시 호출 | 배포 전 sensor 일괄 + curl health |
| `dev-login-smoke` | 명시 호출 | dev 환경 로그인 스모크 테스트 |
| `gc-sweep` (2026-04-26) | 명시 호출 | 미참조·stale harness 자산 청소 (Fowler GC 축) |
| `feedback-to-skill` (2026-04-26 X-L) | 명시 호출 | feedback_*.md PROMOTE 후보를 draft skill로 변환 (Memory v2) |
| `handover-refresh` (2026-04-25 #8) | 명시 호출 | HANDOVER.md 자동 수집 갱신 |
| `macos-tcc-handling` | 키워드 | TCC 권한 다이얼로그 반복 시 osxkeychain 가이드 |
| `production-bug-triage` | 키워드 | 운영 증상 보고 시 curl→코드→수치 3단계 강제 |
| `refund-logic-audit` | 명시 호출 | 결제·환불 로직 감사 |
| `verification-before-completion` | 키워드 | 완료 선언 전 실측 증거 강제 |
| `worktree-isolation` (2026-04-27 F) | 명시 호출 | Edit 폭주 작업 시 git worktree 격리 (HARNESS §8.10 안전망) |
| `deploy-image-verify` (2026-04-27 EEE) | 명시 호출 | Container App image SHA vs git main HEAD 정합 검증 (sensor-deploy-drift 보완) |
| `writing-plans` (2026-04-25 #8) | 키워드 (≥30분 게이트) | 큰 작업 sub-task 분할 |

---

## 1.6. Hooks 인벤토리 (8 이벤트 / 11 스크립트 — 2026-04-26 기준)

`.claude/settings.json` 의 hooks 필드 정의. 이벤트별 스크립트 트리거.

| 이벤트 | 스크립트 | 용도 |
|---|---|---|
| SessionStart | `check-memory-freshness.sh` | 세션 시작 시 메모리 stale 검사 |
| Stop | `stop-memory-guard.sh` | 세션 종료 시 메모리 기록 강제 |
| UserPromptSubmit | `user-prompt-memory-check.sh` + `skill-injector.sh` | 사용자 입력 시 메모리 체크 + 트리거 키워드 매칭 |
| PreCompact | `pre-compact-memory-guard.sh` | 컨텍스트 압축 전 메모리 박제 |
| InstructionsLoaded | `instructions-drift-check.sh` | CLAUDE.md 로드 시 §14 인벤토리 vs 실측 drift 검출 |
| PreToolUse | `pretooluse-bash-guard.sh` | Bash 실행 전 위험 패턴 차단 |
| PostToolUse | `post-edit-tsc.sh` + `post-edit-spec-check.sh` | Edit/Write 후 tsc + spec 자동 검증 |
| PostToolBatch | `post-batch-tsc.sh` (debounce 60s) | Edit 폭주 후 일괄 검증 (lock 파일 기반) |

---

## 2. 자율 실행 (launchd) — ⛔ **영구 비활성** (2026-04-26 #9 사용자 결정)

> **2026-04-26 사용자 결정**: launchd 자율 실행은 **무기한 보류** (영구 비활성).
> 사유: on-demand 호출(Task tool)로 충분히 운영 가능 + 매일 토큰 비용 + cost-accountant 마진 검증 미연동.
> 모든 에이전트는 **on-demand 영구 정착** — 사용자 또는 메인 Claude의 Task tool 호출로만 작동.
> 본 §2의 스케줄·plist 관리·실행 인프라 항목은 **참조용 보존** (재고 시 사용 가능, 재고 자체는 무기한 미정).

### 본래 의도된 스케줄 (참조용 — 영구 비활성)

```
18:04  researcher          → reports/SWEEP_REPORT.md + reports/AI_COST_MONITOR.md
19:08  cost-accountant     → reports/COST_AUDIT_REPORT.md
20:11  planner             → reports/PLANNER_REPORT.md
21:14  visual-canon-keeper → reports/VISUAL_CANON_REPORT.md
22:17  server + web (병렬) → reports/DEV_REPORT.md
23:21  qa                  → reports/QA_REPORT.md → 배포 게이트 판정
```

※ Zenith 06~11, RoadRage 12~17과 시간대 안 겹침.

### 의존성 그래프

```
researcher (독립)
  ↓
cost-accountant (AI_COST_MONITOR 소비)
  ↓
planner (SWEEP_REPORT + COST_AUDIT 소비)
  ↓
visual-canon-keeper (독립 감사)
  ↓
server + web (PLANNER_REPORT 소비, 병렬)
  ↓
qa (DEV_REPORT + COST_AUDIT + VISUAL_CANON 소비)
```

### 실행 인프라 (참조용 — 영구 비활성)

| 구성요소 | 위치 |
|---------|------|
| plist 파일 | `~/Library/LaunchAgents/com.grimoire.{에이전트}.plist` (현재 미설치) |
| 래퍼 스크립트 | `.claude/scripts/run-agent.sh` (네트워크 체크 + 3회 재시도) |
| 프롬프트 파일 | `.claude/prompts/{에이전트}.txt` (server.txt / web.txt 분리됨, 위 §1.1 참조) |
| 로그 | `.launchd-logs/{에이전트}.log` / `.launchd-logs/{에이전트}.err` |

### plist 관리 (참조용 — 영구 비활성)

```bash
# 전체 재로드 (server + web 분리 후)
for agent in researcher cost-accountant planner visual-canon-keeper server web qa; do
  launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.grimoire.$agent.plist 2>/dev/null || true
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.grimoire.$agent.plist
done

# 상태 확인
launchctl list | grep grimoire
```

---

## 3. 센서 시스템 (12개 — 2026-04-26 기준)

> "AI가 '다 했습니다'라고 말하는 것은 증거가 아니다. 센서 스크립트의 stdout만이 증거다."

| 스크립트 | 검증 대상 | 단계 / 핵심 |
|---------|----------|------|
| `.claude/scripts/sensor-server.sh` | grimoire-server | tsc + Jest + build + prisma validate |
| `.claude/scripts/sensor-web.sh` | grimoire-web | tsc + Vitest + build |
| `.claude/scripts/sensor-docs-sync.sh` | server↔web docs | 9개 공유 문서 diff |
| `.claude/scripts/sensor-security-gate.sh` | 보안 8항목 | 가드/admin/쿠키/localStorage/BFF/401/헤더/XSS |
| `.claude/scripts/sensor-secret-leak.sh` (2026-04-25 #5) | 시크릿 평문 | API 키·DB 비밀번호·JWT secret 하드코딩 |
| `.claude/scripts/sensor-log.sh` (2026-04-25 #5) | sensor 결과 적재 | sensor-hits.jsonl 누적 (silent sensor 식별 입력) |
| `.claude/scripts/sensor-hit-rate-report.sh` (2026-04-25 #5) | silent sensor 진단 | 30일간 fire 0회 sensor 식별 |
| `.claude/scripts/sensor-orchestration-ratio.sh` (2026-04-26 P2) | 패턴 1 KPI | jsonl 파싱 → main edits vs subagent task 비율 |
| `.claude/scripts/sensor-credit-atomicity.sh` (2026-04-25 #8) | 결제·환불 원자성 | $transaction Hexagonal 정합 + CreditLog audit + 환불 분기 + Polar webhook secret env 강제 |
| `.claude/scripts/sensor-feedback-promotion.sh` (2026-04-26 #9 X-L) | memory/feedback 영향력 | 28 feedback × 154 검사 위치. PROMOTE/OBSERVE/KEEP 분류 + 신규 90일 면제 |
| `.claude/scripts/sensor-deploy-drift.sh` (2026-04-26 #9 B) | server/web 배포 동기화 | develop ↔ origin ↔ main 정합 + dev/prod health curl. 운영 image SHA 비교는 권한 차단으로 안내만 |
| `.claude/scripts/sensor-cost-margin.sh` (2026-04-26 #9 C) | §0 원가 안전배수 | ai-cost-table.md 12 항목 안전배수 ≥3.0× 자동 검증 + 갱신일 stale + cost-accountant 호출 권장 |

### 에이전트 규칙

- **server / web**: 코드 변경 후 해당 레포 센서 실행, raw stdout을 reports/DEV_REPORT.md에 **요약 없이 전체 첨부**
- **qa**: reports/DEV_REPORT.md 읽은 후 동일 센서 **독립 재실행** → 대조 검증
  - dev PASS + qa PASS → ✅ QA PASS
  - dev PASS + qa FAIL → 🚨 CRITICAL (환경 차이 또는 dev 날조)
- 1개라도 FAIL이면 커밋/배포 금지

### 센서 자체 검증 메타루프

- `sensor-hit-rate-report.sh` 가 silent sensor (오랫동안 fire 0회) 식별 → 검사 항목 정밀화 또는 gc-sweep 후보 등록
- `instructions-drift-check.sh` (Hook InstructionsLoaded) 가 §14 인벤토리 vs 실측 자동 비교 → 문서 drift 즉시 silent 확인

---

## 4. 보고서 파일

| 보고서 | 생산자 | 소비자 | 비고 |
|--------|--------|--------|------|
| `reports/SWEEP_REPORT.md` | researcher | planner | Daily Discovery + Freshness Sweep |
| `reports/AI_COST_MONITOR.md` | researcher | cost-accountant | AI 제공자 가격 캐시 |
| `reports/COST_ALERT.md` | researcher | cost-accountant | 가격 변동 5% 초과 시에만 동적 생성 |
| `reports/COST_AUDIT_REPORT.md` | cost-accountant | planner, qa | 마진 검증 결과 |
| `reports/PLANNER_REPORT.md` | planner | server, web | 작업 지시 (server/web 섹션 분리) |
| `reports/VISUAL_CANON_REPORT.md` | visual-canon-keeper | qa, web | 시각 정본 감사 결과 |
| `reports/DEV_REPORT.md` | server, web | qa | 구현 결과 + 센서 stdout (server/web 섹션 분리) |
| `reports/QA_REPORT.md` | qa | 사용자 | 배포 게이트 판정 |
| `reports/INCIDENT_*.md` | 시스템/qa | server, web | 장애 발생 시 동적 생성 |

모든 보고서는 워크스페이스 루트 하위 `reports/` 디렉토리에 위치. git 추적하지 않음.

---

## 5. knowledge 디렉토리 (4개 — 2026-04-26 기준)

`.claude/knowledge/` — Progressive Disclosure 지식 베이스. 에이전트가 필요 시 Read로 명시 호출.

| 파일 | 용도 |
|------|------|
| `README.md` | 디렉토리 설명 + 사용 규칙 |
| `agent-system.md` | 에이전트 인벤토리 + 오케스트레이션 상세 (역할 개요) |
| **`agent-interaction-matrix.md` (2026-04-26 신설)** | **7×7 핸드오프 매트릭스 + 산출물 정합 + 트리거 규칙 + 금지 조합** |
| `sensors.md` | 센서 스크립트 사용법 + 결과 해석 |

---

## 6. Grimoire 고유 제약

### PLANNING §0 원가 철칙

1. researcher가 매일 Claude/OpenAI/Gemini 가격 확인 → reports/AI_COST_MONITOR.md 갱신
2. 가격 변동 감지 시 reports/COST_ALERT.md 생성
3. cost-accountant가 전체 마진 재계산 → reports/COST_AUDIT_REPORT.md
4. 마진 <3배 기능 검출 시 사용자 에스컬레이션
5. qa가 배포 전 CRITICAL 체크 → FAIL 시 배포 차단

### 사슴악마 시각 정본

1. visual-canon-keeper가 매일 `[author]` 동적 라우트 + 테마 시스템 순회
2. 정본 대조 (구조/타이포/색상/애니메이션/레이아웃)
3. BUG 발견 시 reports/VISUAL_CANON_REPORT.md CRITICAL 항목
4. qa가 배포 전 BUG 체크 → FAIL 시 배포 차단

---

## 7. Zenith 대비 차이 (2026-04-26 갱신)

| 항목 | Zenith | Grimoire |
|------|--------|----------|
| 에이전트 수 | 8 (copywriter, designer 별도) | 7 (VCK가 designer 겸직) |
| 시간대 (자율 실행) | 06~11 KST (활성) | 18~23 KST (**현재 비활성**) |
| Skills | 미도입 | 10개 |
| Sensors | 5개 (server/web/ios/docs/forbidden) | 9개 (server/web/docs/security/secret-leak/log/hit-rate/orchestration/credit) |
| Hooks | 미도입 | 8 이벤트 / 11 스크립트 |
| knowledge | 10개 파일 | 4개 파일 |
| TASK_QUEUE | 있음 (JSON append-only) | 미도입 |
| CLAUDE.md 라인 수 | 543→130 (슬림화) | 458 (패턴 3 진행 중, 본래 517→458) |
| cost-accountant | 없음 | 있음 (Grimoire 고유) |
| visual-canon-keeper | 없음 | 있음 (Grimoire 고유) |
| 핸드오프 매트릭스 | 미명시 | agent-interaction-matrix.md 명시 |

---

## 7.5. Phase 매핑 (vibe-coding 가이드 기반)

Grimoire 에이전트 체인을 vibe-coding Phase 모델로 매핑:

| Phase | vibe-coding 원본 | Grimoire 매핑 | 에이전트 | 산출물 |
|---|---|---|---|---|
| Phase 0 | 맥락 복원 | Live 캐시 + 전날 보고서 Read | researcher | SWEEP_REPORT, AI_COST_MONITOR |
| Phase 1 | PRD/SPEC 작성 | §0 원가 마진 판정 | cost-accountant | COST_AUDIT_REPORT |
| Phase 2 | 아키텍처 설계 | 기획 Draft + 우선순위 | planner | PLANNER_REPORT |
| Phase 3 | 구현 전 검수 | 시각 정본 감사 | visual-canon-keeper | VISUAL_CANON_REPORT |
| Phase 4 | 구현 + 센서 | 코드 수정 + 센서 PASS | server, web (분리) | DEV_REPORT + 센서 stdout |
| Phase 5 | 검증 + 배포 게이트 | 센서 독립 재실행 + §11 전수검사 | qa | QA_REPORT |

### 게이트 체크 — Phase 전환 조건

각 Phase는 다음 게이트를 통과해야 다음 Phase 진행 가능:

- **Phase 0 → 1**: SWEEP_REPORT 생성 + AI_COST_MONITOR 오늘 조사일 갱신
- **Phase 1 → 2**: COST_AUDIT_REPORT CRITICAL 0건 (마진 <3배 기능 없음)
- **Phase 2 → 3**: PLANNER_REPORT 생성 + P0 항목(COST_AUDIT/VISUAL_CANON CRITICAL 반영) 포함
- **Phase 3 → 4**: VISUAL_CANON_REPORT CRITICAL 0건 또는 server/web가 수정 계획 수립
- **Phase 4 → 5**: DEV_REPORT에 센서 raw stdout (server: sensor-server + docs-sync, web: sensor-web + docs-sync) 전부 PASS 첨부 + git 커밋 증거
- **Phase 5 → 배포**: QA_REPORT에 "배포 게이트 PASS" 명시 (dev/qa 센서 대조 통과)

게이트 FAIL 시: 다음 Phase 에이전트는 CRITICAL 해소를 최우선 작업으로 편입 (P0).

### HANDOFF 프로토콜 (에이전트 간 정보 전달)

각 에이전트는 자기 보고서에 다음 필수 포함:

1. **이어받은 정보**: 이전 Phase 보고서의 핵심 요약 (1-3줄)
2. **이번 Phase 결과**: 이번 에이전트가 한 일 + 판정
3. **HANDOFF to 다음 에이전트**: 다음 Phase가 처리할 구체적 항목 (체크리스트 형식)
4. **미해결 CRITICAL**: 있으면 사용자 에스컬레이션 배너

> 상세 7×7 매트릭스: `.claude/knowledge/agent-interaction-matrix.md` 참조.

### CoV (Chain-of-Verification) 공통 패턴

모든 에이전트의 SELF_VERIFICATION 섹션에서 공통으로 자문:

- 모든 주장이 실제 파일/커밋/출력에 근거하는가? (§0 상태 추정 금지)
- [MUST] 항목 중 누락된 게 있는가?
- 이전 Phase 보고서의 CRITICAL을 전부 처리했는가?
- 작가 본문을 인용/로깅하지 않았는가?

---

## 8. 트러블슈팅

### ENOTFOUND 에러 (자율 실행 참조용 — 영구 비활성)
Mac 절전/Wi-Fi 끊김 시 발생. 래퍼 스크립트(`run-agent.sh`)가 30초 간격 3회 재시도.
지속 시 `launchctl list | grep grimoire`로 exit code 확인.

### 로그 미생성 (자율 실행 참조용 — 영구 비활성)
plist 로드 시점이 해당 에이전트 실행 시각 이후면 다음 날 첫 실행까지 로그 없음. 정상.

### plist 수정 후 반영 안 됨 (자율 실행 참조용 — 영구 비활성)
`launchctl bootout` → `launchctl bootstrap` 순서로 재로드 필수.

### Skill 자동 발동 안 됨
Skill의 `triggers` 키워드가 사용자 메시지에 포함되어야 발동. UserPromptSubmit hook의 `skill-injector.sh`가 매칭. `disable-model-invocation: true`인 skill (handover-refresh, gc-sweep)은 사용자 명시 호출(`/skill-name`)만 작동.

### Hook 미작동
`.claude/settings.json` 의 hooks 필드 등록 + 스크립트 실행 권한(`chmod +x`) + JSON 유효성 확인. `instructions-drift-check.sh` 가 silent면 정상.

---

## 변경 이력

| 일자 | 변경 |
|---|---|
| 2026-04-15 | 최초 도입 (Zenith 패턴 차용, 7 에이전트 + 4 센서 + 3 보고서) |
| 2026-04-25 #1 | Phase 1 P0 (Skills 3종 + PostToolUse hook) |
| 2026-04-25 #2 | Phase 1 P1 (UserPromptSubmit + PreToolUse hook + Skill triggers + Agent ouroboros 참조) |
| 2026-04-25 #5 | sensor-secret-leak / sensor-log / sensor-hit-rate-report 신설 |
| 2026-04-25 #6 | 패턴 1+3 (orchestration 분리 + CLAUDE.md slim) 채택 |
| 2026-04-25 #7 | commands→skills 마이그레이션 / PostToolBatch hook / InstructionsLoaded hook / sensor-orchestration-ratio P1 placeholder |
| 2026-04-25 #8 | writing-plans / handover-refresh skill / sensor-credit-atomicity 신설 |
| 2026-04-26 #9 1차+2차 | server/web prompt 분리 / agent-interaction-matrix.md 신설 / gc-sweep skill / sensor-orchestration-ratio P2 (jsonl 파싱) / 본 문서 현행화 (Skills 10 / Sensors 9 / Hooks 8 이벤트 11 스크립트 / launchd 비활성 사실 박제) |
| 2026-04-26 #9 N + Z + X + Y | N: Anthropic SDK signal 완전 전파 (HARNESS §10 Phase 4) — server/web develop push. Z: claude-docs develop 분기 도입 + CLAUDE.md §8 갱신. X-L: sensor-feedback-promotion + feedback-to-skill skill (Memory v2). X-P: generate-skill-graph.sh + research/SKILL_GRAPH.md (Skills 11 / Edges 12 / 트리거 미정의 0). Y: research §15.7 위임 가치 가이드라인 박제 (본 세션 5/6 합치 83%). 본 문서 갱신 (Skills 11 / Sensors 10). |
| 2026-04-26 #9 1차 묶음 (A+D+E+H) | A: launchd 영구 보류 박제 (4 문서). D: post-edit hooks → sensor-log 통합. E: gc-sweep 첫 dry-run (청소 후보 0건). H: orchestration sensor §15.7 합치 분석 추가 (server/web 47.3% + ratio 0.0 → WARN 자동 판정). |
| 2026-04-26 #9 2차 묶음 (B+C) | B: sensor-deploy-drift — develop ↔ main ↔ health 정합 (첫 실측: server develop ahead main 8건 검출). C: sensor-cost-margin — ai-cost-table 안전배수 ≥3.0× 자동 검증 (12 항목 / FAIL 0 / WARN 5 / 평균 3.73×). 본 문서 갱신 (Sensors 10 → 12). |
| 2026-04-27 #9 prod 배포 + Chrome 검증 | 3 레포 develop → main 머지 + push (server `f5d6b1e` / web `4c6216b` / claude-docs `16a7f7a`). server/web prod 배포 (image `prod-f5d6b1e6cc...` / `prod-4c6216b18f...`). Chrome MCP prod 시각 정본 검증 (사슴악마 작가공간 모든 요소 정합). |
| 2026-04-27 #9 H'+I'+F 묶음 | H': sensor-deploy-drift health 임계값 조정 (max-time 10s→60s, cold start 의심 분류 추가). I': cost-accountant agent 위임 (패턴 1 KPI 첫 위임 사례) — WARN 5건 정밀 분석, 분석/베스트가 모든 시뮬의 FAIL 약점 식별, planner 핸드오프 박제. F: worktree-isolation skill 신설 (HARNESS §8.10 안전망, obra/superpowers MIT). Skills 11→12, .gitignore에 .worktrees/ 추가. |
| 2026-04-27 #9 분석 4 크레딧 인상 + W 배포 | cost-accountant agent 위임 (패턴 1 2번째) → ai-cost-table.md §3-2 4 크레딧 재계산 + 시뮬 (베스트 2.79→3.35× FAIL 약점 해소). server `domain/model/config.ts` ANALYSIS_CREDIT_COST 3→4 + spec 30/30 PASS + ai-analysis-spec 갱신. server `e8e34ab` + web `bab239b` 3 레포 develop→main + prod 배포 (image `prod-e8e34ab062f4...` / `prod-bab239b08667...`). claude-docs `9a4f04a` main 머지. |
| **2026-04-27 #9 X 묶음 (AAA+BBB+EEE)** | **AAA: sensor-cost-margin 메시지 강화 (조기 경보 + planner 시점 권장 명시). BBB: researcher agent 위임 (패턴 1 3번째) — AI 가격 변동 0% / 환율 +0.16% / COST_ALERT 미생성 / Claude Opus 4.7 신규 박제. EEE: deploy-image-verify skill 신설 (Container App image SHA vs git main HEAD 정합 검증, 사용자 az 명령 안내). Skills 12→13.** |
