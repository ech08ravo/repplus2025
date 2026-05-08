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

# Set permissions
RUN chown -R shiny:shiny /srv/shiny-server/webgrid

# Expose port
EXPOSE 3838

# Run Shiny Server
CMD ["/usr/bin/shiny-server"]
