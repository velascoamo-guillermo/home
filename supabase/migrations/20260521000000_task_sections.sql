create table task_sections (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  icon text not null
);

alter table household_tasks
  add column section_id uuid references task_sections(id) on delete set null;
