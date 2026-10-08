-- Beauty & Cosmetics E-commerce Platform
-- Custom migration: rules Prisma's schema language can't express.
-- Apply right after the initial Prisma migration:
--   pnpm prisma migrate dev --create-only --name constraints_and_security
--   then paste this file into the generated migration.sql.
-- Source: "Database Design" document (D-107, D-110, D-111, D-118, D-119, D-088).

-- ─────────────────────────────────────────────────────────────
-- Order numbers start at 100001 (D-101, ST-16)
-- ─────────────────────────────────────────────────────────────
ALTER SEQUENCE "orders_order_number_seq" START WITH 100001 RESTART WITH 100001;

-- ─────────────────────────────────────────────────────────────
-- Catalog
-- ─────────────────────────────────────────────────────────────
ALTER TABLE "categories"
  ADD CONSTRAINT "categories_not_own_parent_ck" CHECK ("parent_id" IS NULL OR "parent_id" <> "id");

ALTER TABLE "product_options"
  ADD CONSTRAINT "product_options_position_ck" CHECK ("position" BETWEEN 1 AND 3);

ALTER TABLE "option_values"
  ADD CONSTRAINT "option_values_swatch_hex_ck" CHECK ("swatch_hex" IS NULL OR "swatch_hex" ~ '^#[0-9A-Fa-f]{6}$'),
  ADD CONSTRAINT "option_values_position_ck" CHECK ("position" >= 1);

ALTER TABLE "variants"
  ADD CONSTRAINT "variants_price_ck" CHECK ("price" > 0),
  ADD CONSTRAINT "variants_stock_quantity_ck" CHECK ("stock_quantity" >= 0),
  ADD CONSTRAINT "variants_currency_ck" CHECK ("currency" ~ '^[A-Z]{3}$');

ALTER TABLE "product_images"
  ADD CONSTRAINT "product_images_dimensions_ck" CHECK ("width" > 0 AND "height" > 0),
  ADD CONSTRAINT "product_images_position_ck" CHECK ("position" >= 1);

-- ─────────────────────────────────────────────────────────────
-- Store configuration
-- ─────────────────────────────────────────────────────────────
ALTER TABLE "banners"
  ADD CONSTRAINT "banners_dates_ck" CHECK ("starts_at" IS NULL OR "ends_at" IS NULL OR "ends_at" > "starts_at");

ALTER TABLE "governorates"
  ADD CONSTRAINT "governorates_shipping_fee_ck" CHECK ("shipping_fee" >= 0);

ALTER TABLE "store_settings"
  ADD CONSTRAINT "store_settings_single_row_ck" CHECK ("id" = 1),
  ADD CONSTRAINT "store_settings_cod_max_ck" CHECK ("cod_max_order_value" IS NULL OR "cod_max_order_value" > 0),
  ADD CONSTRAINT "store_settings_free_shipping_ck" CHECK ("free_shipping_threshold" IS NULL OR "free_shipping_threshold" > 0),
  ADD CONSTRAINT "store_settings_return_window_ck" CHECK ("return_window_days" BETWEEN 1 AND 365),
  ADD CONSTRAINT "store_settings_low_stock_ck" CHECK ("low_stock_threshold" >= 0);

-- ─────────────────────────────────────────────────────────────
-- Customers, staff and authentication
-- ─────────────────────────────────────────────────────────────
ALTER TABLE "customers"
  ADD CONSTRAINT "customers_active_has_email_ck" CHECK ("status" <> 'ACTIVE' OR "email" IS NOT NULL);

-- One default address per customer (ST-10)
CREATE UNIQUE INDEX "customer_addresses_one_default_idx"
  ON "customer_addresses" ("customer_id") WHERE "is_default";

ALTER TABLE "auth_tokens"
  ADD CONSTRAINT "auth_tokens_one_owner_ck" CHECK (num_nonnulls("customer_id", "staff_id") = 1);

ALTER TABLE "staff_users"
  ADD CONSTRAINT "staff_users_failed_logins_ck" CHECK ("failed_login_count" >= 0);

ALTER TABLE "rate_limit_counters"
  ADD CONSTRAINT "rate_limit_counters_count_ck" CHECK ("count" >= 0);

-- ─────────────────────────────────────────────────────────────
-- Cart
-- ─────────────────────────────────────────────────────────────
ALTER TABLE "cart_items"
  ADD CONSTRAINT "cart_items_quantity_ck" CHECK ("quantity" BETWEEN 1 AND 10);

-- ─────────────────────────────────────────────────────────────
-- Orders, payments and stock
-- ─────────────────────────────────────────────────────────────
ALTER TABLE "orders"
  ADD CONSTRAINT "orders_amounts_ck" CHECK ("subtotal" >= 0 AND "shipping_fee" >= 0),
  ADD CONSTRAINT "orders_total_ck" CHECK ("total" = "subtotal" + "shipping_fee"),
  ADD CONSTRAINT "orders_shipped_has_tracking_ck"
    CHECK ("status" NOT IN ('SHIPPED', 'DELIVERED') OR "tracking_number" IS NOT NULL);

-- Fast lookup of unpaid card orders that may have expired (D-084)
CREATE INDEX "orders_awaiting_payment_expires_idx"
  ON "orders" ("expires_at") WHERE "status" = 'AWAITING_PAYMENT';

ALTER TABLE "order_items"
  ADD CONSTRAINT "order_items_quantity_ck" CHECK ("quantity" > 0),
  ADD CONSTRAINT "order_items_unit_price_ck" CHECK ("unit_price" > 0),
  ADD CONSTRAINT "order_items_line_total_ck" CHECK ("line_total" = "unit_price" * "quantity");

ALTER TABLE "payments"
  ADD CONSTRAINT "payments_amount_ck" CHECK ("amount" > 0),
  ADD CONSTRAINT "payments_provider_matches_method_ck"
    CHECK (("method" = 'COD' AND "provider" IS NULL) OR ("method" <> 'COD' AND "provider" IS NOT NULL));

ALTER TABLE "refunds"
  ADD CONSTRAINT "refunds_amount_ck" CHECK ("amount" > 0);

ALTER TABLE "return_items"
  ADD CONSTRAINT "return_items_quantity_ck" CHECK ("quantity" > 0);

ALTER TABLE "stock_movements"
  ADD CONSTRAINT "stock_movements_change_ck" CHECK ("quantity_change" <> 0),
  ADD CONSTRAINT "stock_movements_stock_after_ck" CHECK ("stock_after" >= 0);

-- ─────────────────────────────────────────────────────────────
-- System records
-- ─────────────────────────────────────────────────────────────
ALTER TABLE "email_outbox"
  ADD CONSTRAINT "email_outbox_attempts_ck" CHECK ("attempts" >= 0);

-- Audit log is append-only (D-119)
CREATE FUNCTION "audit_logs_block_changes"() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs is append-only: % is not allowed', TG_OP;
END;
$$;

CREATE TRIGGER "audit_logs_no_update_delete"
  BEFORE UPDATE OR DELETE ON "audit_logs"
  FOR EACH ROW EXECUTE FUNCTION "audit_logs_block_changes"();

CREATE TRIGGER "audit_logs_no_truncate"
  BEFORE TRUNCATE ON "audit_logs"
  FOR EACH STATEMENT EXECUTE FUNCTION "audit_logs_block_changes"();

-- ─────────────────────────────────────────────────────────────
-- Supabase lockdown (D-088)
-- Row Level Security on every table with no policies = Supabase's public
-- Data API can read and write nothing. The API app connects as the table
-- owner, which RLS does not restrict.
-- Every later migration that adds a table must enable RLS too
-- (a CI test checks this).
-- ─────────────────────────────────────────────────────────────
DO $$
DECLARE t record;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.tablename);
  END LOOP;
END $$;

-- Remove any access Supabase's API roles have. Skipped automatically on a
-- plain PostgreSQL without these roles.
DO $$
DECLARE r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['anon', 'authenticated'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('REVOKE ALL ON ALL TABLES IN SCHEMA public FROM %I', r);
      EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM %I', r);
      EXECUTE format('REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM %I', r);
      EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM %I', r);
      EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON SEQUENCES FROM %I', r);
      EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM %I', r);
    END IF;
  END LOOP;
END $$;
