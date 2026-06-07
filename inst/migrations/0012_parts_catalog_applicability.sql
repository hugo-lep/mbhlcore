-- Migration 0012: table parts_catalog_applicability
-- Applicabilité avion d'une pièce catalogue. Many-to-many entre parts_catalog
-- et aircraft_types. Nullable au niveau de la pièce — une pièce sans entrée ici
-- est considérée comme non restreinte à un type d'aéronef.
--
-- Utilisé par mbhlMagasin (RFQ, recherche de stock) et mbhlMaintenance
-- (analyse de fiabilité, templates).

CREATE TABLE IF NOT EXISTS mbhlcore.parts_catalog_applicability (
    catalog_id        INT  NOT NULL REFERENCES mbhlcore.parts_catalog,
    aircraft_type_id  INT  NOT NULL REFERENCES mbhlcore.aircraft_types,
    notes             TEXT,                          -- ex: 'SAAB 340B seulement (pas SF34)'
    PRIMARY KEY (catalog_id, aircraft_type_id)
);
