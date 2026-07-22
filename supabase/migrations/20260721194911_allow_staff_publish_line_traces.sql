-- L'éditeur de lignes est accessible aux profils d'exploitation, mais les RPC
-- de publication étaient limitées aux seuls owner/admin du réseau. Autoriser
-- les profils métier habilités, uniquement sur leur réseau actif.

ALTER TABLE public.line_editor_traces ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.line_editor_traces FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.publish_line_trace(
    p_line_id TEXT,
    p_editor_state_id TEXT,
    p_transport_mode TEXT,
    p_color TEXT,
    p_variants JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_network_id UUID := public.current_network_id();
BEGIN
    IF v_network_id IS NULL OR NOT (
        public.can_manage_network(v_network_id)
        OR (
            public.can_access_network(v_network_id)
            AND public.has_role(ARRAY['msr_supervisor', 'regulator', 'admin'])
        )
    ) THEN
        RAISE EXCEPTION 'Accès à la publication des tracés refusé';
    END IF;

    INSERT INTO public.line_editor_traces (
        network_id,
        line_id,
        editor_state_id,
        transport_mode,
        color,
        variants,
        updated_at
    )
    VALUES (
        v_network_id,
        p_line_id,
        p_editor_state_id,
        p_transport_mode,
        p_color,
        p_variants,
        NOW()
    )
    ON CONFLICT (network_id, line_id) DO UPDATE SET
        editor_state_id = EXCLUDED.editor_state_id,
        transport_mode = EXCLUDED.transport_mode,
        color = EXCLUDED.color,
        variants = EXCLUDED.variants,
        updated_at = NOW();
END;
$$;

CREATE OR REPLACE FUNCTION public.unpublish_line_trace(p_line_id TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_network_id UUID := public.current_network_id();
BEGIN
    IF v_network_id IS NULL OR NOT (
        public.can_manage_network(v_network_id)
        OR (
            public.can_access_network(v_network_id)
            AND public.has_role(ARRAY['msr_supervisor', 'regulator', 'admin'])
        )
    ) THEN
        RAISE EXCEPTION 'Accès à la dépublication des tracés refusé';
    END IF;

    DELETE FROM public.line_editor_traces
    WHERE network_id = v_network_id AND line_id = p_line_id;
END;
$$;

REVOKE ALL ON FUNCTION public.publish_line_trace(TEXT, TEXT, TEXT, TEXT, JSONB)
FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unpublish_line_trace(TEXT)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.publish_line_trace(TEXT, TEXT, TEXT, TEXT, JSONB)
TO authenticated;
GRANT EXECUTE ON FUNCTION public.unpublish_line_trace(TEXT)
TO authenticated;
