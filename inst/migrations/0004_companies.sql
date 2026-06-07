-- Migration 0004: tables companies et company_contacts
-- Fournisseurs, MRO, bailleurs. La compagnie cliente elle-même est identifiée
-- via config_global$mbhlCore$own_company_id, pas par un flag dans cette table.

CREATE TABLE IF NOT EXISTS mbhlcore.companies (
    company_id      SERIAL  PRIMARY KEY,
    company_name    TEXT    NOT NULL,
    is_supplier     BOOLEAN NOT NULL DEFAULT FALSE,
    is_mro          BOOLEAN NOT NULL DEFAULT FALSE,
    is_consignment  BOOLEAN NOT NULL DEFAULT FALSE,
    is_lessor       BOOLEAN NOT NULL DEFAULT FALSE,
    country         TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    notes           TEXT
);

CREATE TABLE IF NOT EXISTS mbhlcore.company_contacts (
    contact_id    SERIAL  PRIMARY KEY,
    company_id    INT     NOT NULL REFERENCES mbhlcore.companies,
    contact_name  TEXT    NOT NULL,
    department    TEXT,
    email         TEXT,
    phone         TEXT,
    is_primary    BOOLEAN NOT NULL DEFAULT FALSE,
    notes         TEXT
);
