create table household_tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  icon text not null,
  interval_days int not null,
  next_due_date timestamptz not null,
  notes text not null default ''
);
