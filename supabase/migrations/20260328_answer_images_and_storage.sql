-- Run in Supabase SQL Editor if you already applied an older schema without images + storage.
-- (The full supabase/schema.sql also contains these changes.)

alter table public.daily_answers add column if not exists image_path text;

insert into storage.buckets (id, name, public, file_size_limit)
values ('family_answer_images', 'family_answer_images', true, 10485760)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit;

drop policy if exists "answer_images_select_member" on storage.objects;
create policy "answer_images_select_member"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'family_answer_images'
  and public.is_member_of_family((split_part(name, '/', 1))::uuid)
);

drop policy if exists "answer_images_insert_own" on storage.objects;
create policy "answer_images_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'family_answer_images'
  and split_part(name, '/', 2) = auth.uid()::text
  and public.is_member_of_family((split_part(name, '/', 1))::uuid)
);

drop policy if exists "answer_images_delete_own" on storage.objects;
create policy "answer_images_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'family_answer_images'
  and split_part(name, '/', 2) = auth.uid()::text
  and public.is_member_of_family((split_part(name, '/', 1))::uuid)
);
