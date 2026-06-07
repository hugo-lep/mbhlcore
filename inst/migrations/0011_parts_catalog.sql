-- Migration 0011: table parts_catalog
-- Catalogue central des pièces. Partagé entre mbhlMaintenance, mbhlMagasin
-- et mbhlComptable. Chaque pièce physique (par S/N) est une instance de cette entrée.
--
-- has_own_logbook: TRUE pour les composantes avec carnet réglementaire propre
--   (moteurs, hélices) — active le suivi TSN/TSO/CSN/CSO et la vue logbook.
-- review_status: dashboard widget "types de pièces non révisés".

CREATE TABLE IF NOT EXISTS mbhlcore.parts_catalog (
    catalog_id        SERIAL   PRIMARY KEY,
    part_number       TEXT     NOT NULL,
    description       TEXT     NOT NULL,
    manufacturer      TEXT,                          -- nullable (pièces génériques)
    part_type_id      INT      NOT NULL REFERENCES mbhlcore.part_types,
    unit_of_measure   TEXT     NOT NULL,             -- 'each' | 'quart' | 'liter' | 'foot' | etc.
    has_shelf_life    BOOLEAN  NOT NULL DEFAULT FALSE,
    shelf_life_days   INT,                           -- nullable, si has_shelf_life = TRUE
    has_own_logbook   BOOLEAN  NOT NULL DEFAULT FALSE,
    is_hazmat         BOOLEAN  NOT NULL DEFAULT FALSE,
    review_status     TEXT     NOT NULL DEFAULT 'to_review'
                               CHECK (review_status IN ('to_review', 'reviewed')),
    is_active         BOOLEAN  NOT NULL DEFAULT TRUE,
    notes             TEXT
);
