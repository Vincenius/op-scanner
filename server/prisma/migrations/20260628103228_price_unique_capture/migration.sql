-- CreateIndex
CREATE UNIQUE INDEX "price_variant_id_source_currency_captured_at_key" ON "price"("variant_id", "source", "currency", "captured_at");

