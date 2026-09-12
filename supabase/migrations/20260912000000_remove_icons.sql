-- supabase/migrations/20260912000000_remove_icons.sql
alter table household_tasks
  add column if not exists section text not null default 'general';

update household_tasks set section = case icon
  when 'drop'         then 'plumbing'
  when 'flame'        then 'kitchen'
  when 'fan'          then 'climate'
  when 'lightbulb'    then 'lighting'
  when 'trash'        then 'cleaning'
  when 'shippingbox'  then 'storage'
  when 'hammer'       then 'repairs'
  when 'leaf'         then 'garden'
  when 'air.purifier' then 'airQuality'
  else 'general'
end;

alter table household_tasks drop column if exists icon;
alter table task_sections   drop column if exists icon;
alter table stock_products  drop column if exists icon;
