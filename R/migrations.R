#' Apply all pending database migrations
#'
#' Reads SQL files from the `inst/migrations/` folder of the given package,
#' compares with migrations already recorded in `mbhlcore.schema_migrations`,
#' and applies any pending migrations in alphabetical order. Safe to call
#' multiple times — already applied migrations are skipped.
#'
#' Each migration is recorded with a prefixed ID: `{package}_{filename}`,
#' e.g. `mbhlcore_0001_aircraft` or `mbhlmaintenance_0001_work_orders`.
#' This prevents collisions when multiple packages share the same
#' `schema_migrations` table.
#'
#' @param con     A DBI connection or pool object pointing to the client database.
#' @param package Name of the package whose `inst/migrations/` to apply.
#'   Defaults to `"mbhlcore"`. Other MBHL packages pass their own name here.
#'
#' @return Invisibly returns the number of migrations applied.
#' @importFrom tools file_path_sans_ext
#' @export
run_pending_migrations <- function(con, package = "mbhlcore") {
    .bootstrap_schema(con, schema = package)

    migration_dir <- system.file("migrations", package = package)
    sql_files     <- sort(list.files(migration_dir, pattern = "\\.sql$", full.names = TRUE))
    bare_ids      <- tools::file_path_sans_ext(basename(sql_files))
    migration_ids <- paste0(package, "_", bare_ids)

    applied <- DBI::dbGetQuery(
        con,
        "SELECT migration_id FROM mbhlcore.schema_migrations ORDER BY migration_id"
    )$migration_id

    pending_idx <- which(!migration_ids %in% applied)

    if (length(pending_idx) == 0L) {
        cli::cli_inform(c("v" = "All migrations already applied."))
        return(invisible(0L))
    }

    cli::cli_inform("Applying {length(pending_idx)} pending migration{?s}...")

    for (i in pending_idx) {
        id   <- migration_ids[[i]]
        file <- sql_files[[i]]

        tryCatch(
            DBI::dbWithTransaction(con, {
                .execute_sql_file(con, file)
                DBI::dbExecute(
                    con,
                    glue::glue_sql(
                        "INSERT INTO mbhlcore.schema_migrations (migration_id, applied_at)
                         VALUES ({id}, NOW())",
                        .con = con
                    )
                )
            }),
            error = \(e) cli::cli_abort(
                c(
                    "Migration {.val {id}} failed — rolled back.",
                    "x" = "{conditionMessage(e)}"
                ),
                call = NULL
            )
        )

        cli::cli_inform(c("v" = "{id}"))
    }

    cli::cli_inform(
        c("v" = "{length(pending_idx)} migration{?s} applied successfully.")
    )
    invisible(length(pending_idx))
}


#' List all migrations and their status
#'
#' @param con     A DBI connection or pool object.
#' @param package Name of the package whose `inst/migrations/` to inspect.
#'   Defaults to `"mbhlcore"`.
#'
#' @return A data.frame with columns `migration_id`, `status` ("applied" or
#'   "pending"), and `applied_at` (NA if pending).
#' @export
list_migrations <- function(con, package = "mbhlcore") {
    migration_dir <- system.file("migrations", package = package)
    sql_files     <- sort(list.files(migration_dir, pattern = "\\.sql$"))
    bare_ids      <- tools::file_path_sans_ext(sql_files)
    migration_ids <- paste0(package, "_", bare_ids)

    applied <- tryCatch(
        DBI::dbGetQuery(
            con,
            "SELECT migration_id, applied_at
             FROM mbhlcore.schema_migrations
             ORDER BY migration_id"
        ),
        error = \(e) data.frame(
            migration_id = character(0),
            applied_at   = as.POSIXct(character(0))
        )
    )

    data.frame(
        migration_id = migration_ids,
        status       = ifelse(migration_ids %in% applied$migration_id, "applied", "pending"),
        applied_at   = applied$applied_at[match(migration_ids, applied$migration_id)],
        stringsAsFactors = FALSE
    )
}


#' Display migration status in the console
#'
#' @param con     A DBI connection or pool object.
#' @param package Name of the package whose migrations to display.
#'   Defaults to `"mbhlcore"`.
#'
#' @return Invisibly returns the data.frame from [list_migrations()].
#' @export
migration_status <- function(con, package = "mbhlcore") {
    df <- list_migrations(con, package = package)

    n_applied <- sum(df$status == "applied")
    n_pending <- sum(df$status == "pending")

    cli::cli_h1("{package} — Migration status")
    cli::cli_inform(c(
        "v" = "{n_applied} applied",
        "!" = "{n_pending} pending"
    ))

    for (i in seq_len(nrow(df))) {
        row <- df[i, ]
        if (row$status == "applied") {
            cli::cli_inform(
                "  {.field {row$migration_id}}  {.emph applied {format(row$applied_at, '%Y-%m-%d')}}"
            )
        } else {
            cli::cli_inform("  {.field {row$migration_id}}  {.emph pending}")
        }
    }

    invisible(df)
}


# Crée le schema cible et la table de suivi des migrations.
# La table schema_migrations reste TOUJOURS dans mbhlcore (partagée entre packages).
# Appelé automatiquement par run_pending_migrations() avant toute autre opération.
.bootstrap_schema <- function(con, schema = "mbhlcore") {
    DBI::dbExecute(
        con,
        paste0("CREATE SCHEMA IF NOT EXISTS ", DBI::dbQuoteIdentifier(con, schema))
    )
    DBI::dbExecute(con, "
        CREATE TABLE IF NOT EXISTS mbhlcore.schema_migrations (
            migration_id  TEXT        PRIMARY KEY,
            applied_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
    ")
    invisible(NULL)
}


# Lit un fichier SQL et exécute chaque instruction séparément.
.execute_sql_file <- function(con, path) {
    sql <- paste(readLines(path, warn = FALSE), collapse = "\n")

    # Retirer les commentaires single-line
    sql <- gsub("--[^\n]*", "", sql)

    statements <- strsplit(sql, ";")[[1]]
    statements <- trimws(statements)
    statements <- statements[nzchar(statements)]

    for (stmt in statements) {
        DBI::dbExecute(con, stmt)
    }

    invisible(NULL)
}
