# catch_comparison.R
# Erika Anderson
# created 2026-06
# compares in-season and fisher reported catch estimates

#load libraries
library(DBI)
library(ROracle)
library(getPass)
library(readr)
library(dplyr)
library(ggplot2)
library(tidyr)

#define parameters used in scripts
start_date <- "04/01/2020 00:00"
end_date <- "03/31/2025 23:59"
ATIP_SAFE <- "N"
pfma_list <- "23,101"
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

#read sql code
in_season_sql <- readr::read_file(
  paste0(getwd(),"/sql/in_season_estimates.sql")
  )

fisher_reported_sql <- readr::read_file(
  paste0(getwd(),"/sql/fisher_reported_estimates.sql")
)

# query in-season estimate data
in_season_df <- query_df(oracle_con, in_season_sql,
               params = list(start_date = start_date,
                             end_date = end_date,
                             ATIP_SAFE = ATIP_SAFE,
                             pfma_list = pfma_list,
                             fishery_list = fishery_list)
)

# query fisher reported estimate data
fisher_df <- query_df(oracle_con, fisher_reported_sql,
                         params = list(start_date = start_date,
                                       end_date = end_date,
                                       pfma_list = pfma_list,
                                       fishery_list = fishery_list)
)

# close connection
DBI::dbDisconnect(oracle_con)

# graph both types of catch estimates by year
# separate areas in different panels
# combine datasets
combined_df <- bind_rows(in_season_df, fisher_df) %>%
    rename(
    pfma = MGMT_AREA,
    year = CALENDAR_YEAR,
    source= ESTIMATE_TYPE
  ) %>%
    mutate(
    pfma = factor(pfma),
    year = as.numeric(year),
    source = factor(source)
  )


ggplot(combined_df,
       aes(x = year, y = SOCKEYE_KEPT, fill = source)) +
  geom_col(position = position_dodge(width = 0.8)) +
  facet_wrap(~pfma)+
  labs(
    title = "Annual Catch Comparison by Source",
    x = "Year",
    y = "Count",
    fill = "Estimate Source"
  ) +
  theme_minimal() +
  theme(
    strip.text = element_text(face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )


# determine greatest differences between catch estimates
# from same year and area
# create excel file sorted greatest to least difference

