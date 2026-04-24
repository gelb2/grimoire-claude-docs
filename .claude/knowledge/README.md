# .claude/knowledge/ — Progressive Disclosure 지식 베이스

> 에이전트가 필요할 때 Read 도구로 명시 호출해야만 컨텍스트에 들어온다.
> 자동 로드되지 않는다. CLAUDE.md는 "핵심 지도"로 기능하고, 세부 규칙은 여기에.

## 계층 구조 (vibe-coding 원칙)

- **CLAUDE.md (root)** — 핵심 지도. 모든 에이전트/세션이 반드시 읽는 최소 규칙
- **prompt-engineering/** — 프롬프트 설계 정본 (GMP v2.2 + PRD + vibe-coding)
- **.claude/knowledge/** — 확장 참조. 필요 시에만 Read
- **memory/** — 세션 간 맥락 (사용자 로컬)

## 파일 목록

| 파일 | 원 위치 | 용도 | 독자 |
|------|---------|------|------|
| `README.md` | 신규 | 이 디렉토리 설명 + 계층 원칙 | 전 에이전트 |
| `agent-system.md` | CLAUDE.md §14 상세 | 에이전트 7개 인벤토리 + 오케스트레이션 + 정본 매핑 | planner, qa |
| `sensors.md` | 신규 | 센서 스크립트 사용법 + dev/qa 대조 규칙 | server, web, qa |

## 사용 규칙

1. **에이전트는 작업 시작 전 자기 역할에 필요한 knowledge 파일을 Read**
   - 자동 로드 안 됨 — 반드시 `Read /path/to/knowledge/file.md` 도구 호출
2. **CLAUDE.md에서 "상세: knowledge/X.md 참조"처럼 링크** — 본문에 복사 붙여넣기 금지
3. **새 knowledge 추가 시** 이 README 파일 목록 + CLAUDE.md 참조 맵(§4/§14 등)에 반영
4. **knowledge는 프로젝트 내부 레퍼런스** — prompt-engineering(설계 정본)과 역할 분리

## vibe-coding 가이드 인용

vibe-coding-unified-guide.md에 따르면:
- **CLAUDE.md는 간결하게** 유지 (핵심 지도)
- **세부 사항은 분산 파일** (progressive disclosure)
- **에이전트는 필요한 최소 맥락만 Read** (Fresh Eyes 원칙)

이 원칙을 Grimoire에서는 prompt-engineering/ + .claude/knowledge/ 분리로 구현.
