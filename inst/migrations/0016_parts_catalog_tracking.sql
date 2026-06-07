-- Migration 0016: champs de suivi manquants dans parts_catalog
-- Complète la migration 0011 avec les champs requis par mbhlMaintenance
-- et mbhlMagasin pour le suivi des pièces physiques.
--
-- tracking_class: classification technique de gestion (différent de part_type_id
--   qui est la classification métier configurable par compagnie).
--   'inventory' = pièces courantes gérées en stock
--   'asset'     = composantes capitalisées (moteurs, hélices, rotables)
--   'consumable'= consommables non repris en inventaire (huiles, graisses, câbles)
--
-- is_serialized: TRUE = chaque unité physique a un S/N unique → suivi TSN/TSO/CSN/CSO
-- lot_tracking:  TRUE = traçabilité par numéro de lot (ex: pièces avec shelf life)
-- track_*:       flags de suivi temporel/cyclique, actifs si is_serialized = TRUE

ALTER TABLE mbhlcore.parts_catalog
    ADD COLUMN IF NOT EXISTS tracking_class  TEXT    NOT NULL DEFAULT 'inventory'
                             CHECK (tracking_class IN ('inventory', 'asset', 'consumable')),
    ADD COLUMN IF NOT EXISTS is_serialized   BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS lot_tracking    BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS track_tsn       BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS track_tso       BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS track_csn       BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS track_cso       BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS track_hobbs     BOOLEAN NOT NULL DEFAULT FALSE;
