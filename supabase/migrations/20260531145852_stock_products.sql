create table if not exists stock_products (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    icon text not null,
    packages int not null default 0,
    loose_units int not null default 0,
    units_per_package int not null default 1,
    created_at timestamptz not null default now()
);

alter table household_tasks
    add column if not exists product_id uuid references stock_products(id) on delete set null;
