-- Phase E1: application profiles for authenticated users.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('operator', 'supervisor', 'admin')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.profiles is
  'Application profile per authenticated user, including the role used by the app.';

alter table public.profiles enable row level security;
