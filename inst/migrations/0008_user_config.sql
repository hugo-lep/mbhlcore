-- Migration 0008: table user_config
-- Overrides individuels de permissions et préférences par utilisateur.
-- user_id = protegr2_user_id (TEXT) — clé identique à protegR2.
-- NULL = default deny (ce qui n'est pas accordé est refusé).
-- Le JSONB stocke uniquement les overrides, pas toutes les permissions.
-- Exemple: {"mbhlMaintenance.work_orders.can_open_wo": true}
--
-- Note: structure identique dans tous les packages qui utilisent ce patron.
-- Les fonctions génériques db_get_user_config() / db_save_user_config()
-- sont dans le package s3db (helper DB générique).

CREATE TABLE IF NOT EXISTS mbhlcore.user_config (
    user_id  TEXT   PRIMARY KEY,
    config   JSONB  NOT NULL DEFAULT '{}'
);
