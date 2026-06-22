# catch_comparison.R
# Erika Anderson
# created 2026-06
# compares in-season and fisher reported catch estimates

#load libraries
library(DBI)
library(ROracle)
library(getPass)
library(readr)

#define parameters used in script
start_date <- "04/01/2020 00:00"
end_date <- "03/31/2021 23:59"
# f_start_date <- "2020-04-01"
# f_end_date <-  "2021-03-31"

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
df <- query_df(oracle_con, in_season_sql,
               params = list(start_date = start_date,
                             end_date = end_date)
)


# # query in-season estimate data
# df <- query_df(oracle_con, "SELECT *
#                  FROM fos_v1_1.fishing_event fe
#                WHERE fe.fe_id = :ID",
#                params = list(ID = 3958560)
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

