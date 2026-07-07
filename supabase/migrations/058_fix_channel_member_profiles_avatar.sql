-- ---------------------------------------------------------------------------
-- Fix : get_channel_member_profiles référençait user_profiles.avatar_url,
-- colonne qui n'existe pas (l'avatar vit sur drivers.avatar_url, lié par
-- drivers.user_id = user_profiles.id). Cassait le panel Membres avec
-- "column up.avatar_url does not exist" (42703) et dégradait silencieusement
-- les avatars d'expéditeur dans le chat (DiscussionService._loadSenders).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_channel_member_profiles(p_channel_id UUID)
RETURNS TABLE (id UUID, display_name TEXT, avatar_url TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_active_channel_member(p_channel_id) AND NOT public.is_staff() THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT up.id, up.display_name, d.avatar_url
    FROM public.channel_members cm
    JOIN public.user_profiles up ON up.id = cm.user_id
    LEFT JOIN public.drivers d ON d.user_id = up.id
    WHERE cm.channel_id = p_channel_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_channel_member_profiles(UUID) TO authenticated;
