-- Code journée et emplacement de stationnement à la prise de service
-- ---------------------------------------------------------------------------
-- Deux informations que le conducteur voit déjà sur la console du dépôt au
-- badgeage mais que l'app ne capturait pas : le code du roulement journalier
-- (« Journée », ex. « 38B-4 », qui peut regrouper plusieurs tronçons/lignes
-- dans la même journée) et l'emplacement de stationnement du véhicule au
-- dépôt (« Emplacement », ex. « H13-1 »). Stockées en TEXT déclaratif sur
-- chaque driver_services, sans lien vers transport_services ni table de
-- regroupement — un futur écran « ma journée » pourra requêter tous les
-- driver_services d'un conducteur partageant le même day_code.
-- ---------------------------------------------------------------------------

ALTER TABLE public.driver_services
    ADD COLUMN IF NOT EXISTS day_code TEXT,
    ADD COLUMN IF NOT EXISTS parking_slot TEXT;

COMMENT ON COLUMN public.driver_services.day_code IS
    'Code du roulement journalier (ex. « 38B-4 »), saisi à la prise de service.';

COMMENT ON COLUMN public.driver_services.parking_slot IS
    'Emplacement de stationnement du véhicule au dépôt (ex. « H13-1 »), saisi à la prise de service.';
