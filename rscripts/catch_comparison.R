# catch_comparison.R
# Erika Anderson
# created 2026-06
# compares in-season and fisher reported catch estimates

#load libraries
library(DBI)
library(ROracle)
library(getPass)
library(readr)

#define parameters used in scripts
start_date <- "04/01/2020 00:00"
end_date <- "03/31/2021 23:59"
ATIP_SAFE <- "N"
pfma_list <- "8,9,10"
fishery_list <- "5,6,7"
# 5 is salmon gillnet
# 6 is salmon seine
# 7 is salmon troll

# load helper functions
rdirectory <- paste0(getwd(), "/rscripts")
source(file.path(rdirectory, "config.R"))
source(file.path(rdirectory, "database_connection.R"))
source(file.path(rdirectory, "utils.R"))


#configure
config <- load_config()

# create connection with Oracle database
oracle_con <- connect_oracle(config)

#test connection
#DBI::dbGetQuery(oracle_con, "SELECT SYSDATE FROM dual")

#read sql code for in-season estimates
in_season_sql <- readr::read_file(
  paste0(getwd(),"/sql/in_season_estimates.sql")
  )

# query in-season estimate data
in_season_df <- query_df(oracle_con, in_season_sql,
               params = list(start_date = start_date,
                             end_date = end_date,
                             ATIP_SAFE = ATIP_SAFE,
                             pfma_list = pfma_list,
                             fishery_list = fishery_list)
)


# # query fisher reported estimate data
# fisher_df <- query_df(oracle_con, fisher_reported_estimates.sql,
#                          params = list(start_date = start_date,
#                                        end_date = end_date,
#                                        pfma_list = pfma_list,
#                                        fishery_list = fishery_list)
# )

#  names(df) <- clean_column_names(names(df))


# close connection
DBI::dbDisconnect(oracle_con)


# fisher reported cacth estimates summed by area and year

# graph both types of catch estimates by year
# seperate areas in different panels

# determine greatest differences between catch estimates
# from same year and area
# create excel file sorted greatest to least difference

