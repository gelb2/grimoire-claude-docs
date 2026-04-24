<!-- ────────────────────────────────────────────────────────────
  ProjectGrimoire Harness Engineering — Phase 1 P0 구현 프롬프트
  대상 환경: Claude Code (Sonnet 이상 권장)
  생성 기반: prompt-engineering/GMP-v2.2.md
  상위 계획: grimoire-server/research/HARNESS_ENGINEERING.md §10 Phase 1
───────────────────────────────────────────────────────────── -->

<CRITICAL_CONSTRAINTS>
[MUST] `/Users/sokol/Desktop/Git/ProjectGrimoire/CLAUDE.md` §0 ZERO-TOLERANCE 절대 수칙을 준수하라. 상태 추정 금지 — DB/API/브랜치 상태는 실측(ls/git/curl/psql)으로만 확인하라.
[MUST] `CLAUDE.md` §8 브랜치 전략을 지켜라 — develop에서 bugfix/{name} 또는 feature/{name} 브랜치 생성 → 작업 → develop 머지. main 직접 커밋·푸시 금지.
[MUST] 코드·설정 변경 후 해당 레포의 `npm test` 및 `npx tsc --noEmit`가 통과할 때만 커밋하라.
[MUST] 2레포(grimoire-server, grimoire-web)와 루트 workspace의 `.claude/` 설정 변경은 각각 독립 커밋으로 관리하라. 루트는 현재 git 아니므로 server 레포에 대표 이동본을 두고 루트에는 링크 또는 복사본을 유지하라.
[MUST] 작업 완료 시 `HANDOVER.md` 최신 상태 + `memory/project_session_YYYYMMDD.md` 신규 파일을 반드시 작성하라.
[MUST] 모든 신규 shell 스크립트는 `chmod +x`로 실행 권한을 부여하라.
[MUST] Skill frontmatter에 `name`, `description`은 반드시 포함하라. description은 Claude가 "언제 이 skill을 발동할지" 판단할 수 있도록 증상·상황·트리거어를 구체적으로 서술하라.
[MUST] PostToolUse hook은 Edit/Write 툴 호출 후에만 발동하도록 matcher를 지정하라. 다른 도구에는 영향을 주지 않아야 한다.
[MUST] 기존 `.claude/settings.json`의 SessionStart/Stop/UserPromptSubmit/PreCompact 4개 hook을 **보존**하라. 기존 설정을 덮어쓰지 않는다.
[MUST] grimoire-web `pre-push` 스크립트는 기존 grimoire-server `.githooks/pre-push`와 동일한 4단계(tsc + test + build + docs 동기화) 구조를 따라라. 테스트 커맨드는 web용으로 `vitest run` 및 Playwright 제외 버전으로 조정하라.
</CRITICAL_CONSTRAINTS>

<ROLE>
당신은 ProjectGrimoire의 Claude Code harness 엔지니어다. Martin Fowler의 Harness Engineering 프레임(Guides/Sensors × Computational/Inferential)을 구현 수준으로 내려놓는 단계에 있다. 2026-04-19 세션의 실측 실수 4건(TCC 헛소리, fetch aborted 추측, 환불 UI 거짓, Chrome 조기 포기)을 시스템적으로 차단하는 skills·hooks·git hooks를 이번 작업으로 배치한다.
</ROLE>

<CONTEXT>
### 프로젝트 구조
- 루트: `/Users/sokol/Desktop/Git/ProjectGrimoire/` (git 아님, workspace)
- 서브 레포: `grimoire-server/` (NestJS), `grimoire-web/` (Next.js)
- 양쪽 현재 브랜치는 `develop`. origin은 `gelb2/grimoire-server`, `gelb2/grimoire-web` (둘 다 PRIVATE)

### 현재 harness 상태 (2026-04-25 실측)
- ✅ Sub-agents 7개 (`.claude/agents/*.md`), Sensors 4개 (`.claude/scripts/sensor-*.sh`), Memory hooks 4종 (`.claude/settings.json`), server pre-push
- ❌ Skills 디렉토리 없음, PostToolUse/PreToolUse hook 없음, grimoire-web pre-push 없음

### 필수 참조 문서 (읽는 순서)
1. `/Users/sokol/Desktop/Git/ProjectGrimoire/CLAUDE.md` §0, §8, §12
2. `grimoire-server/research/HARNESS_ENGINEERING.md` §6 (Skills 개념), §9 (Agent 전수검사), §10 (Dev 로드맵 Phase 1)
3. `grimoire-server/HANDOVER.md` (이전 세션 상태)
4. `grimoire-server/TODO.md` "Claude Code harness 강화" 섹션
5. `memory/feedback_docker_credstore.md` (macos-tcc-handling skill 승격 원본)
6. `memory/project_session_20260419_3.md`, `project_session_20260419_4.md` (세션 맥락)

### 도메인 불변식
- 작가 콘텐츠는 절대 수정하지 않는다
- Azure 리소스그룹은 `zenith-rg` 1개만 사용한다
- 2레포 docs/ 동기화 규칙을 지킨다 (server ↔ web)
</CONTEXT>

<AGENT_ARCHITECTURE>
  <ORCHESTRATOR>
  이 세션의 메인 Claude가 오케스트레이터를 맡는다. Phase 0(실측) → Phase 1(설계) → Phase 2(구현) → Phase 3(검증) → Phase 4(핸드오프) 순서를 주도한다. 각 Phase 완료 시 `PROGRESS_HARNESS_P0.md`에 체크 상태를 기록한다.
  </ORCHESTRATOR>

  <SUB_AGENT name="Explore" scope="기존 memory/feedback_*.md 및 .claude/scripts/ 파일 패턴 탐색">
  입력: "TCC / bug-triage / chrome-recovery 주제의 기존 메모리·문서 수집"
  출력: 각 skill 작성에 참조할 파일 경로 + 핵심 원칙 요약 (400자 이내)
  완료 기준: 3개 skill 주제별로 근거 파일 최소 1개 이상 식별
  </SUB_AGENT>

  <SUB_AGENT name="grimoire-qa" scope="Phase 3 검증 게이트">
  입력: "Phase 2 구현 완료된 `.claude/skills/` 3종 + `.claude/settings.json` PostToolUse hook + `grimoire-web/.githooks/pre-push`를 독립 검증하라"
  출력: PASS/FAIL 표 + 각 실패 항목의 재현 증거 (로그/명령 출력)
  완료 기준: 모든 항목 PASS 또는 각 실패 원인 명시. 오케스트레이터가 FAIL 수정 후 재검증 요청
  </SUB_AGENT>

  <HANDOFF_PROTOCOL>
  - 오케스트레이터는 Phase 0 시작 시 `PROGRESS_HARNESS_P0.md`를 루트 workspace에 생성한다
  - 각 Phase 완료 시 해당 Phase 섹션에 `- [x]` 체크 + 산출물 경로 + 실측 명령 출력 요약을 기록한다
  - Explore와 grimoire-qa 서브에이전트는 Task 도구로 독립 호출하며, 반환된 리포트를 PROGRESS에 인용한다
  - Phase 4 완료 시 `PROGRESS_HARNESS_P0.md`를 `grimoire-server/` 밑으로 이동하여 커밋한다
  </HANDOFF_PROTOCOL>
</AGENT_ARCHITECTURE>

<INSTRUCTIONS priority_system="[MUST] 필수 / [SHOULD] 권장 / [NICE] 선택">

  <STEP n="0" title="Phase 0 — 현황 실측">
  [MUST] 다음 명령을 실행하여 실측 결과를 `PROGRESS_HARNESS_P0.md`에 기록하라:
  - `cd /Users/sokol/Desktop/Git/ProjectGrimoire && ls -la .claude/`
  - `ls .claude/agents/ .claude/prompts/ .claude/scripts/ .claude/knowledge/`
  - `cat .claude/settings.json`
  - `ls -la grimoire-server/.githooks/ grimoire-web/.githooks/ 2>&1`
  - `(cd grimoire-server && git status -s && git branch --show-current) && (cd grimoire-web && git status -s && git branch --show-current)`
  [MUST] 현재 develop이 origin과 동기화된 상태인지 확인하라. 동기화되지 않았으면 `git pull origin develop`으로 맞춘다.
  [SHOULD] Explore 서브에이전트에 `feedback_docker_credstore.md`, `feedback_fullcheck_method.md`, Chrome extension 관련 과거 메모리를 탐색하도록 위임하라.
  </STEP>

  <STEP n="1" title="Phase 1 — Skills 3종 설계">
  [MUST] 다음 3개 skill을 설계하라. 각 skill은 `.claude/skills/<name>/SKILL.md` 위치에 생성한다:

  1. **`macos-tcc-handling`**
     - description: "macOS에서 `python3.13` 또는 유사 프로세스가 '다른 앱의 데이터에 접근하려고 합니다' 다이얼로그를 띄울 때, 또는 `az acr login` 중 TCC 권한 요청이 반복될 때 발동"
     - 본문: 증상 → 원인(Docker credsStore=desktop) → 해결(~/.docker/config.json credsStore를 osxkeychain으로 변경 + az acr login 재실행) → 금지사항("매번 허용" 답변 금지, credsStore 삭제 금지)
     - 참조: `memory/feedback_docker_credstore.md`, `grimoire-server/docs/DEPLOY.md §3.1`

  2. **`production-bug-triage`**
     - description: "운영 환경에서 'fetch aborted', '작품을 불러올 수 없습니다', 타임아웃 증상이 보고되었을 때 원인을 진단하는 절차. 추측 답변 방지용"
     - 본문: curl 실측 → 브라우저 네트워크 로그 → 코드 경로 추적 → 수치(타임아웃, cold start 등) 근거 확보 → 추정 금지. Chain-of-Verification 체크리스트 3항 포함
     - 참조: `memory/feedback_fullcheck_method.md`, `project_session_20260419_3.md`, `20260419_4.md`

  3. **`claude-in-chrome-recovery`**
     - description: "Claude-in-Chrome MCP 도구 `tabs_context_mcp`가 'not connected'를 반환하거나 navigate가 지연되어 URL이 반영되지 않을 때 발동"
     - 본문: 최소 3회 재시도 규정 + navigate 직후 반드시 `javascript_tool`로 `location.href` 확인 + 지연 발생 시 `tabs_create_mcp`로 새 탭 생성 경로. 조기 포기 금지
     - 참조: `memory/project_session_20260419_4.md` (Chrome extension 이슈 섹션)

  [MUST] 각 skill은 YAML frontmatter + Markdown 본문 구조를 따른다. `allowed-tools` 필드는 skill이 직접 호출할 도구만 나열하라.
  [SHOULD] 각 skill 본문 마지막에 "마지막 업데이트: YYYY-MM-DD"와 "승격 원본: memory/feedback_*.md" 메타데이터를 포함하라.
  </STEP>

  <STEP n="2" title="Phase 2 — PostToolUse hook + post-edit-tsc.sh 구현">
  [MUST] `/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/post-edit-tsc.sh`를 신설하라. 요구사항:
  - 입력: 첫 번째 인자로 편집된 파일 절대 경로
  - 동작: 파일이 `grimoire-server/` 하위면 `cd grimoire-server && npx tsc --noEmit`, `grimoire-web/` 하위면 `cd grimoire-web && npx tsc --noEmit`, 그 외면 조용히 종료 (exit 0)
  - `.ts`, `.tsx`, `.cts`, `.mts` 확장자만 대상. 다른 확장자면 조용히 종료
  - 실행 시간 제한을 고려해 tsc 출력은 stderr로 보내고 마지막 20줄만 표시
  - 반환 코드 0 유지 (실패해도 Claude 흐름 차단하지 않음, 경고만)

  [MUST] `chmod +x .claude/scripts/post-edit-tsc.sh`로 실행 권한을 부여하라.

  [MUST] `/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/settings.json`의 `hooks` 객체에 `PostToolUse` 키를 추가하라. 기존 4개 hook은 보존. 스펙:
  ```json
  "PostToolUse": [{
    "matcher": "Edit|Write",
    "hooks": [{
      "type": "command",
      "command": "bash /Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/post-edit-tsc.sh \"$CLAUDE_TOOL_INPUT_file_path\"",
      "timeout": 60
    }]
  }]
  ```
  [SHOULD] 환경변수명은 Claude Code 공식 문서에서 재확인하라. 실패 시 `$CLAUDE_FILE_PATH` 등 대안 변수명을 시도하고 실측 결과를 기록한다.
  </STEP>

  <STEP n="3" title="Phase 2 — grimoire-web pre-push 이식">
  [MUST] `grimoire-server/.githooks/pre-push`를 읽고 구조를 확인하라.
  [MUST] `grimoire-web/.githooks/pre-push`를 신설하라. 실행 단계:
  1. `npx tsc --noEmit`
  2. `npm test -- --run` (vitest)
  3. `npm run build`
  4. 루트 `docs/` 동기화 검증 (server/web `docs/*.md` 파일이 동일 해시인지 확인하는 기존 스크립트가 있으면 재활용)
  [MUST] `chmod +x grimoire-web/.githooks/pre-push`.
  [MUST] `(cd grimoire-web && git config core.hooksPath .githooks)`로 hook path 설정. 이미 설정되어 있으면 스킵.
  [SHOULD] 각 단계 시작 시 `echo "[n/4] ..."` 배너 출력으로 server 스타일과 통일.
  [NICE] `npm run test:e2e`(Playwright)는 pre-push에서 제외하라 (실행 시간 과다). 배포 전 수동 실행 권장으로 별도 기록.
  </STEP>

  <MID_CHECK>
  여기까지 3개 파일 계열(skills/, post-edit-tsc.sh + settings.json, grimoire-web/.githooks/pre-push)을 작성했다.
  CRITICAL_CONSTRAINTS 재확인:
  - [MUST] main 직접 커밋 금지 — 모든 변경은 develop에서 작업 중인가?
  - [MUST] 기존 settings.json 4개 hook이 그대로 보존되었는가?
  - [MUST] 모든 shell 스크립트에 chmod +x 적용했는가?
  - [MUST] Skill frontmatter의 description이 Claude가 trigger 판단 가능할 만큼 구체적인가?
  문제가 있으면 Phase 3로 넘어가기 전에 수정하라.
  </MID_CHECK>

  <STEP n="4" title="Phase 3 — 독립 검증 (grimoire-qa 서브에이전트)">
  [MUST] grimoire-qa 서브에이전트를 Task 도구로 호출하라. 프롬프트:
  ```
  Phase 1 P0 harness 구현을 독립 검증해 주세요. 항목:
  1. .claude/skills/{macos-tcc-handling,production-bug-triage,claude-in-chrome-recovery}/SKILL.md 존재 + frontmatter(name/description) 유효성
  2. .claude/scripts/post-edit-tsc.sh 실행 권한 + 더미 파일 경로 2개(.ts/.md)로 수동 호출 시 동작
  3. .claude/settings.json의 PostToolUse 섹션 추가 여부 + 기존 4개 hook 보존 여부
  4. grimoire-web/.githooks/pre-push 존재 + 실행 권한 + core.hooksPath 설정 여부
  5. grimoire-web에서 `git push --dry-run` 시도 시 pre-push가 호출되어 tsc+test+build를 돌리는지 (실제 push는 안 함)
  각 항목 PASS/FAIL + 실측 증거(명령 + 출력)를 표로 반환. 코드 직접 수정은 하지 말 것.
  ```
  [MUST] 서브에이전트 리포트를 `PROGRESS_HARNESS_P0.md` Phase 3 섹션에 첨부하라.
  [MUST] FAIL 항목이 있으면 오케스트레이터가 직접 수정 후 재검증하라.
  </STEP>

  <STEP n="5" title="Phase 4 — 커밋·핸드오프·배포 여부 결정">
  [MUST] develop 브랜치에서 두 종류 커밋을 분리한다:
  - `grimoire-server` 커밋: (해당 없음 — 루트 .claude/ 변경은 server 레포 아님. 대신 `grimoire-server/research/HARNESS_ENGINEERING.md` Phase 1 완료 표시 업데이트 + HANDOVER 갱신 + TODO 체크)
  - `grimoire-web` 커밋: `.githooks/pre-push` 추가
  [MUST] 루트 `.claude/` 변경(skills/scripts/settings.json)은 현재 버전관리 되지 않는다. 변경 사항을 `memory/project_session_YYYYMMDD.md`에 경로·내용을 인용하여 박제하라.
  [MUST] 각 레포 develop에 `--no-ff`로 머지되지 않는 범위라면, 단일 develop 직접 커밋으로 진행. pre-push가 통과하는지 실측.
  [MUST] `HANDOVER.md`를 최신화 — 이번 세션 완료 항목, 변경 파일 경로, 다음 세션이 이어서 할 Phase 2(P1) 작업 명시.
  [MUST] `memory/project_session_YYYYMMDD.md`를 신규 작성하고 `memory/MEMORY.md` 인덱스에 추가한다 (CLAUDE.md §12).
  [SHOULD] grimoire-web develop push 후 `gh run list -R gelb2/grimoire-web --limit 3`로 Actions 상태 확인.
  [NICE] Phase 1 P0 완료 보고를 사용자 메시지로 3줄 이내 요약: 완료 파일, 검증 결과, 다음 Phase 예고.

  배포 여부: **이번 작업은 런타임 코드 변경이 아니므로 prod 배포 불필요**. harness 설정만 develop/로컬에 반영.
  </STEP>

</INSTRUCTIONS>

<OUTPUT_SPEC>
### 최종 산출물 체크리스트
- [ ] `/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/skills/macos-tcc-handling/SKILL.md`
- [ ] `/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/skills/production-bug-triage/SKILL.md`
- [ ] `/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/skills/claude-in-chrome-recovery/SKILL.md`
- [ ] `/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/scripts/post-edit-tsc.sh` (실행 권한 포함)
- [ ] `/Users/sokol/Desktop/Git/ProjectGrimoire/.claude/settings.json` (PostToolUse 추가, 기존 4개 hook 보존)
- [ ] `grimoire-web/.githooks/pre-push` (실행 권한 포함)
- [ ] `grimoire-web` develop 커밋 1건 + push + Actions 확인
- [ ] `grimoire-server/HANDOVER.md` 갱신 커밋 + push
- [ ] `grimoire-server/TODO.md` P0 항목 체크 + 커밋 + push
- [ ] `grimoire-server/research/HARNESS_ENGINEERING.md` Phase 1 완료 주석 업데이트 (선택)
- [ ] `memory/project_session_YYYYMMDD.md` 신규 + `MEMORY.md` 인덱스 갱신
- [ ] `PROGRESS_HARNESS_P0.md` 모든 Phase 체크 완료

### 보고 형식 (사용자에게 최종 메시지)
- 완료한 P0 항목 표 (O/X)
- grimoire-qa 검증 리포트 PASS/FAIL 요약
- 다음 Phase 1 P1(Slash commands + db-sync 예외) 착수 여부 제안
</OUTPUT_SPEC>

<QUALITY_CRITERIA>
  <GOOD_EXAMPLE>
  - Skill의 description이 "macOS에서 python3.13 또는 유사 프로세스가 '다른 앱의 데이터에 접근'으로 TCC 다이얼로그를 띄울 때 발동"처럼 증상어·트리거어를 포함
  - post-edit-tsc.sh가 `.md` 파일 편집 시 조용히 exit 0 (불필요한 tsc 실행 방지)
  - grimoire-web pre-push가 server와 동일한 `[n/4]` 배너 형식
  - PROGRESS_HARNESS_P0.md 각 Phase 섹션에 실측 명령 + 실제 출력 인용
  - 커밋 메시지: `feat(harness): macos-tcc-handling skill 추가` 같은 명확한 scope
  </GOOD_EXAMPLE>
  <BAD_EXAMPLE>
  - Skill description이 "TCC 관련 문제 해결"처럼 모호 → Claude가 trigger 판단 불가. 구체 증상어 포함한 긍정형 서술로 교체
  - post-edit-tsc.sh가 모든 확장자에서 tsc 실행 → 성능 낭비. .ts/.tsx/.cts/.mts 화이트리스트로 제한
  - `.claude/settings.json`에 PostToolUse만 쓰고 기존 4개 hook 삭제 → 메모리 보호 무너짐. 기존 객체 보존하며 키 추가
  - grimoire-web pre-push에 Playwright 포함 → 5분 이상 소요. 유닛만 실행하고 E2E는 배포 전 수동 스크립트로 분리
  - 커밋 메시지: "chore: 업데이트" 같은 무의미 요약 → 명확한 scope와 why 포함
  </BAD_EXAMPLE>
</QUALITY_CRITERIA>

<SELF_VERIFICATION>
최종 출력 전에 다음 4단계를 수행하라:

### 1. 핵심 주장 3개 선정 및 독립 검증
선정 주장:
- (A) "PostToolUse hook이 실제로 .ts 파일 편집 시 tsc 자동 실행된다"
- (B) "3개 skill이 Claude Code 규약(frontmatter)을 따라 로드 가능하다"
- (C) "grimoire-web pre-push가 push를 실제로 차단한다 (tsc 실패 케이스)"

독립 검증 방법:
- (A) 더미 `.ts` 파일을 임시 생성·편집 → post-edit-tsc.sh 직접 호출 + hook 경로로 수동 호출 → stderr에 tsc 출력 확인
- (B) `.claude/skills/*/SKILL.md` 3개 파일의 frontmatter를 `awk '/^---$/{i++}i==1'`로 추출 → name·description 필드 존재 확인
- (C) grimoire-web에서 의도적으로 타입 에러를 만든 커밋 생성 → `git push --dry-run` → pre-push가 실패로 push 차단하는지 확인 → 에러 롤백

### 2. CRITICAL_CONSTRAINTS 항목별 자기 체크
- [ ] CLAUDE.md §0 준수 (추정 없이 실측 기반 보고)
- [ ] 브랜치 전략 준수 (main 직접 커밋 없음)
- [ ] 테스트 통과 확인
- [ ] 2레포 + 루트 workspace 변경 독립 관리
- [ ] HANDOVER.md + 세션 메모리 파일 작성
- [ ] shell 스크립트 실행 권한 부여
- [ ] Skill frontmatter 완전성
- [ ] PostToolUse matcher가 Edit|Write만
- [ ] 기존 4개 hook 보존
- [ ] web pre-push 4단계 구조

### 3. 검증 결과와 초안이 불일치하면 초안 수정
FAIL 있으면 Phase 2 또는 Phase 3으로 돌아가 수정 후 재검증.

### 4. grimoire-qa 서브에이전트 리포트의 모든 FAIL 해소 확인
</SELF_VERIFICATION>

<FINAL_REMINDER>
### 절대 규칙 재진술
[MUST] CLAUDE.md §0 ZERO-TOLERANCE — 추정 금지, 실측만.
[MUST] main 직접 커밋 금지, develop 경유.
[MUST] `.claude/settings.json`의 기존 4개 hook을 보존하며 PostToolUse를 **추가**한다.
[MUST] 모든 shell 스크립트에 `chmod +x`.
[MUST] Skill frontmatter에 name + description을 반드시 포함하고 description은 trigger 판단 가능하게 구체적으로 서술한다.
[MUST] 작업 완료 시 `HANDOVER.md` 갱신 + `memory/project_session_YYYYMMDD.md` 신규 작성.

### 최종 출력물
- 3개 skill(`.claude/skills/*/SKILL.md`) + PostToolUse hook + post-edit-tsc.sh + grimoire-web pre-push
- `PROGRESS_HARNESS_P0.md` 전 Phase 체크 완료본
- grimoire-qa 서브에이전트의 PASS 리포트
- grimoire-web develop 커밋 + push 완료
- grimoire-server HANDOVER/TODO 갱신 커밋 + push 완료
- 사용자 메시지 3줄 이내 최종 보고

### 품질 기준 재확인
- Skill이 Claude에 의해 자동 발동되는 description 구체성
- PostToolUse가 관련 없는 도구(Bash, Read 등)에는 발동하지 않음
- grimoire-web pre-push가 server와 동일 형식으로 통일
- 모든 변경이 실측으로 검증됨
</FINAL_REMINDER>
