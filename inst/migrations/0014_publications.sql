-- Migration 0014: module publications
-- Suivi des publications de référence de la compagnie: AMM, MPD, MRB, CMM,
-- IPC, MEL, FCOM, ALM, etc. Dans mbhlCore car compagnie-wide.
--
-- Quand une publication impacte la maintenance planifiée, une entrée
-- maint_inspection_sources (mbhlMaintenance) est créée avec un publication_id FK.
-- publication_revision_log sert alors de journal des révisions pour cette source.
--
-- publication_applicability: une publication peut couvrir plusieurs types d'aéronefs
-- et/ou plusieurs pièces catalogue. Au moins l'un des deux FK doit être non-NULL.

CREATE TABLE IF NOT EXISTS mbhlcore.publications (
    publication_id        SERIAL   PRIMARY KEY,
    title                 TEXT     NOT NULL,    -- ex: 'SAAB 340B AMM', 'Hamilton 14SF-23 CMM'
    pub_type              TEXT     NOT NULL     -- 'amm' | 'mpd' | 'mrb' | 'cmm' | 'ipc'
                          CHECK (pub_type IN ('amm', 'mpd', 'mrb', 'cmm', 'ipc',
                                              'mel', 'fcom', 'alm', 'other')),
    owner                 TEXT,                -- ex: 'SAAB', 'Hamilton', 'TC', 'Pascan'
    current_version       TEXT,                -- ex: 'Rev 39', 'Issue 4'
    current_version_date  DATE,
    doc_ref               TEXT,                -- S3 (copie de la version courante)
    is_active             BOOLEAN  NOT NULL DEFAULT TRUE,
    notes                 TEXT
);

CREATE TABLE IF NOT EXISTS mbhlcore.publication_applicability (
    applicability_id  SERIAL  PRIMARY KEY,
    publication_id    INT     NOT NULL REFERENCES mbhlcore.publications,
    aircraft_type_id  INT     REFERENCES mbhlcore.aircraft_types,   -- nullable
    catalog_id        INT     REFERENCES mbhlcore.parts_catalog,    -- nullable
    -- au moins l'un des deux doit être non-NULL
    CONSTRAINT chk_pub_applicability_not_both_null
        CHECK (aircraft_type_id IS NOT NULL OR catalog_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS mbhlcore.publication_revision_log (
    log_id          SERIAL   PRIMARY KEY,
    publication_id  INT      NOT NULL REFERENCES mbhlcore.publications,
    version         TEXT     NOT NULL,    -- ex: 'Rev 39'
    revision_date   DATE,
    summary         TEXT,                -- ex: '25-60-01 AMM reference change'
    doc_ref         TEXT,                -- nullable — S3 (highlights de la révision)
    evaluated_by    INT      REFERENCES mbhlcore.personnel,
    evaluated_date  DATE,
    notes           TEXT
);
