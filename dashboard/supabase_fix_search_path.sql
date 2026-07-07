-- Corrige l'avertissement "Function Search Path Mutable" du linter Supabase
-- pour toutes les fonctions signalées, en s'appuyant sur pg_proc pour
-- retrouver la signature exacte de chaque fonction (gère les surcharges,
-- ex. get_nearby_stops qui a deux variantes).
--
-- A exécuter sur le projet Supabase live (SQL editor du dashboard, ou psql).
-- Idempotent : peut être rejoué sans risque.

do $$
declare
  fn record;
  target_names text[] := array[
    'aggregate_community_vehicles',
    'assert_driver_manager',
    'compute_reliability_score',
    'current_user_role',
    'get_nearby_stops',
    'get_station_detail',
    'get_stop_departures',
    'handle_new_auth_user',
    'has_role',
    'is_staff',
    'log_incident_action',
    'match_probable_trip',
    'msr_plan_patrol',
    'normalize_station_name',
    'process_incident_rules',
    'refresh_live_fleet_positions',
    'search_stations',
    'start_driver_session_auto',
    'touch_gtfs_stop_updated_at',
    'touch_station_name_normalized',
    'touch_stop_geom',
    'trg_process_incident_rules',
    'my_driver_access_status',
    'mission_reference_code',
    'detect_probable_route',
    'purge_old_user_locations',
    'list_pending_driver_access_requests',
    'claim_driver_access',
    'touch_updated_at',
    'current_driver_id',
    'promote_profile_to_driver',
    'control_mission_preview_json',
    'control_mission_full_json',
    'submit_driver_registration_request',
    'find_user_by_email_for_driver',
    'add_or_promote_driver',
    'review_driver_registration_request',
    'list_pending_driver_requests',
    'list_registered_drivers',
    'get_stops_served_routes',
    'compute_coherence_for_position',
    'msr_build_line_buffer',
    'check_driver_matricule',
    'review_driver_access_request',
    'current_driver_is_control',
    'search_team_agents',
    'resolve_gtfs_stop_id',
    'se_deduce_required_habilitation',
    'control_team_schedule_bounds',
    'get_stop_serving_lines'
  ];
begin
  for fn in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any(target_names)
  loop
    execute format('alter function %s set search_path = public, pg_temp', fn.sig);
    raise notice 'Fixed search_path for %', fn.sig;
  end loop;
end $$;
