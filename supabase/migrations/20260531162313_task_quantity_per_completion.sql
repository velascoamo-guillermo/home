alter table household_tasks
    add column if not exists quantity_per_completion int not null default 1;
