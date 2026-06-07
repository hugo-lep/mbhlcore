-- Migration 0010: table part_types
-- Types de pièces configurables par compagnie.
-- Exemples Pascan: engine, propeller, rotable, repairable part, consumable, part, avionics
-- Aucune valeur par défaut insérée — chaque compagnie configure ses propres types.

CREATE TABLE IF NOT EXISTS mbhlcore.part_types (
    type_id      SERIAL  PRIMARY KEY,
    type_name    TEXT    NOT NULL UNIQUE,
    description  TEXT,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE
);
