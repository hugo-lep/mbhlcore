#' Bootstrap a new MBHL client database
#'
#' Applies all pending migrations and seeds the base currency. Safe to call
#' multiple times — already-applied migrations and existing data are skipped.
#'
#' @param con A DBI connection or pool object pointing to the client database.
#' @param base_currency_code ISO 4217 currency code for the base currency.
#'   Default: `"CAD"`.
#' @param base_currency_name Full name of the base currency. If `NULL`,
#'   derived automatically from common codes (CAD, USD, EUR, GBP).
#'
#' @return Invisibly returns `TRUE`.
#' @export
#'
#' @examples
#' \dontrun{
#' pool <- protegR2_db_connection(config_global)
#' mbhl_bootstrap_client(pool)
#' }
mbhl_bootstrap_client <- function(con,
                                   base_currency_code = "CAD",
                                   base_currency_name = NULL) {
    cli::cli_h1("mbhlcore — Bootstrap client")

    # Migrations (schema, tables, groupes de permissions par défaut)
    run_pending_migrations(con)

    # Devise de base
    .seed_base_currency(con, base_currency_code, base_currency_name)

    cli::cli_inform(c("v" = "Client opérationnel."))
    invisible(TRUE)
}


#' Check that the MBHL client database is properly set up
#'
#' Validates that all expected tables exist, a base currency is defined,
#' and the default permission groups are in place.
#'
#' @param con A DBI connection or pool object.
#'
#' @return Invisibly returns `TRUE` if all checks pass, `FALSE` otherwise.
#' @export
mbhl_check_setup <- function(con) {
    cli::cli_h1("mbhlcore — Vérification du setup")

    ok <- TRUE

    # Tables attendues dans mbhlcore
    expected_tables <- c(
        "aircraft", "bases", "currencies", "exchange_rates",
        "companies", "company_contacts",
        "personnel", "personnel_licenses",
        "permission_groups", "permission_group_items",
        "personnel_permission_groups", "schema_migrations"
    )

    existing <- DBI::dbGetQuery(con, "
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'mbhlcore'
    ")$table_name

    missing_tables <- setdiff(expected_tables, existing)

    if (length(missing_tables) == 0L) {
        cli::cli_inform(c("v" = "Toutes les tables mbhlcore sont présentes ({length(expected_tables)}/{length(expected_tables)})."))
    } else {
        cli::cli_inform(c("x" = "Tables manquantes: {.val {missing_tables}}"))
        ok <- FALSE
    }

    # Devise de base
    n_base <- DBI::dbGetQuery(
        con,
        "SELECT COUNT(*) AS n FROM mbhlcore.currencies WHERE is_base_currency = TRUE"
    )$n

    if (n_base == 1L) {
        base_code <- DBI::dbGetQuery(
            con,
            "SELECT currency_code FROM mbhlcore.currencies WHERE is_base_currency = TRUE"
        )$currency_code
        cli::cli_inform(c("v" = "Devise de base: {.val {base_code}}"))
    } else if (n_base == 0L) {
        cli::cli_inform(c("x" = "Aucune devise de base définie."))
        ok <- FALSE
    } else {
        cli::cli_inform(c("x" = "Plusieurs devises de base ({n_base}) — une seule autorisée."))
        ok <- FALSE
    }

    # Groupes de permissions par défaut
    default_groups <- c(
        "apprenti_ame", "ame", "lead_ame", "maintenance_control",
        "gestionnaire_maintenance", "magasinier_l1", "magasinier_l2",
        "flight_tech_dispatcher"
    )

    existing_groups <- tryCatch(
        DBI::dbGetQuery(con, "SELECT group_name FROM mbhlcore.permission_groups")$group_name,
        error = \(e) character(0)
    )

    missing_groups <- setdiff(default_groups, existing_groups)

    if (length(missing_groups) == 0L) {
        cli::cli_inform(c("v" = "Groupes de permissions par défaut: tous présents ({length(default_groups)}/{length(default_groups)})."))
    } else {
        cli::cli_inform(c("x" = "Groupes manquants: {.val {missing_groups}}"))
        ok <- FALSE
    }

    # Résultat final
    if (ok) {
        cli::cli_inform(c("v" = "Setup complet — client prêt."))
    } else {
        cli::cli_inform(c(
            "!" = "Setup incomplet.",
            "i" = "Lancer {.fn mbhl_bootstrap_client} pour corriger."
        ))
    }

    invisible(ok)
}


#' Display a summary of the client database state
#'
#' @param con A DBI connection or pool object.
#'
#' @return Invisibly returns a named list with the counts.
#' @export
mbhl_client_info <- function(con) {
    counts <- list(
        aircraft   = .count_table(con, "mbhlcore.aircraft",   "is_active = TRUE"),
        bases      = .count_table(con, "mbhlcore.bases",      "is_active = TRUE"),
        companies  = .count_table(con, "mbhlcore.companies",  "is_active = TRUE"),
        personnel  = .count_table(con, "mbhlcore.personnel",  "is_active = TRUE"),
        perm_groups = .count_table(con, "mbhlcore.permission_groups", "is_active = TRUE")
    )

    last_migration <- tryCatch(
        DBI::dbGetQuery(con, "
            SELECT migration_id, applied_at
            FROM mbhlcore.schema_migrations
            ORDER BY applied_at DESC
            LIMIT 1
        "),
        error = \(e) data.frame(migration_id = NA, applied_at = NA)
    )

    cli::cli_h1("mbhlcore — État du client")
    cli::cli_inform(c(
        "*" = "Avions actifs:       {counts$aircraft}",
        "*" = "Bases actives:       {counts$bases}",
        "*" = "Compagnies actives:  {counts$companies}",
        "*" = "Personnel actif:     {counts$personnel}",
        "*" = "Groupes permissions: {counts$perm_groups}",
        "*" = "Dernière migration:  {last_migration$migration_id[[1]]} ({format(last_migration$applied_at[[1]], '%Y-%m-%d')})"
    ))

    invisible(counts)
}


# Insère la devise de base si elle n'existe pas déjà.
.seed_base_currency <- function(con, code, name) {
    already <- DBI::dbGetQuery(
        con,
        "SELECT COUNT(*) AS n FROM mbhlcore.currencies WHERE is_base_currency = TRUE"
    )$n

    if (already >= 1L) {
        existing_code <- DBI::dbGetQuery(
            con,
            "SELECT currency_code FROM mbhlcore.currencies WHERE is_base_currency = TRUE"
        )$currency_code
        cli::cli_inform(c("v" = "Devise de base déjà définie: {.val {existing_code}} — ignoré."))
        return(invisible(NULL))
    }

    if (is.null(name)) {
        name <- .currency_name(code)
    }

    DBI::dbExecute(
        con,
        glue::glue_sql(
            "INSERT INTO mbhlcore.currencies (currency_code, currency_name, is_base_currency)
             VALUES ({code}, {name}, TRUE)
             ON CONFLICT (currency_code) DO NOTHING",
            .con = con
        )
    )

    cli::cli_inform(c("v" = "Devise de base créée: {.val {code}} ({name})."))
    invisible(NULL)
}


# Retourne le nom complet d'une devise courante, ou le code si inconnu.
.currency_name <- function(code) {
    known <- c(
        CAD = "Dollar canadien",
        USD = "Dollar américain",
        EUR = "Euro",
        GBP = "Livre sterling",
        CHF = "Franc suisse",
        MXN = "Peso mexicain"
    )
    rlang::`%||%`(known[[code]], code)
}


# Compte les lignes d'une table avec un filtre optionnel.
.count_table <- function(con, table, where = NULL) {
    query <- if (is.null(where)) {
        glue::glue("SELECT COUNT(*) AS n FROM {table}")
    } else {
        glue::glue("SELECT COUNT(*) AS n FROM {table} WHERE {where}")
    }
    tryCatch(
        DBI::dbGetQuery(con, query)$n,
        error = \(e) NA_integer_
    )
}


# Note: utiliser rlang::`%||%` directement — rlang est dans Imports
