-- Migration 0001: table aircraft
-- Avions de la flotte. is_active = FALSE si vendu/retiré (historique conservé).

CREATE TABLE IF NOT EXISTS mbhlcore.aircraft (
    aircraft_id         SERIAL      PRIMARY KEY,
    registration        TEXT        NOT NULL,
    icao_type           TEXT,
    manufacturer        TEXT,
    model               TEXT,
    series              TEXT,
    msn                 TEXT,
    year_manufactured   INT,
    is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
    notes               TEXT
);
