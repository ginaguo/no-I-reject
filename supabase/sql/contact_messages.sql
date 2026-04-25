-- Run once in Supabase SQL Editor.
create table if not exists public.contact_messages (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name       text,
  email      text,
  message    text not null,
  user_agent text,
  ip         text
);

-- RLS: nobody can read/write through the public API; only the service role
-- (used by our Edge Function) can insert. You read messages via the dashboard.
alter table public.contact_messages enable row level security;
-- Intentionally NO policies — RLS denies by default, which is what we want.
