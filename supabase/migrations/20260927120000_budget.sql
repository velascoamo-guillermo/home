-- Budget: replaces the monthly spreadsheet. Money is integer cents; rows are only soft-deleted.
create table if not exists budget_members (
    id uuid primary key default gen_random_uuid(),
    name text not null check (length(btrim(name)) > 0),
    sort_order integer not null default 0,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create table if not exists budget_categories (
    id uuid primary key default gen_random_uuid(),
    name text not null check (length(btrim(name)) > 0),
    estimate_cents bigint not null default 0 check (estimate_cents >= 0),
    sort_order integer not null default 0,
    archived boolean not null default false,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create table if not exists budget_incomes (
    id uuid primary key default gen_random_uuid(),
    member_id uuid not null references budget_members(id) on delete restrict,
    month text not null check (month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    amount_cents bigint not null check (amount_cents >= 0),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create table if not exists budget_recurring (
    id uuid primary key default gen_random_uuid(),
    name text not null check (length(btrim(name)) > 0),
    amount_cents bigint not null check (amount_cents > 0 and amount_cents <= 100000000),
    category_id uuid not null references budget_categories(id) on delete restrict,
    payer_id uuid not null references budget_members(id) on delete restrict,
    day_of_month integer not null check (day_of_month between 1 and 28),
    active boolean not null default true,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create table if not exists budget_expenses (
    id uuid primary key default gen_random_uuid(),
    name text not null default '',
    amount_cents bigint not null check (amount_cents > 0 and amount_cents <= 100000000),
    category_id uuid not null references budget_categories(id) on delete restrict,
    payer_id uuid not null references budget_members(id) on delete restrict,
    date timestamptz not null,
    recurring_id uuid references budget_recurring(id) on delete restrict,
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

-- Same sync conventions as every other table: cursor index, open RLS, and a server-stamped
-- updated_at on insert AND update (see 20260914120000_server_stamped_inserts.sql).
do $$
declare t text;
begin
  foreach t in array array[
    'budget_members','budget_categories','budget_incomes','budget_recurring','budget_expenses'
  ] loop
    execute format('create index if not exists %I on %I (updated_at)', t || '_updated_at_idx', t);
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists "allow all" on %I', t);
    execute format('create policy "allow all" on %I for all using (true) with check (true)', t);
    execute format('drop trigger if exists %I on %I', t || '_set_updated_at', t);
    execute format('create trigger %I before insert or update on %I for each row execute function set_updated_at()',
                   t || '_set_updated_at', t);
  end loop;
end $$;
