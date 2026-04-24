-- AlterTable: 가입 보너스 이중 적용 수정 (기본값 3 → 0, grant(3)으로만 적립)
ALTER TABLE "authors" ALTER COLUMN "credits" SET DEFAULT 0;
