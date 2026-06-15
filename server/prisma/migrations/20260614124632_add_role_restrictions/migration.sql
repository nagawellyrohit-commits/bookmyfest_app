-- AlterTable
ALTER TABLE "events" ADD COLUMN     "branch" TEXT NOT NULL DEFAULT 'Open',
ADD COLUMN     "brochure_pages" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "brochure_url" TEXT,
ADD COLUMN     "event_type" TEXT NOT NULL DEFAULT 'individual',
ADD COLUMN     "is_approved" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "is_pending_deletion" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "max_members" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "min_members" INTEGER NOT NULL DEFAULT 1,
ADD COLUMN     "pending_updates" JSONB,
ADD COLUMN     "poster_url_1" TEXT,
ADD COLUMN     "poster_url_2" TEXT,
ADD COLUMN     "poster_url_3" TEXT,
ADD COLUMN     "poster_url_4" TEXT,
ADD COLUMN     "whatsapp_group_link" TEXT;

-- AlterTable
ALTER TABLE "job_profiles" ADD COLUMN     "branch" TEXT,
ADD COLUMN     "business_name" TEXT,
ADD COLUMN     "contact_phone" TEXT,
ADD COLUMN     "description" TEXT,
ADD COLUMN     "instagram_url" TEXT,
ADD COLUMN     "linkedin_url" TEXT,
ADD COLUMN     "passing_year" INTEGER,
ADD COLUMN     "website_url" TEXT;

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "student_id" TEXT;
