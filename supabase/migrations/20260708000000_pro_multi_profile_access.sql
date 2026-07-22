-- Aule Pro — Socle multi-profils.
-- Passe du modèle mono-rôle (user_profiles.role) à des profils cumulables par
-- utilisateur + overrides de permissions indépendants du profil.
-- Idempotent : réexécutable sans dommage. Backend partagé (rllcdvuqduuyhdcifiwp).

-- ── Profils cumulables ──────────────────────────────────────────────────────
create table if not exists public.profile_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  profile_key text not null,
  context jsonb not null default '{}'::jsonb, -- depot, reseau, zone…
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (user_id, profile_key),
  constraint profile_assignments_profile_key_check check (
    profile_key in (
      'driver',
      'vtc',
      'controller',
      'operations',
      'supervisor',
      'merchant',
      'platform_admin',
      'super_admin',
      'admin'
    )
  )
);

create index if not exists idx_profile_assignments_user
  on public.profile_assignments (user_id);

-- ── Overrides de permissions (grant/révocation individuels) ──────────────────
create table if not exists public.user_permission_overrides (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  permission text not null, -- ex. 'commerce.catalog'
  granted boolean not null default true,
  created_at timestamptz not null default now(),
  unique (user_id, permission)
);

create index if not exists idx_user_permission_overrides_user
  on public.user_permission_overrides (user_id);

-- ── RLS : chacun lit ses propres profils / overrides ─────────────────────────
alter table public.profile_assignments enable row level security;
alter table public.user_permission_overrides enable row level security;

drop policy if exists "profile_assignments_select_own" on public.profile_assignments;
create policy "profile_assignments_select_own"
  on public.profile_assignments for select
  using (auth.uid() = user_id);

drop policy if exists "permission_overrides_select_own" on public.user_permission_overrides;
create policy "permission_overrides_select_own"
  on public.user_permission_overrides for select
  using (auth.uid() = user_id);
-- Écritures réservées au service_role / triggers (aucune policy insert/update).

-- ── Pont role → profil : mapping partagé, backfill + trigger de synchro ──────
create or replace function public.profile_key_for_role(p_role text)
  returns text
  language sql
  immutable
as $$
  select case p_role
    when 'driver' then 'driver'
    when 'msr_agent' then 'controller'
    when 'msr_supervisor' then 'supervisor'
    when 'regulator' then 'operations'
    when 'admin' then 'admin'
    else null
  end;
$$;

-- Backfill des utilisateurs existants (passenger => aucun profil pro).
insert into public.profile_assignments (user_id, profile_key)
select up.id, public.profile_key_for_role(up.role)
from public.user_profiles up
where public.profile_key_for_role(up.role) is not null
on conflict (user_id, profile_key) do nothing;

-- Maintient profile_assignments aligné quand user_profiles.role change/est créé.
-- N'ajoute jamais de profil (ex. merchant ajouté manuellement reste), ne
-- supprime rien : le role reste une source, pas la seule.
create or replace function public.sync_profile_assignment_from_role()
  returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare
  pk text;
begin
  pk := public.profile_key_for_role(new.role);
  if pk is not null then
    insert into public.profile_assignments (user_id, profile_key)
    values (new.id, pk)
    on conflict (user_id, profile_key) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_profile_assignment on public.user_profiles;
create trigger trg_sync_profile_assignment
  after insert or update of role on public.user_profiles
  for each row
  execute function public.sync_profile_assignment_from_role();
