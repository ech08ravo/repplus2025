# RepPlusApp Dockerfile
FROM rocker/shiny:4.4.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install R packages
RUN R -e "install.packages(c('shiny', 'OpenRepGrid', 'jsonlite', 'httr2', 'DT', 'uuid', 'igraph'), repos='https://cran.rstudio.com/')"

# Copy app files
COPY app.R /srv/shiny-server/repplus/app.R
COPY R/ /srv/shiny-server/repplus/R/

# Set permissions
RUN chown -R shiny:shiny /srv/shiny-server/repplus

# Expose port
EXPOSE 3838

# Run Shiny Server
CMD ["/usr/bin/shiny-server"]
