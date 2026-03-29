-- Family App — minimal Supabase schema (run in SQL Editor as one script)
-- Aligns with mobile/lib/supabase/family_repository.dart + family_row.dart
--
-- Tables: public.families (id, name, invite_code, created_at)
--         public.family_members (family_id, user_id, role)
--
-- After run: Authentication → enable Email (or your provider). Only `authenticated`
-- users can use these policies (anon has no access).
--
-- Note: The main HomeScreen still uses the local Flask API; this schema is for the
-- Supabase path (e.g. SupabaseFamilyScreen) once you sign in with Supabase Auth.

-- Supabase hosts pgcrypto under schema `extensions` by default.
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  invite_code text not null unique default encode(gen_random_bytes(4), 'hex'),
  created_at timestamptz not null default now()
);

create table if not exists public.family_members (
  family_id uuid not null references public.families (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  created_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

create index if not exists family_members_user_id_idx on public.family_members (user_id);

comment on table public.families is 'A household / family group.';
comment on column public.families.invite_code is 'Shareable code to join this family (short hex).';

-- ---------------------------------------------------------------------------
-- Trigger: creating a row in families adds the current user as owner
-- ---------------------------------------------------------------------------

create or replace function public._trg_families_add_creator_as_owner()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to create a family';
  end if;
  insert into public.family_members (family_id, user_id, role)
  values (new.id, auth.uid(), 'owner');
  return new;
end;
$$;

drop trigger if exists families_add_creator_as_owner on public.families;
create trigger families_add_creator_as_owner
after insert on public.families
for each row
execute procedure public._trg_families_add_creator_as_owner();

-- ---------------------------------------------------------------------------
-- RPC: join an existing family by invite code (optional; for next app steps)
-- ---------------------------------------------------------------------------

create or replace function public.join_family_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  fid uuid;
  normalized text;
begin
  if auth.uid() is null then
    raise exception 'Must be signed in';
  end if;
  normalized := lower(trim(p_code));
  select id into fid
  from public.families
  where lower(invite_code) = normalized
  limit 1;
  if fid is null then
    raise exception 'invalid_invite_code';
  end if;
  insert into public.family_members (family_id, user_id, role)
  values (fid, auth.uid(), 'member')
  on conflict (family_id, user_id) do nothing;
  return fid;
end;
$$;

grant execute on function public.join_family_by_code(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.families enable row level security;
alter table public.family_members enable row level security;

drop policy if exists "families_select_member" on public.families;
create policy "families_select_member"
on public.families
for select
to authenticated
using (
  exists (
    select 1
    from public.family_members m
    where m.family_id = families.id
      and m.user_id = auth.uid()
  )
);

drop policy if exists "families_insert_authenticated" on public.families;
create policy "families_insert_authenticated"
on public.families
for insert
to authenticated
with check (true);

drop policy if exists "families_update_member" on public.families;
create policy "families_update_member"
on public.families
for update
to authenticated
using (
  exists (
    select 1
    from public.family_members m
    where m.family_id = families.id
      and m.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.family_members m
    where m.family_id = families.id
      and m.user_id = auth.uid()
  )
);

drop policy if exists "families_delete_owner" on public.families;
create policy "families_delete_owner"
on public.families
for delete
to authenticated
using (
  exists (
    select 1
    from public.family_members m
    where m.family_id = families.id
      and m.user_id = auth.uid()
      and m.role = 'owner'
  )
);

-- Must not self-join family_members here (Postgres RLS → infinite recursion).
drop policy if exists "family_members_select_if_member" on public.family_members;
create policy "family_members_select_if_member"
on public.family_members
for select
to authenticated
using (user_id = auth.uid());

-- No INSERT/UPDATE/DELETE policies on family_members for authenticated:
-- membership changes go through trigger (new family) or join_family_by_code().

-- ---------------------------------------------------------------------------
-- Daily questions & answers (cloud product; UUID ids)
-- ---------------------------------------------------------------------------

create table if not exists public.daily_questions (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  question_date date not null,
  question_text text not null,
  created_at timestamptz not null default now()
);

create index if not exists daily_questions_family_id_idx on public.daily_questions (family_id);

create table if not exists public.daily_answers (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.daily_questions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  author_display_name text,
  answer_text text not null,
  image_path text,
  created_at timestamptz not null default now()
);

-- If the table already existed without image_path, add it when re-running this script.
alter table public.daily_answers add column if not exists image_path text;

create index if not exists daily_answers_question_id_idx on public.daily_answers (question_id);

alter table public.daily_questions enable row level security;
alter table public.daily_answers enable row level security;

-- SECURITY DEFINER helpers: plain subqueries on family_members can still see zero rows
-- under nested RLS during INSERT checks; definer reads membership with explicit uid filter.

-- Bypass RLS only inside these checks so nested policy evaluation cannot hide rows.
create or replace function public.is_member_of_family(p_family_id uuid)
returns boolean
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  uid uuid;
  ok boolean;
begin
  uid := auth.uid();
  if uid is null then
    return false;
  end if;
  set local row_security = off;
  select exists (
    select 1
    from public.family_members fm
    where fm.family_id = p_family_id
      and fm.user_id = uid
  ) into ok;
  return ok;
end;
$$;

create or replace function public.is_question_in_my_family(p_question_id uuid)
returns boolean
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  uid uuid;
  ok boolean;
begin
  uid := auth.uid();
  if uid is null then
    return false;
  end if;
  set local row_security = off;
  select exists (
    select 1
    from public.daily_questions q
    inner join public.family_members fm on fm.family_id = q.family_id
    where q.id = p_question_id
      and fm.user_id = uid
  ) into ok;
  return ok;
end;
$$;

create or replace function public.is_photo_in_my_family(p_photo_id uuid)
returns boolean
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  uid uuid;
  ok boolean;
begin
  uid := auth.uid();
  if uid is null then
    return false;
  end if;
  set local row_security = off;
  select exists (
    select 1
    from public.family_photos ph
    inner join public.family_members fm on fm.family_id = ph.family_id
    where ph.id = p_photo_id
      and fm.user_id = uid
  ) into ok;
  return ok;
end;
$$;

revoke all on function public.is_member_of_family(uuid) from public;
revoke all on function public.is_question_in_my_family(uuid) from public;
revoke all on function public.is_photo_in_my_family(uuid) from public;
grant execute on function public.is_member_of_family(uuid) to authenticated;
grant execute on function public.is_question_in_my_family(uuid) to authenticated;
grant execute on function public.is_photo_in_my_family(uuid) to authenticated;

drop policy if exists "daily_questions_select_member" on public.daily_questions;
create policy "daily_questions_select_member"
on public.daily_questions
for select
to authenticated
using (public.is_member_of_family(family_id));

drop policy if exists "daily_questions_insert_member" on public.daily_questions;
create policy "daily_questions_insert_member"
on public.daily_questions
for insert
to authenticated
with check (public.is_member_of_family(family_id));

drop policy if exists "daily_questions_update_member" on public.daily_questions;
create policy "daily_questions_update_member"
on public.daily_questions
for update
to authenticated
using (public.is_member_of_family(family_id))
with check (public.is_member_of_family(family_id));

drop policy if exists "daily_questions_delete_member" on public.daily_questions;
create policy "daily_questions_delete_member"
on public.daily_questions
for delete
to authenticated
using (public.is_member_of_family(family_id));

drop policy if exists "daily_answers_select_member" on public.daily_answers;
create policy "daily_answers_select_member"
on public.daily_answers
for select
to authenticated
using (public.is_question_in_my_family(question_id));

drop policy if exists "daily_answers_insert_member" on public.daily_answers;
create policy "daily_answers_insert_member"
on public.daily_answers
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_question_in_my_family(question_id)
);

drop policy if exists "daily_answers_update_own" on public.daily_answers;
create policy "daily_answers_update_own"
on public.daily_answers
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "daily_answers_delete_own" on public.daily_answers;
create policy "daily_answers_delete_own"
on public.daily_answers
for delete
to authenticated
using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Family album (cloud photos; path in bucket family_album_images)
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Album engagement (likes + comments; membership via is_photo_in_my_family)
-- ---------------------------------------------------------------------------

create table if not exists public.family_photo_likes (
  photo_id uuid not null references public.family_photos (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (photo_id, user_id)
);

create index if not exists family_photo_likes_photo_id_idx on public.family_photo_likes (photo_id);

create table if not exists public.family_photo_comments (
  id uuid primary key default gen_random_uuid(),
  photo_id uuid not null references public.family_photos (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  body text not null,
  author_display_name text,
  created_at timestamptz not null default now()
);

create index if not exists family_photo_comments_photo_id_idx on public.family_photo_comments (photo_id);

alter table public.family_photo_likes enable row level security;
alter table public.family_photo_comments enable row level security;

drop policy if exists "family_photo_likes_select_member" on public.family_photo_likes;
create policy "family_photo_likes_select_member"
on public.family_photo_likes
for select
to authenticated
using (public.is_photo_in_my_family(photo_id));

drop policy if exists "family_photo_likes_insert_member" on public.family_photo_likes;
create policy "family_photo_likes_insert_member"
on public.family_photo_likes
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_photo_in_my_family(photo_id)
);

drop policy if exists "family_photo_likes_delete_own" on public.family_photo_likes;
create policy "family_photo_likes_delete_own"
on public.family_photo_likes
for delete
to authenticated
using (
  user_id = auth.uid()
  and public.is_photo_in_my_family(photo_id)
);

drop policy if exists "family_photo_comments_select_member" on public.family_photo_comments;
create policy "family_photo_comments_select_member"
on public.family_photo_comments
for select
to authenticated
using (public.is_photo_in_my_family(photo_id));

drop policy if exists "family_photo_comments_insert_member" on public.family_photo_comments;
create policy "family_photo_comments_insert_member"
on public.family_photo_comments
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_photo_in_my_family(photo_id)
);

drop policy if exists "family_photo_comments_delete_own" on public.family_photo_comments;
create policy "family_photo_comments_delete_own"
on public.family_photo_comments
for delete
to authenticated
using (user_id = auth.uid());

-- Read-only: one query for grid thumbnails with engagement counts (RLS via family_photos).
create or replace view public.family_photos_with_counts as
select
  p.id,
  p.family_id,
  p.user_id,
  p.caption,
  p.image_path,
  p.uploader_display_name,
  p.created_at,
  coalesce(
    (select count(*)::bigint from public.family_photo_likes l where l.photo_id = p.id),
    0
  ) as like_count,
  coalesce(
    (select count(*)::bigint from public.family_photo_comments c where c.photo_id = p.id),
    0
  ) as comment_count
from public.family_photos p;

-- ---------------------------------------------------------------------------
-- Grants (Supabase often has defaults; explicit is clearer)
-- ---------------------------------------------------------------------------

grant select, insert, update, delete on public.families to authenticated;
grant select on public.family_members to authenticated;
grant select, insert, update, delete on public.daily_questions to authenticated;
grant select, insert, update, delete on public.daily_answers to authenticated;
grant select, insert, update, delete on public.family_photos to authenticated;
grant select, insert, delete on public.family_photo_likes to authenticated;
grant select, insert, delete on public.family_photo_comments to authenticated;
grant select on public.family_photos_with_counts to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: answer images (path = {family_id}/{user_id}/{filename})
-- Public bucket so Image.network(publicUrl) works; upload/delete restricted by RLS.
-- ---------------------------------------------------------------------------

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

-- Private: clients load via signed URLs (authenticated); answer images bucket stays public.
insert into storage.buckets (id, name, public, file_size_limit)
values ('family_album_images', 'family_album_images', false, 10485760)
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
