-- Aule Admin — centre de contrôle opérationnel.
-- Tables génériques et configurables pour administrer réseaux, dépôts,
-- marketplace, exploitation et rôles sans recoder l'application.

create table if not exists public.aule_admin_resources (
  id uuid primary key default gen_random_uuid(),
  resource_type text not null,
  name text not null,
  status text not null default 'active',
  network_id uuid null,
  depot_id uuid null,
  owner_user_id uuid null references auth.users (id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint aule_admin_resources_type_check check (
    resource_type in (
      'network',
      'depot',
      'line',
      'stop',
      'station',
      'vehicle',
      'traveler',
      'driver',
      'controller',
      'operations_agent',
      'vtc_driver',
      'merchant',
      'product',
      'order',
      'promotion',
      'delivery',
      'incident',
      'mission',
      'announcement',
      'integration',
      'api_key',
      'storage_bucket',
      'monitor'
    )
  )
);

create index if not exists idx_aule_admin_resources_type
  on public.aule_admin_resources (resource_type);

create index if not exists idx_aule_admin_resources_network
  on public.aule_admin_resources (network_id);

create table if not exists public.aule_admin_roles (
  id uuid primary key default gen_random_uuid(),
  role_key text not null unique,
  label text not null,
  description text null,
  permissions text[] not null default '{}',
  restrictions jsonb not null default '{}'::jsonb,
  scope jsonb not null default '{}'::jsonb,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.aule_admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid null references auth.users (id) on delete set null,
  action text not null,
  resource_type text not null,
  resource_id text null,
  before_state jsonb null,
  after_state jsonb null,
  created_at timestamptz not null default now()
);

create or replace function public.set_aule_admin_updated_at()
  returns trigger
  language plpgsql
  set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_aule_admin_resources_updated_at on public.aule_admin_resources;
create trigger trg_aule_admin_resources_updated_at
  before update on public.aule_admin_resources
  for each row
  execute function public.set_aule_admin_updated_at();

drop trigger if exists trg_aule_admin_roles_updated_at on public.aule_admin_roles;
create trigger trg_aule_admin_roles_updated_at
  before update on public.aule_admin_roles
  for each row
  execute function public.set_aule_admin_updated_at();

create or replace function public.is_aule_platform_admin()
  returns boolean
  language sql
  stable
  security definer
  set search_path = public
as $$
  select exists (
    select 1
    from public.user_profiles up
    where up.id = auth.uid()
      and up.role = 'admin'
  )
  or exists (
    select 1
    from public.profile_assignments pa
    where pa.user_id = auth.uid()
      and pa.is_active = true
      and pa.profile_key in ('admin', 'platform_admin', 'super_admin')
  );
$$;

alter table public.aule_admin_resources enable row level security;
alter table public.aule_admin_roles enable row level security;
alter table public.aule_admin_audit_logs enable row level security;

drop policy if exists "aule_admin_resources_admin_all" on public.aule_admin_resources;
create policy "aule_admin_resources_admin_all"
  on public.aule_admin_resources
  for all
  using (public.is_aule_platform_admin())
  with check (public.is_aule_platform_admin());

drop policy if exists "aule_admin_roles_admin_all" on public.aule_admin_roles;
create policy "aule_admin_roles_admin_all"
  on public.aule_admin_roles
  for all
  using (public.is_aule_platform_admin())
  with check (public.is_aule_platform_admin());

drop policy if exists "aule_admin_audit_logs_admin_select" on public.aule_admin_audit_logs;
create policy "aule_admin_audit_logs_admin_select"
  on public.aule_admin_audit_logs
  for select
  using (public.is_aule_platform_admin());

insert into public.aule_admin_roles (role_key, label, description, permissions, restrictions, scope, is_system)
values
  ('driver', 'Conducteur', 'Espace conducteur Aule Pro', array['driver.take_service','driver.services','driver.vehicle','driver.assistant','driver.service_exchange','driver.history'], '{"hidden":["admin.*","ops.*","commerce.*"]}'::jsonb, '{"network":true,"depot":true}'::jsonb, true),
  ('controller', 'Contrôleur', 'Contrôle terrain et procès-verbaux', array['control.missions','control.map_ops','control.controls','control.penalties','control.team','control.personal_stats'], '{"hidden":["admin.*","commerce.*"]}'::jsonb, '{"network":true,"mission_zone":true}'::jsonb, true),
  ('operations', 'Agent exploitation', 'Centre exploitation réseau', array['ops.network_view','ops.fleet_tracking','ops.missions_manage','ops.announcements','ops.disruptions','ops.notifications','ops.incidents','ops.teams','ops.stats'], '{"hidden":["admin.roles","admin.backups","admin.storage"]}'::jsonb, '{"network":true,"depot":true}'::jsonb, true),
  ('vtc', 'Chauffeur VTC', 'Mobilité à la demande', array['vtc.rides','vtc.availability','vtc.history','vtc.earnings','vtc.schedule','vtc.stats','vtc.messaging'], '{"hidden":["ops.*","admin.*","commerce.*"]}'::jsonb, '{"network":true}'::jsonb, true),
  ('merchant', 'Commerçant', 'Gestion boutique marketplace', array['commerce.store','commerce.catalog','commerce.orders','commerce.promotions','commerce.hours','commerce.deliveries','commerce.reviews','commerce.employees','commerce.stats'], '{"hidden":["ops.*","driver.*","admin.*"]}'::jsonb, '{"merchant_id":true}'::jsonb, true),
  ('platform_admin', 'Administrateur Aule', 'Administration interne Aule', array['admin.dashboard','admin.supervision','admin.networks','admin.users','admin.marketplace','admin.analytics','admin.permissions','admin.roles','admin.apis','admin.logs','admin.backups','admin.communications','admin.storage','admin.monitoring','admin.integrations'], '{}'::jsonb, '{"platform":true}'::jsonb, true)
on conflict (role_key) do update set
  label = excluded.label,
  description = excluded.description,
  permissions = excluded.permissions,
  restrictions = excluded.restrictions,
  scope = excluded.scope,
  is_system = excluded.is_system;
