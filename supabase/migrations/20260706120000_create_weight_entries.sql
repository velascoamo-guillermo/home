create table if not exists weight_entries (
    id uuid primary key default gen_random_uuid(),
    pet_id uuid not null references pets(id) on delete cascade,
    date timestamptz not null,
    weight_kg double precision not null check (weight_kg > 0),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create index if not exists weight_entries_updated_at_idx on weight_entries (updated_at);

alter table weight_entries enable row level security;

create policy "allow all"
    on weight_entries
    for all
    using (true)
    with check (true);

drop trigger if exists weight_entries_set_updated_at on weight_entries;
create trigger weight_entries_set_updated_at
    before update on weight_entries
    for each row execute function set_updated_at();
