create table if not exists meals (
    id uuid primary key default gen_random_uuid(),
    day_of_week integer not null check (day_of_week between 1 and 7),
    slot text not null check (slot in ('lunch', 'dinner')),
    title text not null default '',
    servings integer,
    calories integer,
    protein_g integer,
    carbs_g integer,
    fat_g integer,
    created_at timestamptz not null default now(),
    unique (day_of_week, slot)
);

create table if not exists meal_products (
    id uuid primary key default gen_random_uuid(),
    meal_id uuid not null references meals(id) on delete cascade,
    product_id uuid not null references stock_products(id) on delete cascade,
    quantity integer not null default 1 check (quantity >= 1),
    unique (meal_id, product_id)
);

alter table meals enable row level security;
alter table meal_products enable row level security;

create policy "allow all"
    on meals
    for all
    using (true)
    with check (true);

create policy "allow all"
    on meal_products
    for all
    using (true)
    with check (true);
