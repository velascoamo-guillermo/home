alter table stock_products add column if not exists level text not null default 'full'
  check (level in ('out','low','medium','full'));
update stock_products set level = case
  when packages = 0 and loose_units = 0 then 'out'
  when packages = 0 then 'low'
  when packages = 1 then 'medium'
  else 'full' end;
