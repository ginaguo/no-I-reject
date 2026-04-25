-- Ensure user data is deleted when an auth user is deleted.
-- Run this in the Supabase SQL Editor (Dashboard → SQL → New query).
-- Safe to run multiple times.

-- ============================================================
-- moments
-- ============================================================
ALTER TABLE public.moments
  DROP CONSTRAINT IF EXISTS moments_user_id_fkey;

ALTER TABLE public.moments
  ADD CONSTRAINT moments_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

-- ============================================================
-- user_focus
-- ============================================================
ALTER TABLE public.user_focus
  DROP CONSTRAINT IF EXISTS user_focus_user_id_fkey;

ALTER TABLE public.user_focus
  ADD CONSTRAINT user_focus_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

-- ============================================================
-- user_custom_tags
-- ============================================================
ALTER TABLE public.user_custom_tags
  DROP CONSTRAINT IF EXISTS user_custom_tags_user_id_fkey;

ALTER TABLE public.user_custom_tags
  ADD CONSTRAINT user_custom_tags_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

-- Verify (optional): list FKs
-- SELECT conname, conrelid::regclass, confdeltype
-- FROM pg_constraint
-- WHERE conname LIKE '%user_id_fkey' AND connamespace = 'public'::regnamespace;
