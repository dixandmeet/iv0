-- Dépréciation messagerie legacy (driver_messages / staff_messages)
-- Les nouvelles fonctionnalités utilisent le framework platform (042/043).

COMMENT ON TABLE public.driver_messages IS
    'LEGACY — remplacé par resources/channels/messages (042_platform_resources). Ne pas étendre.';

COMMENT ON TABLE public.staff_messages IS
    'LEGACY — remplacé par resources/channels/messages (042_platform_resources). Ne pas étendre.';
