create table public.orders (
    id uuid primary key default gen_random_uuid (),
    created_at timestamp(3) not null default now(),
    updated_at timestamp(3) not null default now(),
    status public.order_status not null default 'PENDING',
    issue_date date not null default now(),
    shipping_total numeric not null default 0
);

create table public.line_items (
    id uuid primary key default gen_random_uuid (),
    order_id uuid references public.orders (id) on delete cascade,
    product_id uuid not null, -- Should reference public.products
    name text not null,
    quantity numeric not null,
    unit text not null,
    unit_price numeric not null,
    tax_rate_percentage numeric default 0,
    discount numeric default 0
);

create or replace function insert_order_with_line_items (order jsonb, line_items jsonb)
    returns public.orders
    language plpgsql
    set search_path = ''
    as $function$
declare
    new_order public.orders;
begin
    -- Create a order record where default fields are populated
    select
        * into new_order
    from
        jsonb_populate_record(null::public.orders, $1);
    new_order.id = gen_random_uuid ();
    new_order.created_at = now();
    new_order.updated_at = now();
    new_order.status = coalesce(new_order.status, 'PENDING'::public.order_status);
    new_order.issue_date = coalesce(new_order.issue_date, now());
    new_order.shipping_total = coalesce(new_order.shipping_total, 0);
    -- Insert the new order
    insert into public.orders
        values (new_order.*);
    -- Insert the associated line items
    insert into public.line_items
    select
        gen_random_uuid () as id,
        new_order.id as order_id,
        product_id,
        name,
        quantity,
        unit,
        unit_price,
        coalesce(tax_rate_percentage, 0) as tax_rate_percentage,
        coalesce(discount, 0) as discount
    from
        jsonb_populate_recordset(null::public.line_items, $2);
    -- Return the inserted order
    return new_order;
end;
$function$;
