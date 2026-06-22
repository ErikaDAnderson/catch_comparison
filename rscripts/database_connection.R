# =============================================================================
# Database Connection Utilities
# =============================================================================
# Provides connection management for Oracle (source)
# Modified from fos-data-explorer
# =============================================================================

library(DBI)

# -----------------------------------------------------------------------------
# Oracle Connection Management
# -----------------------------------------------------------------------------

#' Create Oracle connection
#' @param config Configuration list from load_config()
#' @return Oracle connection object
connect_oracle <- function(config = NULL) {
  if (is.null(config)) {
    config <- load_config()
  }

  oracle_config <- get_oracle_config(config)

  if (!requireNamespace("ROracle", quietly = TRUE)) {
    # Fall back to odbc if ROracle not available
    if (!requireNamespace("odbc", quietly = TRUE)) {
      # Fall back to JDBC if odbc not available
      if (!requireNamespace("RJDBC", quietly = TRUE)) {
        stop("Package 'ROracle', 'odbc', or 'RJDBC' is required for Oracle connectivity.")
      }
      return(connect_oracle_jdbc(oracle_config))
    }

    # Check if ODBC drivers are available before trying ODBC
    tryCatch({
      drivers <- odbc::odbcListDrivers()
      oracle_drivers <- drivers[grepl("oracle", drivers$name, ignore.case = TRUE), ]
      if (nrow(oracle_drivers) == 0 &&
          (is.null(oracle_config$odbc_driver) || nchar(trimws(oracle_config$odbc_driver)) == 0)) {
        # No ODBC drivers available, try JDBC
        if (requireNamespace("RJDBC", quietly = TRUE)) {
          return(connect_oracle_jdbc(oracle_config))
        }
      }
    }, error = function(e) {
      # If ODBC check fails, try JDBC
      if (requireNamespace("RJDBC", quietly = TRUE)) {
        return(connect_oracle_jdbc(oracle_config))
      }
    })

    return(connect_oracle_odbc(oracle_config))
  }

  # Build connection string
  if (!is.null(oracle_config$service_name) && nchar(oracle_config$service_name) > 0) {
    connect_string <- sprintf(
      "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=%s)(PORT=%d))(CONNECT_DATA=(SERVICE_NAME=%s)))",
      oracle_config$host,
      oracle_config$port,
      oracle_config$service_name
    )
  } else if (!is.null(oracle_config$sid) && nchar(oracle_config$sid) > 0) {
    connect_string <- sprintf(
      "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=%s)(PORT=%d))(CONNECT_DATA=(SID=%s)))",
      oracle_config$host,
      oracle_config$port,
      oracle_config$sid
    )
  } else {
    stop("Either ORACLE_SERVICE_NAME or ORACLE_SID must be configured.")
  }

  drv <- DBI::dbDriver("Oracle")
  con <- DBI::dbConnect(
    drv,
    username = oracle_config$username,
    password = oracle_config$password,
    dbname = connect_string
  )

  # Set schema
  DBI::dbExecute(con, sprintf("ALTER SESSION SET CURRENT_SCHEMA = %s", oracle_config$schema))

  con
}

#' Create Oracle connection via ODBC (fallback)
#' @param oracle_config Oracle configuration list
#' @return ODBC connection object
connect_oracle_odbc <- function(oracle_config) {
  if (!requireNamespace("odbc", quietly = TRUE)) {
    stop("Package 'odbc' is required for Oracle ODBC connectivity.")
  }

  resolve_driver_name <- function() {
    if (!is.null(oracle_config$odbc_driver) && nchar(trimws(oracle_config$odbc_driver)) > 0) {
      return(trimws(oracle_config$odbc_driver))
    }
    drivers <- unique(odbc::odbcListDrivers()$name)
    oracle_drivers <- drivers[grepl("oracle", drivers, ignore.case = TRUE)]
    if (length(oracle_drivers) == 0) {
      stop("No Oracle ODBC driver found. Set ORACLE_ODBC_DRIVER in .env to the installed driver name.")
    }
    oracle_drivers[1]
  }

  db_target <- oracle_config$service_name %||% oracle_config$sid
  if (is.null(db_target) || nchar(trimws(db_target)) == 0) {
    stop("Either ORACLE_SERVICE_NAME or ORACLE_SID must be configured for ODBC connection.")
  }

  if (!is.null(oracle_config$odbc_dsn) && nchar(trimws(oracle_config$odbc_dsn)) > 0) {
    con <- DBI::dbConnect(
      odbc::odbc(),
      dsn = trimws(oracle_config$odbc_dsn),
      uid = oracle_config$username,
      pwd = oracle_config$password
    )
    return(con)
  }

  driver_name <- resolve_driver_name()
  dbq_candidates <- c(
    sprintf("//%s:%d/%s", oracle_config$host, oracle_config$port, db_target),
    sprintf("%s:%d/%s", oracle_config$host, oracle_config$port, db_target)
  )

  last_error <- NULL
  for (dbq in dbq_candidates) {
    try_result <- tryCatch(
      DBI::dbConnect(
        odbc::odbc(),
        Driver = driver_name,
        DBQ = dbq,
        UID = oracle_config$username,
        PWD = oracle_config$password
      ),
      error = function(e) {
        last_error <<- e
        NULL
      }
    )
    if (!is.null(try_result)) {
      return(try_result)
    }
  }

  stop(sprintf(
    "Oracle ODBC connection failed using driver '%s'. Last error: %s",
    driver_name,
    if (!is.null(last_error)) last_error$message else "Unknown error"
  ))
}

#' Create Oracle connection via JDBC (fallback)
#' @param oracle_config Oracle configuration list
#' @return JDBC connection object
connect_oracle_jdbc <- function(oracle_config) {
  if (!requireNamespace("RJDBC", quietly = TRUE)) {
    stop("Package 'RJDBC' is required for Oracle JDBC connectivity.")
  }

  # Find JDBC driver JAR file
  jdbc_jar <- oracle_config$jdbc_jar
  if (is.null(jdbc_jar) || !file.exists(jdbc_jar)) {
    # Try to find ojdbc jar in Oracle Instant Client directory
    instant_client_dir <- Sys.getenv("ORACLE_HOME")
    if (nchar(instant_client_dir) == 0) {
      instant_client_dir <- file.path(Sys.getenv("HOME"), "oracle", "instantclient_23_9")
    }

    # Look for ojdbc8.jar (compatible with Java 8+)
    jdbc_candidates <- c(
      file.path(instant_client_dir, "ojdbc8.jar"),
      file.path(instant_client_dir, "ojdbc11.jar"),
      file.path(instant_client_dir, "ojdbc17.jar")
    )

    jdbc_jar <- NULL
    for (jar in jdbc_candidates) {
      if (file.exists(jar)) {
        jdbc_jar <- jar
        break
      }
    }

    if (is.null(jdbc_jar)) {
      stop(sprintf(
        "Oracle JDBC driver JAR not found. Set ORACLE_JDBC_JAR in .env or place ojdbc*.jar in %s",
        instant_client_dir
      ))
    }
  }

  # Create JDBC driver
  drv <- RJDBC::JDBC("oracle.jdbc.OracleDriver", jdbc_jar)

  # Build JDBC connection URL
  if (!is.null(oracle_config$service_name) && nchar(oracle_config$service_name) > 0) {
    jdbc_url <- sprintf(
      "jdbc:oracle:thin:@%s:%d/%s",
      oracle_config$host,
      oracle_config$port,
      oracle_config$service_name
    )
  } else if (!is.null(oracle_config$sid) && nchar(oracle_config$sid) > 0) {
    jdbc_url <- sprintf(
      "jdbc:oracle:thin:@%s:%d:%s",
      oracle_config$host,
      oracle_config$port,
      oracle_config$sid
    )
  } else {
    stop("Either ORACLE_SERVICE_NAME or ORACLE_SID must be configured for JDBC connection.")
  }

  # Connect
  con <- DBI::dbConnect(
    drv,
    jdbc_url,
    oracle_config$username,
    oracle_config$password
  )

  # Set schema (JDBC doesn't support dbExecute the same way, use dbSendUpdate)
  tryCatch({
    RJDBC::dbSendUpdate(con, sprintf("ALTER SESSION SET CURRENT_SCHEMA = %s", oracle_config$schema))
  }, error = function(e) {
    # Fallback: try with dbGetQuery
    tryCatch({
      DBI::dbGetQuery(con, sprintf("ALTER SESSION SET CURRENT_SCHEMA = %s", oracle_config$schema))
    }, error = function(e2) {
      warning(sprintf("Could not set Oracle schema: %s", e2$message))
    })
  })

  con
}

# -----------------------------------------------------------------------------
# Query Utilities
# -----------------------------------------------------------------------------

#' Execute query and return data frame
#' @param con Database connection
#' @param sql SQL query string
#' @param params Named list of parameters (optional)
#' @return Data frame with query results
query_df <- function(con, sql, params = NULL) {
  if (!is.null(params)) {
    # Simple parameter substitution for named params like :param_name
    for (name in names(params)) {
      pattern <- sprintf(":%s\\b", name)
      value <- params[[name]]
      if (is.character(value)) {
        value <- sprintf("'%s'", gsub("'", "''", value))
      } else if (is.null(value)) {
        value <- "NULL"
      }
      sql <- gsub(pattern, as.character(value), sql)
    }
  }

  DBI::dbGetQuery(con, sql)
}
