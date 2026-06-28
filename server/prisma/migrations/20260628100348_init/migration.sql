-- CreateEnum
CREATE TYPE "CardType" AS ENUM ('LEADER', 'CHARACTER', 'EVENT', 'STAGE', 'DON');

-- CreateEnum
CREATE TYPE "CardCondition" AS ENUM ('NM', 'LP', 'MP', 'HP', 'DMG');

-- CreateTable
CREATE TABLE "set" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "release_date" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "set_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card" (
    "id" TEXT NOT NULL,
    "card_code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "colors" TEXT[],
    "type" "CardType" NOT NULL,
    "cost" INTEGER,
    "power" INTEGER,
    "counter" INTEGER,
    "attribute" TEXT,
    "family" TEXT,
    "ability_text" TEXT,
    "trigger_text" TEXT,
    "set_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "card_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "card_variant" (
    "variant_id" TEXT NOT NULL,
    "card_id" TEXT NOT NULL,
    "rarity" TEXT,
    "is_alt_art" BOOLEAN NOT NULL DEFAULT false,
    "variant_label" TEXT,
    "image_thumb_url" TEXT,
    "image_full_url" TEXT,
    "phash" TEXT,
    "phash_variants" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "card_variant_pkey" PRIMARY KEY ("variant_id")
);

-- CreateTable
CREATE TABLE "price" (
    "id" TEXT NOT NULL,
    "variant_id" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "currency" TEXT NOT NULL,
    "market_price" DECIMAL(12,2),
    "low_price" DECIMAL(12,2),
    "captured_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "price_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "password_hash" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "collection_item" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "variant_id" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,
    "condition" "CardCondition" NOT NULL DEFAULT 'NM',
    "is_foil" BOOLEAN NOT NULL DEFAULT false,
    "notes" TEXT,
    "client_uuid" TEXT NOT NULL,
    "added_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,
    "deleted_at" TIMESTAMP(3),

    CONSTRAINT "collection_item_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refresh_token" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "revoked_at" TIMESTAMP(3),
    "replaced_by" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "refresh_token_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "set_code_key" ON "set"("code");

-- CreateIndex
CREATE UNIQUE INDEX "card_card_code_key" ON "card"("card_code");

-- CreateIndex
CREATE INDEX "card_set_id_idx" ON "card"("set_id");

-- CreateIndex
CREATE INDEX "card_type_idx" ON "card"("type");

-- CreateIndex
CREATE INDEX "card_variant_card_id_idx" ON "card_variant"("card_id");

-- CreateIndex
CREATE INDEX "price_variant_id_source_currency_captured_at_idx" ON "price"("variant_id", "source", "currency", "captured_at");

-- CreateIndex
CREATE UNIQUE INDEX "user_email_key" ON "user"("email");

-- CreateIndex
CREATE UNIQUE INDEX "collection_item_client_uuid_key" ON "collection_item"("client_uuid");

-- CreateIndex
CREATE INDEX "collection_item_user_id_idx" ON "collection_item"("user_id");

-- CreateIndex
CREATE INDEX "collection_item_variant_id_idx" ON "collection_item"("variant_id");

-- CreateIndex
CREATE INDEX "collection_item_user_id_updated_at_idx" ON "collection_item"("user_id", "updated_at");

-- CreateIndex
CREATE UNIQUE INDEX "refresh_token_token_hash_key" ON "refresh_token"("token_hash");

-- CreateIndex
CREATE INDEX "refresh_token_user_id_idx" ON "refresh_token"("user_id");

-- AddForeignKey
ALTER TABLE "card" ADD CONSTRAINT "card_set_id_fkey" FOREIGN KEY ("set_id") REFERENCES "set"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "card_variant" ADD CONSTRAINT "card_variant_card_id_fkey" FOREIGN KEY ("card_id") REFERENCES "card"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "price" ADD CONSTRAINT "price_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "card_variant"("variant_id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collection_item" ADD CONSTRAINT "collection_item_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "collection_item" ADD CONSTRAINT "collection_item_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "card_variant"("variant_id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refresh_token" ADD CONSTRAINT "refresh_token_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE;
