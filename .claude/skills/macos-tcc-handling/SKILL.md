---
name: macos-tcc-handling
description: macOS에서 `az acr login`, `docker login`, `make deploy-*` 실행 중 "`python3.13`이 다른 앱(Docker Desktop 등)의 데이터에 접근하려고 합니다" 또는 유사 TCC 권한 다이얼로그가 반복 노출될 때 발동. "매번 허용 누르세요" 같은 면피성 답변 금지. Docker credsStore=desktop 설정이 원인이며 osxkeychain으로 전환이 유일한 정답.
allowed-tools: Read, Bash, Edit
triggers:
  - "python3.13"
  - "TCC"
  - "tcc"
  - "다이얼로그"
  - "매번 허용"
  - "허용 안 함"
  - "docker login"
  - "credsStore"
  - "acr login"
  - "Docker Desktop"
  - "docker-credential-desktop"
effort: low
---

# macOS TCC 다이얼로그 대응 (Docker credsStore)

## 증상 (이 중 1개라도 보이면 이 skill 발동)

- `az acr login --name grimoireacr` 또는 `make deploy-{dev,prod}` 실행 중 시스템 다이얼로그:
  > `python3.13`이(가) 다른 앱의 데이터에 접근하려고 합니다. [허용 안 함] [허용]
- `docker login` 단독 실행 시 동일 다이얼로그
- 다이얼로그가 **매 실행마다** 반복되어 CI/자동화 흐름이 멈춤
- 백엔드 개발자의 정상적인 배포 과정에서 TCC 요청이 반복되는 상황

> 일반 Mac 백엔드 개발자는 이 다이얼로그를 볼 일이 없다. 반복 발생 시 설정 이상이다.

## 근본 원인 (추측 금지, 실측 체인)

1. `az acr login` → 내부적으로 `docker login`을 호출
2. `docker login` → `~/.docker/config.json`의 `credsStore` 설정 확인
3. `credsStore: "desktop"` (Docker Desktop 4.x 기본) → `docker-credential-desktop` 바이너리 실행
4. 이 바이너리가 Docker Desktop 샌드박스 디렉토리(`~/Library/Containers/com.docker.docker/`)에 자격증명 저장 시도
5. macOS Sequoia+ TCC가 "Azure CLI의 python3.13이 다른 앱(Docker Desktop)의 샌드박스 데이터에 접근"으로 감지
6. → 매 실행마다 권한 다이얼로그

## 해결 프로토콜 (순서 엄수)

### 1단계 — 현재 설정 실측

```bash
cat ~/.docker/config.json | python3 -c "import json, sys; c = json.load(sys.stdin); print('credsStore:', c.get('credsStore', '(unset)'))"
```

- 출력이 `credsStore: desktop`이면 → 2단계 진행
- 출력이 `credsStore: osxkeychain`이면 → TCC 원인은 다른 곳, Docker Desktop 버전·macOS 권한 재검토

### 2단계 — osxkeychain으로 전환

```bash
# 백업
cp ~/.docker/config.json ~/.docker/config.json.bak.$(date +%Y%m%d)

# 수정 (Python 사용해 JSON 무결성 보장)
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.docker' / 'config.json'
c = json.loads(p.read_text())
c['credsStore'] = 'osxkeychain'
p.write_text(json.dumps(c, indent=2))
print('credsStore updated to osxkeychain')
"
```

### 3단계 — `docker-credential-osxkeychain` 바이너리 존재 확인

```bash
which docker-credential-osxkeychain
# /usr/local/bin/docker-credential-osxkeychain 예상
# 없으면 Docker Desktop 재설치 필요 (함께 설치됨)
```

### 4단계 — Azure ACR 재로그인으로 Keychain에 저장

```bash
az acr login --name grimoireacr
```

- 첫 실행 시 **Keychain 1회 허용 다이얼로그** 나옴 → "항상 허용"
- 이후 `az acr login`·`docker login`은 TCC 다이얼로그 없이 Keychain 표준 접근

### 5단계 — 배포 스크립트 재실행 (검증)

```bash
cd /Users/sokol/Desktop/Git/ProjectGrimoire/grimoire-server
SKIP_INTERACTIVE=1 make deploy-dev  # 또는 -prod
```

TCC 다이얼로그가 더 이상 안 뜨면 성공.

## 절대 금지 사항

### [MUST NOT] "매번 허용 누르세요" 답변
이는 사용자를 기만하는 일회성 면피다. CLAUDE.md §0 ZERO-TOLERANCE 위반 사례로 2026-04-19에 사용자 격노 유발.

### [MUST NOT] `credsStore` 필드 삭제
`credsStore`를 지우면 Docker가 `auths` 섹션에 **base64 평문**으로 자격증명 저장 — 보안사고 직결. 반드시 `osxkeychain`으로 **교체**, 삭제 금지.

### [MUST NOT] Docker Desktop 강제 종료로 우회
Docker Desktop을 안 띄워도 `docker-credential-desktop` 바이너리가 호출되면 동일 증상. 근본 해결은 credsStore 변경뿐.

## 관련 정본

- `memory/feedback_docker_credstore.md` (이 skill의 승격 원본)
- `grimoire-server/docs/DEPLOY.md §3.1` (로컬 머신 세팅 — credsStore 섹션)
- `grimoire-server/INFRASTRUCTURE.md §12.2` (배포 트러블슈팅)
- `grimoire-web/docs/DEPLOY.md §3.1` (동기화본)

## 검증된 이력

- 2026-04-19 `project_session_20260419_4.md`: 배포 중 TCC 다이얼로그 반복 → credsStore 변경으로 영구 해결 확인

---

승격 원본: `memory/feedback_docker_credstore.md`
마지막 업데이트: 2026-04-25
