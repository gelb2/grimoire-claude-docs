# Harness Engineering — 루트 workspace Git 관리 (분리 정본, 2026-05-02 묶음 N NEW-12)

> **분리 사유**: `research/HARNESS_ENGINEERING.md` §11 (루트 workspace Git 관리, 179줄)을 별도 정본으로 분리. § 번호 그대로 유지 (§11). 외부 참조 0건이라 영향 없음.
>
> **참조하는 파일**: 본 §11은 자기완결 가이드라인이라 직접 참조 적음 (claude-docs 운영 시 참고용 단독 정본).
>
> **원본 위치**: `research/HARNESS_ENGINEERING.md` §11 (2026-04-25 v2 신설 → 2026-05-02 본 파일로 분리).

---

## 11. 루트 workspace Git 관리 방법 (v2 신설)

### 11.1 현재 구조 (실측)

```
/Users/sokol/Desktop/Git/ProjectGrimoire/          ← git 아님
├── .DS_Store
├── .claude/                    ← 에이전트·프롬프트·센서·hook 설정
├── .idea/                      ← IntelliJ (로컬)
├── .launchd-logs/              ← 자율 실행 로그
├── .obsidian/                  ← Obsidian (로컬)
├── ACCOUNTS.md
├── AUTOMATION.md
├── CLAUDE.md                   ← 루트 규칙 정본
├── DOC_MAP.html
├── PLANNING_GRIMOIRE.md        ← 최상위 기획 정본
├── SYNC_STATUS.md
├── agents → .claude/agents     ← symlink
├── grimoire-server/            ← 독립 git 레포
├── grimoire-web/               ← 독립 git 레포
├── node_modules/
├── package-lock.json
├── package.json
├── prisma/
├── prompt-engineering/         ← GMP v2.2, 바이브코딩 가이드 등 정본
├── reports/                    ← 자율 에이전트 리포트
├── research/                   ← 이 문서 포함
└── seed-data/
```

**문제**: 루트의 CLAUDE.md·PLANNING_GRIMOIRE.md·prompt-engineering·research·.claude 등 핵심 자산이 **버전 관리 안 됨**. 사용자 수동 백업 의존.

### 11.2 옵션 비교

#### 옵션 A: 루트 git init + 서브 레포 gitignore (**추천**)

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire
git init -b main
cat > .gitignore <<'EOF'
# 서브 레포 (독립 git으로 관리 중)
grimoire-server/
grimoire-web/

# 빌드 산출물
node_modules/
.launchd-logs/

# 로컬 IDE
.idea/
.obsidian/
.DS_Store

# Claude Code 사용자별
.claude/settings.local.json

# 기타
무제.base
EOF

git add .
git commit -m "chore: 루트 workspace 초기 커밋 (CLAUDE.md·PLANNING_GRIMOIRE·.claude·docs·research)"
gh repo create gelb2/grimoire-workspace --private --source=. --remote=origin --push
```

**장점**
- 기존 server/web 독립성 유지
- 루트 자산(약 10~15MB) 별도 PRIVATE repo로 보호
- GitHub Actions로 self-dogfooding 가능 (프로젝트 상태 요약 봇 등)

**단점**
- 3개 레포 관리 부담 (server/web/workspace)
- 3개 레포 간 동기화는 여전히 사람이 책임

**이번 프로젝트에 권장 이유**: `.claude/`의 agent/prompt/sensor 설정이 사용자 머리 밖으로 벗어나면 재구성 불가. 이걸 PRIVATE git에 박제가 안전장치.

#### 옵션 B: Git Submodule

루트에 init 후 `grimoire-server`/`grimoire-web`을 submodule로 pinning.

**장점**: 3개 레포 연결성 명시
**단점**: 
- Submodule 관리 복잡. 매번 commit hash 추적
- 사용자가 `git submodule update --recursive` 잊으면 stale
- Claude Code가 submodule 내부 변경 추적 어려움

**비추천**.

#### 옵션 C: Monorepo 전환 (pnpm workspaces / turborepo / nx)

`package.json` workspace로 grimoire-server + grimoire-web을 monorepo 편입.

**장점**: 최신 스택. 코드 공유 가능
**단점**:
- 기존 CI/CD, 배포 스크립트, Docker build, GitHub Actions 모두 재구성
- 회귀 리스크 큼
- ProjectGrimoire는 이미 상당한 인프라 투자 완료 상태 — ROI 낮음

**장기 검토는 가치 있음. 지금 실행은 비추천**.

#### 옵션 D: 루트 자산을 grimoire-server에 이식

루트의 `CLAUDE.md`·`PLANNING_GRIMOIRE.md`·`.claude/` 등을 `grimoire-server/workspace/`로 이동.

**장점**: 기존 1 git에 편입, 단순
**단점**:
- 루트 기반 launchd plist, 에이전트 bash 스크립트의 절대경로 대거 수정 필요
- "루트 workspace" 개념 상실
- server 레포가 grimoire-web까지 규정하는 형태가 되어 대칭성 깨짐

**비추천**.

#### 옵션 E: Dotfiles-style 별도 레포 (symlink)

사용자 `~/dotfiles-grimoire` 레포에 파일 저장, 루트로 symlink.

**장점**: 기존 구조 불변
**단점**:
- symlink 관리 복잡 (특히 `.claude/agents/` 같은 중첩)
- Windows 환경 이전 시 문제
- 사용자 혼란 증가

**비추천**.

### 11.3 옵션 A 실행 절차 (제안 — 사용자 승인 필요)

```bash
# 1) 루트 진입
cd /Users/sokol/Desktop/Git/ProjectGrimoire

# 2) 기존 서브 repo 건드리지 않는지 확인
ls -la grimoire-server/.git grimoire-web/.git  # 존재 확인

# 3) git init (메인 브랜치 main)
git init -b main

# 4) .gitignore 작성 (위 §11.2 옵션 A 내용)
cat > .gitignore <<'EOF'
grimoire-server/
grimoire-web/
node_modules/
.launchd-logs/
.idea/
.obsidian/
.DS_Store
.claude/settings.local.json
무제.base
memory/          # ~/.claude/ 로 관리되는 메모리는 별도
reports/         # 자율 에이전트 로그는 재생성 가능
EOF

# 5) 최초 커밋
git add .
git status  # 확인 — grimoire-server/, grimoire-web/ 제외됐는지
git commit -m "chore: ProjectGrimoire workspace 초기 커밋"

# 6) GitHub PRIVATE repo 생성 + push
gh repo create gelb2/grimoire-workspace --private --source=. --remote=origin --push

# 7) 브랜치 전략 확정 (단순: main 직접 작업)
#    루트는 빈번한 변경이 아니므로 develop 분리 불필요
```

### 11.4 운영 원칙 (옵션 A 채택 시)

- **커밋 빈도**: CLAUDE.md / PLANNING_GRIMOIRE.md / `.claude/` 변경 시 즉시
- **서브 레포와의 경계**: 루트 workspace는 **규칙·기획·harness**만, 서브는 **코드**만
- **핸드오프**: HANDOVER.md는 `grimoire-server/`에 유지 (현재 구조) — 다음 세션이 server pull만으로 읽을 수 있으므로
- **민감 정보**: 루트에 `ACCOUNTS.md`가 있음 — 내용 확인 후 반드시 `.gitignore`에 추가하거나 마스킹 후 커밋

### 11.5 사전 경고

- `memory/` 디렉토리는 실제로 `~/.claude/projects/.../memory/`에 위치 (루트 아님). 워크스페이스에 편입하려면 symlink 또는 별도 설계
- `.launchd-logs/` 커밋 시 용량 폭주 — `.gitignore` 필수
- `reports/` 자율 에이전트 생성물은 많은 용량 — `.gitignore` 또는 최근 N개만 보존
- `ACCOUNTS.md`에 계정 정보 있으면 PRIVATE여도 커밋 전 내용 검수

---

