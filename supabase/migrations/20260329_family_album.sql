-- Cloud family album: metadata in public.family_photos, files in storage.family_album_images.
-- Object path convention: {family_id}/{user_id}/{unix_ms}.{ext} (same as answer images).

create table if not exists public.family_photos (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  caption text not null default '',
  image_path text not null,
  uploader_display_name text,
  created_at timestamptz not null default now()
);

create index if not exists family_photos_family_id_idx on public.family_photos (family_id);
create index if not exists family_photos_created_at_idx on public.family_photos (created_at desc);

alter table public.family_photos enable row level security;

drop policy if exists "family_photos_select_member" on public.family_photos;
create policy "family_photos_select_member"
on public.family_photos
for select
to authenticated
using (public.is_member_of_family(family_id));

drop policy if exists "family_photos_insert_member" on public.family_photos;
create policy "family_photos_insert_member"
on public.family_photos
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_member_of_family(family_id)
);

drop policy if exists "family_photos_update_own" on public.family_photos;
create policy "family_photos_update_own"
on public.family_photos
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "family_photos_delete_own" on public.family_photos;
create policy "family_photos_delete_own"
on public.family_photos
for delete
to authenticated
using (user_id = auth.uid());

grant select, insert, update, delete on public.family_photos to authenticated;

insert into storage.buckets (id, name, public, file_size_limit)
values ('family_album_images', 'family_album_images', true, 10485760)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit;

drop policy if exists "album_images_select_member" on storage.objects;
create policy "album_images_select_member"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'family_album_images'
  and public.is_member_of_family((split_part(name, '/', 1))::uuid)
);

drop policy if exists "album_images_insert_own" on storage.objects;
create policy "album_images_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'family_album_images'
  and split_part(name, '/', 2) = auth.uid()::text
  and public.is_member_of_family((split_part(name, '/', 1))::uuid)
);

drop policy if exists "album_images_delete_own" on storage.objects;
create policy "album_images_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'family_album_images'
  and split_part(name, '/', 2) = auth.uid()::text
  and public.is_member_of_family((split_part(name, '/', 1))::uuid)
);
