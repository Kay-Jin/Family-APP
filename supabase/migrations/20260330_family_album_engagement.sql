-- Likes and comments on cloud family album photos.

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

revoke all on function public.is_photo_in_my_family(uuid) from public;
grant execute on function public.is_photo_in_my_family(uuid) to authenticated;

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

grant select, insert, delete on public.family_photo_likes to authenticated;
grant select, insert, delete on public.family_photo_comments to authenticated;
