import postgres, {
  drizzle,
} from "https://deno.land/x/drizzle@v0.23.85/postgres.ts";
import {
  pgTable,
  text,
  timestamp,
  uuid,
  date,
  pgEnum,
  numeric,
} from "https://deno.land/x/drizzle@v0.23.85/pg-core.ts";
import { InferModel } from "https://deno.land/x/drizzle@v0.23.85/mod.ts";

const databaseUrl = Deno.env.get("SUPABASE_DB_URL")!;
const client = postgres(databaseUrl);

const orderStatus = pgEnum("order_status", ["PENDING", "SHIPPED", "DELIVERED"]);

const orders = pgTable("orders", {
  id: uuid("id").primaryKey(),
  createdAt: timestamp("created_at", { precision: 3, withTimezone: true })
    .defaultNow()
    .notNull(),
  updatedAt: timestamp("updated_at", { precision: 3, withTimezone: true })
    .defaultNow()
    .notNull(),
  status: orderStatus("status").default("PENDING").notNull(),
  issueDate: date("issue_date").defaultNow().notNull(),
  shippingTotal: numeric("shipping_total").default("0").notNull(),
});

const lineItems = pgTable("line_items", {
  id: uuid("id").primaryKey(),
  orderId: uuid("order_id")
    .notNull()
    .references(() => orders.id),
  productId: uuid("product_id").notNull(),
  name: text("name").notNull(),
  quantity: numeric("quantity").notNull(),
  unit: text("unit").notNull(),
  unitPrice: numeric("unitPrice").notNull(),
  taxRatePercentage: numeric("tax_rate_percentage").default("0").notNull(),
  discount: numeric("discount").default("0").notNull(),
});

type Order = InferModel<typeof orders>;
type NewOrder = InferModel<typeof orders, "insert">;

type LineItem = InferModel<typeof lineItems>;
type NewLineItem = InferModel<typeof lineItems, "insert">;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    let order: Order & { lineItems?: LineItem[] };
    await client.begin(async (transaction) => {
      const db = drizzle(transaction);
      const insertedOrders = await db
        .insert(orders)
        .values({
          status: body.status,
          issueDate: body.issueDate,
          shippingTotal: body.shippingTotal,
        } as NewOrder)
        .returning();
      order = insertedOrders[0];

      const insertedLineItems = await db
        .insert(lineItems)
        .values(
          body.lineItems.map((lineItem: NewLineItem) => ({
            ...lineItem,
            orderId: order!.id,
          }))
        )
        .returning();
      order.lineItems = insertedLineItems;
    });

    return new Response(JSON.stringify(order!), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error(err);
    return new Response(
      JSON.stringify({ message: String(err?.message ?? err) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
