#!/usr/bin/env Rscript
# Deploy to the shinyapps.io backup site.
#
# appId is pinned here on purpose. rsconnect normally remembers which app to
# update in rsconnect/, but that directory is gitignored, so it exists only on
# the machine that first deployed. Without the id, a deploy from a fresh clone,
# from the server, or from a colleague's machine would CREATE A SECOND APP at a
# new URL rather than updating this one - quietly, and only obvious afterwards.
# Naming the id makes any clone update the right app.
#
# The account secret is not here; it lives in ~/.rsconnect on the deploying
# machine, set once with rsconnect::setAccountInfo().
#
# Usage:  Rscript deploy_shinyapps.R

suppressMessages(library(rsconnect))

APP_NAME <- "repplus2025"
ACCOUNT  <- "ech08ravo"
SERVER   <- "shinyapps.io"
APP_ID   <- 16110826          # https://ech08ravo.shinyapps.io/repplus2025/

accts <- accounts()
if (!any(accts$name == ACCOUNT & accts$server == SERVER)) {
  stop("No shinyapps.io credentials for '", ACCOUNT, "' on this machine.\n",
       "  Set them once with rsconnect::setAccountInfo(name=, token=, secret=)\n",
       "  from https://www.shinyapps.io/admin/#/tokens", call. = FALSE)
}

app_version <- sub('.*"(.*)".*', "\\1",
                   grep("^APP_VERSION <-", readLines("app.R"), value = TRUE)[1])
cat("Deploying v", app_version, " to ", ACCOUNT, "/", APP_NAME,
    " (appId ", APP_ID, ")\n", sep = "")

deployApp(
  appDir        = ".",
  appName       = APP_NAME,
  appId         = APP_ID,
  account       = ACCOUNT,
  server        = SERVER,
  forceUpdate   = TRUE,
  launch.browser = FALSE,
  logLevel      = "normal"
)

cat("\nDeployed. Verify at https://", ACCOUNT, ".shinyapps.io/", APP_NAME, "/\n", sep = "")
