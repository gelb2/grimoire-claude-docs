# Sprint Progress — 테마 에디터 preset 변경 시 name 자동 동기 UX

> **Sprint ID**: sprint-theme-editor-name-sync
> **Initializer**: grimoire-planner (세션 #10_6 묶음 II 작업 B)
> **착수일**: 2026-05-03
> **마감**: 본 세션 종료 전 (1~1.5h)
> **PLANNING 근거**: PLANNING_GRIMOIRE.md §10 P2-#10
> **Initializer 패턴**: 책 Ch 16 Anthropic 3-에이전트 (Initializer → Generator → Evaluator)

본 progress.md는 **Generator(grimoire-web)와 Evaluator(grimoire-qa)의 단일 진실(single source of truth)**입니다. 모든 의사결정·범위·검증 게이트는 이 문서를 정본으로 합니다. 모호 시 본 문서를 갱신한 후 진행하십시오.

---

## 0. 한 줄 목표 (Goal)

> 작가가 테마 에디터에서 **테마 이름(themeName)을 직접 수정한 뒤** preset(프리셋)을 변경해도, 사용자가 입력한 name이 preset label로 **덮어써지지 않도록** 보존한다. 사용자가 name을 한 번도 수정하지 않은 상태에서는 기존처럼 preset label을 자동 동기한다.

---

## 1. 배경 (Why)

- 위치: `grimoire-web/src/app/dashboard/theme/page.tsx:80~86` `handlePresetChange`
- 현 동작: `if (label) setThemeName(label)` — preset 변경 시 항상 label로 덮어씀
- 사용자 보고: name을 직접 입력 후 preset을 바꾸면 입력값이 사라짐 (UX 손실)
- PLANNING §10 P2-#10에 박제된 정식 과제

---

## 2. 범위 (Scope)

### IN
1. `grimoire-web/src/app/dashboard/theme/page.tsx`
   - `userEditedName: boolean` state 신설 (`useState(false)`)
   - `handlePresetChange`: `!userEditedName`일 때만 `setThemeName(label)`
   - OptionsPanel에 전달하는 `onNameChange` 콜백 래핑 — 사용자 입력 감지 시 `userEditedName=true` 마크
   - 초기 로드 시(useEffect에서 `setThemeName(themeData.name ?? '')`) `userEditedName`은 `false` 유지 (자동 로드는 사용자 편집이 아님)
2. `grimoire-web/src/app/dashboard/theme/_components/OptionsPanel.tsx`
   - **시그니처 변경 불필요** (기존 `onNameChange?: (name: string) => void` 그대로 사용)
   - 단, page.tsx에서 래핑된 콜백을 받도록 한다
3. 테스트 신설 (위치는 Generator 결정 — 권장: `grimoire-web/src/app/dashboard/theme/__tests__/preset-name-sync.spec.tsx`)
   - Vitest + @testing-library/react
4. Eval regression task 신설: `eval/tasks/regression-50-theme-preset-name-sync.json`
   - category: `convention` 또는 `edge_case` (Generator 판단)
   - eval_criteria: `grep` — page.tsx에 `userEditedName` state 존재 여부 + `!userEditedName` 가드 존재 여부
   - threshold: 1.0 / runs: 1

### OUT (Out of Scope)
- AI 생성 모드(`handleGenerate`)에서의 name 동기화 정책 변경 (별도 과제)
- preset 선택 화면(`PresetSelectScreen`)의 name 입력 UX 변경
- 디자인 토큰/시각 정본 변경 (시각 정본 무관 — VCK는 "변경 없음" 사전 확인만)
- i18n 문구 변경

---

## 3. Acceptance Criteria (AC)

Evaluator(qa)는 아래 5건을 **순차적으로** 검증합니다. 모두 PASS여야 Sprint 종료.

| # | 시나리오 | 기대 결과 |
|---|---------|----------|
| AC-1 | 신규 진입(name 미수정) → preset 드롭다운 변경 | themeName이 preset label로 동기됨 (기존 동작 보존) |
| AC-2 | 사용자가 name input에 직접 타이핑 → preset 변경 | themeName이 사용자 입력값 그대로 보존 (덮어쓰기 금지) |
| AC-3 | 사용자가 name 직접 수정 → 다시 input을 비워 빈 문자열 → preset 변경 | name 보존 (빈 문자열도 "사용자 의도"로 간주, 덮어쓰기 금지) |
| AC-4 | edit 모드 진입(`?id=xxx`) — 서버 로드한 name 표시 → preset 변경 | 서버 로드는 "사용자 편집 아님" → preset label로 동기 |
| AC-5 | AC-2 후 페이지 새로고침 → 다시 preset 변경 | userEditedName 초기화 → preset label로 동기 (state는 메모리 only, 의도된 동작) |

---

## 4. Test Plan

### 4-1. 유닛 테스트 (Vitest)
파일: `grimoire-web/src/app/dashboard/theme/__tests__/preset-name-sync.spec.tsx`

```
describe('테마 에디터 preset name 자동 동기')
  it('AC-1: name 미수정 상태에서 preset 변경 → label로 동기')
  it('AC-2: name 직접 수정 후 preset 변경 → name 보존')
  it('AC-3: name 직접 수정 후 빈 문자열 → preset 변경 → name 보존(빈 문자열)')
  it('AC-4: edit 모드 서버 로드 후 preset 변경 → label로 동기')
```
- AC-5는 새로고침 시뮬 어렵 → Playwright 또는 수동 검증 (qa 판단)
- mock: `api.getTheme`, `api.getAuthorSpace` 등

### 4-2. 회귀 (eval)
- `eval/scripts/eval-runner.sh` 실행 → regression-50 PASS 확인
- 기존 회귀 task 모두 PASS 유지 (drift 0)

### 4-3. 수동 검증 (개발 서버)
- `npm run dev` (port 3001) → /dashboard/theme 진입 → AC-1~AC-4 직접 클릭

---

## 5. 검증 게이트 (Gates)

Generator(web)는 커밋 직전 아래 모두 PASS여야 합니다.

| 게이트 | 명령 | 기대 |
|-------|------|------|
| TypeScript | `cd grimoire-web && npx tsc --noEmit` | 0 errors |
| Lint | `cd grimoire-web && npm run lint` | 0 errors (warn 허용) |
| Unit test | `cd grimoire-web && npm test -- preset-name-sync` | PASS |
| 회귀 task | `bash eval/scripts/eval-runner.sh` | regression-50 포함 전체 PASS |
| sensor-shared-contracts | `bash .claude/scripts/sensor-shared-contracts.sh` | drift 0 (본 작업은 인터페이스 변경 없음 → 자동 PASS 예상) |
| sensor-instruction-degradation | `bash .claude/scripts/sensor-instruction-degradation.sh` | WARN 0 |
| sensor-agent-priority-labels | `bash .claude/scripts/sensor-agent-priority-labels.sh` | PASS |
| sensor-agent-interaction | `bash .claude/scripts/sensor-agent-interaction.sh` | PASS |

### Evaluator(qa) 추가 게이트
- 위 5종 sensor 독립 재실행
- AC-1~AC-5 채점 → QA_REPORT.md `## 3. Eval 결과` 하위에 `### sprint-theme-editor-name-sync 통과율` 박제 (5/5 = 100%)

---

## 6. 산출물 체크리스트 (Generator 갱신 대상)

Generator(web)가 작업 진행 시 본 섹션의 체크박스를 즉시 갱신합니다.

- [x] `grimoire-web/src/app/dashboard/theme/page.tsx` 수정
  - [x] `userEditedName` state 추가 (useThemeName hook 추출)
  - [x] `handlePresetChange` 가드 추가 (`!userEditedName` — hook 내부 syncNameFromPreset)
  - [x] OptionsPanel에 전달하는 `onNameChange` 래핑 (handleNameChange — true 마크)
- [x] `grimoire-web/src/app/dashboard/theme/_hooks/useThemeName.ts` 신설 (테스트 가능성 위해 hook 추출)
- [x] `grimoire-web/src/app/dashboard/theme/_hooks/preset-name-sync.test.tsx` 신설 (AC-1~AC-5 + 가드 1건 = 6 it, vitest config가 `*.test.tsx` include 패턴이라 .spec.tsx 대신 .test.tsx 채택)
- [x] `eval/tasks/regression-50-theme-preset-name-sync.json` 신설 (5 criteria)
- [x] `grimoire-web/CHANGELOG.md` 1줄 박제 (`### Fixed`)
- [ ] `grimoire-web/TECH_STATUS.md` 해당 섹션 갱신 (해당 없음 — 정책 변경 0)
- [x] DEV_REPORT.md `## Web 섹션` 작성 (산출물·게이트·sensor raw stdout 박제)

### Generator 회귀 결과 (2026-05-03)
- tsc --noEmit: PASS (0 errors)
- vitest preset-name-sync: 6/6 PASS
- vitest 전체 (sensor-web): 8 files / 125 tests PASS
- Next.js build: PASS (23 routes)
- eval-runner: 50/50 PASS (regression-50 신규 5/5 포함, drift 0)
- sensor-shared-contracts: PASS (drift 0)
- sensor-instruction-degradation: 11/11 WARN 0
- sensor-agent-priority-labels: 7/7 PASS
- sensor-agent-interaction: PASS
- sensor-web.sh: 3/3 PASS

### Evaluator(qa) 산출물
- [ ] QA_REPORT.md 업데이트 — sprint-progress 통과율 박제 + 배포 게이트 판정

---

## 7. 위험 및 롤백 (Risk & Rollback)

### 위험
1. **R1**: `userEditedName`이 너무 적극적으로 마크되어 AC-1(자동 로드)에서도 true가 됨 → AC-1 FAIL
   - 완화: useEffect의 `setThemeName(themeData.name ?? '')`는 page.tsx 내부에서 직접 호출(OptionsPanel 콜백 미경유)이므로 자연 회피. 단, Generator는 검증 시 명시 확인.
2. **R2**: edit 모드에서 사용자가 name을 살짝 수정한 뒤 preset 변경 → 의도와 다르게 보존될 수 있음
   - 판단: AC-2 정책상 "한 번이라도 사용자가 입력 이벤트를 발생시키면 보존"이 정답 (PLANNING §10 P2-#10 의도)
3. **R3**: 회귀 task 추가로 eval-runner 실행 시간 증가
   - 완화: 단순 grep 1회, 무시 가능

### 롤백
- 단일 커밋(`fix(web): 테마 에디터 preset 변경 시 name 자동 동기 UX 개선`)으로 묶기 → `git revert <sha>` 한 번으로 복구
- Generator는 별도 PR/브랜치 없이 develop 직접 작업 (Sprint 규모 1~1.5h, per-repo main 머지 정책 준수)

---

## 8. HANDOFF Chain

```
planner (현재 — Initializer 완료)
  ↓ 본 progress.md + PLANNER_REPORT.md
visual-canon-keeper (사전 검수)
  ↓ "시각 정본 변경 없음 — PASS" 확인 (예상 5분)
grimoire-web (Generator)
  ↓ §6 체크리스트 모두 ✅ + DEV_REPORT.md 박제
grimoire-qa (Evaluator)
  ↓ §5 게이트 + §3 AC 채점 → QA_REPORT.md 박제
사용자 (배포 게이트 최종 판정)
```

---

## 9. 변경 이력

- 2026-05-03 — planner — Sprint 계약 초안 작성 (Initializer 1회차)
- 2026-05-03 — grimoire-web (Generator) — 구현 완료. useThemeName hook 추출(테스트 가능성), page.tsx 리팩토링, vitest 6/6 PASS, eval 50/50 PASS, sensor 5종 PASS. 영향 파일 4건(page.tsx, useThemeName.ts, preset-name-sync.test.tsx, regression-50-*.json) + CHANGELOG. 커밋은 메인 단계 위임.
