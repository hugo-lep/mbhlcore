-- Migration 0009: table aircraft_types
-- Référence des types d'aéronefs. Partagée entre tous les volets MBHL:
-- mbhlMaintenance (templates, ADs, SBs), mbhlMagasin (applicabilité pièces),
-- publications (applicabilité documents).

CREATE TABLE IF NOT EXISTS mbhlcore.aircraft_types (
    type_id       SERIAL  PRIMARY KEY,
    icao_type     TEXT    NOT NULL,       -- ex: 'SF34', 'B190', 'AT43'
    manufacturer  TEXT    NOT NULL,       -- ex: 'SAAB', 'Beechcraft', 'ATR'
    model         TEXT    NOT NULL,       -- ex: '340', '1900', '42'
    variant       TEXT,                   -- nullable (ex: 'B', 'D' — NULL = tous variants)
    notes         TEXT
);
