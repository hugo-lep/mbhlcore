# Contexte de développement — MBHL Core (`mbhlCore`)

> Fichier autonome. Contient tout le contexte nécessaire pour travailler sur `mbhlCore`.
> Dernière mise à jour: 2026-06-07

## Références rapides

| Document | Chemin | Contenu |
|----------|--------|---------|
| **Plan global MBHL** | `C:\R\obsidian_notes\1-Projects\AvNumbers\mbhl.md` | Vue d'ensemble, ordre de développement inter-packages, statuts |
| **Plan de travail mbhlCore** | `inst/dev/plan.md` | Tâches précises, phases, critères de succès pour CE package |

---

## 1. Vue d'ensemble du projet MBHL

**MBHL** est le module maintenance de la plateforme **AvnumbeRs**. Application Shiny (R + bslib) connectée à PostgreSQL, destinée à une compagnie aérienne gérant opérations et maintenance.

**Trois volets interdépendants:**
- `mbhlMaintenance` — inspections, work orders, forecast, TSO/TSN/CSO/CSN
- `mbhlMagasin` — approvisionnement, inventaire, types de pièces, tracking, consignes
- `mbhlComptable` — lecture des coûts (vue comptable vs vue maintenance)

**Modèle d'affaires:** SaaS hébergé par avnumbers, une base de données PostgreSQL par projet client (ex: `pascan_avn`), avec un schema par package R.

---

## 2. Écosystème existant (packages déjà en production)

| Package | Description | Statut |
|---------|-------------|--------|
| **avnumbers** | Application Shiny principale, point d'entrée | En production |
| **protegR** | Auth (wrapper shinydashboard) — NON utilisé dans MBHL | En production |
| **protegR2** | Auth (wrapper bslib) — utilisé dans MBHL | En développement |
| **bslibHL** | Framework dashboard bslib — UI réutilisable | En développement |
| **s3db** | Accès S3 OVH + helpers DB généraux | En production |
| **logpage** | Saisie pages de log + services au sol | En production (migration requise) |
| **OTP** | Opérations: OTP, Amelia/Intelysis, graphiques retards | En production |

**Nouveaux repos GitHub pour MBHL:**
```
github.com/avnumbers/
  ├── mbhlCore           ← connexion DB, utilitaires, helpers partagés
  ├── mbhlMaintenance    ← W.O., inspections, forecast, TSO/TSN
  ├── mbhlMagasin        ← inventaire, commandes, tracking, consignes
  └── mbhlComptable      ← logique financière, rapports
```

**Rôle de `mbhlCore`:** connexion PostgreSQL, fonctions helpers, conventions partagées. Pas de modules Shiny propres — c'est la "plomberie" importée par les 3 autres packages.

---

## 3. Architecture applicative

### 3.1 Déploiement par client

**Une instance Shiny par client, routée par nginx (subdomain):**
```
pascan.avnumbers.ca   → /srv/shiny-server/pascan/   (DB PostgreSQL: pascan_avn)
client2.avnumbers.ca  → /srv/shiny-server/client2/  (DB PostgreSQL: client2_avn)
```

Isolation totale: instance Shiny distincte + base de données PostgreSQL distincte. Code R identique pour tous les clients, seul le paramètre de connexion (DB) change.

**Structure PostgreSQL à trois niveaux:**
```
pascan_avn                  ← base de données  (projet: client + application)
  ├── protegr2              ← schema           (= package R)
  │     └── users           ← table
  ├── mbhlcore              ← schema
  │     ├── aircraft
  │     ├── bases
  │     ├── personnel
  │     └── ...
  ├── mbhlmaintenance       ← schema
  │     ├── work_orders
  │     ├── inspections
  │     └── ...
  ├── mbhlmagasin           ← schema
  │     ├── parts
  │     ├── purchase_orders
  │     └── ...
  └── mbhlcomptable         ← schema
        ├── transactions
        └── ...
```

Les packages `mbhlMaintenance`, `mbhlMagasin` et `mbhlComptable` peuvent lire les tables du schema `mbhlcore` (cross-schema queries dans la même DB).

### 3.2 VPS — Stratégie par phases

```
Phase 1 — Pascan (client unique)
┌─────────────────────────────┐
│  VPS unique                 │
│  ├── Shiny Server           │
│  └── PostgreSQL             │
│       └── db: pascan_avn    │
└─────────────────────────────┘

Phase 2 — Séparation si nécessaire
┌──────────────────┐    ┌────────────────────────┐
│  VPS Shiny       │    │  VPS PostgreSQL         │
│  └── App Shiny   │◄──►│  └── db: pascan_avn     │
└──────────────────┘    └────────────────────────┘

Phase 3 — Multi-clients
┌──────────────────┐    ┌────────────────────────┐
│  VPS Shiny       │    │  VPS PostgreSQL         │
│  └── App Shiny   │◄──►│  ├── db: pascan_avn     │
│    (tous clients)│    │  ├── db: client2_avn    │
└──────────────────┘    └────────────────────────┘
```

### 3.3 Stockage fichiers

**S3 OVH via package `s3db`** — PDFs, certifications, maintenance releases, exports.
Les références (chemins S3) sont stockées dans PostgreSQL; les fichiers dans S3.

### 3.4 Prérequis avant MBHL

Migration `logpage` requise avant de démarrer MBHL:
- [ ] Migrer `logpage`: protegR → protegR2 et .rds S3 → PostgreSQL
- [ ] Concevoir le schéma PostgreSQL pour les pages de log
- [ ] Script de migration .rds → PostgreSQL

---

## 4. Authentification — protegR2

protegR2 est le seul package d'authentification utilisé dans MBHL.

### 4.1 global_config

- Stocké sur S3, chargé **une seule fois** au démarrage dans `global.R`, gardé en mémoire
- Commun à tous les utilisateurs — choix d'entreprise, API keys, apparence
- Structure organisée par package:
```r
config_global$logpage$api_key_amelia
config_global$mbhlCore$wo_number_format
config_global$mbhlCore$internal_part_id_prefix  # ex: "PAS" → PAS-2024-00342
config_global$mbhlCore$own_company_id            # identifie la compagnie cliente elle-même
config_global$mbhlMaintenance$...
config_global$mbhlMagasin$smtp_host
config_global$mbhlMagasin$smtp_port
config_global$mbhlMagasin$smtp_user
```

### 4.2 user_config

- Chargé au login, propre à l'utilisateur, **stocké dans PostgreSQL** (schema client)
- En mémoire pour la durée de la session — lecture locale ~1–5ms vs S3 ~50–200ms
- Structure JSONB en mémoire:
```r
user_config$logpage$see_price
user_config$mbhlMaintenance$can_close_wo
user_config$mbhlMagasin$can_approve_po
```
- Stockage PostgreSQL:
```sql
user_config (user_id TEXT, config JSONB)
```
- **NULL = "default deny" implicite** — ce qui n'est pas accordé est refusé par défaut
- **Extensible sans migration** — ajouter un droit = commencer à l'utiliser dans le code

### 4.3 Registre des permissions (par package)

Chaque package exporte un objet listant toutes ses permissions avec description lisible:
```r
# mbhlMaintenance/R/permissions.R
mbhl_maintenance_permissions <- list(
  work_orders = list(
    can_open_wo           = "Ouvrir un work order",
    can_close_wo          = "Fermer un work order",
    can_review_wo         = "Réviser un work order (maintenance control)",
    can_stage_wo          = "Préparer un work order (staged)"
  ),
  inspections = list(
    can_approve_extension = "Approuver une extension d'inspection",
    can_void_completion   = "Annuler une completion (correction)"
  ),
  catalog = list(
    can_review_catalog    = "Réviser les entrées parts_catalog"
  )
)
```
Double rôle: référence développeur + source de l'interface admin (génère les toggles dynamiquement).

---

## 5. Base de données PostgreSQL — Conventions

### 5.1 Conventions de nommage

- **snake_case** pour bases de données, schemas, tables et colonnes
- **Trois niveaux hiérarchiques:**

| Niveau | Contenu | Exemple |
|--------|---------|---------|
| **base de données** | `{client}_{projet}` | `pascan_avn` |
| **schema** | nom du package R (minuscules) | `mbhlcore`, `mbhlmaintenance`, `mbhlmagasin`, `mbhlcomptable`, `protegr2` |
| **table** | nom fonctionnel en snake_case, **sans préfixe** | `work_orders`, `aircraft`, `parts` |

- Le schema joue le rôle de séparation fonctionnelle — **les préfixes de table (`maint_`, `store_`, `acct_`) sont abandonnés**, ils sont devenus redondants.
- Référence complète: `pascan_avn.mbhlmaintenance.work_orders`
- Les entités partagées vivent dans `mbhlcore` et sont accessibles par tous les autres packages via cross-schema queries.

### 5.2 Immutabilité comptable

Les enregistrements financiers passés ne peuvent **jamais** être modifiés:
- Soft delete uniquement (champ `is_active` ou `is_voided`)
- Journal d'audit `_audit_log` pour les actions critiques
- Si erreur découverte → créer un nouvel enregistrement correctif, lier à l'ancien

### 5.3 Gestion des migrations

Scripts SQL versionnés dans `mbhlCore/migrations/`:
```
mbhlCore/migrations/
  001_initial.sql
  002_add_x.sql
  003_add_y.sql
```

Table de suivi dans PostgreSQL:
```sql
schema_migrations
─────────────────────────────────
migration_id    TEXT PRIMARY KEY   -- ex: '001_initial'
applied_at      TIMESTAMP
applied_by      TEXT
```

Fonction dans mbhlCore:
```r
run_pending_migrations(con)
# Lit le dossier migrations/, compare avec mbhlcore.schema_migrations, applique les pendants
# con est déjà connecté à la bonne DB (pascan_avn, client2_avn, etc.)
```

---

## 6. Entités centrales (schema `mbhlcore`)

Ces tables vivent dans le schema `mbhlcore` et sont partagées entre tous les volets MBHL.

### 6.1 `aircraft`

```sql
aircraft
────────────────────────────────────────────
aircraft_id         SERIAL PRIMARY KEY
registration        TEXT NOT NULL    -- ex: C-FXXX, N-12345 (unique par compagnie)
icao_type           TEXT             -- ex: ATR4, DH8B (code ICAO — utile pour templates maintenance)
manufacturer        TEXT             -- ex: ATR, de Havilland
model               TEXT             -- ex: ATR 42, Dash 8
series              TEXT             -- ex: 300, 200 (nullable)
msn                 TEXT             -- manufacturer serial number
year_manufactured   INT              -- nullable
is_active           BOOLEAN NOT NULL DEFAULT TRUE
notes               TEXT
```

`is_active = FALSE` si avion vendu/retiré — l'historique est conservé.

### 6.2 `bases`

```sql
bases
────────────────────────────────────────────
base_id             SERIAL PRIMARY KEY
base_code           TEXT NOT NULL    -- ex: YUL, YHU, YMX (IATA ou code interne)
base_name           TEXT NOT NULL    -- ex: "Montréal-Trudeau", "Val-d'Or"
base_type           TEXT NOT NULL    -- 'airport' | 'maintenance_facility' | 'other'
is_active           BOOLEAN NOT NULL DEFAULT TRUE
notes               TEXT
```

### 6.3 `currencies` + `exchange_rates`

```sql
currencies
────────────────────────────────────────────
currency_id         SERIAL PRIMARY KEY
currency_code       TEXT NOT NULL    -- 'CAD' | 'USD' | 'EUR' | etc.
currency_name       TEXT NOT NULL
is_base_currency    BOOLEAN NOT NULL DEFAULT FALSE
-- UNE SEULE ligne avec is_base_currency = TRUE
-- C'est la devise de comptabilité de la compagnie
```

```sql
exchange_rates      -- taux INDICATIFS pour affichage uniquement (NON officiels)
────────────────────────────────────────────
currency_from       TEXT NOT NULL
currency_to         TEXT NOT NULL
rate                NUMERIC NOT NULL
updated_at          TIMESTAMP NOT NULL
updated_by          TEXT NOT NULL
PRIMARY KEY (currency_from, currency_to)
```

**Philosophie des taux de change:**
- Toute transaction est enregistrée dans sa **devise d'origine** (ex: USD 1 500)
- `exchange_rates` sert uniquement à l'affichage approximatif (~2 050 CAD)
- Un snapshot `indicative_rate_at_creation` est capturé dans chaque transaction (référence, pas comptabilité)
- Le **vrai taux comptable** vient de la réconciliation SAGE — hors périmètre MBHL

### 6.4 `companies` + `company_contacts`

```sql
companies
────────────────────────────────────────────
company_id          SERIAL PRIMARY KEY
company_name        TEXT NOT NULL
is_supplier         BOOLEAN NOT NULL DEFAULT FALSE  -- vend des pièces
is_mro              BOOLEAN NOT NULL DEFAULT FALSE  -- effectue des travaux (sous-traitance)
is_consignment      BOOLEAN NOT NULL DEFAULT FALSE  -- fournit des pièces en consigne
is_lessor           BOOLEAN NOT NULL DEFAULT FALSE  -- bailleur (avions ou équipements)
country             TEXT
is_active           BOOLEAN NOT NULL DEFAULT TRUE
notes               TEXT
-- Note: la compagnie cliente (ex: Pascan) est identifiée via
-- config_global$mbhlCore$own_company_id — pas de flag dans la table
```

```sql
company_contacts    -- contacts multiples par compagnie (départements distincts)
────────────────────────────────────────────
contact_id          SERIAL PRIMARY KEY
company_id          INT NOT NULL REFERENCES companies
contact_name        TEXT NOT NULL
department          TEXT             -- nullable (ex: "Consignment", "Parts Sales")
email               TEXT             -- nullable
phone               TEXT             -- nullable
is_primary          BOOLEAN NOT NULL DEFAULT FALSE
notes               TEXT
```

### 6.5 `personnel` + `personnel_licenses`

protegR2 gère sa propre table `users` (auth). MBHL maintient une table `personnel` distincte.

```sql
-- protegR2 → table users (auth)    MBHL → table personnel
-- ─────────────────────────────    ──────────────────────────────────────
-- user_id   ◄──────────────────    protegr2_user_id  (FK nullable)
-- username                         full_name
-- password_hash                    default_base_id
-- ...                              is_active

personnel
────────────────────────────────────────────
personnel_id            SERIAL PRIMARY KEY
protegr2_user_id        TEXT             -- nullable: personne sans login (ex: AME externe)
full_name               TEXT NOT NULL
default_base_id         INT REFERENCES bases  -- nullable
is_active               BOOLEAN NOT NULL DEFAULT TRUE
notes                   TEXT
```

`protegr2_user_id` nullable: permet de référencer des signataires sans accès à l'application (ex: AME externe d'un W.O. outsource).

```sql
personnel_licenses  -- credentials de tout type
────────────────────────────────────────────
license_id          SERIAL PRIMARY KEY
personnel_id        INT NOT NULL REFERENCES personnel
license_type        TEXT NOT NULL    -- 'ame' | 'driver' | 'dangerous_goods' | 'first_aid' | 'other'
authority           TEXT             -- 'TC' | 'FAA' | 'EASA' | 'SAAQ' | autre
license_number      TEXT             -- nullable
expiry_date         DATE             -- nullable
is_active           BOOLEAN NOT NULL DEFAULT TRUE
notes               TEXT
```

### 6.6 `aircraft_types`

Référence des types d'aéronefs. Partagée entre tous les volets MBHL: `mbhlMaintenance`
(templates, ADs, SBs), `mbhlMagasin` (applicabilité pièces), publications (applicabilité documents).

```sql
aircraft_types
────────────────────────────────────────────
type_id       SERIAL PRIMARY KEY
icao_type     TEXT NOT NULL        -- ex: 'SF34', 'B190', 'AT43'
manufacturer  TEXT NOT NULL        -- ex: 'SAAB', 'Beechcraft', 'ATR'
model         TEXT NOT NULL        -- ex: '340', '1900', '42'
variant       TEXT                 -- nullable (ex: 'B', 'D' — NULL = tous variants)
notes         TEXT
```

### 6.7 `part_types`

Types de pièces configurables par compagnie. Exemples Pascan: engine, propeller, rotable,
repairable part, consumable, part, avionics. Aucune valeur par défaut — chaque compagnie
configure ses propres types.

```sql
part_types
────────────────────────────────────────────
type_id      SERIAL PRIMARY KEY
type_name    TEXT NOT NULL UNIQUE
description  TEXT
is_active    BOOLEAN NOT NULL DEFAULT TRUE
```

### 6.8 `parts_catalog`

Catalogue central des pièces. Partagé entre `mbhlMaintenance`, `mbhlMagasin` et `mbhlComptable`.
Chaque pièce physique (par S/N) est une instance de cette entrée.

- `has_own_logbook`: TRUE pour les composantes avec carnet réglementaire propre (moteurs, hélices)
  — active le suivi TSN/TSO/CSN/CSO et la vue logbook dans `mbhlMaintenance`.
- `review_status`: alimente le widget dashboard "types de pièces non révisés".

```sql
parts_catalog
────────────────────────────────────────────
catalog_id        SERIAL PRIMARY KEY
part_number       TEXT NOT NULL
description       TEXT NOT NULL
manufacturer      TEXT                         -- nullable (pièces génériques)
part_type_id      INT NOT NULL REFERENCES part_types
unit_of_measure   TEXT NOT NULL                -- 'each' | 'quart' | 'liter' | 'foot' | etc.
tracking_class    TEXT NOT NULL DEFAULT 'inventory'
                  CHECK (tracking_class IN ('inventory', 'asset', 'consumable'))
                  -- 'inventory'  = pièces courantes gérées en stock
                  -- 'asset'      = composantes capitalisées (moteurs, hélices, rotables)
                  -- 'consumable' = consommables non repris en inventaire
is_serialized     BOOLEAN NOT NULL DEFAULT FALSE  -- chaque unité a un S/N → suivi TSN/TSO
lot_tracking      BOOLEAN NOT NULL DEFAULT FALSE  -- traçabilité par numéro de lot
has_shelf_life    BOOLEAN NOT NULL DEFAULT FALSE
shelf_life_days   INT                          -- nullable, si has_shelf_life = TRUE
has_own_logbook   BOOLEAN NOT NULL DEFAULT FALSE
is_hazmat         BOOLEAN NOT NULL DEFAULT FALSE
track_tsn         BOOLEAN NOT NULL DEFAULT FALSE  -- Time Since New
track_tso         BOOLEAN NOT NULL DEFAULT FALSE  -- Time Since Overhaul
track_csn         BOOLEAN NOT NULL DEFAULT FALSE  -- Cycles Since New
track_cso         BOOLEAN NOT NULL DEFAULT FALSE  -- Cycles Since Overhaul
track_hobbs       BOOLEAN NOT NULL DEFAULT FALSE  -- Hobbs hours
review_status     TEXT NOT NULL DEFAULT 'to_review'
                  CHECK (review_status IN ('to_review', 'reviewed'))
is_active         BOOLEAN NOT NULL DEFAULT TRUE
notes             TEXT
```

**Note:** `tracking_class` est la classification *technique* de gestion (inventory/asset/consumable).
`part_type_id` est la classification *métier* configurable par compagnie (engine, propeller, rotable…).
Les deux coexistent — un moteur a `part_type_id = engine` ET `tracking_class = 'asset'`.

**`asset_pool_type_id` absent intentionnellement** — le lien entre une pièce catalogue et un pool
d'actifs sera possédé par `mbhlComptable` via une table `asset_pool_catalog_items` pointant vers
`mbhlcore.parts_catalog`. Aucun champ comptable dans le catalogue.

### 6.9 `parts_catalog_applicability`

Applicabilité avion d'une pièce. Many-to-many entre `parts_catalog` et `aircraft_types`.
Une pièce sans entrée ici est considérée non restreinte à un type d'aéronef.

```sql
parts_catalog_applicability
────────────────────────────────────────────
catalog_id        INT NOT NULL REFERENCES parts_catalog
aircraft_type_id  INT NOT NULL REFERENCES aircraft_types
notes             TEXT                         -- ex: 'SAAB 340B seulement (pas SF34)'
PRIMARY KEY (catalog_id, aircraft_type_id)
```

### 6.10 `parts_catalog_positions`

Positions d'installation prédéfinies par type de pièce. Utilisées dans
`part_events.position_id` (mbhlMaintenance) et `maint_wo_task_parts.position_id`
pour identifier l'emplacement physique d'une pièce installée.

Quand une pièce a plusieurs positions possibles (ex: starter-gen → LH ou RH engine),
les options sont définies ici et sélectionnées à l'installation. `position_id` est nullable
sur les events si la pièce n'a qu'une seule position possible.

```sql
parts_catalog_positions
────────────────────────────────────────────
position_id         SERIAL PRIMARY KEY
catalog_id          INT NOT NULL REFERENCES parts_catalog
aircraft_type_id    INT REFERENCES aircraft_types          -- nullable
position_name       TEXT NOT NULL    -- ex: 'LH engine', 'RH engine', 'aft mount'
parent_position_id  INT REFERENCES parts_catalog_positions -- nullable (positions imbriquées)
is_active           BOOLEAN NOT NULL DEFAULT TRUE
```

### 6.11 `publications` + tables associées

Suivi des publications de référence de la compagnie: AMM, MPD, MRB, CMM, IPC, MEL, FCOM, ALM.
Dans `mbhlCore` car compagnie-wide. Quand une publication impacte la maintenance planifiée,
une entrée `maint_inspection_sources` (mbhlMaintenance) est créée avec un `publication_id` FK.

```sql
publications
────────────────────────────────────────────
publication_id        SERIAL PRIMARY KEY
title                 TEXT NOT NULL        -- ex: 'SAAB 340B AMM', 'Hamilton 14SF-23 CMM'
pub_type              TEXT NOT NULL        -- 'amm'|'mpd'|'mrb'|'cmm'|'ipc'|'mel'|'fcom'|'alm'|'other'
owner                 TEXT                 -- ex: 'SAAB', 'Hamilton', 'TC', 'Pascan'
current_version       TEXT                 -- ex: 'Rev 39', 'Issue 4'
current_version_date  DATE
doc_ref               TEXT                 -- S3 (copie de la version courante)
is_active             BOOLEAN NOT NULL DEFAULT TRUE
notes                 TEXT

publication_applicability  -- many-to-many: publication ↔ aircraft_types ou parts_catalog
────────────────────────────────────────────
applicability_id  SERIAL PRIMARY KEY
publication_id    INT NOT NULL REFERENCES publications
aircraft_type_id  INT REFERENCES aircraft_types    -- nullable
catalog_id        INT REFERENCES parts_catalog     -- nullable
-- au moins l'un des deux doit être non-NULL (CONSTRAINT chk_pub_applicability_not_both_null)

publication_revision_log  -- historique des révisions évaluées
────────────────────────────────────────────
log_id          SERIAL PRIMARY KEY
publication_id  INT NOT NULL REFERENCES publications
version         TEXT NOT NULL        -- ex: 'Rev 39'
revision_date   DATE
summary         TEXT                 -- ex: '25-60-01 AMM reference change'
doc_ref         TEXT                 -- nullable — S3 (highlights de la révision)
evaluated_by    INT REFERENCES personnel
evaluated_date  DATE
notes           TEXT
```

**Notes d'utilisation:**
- Une AMM peut avoir une entrée `maint_inspection_sources` avec `source_type = 'mrb'` si elle joue
  le rôle du MRB (petits avions sans MRB séparé).
- Un même document peut générer plusieurs sources de maintenance (ex: MPD SAAB → source `mrb` + source `alm`).

### 6.12 `parts_catalog_alternate_groups` + `parts_catalog_alternate_memberships`

Groupes de P/Ns interchangeables. Utilisé par `mbhlMagasin` (RFQ, recherche de stock) et
`mbhlMaintenance` (analyse de fiabilité).

**Principe fondamental:** aucun P/N "principal" — tous les membres du groupe sont égaux.
Chaque P/N reste son propre `catalog_id` indépendant. Le groupe est une relation de recherche
et d'analyse, **invisible sur les documents** (PO, RO, certification → toujours le vrai P/N
de la pièce physique).

```sql
parts_catalog_alternate_groups
────────────────────────────────────────────
group_id     SERIAL PRIMARY KEY
description  TEXT NOT NULL    -- ex: 'Starter-gen AT400/AT401/AT402 (SAAB 340B)'
notes        TEXT

parts_catalog_alternate_memberships
────────────────────────────────────────────
group_id    INT NOT NULL REFERENCES parts_catalog_alternate_groups
catalog_id  INT NOT NULL REFERENCES parts_catalog
notes       TEXT             -- ex: 'approuvé SAAB 340B seulement (pas SF34)'
PRIMARY KEY (group_id, catalog_id)
```

**Impacts par volet:**
- **Recherche de stock (mbhlMagasin):** case "inclure les alternates" cochée par défaut — tous les
  P/Ns du groupe apparaissent avec leur P/N réel. Décochable pour isoler un P/N exact.
- **RFQ (mbhlMagasin):** un item RFQ peut cibler un groupe entier. Le magasinier peut décocher des
  P/Ns avec une raison obligatoire (voir `store_rfq_item_catalog_exclusions` dans mbhlMagasin).
- **Analyse de fiabilité (mbhlMaintenance):** `maint_reliability_analysis_catalogs` (many-to-many)
  permet de pooler plusieurs catalog_ids d'un même groupe pour augmenter le volume d'observations.

---

## 7. Gestion des permissions — `mbhlCore`

### 7.1 Deux niveaux distincts

| Niveau | Package | Valeurs | Rôle |
|--------|---------|---------|------|
| **roles** | protegR2 | `user` \| `admin` \| `super-admin` \| `dev` | Accès à l'application |
| **permission_groups** | mbhlCore | `ame`, `lead_ame`, `apprenti_ame`... | Permissions fonctionnelles MBHL |

### 7.2 Modèle de fusion au login

```
Permissions effectives = UNION(tous les permission_groups de l'utilisateur)
                         + ajouts individuels (user_config)
                         - révocations individuelles (user_config, si besoin)
```

- Au login: calcul unique → stocké en mémoire de session
- Code applicatif utilise `user_config$mbhlMaintenance$can_close_wo` sans savoir l'origine
- `user_config` (JSONB) stocke **uniquement les overrides individuels**
- Changement de groupe = recharge automatique au prochain login
- Les overrides individuels survivent à un changement de groupe

### 7.3 Tables dans `mbhlCore`

```sql
permission_groups           -- groupes configurables par client
────────────────────────────────────────────
group_id                    SERIAL PRIMARY KEY
group_name                  TEXT NOT NULL    -- ex: 'ame', 'lead_ame', 'apprenti_ame'
group_description           TEXT
is_active                   BOOLEAN NOT NULL DEFAULT TRUE
notes                       TEXT

permission_group_items      -- permissions incluses dans un groupe
────────────────────────────────────────────
item_id                     SERIAL PRIMARY KEY
group_id                    INT NOT NULL REFERENCES permission_groups
permission_key              TEXT NOT NULL    -- ex: 'mbhlMaintenance.work_orders.can_open_wo'
is_granted                  BOOLEAN NOT NULL  -- TRUE = accordé, FALSE = refusé explicitement

personnel_permission_groups -- groupes assignés à un membre du personnel
────────────────────────────────────────────
assignment_id               SERIAL PRIMARY KEY
personnel_id                INT NOT NULL REFERENCES personnel
group_id                    INT NOT NULL REFERENCES permission_groups
assigned_by                 INT NOT NULL REFERENCES personnel
assigned_date               DATE NOT NULL
```

### 7.4 Groupes par défaut (exemple Pascan)

`apprenti_ame` | `ame` | `lead_ame` | `maintenance_control` | `gestionnaire_maintenance` | `magasinier_l1` | `magasinier_l2` | `flight_tech_dispatcher`

### 7.5 Matrice des permissions par défaut

**Abréviations:** App=apprenti_ame | AME=ame | Lead=lead_ame | MC=maintenance_control | Gest=gestionnaire | Mag1=magasinier_l1 | Mag2=magasinier_l2 | FTD=flight_tech_dispatcher

#### mbhlMaintenance — Work Orders

| Permission key | Description | App | AME | Lead | MC | Gest | Mag1 | Mag2 | FTD |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `can_view_wo` | Voir les W.O. | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_open_wo` | Ouvrir un W.O. | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `can_stage_wo` | Préparer un W.O. (staged) | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_add_task` | Ajouter une tâche à un W.O. ouvert | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `can_close_task` | Signer/fermer une tâche | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `can_close_wo` | Fermer un W.O. | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `can_review_wo` | Réviser un W.O. → reviewed ou completed | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `can_void_completion` | Annuler une completion d'inspection | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ | ❌ |

#### mbhlMaintenance — Inspections

| Permission key | Description | App | AME | Lead | MC | Gest | Mag1 | Mag2 | FTD |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `can_view_inspections` | Voir le forecast et les inspections | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ |
| `can_create_inspection` | Créer une inspection sur un avion/pièce | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_edit_inspection` | Modifier une inspection existante | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_approve_extension` | Approuver une extension d'inspection | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ✅ |
| `can_manage_packages` | Créer/modifier des packages d'inspection | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_manage_deferrals` | Créer/gérer des ajournements MEL/non-MEL | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

#### mbhlMagasin

| Permission key | Description | App | AME | Lead | MC | Gest | Mag1 | Mag2 | FTD |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `can_view_inventory` | Voir l'inventaire et les stocks | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ |
| `can_view_costs` | Voir les prix et coûts des commandes | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| `can_create_rfq` | Créer une RFQ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ❌ |
| `can_create_order` | Créer un PO/RO/SO | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| `can_send_order` | Envoyer un PO/RO/SO au fournisseur | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| `can_receive_order` | Réceptionner une commande | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ |
| `can_adjust_inventory` | Ajustement d'inventaire | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ |
| `can_manage_catalog` | Gérer le catalogue de pièces | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ |

#### mbhlComptable

| Permission key | Description | App | AME | Lead | MC | Gest | Mag1 | Mag2 | FTD |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `can_view_acct_reports` | Voir les rapports comptables | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_approve_invoice` | Approuver une facture fournisseur | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ | ❌ |
| `can_import_sage` | Importer le fichier mensuel comptable | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `can_reconcile` | Réconcilier les lignes comptables aux factures | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_manage_asset_pools` | Gérer les pools d'actifs | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_view_maintenance_costs` | Vue maintenance des coûts (par avion) | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |

#### mbhlCore — Administration

| Permission key | Description | App | AME | Lead | MC | Gest | Mag1 | Mag2 | FTD |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `can_manage_aircraft` | Créer/modifier les avions | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_manage_bases` | Créer/modifier les bases | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_manage_companies` | Gérer les compagnies/fournisseurs | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ✅ | ❌ |
| `can_manage_personnel` | Gérer les fiches personnel | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_manage_permissions` | Gérer les permission_groups | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_manage_currencies` | Gérer les devises et taux | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `can_view_reliability` | Voir les rapports de fiabilité | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |

---

## 8. Gestion des langues

- **Volet Maintenance:** anglais (terminologie aéronautique standardisée)
- **Interface générale:** multilingue (français/anglais minimum)
- protegR2 a déjà une logique de gestion multilingue → à réutiliser dans MBHL
- Convention: toutes les clés de traduction dans des fichiers `.yml` ou listes R nommées

---

## 9. Google Analytics

**Option A (recommandée):** Intégration unique dans protegR2 — un seul point de configuration, tracking automatique pour toute application wrapped par protegR2.

**Option B:** Par package — plus granulaire (distinguer l'usage par volet), mais plus de code à maintenir.

→ Retenir l'Option A si l'architecture reste mono-app.

---

## 10. Dashboard — Widgets (vue synthétique)

Page d'accueil adaptée au rôle de l'utilisateur connecté. Signale ce qui demande attention.

| Widget | Description | Volet |
|--------|-------------|-------|
| Forecast critique | Inspections dues dans les X prochaines heures/jours — rouge/jaune par avion | Maintenance |
| W.O. ouverts | Liste des W.O. en cours, par avion et statut | Maintenance |
| W.O. à réviser | W.O. fermés en attente de reviewed | Maintenance |
| Types de pièces non révisés | `parts_catalog` avec `review_status = 'to_review'` | Magasin |
| Pièces `serviceable` expirant | Pièces déposées dont le délai de 24h approche ou est dépassé | Maintenance/Magasin |
| Outils calibrés à échéance | Calibration due prochainement | Maintenance |
| Ajournements actifs | Défectuosités différées (MEL/sans MEL) — expirant bientôt en rouge | Maintenance |
| Factures en attente | Factures reçues non encore approuvées | Comptable |
| Repair fees en attente | Exchange/repair fees sans facture finale | Comptable/Magasin |
| Lignes SAGE non réconciliées | Lignes import SAGE sans match MBHL | Comptable |

**Principes:** Le dashboard est adapté au rôle. Chaque widget est un raccourci vers la liste filtrée correspondante.

---

## 11. Interactions entre volets

```
Magasin ──────────────────────────────────────────►  Maintenance
   │   (pièce utilisée dans un W.O., inventaire -1)       │
   │                                                        │
   ▼                                                        ▼
Comptable ◄────────────────────────────────────── Maintenance
   (coût d'achat, factures, exchange/repair fees)  (coût attribué à l'avion)
```

**Flux de données clés:**
1. **Commande de pièce** (Magasin) → déclenche une transaction financière (Comptable)
2. **Réception de pièce** (Magasin) → pièce entre dans l'inventaire ou le pool d'actifs
3. **Utilisation de pièce dans un W.O.** (Maintenance) → balance l'inventaire (Magasin) + attribue le coût (Comptable)
4. **Fermeture d'un W.O.** (Maintenance) → génère un maintenance release PDF (S3)
5. **Réparation d'un actif** (Magasin) → mise à jour de la valeur du pool (Comptable)

---

## 12. MVP — Périmètre

**Dans le MVP:**
- Entités centrales (aircraft, bases, personnel, companies, currencies)
- `mbhlMaintenance`: catalogue pièces, inspections, forecast, W.O. complet (staged→open→closed→completed)
- `mbhlMagasin`: inventaire, PO/RO/SO, réception, lots, consignes, stock minimum

**Hors MVP (architecture pensée dès le départ):**
- `mbhlComptable`: factures, réconciliation SAGE, pools d'actifs, vues des coûts
- Module de fiabilité (CI 605-002, métriques URR/MTBUR/DR)
- Réclamations de dépenses / perdiems
- Outils calibrés (schéma conçu, développement différé)

---

## 13. Questions ouvertes

| # | Question | Statut |
|---|----------|--------|
| 21 | Retour de "core" sur les échanges | ❓ Pending — Hugo se renseigne |
| 17 | Publications techniques — scope et modèle | ❓ À documenter (plus tard) |
| 18 | Formation du personnel — scope et modèle | ❓ À documenter (plus tard) |
