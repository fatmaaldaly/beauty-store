-- Extensions (D-148). IF NOT EXISTS: safe on Supabase, where some
-- extensions are pre-installed, and on plain PostgreSQL in CI.
CREATE EXTENSION IF NOT EXISTS "citext";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- CreateEnum
CREATE TYPE "locale" AS ENUM ('en', 'ar');

-- CreateEnum
CREATE TYPE "record_status" AS ENUM ('ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "product_status" AS ENUM ('DRAFT', 'ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "option_kind" AS ENUM ('SHADE', 'SIZE', 'SCENT');

-- CreateEnum
CREATE TYPE "customer_status" AS ENUM ('ACTIVE', 'ANONYMIZED');

-- CreateEnum
CREATE TYPE "staff_role" AS ENUM ('ADMIN', 'STAFF');

-- CreateEnum
CREATE TYPE "staff_status" AS ENUM ('INVITED', 'ACTIVE', 'DEACTIVATED');

-- CreateEnum
CREATE TYPE "auth_token_purpose" AS ENUM ('EMAIL_VERIFICATION', 'PASSWORD_RESET', 'EMAIL_CHANGE', 'STAFF_INVITE');

-- CreateEnum
CREATE TYPE "order_status" AS ENUM ('AWAITING_PAYMENT', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED', 'RETURNED_TO_SENDER');

-- CreateEnum
CREATE TYPE "payment_status" AS ENUM ('UNPAID', 'PAID', 'PARTIALLY_REFUNDED', 'REFUNDED', 'FAILED');

-- CreateEnum
CREATE TYPE "payment_method" AS ENUM ('CARD', 'COD', 'WALLET');

-- CreateEnum
CREATE TYPE "payment_provider_name" AS ENUM ('PAYMOB');

-- CreateEnum
CREATE TYPE "payment_attempt_status" AS ENUM ('PENDING', 'SUCCEEDED', 'FAILED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "refund_method" AS ENUM ('PROVIDER', 'BANK_TRANSFER', 'WALLET_TRANSFER', 'CASH');

-- CreateEnum
CREATE TYPE "refund_status" AS ENUM ('PENDING', 'SUCCEEDED', 'FAILED');

-- CreateEnum
CREATE TYPE "return_disposition" AS ENUM ('RESTOCK', 'WRITE_OFF');

-- CreateEnum
CREATE TYPE "status_actor" AS ENUM ('CUSTOMER', 'STAFF', 'SYSTEM', 'PAYMENT_WEBHOOK');

-- CreateEnum
CREATE TYPE "stock_movement_reason" AS ENUM ('ORDER_PLACED', 'ORDER_CANCELLED', 'ORDER_EXPIRED', 'RETURNED_TO_SENDER', 'RETURN_RESTOCKED', 'RECEIVED', 'CORRECTION', 'DAMAGED');

-- CreateEnum
CREATE TYPE "email_status" AS ENUM ('PENDING', 'SENT', 'FAILED');

-- CreateTable
CREATE TABLE "brands" (
    "id" UUID NOT NULL,
    "name" CITEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "logo_storage_key" TEXT,
    "status" "record_status" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "brands_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "brand_translations" (
    "brand_id" UUID NOT NULL,
    "locale" "locale" NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "brand_translations_pkey" PRIMARY KEY ("brand_id","locale")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" UUID NOT NULL,
    "parent_id" UUID,
    "slug" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "status" "record_status" NOT NULL DEFAULT 'ACTIVE',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "category_translations" (
    "category_id" UUID NOT NULL,
    "locale" "locale" NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "category_translations_pkey" PRIMARY KEY ("category_id","locale")
);

-- CreateTable
CREATE TABLE "products" (
    "id" UUID NOT NULL,
    "brand_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "slug" TEXT NOT NULL,
    "status" "product_status" NOT NULL DEFAULT 'DRAFT',
    "activated_at" TIMESTAMPTZ(6),
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_translations" (
    "product_id" UUID NOT NULL,
    "locale" "locale" NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "product_translations_pkey" PRIMARY KEY ("product_id","locale")
);

-- CreateTable
CREATE TABLE "product_options" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "kind" "option_kind" NOT NULL,
    "position" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "product_options_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "option_values" (
    "id" UUID NOT NULL,
    "option_id" UUID NOT NULL,
    "position" INTEGER NOT NULL,
    "swatch_hex" CHAR(7),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "option_values_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "option_value_translations" (
    "option_value_id" UUID NOT NULL,
    "locale" "locale" NOT NULL,
    "label" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "option_value_translations_pkey" PRIMARY KEY ("option_value_id","locale")
);

-- CreateTable
CREATE TABLE "variants" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "sku" CITEXT NOT NULL,
    "option_key" TEXT NOT NULL DEFAULT '',
    "price" DECIMAL(12,2) NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'EGP',
    "stock_quantity" INTEGER NOT NULL DEFAULT 0,
    "is_enabled" BOOLEAN NOT NULL DEFAULT true,
    "status" "record_status" NOT NULL DEFAULT 'ACTIVE',
    "image_id" UUID,
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "variants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "variant_option_values" (
    "variant_id" UUID NOT NULL,
    "option_value_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "variant_option_values_pkey" PRIMARY KEY ("variant_id","option_value_id")
);

-- CreateTable
CREATE TABLE "product_images" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "storage_key" TEXT NOT NULL,
    "width" INTEGER NOT NULL,
    "height" INTEGER NOT NULL,
    "position" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "product_images_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_image_translations" (
    "image_id" UUID NOT NULL,
    "locale" "locale" NOT NULL,
    "alt_text" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "product_image_translations_pkey" PRIMARY KEY ("image_id","locale")
);

-- CreateTable
CREATE TABLE "banners" (
    "id" UUID NOT NULL,
    "storage_key" TEXT NOT NULL,
    "link_url" TEXT,
    "position" INTEGER NOT NULL,
    "starts_at" TIMESTAMPTZ(6),
    "ends_at" TIMESTAMPTZ(6),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "banners_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "banner_translations" (
    "banner_id" UUID NOT NULL,
    "locale" "locale" NOT NULL,
    "alt_text" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "banner_translations_pkey" PRIMARY KEY ("banner_id","locale")
);

-- CreateTable
CREATE TABLE "featured_products" (
    "product_id" UUID NOT NULL,
    "position" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "featured_products_pkey" PRIMARY KEY ("product_id")
);

-- CreateTable
CREATE TABLE "governorates" (
    "code" VARCHAR(8) NOT NULL,
    "shipping_fee" DECIMAL(12,2) NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'EGP',
    "is_enabled" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "governorates_pkey" PRIMARY KEY ("code")
);

-- CreateTable
CREATE TABLE "governorate_translations" (
    "code" VARCHAR(8) NOT NULL,
    "locale" "locale" NOT NULL,
    "name" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "governorate_translations_pkey" PRIMARY KEY ("code","locale")
);

-- CreateTable
CREATE TABLE "store_settings" (
    "id" SMALLINT NOT NULL DEFAULT 1,
    "cod_max_order_value" DECIMAL(12,2),
    "free_shipping_threshold" DECIMAL(12,2),
    "return_window_days" INTEGER NOT NULL DEFAULT 14,
    "low_stock_threshold" INTEGER NOT NULL DEFAULT 5,
    "new_order_email_enabled" BOOLEAN NOT NULL DEFAULT false,
    "new_order_email_recipients" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "contact_email" CITEXT,
    "contact_phone" TEXT,
    "version" INTEGER NOT NULL DEFAULT 1,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "store_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customers" (
    "id" UUID NOT NULL,
    "email" CITEXT,
    "email_verified_at" TIMESTAMPTZ(6),
    "password_hash" TEXT,
    "google_subject" TEXT,
    "first_name" TEXT,
    "last_name" TEXT,
    "phone" TEXT,
    "status" "customer_status" NOT NULL DEFAULT 'ACTIVE',
    "anonymized_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "customers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_addresses" (
    "id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "recipient_name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "governorate_code" VARCHAR(8) NOT NULL,
    "city_area" TEXT NOT NULL,
    "street" TEXT NOT NULL,
    "building" TEXT NOT NULL,
    "floor" TEXT,
    "apartment" TEXT,
    "landmark" TEXT,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "customer_addresses_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "customer_sessions" (
    "id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "last_seen_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ip" INET,
    "user_agent" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "customer_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "staff_users" (
    "id" UUID NOT NULL,
    "email" CITEXT NOT NULL,
    "password_hash" TEXT,
    "first_name" TEXT NOT NULL,
    "last_name" TEXT NOT NULL,
    "role" "staff_role" NOT NULL,
    "status" "staff_status" NOT NULL DEFAULT 'INVITED',
    "locale" "locale" NOT NULL DEFAULT 'en',
    "totp_secret_encrypted" TEXT,
    "totp_enabled_at" TIMESTAMPTZ(6),
    "failed_login_count" INTEGER NOT NULL DEFAULT 0,
    "locked_until" TIMESTAMPTZ(6),
    "last_login_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "staff_users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "staff_sessions" (
    "id" UUID NOT NULL,
    "staff_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "last_seen_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "two_factor_passed" BOOLEAN NOT NULL DEFAULT false,
    "ip" INET,
    "user_agent" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "staff_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "staff_recovery_codes" (
    "id" UUID NOT NULL,
    "staff_id" UUID NOT NULL,
    "code_hash" TEXT NOT NULL,
    "used_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "staff_recovery_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "auth_tokens" (
    "id" UUID NOT NULL,
    "purpose" "auth_token_purpose" NOT NULL,
    "token_hash" TEXT NOT NULL,
    "customer_id" UUID,
    "staff_id" UUID,
    "new_email" CITEXT,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "used_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "auth_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rate_limit_counters" (
    "key" TEXT NOT NULL,
    "count" INTEGER NOT NULL DEFAULT 0,
    "window_ends_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "rate_limit_counters_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "carts" (
    "id" UUID NOT NULL,
    "customer_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "carts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cart_items" (
    "cart_id" UUID NOT NULL,
    "variant_id" UUID NOT NULL,
    "quantity" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "cart_items_pkey" PRIMARY KEY ("cart_id","variant_id")
);

-- CreateTable
CREATE TABLE "orders" (
    "id" UUID NOT NULL,
    "order_number" BIGSERIAL NOT NULL,
    "customer_id" UUID,
    "guest_token_hash" TEXT,
    "status" "order_status" NOT NULL,
    "payment_status" "payment_status" NOT NULL DEFAULT 'UNPAID',
    "payment_method" "payment_method" NOT NULL,
    "contact_name" TEXT NOT NULL,
    "contact_email" CITEXT NOT NULL,
    "contact_phone" TEXT NOT NULL,
    "recipient_name" TEXT NOT NULL,
    "ship_phone" TEXT NOT NULL,
    "governorate_code" VARCHAR(8) NOT NULL,
    "governorate_name" TEXT NOT NULL,
    "city_area" TEXT NOT NULL,
    "street" TEXT NOT NULL,
    "building" TEXT NOT NULL,
    "floor" TEXT,
    "apartment" TEXT,
    "landmark" TEXT,
    "note" VARCHAR(500),
    "currency" CHAR(3) NOT NULL DEFAULT 'EGP',
    "subtotal" DECIMAL(12,2) NOT NULL,
    "shipping_fee" DECIMAL(12,2) NOT NULL,
    "total" DECIMAL(12,2) NOT NULL,
    "expires_at" TIMESTAMPTZ(6),
    "courier_name" TEXT,
    "tracking_number" TEXT,
    "shipped_at" TIMESTAMPTZ(6),
    "delivered_at" TIMESTAMPTZ(6),
    "cancelled_at" TIMESTAMPTZ(6),
    "cancellation_reason" TEXT,
    "version" INTEGER NOT NULL DEFAULT 1,
    "anonymized_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_items" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "variant_id" UUID NOT NULL,
    "product_name" TEXT NOT NULL,
    "brand_name" TEXT NOT NULL,
    "option_summary" TEXT NOT NULL DEFAULT '',
    "sku" TEXT NOT NULL,
    "unit_price" DECIMAL(12,2) NOT NULL,
    "quantity" INTEGER NOT NULL,
    "line_total" DECIMAL(12,2) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "order_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "order_status_history" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "from_status" "order_status",
    "to_status" "order_status" NOT NULL,
    "actor_type" "status_actor" NOT NULL,
    "staff_id" UUID,
    "note" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "order_status_history_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payments" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "method" "payment_method" NOT NULL,
    "provider" "payment_provider_name",
    "provider_reference" TEXT,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'EGP',
    "status" "payment_attempt_status" NOT NULL DEFAULT 'PENDING',
    "succeeded_at" TIMESTAMPTZ(6),
    "collected_by_staff_id" UUID,
    "failure_reason" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "refunds" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "payment_id" UUID,
    "return_id" UUID,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'EGP',
    "method" "refund_method" NOT NULL,
    "status" "refund_status" NOT NULL DEFAULT 'PENDING',
    "provider_reference" TEXT,
    "idempotency_key" TEXT NOT NULL,
    "reason" TEXT,
    "staff_id" UUID,
    "completed_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "refunds_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "returns" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "staff_id" UUID NOT NULL,
    "note" TEXT,
    "override_reason" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "returns_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "return_items" (
    "id" UUID NOT NULL,
    "return_id" UUID NOT NULL,
    "order_item_id" UUID NOT NULL,
    "quantity" INTEGER NOT NULL,
    "disposition" "return_disposition" NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "return_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "payment_webhook_events" (
    "id" UUID NOT NULL,
    "provider" "payment_provider_name" NOT NULL,
    "event_id" TEXT NOT NULL,
    "event_type" TEXT NOT NULL,
    "payload" JSONB NOT NULL,
    "signature_valid" BOOLEAN NOT NULL,
    "received_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processed_at" TIMESTAMPTZ(6),
    "error" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "payment_webhook_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "stock_movements" (
    "id" UUID NOT NULL,
    "variant_id" UUID NOT NULL,
    "quantity_change" INTEGER NOT NULL,
    "stock_after" INTEGER NOT NULL,
    "reason" "stock_movement_reason" NOT NULL,
    "order_id" UUID,
    "return_id" UUID,
    "staff_id" UUID,
    "note" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "stock_movements_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "idempotency_keys" (
    "id" UUID NOT NULL,
    "scope" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "request_hash" TEXT NOT NULL,
    "response_status" INTEGER,
    "response_body" JSONB,
    "order_id" UUID,
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "idempotency_keys_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "audit_logs" (
    "id" UUID NOT NULL,
    "staff_id" UUID,
    "action" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" TEXT NOT NULL,
    "before" JSONB,
    "after" JSONB,
    "ip" INET,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "email_outbox" (
    "id" UUID NOT NULL,
    "template" TEXT NOT NULL,
    "to_email" CITEXT NOT NULL,
    "locale" "locale" NOT NULL DEFAULT 'en',
    "payload" JSONB NOT NULL,
    "status" "email_status" NOT NULL DEFAULT 'PENDING',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "next_attempt_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sent_at" TIMESTAMPTZ(6),
    "last_error" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL,

    CONSTRAINT "email_outbox_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "brands_name_key" ON "brands"("name");

-- CreateIndex
CREATE UNIQUE INDEX "brands_slug_key" ON "brands"("slug");

-- CreateIndex
CREATE INDEX "brands_name_trgm_idx" ON "brands" USING GIN ("name" gin_trgm_ops);

-- CreateIndex
CREATE UNIQUE INDEX "categories_slug_key" ON "categories"("slug");

-- CreateIndex
CREATE INDEX "categories_parent_id_idx" ON "categories"("parent_id");

-- CreateIndex
CREATE INDEX "category_translations_name_trgm_idx" ON "category_translations" USING GIN ("name" gin_trgm_ops);

-- CreateIndex
CREATE UNIQUE INDEX "products_slug_key" ON "products"("slug");

-- CreateIndex
CREATE INDEX "products_status_category_id_idx" ON "products"("status", "category_id");

-- CreateIndex
CREATE INDEX "products_status_brand_id_idx" ON "products"("status", "brand_id");

-- CreateIndex
CREATE INDEX "products_activated_at_idx" ON "products"("activated_at");

-- CreateIndex
CREATE INDEX "product_translations_name_trgm_idx" ON "product_translations" USING GIN ("name" gin_trgm_ops);

-- CreateIndex
CREATE UNIQUE INDEX "product_options_product_id_kind_key" ON "product_options"("product_id", "kind");

-- CreateIndex
CREATE UNIQUE INDEX "product_options_product_id_position_key" ON "product_options"("product_id", "position");

-- CreateIndex
CREATE INDEX "option_values_option_id_position_idx" ON "option_values"("option_id", "position");

-- CreateIndex
CREATE UNIQUE INDEX "variants_sku_key" ON "variants"("sku");

-- CreateIndex
CREATE INDEX "variants_image_id_idx" ON "variants"("image_id");

-- CreateIndex
CREATE UNIQUE INDEX "variants_product_id_option_key_key" ON "variants"("product_id", "option_key");

-- CreateIndex
CREATE INDEX "variant_option_values_option_value_id_idx" ON "variant_option_values"("option_value_id");

-- CreateIndex
CREATE INDEX "product_images_product_id_position_idx" ON "product_images"("product_id", "position");

-- CreateIndex
CREATE UNIQUE INDEX "customers_email_key" ON "customers"("email");

-- CreateIndex
CREATE UNIQUE INDEX "customers_google_subject_key" ON "customers"("google_subject");

-- CreateIndex
CREATE INDEX "customer_addresses_customer_id_idx" ON "customer_addresses"("customer_id");

-- CreateIndex
CREATE INDEX "customer_addresses_governorate_code_idx" ON "customer_addresses"("governorate_code");

-- CreateIndex
CREATE UNIQUE INDEX "customer_sessions_token_hash_key" ON "customer_sessions"("token_hash");

-- CreateIndex
CREATE INDEX "customer_sessions_customer_id_idx" ON "customer_sessions"("customer_id");

-- CreateIndex
CREATE INDEX "customer_sessions_expires_at_idx" ON "customer_sessions"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "staff_users_email_key" ON "staff_users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "staff_sessions_token_hash_key" ON "staff_sessions"("token_hash");

-- CreateIndex
CREATE INDEX "staff_sessions_staff_id_idx" ON "staff_sessions"("staff_id");

-- CreateIndex
CREATE INDEX "staff_sessions_expires_at_idx" ON "staff_sessions"("expires_at");

-- CreateIndex
CREATE INDEX "staff_recovery_codes_staff_id_idx" ON "staff_recovery_codes"("staff_id");

-- CreateIndex
CREATE UNIQUE INDEX "auth_tokens_token_hash_key" ON "auth_tokens"("token_hash");

-- CreateIndex
CREATE INDEX "auth_tokens_customer_id_idx" ON "auth_tokens"("customer_id");

-- CreateIndex
CREATE INDEX "auth_tokens_staff_id_idx" ON "auth_tokens"("staff_id");

-- CreateIndex
CREATE INDEX "auth_tokens_expires_at_idx" ON "auth_tokens"("expires_at");

-- CreateIndex
CREATE INDEX "rate_limit_counters_window_ends_at_idx" ON "rate_limit_counters"("window_ends_at");

-- CreateIndex
CREATE UNIQUE INDEX "carts_customer_id_key" ON "carts"("customer_id");

-- CreateIndex
CREATE INDEX "cart_items_variant_id_idx" ON "cart_items"("variant_id");

-- CreateIndex
CREATE UNIQUE INDEX "orders_order_number_key" ON "orders"("order_number");

-- CreateIndex
CREATE UNIQUE INDEX "orders_guest_token_hash_key" ON "orders"("guest_token_hash");

-- CreateIndex
CREATE INDEX "orders_status_created_at_idx" ON "orders"("status", "created_at");

-- CreateIndex
CREATE INDEX "orders_customer_id_created_at_idx" ON "orders"("customer_id", "created_at");

-- CreateIndex
CREATE INDEX "orders_contact_email_idx" ON "orders"("contact_email");

-- CreateIndex
CREATE INDEX "orders_contact_phone_idx" ON "orders"("contact_phone");

-- CreateIndex
CREATE INDEX "orders_governorate_code_idx" ON "orders"("governorate_code");

-- CreateIndex
CREATE INDEX "order_items_order_id_idx" ON "order_items"("order_id");

-- CreateIndex
CREATE INDEX "order_items_variant_id_idx" ON "order_items"("variant_id");

-- CreateIndex
CREATE INDEX "order_status_history_order_id_created_at_idx" ON "order_status_history"("order_id", "created_at");

-- CreateIndex
CREATE INDEX "order_status_history_staff_id_idx" ON "order_status_history"("staff_id");

-- CreateIndex
CREATE INDEX "payments_order_id_idx" ON "payments"("order_id");

-- CreateIndex
CREATE INDEX "payments_succeeded_at_idx" ON "payments"("succeeded_at");

-- CreateIndex
CREATE INDEX "payments_collected_by_staff_id_idx" ON "payments"("collected_by_staff_id");

-- CreateIndex
CREATE UNIQUE INDEX "payments_provider_provider_reference_key" ON "payments"("provider", "provider_reference");

-- CreateIndex
CREATE UNIQUE INDEX "refunds_idempotency_key_key" ON "refunds"("idempotency_key");

-- CreateIndex
CREATE INDEX "refunds_order_id_idx" ON "refunds"("order_id");

-- CreateIndex
CREATE INDEX "refunds_payment_id_idx" ON "refunds"("payment_id");

-- CreateIndex
CREATE INDEX "refunds_return_id_idx" ON "refunds"("return_id");

-- CreateIndex
CREATE INDEX "refunds_staff_id_idx" ON "refunds"("staff_id");

-- CreateIndex
CREATE INDEX "refunds_completed_at_idx" ON "refunds"("completed_at");

-- CreateIndex
CREATE INDEX "returns_order_id_idx" ON "returns"("order_id");

-- CreateIndex
CREATE INDEX "returns_staff_id_idx" ON "returns"("staff_id");

-- CreateIndex
CREATE INDEX "return_items_return_id_idx" ON "return_items"("return_id");

-- CreateIndex
CREATE INDEX "return_items_order_item_id_idx" ON "return_items"("order_item_id");

-- CreateIndex
CREATE INDEX "payment_webhook_events_received_at_idx" ON "payment_webhook_events"("received_at");

-- CreateIndex
CREATE UNIQUE INDEX "payment_webhook_events_provider_event_id_key" ON "payment_webhook_events"("provider", "event_id");

-- CreateIndex
CREATE INDEX "stock_movements_variant_id_created_at_idx" ON "stock_movements"("variant_id", "created_at");

-- CreateIndex
CREATE INDEX "stock_movements_order_id_idx" ON "stock_movements"("order_id");

-- CreateIndex
CREATE INDEX "stock_movements_return_id_idx" ON "stock_movements"("return_id");

-- CreateIndex
CREATE INDEX "stock_movements_staff_id_idx" ON "stock_movements"("staff_id");

-- CreateIndex
CREATE INDEX "idempotency_keys_expires_at_idx" ON "idempotency_keys"("expires_at");

-- CreateIndex
CREATE INDEX "idempotency_keys_order_id_idx" ON "idempotency_keys"("order_id");

-- CreateIndex
CREATE UNIQUE INDEX "idempotency_keys_scope_key_key" ON "idempotency_keys"("scope", "key");

-- CreateIndex
CREATE INDEX "audit_logs_entity_type_entity_id_idx" ON "audit_logs"("entity_type", "entity_id");

-- CreateIndex
CREATE INDEX "audit_logs_staff_id_created_at_idx" ON "audit_logs"("staff_id", "created_at");

-- CreateIndex
CREATE INDEX "audit_logs_created_at_idx" ON "audit_logs"("created_at");

-- CreateIndex
CREATE INDEX "email_outbox_status_next_attempt_at_idx" ON "email_outbox"("status", "next_attempt_at");

-- AddForeignKey
ALTER TABLE "brand_translations" ADD CONSTRAINT "brand_translations_brand_id_fkey" FOREIGN KEY ("brand_id") REFERENCES "brands"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "categories" ADD CONSTRAINT "categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "category_translations" ADD CONSTRAINT "category_translations_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_brand_id_fkey" FOREIGN KEY ("brand_id") REFERENCES "brands"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_translations" ADD CONSTRAINT "product_translations_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_options" ADD CONSTRAINT "product_options_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "option_values" ADD CONSTRAINT "option_values_option_id_fkey" FOREIGN KEY ("option_id") REFERENCES "product_options"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "option_value_translations" ADD CONSTRAINT "option_value_translations_option_value_id_fkey" FOREIGN KEY ("option_value_id") REFERENCES "option_values"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "variants" ADD CONSTRAINT "variants_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "variants" ADD CONSTRAINT "variants_image_id_fkey" FOREIGN KEY ("image_id") REFERENCES "product_images"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "variant_option_values" ADD CONSTRAINT "variant_option_values_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "variants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "variant_option_values" ADD CONSTRAINT "variant_option_values_option_value_id_fkey" FOREIGN KEY ("option_value_id") REFERENCES "option_values"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_images" ADD CONSTRAINT "product_images_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_image_translations" ADD CONSTRAINT "product_image_translations_image_id_fkey" FOREIGN KEY ("image_id") REFERENCES "product_images"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "banner_translations" ADD CONSTRAINT "banner_translations_banner_id_fkey" FOREIGN KEY ("banner_id") REFERENCES "banners"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "featured_products" ADD CONSTRAINT "featured_products_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "governorate_translations" ADD CONSTRAINT "governorate_translations_code_fkey" FOREIGN KEY ("code") REFERENCES "governorates"("code") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_addresses" ADD CONSTRAINT "customer_addresses_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_addresses" ADD CONSTRAINT "customer_addresses_governorate_code_fkey" FOREIGN KEY ("governorate_code") REFERENCES "governorates"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "customer_sessions" ADD CONSTRAINT "customer_sessions_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff_sessions" ADD CONSTRAINT "staff_sessions_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "staff_users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "staff_recovery_codes" ADD CONSTRAINT "staff_recovery_codes_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "staff_users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth_tokens" ADD CONSTRAINT "auth_tokens_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "auth_tokens" ADD CONSTRAINT "auth_tokens_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "staff_users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "carts" ADD CONSTRAINT "carts_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cart_items" ADD CONSTRAINT "cart_items_cart_id_fkey" FOREIGN KEY ("cart_id") REFERENCES "carts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cart_items" ADD CONSTRAINT "cart_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "variants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "customers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_governorate_code_fkey" FOREIGN KEY ("governorate_code") REFERENCES "governorates"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "variants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_status_history" ADD CONSTRAINT "order_status_history_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_status_history" ADD CONSTRAINT "order_status_history_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "staff_users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "payments" ADD CONSTRAINT "payments_collected_by_staff_id_fkey" FOREIGN KEY ("collected_by_staff_id") REFERENCES "staff_users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_payment_id_fkey" FOREIGN KEY ("payment_id") REFERENCES "payments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "returns"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "refunds" ADD CONSTRAINT "refunds_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "staff_users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "returns" ADD CONSTRAINT "returns_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "returns" ADD CONSTRAINT "returns_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "staff_users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "return_items" ADD CONSTRAINT "return_items_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "returns"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "return_items" ADD CONSTRAINT "return_items_order_item_id_fkey" FOREIGN KEY ("order_item_id") REFERENCES "order_items"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_movements" ADD CONSTRAINT "stock_movements_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "variants"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_movements" ADD CONSTRAINT "stock_movements_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_movements" ADD CONSTRAINT "stock_movements_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "returns"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "stock_movements" ADD CONSTRAINT "stock_movements_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "staff_users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "idempotency_keys" ADD CONSTRAINT "idempotency_keys_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "staff_users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
