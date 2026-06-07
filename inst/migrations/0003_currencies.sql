-- Migration 0003: tables currencies et exchange_rates
-- Une seule devise de base (is_base_currency = TRUE) — devise de comptabilité.
-- Les taux de change sont indicatifs uniquement (affichage approximatif).

CREATE TABLE IF NOT EXISTS mbhlcore.currencies (
    currency_id       SERIAL  PRIMARY KEY,
    currency_code     TEXT    NOT NULL UNIQUE,
    currency_name     TEXT    NOT NULL,
    is_base_currency  BOOLEAN NOT NULL DEFAULT FALSE
);

-- Garantit qu'une seule devise peut être la devise de base
CREATE UNIQUE INDEX IF NOT EXISTS currencies_single_base
    ON mbhlcore.currencies (is_base_currency)
    WHERE is_base_currency = TRUE;

CREATE TABLE IF NOT EXISTS mbhlcore.exchange_rates (
    currency_from  TEXT           NOT NULL,
    currency_to    TEXT           NOT NULL,
    rate           NUMERIC        NOT NULL,
    updated_at     TIMESTAMPTZ    NOT NULL,
    updated_by     TEXT           NOT NULL,
    PRIMARY KEY (currency_from, currency_to)
);
