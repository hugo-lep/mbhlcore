-- Migration 0013: table parts_catalog_positions
-- Positions d'installation prédéfinies par type de pièce. Utilisées dans
-- part_events.position_id (mbhlMaintenance) et maint_wo_task_parts.position_id
-- pour identifier l'emplacement physique d'une pièce installée.
--
-- aircraft_type_id: nullable — position applicable à tous les types si NULL.
-- parent_position_id: permet les positions imbriquées (ex: engine → LH engine).
--
-- Quand une pièce a plusieurs positions possibles (ex: starter-gen → LH ou RH
-- engine), les options sont définies ici et sélectionnées à l'installation.
-- position_id est nullable sur les events si la pièce n'a qu'une seule position.

CREATE TABLE IF NOT EXISTS mbhlcore.parts_catalog_positions (
    position_id         SERIAL  PRIMARY KEY,
    catalog_id          INT     NOT NULL REFERENCES mbhlcore.parts_catalog,
    aircraft_type_id    INT     REFERENCES mbhlcore.aircraft_types,  -- nullable
    position_name       TEXT    NOT NULL,    -- ex: 'LH engine', 'RH engine', 'aft mount'
    parent_position_id  INT     REFERENCES mbhlcore.parts_catalog_positions,  -- nullable
    is_active           BOOLEAN NOT NULL DEFAULT TRUE
);
