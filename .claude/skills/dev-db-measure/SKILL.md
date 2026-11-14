---
name: dev-db-measure
description: dev DB 측정 영역 — firewall + secret + psql SELECT + firewall 정리 일괄. PAY-P3-E §7-1 단계 1 측정 SQL 영역 박제.
allowed-tools: Bash
disable-model-invocation: true
trigger-mode: manual
effort: medium
owner-agent: grimoire-infrastructure
owner-skill: ""
responsibility-note: "dev DB 측정 (psql SELECT) 표준 절차 박제 — PAY-P3-E §7-1 단계 1 영역 33 측정 SQL 영역 정합"
---

# Dev DB Measure — dev DB 영역 측정 표준 영역

## 책임 영역 (2026-05-10 Phase 2 박제)

- **owner**: grimoire-infrastructure (Azure / firewall / DB cred / psql 영역)
- **trigger 패턴**: `disable-model-invocation: true` — 사용자 명시 호출만
- **사용자 명시 키워드**: "dev DB 측정" / "PAY-P3-E §7-1 단계 1 진행" / "SELECT 측정"

> **근거**: 5/9 PAY-P3-E §7-1 단계 1 영역 sandbox 차단 사슬 (3회) 박제 → 5/10 본 세션 §B 통과 매커니즘 정합 영역 통합 박제.

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
  --rule-name "db-measure-$TS" \
  --start-ip-address $IP --end-ip-address $IP
```

### 단계 2 — DATABASE_URL 영역 secret show 영역

```bash
# secret show 영역 단독 명령 (compound command 영역 sandbox 차단 영역 회피)
DATABASE_URL=$(az containerapp secret show \
  -n grimoire-server-dev -g zenith-rg \
  --secret-name database-url --query value -o tsv)

# 자격증명 영역 mask 강제
echo "DATABASE_URL len=$(echo -n "$DATABASE_URL" | wc -c)"
```

### 단계 3 — psql SELECT 측정 영역

```bash
# SELECT 측정 영역 (READ-ONLY 영역 강제 — INSERT/UPDATE/DELETE 영역 절대 금지)
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM users;"
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM works;"
psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM payments;"
# ... 33 측정 SQL 영역 (PAY-P3-E §7-1 단계 1 영역 정본)

# 또는 .sql 영역 파일 영역 batch 영역 실행
psql "$DATABASE_URL" -f /path/to/measure.sql
```

**임계 영역**: SELECT 영역만 강제 — INSERT/UPDATE/DELETE 영역 절대 금지 (sandbox + bash-guard 영역 차단 영역 정합).

### 단계 4 — 결과 영역 박제

```bash
# 측정 영역 결과 영역 박제 (.claude/state/dev-db-measure-{TS}.md 영역 또는 raw 영역)
echo "=== dev DB 측정 영역 결과 ($TS) ==="
echo "users: N"
echo "works: N"
echo "payments: N"
# ...
```

**박제 영역**:
- `.claude/state/dev-db-measure-{TS}.md` — raw 박제 영역
- `.claude/state/pay-p3-e-dev-apply-raw.md` 또는 동등 영역 — Sprint 종속 영역 박제

### 단계 5 — 정리 영역

```bash
# firewall rule 삭제 (잔존 0건 박제 영역)
az postgres flexible-server firewall-rule delete \
  -g zenith-rg -n grimoire-db-dev \
  --rule-name "db-measure-$TS" --yes

# 잔존 영역 검증
az postgres flexible-server firewall-rule list \
  -g zenith-rg --name grimoire-db-dev \
  --query "[?contains(name, 'db-measure')].name" -o tsv

# DATABASE_URL 영역 unset 강제
unset DATABASE_URL
```

## sandbox allow 영역 정합 (4/N)

- `Bash(az postgres flexible-server firewall-rule create:*)`
- `Bash(az postgres flexible-server firewall-rule delete:*)`
- `Bash(az postgres flexible-server firewall-rule list:*)`
- `Bash(az containerapp secret show:*)` (secret list 영역 X — show 영역 단독)
- `Bash(psql:*)` — SELECT 영역 강제 영역 (사용자 직접 영역 sandbox 추가 영역)

## INSERT/UPDATE/DELETE 영역 절대 금지

본 skill은 SELECT 영역만 강제. INSERT/UPDATE/DELETE 영역 = `dev-migration-apply` skill 영역 또는 사용자 직접 영역 진입.

**근거**: 5/9 sandbox 차단 사슬 (3회) 영역 = `prisma migrate deploy` 영역 = ALTER/DROP 영역 차단 정합 영역. SELECT 영역만 안전 영역.

## 박제 의무 (Mitchell Ghostty 정합)

측정 영역 진행 중 발견하는 결함 / 우회 / 거짓 보고 영역 즉시 박제:

```bash
bash /Users/sokol/Git/ProjectGrimoire/.claude/scripts/incident-log.sh \
  dev_db_measure {severity} {source} "{description}"
```

## 관련 정본
- `.claude/state/pay-p3-e-dev-apply-raw.md` — 5/9~10 본 세션 박제 영역
- `.claude/skills/dev-migration-apply/SKILL.md` — schema apply 영역 (INSERT/UPDATE/DELETE 영역)
- `.claude/agents/grimoire-infrastructure.md` — 책임 agent 자기 정의 (DB 측정/SELECT 영역 책임 명시 박제)

## 변경 이력
- 2026-05-10 #10_8 Phase 2: 신설 — 사용자 명시 (5/10) "다 진행해" + Phase 2 8건 skill 영역 7번째. 5/9 PAY-P3-E §7-1 단계 1 영역 sandbox 차단 사슬 (3회) → 5/10 본 세션 §B 통과 매커니즘 정합 영역 통합 박제. SELECT 영역만 강제 + INSERT/UPDATE/DELETE 영역 절대 금지 박제. 메인 영역 매번 명령 영역 영역 X = skill 영역 박제 영역 영역.
