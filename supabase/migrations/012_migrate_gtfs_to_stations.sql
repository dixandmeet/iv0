-- Migration gtfs_stops → stations + stops + gtfs_stop_mapping

DO $$
DECLARE
    v_network_id UUID;
BEGIN
    SELECT id INTO v_network_id FROM public.networks WHERE code = 'naolib-nantes' LIMIT 1;
    IF v_network_id IS NULL THEN
        RAISE EXCEPTION 'Réseau naolib-nantes introuvable — exécuter 011 d''abord';
    END IF;

    -- -----------------------------------------------------------------------
    -- 1. Stations : une par nom normalisé (arrêts physiques + parents pour noms)
    -- -----------------------------------------------------------------------
    INSERT INTO public.stations (
        network_id, name, commune, latitude_center, longitude_center, status, updated_by
    )
    SELECT DISTINCT ON (public.normalize_station_name(gs.stop_name))
        v_network_id,
        gs.stop_name,
        COALESCE(gs.commune, 'Nantes'),
        ST_Y(gs.geom::geometry),
        ST_X(gs.geom::geometry),
        COALESCE(gs.status, 'active'),
        gs.updated_by
    FROM public.gtfs_stops gs
    WHERE COALESCE(gs.location_type, 0) = 0
    ORDER BY public.normalize_station_name(gs.stop_name), gs.stop_id
    ON CONFLICT (network_id, name_normalized) DO NOTHING;

    -- Enrichir centres avec parents GTFS (location_type = 1)
    UPDATE public.stations st
    SET
        latitude_center = COALESCE(ST_Y(parent.geom::geometry), st.latitude_center),
        longitude_center = COALESCE(ST_X(parent.geom::geometry), st.longitude_center)
    FROM public.gtfs_stops parent
    WHERE COALESCE(parent.location_type, 0) = 1
      AND public.normalize_station_name(parent.stop_name) = st.name_normalized
      AND st.network_id = v_network_id;

    -- Recentrer sur centroïde des arrêts physiques si pas de parent
    UPDATE public.stations st
    SET
        latitude_center = sub.centroid_lat,
        longitude_center = sub.centroid_lng
    FROM (
        SELECT
            public.normalize_station_name(gs.stop_name) AS nn,
            AVG(ST_Y(gs.geom::geometry)) AS centroid_lat,
            AVG(ST_X(gs.geom::geometry)) AS centroid_lng
        FROM public.gtfs_stops gs
        WHERE COALESCE(gs.location_type, 0) = 0
        GROUP BY public.normalize_station_name(gs.stop_name)
    ) sub
    WHERE st.name_normalized = sub.nn
      AND st.network_id = v_network_id
      AND (st.latitude_center IS NULL OR st.longitude_center IS NULL);

    -- -----------------------------------------------------------------------
    -- 2. Stops : arrêts physiques uniquement (location_type != 1)
    -- -----------------------------------------------------------------------
    INSERT INTO public.stops (
        network_id,
        station_id,
        code,
        source,
        gtfs_source_id,
        name,
        latitude,
        longitude,
        geom,
        platform,
        transport_mode,
        is_accessible,
        status,
        address,
        tariff_zone,
        updated_by
    )
    SELECT
        v_network_id,
        st.id,
        gs.stop_id,
        'gtfs'::public.stop_source,
        gs.stop_id,
        gs.stop_name,
        ST_Y(gs.geom::geometry),
        ST_X(gs.geom::geometry),
        gs.geom,
        NULL,
        CASE
            WHEN gs.transport_modes @> ARRAY['tram']::TEXT[] THEN 'tram'::public.stop_transport_mode
            WHEN gs.transport_modes @> ARRAY['train']::TEXT[] THEN 'train'::public.stop_transport_mode
            WHEN gs.transport_modes @> ARRAY['navibus']::TEXT[] THEN 'ferry'::public.stop_transport_mode
            WHEN gs.transport_modes @> ARRAY['metro']::TEXT[] THEN 'metro'::public.stop_transport_mode
            ELSE 'bus'::public.stop_transport_mode
        END,
        COALESCE(gs.wheelchair_boarding, 0) = 1,
        COALESCE(gs.status, 'active'),
        gs.address,
        gs.tariff_zone,
        gs.updated_by
    FROM public.gtfs_stops gs
    JOIN public.stations st
        ON st.network_id = v_network_id
       AND st.name_normalized = public.normalize_station_name(gs.stop_name)
    WHERE COALESCE(gs.location_type, 0) = 0
    ON CONFLICT (network_id, code) DO NOTHING;

    -- -----------------------------------------------------------------------
    -- 3. Mapping GTFS
    -- -----------------------------------------------------------------------
    INSERT INTO public.gtfs_stop_mapping (network_id, gtfs_stop_id, stop_id)
    SELECT v_network_id, s.code, s.id
    FROM public.stops s
    WHERE s.network_id = v_network_id
      AND s.source = 'gtfs'
    ON CONFLICT DO NOTHING;

    -- -----------------------------------------------------------------------
    -- 4. Audit logs : lier stop_uuid
    -- -----------------------------------------------------------------------
    UPDATE public.stop_audit_log sal
    SET stop_uuid = s.id
    FROM public.stops s
    WHERE sal.stop_id = s.code
      AND sal.stop_uuid IS NULL;

END $$;

-- Vérifications (échouent si incohérence)
DO $$
DECLARE
    v_dup INTEGER;
    v_orphan INTEGER;
    v_mapping INTEGER;
    v_gtfs INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_dup
    FROM (
        SELECT network_id, name_normalized, COUNT(*) AS c
        FROM public.stations
        GROUP BY 1, 2
        HAVING COUNT(*) > 1
    ) x;
    IF v_dup > 0 THEN
        RAISE EXCEPTION 'Migration invalide : % doublons de station', v_dup;
    END IF;

    SELECT COUNT(*) INTO v_orphan FROM public.stops WHERE station_id IS NULL;
    IF v_orphan > 0 THEN
        RAISE EXCEPTION 'Migration invalide : % arrêts sans station', v_orphan;
    END IF;

    SELECT COUNT(*) INTO v_mapping FROM public.gtfs_stop_mapping;
    SELECT COUNT(*) INTO v_gtfs FROM public.stops WHERE source = 'gtfs';
    IF v_mapping <> v_gtfs THEN
        RAISE EXCEPTION 'Migration invalide : mapping % != stops gtfs %', v_mapping, v_gtfs;
    END IF;
END $$;
