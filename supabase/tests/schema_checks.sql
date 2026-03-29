-- Family App — Supabase schema / policy regression checks
--
-- Expected shape matches supabase/schema.sql and mobile/lib/supabase/* repositories.
--
-- How to run:
--   • Supabase Dashboard → SQL Editor → paste and run
--   • Cursor Supabase MCP: execute_sql with this file contents
--   • psql: psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/schema_checks.sql
--
-- Interpretation:
--   failed_count = 0  → all checks passed
--   failed_count > 0  → see details JSON array (check_id + detail)

WITH
  exp_tables AS (
    SELECT unnest(ARRAY[
      'families', 'family_members', 'daily_questions', 'daily_answers', 'family_photos',
      'family_photo_likes', 'family_photo_comments'
    ]) AS t
  ),
  missing_tables AS (
    SELECT
      'missing_table_' || e.t AS check_id,
      format('public.%I does not exist', e.t) AS detail
    FROM exp_tables e
    WHERE NOT EXISTS (
      SELECT 1
      FROM information_schema.tables x
      WHERE x.table_schema = 'public'
        AND x.table_name = e.t
    )
  ),
  rls_off AS (
    SELECT
      'rls_disabled_' || c.relname AS check_id,
      format('RLS is not enabled on public.%I', c.relname) AS detail
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relkind = 'r'
      AND c.relname IN (
        'families', 'family_members', 'daily_questions', 'daily_answers', 'family_photos',
        'family_photo_likes', 'family_photo_comments'
      )
      AND c.relrowsecurity IS NOT TRUE
  ),
  missing_columns AS (
    SELECT *
    FROM (
      VALUES
        ('families', ARRAY['id', 'name', 'invite_code', 'created_at']),
        ('family_members', ARRAY['family_id', 'user_id', 'role', 'created_at']),
        ('daily_questions', ARRAY['id', 'family_id', 'question_date', 'question_text', 'created_at']),
        ('daily_answers', ARRAY['id', 'question_id', 'user_id', 'author_display_name', 'answer_text', 'image_path', 'created_at']),
        ('family_photos', ARRAY['id', 'family_id', 'user_id', 'caption', 'image_path', 'uploader_display_name', 'created_at']),
        ('family_photo_likes', ARRAY['photo_id', 'user_id', 'created_at']),
        ('family_photo_comments', ARRAY['id', 'photo_id', 'user_id', 'body', 'author_display_name', 'created_at'])
    ) AS spec(tbl, cols)
    CROSS JOIN LATERAL unnest(spec.cols) AS c(col)
    WHERE NOT EXISTS (
      SELECT 1
      FROM information_schema.columns x
      WHERE x.table_schema = 'public'
        AND x.table_name = spec.tbl
        AND x.column_name = c.col
    )
  ),
  missing_columns_flat AS (
    SELECT
      format('missing_column_%s_%s', tbl, col) AS check_id,
      format('public.%I is missing column %I', tbl, col) AS detail
    FROM missing_columns
  ),
  missing_functions AS (
    SELECT
      'missing_function_' || f.fn AS check_id,
      format('public.%I() not found', f.fn) AS detail
    FROM (VALUES
      ('join_family_by_code'),
      ('is_member_of_family'),
      ('is_question_in_my_family'),
      ('is_photo_in_my_family'),
      ('_trg_families_add_creator_as_owner')
    ) AS f(fn)
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.proname = f.fn
    )
  ),
  missing_family_insert_trigger AS (
    SELECT
      'missing_trigger_families_add_creator_as_owner' AS check_id,
      'after insert trigger families_add_creator_as_owner on public.families is missing' AS detail
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_trigger t
      JOIN pg_class c ON c.oid = t.tgrelid
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname = 'families'
        AND NOT t.tgisinternal
        AND t.tgname = 'families_add_creator_as_owner'
    )
  ),
  missing_views AS (
    SELECT
      'missing_view_family_photos_with_counts' AS check_id,
      'public.family_photos_with_counts view is missing' AS detail
    WHERE NOT EXISTS (
      SELECT 1
      FROM information_schema.views v
      WHERE v.table_schema = 'public'
        AND v.table_name = 'family_photos_with_counts'
    )
  ),
  join_rpc_not_granted AS (
    SELECT
      'join_family_by_code_not_executable_by_authenticated' AS check_id,
      'role authenticated cannot EXECUTE public.join_family_by_code(text)' AS detail
    WHERE NOT has_function_privilege(
      'authenticated',
      'public.join_family_by_code(text)',
      'EXECUTE'
    )
  ),
  storage_bucket AS (
    SELECT
      'storage_bucket_family_answer_images' AS check_id,
      'storage.buckets row id=family_answer_images missing, not public, or wrong size limit' AS detail
    WHERE NOT EXISTS (
      SELECT 1
      FROM storage.buckets b
      WHERE b.id = 'family_answer_images'
        AND b.public IS TRUE
        AND b.file_size_limit = 10485760
    )
  ),
  storage_bucket_album AS (
    SELECT
      'storage_bucket_family_album_images' AS check_id,
      'storage.buckets row id=family_album_images missing, not public, or wrong size limit' AS detail
    WHERE NOT EXISTS (
      SELECT 1
      FROM storage.buckets b
      WHERE b.id = 'family_album_images'
        AND b.public IS TRUE
        AND b.file_size_limit = 10485760
    )
  ),
  storage_policies AS (
    SELECT *
    FROM (VALUES
      ('answer_images_select_member'),
      ('answer_images_insert_own'),
      ('answer_images_delete_own')
    ) AS p(name)
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_policies pol
      WHERE pol.schemaname = 'storage'
        AND pol.tablename = 'objects'
        AND pol.policyname = p.name
    )
  ),
  storage_policies_flat AS (
    SELECT
      'missing_storage_policy_' || name AS check_id,
      format('storage.objects policy %I missing', name) AS detail
    FROM storage_policies
  ),
  storage_policies_album AS (
    SELECT *
    FROM (VALUES
      ('album_images_select_member'),
      ('album_images_insert_own'),
      ('album_images_delete_own')
    ) AS p(name)
    WHERE NOT EXISTS (
      SELECT 1
      FROM pg_policies pol
      WHERE pol.schemaname = 'storage'
        AND pol.tablename = 'objects'
        AND pol.policyname = p.name
    )
  ),
  storage_policies_album_flat AS (
    SELECT
      'missing_storage_policy_' || name AS check_id,
      format('storage.objects policy %I missing', name) AS detail
    FROM storage_policies_album
  ),
  failures AS (
    SELECT * FROM missing_tables
    UNION ALL SELECT * FROM rls_off
    UNION ALL SELECT * FROM missing_columns_flat
    UNION ALL SELECT * FROM missing_functions
    UNION ALL SELECT * FROM missing_family_insert_trigger
    UNION ALL SELECT * FROM missing_views
    UNION ALL SELECT * FROM join_rpc_not_granted
    UNION ALL SELECT * FROM storage_bucket
    UNION ALL SELECT * FROM storage_bucket_album
    UNION ALL SELECT * FROM storage_policies_flat
    UNION ALL SELECT * FROM storage_policies_album_flat
  )
SELECT
  (SELECT count(*)::int FROM failures) AS failed_count,
  coalesce(
    (SELECT json_agg(json_build_object('check_id', check_id, 'detail', detail) ORDER BY check_id) FROM failures),
    '[]'::json
  ) AS details;
