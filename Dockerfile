# WebGrid.Online Dockerfile
FROM rocker/shiny:4.5.3

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('shiny', 'OpenRepGrid', 'jsonlite', 'httr2', 'DT', 'uuid', 'igraph'), repos='https://cran.rstudio.com/')"

# Copy Shiny Server config (idle timeout, sanitized errors)
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

# Copy app files
COPY app.R /srv/shiny-server/webgrid/app.R
COPY R/ /srv/shiny-server/webgrid/R/
COPY dataExamples/ /srv/shiny-server/webgrid/dataExamples/

# Manual text used as RAG context for the Ask Claude buttons. Without these,
# load_repplus_docs() (R/claude_api.R) finds nothing and the tryCatch in app.R
# silently falls back to an empty list, so questions go to the API with no
# manual context. Only the .txt files are read - the PDFs are not needed.
COPY RepPlusDocs/*.txt /srv/shiny-server/webgrid/RepPlusDocs/

# Entrypoint that promotes whitelisted container env vars into R's
# Renviron.site so R sessions spawned by shiny-server can see them
# (shiny-server does not propagate env to its R workers).
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set permissions
RUN chown -R shiny:shiny /srv/shiny-server/webgrid

# Expose port
EXPOSE 3838

# Run Shiny Server via the entrypoint
CMD ["/usr/local/bin/docker-entrypoint.sh"]
