---
name: dev-migration-apply
description: dev DB schema apply 영역 — firewall + secret + prisma migrate deploy + 사후 검증 + 정리 일괄. PAY-P3-E §7-1 단계 6-3 (5/10 본 세션 §B 통과 매커니즘 정합) 영역 박제.
allowed-tools: Bash
disable-model-invocation: true
trigger-mode: manual
effort: medium
owner-agent: grimoire-infrastructure
owner-skill: ""
responsibility-note: "dev 환경 DB schema apply 표준 절차 박제 — Sprint별 메인 영역 명령 묶음 영역 영역 영역 X (skill 영역 영역 박제)"
---

# Dev Migration Apply — DB schema apply 표준 영역

## 책임 영역 (2026-05-10 Phase 2 박제)

- **owner**: grimoire-infrastructure (Azure / firewall / DB cred / Prisma deploy 영역)
- **trigger 패턴**: `disable-model-invocation: true` — 사용자 명시 호출만
- **사용자 명시 키워드**: "dev migration apply 진행" / "dev DB schema 갱신" / "PAY-P3-E §7-1 단계 6-3 진입" 등

> **근거**: 5/10 본 세션 §B (`pay-p3-e-dev-apply-raw.md` line 267~301) 통과 매커니즘 raw 박제 — 9회 차단 후 10번째 시도 통과 정합.

## 언제 발동하는가

다음 상황 1개 이상:

1. Sprint Initializer §7-1 단계 6-3 (Prisma deploy 영역) 진입 시점
2. Schema 변경 영역 dev 환경 영역 검증 진입 시점
3. 사용자 명시 "dev migration apply 진행"

## 사용자 직접 영역 (Stage 2 사용자 영역 강제)

본 skill은 메인 Claude 영역 자동 호출 영역 X. 사용자 명시 키워드 후 grimoire-infrastructure agent 영역 위임 영역 영역 진입.

## 표준 명령 묶음 (5 단계)

### 단계 1 — firewall + 자격증명 영역 진입

```bash
TS=$(date +%s)
IP=$(curl -s ifconfig.me)
echo "TS=$TS IP=$IP"

# firewall rule 생성 (timestamp suffix 영역 충돌 회피)
az postgres flexible-server firewall-rule create \
  -g zenith-rg -n grimoire-db-dev \
  --rule-name "migration-apply-$TS" \
  --start-ip-address $IP --end-ip-address $IP
```

### 단계 2 — DATABASE_URL 영역 secret show 영역

```bash
# secret show 영역 단독 명령 (compound command 영역 sandbox 차단 영역 회피)
DATABASE_URL=$(az containerapp secret show \
  -n grimoire-server-dev -g zenith-rg \
  --secret-name database-url --query value -o tsv)

# 자격증명 영역 mask 강제 (raw 박제 영역 0건)
echo "DATABASE_URL len=$(echo -n "$DATABASE_URL" | wc -c)"
```

### 단계 3 — Prisma migrate deploy 영역

```bash
cd /Users/sokol/Git/ProjectGrimoire/grimoire-server
DATABASE_URL="$DATABASE_URL" npx prisma migrate deploy
```

**예상 출력 영역**:
```
N migrations found
Applying migration <timestamp>_<name>
All migrations have been successfully applied.
```

### 단계 4 — 사후 검증 영역 (3 가지)

```bash
# 4-1. status 검증 ("Database schema is up to date!")
DATABASE_URL="$DATABASE_URL" npx prisma migrate status

# 4-2. dev curl 영역 (HTTP 200 + cold start 영역 박제)
curl -sS -w "%{http_code} %{time_total}s\n" https://dev-api.grimoire-book.com/api/payments/products

# 4-3. sensor-deploy-health 영역 (5/5 PASS 영역)
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/sensor-deploy-health.sh
```

### 단계 5 — 정리 영역

```bash
# firewall rule 삭제 (잔존 0건 박제 영역)
az postgres flexible-server firewall-rule delete \
  -g zenith-rg -n grimoire-db-dev \
  --rule-name "migration-apply-$TS" --yes

# 잔존 영역 검증
az postgres flexible-server firewall-rule list \
  -g zenith-rg --name grimoire-db-dev \
  --query "[?contains(name, 'migration-apply')].name" -o tsv

# DATABASE_URL 영역 unset 강제
unset DATABASE_URL
```

## 사용자 결정 영역 (5/9 박제)

- DB 비밀번호 회전 (5/9 자격증명 영역 부분 노출 사고 영역 회복 정합) — 진행 영역 별도 사용자 명시
- prod 환경 영역 진입 = dev 24h 안정성 박제 후 사용자 명시

## sandbox allow 영역 정합 (8/11)

- `Bash(az postgres flexible-server firewall-rule create:*)`
- `Bash(az postgres flexible-server firewall-rule delete:*)`
- `Bash(az postgres flexible-server firewall-rule list:*)`
- `Bash(az containerapp secret show:*)` (secret list 영역 X — show 영역 단독)
- `Bash(az containerapp revision list:*)`
- `Bash(npx prisma migrate deploy:*)`
- `Bash(npx prisma migrate status:*)`
- `Bash(bash .claude/scripts/sensor-deploy-health.sh:*)`

## 박제 의무 (Mitchell Ghostty 정합)

명령 묶음 영역 진행 중 발견하는 결함 / 우회 / 거짓 보고 영역 즉시 박제:

```bash
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/incident-log.sh \
  dev_migration_apply {severity} {source} "{description}"
```

## 관련 정본
- `.claude/state/pay-p3-e-dev-apply-raw.md` §B — 5/10 본 세션 통과 매커니즘 raw 박제
- `.claude/scripts/sensor-deploy-health.sh` — 사후 검증 sensor
- `.claude/scripts/sensor-fk-cascade-policy.sh` — schema 영역 정합 sensor
- `grimoire-server/prisma/migrations/` — 마이그레이션 정본
- `.claude/agents/grimoire-infrastructure.md` — 책임 agent 자기 정의

## 변경 이력
- 2026-05-10 #10_8 Phase 2: 신설 — 사용자 명시 (5/10) "다 진행해" + Phase 2 8건 skill 영역 1번째. PAY-P3-E §7-1 단계 6-3 영역 raw 박제 정합. 메인 영역 매번 명령 영역 영역 X = skill 영역 박제 영역 영역.
