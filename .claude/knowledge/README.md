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
| `agent-system.md` | CLAUDE.md §14 상세 | 에이전트 7개 인벤토리 + 오케스트레이션 + 정본 매핑 (역할 개요) | planner, qa |
| `agent-interaction-matrix.md` (2026-04-26 신설) | research §8.8 명시 TODO | 7×7 핸드오프 매트릭스 + 산출물 정합 + 트리거 규칙 + 금지 조합 | 전 에이전트 (특히 planner/qa) |
| `sensors.md` | 신규 | 센서 스크립트 사용법 + dev/qa 대조 규칙 | server, web, qa |
| `book-harness-engineering-completion.md` (2026-04-30 #10 D1 신설) | 책 「하네스 엔지니어링 완전 정복」 Ch 08+15+16 학습 박제 | 분할 정본 + EDD + shared-contracts 적용 패턴 정본 + 운영 데이터 누적 (L2) | 전 에이전트 (자가 검증 시) |
| `visual-canon-inventory.md` (2026-04-30 Phase B 분할) | grimoire-visual-canon-keeper.md §2~§3 분리 | 사슴악마 정본 4 영역 인벤토리 + 6 카테고리 불일치 (Critical/High/Medium/Low) | visual-canon-keeper, web |
| `researcher-scope.md` (2026-04-30 Phase B 분할) | grimoire-researcher.md 일부 분리 | researcher 자료 계층 (Canonical / Live / Ephemeral) + 매일 sweep 대상 | researcher |
| `red-team-constitution.md` (2026-05-02 #10_6 묶음 W 신설) | Anthropic Constitutional AI 16 principles + ProjectGrimoire 도메인 + OWASP LLM Top 10 (P17/P18/P19) | 매 commit 직전 sensor-adversarial-pre-commit 자동 검증용 정본 | 전 에이전트 (특히 server) |
| `build-to-delete-policy.md` (2026-05-03 #10_6 묶음 II 신설) | 책 부록 B 신개념 + Mitchell Ghostty 패턴. Skills/Sensors/Hooks를 영구(A) / 진화(B) / 폐기 후보(C) 3 카테고리로 분류 | 분기별 Build-to-Delete 리뷰 시 (사용자 승인 게이트 + 회귀 검증) | 전 에이전트 (특히 책임자 사용자) |

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
