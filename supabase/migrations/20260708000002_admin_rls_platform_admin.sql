-- Admin sans clé service_role : autorise les écritures via la session admin
-- authentifiée (is_aule_platform_admin), en complément des policies existantes.
-- Prérequis : 20260708_admin_control_center.sql et 20260708_pro_multi_profile_access.sql

drop policy if exists profiles_admin_all on public.user_profiles;
create policy profiles_admin_all on public.user_profiles
  for all to authenticated
  using (public.is_aule_platform_admin())
  with check (public.is_aule_platform_admin());

drop policy if exists "profile_assignments_admin_all" on public.profile_assignments;
create policy "profile_assignments_admin_all"
  on public.profile_assignments
  for all
  using (public.is_aule_platform_admin())
  with check (public.is_aule_platform_admin());

drop policy if exists "permission_overrides_admin_all" on public.user_permission_overrides;
create policy "permission_overrides_admin_all"
  on public.user_permission_overrides
  for all
  using (public.is_aule_platform_admin())
  with check (public.is_aule_platform_admin());

drop policy if exists "aule_admin_audit_logs_admin_insert" on public.aule_admin_audit_logs;
create policy "aule_admin_audit_logs_admin_insert"
  on public.aule_admin_audit_logs
  for insert
  with check (public.is_aule_platform_admin());
