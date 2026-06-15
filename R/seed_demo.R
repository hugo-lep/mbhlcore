# ── Helpers internes ──────────────────────────────────────────────────────────

.read_seed_csv <- function(filename, package = "mbhlcore") {
    path <- system.file("seed", filename, package = package)
    if (!nzchar(path)) {
        cli::cli_abort(
            "Fichier seed {.file {filename}} introuvable dans {.pkg {package}}.",
            "i" = "Le package est-il installé ? Lance {.code devtools::load_all()}."
        )
    }
    utils::read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA"),
                    encoding = "UTF-8")
}

# Convertit "TRUE"/"FALSE" (character) en logical
.bool_col <- function(x) toupper(trimws(x)) == "TRUE"

# Construit un vecteur nommé key → id pour résoudre les FK
.build_lookup <- function(con, schema, table, key_col, val_col) {
    df <- DBI::dbGetQuery(
        con,
        sprintf('SELECT "%s", "%s" FROM "%s"."%s"', key_col, val_col, schema, table)
    )
    stats::setNames(df[[val_col]], df[[key_col]])
}

# Vérifie si une table est déjà peuplée
.already_seeded <- function(con, table, schema = "mbhlcore") {
    n <- DBI::dbGetQuery(
        con,
        sprintf('SELECT COUNT(*) FROM "%s"."%s"', schema, table)
    )[[1]]
    n > 0L
}

# Référence qualifiée pour dbAppendTable
.tbl <- function(table) DBI::Id(schema = "mbhlcore", table = table)

# Arithmétique de date sans lubridate
.add_years <- function(date, n) {
    d <- as.POSIXlt(date)
    d$year <- d$year + as.integer(n)
    as.Date(d)
}
.add_months <- function(date, n) {
    d <- as.POSIXlt(date)
    d$mon <- d$mon + as.integer(n)
    as.Date(d)
}


# ── Fonctions seed individuelles ──────────────────────────────────────────────

#' Seed demo: types d'aéronefs
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_aircraft_types <- function(con) {
    if (.already_seeded(con, "aircraft_types")) {
        cli::cli_inform(c("v" = "aircraft_types déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df <- .read_seed_csv("aircraft_types.csv")
    DBI::dbAppendTable(con, .tbl("aircraft_types"), df)
    cli::cli_inform(c("v" = "{nrow(df)} aircraft_types insérés."))
    invisible(NULL)
}


#' Seed demo: bases
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_bases <- function(con) {
    if (.already_seeded(con, "bases")) {
        cli::cli_inform(c("v" = "bases déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df <- .read_seed_csv("bases.csv")
    df$is_active <- .bool_col(df$is_active)
    DBI::dbAppendTable(con, .tbl("bases"), df)
    cli::cli_inform(c("v" = "{nrow(df)} bases insérées."))
    invisible(NULL)
}


#' Seed demo: devises
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_currencies <- function(con) {
    if (.already_seeded(con, "currencies")) {
        cli::cli_inform(c("v" = "currencies déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df <- .read_seed_csv("currencies.csv")
    df$is_base_currency <- .bool_col(df$is_base_currency)
    DBI::dbAppendTable(con, .tbl("currencies"), df)
    cli::cli_inform(c("v" = "{nrow(df)} currencies insérées."))
    invisible(NULL)
}


#' Seed demo: taux de change
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_exchange_rates <- function(con) {
    if (.already_seeded(con, "exchange_rates")) {
        cli::cli_inform(c("v" = "exchange_rates déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df <- .read_seed_csv("exchange_rates.csv")
    df$updated_at <- Sys.time()
    df$rate       <- as.numeric(df$rate)
    DBI::dbAppendTable(con, .tbl("exchange_rates"), df)
    cli::cli_inform(c("v" = "{nrow(df)} taux de change insérés."))
    invisible(NULL)
}


#' Seed demo: types de pièces
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_part_types <- function(con) {
    if (.already_seeded(con, "part_types")) {
        cli::cli_inform(c("v" = "part_types déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df <- .read_seed_csv("part_types.csv")
    df$is_active <- .bool_col(df$is_active)
    DBI::dbAppendTable(con, .tbl("part_types"), df)
    cli::cli_inform(c("v" = "{nrow(df)} part_types insérés."))
    invisible(NULL)
}


#' Seed demo: compagnies
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_companies <- function(con) {
    if (.already_seeded(con, "companies")) {
        cli::cli_inform(c("v" = "companies déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df <- .read_seed_csv("companies.csv")
    for (col in c("is_supplier", "is_mro", "is_consignment", "is_lessor", "is_active")) {
        df[[col]] <- .bool_col(df[[col]])
    }
    DBI::dbAppendTable(con, .tbl("companies"), df)
    cli::cli_inform(c("v" = "{nrow(df)} compagnies insérées."))
    invisible(NULL)
}


#' Seed demo: contacts compagnies
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_company_contacts <- function(con) {
    if (.already_seeded(con, "company_contacts")) {
        cli::cli_inform(c("v" = "company_contacts déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df  <- .read_seed_csv("company_contacts.csv")
    lkp <- .build_lookup(con, "mbhlcore", "companies", "company_name", "company_id")

    df$company_id <- lkp[df$company_name]
    df$is_primary <- .bool_col(df$is_primary)
    df$company_name <- NULL

    DBI::dbAppendTable(con, .tbl("company_contacts"), df)
    cli::cli_inform(c("v" = "{nrow(df)} contacts insérés."))
    invisible(NULL)
}


#' Seed demo: personnel
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_personnel <- function(con) {
    if (.already_seeded(con, "personnel")) {
        cli::cli_inform(c("v" = "personnel déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df  <- .read_seed_csv("personnel.csv")
    lkp <- .build_lookup(con, "mbhlcore", "bases", "base_code", "base_id")

    df$default_base_id  <- lkp[df$default_base_code]
    df$is_active        <- .bool_col(df$is_active)
    df$default_base_code <- NULL

    DBI::dbAppendTable(con, .tbl("personnel"), df)
    cli::cli_inform(c("v" = "{nrow(df)} membres du personnel insérés."))
    invisible(NULL)
}


#' Seed demo: licences du personnel
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_personnel_licenses <- function(con) {
    if (.already_seeded(con, "personnel_licenses")) {
        cli::cli_inform(c("v" = "personnel_licenses déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df  <- .read_seed_csv("personnel_licenses.csv")
    lkp <- .build_lookup(con, "mbhlcore", "personnel", "full_name", "personnel_id")

    df$personnel_id <- lkp[df$personnel_full_name]

    # Calcul des dates d'expiry relatives à aujourd'hui
    today <- Sys.Date()
    df$expiry_date <- mapply(
        function(yrs, mos) {
            if (is.na(yrs)) return(NA_character_)
            d <- .add_months(.add_years(today, yrs), mos)
            as.character(d)
        },
        df$expiry_years, df$expiry_months,
        SIMPLIFY = TRUE
    )
    df$expiry_date <- as.Date(df$expiry_date)

    df$is_active             <- .bool_col(df$is_active)
    df$personnel_full_name   <- NULL
    df$expiry_years          <- NULL
    df$expiry_months         <- NULL

    DBI::dbAppendTable(con, .tbl("personnel_licenses"), df)
    cli::cli_inform(c("v" = "{nrow(df)} licences insérées."))
    invisible(NULL)
}


#' Seed demo: assignation des groupes de permissions
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_personnel_permission_groups <- function(con) {
    if (.already_seeded(con, "personnel_permission_groups")) {
        cli::cli_inform(c("v" = "personnel_permission_groups déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df       <- .read_seed_csv("personnel_permission_groups.csv")
    p_lkp    <- .build_lookup(con, "mbhlcore", "personnel",         "full_name",   "personnel_id")
    grp_lkp  <- .build_lookup(con, "mbhlcore", "permission_groups", "group_name",  "group_id")

    df$personnel_id  <- p_lkp[df$personnel_full_name]
    df$group_id      <- grp_lkp[df$group_name]
    df$assigned_by   <- p_lkp[df$assigned_by_name]
    df$assigned_date <- Sys.Date()

    df$personnel_full_name <- NULL
    df$group_name          <- NULL
    df$assigned_by_name    <- NULL

    DBI::dbAppendTable(con, .tbl("personnel_permission_groups"), df)
    cli::cli_inform(c("v" = "{nrow(df)} assignations de groupes insérées."))
    invisible(NULL)
}


#' Seed demo: appareils
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_aircraft <- function(con) {
    if (.already_seeded(con, "aircraft")) {
        cli::cli_inform(c("v" = "aircraft déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df <- .read_seed_csv("aircraft.csv")
    df$is_active          <- .bool_col(df$is_active)
    df$year_manufactured  <- as.integer(df$year_manufactured)
    df$default_base_code  <- NULL   # pas de colonne base dans aircraft

    DBI::dbAppendTable(con, .tbl("aircraft"), df)
    cli::cli_inform(c("v" = "{nrow(df)} appareils insérés."))
    invisible(NULL)
}


#' Seed demo: publications
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_publications <- function(con) {
    if (.already_seeded(con, "publications")) {
        cli::cli_inform(c("v" = "publications déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df <- .read_seed_csv("publications.csv")
    df$is_active             <- .bool_col(df$is_active)
    df$current_version_date  <- as.Date(df$current_version_date)

    DBI::dbAppendTable(con, .tbl("publications"), df)
    cli::cli_inform(c("v" = "{nrow(df)} publications insérées."))
    invisible(NULL)
}


#' Seed demo: applicabilité des publications
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_publication_applicability <- function(con) {
    if (.already_seeded(con, "publication_applicability")) {
        cli::cli_inform(c("v" = "publication_applicability déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df      <- .read_seed_csv("publication_applicability.csv")
    pub_lkp <- .build_lookup(con, "mbhlcore", "publications",   "title",     "publication_id")
    typ_lkp <- .build_lookup(con, "mbhlcore", "aircraft_types", "icao_type", "type_id")

    df$publication_id    <- pub_lkp[df$publication_title]
    df$aircraft_type_id  <- typ_lkp[df$icao_type]
    df$catalog_id        <- NA_integer_  # pas de pièces-specifiques dans le seed actuel

    df$publication_title <- NULL
    df$icao_type         <- NULL
    df$part_number       <- NULL

    DBI::dbAppendTable(con, .tbl("publication_applicability"), df)
    cli::cli_inform(c("v" = "{nrow(df)} entrées d'applicabilité publications insérées."))
    invisible(NULL)
}


#' Seed demo: journal de révisions des publications
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_publication_revision_log <- function(con) {
    if (.already_seeded(con, "publication_revision_log")) {
        cli::cli_inform(c("v" = "publication_revision_log déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df      <- .read_seed_csv("publication_revision_log.csv")
    pub_lkp <- .build_lookup(con, "mbhlcore", "publications", "title",     "publication_id")
    per_lkp <- .build_lookup(con, "mbhlcore", "personnel",    "full_name", "personnel_id")

    df$publication_id   <- pub_lkp[df$publication_title]
    df$evaluated_by     <- per_lkp[df$evaluated_by_name]
    df$revision_date    <- as.Date(df$revision_date)
    df$evaluated_date   <- as.Date(df$evaluated_date)

    df$publication_title  <- NULL
    df$evaluated_by_name  <- NULL

    DBI::dbAppendTable(con, .tbl("publication_revision_log"), df)
    cli::cli_inform(c("v" = "{nrow(df)} révisions de publications insérées."))
    invisible(NULL)
}


#' Seed demo: catalogue de pièces
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_parts_catalog <- function(con) {
    if (.already_seeded(con, "parts_catalog")) {
        cli::cli_inform(c("v" = "parts_catalog déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df      <- .read_seed_csv("parts_catalog.csv")
    typ_lkp <- .build_lookup(con, "mbhlcore", "part_types", "type_name", "type_id")

    df$part_type_id <- typ_lkp[df$part_type_name]
    df$part_type_name <- NULL

    for (col in c("is_serialized", "lot_tracking", "has_shelf_life", "has_own_logbook",
                  "is_hazmat", "track_tsn", "track_tso", "track_csn", "track_cso",
                  "track_hobbs", "is_active")) {
        df[[col]] <- .bool_col(df[[col]])
    }
    df$shelf_life_days <- suppressWarnings(as.integer(df$shelf_life_days))

    DBI::dbAppendTable(con, .tbl("parts_catalog"), df)
    cli::cli_inform(c("v" = "{nrow(df)} entrées du catalogue insérées."))
    invisible(NULL)
}


#' Seed demo: applicabilité des pièces par type d'aéronef
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_parts_catalog_applicability <- function(con) {
    if (.already_seeded(con, "parts_catalog_applicability")) {
        cli::cli_inform(c("v" = "parts_catalog_applicability déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df      <- .read_seed_csv("parts_catalog_applicability.csv")
    cat_lkp <- .build_lookup(con, "mbhlcore", "parts_catalog",   "part_number", "catalog_id")
    typ_lkp <- .build_lookup(con, "mbhlcore", "aircraft_types",  "icao_type",   "type_id")

    df$catalog_id        <- cat_lkp[df$part_number]
    df$aircraft_type_id  <- typ_lkp[df$icao_type]

    df$part_number  <- NULL
    df$icao_type    <- NULL

    # Éliminer les lignes avec FK manquantes
    df <- df[!is.na(df$catalog_id) & !is.na(df$aircraft_type_id), ]

    DBI::dbAppendTable(con, .tbl("parts_catalog_applicability"), df)
    cli::cli_inform(c("v" = "{nrow(df)} entrées d'applicabilité pièces insérées."))
    invisible(NULL)
}


#' Seed demo: positions d'installation des pièces
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_parts_catalog_positions <- function(con) {
    if (.already_seeded(con, "parts_catalog_positions")) {
        cli::cli_inform(c("v" = "parts_catalog_positions déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df      <- .read_seed_csv("parts_catalog_positions.csv")
    cat_lkp <- .build_lookup(con, "mbhlcore", "parts_catalog",  "part_number", "catalog_id")
    typ_lkp <- .build_lookup(con, "mbhlcore", "aircraft_types", "icao_type",   "type_id")

    df$catalog_id       <- cat_lkp[df$part_number]
    df$aircraft_type_id <- typ_lkp[df$icao_type]   # NA si icao_type vide → NULL en DB
    df$is_active        <- TRUE

    df$part_number <- NULL
    df$icao_type   <- NULL

    df <- df[!is.na(df$catalog_id), ]

    DBI::dbAppendTable(con, .tbl("parts_catalog_positions"), df)
    cli::cli_inform(c("v" = "{nrow(df)} positions insérées."))
    invisible(NULL)
}


#' Seed demo: groupes de P/Ns alternatifs
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_parts_catalog_alternate_groups <- function(con) {
    if (.already_seeded(con, "parts_catalog_alternate_groups")) {
        cli::cli_inform(c("v" = "parts_catalog_alternate_groups déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df <- .read_seed_csv("parts_catalog_alternate_groups.csv")
    names(df)[names(df) == "group_description"] <- "description"

    DBI::dbAppendTable(con, .tbl("parts_catalog_alternate_groups"), df)
    cli::cli_inform(c("v" = "{nrow(df)} groupes d'alternates insérés."))
    invisible(NULL)
}


#' Seed demo: membres des groupes de P/Ns alternatifs
#' @param con Connexion ou pool DBI.
#' @export
seed_demo_parts_catalog_alternate_memberships <- function(con) {
    if (.already_seeded(con, "parts_catalog_alternate_memberships")) {
        cli::cli_inform(c("v" = "parts_catalog_alternate_memberships déjà peuplée — ignorée."))
        return(invisible(NULL))
    }
    df      <- .read_seed_csv("parts_catalog_alternate_memberships.csv")
    grp_lkp <- .build_lookup(con, "mbhlcore", "parts_catalog_alternate_groups",
                             "description", "group_id")
    cat_lkp <- .build_lookup(con, "mbhlcore", "parts_catalog", "part_number", "catalog_id")

    df$group_id   <- grp_lkp[df$group_description]
    df$catalog_id <- cat_lkp[df$part_number]

    df$group_description <- NULL
    df$part_number       <- NULL

    df <- df[!is.na(df$group_id) & !is.na(df$catalog_id), ]

    DBI::dbAppendTable(con, .tbl("parts_catalog_alternate_memberships"), df)
    cli::cli_inform(c("v" = "{nrow(df)} membres d'alternates insérés."))
    invisible(NULL)
}


# ── Orchestrateur ─────────────────────────────────────────────────────────────

#' Seed toutes les données de démonstration de mbhlCore
#'
#' Appelle toutes les fonctions `seed_demo_*` dans le bon ordre de dépendances.
#' Chaque fonction est idempotente — si la table est déjà peuplée, elle est ignorée.
#'
#' @param con Connexion ou pool DBI pointant vers la base client.
#' @return Invisible NULL.
#' @export
seed_demo_data <- function(con) {
    cli::cli_h1("mbhlCore — Seed données démo")

    # Niveau 1 — aucune dépendance
    seed_demo_aircraft_types(con)
    seed_demo_bases(con)
    seed_demo_currencies(con)
    seed_demo_exchange_rates(con)
    seed_demo_part_types(con)
    seed_demo_companies(con)

    # Niveau 2 — dépend du niveau 1
    seed_demo_company_contacts(con)
    seed_demo_personnel(con)

    # Niveau 3 — dépend du niveau 1-2
    seed_demo_personnel_licenses(con)
    seed_demo_personnel_permission_groups(con)
    seed_demo_aircraft(con)
    seed_demo_publications(con)

    # Niveau 4 — dépend du niveau 1-3
    seed_demo_publication_applicability(con)
    seed_demo_publication_revision_log(con)
    seed_demo_parts_catalog(con)

    # Niveau 5 — dépend du niveau 4
    seed_demo_parts_catalog_applicability(con)
    seed_demo_parts_catalog_positions(con)
    seed_demo_parts_catalog_alternate_groups(con)

    # Niveau 6 — dépend du niveau 5
    seed_demo_parts_catalog_alternate_memberships(con)

    cli::cli_inform(c("v" = "Seed démo mbhlCore terminé."))
    invisible(NULL)
}
