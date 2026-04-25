# 참고 프로젝트 — ProjectGrimoire 도메인 외부 사례

> **2026-04-25 세션 #7 신설** — 루트 `CLAUDE.md` §13에서 분리. 패턴 3(SSOT + CLAUDE.md 좁게) 진화 단계 P2 일부.
> CLAUDE.md §13은 이 문서로의 1줄 pointer만 유지.

ProjectGrimoire 개발 시 차용한 외부 프로젝트와 차용 영역.

| 프로젝트 | 참고 대상 |
|---------|----------|
| **DeerDevil** | MD 파서, 블록 시스템, CSS Variables, 타이핑 이펙트, E2E 테스트 |
| **projectZenith** | 폴더 구조, 문서 동기화, Azure 배포, 브랜치 전략, CI/CD, **멀티 에이전트 구조** (7 subagent 패턴 차용 — `research/HARNESS_ENGINEERING.md` §14 참조) |
| **YECHANGPE_urbanProjectAuto** | Claude API 래퍼, 구조화 프롬프트, JSON 파싱 에러 복구, 결과 캐싱 |
| **Tajook** | 크레딧 시스템 (적립/차감/로그), 재가입 방지, RLS, 관리자 크레딧 부여 |

## 차용 시 원칙

1. **선별 차용**: 전체 install 금지 — 도메인 충돌 위험. 필요한 패턴만 ProjectGrimoire 도메인에 맞춰 변형
2. **출처 박제**: 차용 코드·구조에는 주석 또는 `research/`에 출처 명시
3. **회귀 인지**: 원본 프로젝트의 기존 결정·실수도 함께 인지하여 같은 함정 회피

## 관련 정본
- `research/HARNESS_ENGINEERING.md` §7 (커뮤니티 3대 레포: superpowers / oh-my-claudecode / ouroboros)
- `prompt-engineering/` 3종 (GMP v2.2 / PRD 생성 / 바이브코딩) — 외부 프로젝트가 아닌 자체 개발

## 미차용 항목 (보류 결정)
- **superpowers** 167k⭐ — 일괄 install 금지, `verification-before-completion` 등 선별 이식
- **oh-my-claudecode** 31k⭐ — 19 agent 일괄 install 시 ProjectGrimoire 7 agent와 충돌, `OpenClaw gateway` / `Skill learning` 검토만
- **Q00/ouroboros** — Python 스택 분리, 개념(Ambiguity Score)만 차용 검토

상세: `research/HARNESS_ENGINEERING.md` §7
