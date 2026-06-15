#' Registry of mbhlCore permissions
#'
#' Exported list of all permissions defined by this package, with human-readable
#' descriptions. Used by the admin interface to generate permission toggles
#' dynamically. This is the source of truth — add a permission here before
#' using it anywhere in the code.
#'
#' @export
mbhlcore_permissions <- list(
    administration = list(
        can_manage_aircraft       = "Créer/modifier les avions",
        can_manage_bases          = "Créer/modifier les bases",
        can_manage_companies      = "Gérer les compagnies et fournisseurs",
        can_manage_personnel      = "Gérer les fiches personnel",
        can_manage_permissions    = "Gérer les groupes de permissions",
        can_manage_currencies     = "Gérer les devises et taux de change",
        can_manage_aircraft_types = "Créer/modifier les types d'aéronefs",
        can_manage_part_types     = "Configurer les types de pièces",
        can_manage_publications   = "Gérer les publications et révisions",
        can_view_reliability      = "Voir les rapports de fiabilité"
    )
)
