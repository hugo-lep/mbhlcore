-- Migration 0006: tables du système de permissions MBHL
-- Distinct des roles protegR2 (user/admin/super-admin).
-- Les permissions effectives = UNION des groupes + overrides individuels.

CREATE TABLE IF NOT EXISTS mbhlcore.permission_groups (
    group_id           SERIAL  PRIMARY KEY,
    group_name         TEXT    NOT NULL UNIQUE,
    group_description  TEXT,
    is_active          BOOLEAN NOT NULL DEFAULT TRUE,
    notes              TEXT
);

CREATE TABLE IF NOT EXISTS mbhlcore.permission_group_items (
    item_id         SERIAL  PRIMARY KEY,
    group_id        INT     NOT NULL REFERENCES mbhlcore.permission_groups,
    permission_key  TEXT    NOT NULL,
    is_granted      BOOLEAN NOT NULL,
    UNIQUE (group_id, permission_key)
);

CREATE TABLE IF NOT EXISTS mbhlcore.personnel_permission_groups (
    assignment_id  SERIAL  PRIMARY KEY,
    personnel_id   INT     NOT NULL REFERENCES mbhlcore.personnel,
    group_id       INT     NOT NULL REFERENCES mbhlcore.permission_groups,
    assigned_by    INT     NOT NULL REFERENCES mbhlcore.personnel,
    assigned_date  DATE    NOT NULL,
    UNIQUE (personnel_id, group_id)
);
