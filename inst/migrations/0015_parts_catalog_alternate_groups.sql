-- Migration 0015: groupes de P/Ns interchangeables
-- Relation transversale au catalogue partagé. Utilisée par mbhlMagasin
-- (RFQ, recherche de stock) et mbhlMaintenance (analyse de fiabilité).
--
-- Principe fondamental: aucun P/N "principal" — tous les membres sont égaux.
-- Chaque P/N reste son propre catalog_id indépendant. Le groupe est une relation
-- de recherche et d'analyse, INVISIBLE sur les documents (PO, RO, certification
-- → toujours le vrai P/N de la pièce physique).
--
-- parts_catalog_alternate_memberships.notes: raison de l'appartenance ou restrictions
-- ex: 'approuvé SAAB 340B seulement (pas SF34)'

CREATE TABLE IF NOT EXISTS mbhlcore.parts_catalog_alternate_groups (
    group_id     SERIAL  PRIMARY KEY,
    description  TEXT    NOT NULL,   -- ex: 'Starter-gen AT400/AT401/AT402 (SAAB 340B)'
    notes        TEXT
);

CREATE TABLE IF NOT EXISTS mbhlcore.parts_catalog_alternate_memberships (
    group_id    INT   NOT NULL REFERENCES mbhlcore.parts_catalog_alternate_groups,
    catalog_id  INT   NOT NULL REFERENCES mbhlcore.parts_catalog,
    notes       TEXT,                -- ex: 'approuvé SAAB 340B seulement (pas SF34)'
    PRIMARY KEY (group_id, catalog_id)
);
