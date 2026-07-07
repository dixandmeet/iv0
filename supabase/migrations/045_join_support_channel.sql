-- Permet aux voyageurs de rejoindre le canal support avant d'écrire.
CREATE OR REPLACE FUNCTION public.join_support_channel()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_resource_id UUID := '00000000-0000-4000-8000-000000000101';
    v_channel_id UUID;
    v_role_id UUID;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_channel_id := public.ensure_discussion_channel(v_resource_id);

    INSERT INTO public.channel_members (channel_id, user_id, status)
    VALUES (v_channel_id, auth.uid(), 'active')
    ON CONFLICT (channel_id, user_id) DO UPDATE SET status = 'active';

    SELECT id INTO v_role_id FROM public.roles WHERE key = 'channel_member' LIMIT 1;
    IF v_role_id IS NOT NULL THEN
        INSERT INTO public.member_roles (user_id, role_id, channel_id, resource_id)
        VALUES (auth.uid(), v_role_id, v_channel_id, v_resource_id)
        ON CONFLICT DO NOTHING;
    END IF;

    RETURN v_channel_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_support_channel() TO authenticated;
