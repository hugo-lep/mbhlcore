#' Registry of mbhlCore permissions
#'
#' Exported list of all permissions defined by this package, with human-readable
#' descriptions. Used by the admin interface to generate permission toggles
#' dynamically.
#'
#' @export
mbhlcore_permissions <- list(
    administration = list(
        can_manage_aircraft    = "Créer/modifier les avions",
        can_manage_bases       = "Créer/modifier les bases",
        can_manage_companies   = "Gérer les compagnies et fournisseurs",
        can_manage_personnel   = "Gérer les fiches personnel",
        can_manage_permissions = "Gérer les groupes de permissions",
        can_manage_currencies  = "Gérer les devises et taux de change",
        can_view_reliability   = "Voir les rapports de fiabilité"
    )
)


#' Build effective permissions for a personnel member
#'
#' Computes the effective permission set by combining all permission groups
#' assigned to the personnel member (UNION — any TRUE wins), then applies
#' individual overrides from `mbhlcore.config_user`.
#'
#' Called once at login; the result is kept in session memory.
#'
#' @param con A DBI connection or pool object.
#' @param personnel_id Integer personnel ID from `mbhlcore.personnel`.
#'
#' @return A named list of `permission_key = TRUE/FALSE`. Any key absent from
#'   the list is implicitly `FALSE` (default deny).
#' @importFrom stats setNames
#' @export
#'
#' @examples
#' \dontrun{
#' config_user <- build_user_permissions(con, personnel_id = 3L)
#' has_permission(config_user, "mbhlMaintenance.work_orders.can_close_wo")
#' }
build_user_permissions <- function(con, personnel_id) {
    # Permissions issues des groupes (UNION: un seul TRUE suffit)
    group_perms <- DBI::dbGetQuery(
        con,
        glue::glue_sql(
            "SELECT pgi.permission_key,
                    BOOL_OR(pgi.is_granted) AS is_granted
             FROM mbhlcore.personnel_permission_groups ppg
             JOIN mbhlcore.permission_groups pg
               ON ppg.group_id = pg.group_id AND pg.is_active = TRUE
             JOIN mbhlcore.permission_group_items pgi
               ON pg.group_id = pgi.group_id
             WHERE ppg.personnel_id = {personnel_id}
             GROUP BY pgi.permission_key",
            .con = con
        )
    )

    permissions <- if (nrow(group_perms) > 0L) {
        setNames(as.list(group_perms$is_granted), group_perms$permission_key)
    } else {
        list()
    }

    # Overrides individuels (prennent le dessus sur les groupes)
    # On utilise protegr2_user_id comme user_id pour la table user_config
    protegr2_id <- DBI::dbGetQuery(
        con,
        glue::glue_sql(
            "SELECT protegr2_user_id FROM mbhlcore.personnel
             WHERE personnel_id = {personnel_id}",
            .con = con
        )
    )$protegr2_user_id[[1]]

    overrides <- if (!is.null(protegr2_id) && !is.na(protegr2_id)) {
        s3db::db_get_user_config(con, user_id = protegr2_id, schema = "mbhlcore")
    } else {
        list()
    }

    for (key in names(overrides)) {
        permissions[[key]] <- isTRUE(overrides[[key]])
    }

    permissions
}


#' Check if a user has a specific permission
#'
#' @param config_user Named list returned by [build_user_permissions()].
#' @param key Permission key, e.g. `"mbhlMaintenance.work_orders.can_close_wo"`.
#'
#' @return `TRUE` if the permission is granted, `FALSE` otherwise (including
#'   if the key is absent — default deny).
#' @export
has_permission <- function(config_user, key) {
    isTRUE(config_user[[key]])
}


#' Assert that a user has a specific permission
#'
#' Like [has_permission()], but throws an error if the permission is denied.
#' Use for server-side enforcement of critical actions.
#'
#' @param config_user Named list returned by [build_user_permissions()].
#' @param key Permission key, e.g. `"mbhlMaintenance.work_orders.can_close_wo"`.
#' @param call The call environment for error reporting. Default: caller env.
#'
#' @return Invisibly returns `TRUE` if permission is granted.
#' @export
assert_permission <- function(config_user, key, call = rlang::caller_env()) {
    if (!has_permission(config_user, key)) {
        cli::cli_abort(
            c(
                "Permission refusée: {.val {key}}.",
                "i" = "Contactez votre administrateur si vous croyez que c'est une erreur."
            ),
            call = call
        )
    }
    invisible(TRUE)
}
