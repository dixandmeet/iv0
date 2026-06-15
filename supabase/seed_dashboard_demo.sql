-- Données de démonstration pour le poste de contrôle Aule
-- À exécuter après les migrations 001–006 et seed_tan.sql
-- Usage : psql $DATABASE_URL -f supabase/seed_dashboard_demo.sql

BEGIN;

-- Nettoyage idempotent des données demo précédentes
DELETE FROM live_fleet_positions
WHERE route_id IN ('1', '2', '3', 'C4', 'C6', 'C20', '10', '26')
  AND source IN ('driver', 'community', 'operator');

DELETE FROM network_incidents
WHERE title IN (
  'Affluence anormale — Commerce',
  'Retard récurrent ligne C4',
  'Incident critique — Gare Nord'
);

DELETE FROM msr_missions
WHERE zone_config->>'demo' = 'true';

-- Flotte live (~8 véhicules autour de Nantes)
INSERT INTO live_fleet_positions (
  route_id, trip_id, transport_type, geom, speed, heading,
  source, source_confidence, reliability_score, freshness_seconds,
  coherence_score, estimated_delay_seconds, last_seen_at
) VALUES
  ('1', NULL, 'tram',
   ST_SetSRID(ST_MakePoint(-1.5536, 47.2184), 4326),
   28, 45, 'driver', 100, 92, 12, 88, 0, NOW() - INTERVAL '12 seconds'),
  ('2', NULL, 'tram',
   ST_SetSRID(ST_MakePoint(-1.5620, 47.2120), 4326),
   22, 120, 'driver', 100, 88, 25, 85, 180, NOW() - INTERVAL '25 seconds'),
  ('3', NULL, 'tram',
   ST_SetSRID(ST_MakePoint(-1.5480, 47.2250), 4326),
   30, 270, 'operator', 95, 85, 45, 80, 0, NOW() - INTERVAL '45 seconds'),
  ('C4', NULL, 'bus',
   ST_SetSRID(ST_MakePoint(-1.5350, 47.2480), 4326),
   35, 180, 'community', 72, 68, 90, 65, 420, NOW() - INTERVAL '90 seconds'),
  ('C6', NULL, 'bus',
   ST_SetSRID(ST_MakePoint(-1.5700, 47.2300), 4326),
   40, 90, 'driver', 100, 94, 8, 90, 0, NOW() - INTERVAL '8 seconds'),
  ('C20', NULL, 'bus',
   ST_SetSRID(ST_MakePoint(-1.5450, 47.2100), 4326),
   18, 315, 'community', 55, 52, 180, 60, 600, NOW() - INTERVAL '180 seconds'),
  ('10', NULL, 'bus',
   ST_SetSRID(ST_MakePoint(-1.5580, 47.2350), 4326),
   32, 200, 'operator', 95, 78, 60, 75, 120, NOW() - INTERVAL '60 seconds'),
  ('26', NULL, 'bus',
   ST_SetSRID(ST_MakePoint(-1.5400, 47.2200), 4326),
   25, 150, 'driver', 100, 91, 15, 87, 0, NOW() - INTERVAL '15 seconds');

-- Incidents réseau (info / warning / critical)
INSERT INTO network_incidents (
  incident_type, severity, status, title, description,
  route_id, geom, source
) VALUES
  ('crowding', 'info', 'open',
   'Affluence anormale — Commerce',
   'Pic de fréquentation signalé à l''arrêt Commerce, tram 1.',
   '1',
   ST_SetSRID(ST_MakePoint(-1.5608, 47.2134), 4326),
   'community'),
  ('delay', 'warning', 'acknowledged',
   'Retard récurrent ligne C4',
   'Retard moyen de 7 min observé sur le tronçon Gare Nord → Greneraie.',
   'C4',
   ST_SetSRID(ST_MakePoint(-1.5378, 47.2438), 4326),
   'system'),
  ('disruption', 'critical', 'in_progress',
   'Incident critique — Gare Nord',
   'Panne signalée au niveau de la gare, perturbation majeure attendue.',
   NULL,
   ST_SetSRID(ST_MakePoint(-1.5414, 47.2369), 4326),
   'regulator');

-- Missions MSR de démonstration
INSERT INTO msr_missions (
  zone_type, zone_config, status, started_at
) VALUES
  ('sector', '{"sector_id": "centre-ville", "label": "Centre-ville", "demo": "true"}'::jsonb,
   'in_progress', NOW() - INTERVAL '45 minutes'),
  ('line_buffer', '{"route_id": "C4", "buffer_m": 150, "demo": "true"}'::jsonb,
   'assigned', NULL);

COMMIT;
