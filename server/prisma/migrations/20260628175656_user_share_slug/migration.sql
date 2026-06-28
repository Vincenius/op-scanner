-- AlterTable
ALTER TABLE "user" ADD COLUMN     "share_slug" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "user_share_slug_key" ON "user"("share_slug");

