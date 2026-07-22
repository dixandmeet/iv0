-- Enregistre le brouillon complet de l'éditeur sans donner aux profils
-- d'exploitation un droit d'écriture général sur le catalogue du réseau.
CREATE OR REPLACE FUNCTION public.save_line_editor_state(
    p_line_id TEXT,
    p_editor_state JSONB
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_network_id UUID := public.current_network_id();
BEGIN
    IF NULLIF(BTRIM(p_line_id), '') IS NULL THEN
        RAISE EXCEPTION 'Identifiant de ligne requis';
    END IF;

    IF p_editor_state IS NULL OR JSONB_TYPEOF(p_editor_state) <> 'object' THEN
        RAISE EXCEPTION 'État de l''éditeur invalide';
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

    UPDATE public.network_lines
    SET editor_state = p_editor_state,
        updated_at = NOW()
    WHERE network_id = v_network_id
      AND line_id = BTRIM(p_line_id);

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ligne introuvable sur le réseau actif';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.save_line_editor_state(TEXT, JSONB)
FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.save_line_editor_state(TEXT, JSONB)
TO authenticated;
