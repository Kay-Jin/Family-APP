-- Family care suite: quick status, cloud voice mailbox, medical cards,
-- birthday reminders, optional care presence (privacy-first, default off).

-- ---------------------------------------------------------------------------
-- Quick status (one-tap for parents)
-- ---------------------------------------------------------------------------

create table if not exists public.family_status_posts (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  author_display_name text,
  status_code text not null check (status_code in ('home', 'on_way', 'tired', 'need_chat')),
  note text,
  created_at timestamptz not null default now()
);

create index if not exists family_status_posts_family_id_created_at_idx
  on public.family_status_posts (family_id, created_at desc);

alter table public.family_status_posts enable row level security;

drop policy if exists "family_status_posts_select_member" on public.family_status_posts;
create policy "family_status_posts_select_member"
on public.family_status_posts
for select
to authenticated
using (public.is_member_of_family(family_id));

drop policy if exists "family_status_posts_insert_own" on public.family_status_posts;
create policy "family_status_posts_insert_own"
on public.family_status_posts
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_member_of_family(family_id)
);

drop policy if exists "family_status_posts_delete_own" on public.family_status_posts;
create policy "family_status_posts_delete_own"
on public.family_status_posts
for delete
to authenticated
using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Voice mailbox (private bucket family_voice_messages; path family_id/user_id/file)
-- ---------------------------------------------------------------------------

create table if not exists public.family_voice_messages (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  author_display_name text,
  title text not null,
  storage_path text not null,
  duration_seconds int,
  created_at timestamptz not null default now()
);

create index if not exists family_voice_messages_family_id_created_at_idx
  on public.family_voice_messages (family_id, created_at desc);

alter table public.family_voice_messages enable row level security;

drop policy if exists "family_voice_messages_select_member" on public.family_voice_messages;
create policy "family_voice_messages_select_member"
on public.family_voice_messages
for select
to authenticated
using (public.is_member_of_family(family_id));

drop policy if exists "family_voice_messages_insert_own" on public.family_voice_messages;
create policy "family_voice_messages_insert_own"
on public.family_voice_messages
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_member_of_family(family_id)
);

drop policy if exists "family_voice_messages_update_own" on public.family_voice_messages;
create policy "family_voice_messages_update_own"
on public.family_voice_messages
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and public.is_member_of_family(family_id));

drop policy if exists "family_voice_messages_delete_own" on public.family_voice_messages;
create policy "family_voice_messages_delete_own"
on public.family_voice_messages
for delete
to authenticated
using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Medical / emergency card (one row per member per family; family-visible)
-- ---------------------------------------------------------------------------

create table if not exists public.family_medical_cards (
  family_id uuid not null references public.families (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  display_name text,
  allergies text,
  medications text,
  hospitals text,
  emergency_contact_name text,
  emergency_contact_phone text,
  accompaniment_note text,
  updated_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

alter table public.family_medical_cards enable row level security;

drop policy if exists "family_medical_cards_select_member" on public.family_medical_cards;
create policy "family_medical_cards_select_member"
on public.family_medical_cards
for select
to authenticated
using (public.is_member_of_family(family_id));

drop policy if exists "family_medical_cards_insert_own" on public.family_medical_cards;
create policy "family_medical_cards_insert_own"
on public.family_medical_cards
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_member_of_family(family_id)
);

drop policy if exists "family_medical_cards_update_own" on public.family_medical_cards;
create policy "family_medical_cards_update_own"
on public.family_medical_cards
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and public.is_member_of_family(family_id));

drop policy if exists "family_medical_cards_delete_own" on public.family_medical_cards;
create policy "family_medical_cards_delete_own"
on public.family_medical_cards
for delete
to authenticated
using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Birthday reminders (month/day; not full DOB required)
-- ---------------------------------------------------------------------------

create table if not exists public.family_birthday_reminders (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families (id) on delete cascade,
  created_by uuid not null references auth.users (id) on delete cascade,
  person_name text not null,
  month int not null check (month between 1 and 12),
  day int not null check (day between 1 and 31),
  notify_days_before int not null default 3 check (notify_days_before >= 0 and notify_days_before <= 60),
  created_at timestamptz not null default now()
);

create index if not exists family_birthday_reminders_family_id_idx
  on public.family_birthday_reminders (family_id);

alter table public.family_birthday_reminders enable row level security;

drop policy if exists "family_birthday_reminders_select_member" on public.family_birthday_reminders;
create policy "family_birthday_reminders_select_member"
on public.family_birthday_reminders
for select
to authenticated
using (public.is_member_of_family(family_id));

drop policy if exists "family_birthday_reminders_insert_member" on public.family_birthday_reminders;
create policy "family_birthday_reminders_insert_member"
on public.family_birthday_reminders
for insert
to authenticated
with check (
  created_by = auth.uid()
  and public.is_member_of_family(family_id)
);

drop policy if exists "family_birthday_reminders_update_creator" on public.family_birthday_reminders;
create policy "family_birthday_reminders_update_creator"
on public.family_birthday_reminders
for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid() and public.is_member_of_family(family_id));

drop policy if exists "family_birthday_reminders_delete_creator" on public.family_birthday_reminders;
create policy "family_birthday_reminders_delete_creator"
on public.family_birthday_reminders
for delete
to authenticated
using (created_by = auth.uid());

-- ---------------------------------------------------------------------------
-- Care preferences & optional presence (default off)
-- ---------------------------------------------------------------------------

create table if not exists public.family_care_preferences (
  user_id uuid not null references auth.users (id) on delete cascade,
  family_id uuid not null references public.families (id) on delete cascade,
  gentle_radar_enabled boolean not null default false,
  share_care_presence boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, family_id)
);

alter table public.family_care_preferences enable row level security;

drop policy if exists "family_care_preferences_select_own" on public.family_care_preferences;
create policy "family_care_preferences_select_own"
on public.family_care_preferences
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "family_care_preferences_insert_own" on public.family_care_preferences;
create policy "family_care_preferences_insert_own"
on public.family_care_preferences
for insert
to authenticated
with check (user_id = auth.uid() and public.is_member_of_family(family_id));

drop policy if exists "family_care_preferences_update_own" on public.family_care_preferences;
create policy "family_care_preferences_update_own"
on public.family_care_preferences
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and public.is_member_of_family(family_id));

drop policy if exists "family_care_preferences_delete_own" on public.family_care_preferences;
create policy "family_care_preferences_delete_own"
on public.family_care_preferences
for delete
to authenticated
using (user_id = auth.uid());

create table if not exists public.family_care_presence (
  family_id uuid not null references public.families (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  last_care_tab_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

alter table public.family_care_presence enable row level security;

drop policy if exists "family_care_presence_select_member" on public.family_care_presence;
create policy "family_care_presence_select_member"
on public.family_care_presence
for select
to authenticated
using (public.is_member_of_family(family_id));

drop policy if exists "family_care_presence_upsert_own" on public.family_care_presence;
create policy "family_care_presence_upsert_own"
on public.family_care_presence
for insert
to authenticated
with check (
  user_id = auth.uid()
  and public.is_member_of_family(family_id)
);

drop policy if exists "family_care_presence_update_own" on public.family_care_presence;
create policy "family_care_presence_update_own"
on public.family_care_presence
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and public.is_member_of_family(family_id));

drop policy if exists "family_care_presence_delete_own" on public.family_care_presence;
create policy "family_care_presence_delete_own"
on public.family_care_presence
for delete
to authenticated
using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Storage: voice messages
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit)
values ('family_voice_messages', 'family_voice_messages', false, 20971520)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit;

drop policy if exists "voice_messages_select_member" on storage.objects;
create policy "voice_messages_select_member"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'family_voice_messages'
  and public.is_member_of_family((split_part(name, '/', 1))::uuid)
);

drop policy if exists "voice_messages_insert_own" on storage.objects;
create policy "voice_messages_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'family_voice_messages'
  and split_part(name, '/', 2) = auth.uid()::text
  and public.is_member_of_family((split_part(name, '/', 1))::uuid)
);

drop policy if exists "voice_messages_delete_own" on storage.objects;
create policy "voice_messages_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'family_voice_messages'
  and split_part(name, '/', 2) = auth.uid()::text
  and public.is_member_of_family((split_part(name, '/', 1))::uuid)
);
