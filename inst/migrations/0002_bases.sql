-- Migration 0002: table bases
-- Bases d'opération et installations de maintenance.

CREATE TABLE IF NOT EXISTS mbhlcore.bases (
    base_id     SERIAL  PRIMARY KEY,
    base_code   TEXT    NOT NULL,
    base_name   TEXT    NOT NULL,
    base_type   TEXT    NOT NULL CHECK (base_type IN ('airport', 'maintenance_facility', 'other')),
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    notes       TEXT
);
