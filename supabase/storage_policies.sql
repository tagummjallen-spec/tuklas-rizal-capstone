-- ============================================================================
-- supabase/storage_policies.sql
-- TuklasRizal — Supabase Storage for tourism photography
--
-- Creates the public `tourism-media` bucket and its access policies.
-- Idempotent: safe to re-run from the Supabase SQL Editor or the CLI.
--
-- Folder convention (enforced by the apps, not the bucket):
--   tourism-media/events/<uuid>.jpg
--   tourism-media/pois/<uuid>.jpg
--
-- Public read lets the mobile app render gallery images without a session.
-- Writes require an authenticated LGU account; the web admin and mobile app
-- both upload while signed in. There is no service-role key in either client.
-- ============================================================================

-- 1. Public bucket -----------------------------------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'tourism-media',
  'tourism-media',
  true,
  5242880, -- 5 MB per image
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Policies ---------------------------------------------------------------
-- Drop-then-create keeps the script idempotent (CREATE POLICY has no IF NOT EXISTS).
DROP POLICY IF EXISTS "tourism_media_public_read" ON storage.objects;
CREATE POLICY "tourism_media_public_read" ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'tourism-media');

DROP POLICY IF EXISTS "tourism_media_auth_insert" ON storage.objects;
CREATE POLICY "tourism_media_auth_insert" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'tourism-media');

DROP POLICY IF EXISTS "tourism_media_auth_update" ON storage.objects;
CREATE POLICY "tourism_media_auth_update" ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'tourism-media')
  WITH CHECK (bucket_id = 'tourism-media');

DROP POLICY IF EXISTS "tourism_media_auth_delete" ON storage.objects;
CREATE POLICY "tourism_media_auth_delete" ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'tourism-media');

-- 3. Verification -----------------------------------------------------------
SELECT id, name, public, file_size_limit, allowed_mime_types
FROM storage.buckets
WHERE id = 'tourism-media';
