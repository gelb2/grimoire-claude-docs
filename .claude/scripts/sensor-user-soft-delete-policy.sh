#!/bin/bash
# sensor-user-soft-delete-policy.sh — USER-SOFT-DELETE Sprint (2026-05-15) 회귀 차단
#
# 13 검증: schema deletedAt + index + migration + middleware + anonymizer + usecase + cron +
#         AuditLog 4 action + DELETE /me + admin force-delete + admin anonymize (qa #20 보강) +
#         shared-contracts §29 + spec 수
#
# 정본:
# - `.claude/shared-contracts.md §29 UserSoftDeletePolicy`
# - `grimoire-server/ADR.md ADR-011`
# - `.claude/state/sprint-user-soft-delete-draft.md`

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SERVER="${ROOT}/grimoire-server"
fail_count=0

echo "[sensor-user-soft-delete-policy] USER-SOFT-DELETE 회귀 차단 검증 진입"

# 1. Author.deletedAt 컬럼 박제
if ! grep -qE "deletedAt\s+DateTime\?\s+@map\(\"deleted_at\"\)" "${SERVER}/prisma/schema.prisma"; then
  echo "FAIL [1/12]: Author.deletedAt 컬럼 박제 0건 (schema.prisma)"
  fail_count=$((fail_count + 1))
fi

# 2. @@index([deletedAt]) 박제 (cron 영역 정합)
if ! grep -qE "@@index\(\[deletedAt\]\)" "${SERVER}/prisma/schema.prisma"; then
  echo "FAIL [2/12]: @@index([deletedAt]) 박제 0건 (schema.prisma)"
  fail_count=$((fail_count + 1))
fi

# 3. migration SQL 박제
MIGRATION_SQL="${SERVER}/prisma/migrations/20260515_user_soft_delete_policy/migration.sql"
if [ ! -f "${MIGRATION_SQL}" ]; then
  echo "FAIL [3/12]: migration.sql 박제 0건 (${MIGRATION_SQL})"
  fail_count=$((fail_count + 1))
else
  if ! grep -qE "ALTER TABLE \"authors\" ADD COLUMN \"deleted_at\"" "${MIGRATION_SQL}"; then
    echo "FAIL [3/12]: migration.sql ALTER TABLE ADD COLUMN 박제 0건"
    fail_count=$((fail_count + 1))
  fi
fi

# 4. prisma-soft-delete.middleware.ts 박제
MW_FILE="${SERVER}/src/adapter/outbound/persistence/prisma-soft-delete.middleware.ts"
if [ ! -f "${MW_FILE}" ]; then
  echo "FAIL [4/12]: prisma-soft-delete.middleware.ts 박제 0건"
  fail_count=$((fail_count + 1))
else
  # Prisma 6.x $use 제거 → $extends 마이그레이션 (eb5d931): applySoftDeleteExtension 정합
  if ! grep -q "applySoftDeleteExtension" "${MW_FILE}"; then
    echo "FAIL [4/12]: applySoftDeleteExtension 함수 박제 0건"
    fail_count=$((fail_count + 1))
  fi
fi

# 5. default-user-anonymizer.adapter.ts 박제
ANON_FILE="${SERVER}/src/adapter/outbound/persistence/default-user-anonymizer.adapter.ts"
if [ ! -f "${ANON_FILE}" ]; then
  echo "FAIL [5/12]: default-user-anonymizer.adapter.ts 박제 0건"
  fail_count=$((fail_count + 1))
else
  if ! grep -qE "anonymized-.+@deleted\.local" "${ANON_FILE}"; then
    echo "FAIL [5/12]: anonymized-{uuid}@deleted.local 영역 박제 0건"
    fail_count=$((fail_count + 1))
  fi
fi

# 6. user-soft-delete.usecase.ts 박제
USECASE_FILE="${SERVER}/src/application/author/user-soft-delete.usecase.ts"
if [ ! -f "${USECASE_FILE}" ]; then
  echo "FAIL [6/12]: user-soft-delete.usecase.ts 박제 0건"
  fail_count=$((fail_count + 1))
else
  if ! grep -q "class UserSoftDeleteUseCase" "${USECASE_FILE}"; then
    echo "FAIL [6/12]: UserSoftDeleteUseCase 클래스 박제 0건"
    fail_count=$((fail_count + 1))
  fi
fi

# 7. user-hard-delete.job.ts 박제 + @Cron 표현
CRON_FILE="${SERVER}/src/application/author/user-hard-delete.job.ts"
if [ ! -f "${CRON_FILE}" ]; then
  echo "FAIL [7/12]: user-hard-delete.job.ts 박제 0건"
  fail_count=$((fail_count + 1))
else
  if ! grep -qE "@Cron\('0 0 4 \* \* \*'\)" "${CRON_FILE}"; then
    echo "FAIL [7/12]: @Cron('0 0 4 * * *') 매일 새벽 4시 박제 0건 (옵션 A 정합)"
    fail_count=$((fail_count + 1))
  fi
fi

# 8. AdminAuditLog 4 action 박제
for action in self_account_delete admin_force_delete gdpr_anonymize 30d_hard_delete; do
  if ! grep -rq "${action}" "${SERVER}/src/application/" "${SERVER}/src/adapter/"; then
    echo "FAIL [8/12]: AuditLog '${action}' 박제 0건"
    fail_count=$((fail_count + 1))
  fi
done

# 9. DELETE /me 엔드포인트 박제 (JWT 인증)
AUTHOR_CTRL="${SERVER}/src/adapter/inbound/http/controller/author.controller.ts"
if ! grep -qE "@Delete\('me'\)" "${AUTHOR_CTRL}"; then
  echo "FAIL [9/12]: DELETE /me 엔드포인트 박제 0건 (author.controller.ts)"
  fail_count=$((fail_count + 1))
fi

# 10. POST /admin/authors/:id/force-delete 엔드포인트 박제 (AdminGuard)
ADMIN_CTRL="${SERVER}/src/adapter/inbound/http/controller/admin.controller.ts"
if ! grep -qE "force-delete" "${ADMIN_CTRL}"; then
  echo "FAIL [10/13]: POST /admin/authors/:id/force-delete 엔드포인트 박제 0건"
  fail_count=$((fail_count + 1))
fi

# 11. POST /admin/authors/:id/anonymize 엔드포인트 박제 (qa #20 server-web 정합 보강 — 2026-05-15)
# - @Post('authors/:authorId/anonymize') decoration 박제 정합
# - anonymizeOnly UseCase 메서드 박제 정합
# - AdminAuditLog gdpr_anonymize action 박제 (이미 8/13 영역 포함 — 본 검증 영역 endpoint 영역만)
if ! grep -qE "@Post\(['\"]authors/:authorId/anonymize['\"]\)" "${ADMIN_CTRL}"; then
  echo "FAIL [11/13]: POST /admin/authors/:id/anonymize 엔드포인트 박제 0건 (admin.controller.ts)"
  fail_count=$((fail_count + 1))
fi

USECASE_FILE2="${SERVER}/src/application/author/user-soft-delete.usecase.ts"
if ! grep -qE "anonymizeOnly\s*\(" "${USECASE_FILE2}"; then
  echo "FAIL [11/13]: anonymizeOnly 메서드 박제 0건 (user-soft-delete.usecase.ts)"
  fail_count=$((fail_count + 1))
fi

# 12. shared-contracts §29 박제
SHARED="${ROOT}/.claude/shared-contracts.md"
if ! grep -qE "##\s*29\.\s*UserSoftDeletePolicy" "${SHARED}"; then
  echo "FAIL [12/13]: shared-contracts §29 UserSoftDeletePolicy 박제 0건"
  fail_count=$((fail_count + 1))
fi

# 13. spec 박제 (4 spec ≥ 20 it 합 + admin controller spec ≥ 1 it)
SPEC_USECASE="${SERVER}/src/application/author/user-soft-delete.usecase.spec.ts"
SPEC_MW="${SERVER}/src/adapter/outbound/persistence/prisma-soft-delete.middleware.spec.ts"
SPEC_ANON="${SERVER}/src/adapter/outbound/persistence/default-user-anonymizer.adapter.spec.ts"
SPEC_CRON="${SERVER}/src/application/author/user-hard-delete.job.spec.ts"
SPEC_ADMIN_CTRL="${SERVER}/src/adapter/inbound/http/controller/admin.controller.spec.ts"

it_total=0
for f in "${SPEC_USECASE}" "${SPEC_MW}" "${SPEC_ANON}" "${SPEC_CRON}"; do
  if [ ! -f "${f}" ]; then
    echo "FAIL [13/13]: spec 박제 0건 (${f})"
    fail_count=$((fail_count + 1))
  else
    n=$(grep -cE "(^\s*it\(|^\s*it\.each)" "${f}" || true)
    it_total=$((it_total + n))
  fi
done

# admin controller spec (qa #20 보강 — endpoint 영역 영역 spec ≥ 1 it 강제)
if [ ! -f "${SPEC_ADMIN_CTRL}" ]; then
  echo "FAIL [13/13]: admin.controller.spec.ts 박제 0건 (anonymize 엔드포인트 영역 spec 영역)"
  fail_count=$((fail_count + 1))
else
  ctrl_it=$(grep -cE "(^\s*it\(|^\s*it\.each)" "${SPEC_ADMIN_CTRL}" || true)
  if [ "${ctrl_it}" -lt 1 ]; then
    echo "FAIL [13/13]: admin.controller.spec.ts it 수 부족 (${ctrl_it} < 1 — anonymize 영역 검증 영역 영역)"
    fail_count=$((fail_count + 1))
  fi
fi

if [ "${it_total}" -lt 20 ]; then
  echo "FAIL [13/13]: spec it 수 부족 (total=${it_total} < 20)"
  fail_count=$((fail_count + 1))
fi

# 종료
echo ""
echo "=== sensor-user-soft-delete-policy 요약 ==="
echo "spec it 합 (usecase + middleware + anonymizer + cron): ${it_total}"
echo "admin.controller.spec it 합 (anonymize 검증): ${ctrl_it:-0}"
if [ "${fail_count}" -eq 0 ]; then
  echo "PASS: USER-SOFT-DELETE Soft delete 패턴 + GDPR 익명화 + 30일 cron + anonymize 엔드포인트 정합 (13/13)"
  exit 0
else
  echo "FAIL: ${fail_count} 검증 실패"
  exit 1
fi
