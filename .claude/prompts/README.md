# `.claude/prompts/` — 자율 실행용 작업 프롬프트

> launchd 또는 외부 호출자(`run-agent.sh`)가 Claude CLI에 그대로 전달하는 프롬프트 모음.
> agents/*.md는 Task tool spawn 시점의 정의 (page level)이고, prompts/*.txt는 단일 작업 단위 instruction (job level).

## 1:1 매핑 (2026-04-26 기준 — server/web 분리 완료)

| 에이전트 (`.claude/agents/`) | 프롬프트 (`.claude/prompts/`) | 비고 |
|---|---|---|
| grimoire-planner.md | planner.txt | 기획 Draft + 원가 게이트 |
| grimoire-researcher.md | researcher.txt | 경쟁사 + AI 가격 모니터링 |
| grimoire-cost-accountant.md | cost-accountant.txt | §0 원가 마진 검증 |
| grimoire-visual-canon-keeper.md | visual-canon-keeper.txt | 사슴악마 정본 + 디자이너 |
| **grimoire-server.md** | **server.txt** ← 신설 (2026-04-26) | NestJS 백엔드 단독 |
| **grimoire-web.md** | **web.txt** ← 신설 (2026-04-26) | Next.js 프론트엔드 단독 |
| grimoire-qa.md | qa.txt | server + web 통합 검증 (qa는 양쪽 통합 책임이라 분리 안 함) |

## 호출 예시

```bash
# server 자율 실행
.claude/scripts/run-agent.sh \
  grimoire-server \
  .claude/prompts/server.txt \
  "Read,Write,Edit,Bash,Glob,Grep"

# web 자율 실행
.claude/scripts/run-agent.sh \
  grimoire-web \
  .claude/prompts/web.txt \
  "Read,Write,Edit,Bash,Glob,Grep"
```

## 변경 이력

| 일자 | 변경 | 사유 |
|---|---|---|
| 2026-04-26 | developers.txt → server.txt + web.txt 분리 | research/HARNESS_ENGINEERING.md §9.4 P0 (prompts 6 vs agents 7 drift 해소). server/web 도메인 단독 책임 명시 |

## 관련 정본
- `research/HARNESS_ENGINEERING.md` §9.4 — Agent 개선 로드맵
- `.claude/knowledge/agent-interaction-matrix.md` — 7 에이전트 핸드오프 규칙 (§8.8)
- `AUTOMATION.md` §1 — 에이전트 인벤토리
