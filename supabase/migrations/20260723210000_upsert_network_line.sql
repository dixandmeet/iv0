-- Persistance serveur des éditions de lignes (GTFS incluses).
-- Jusqu'ici seule save_line_editor_state existait, en UPDATE seul : elle échoue
-- pour une ligne GTFS qui n'a pas encore de row dans network_lines. Cette RPC
-- fait un upsert et reste ouverte aux superviseurs/régulateurs (comme
-- save_line_editor_state et publish_line_trace), afin qu'une édition de tracé
-- soit partagée entre tous les supports (dashboard web + app mobile).

CREATE OR REPLACE FUNCTION public.upsert_network_line(
    p_line_id text,
    p_short_name text,
    p_long_name text,
    p_transport_mode text,
    p_color text,
    p_source text,
    p_data jsonb,
    p_editor_state jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_network_id UUID := public.current_network_id();
BEGIN
    IF NULLIF(BTRIM(p_line_id), '') IS NULL THEN
        RAISE EXCEPTION 'Identifiant de ligne requis';
    END IF;

    IF v_network_id IS NULL OR NOT (
        public.can_manage_network(v_network_id)
        OR (
            public.can_access_network(v_network_id)
            AND public.has_role(ARRAY['msr_supervisor', 'regulator', 'admin'])
        )
    ) THEN
        RAISE EXCEPTION 'Accès à l''enregistrement de la ligne refusé';
    END IF;

    INSERT INTO public.network_lines (
        network_id, line_id, short_name, long_name,
        transport_mode, color, source, data, editor_state,
        created_by, updated_at
    )
    VALUES (
        v_network_id,
        BTRIM(p_line_id),
        COALESCE(NULLIF(BTRIM(p_short_name), ''), BTRIM(p_line_id)),
        p_long_name,
        COALESCE(NULLIF(p_transport_mode, ''), 'bus'),
        COALESCE(NULLIF(p_color, ''), '#2563EB'),
        COALESCE(NULLIF(p_source, ''), 'manual'),
        COALESCE(p_data, '{}'::jsonb),
        p_editor_state,
        auth.uid(),
        NOW()
    )
    ON CONFLICT (network_id, line_id) DO UPDATE SET
        short_name = EXCLUDED.short_name,
        long_name = EXCLUDED.long_name,
        transport_mode = EXCLUDED.transport_mode,
        color = EXCLUDED.color,
        source = EXCLUDED.source,
        data = EXCLUDED.data,
        editor_state = EXCLUDED.editor_state,
        updated_at = NOW();
END;
$function$;

GRANT EXECUTE ON FUNCTION public.upsert_network_line(
    text, text, text, text, text, text, jsonb, jsonb
) TO authenticated;
