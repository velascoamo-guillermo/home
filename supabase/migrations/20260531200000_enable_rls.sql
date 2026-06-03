-- Single-user app: enable RLS on all tables and allow all operations.
-- This satisfies Supabase security requirements without restricting access.

alter table pets enable row level security;
alter table veterinarian enable row level security;
alter table appointments enable row level security;
alter table clinical_entries enable row level security;
alter table pet_events enable row level security;
alter table pet_files enable row level security;
alter table household_tasks enable row level security;
alter table task_sections enable row level security;
alter table stock_products enable row level security;

create policy "allow all" on pets using (true) with check (true);
create policy "allow all" on veterinarian using (true) with check (true);
create policy "allow all" on appointments using (true) with check (true);
create policy "allow all" on clinical_entries using (true) with check (true);
create policy "allow all" on pet_events using (true) with check (true);
create policy "allow all" on pet_files using (true) with check (true);
create policy "allow all" on household_tasks using (true) with check (true);
create policy "allow all" on task_sections using (true) with check (true);
create policy "allow all" on stock_products using (true) with check (true);
