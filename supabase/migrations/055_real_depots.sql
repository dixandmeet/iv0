-- ===========================================================================
-- 055 — Dépôts réels Naolib (Semitan) : BLX / TTX / SHX
-- ===========================================================================
-- La table `depots` ne contenait que des entrées indicatives
-- (chantenay / haluchere / pirmil), jamais référencées. Tout l'écosystème
-- (roster `default_depot`, services, échange de services) raisonne en codes
-- BLX / TTX / SHX. On installe ces dépôts pour que `drivers.depot_id` —
-- renseigné à l'onboarding — pilote directement le matching de l'échange de
-- services (feed `list_service_exchange_feed`, `se_notify_compatible`…), qui
-- filtre par `depot_id`.
--
-- Les coordonnées `geom` sont indicatives (aucune logique « dépôt le plus
-- proche » ne s'appuie dessus aujourd'hui), juste pour satisfaire NOT NULL.
-- ===========================================================================

INSERT INTO public.depots (code, name, geom) VALUES
    ('BLX', 'Le Bêle',     ST_SetSRID(ST_Point(-1.5210, 47.2607), 4326)),
    ('TTX', 'Trentemoult', ST_SetSRID(ST_Point(-1.5650, 47.1925), 4326)),
    ('SHX', 'Semitan',     ST_SetSRID(ST_Point(-1.5440, 47.2240), 4326))
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- Purge des dépôts indicatifs (ON DELETE SET NULL sur toutes les FK).
DELETE FROM public.depots WHERE code IN ('chantenay', 'haluchere', 'pirmil');
