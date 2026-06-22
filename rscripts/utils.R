# =============================================================================
#  Utility Functions
# =============================================================================
# Common utility functions used across the application
# Modified from fos-data-explorer
# =============================================================================

#' Log message with timestamp
#' @param msg Message to log
#' @param level Log level: "INFO", "WARN", "ERROR"
log_msg <- function(msg, level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  message(sprintf("[%s] [%s] %s", timestamp, level, msg))
}

#' Log info message
log_info <- function(msg) log_msg(msg, "INFO")

#' Log warning message
log_warn <- function(msg) log_msg(msg, "WARN")

#' Log error message
log_error <- function(msg) log_msg(msg, "ERROR")

#' Safely execute a function with error handling
#' @param expr Expression to evaluate
#' @param on_error Value to return on error (default: NULL)
#' @param log_errors Whether to log errors (default: TRUE)
#' @return Result of expression or on_error value
safe_exec <- function(expr, on_error = NULL, log_errors = TRUE) {
  tryCatch(
    expr,
    error = function(e) {
      if (log_errors) {
        log_error(sprintf("Error: %s", e$message))
      }
      on_error
    }
  )
}

#' Convert Oracle date string to R Date
#' @param date_str Date string from Oracle
#' @param format Date format (default: DD-MON-YY)
#' @return R Date object
parse_oracle_date <- function(date_str, format = "%d-%b-%y") {
  as.Date(date_str, format = format)
}

#' Clean column names to snake_case
#' @param names Character vector of column names
#' @return Character vector with cleaned names
clean_column_names <- function(names) {
  names <- tolower(names)
  names <- gsub("[^a-z0-9]+", "_", names)
  names <- gsub("^_|_$", "", names)
  names
}

#' Map gear type from fishery name
#' @param fishery Fishery name from Oracle
#' @return Standardized gear type
map_gear_type <- function(fishery) {
  dplyr::case_when(
    grepl("seine", fishery, ignore.case = TRUE) ~ "Seine",
    grepl("gill", fishery, ignore.case = TRUE) ~ "Gill net",
    grepl("troll", fishery, ignore.case = TRUE) ~ "Troll",
    TRUE ~ "Other"
  )
}

#' Map licence area from licence ID
#' @param lic_id Licence ID from Oracle
#' @return Licence area name
map_licence_area <- function(lic_id) {
  mapping <- c(
    "5328" = "Seine A",
    "5330" = "Seine B",
    "5332" = "Gillnet C",
    "5334" = "Gillnet D",
    "5336" = "Gillnet E",
    "5338" = "Troll F",
    "5340" = "Troll G",
    "5342" = "Troll H"
  )

  result <- mapping[as.character(lic_id)]
  ifelse(is.na(result), "Other", result)
}

#' Format number with thousands separator
#' @param x Numeric value
#' @param digits Number of decimal places
#' @return Formatted string
format_number <- function(x, digits = 0) {
  format(round(x, digits), big.mark = ",", scientific = FALSE)
}

#' Calculate percentage
#' @param numerator Numerator value
#' @param denominator Denominator value
#' @param digits Number of decimal places
#' @return Percentage value
calc_pct <- function(numerator, denominator, digits = 1) {
  if (is.na(denominator) || denominator == 0) {
    return(NA_real_)
  }
  round(numerator / denominator * 100, digits)
}

#' Coalesce NA values
#' @param x Primary value
#' @param y Fallback value
#' @return x if not NA, otherwise y
coalesce_na <- function(x, y) {
  ifelse(is.na(x), y, x)
}

#' Create timestamp for current UTC time
#' @return POSIXct timestamp in UTC
utc_now <- function() {
  as.POSIXct(Sys.time(), tz = "UTC")
}

#' Validate data frame has required columns
#' @param df Data frame
#' @param required Character vector of required column names
#' @return TRUE if valid, otherwise stops with error
validate_columns <- function(df, required) {
  missing <- setdiff(required, names(df))
  if (length(missing) > 0) {
    stop(sprintf("Missing required columns: %s", paste(missing, collapse = ", ")))
  }
  TRUE
}

#' Species codes to names mapping
SPECIES_MAP <- c(
  "118" = "Sockeye",
  "115" = "Coho",
  "108" = "Pink",
  "112" = "Chum",
  "124" = "Chinook",
  "128" = "Steelhead"
)

#' Map species code to name
#' @param code Species code
#' @return Species name
map_species <- function(code) {
  result <- SPECIES_MAP[as.character(code)]
  ifelse(is.na(result), as.character(code), result)
}