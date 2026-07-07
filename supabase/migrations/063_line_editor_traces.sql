-- Tracés de lignes publiés depuis l'éditeur de ligne du dashboard, consommés par la carte
-- immersive à la place des tracés démo figés de real-line-shapes.json.
-- line_id = shortName de la ligne dans l'éditeur, aligné sur driver_services.line_id /
-- gtfs_routes.route_id (ex. "1", "2", "3") pour rester cohérent avec le réseau réel.

CREATE TABLE public.line_editor_traces (
    line_id TEXT PRIMARY KEY,
    editor_state_id TEXT NOT NULL,
    transport_mode TEXT NOT NULL CHECK (transport_mode IN ('bus', 'tram', 'boat', 'shuttle')),
    color TEXT NOT NULL,
    -- [{ direction: 'aller'|'retour', coordinates: [[lng,lat], ...] }, ...]
    variants JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.publish_line_trace(
    p_line_id TEXT,
    p_editor_state_id TEXT,
    p_transport_mode TEXT,
    p_color TEXT,
    p_variants JSONB
)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    INSERT INTO public.line_editor_traces (line_id, editor_state_id, transport_mode, color, variants, updated_at)
    VALUES (p_line_id, p_editor_state_id, p_transport_mode, p_color, p_variants, now())
    ON CONFLICT (line_id) DO UPDATE SET
        editor_state_id = EXCLUDED.editor_state_id,
        transport_mode = EXCLUDED.transport_mode,
        color = EXCLUDED.color,
        variants = EXCLUDED.variants,
        updated_at = now();
$$;

CREATE OR REPLACE FUNCTION public.unpublish_line_trace(p_line_id TEXT)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    DELETE FROM public.line_editor_traces WHERE line_id = p_line_id;
$$;

CREATE OR REPLACE FUNCTION public.get_published_line_traces()
RETURNS TABLE (
    line_id TEXT,
    transport_mode TEXT,
    color TEXT,
    variants JSONB
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT line_id, transport_mode, color, variants
    FROM public.line_editor_traces;
$$;

REVOKE ALL ON FUNCTION public.publish_line_trace(TEXT, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.unpublish_line_trace(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_published_line_traces() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.publish_line_trace(TEXT, TEXT, TEXT, TEXT, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.unpublish_line_trace(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_published_line_traces() TO anon, authenticated;
