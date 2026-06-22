# =============================================================================
# FOS Data Explorer - Configuration Management
# =============================================================================
# Loads and validates environment configuration from .env file
# Modified from fos-data-explorer
# =============================================================================

#' Load environment variables from .env file
#' @param env_file Path to .env file (default: .env in project root)
#' @return Named list of configuration values
load_config <- function(env_file = NULL) {
  if (is.null(env_file)) {
    # Look for .env in project root
    env_file <- file.path(get_project_root(), ".env")
  }

  if (!file.exists(env_file)) {
    stop(sprintf("Configuration file not found: %s\nCopy .env.example to .env and configure.", env_file))
  }

  # Read and parse .env file
  lines <- readLines(env_file, warn = FALSE)
  lines <- lines[!grepl("^\\s*#", lines)]  # Remove comments

  lines <- lines[nchar(trimws(lines)) > 0]  # Remove empty lines

  config <- list()
  for (line in lines) {
    if (grepl("=", line)) {
      parts <- strsplit(line, "=", fixed = TRUE)[[1]]
      key <- trimws(parts[1])
      value <- trimws(paste(parts[-1], collapse = "="))
      # Remove surrounding quotes if present
      value <- gsub("^['\"]|['\"]$", "", value)
      config[[key]] <- value
    }
  }

  # Convert known integer fields
  int_fields <- c("ORACLE_PORT", "ORACLE_FETCH_SIZE", "SHINY_PORT", "SHINY_MAX_CONNECTIONS")
  for (field in int_fields) {
    if (!is.null(config[[field]])) {
      config[[field]] <- as.integer(config[[field]])
    }
  }

  config
}

#' Get project root directory
#' @return Absolute path to project root
get_project_root <- function() {
  # Try to find project root by looking for marker files
  markers <- c(".env", ".env.example", "R", "sql")

  path <- getwd()
  while (path != dirname(path)) {  # Stop at filesystem root
    has_markers <- sapply(markers, function(m) file.exists(file.path(path, m)))
    if (sum(has_markers) >= 2) {
      return(path)
    }
    path <- dirname(path)
  }

  # Fall back to working directory
  getwd()
}

#' Validate configuration has required keys
#' @param config Configuration list from load_config()
#' @param required Character vector of required key names
#' @return TRUE if valid, otherwise stops with error
validate_config <- function(config, required) {
  missing <- setdiff(required, names(config))
  if (length(missing) > 0) {
    stop(sprintf("Missing required configuration keys: %s", paste(missing, collapse = ", ")))
  }
  TRUE
}

#' Get Oracle connection configuration
#' @param config Configuration list
#' @return List with Oracle connection parameters
get_oracle_config <- function(config) {
  required <- c("ORACLE_HOST", "ORACLE_PORT", "ORACLE_USERNAME", "ORACLE_SCHEMA")
  validate_config(config, required)

  # Prompt for password securely
  if (!requireNamespace("getPass", quietly = TRUE)) {
    stop("Package 'getPass' is required. Install with install.packages('getPass')")
  }

  password <- getPass::getPass("Enter Oracle password: ")

  list(
    host = config$ORACLE_HOST,
    port = config$ORACLE_PORT,
    service_name = config$ORACLE_SERVICE_NAME,
    sid = config$ORACLE_SID,
    schema = config$ORACLE_SCHEMA,
    username = config$ORACLE_USERNAME,
    password = password,   # <-- not stored in config
    fetch_size = config$ORACLE_FETCH_SIZE %||% 50000L,
    odbc_driver = config$ORACLE_ODBC_DRIVER,
    odbc_dsn = config$ORACLE_ODBC_DSN,
    jdbc_jar = config$ORACLE_JDBC_JAR
  )
}
