-- Numéro de « train » à la prise de service
-- ---------------------------------------------------------------------------
-- Position du véhicule dans la flotte en circulation sur la ligne, telle que
-- lue par le conducteur sur sa feuille de route. Ex. ligne 1 en heure de
-- pointe : jusqu'à ~35 trams en ligne, notés « 1-1 », « 1-2 » … « 1-35 ».
-- Stocké en TEXT (libellé complet « ligne-position ») pour rester lisible côté
-- supervision flotte, cohérent avec line_id / vehicle_id déjà en TEXT (cf. 021).
-- ---------------------------------------------------------------------------

ALTER TABLE public.driver_services
    ADD COLUMN IF NOT EXISTS train_number TEXT;

COMMENT ON COLUMN public.driver_services.train_number IS
    'Position du véhicule dans la flotte en ligne (ex. « 1-12 »), saisie à la prise de service.';
