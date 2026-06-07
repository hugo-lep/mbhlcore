
library(mbhlcore)
library(DBI)
library(RPostgres)

con <- dbConnect(
  drv     = RPostgres::Postgres(),
  dbname  = "pascan_avn",
  host    = "localhost",
  port    = 5432,
  user    = "pascan_avn",
  password = "8msaUhw6rc",
)

mbhl_bootstrap_client(con)
# → Crée tous les schemas, tables et données de référence

mbhl_check_setup(con)        # → Confirme que tout est en ordre

mbhl_client_info(con)        # résumé de l'état

