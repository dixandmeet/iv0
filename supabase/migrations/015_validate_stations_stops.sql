-- Jeu de validation post-migration stations/stops (exécuter manuellement)
-- Attendu : 0 ligne sur les doublons, comptages cohérents, cas Ranzay = 4-5 arrêts

-- Unicité stations par réseau
SELECT network_id, name_normalized, COUNT(*)
FROM stations
GROUP BY 1, 2
HAVING COUNT(*) > 1;

-- Arrêts orphelins
SELECT COUNT(*) FROM stops WHERE station_id IS NULL;

-- Couverture migration GTFS opérationnels
SELECT
  (SELECT COUNT(*) FROM gtfs_stops WHERE location_type != 1) AS gtfs_operational,
  (SELECT COUNT(*) FROM stops WHERE source = 'gtfs') AS stops_gtfs,
  (SELECT COUNT(*) FROM gtfs_stop_mapping) AS mappings;

-- Jeu de validation nommé
SELECT s.name, COUNT(st.id) AS stop_count
FROM stations s
LEFT JOIN stops st ON st.station_id = s.id
WHERE s.name_normalized IN (
  normalize_station_name('Ranzay'),
  normalize_station_name('Commerce'),
  normalize_station_name('Gare Nord'),
  normalize_station_name('Gare Sud'),
  normalize_station_name('Pirmil'),
  normalize_station_name('Duchesse Anne'),
  normalize_station_name('Hôtel Dieu')
)
GROUP BY s.id, s.name
ORDER BY s.name;
