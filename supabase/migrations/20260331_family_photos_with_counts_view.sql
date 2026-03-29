-- Read-only view: album grid can show like/comment counts in one query (RLS via underlying family_photos).

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

grant select on public.family_photos_with_counts to authenticated;
