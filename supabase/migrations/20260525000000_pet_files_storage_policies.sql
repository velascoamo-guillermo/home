-- Allow anon to manage files in pet-files bucket (single-user app, no auth)
create policy "anon can upload pet-files"
on storage.objects for insert
to anon
with check (bucket_id = 'pet-files');

create policy "anon can update pet-files"
on storage.objects for update
to anon
using (bucket_id = 'pet-files');

create policy "anon can read pet-files"
on storage.objects for select
to anon
using (bucket_id = 'pet-files');

create policy "anon can delete pet-files"
on storage.objects for delete
to anon
using (bucket_id = 'pet-files');
