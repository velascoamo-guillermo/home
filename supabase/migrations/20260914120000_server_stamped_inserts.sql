-- Clients pull rows with updated_at > cursor. Inserts kept the client's updated_at
-- (the trigger only fired on update), so a row that reached Supabase late — an
-- offline/failed op retried days later — landed behind other devices' cursors and
-- was never pulled. Stamp inserts server-side too so every write is newer than
-- any cursor issued before it.
do $$
declare t text;
begin
  foreach t in array array[
    'pets','veterinarian','appointments','clinical_entries','pet_events',
    'task_sections','household_tasks','stock_products','meals','meal_products',
    'weight_entries','menu_entries'
  ] loop
    execute format('drop trigger if exists %I on %I', t || '_set_updated_at', t);
    execute format('create trigger %I before insert or update on %I for each row execute function set_updated_at()',
                   t || '_set_updated_at', t);
  end loop;
end $$;
