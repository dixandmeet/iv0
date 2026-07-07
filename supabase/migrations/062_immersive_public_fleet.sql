-- Public, anonymised fleet snapshot for the traveller-facing immersive map.
-- It intentionally exposes no driver, service, session, or internal vehicle ID.

CREATE OR REPLACE FUNCTION public.immersive_fleet_positions(
    p_max_age_seconds INTEGER DEFAULT 120
)
RETURNS TABLE (
    public_id TEXT,
    vehicle_type TEXT,
    route_id TEXT,
    destination TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    recorded_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH latest_positions AS (
        SELECT DISTINCT ON (vp.driver_service_id)
            vp.driver_service_id,
            vp.latitude,
            vp.longitude,
            vp.speed,
            vp.heading,
            vp.created_at
        FROM public.vehicle_positions vp
        WHERE vp.driver_service_id IS NOT NULL
          AND vp.created_at >= NOW() - make_interval(
              secs => GREATEST(0, LEAST(COALESCE(p_max_age_seconds, 120), 300))
          )
          AND vp.latitude BETWEEN -90 AND 90
          AND vp.longitude BETWEEN -180 AND 180
        ORDER BY vp.driver_service_id, vp.created_at DESC
    )
    SELECT
        -- Rotating the opaque key daily prevents long-term public correlation.
        md5(lp.driver_service_id::TEXT || ':' || CURRENT_DATE::TEXT) AS public_id,
        CASE
            WHEN gr.route_type IN (0, 1, 2)
              OR ds.train_number IS NOT NULL
              OR upper(COALESCE(ds.line_id, '')) IN ('1', '2', '3')
                THEN 'tram'
            ELSE 'bus'
        END AS vehicle_type,
        COALESCE(ds.line_id, '') AS route_id,
        ds.headsign AS destination,
        lp.latitude,
        lp.longitude,
        lp.speed,
        lp.heading,
        lp.created_at AS recorded_at
    FROM latest_positions lp
    JOIN public.driver_services ds ON ds.id = lp.driver_service_id
    LEFT JOIN public.gtfs_routes gr ON gr.route_id = ds.line_id
    WHERE ds.status = 'active';
$$;

REVOKE ALL ON FUNCTION public.immersive_fleet_positions(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.immersive_fleet_positions(INTEGER)
    TO anon, authenticated;
