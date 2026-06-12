-- AlterTable
ALTER TABLE "ProofOfPlayLog" ADD COLUMN "deviceId" TEXT;
ALTER TABLE "ProofOfPlayLog" ADD COLUMN "assetName" TEXT NOT NULL DEFAULT '';
ALTER TABLE "ProofOfPlayLog" ADD COLUMN "playlistName" TEXT;
ALTER TABLE "ProofOfPlayLog" ADD COLUMN "campaignName" TEXT;
ALTER TABLE "ProofOfPlayLog" ADD COLUMN "startTime" TIMESTAMP(3);
ALTER TABLE "ProofOfPlayLog" ADD COLUMN "endTime" TIMESTAMP(3);
ALTER TABLE "ProofOfPlayLog" ADD COLUMN "durationSeconds" INTEGER;

-- Backfill from legacy columns
UPDATE "ProofOfPlayLog"
SET
  "assetName" = "content",
  "startTime" = "timestamp"
WHERE "startTime" IS NULL;

ALTER TABLE "ProofOfPlayLog" ALTER COLUMN "startTime" SET NOT NULL;

-- CreateIndex
CREATE INDEX "ProofOfPlayLog_organizationId_startTime_idx" ON "ProofOfPlayLog"("organizationId", "startTime");
CREATE INDEX "ProofOfPlayLog_organizationId_deviceId_startTime_idx" ON "ProofOfPlayLog"("organizationId", "deviceId", "startTime");

-- AddForeignKey
ALTER TABLE "ProofOfPlayLog" ADD CONSTRAINT "ProofOfPlayLog_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE SET NULL ON UPDATE CASCADE;
