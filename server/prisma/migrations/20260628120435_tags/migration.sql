-- CreateTable
CREATE TABLE "tag" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "client_uuid" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "color" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "tag_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "collection_item_tag" (
    "collection_item_id" TEXT NOT NULL,
    "tag_id" TEXT NOT NULL,

    CONSTRAINT "collection_item_tag_pkey" PRIMARY KEY ("collection_item_id","tag_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "tag_client_uuid_key" ON "tag"("client_uuid");

-- CreateIndex
CREATE INDEX "tag_user_id_idx" ON "tag"("user_id");

-- CreateIndex
CREATE INDEX "collection_item_tag_tag_id_idx" ON "collection_item_tag"("tag_id");

-- AddForeignKey
ALTER TABLE "tag" ADD CONSTRAINT "tag_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collection_item_tag" ADD CONSTRAINT "collection_item_tag_collection_item_id_fkey" FOREIGN KEY ("collection_item_id") REFERENCES "collection_item"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collection_item_tag" ADD CONSTRAINT "collection_item_tag_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "tag"("id") ON DELETE CASCADE ON UPDATE CASCADE;

