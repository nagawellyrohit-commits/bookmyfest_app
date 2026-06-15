-- AlterTable
ALTER TABLE "users" ADD COLUMN     "is_pending_deletion" BOOLEAN NOT NULL DEFAULT false;
