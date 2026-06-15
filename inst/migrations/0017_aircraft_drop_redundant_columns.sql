-- Migration 0017: retirer les colonnes redondantes de aircraft
-- manufacturer, model et series sont déjà dans aircraft_types (via icao_type).
-- year_manufactured et msn restent — ils sont propres à chaque avion physique.

ALTER TABLE mbhlcore.aircraft
    DROP COLUMN IF EXISTS manufacturer,
    DROP COLUMN IF EXISTS model,
    DROP COLUMN IF EXISTS series;
