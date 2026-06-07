-- Migration 0005: tables personnel et personnel_licenses
-- Distinct de la table users de protegR2 (auth).
-- protegr2_user_id est nullable: permet de référencer des signataires
-- sans accès à l'application (ex: AME externe d'un W.O. outsourcé).

CREATE TABLE IF NOT EXISTS mbhlcore.personnel (
    personnel_id      SERIAL  PRIMARY KEY,
    protegr2_user_id  TEXT,
    full_name         TEXT    NOT NULL,
    default_base_id   INT     REFERENCES mbhlcore.bases,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    notes             TEXT
);

CREATE TABLE IF NOT EXISTS mbhlcore.personnel_licenses (
    license_id     SERIAL  PRIMARY KEY,
    personnel_id   INT     NOT NULL REFERENCES mbhlcore.personnel,
    license_type   TEXT    NOT NULL CHECK (
                       license_type IN ('ame', 'driver', 'dangerous_goods', 'first_aid', 'other')
                   ),
    authority      TEXT,
    license_number TEXT,
    expiry_date    DATE,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    notes          TEXT
);
