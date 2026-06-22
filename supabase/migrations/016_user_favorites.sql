-- Favoris synchronisés par compte (passagers connectés)
-- Source de vérité côté app = local (SharedPreferences, offline-first) ;
-- cette table permet de retrouver ses favoris sur tous ses appareils.

CREATE TABLE IF NOT EXISTS user_favorites (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('stop', 'line')),
    ref_id TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    PRIMARY KEY (user_id, kind, ref_id)
);

CREATE INDEX IF NOT EXISTS idx_user_favorites_user ON user_favorites(user_id);

-- ---------------------------------------------------------------------------
-- RLS : chaque utilisateur ne voit / ne gère que ses propres favoris
-- ---------------------------------------------------------------------------
ALTER TABLE user_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS favorites_select_own ON user_favorites;
CREATE POLICY favorites_select_own ON user_favorites
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS favorites_insert_own ON user_favorites;
CREATE POLICY favorites_insert_own ON user_favorites
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS favorites_delete_own ON user_favorites;
CREATE POLICY favorites_delete_own ON user_favorites
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());
