-- Offline-first sync: updated_at + deleted_at on all synced tables.
do $$
declare t text;
begin
  foreach t in array array[
    'pets','veterinarian','appointments','clinical_entries','pet_events',
    'task_sections','household_tasks','stock_products','meals','meal_products'
  ] loop
    execute format('alter table %I add column if not exists updated_at timestamptz not null default now()', t);
    execute format('alter table %I add column if not exists deleted_at timestamptz', t);
    execute format('create index if not exists %I on %I (updated_at)', t || '_updated_at_idx', t);
  end loop;
end $$;

-- Auto-bump updated_at on every update.
create or replace function set_updated_at() returns trigger as $$
begin new.updated_at = now(); return new; end;
$$ language plpgsql;

do $$
declare t text;
begin
  foreach t in array array[
    'pets','veterinarian','appointments','clinical_entries','pet_events',
    'task_sections','household_tasks','stock_products','meals','meal_products'
  ] loop
    execute format('drop trigger if exists %I on %I', t || '_set_updated_at', t);
    execute format('create trigger %I before update on %I for each row execute function set_updated_at()',
                   t || '_set_updated_at', t);
  end loop;
end $$;
