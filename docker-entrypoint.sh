#!/bin/sh
# At container start, copy whitelisted environment variables into
# /usr/local/lib/R/etc/Renviron.site so R sessions spawned by shiny-server
# can see them. Shiny-server (open source) does not propagate the container
# env to its R workers, so without this step Sys.getenv("ANTHROPIC_API_KEY")
# returns "" inside the app even when the var is set in the container.

set -e

RENV_SITE="/usr/local/lib/R/etc/Renviron.site"

# Reset Renviron.site each start so removing a key from .env removes it from R.
: > "$RENV_SITE"

for var in ANTHROPIC_API_KEY; do
  val=$(printenv "$var" || true)
  if [ -n "$val" ]; then
    echo "$var=$val" >> "$RENV_SITE"
  fi
done

chmod 644 "$RENV_SITE"

exec /usr/bin/shiny-server
