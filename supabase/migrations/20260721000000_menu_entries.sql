-- Meal catalog split: menu_entries assigns catalog meals to (day, slot).
create table if not exists menu_entries (
    id uuid primary key default gen_random_uuid(),
    day_of_week integer not null check (day_of_week between 1 and 7),
    slot text not null check (slot in ('lunch', 'dinner')),
    meal_id uuid not null references meals(id) on delete cascade,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz
);

create index if not exists menu_entries_updated_at_idx on menu_entries (updated_at);

alter table menu_entries enable row level security;

create policy "allow all"
    on menu_entries
    for all
    using (true)
    with check (true);

drop trigger if exists menu_entries_set_updated_at on menu_entries;
create trigger menu_entries_set_updated_at
    before update on menu_entries
    for each row execute function set_updated_at();

-- Backfill: every live meal row is currently a (day, slot) assignment.
insert into menu_entries (day_of_week, slot, meal_id)
select day_of_week, slot, id
from meals
where deleted_at is null and title <> '';

-- Dedupe recipes by lower(title). Canonical = most recently updated.
-- Empty titles are NOT deduped.
create temporary table _meal_dupes on commit drop as
with ranked as (
    select id,
           lower(title) as key,
           row_number() over (partition by lower(title)
                              order by updated_at desc, id) as rn
    from meals
    where deleted_at is null and title <> ''
),
canon as (
    select key, id from ranked where rn = 1
)
select r.id as dupe_id, c.id as canon_id
from ranked r
join canon c on c.key = r.key
where r.rn > 1;

update menu_entries me
set meal_id = d.canon_id, updated_at = now()
from _meal_dupes d
where me.meal_id = d.dupe_id;

-- Repoint product links where the canonical meal lacks that product…
-- distinct on caps this at one repointed row per (canon_id, product_id):
-- a single UPDATE...FROM evaluates `not exists` against the pre-statement
-- snapshot for every candidate row, so if two+ dupes hold the same product
-- (e.g. the same recipe re-entered on another weekday) they'd otherwise all
-- pass the guard and collide on meal_products' unique (meal_id, product_id).
-- Tie-break picks the most recently updated candidate, then id, so the
-- choice is deterministic; whichever candidate is NOT picked here still
-- points at dupe_id and is caught by the tombstone statement below.
with repoint_candidates as (
    select distinct on (d.canon_id, mp.product_id)
        mp.id as row_id,
        d.canon_id
    from meal_products mp
    join _meal_dupes d on d.dupe_id = mp.meal_id
    where mp.deleted_at is null
      and not exists (
          select 1 from meal_products x
          where x.meal_id = d.canon_id
            and x.product_id = mp.product_id
            and x.deleted_at is null
      )
    order by d.canon_id, mp.product_id, mp.updated_at desc, mp.id
)
update meal_products mp
set meal_id = rc.canon_id, updated_at = now()
from repoint_candidates rc
where mp.id = rc.row_id;

-- …and tombstone the colliding leftovers.
update meal_products mp
set deleted_at = now(), updated_at = now()
from _meal_dupes d
where mp.meal_id = d.dupe_id
  and mp.deleted_at is null;

-- Tombstone duplicate meals.
update meals m
set deleted_at = now(), updated_at = now()
from _meal_dupes d
where m.id = d.dupe_id;

-- Drop the old slot-identity of meals (also drops unique(day_of_week, slot)).
alter table meals drop column if exists day_of_week;
alter table meals drop column if exists slot;
