// Verifies the database enforces the rules from the Database Design document.
// Runs against a scratch PostgreSQL with both migrations applied.
import pg from "pg";
import { randomUUID } from "node:crypto";

// DB_URL overrides; otherwise the same direct connection migrations use.
const pool = new pg.Pool({ connectionString: process.env.DB_URL ?? process.env.DIRECT_URL, max: 25 });
const q = (sql, params) => pool.query(sql, params);
let passed = 0, failed = 0;

async function expectOk(name, fn) {
  try { await fn(); console.log("PASS", name); passed++; }
  catch (e) { console.log("FAIL", name, "-", e.message); failed++; }
}
async function expectReject(name, fn, match) {
  try { await fn(); console.log("FAIL", name, "- was allowed"); failed++; }
  catch (e) {
    if (match && !e.message.includes(match)) { console.log("FAIL", name, "- wrong error:", e.message); failed++; }
    else { console.log("PASS", name, "->", e.message.split("\n")[0]); passed++; }
  }
}

// ── Base data ────────────────────────────────────────────────
const now = "now()";
await q(`INSERT INTO governorates (code, shipping_fee, updated_at) VALUES ('CAI', 60, ${now})`);
const brandId = randomUUID(), catId = randomUUID(), prodId = randomUUID(), varId = randomUUID();
await q(`INSERT INTO brands (id, name, slug, updated_at) VALUES ($1, 'Glow Lab', 'glow-lab', ${now})`, [brandId]);
await q(`INSERT INTO categories (id, slug, updated_at) VALUES ($1, 'lipstick', ${now})`, [catId]);
await q(`INSERT INTO products (id, brand_id, category_id, slug, status, updated_at) VALUES ($1,$2,$3,'velvet-matte','ACTIVE',${now})`, [prodId, brandId, catId]);
await q(`INSERT INTO variants (id, product_id, sku, option_key, price, stock_quantity, updated_at) VALUES ($1,$2,'GL-VM-04','a',350.00,5,${now})`, [varId, prodId]);

function orderInsert(extra = {}) {
  const o = { id: randomUUID(), status: "CONFIRMED", subtotal: 350, shipping: 60, total: 410, tracking: null, ...extra };
  return q(
    `INSERT INTO orders (id, status, payment_method, contact_name, contact_email, contact_phone, recipient_name, ship_phone,
       governorate_code, governorate_name, city_area, street, building, subtotal, shipping_fee, total, tracking_number, updated_at)
     VALUES ($1,$2,'COD','Nour','nour@example.com','01012345678','Nour','01012345678','CAI','Cairo','Maadi','Road 9','12',$3,$4,$5,$6,now())
     RETURNING order_number`,
    [o.id, o.status, o.subtotal, o.shipping, o.total, o.tracking]);
}

// ── Tests ────────────────────────────────────────────────────
await expectOk("order numbers start at 100001", async () => {
  const r = await orderInsert();
  if (String(r.rows[0].order_number) !== "100001") throw new Error("got " + r.rows[0].order_number);
});

await expectReject("duplicate SKU differing only in case", () =>
  q(`INSERT INTO variants (id, product_id, sku, option_key, price, updated_at) VALUES ($1,$2,'gl-vm-04','b',350,now())`, [randomUUID(), prodId]), "variants_sku_key");

await expectReject("two variants with the same option combination", () =>
  q(`INSERT INTO variants (id, product_id, sku, option_key, price, updated_at) VALUES ($1,$2,'GL-VM-05','a',350,now())`, [randomUUID(), prodId]), "variants_product_id_option_key_key");

await expectReject("price of zero", () =>
  q(`INSERT INTO variants (id, product_id, sku, option_key, price, updated_at) VALUES ($1,$2,'GL-VM-06','c',0,now())`, [randomUUID(), prodId]), "variants_price_ck");

await expectReject("stock below zero", () =>
  q(`UPDATE variants SET stock_quantity = stock_quantity - 6 WHERE id = $1`, [varId]), "variants_stock_quantity_ck");

await expectReject("order total that doesn't add up", () => orderInsert({ total: 400 }), "orders_total_ck");

await expectReject("shipped order without a tracking number", () => orderInsert({ status: "SHIPPED" }), "orders_shipped_has_tracking_ck");

await expectReject("COD payment with a provider", async () => {
  const r = await q(`SELECT id FROM orders LIMIT 1`);
  await q(`INSERT INTO payments (id, order_id, method, provider, amount, updated_at) VALUES ($1,$2,'COD','PAYMOB',410,now())`, [randomUUID(), r.rows[0].id]);
}, "payments_provider_matches_method_ck");

await expectReject("card payment without a provider", async () => {
  const r = await q(`SELECT id FROM orders LIMIT 1`);
  await q(`INSERT INTO payments (id, order_id, method, amount, updated_at) VALUES ($1,$2,'CARD',410,now())`, [randomUUID(), r.rows[0].id]);
}, "payments_provider_matches_method_ck");

await expectReject("customer emails differing only in case", async () => {
  await q(`INSERT INTO customers (id, email, updated_at) VALUES ($1,'Nour@Example.com',now())`, [randomUUID()]);
  await q(`INSERT INTO customers (id, email, updated_at) VALUES ($1,'nour@example.com',now())`, [randomUUID()]);
}, "customers_email_key");

await expectReject("active customer without an email", () =>
  q(`INSERT INTO customers (id, status, updated_at) VALUES ($1,'ACTIVE',now())`, [randomUUID()]), "customers_active_has_email_ck");

await expectReject("two default addresses for one customer", async () => {
  const c = randomUUID();
  await q(`INSERT INTO customers (id, email, updated_at) VALUES ($1,'sara@example.com',now())`, [c]);
  for (let i = 0; i < 2; i++)
    await q(`INSERT INTO customer_addresses (id, customer_id, recipient_name, phone, governorate_code, city_area, street, building, is_default, updated_at)
             VALUES ($1,$2,'Sara','01112345678','CAI','Zamalek','26 July','5',true,now())`, [randomUUID(), c]);
}, "customer_addresses_one_default_idx");

await expectReject("auth token with no owner", () =>
  q(`INSERT INTO auth_tokens (id, purpose, token_hash, expires_at, updated_at) VALUES ($1,'PASSWORD_RESET','h1',now(),now())`, [randomUUID()]), "auth_tokens_one_owner_ck");

await expectReject("a second store settings row", async () => {
  await q(`INSERT INTO store_settings (id, updated_at) VALUES (1, now())`);
  await q(`INSERT INTO store_settings (id, updated_at) VALUES (2, now())`);
}, "store_settings_single_row_ck");

await expectReject("cart quantity above 10", async () => {
  const c = randomUUID(), cart = randomUUID();
  await q(`INSERT INTO customers (id, email, updated_at) VALUES ($1,'mona@example.com',now())`, [c]);
  await q(`INSERT INTO carts (id, customer_id, updated_at) VALUES ($1,$2,now())`, [cart, c]);
  await q(`INSERT INTO cart_items (cart_id, variant_id, quantity, updated_at) VALUES ($1,$2,11,now())`, [cart, varId]);
}, "cart_items_quantity_ck");

await expectReject("duplicate payment webhook event", async () => {
  for (let i = 0; i < 2; i++)
    await q(`INSERT INTO payment_webhook_events (id, provider, event_id, event_type, payload, signature_valid, updated_at)
             VALUES ($1,'PAYMOB','evt_1','TRANSACTION','{}',true,now())`, [randomUUID()]);
}, "payment_webhook_events_provider_event_id_key");

await expectReject("hard-deleting a variant that was ordered", async () => {
  const r = await q(`SELECT id FROM orders LIMIT 1`);
  await q(`INSERT INTO order_items (id, order_id, variant_id, product_name, brand_name, sku, unit_price, quantity, line_total, updated_at)
           VALUES ($1,$2,$3,'Velvet Matte','Glow Lab','GL-VM-04',350,1,350,now())`, [randomUUID(), r.rows[0].id, varId]);
  await q(`DELETE FROM variants WHERE id = $1`, [varId]);
}, "order_items_variant_id_fkey");

await expectReject("editing the audit log", async () => {
  const id = randomUUID();
  await q(`INSERT INTO audit_logs (id, action, entity_type, entity_id) VALUES ($1,'product.price_changed','product',$2)`, [id, prodId]);
  await q(`UPDATE audit_logs SET action = 'tampered' WHERE id = $1`, [id]);
}, "append-only");

await expectReject("deleting from the audit log", () => q(`DELETE FROM audit_logs`), "append-only");

// ── Concurrency: 20 shoppers, last 5 units (SM-3, design section 5.1) ──
await expectOk("20 simultaneous orders for the last 5 units never oversell", async () => {
  await q(`UPDATE variants SET stock_quantity = 5 WHERE id = $1`, [varId]);
  const attempt = async () => {
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const r = await client.query(`SELECT stock_quantity FROM variants WHERE id = $1 FOR UPDATE`, [varId]);
      await new Promise((res) => setTimeout(res, 5)); // widen the race window
      if (r.rows[0].stock_quantity < 1) { await client.query("ROLLBACK"); return "sold out"; }
      await client.query(`UPDATE variants SET stock_quantity = stock_quantity - 1 WHERE id = $1`, [varId]);
      await client.query("COMMIT");
      return "bought";
    } catch (e) { await client.query("ROLLBACK"); return "error: " + e.message; }
    finally { client.release(); }
  };
  const results = await Promise.all(Array.from({ length: 20 }, attempt));
  const bought = results.filter((r) => r === "bought").length;
  const soldOut = results.filter((r) => r === "sold out").length;
  const stock = (await q(`SELECT stock_quantity FROM variants WHERE id = $1`, [varId])).rows[0].stock_quantity;
  console.log(`      bought=${bought} soldOut=${soldOut} finalStock=${stock}`);
  if (bought !== 5 || soldOut !== 15 || stock !== 0) throw new Error("oversold or undersold");
});

// Without the lock, the same race can oversell. Shown for comparison; the
// database CHECK still refuses negative stock, so it fails loudly instead.
await expectOk("without the row lock, the stock check catches the race", async () => {
  await q(`UPDATE variants SET stock_quantity = 5 WHERE id = $1`, [varId]);
  const attempt = async () => {
    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const r = await client.query(`SELECT stock_quantity FROM variants WHERE id = $1`, [varId]); // no FOR UPDATE
      await new Promise((res) => setTimeout(res, 5));
      if (r.rows[0].stock_quantity < 1) { await client.query("ROLLBACK"); return "sold out"; }
      await client.query(`UPDATE variants SET stock_quantity = stock_quantity - 1 WHERE id = $1`, [varId]);
      await client.query("COMMIT");
      return "bought";
    } catch { await client.query("ROLLBACK"); return "blocked by database"; }
    finally { client.release(); }
  };
  const results = await Promise.all(Array.from({ length: 20 }, attempt));
  const stock = (await q(`SELECT stock_quantity FROM variants WHERE id = $1`, [varId])).rows[0].stock_quantity;
  const blocked = results.filter((r) => r === "blocked by database").length;
  console.log(`      bought=${results.filter((r) => r === "bought").length} blockedByCheck=${blocked} finalStock=${stock}`);
  if (stock < 0) throw new Error("stock went negative");
});

await expectOk("Row Level Security enabled on every table", async () => {
  const r = await q(`SELECT count(*) FILTER (WHERE NOT rowsecurity) AS off FROM pg_tables WHERE schemaname = 'public'`);
  if (Number(r.rows[0].off) !== 0) throw new Error(r.rows[0].off + " tables without RLS");
});

console.log(`\n${passed} passed, ${failed} failed`);
await pool.end();
process.exit(failed ? 1 : 0);
