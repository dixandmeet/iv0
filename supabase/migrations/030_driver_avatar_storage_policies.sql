-- Corrige les politiques Storage : chemin basé sur auth.uid() (plus fiable
-- que current_driver_id() dans le contexte Storage).
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS driver_avatars_insert_own ON storage.objects;
CREATE POLICY driver_avatars_insert_own ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'driver-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS driver_avatars_update_own ON storage.objects;
CREATE POLICY driver_avatars_update_own ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'driver-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'driver-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS driver_avatars_delete_own ON storage.objects;
CREATE POLICY driver_avatars_delete_own ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'driver-avatars'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
