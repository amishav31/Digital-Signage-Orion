-- AlterEnum
ALTER TYPE "AssetType" ADD VALUE 'URL';

-- AlterTable
ALTER TABLE "Asset" ADD COLUMN "url" TEXT;
ALTER TABLE "Asset" ADD COLUMN "defaultDurationSeconds" INTEGER;
ALTER TABLE "Asset" ALTER COLUMN "s3Key" DROP NOT NULL;
