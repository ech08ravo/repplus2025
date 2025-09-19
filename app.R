library(shiny)
library(OpenRepGrid)
library(DT)
library(uuid)

# Source the focus analysis functions
source("R/focus_analysis.R")

ui <- fluidPage(
  tags$head(tags$style(HTML('
    .container-fluid { max-width: 1400px; }
    .dataTables_wrapper { overflow-x: auto; }
  '))),
  titlePanel("RepGrid Elicitation"),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      fileInput("rgrid_file", "Import .rgrid", accept = ".rgrid"),
      actionButton("import_rgrid", "Load Grid"),
      tags$hr(),
      actionButton("load_sample", "Load Sample Data"),
      tags$hr(),
      textInput("element_name", "Enter element name:"),
      actionButton("add_element", "Add element"),
      tags$hr(),
      textInput("construct_left",  "Enter left pole label:"),
      textInput("construct_right", "Enter right pole label:"),
      actionButton("add_construct", "Add construct"),
      tags$hr(),
      selectInput("rating_element",   "Select element:",   choices = NULL),
      selectInput("rating_construct", "Select construct:", choices = NULL),
      sliderInput("rating_score", "Rating:", min = 1, max = 7, value = 4),
      actionButton("add_rating", "Add rating"),
      tags$hr(),
      DTOutput("ratings_table"),
      actionButton("remove_rating", "Remove selected rating"),
      tags$hr(),
      checkboxInput("impute_missing", "Impute missing ratings (use 4)", value = FALSE),
      selectInput("col_elements", "Element color", choices = c("black","blue","red","darkgreen","purple"), selected = "blue"),
      selectInput("col_constructs", "Construct color", choices = c("black","red","orange","darkgreen","brown"), selected = "red"),
      selectInput(
        "heat_palette", "Heatmap palette",
        choices = c("Blue-White-Red", "Greys", "Terrain"),
        selected = "Blue-White-Red"
      ),
      actionButton("analyze", "Analyze Grid"),
      tags$hr(),
      downloadButton("download_grid", "Download Grid as CSV"),
      downloadButton("download_rgrid", "Download Grid as .rgrid")
    ),
    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel(
          "Summary & Biplot",
          h4("Elements List"), uiOutput("elements_ui"),
          h4("Constructs List"), uiOutput("constructs_ui"),
          tags$hr(), h4("Missing Ratings"), tableOutput("missing_table"),
          tags$hr(), h4("Analysis Summary"), verbatimTextOutput("analysis_summary"),
          h4("PCA Biplot (colored)"), plotOutput("pca_biplot")
        ),
        tabPanel("Heatmap", plotOutput("heatmap_plot", height = 500)),
        tabPanel("Element Dendrogram", plotOutput("dend_elements")),
        tabPanel("Construct Dendrogram", plotOutput("dend_constructs"))
      )
    )
  )
)

server <- function(input, output, session) {
  rv <- reactiveValues(
    elements = character(),
    constructs = data.frame(
      left = character(),
      right = character(),
      stringsAsFactors = FALSE
    ),
    ratings = data.frame(
      element = character(),
      construct = character(),
      rating = numeric(),
      stringsAsFactors = FALSE
    ),
    scores_mat_last = NULL,
    repgrid_last = NULL
  )

  # Load sample data (elements, constructs, ratings)
  observeEvent(input$load_sample, {
    rv$elements <- c("e1", "e2", "e3")
    rv$constructs <- data.frame(
      left = c("left", "black", "high"),
      right = c("right", "white", "low"),
      stringsAsFactors = FALSE
    )
    rv$ratings <- data.frame(
      element = rep(rv$elements, times = nrow(rv$constructs)),
      construct = rep(
        paste(rv$constructs$left, "-", rv$constructs$right),
        each = length(rv$elements)
      ),
      rating = c(4, 2, 6, 5, 3, 7, 6, 4, 2),
      stringsAsFactors = FALSE
    )
  })

  # Add element / construct / rating
  observeEvent(input$add_element, {
    req(input$element_name)
    rv$elements <- c(rv$elements, input$element_name)
    updateTextInput(session, "element_name", value = "")
  })

  observeEvent(input$add_construct, {
    req(input$construct_left, input$construct_right)
    rv$constructs <- rbind(
      rv$constructs,
      data.frame(
        left = input$construct_left,
        right = input$construct_right,
        stringsAsFactors = FALSE
      )
    )
    updateTextInput(session, "construct_left", value = "")
    updateTextInput(session, "construct_right", value = "")
  })

  observe({
    updateSelectInput(session, "rating_element", choices = rv$elements)
    construct_labels <- if (nrow(rv$constructs) > 0) {
      paste(rv$constructs$left, "-", rv$constructs$right)
    } else {
      character()
    }
    updateSelectInput(session, "rating_construct", choices = construct_labels)
  })

  compute_missing <- reactive({
    if (length(rv$elements) == 0 || nrow(rv$constructs) == 0) return(NULL)
    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)
    all_pairs <- expand.grid(element = rv$elements, construct = construct_labels, stringsAsFactors = FALSE)
    key <- paste(rv$ratings$element, rv$ratings$construct, sep = "||")
    all_key <- paste(all_pairs$element, all_pairs$construct, sep = "||")
    missing_idx <- !(all_key %in% key)
    if (!any(missing_idx)) return(NULL)
    all_pairs[missing_idx, , drop = FALSE]
  })

  output$missing_table <- renderTable({ compute_missing() }, rownames = FALSE)

  observeEvent(input$add_rating, {
    req(input$rating_element, input$rating_construct, input$rating_score)
    rv$ratings <- rbind(
      rv$ratings,
      data.frame(
        element = input$rating_element,
        construct = input$rating_construct,
        rating = input$rating_score,
        stringsAsFactors = FALSE
      )
    )
  })

  # UI lists & ratings table
  output$elements_ui <- renderUI({
    if (length(rv$elements) == 0) p("No elements yet.")
    else tags$ul(lapply(rv$elements, tags$li))
  })

  output$constructs_ui <- renderUI({
    if (nrow(rv$constructs) == 0) p("No constructs yet.")
    else tags$ul(lapply(seq_len(nrow(rv$constructs)), function(i) {
      tags$li(paste(rv$constructs$left[i], "-", rv$constructs$right[i]))
    }))
  })

  output$ratings_table <- renderDT({
    datatable(
      rv$ratings,
      selection = "single",
      rownames = FALSE,
      options = list(scrollX = TRUE, autoWidth = TRUE, pageLength = 15)
    )
  })

  observeEvent(input$remove_rating, {
    sel <- input$ratings_table_rows_selected
    if (length(sel)) {
      rv$ratings <- rv$ratings[-sel, , drop = FALSE]
    }
  })

  # Import .rgrid (robust parser for multiple formats)
  observeEvent(input$import_rgrid, {
    req(input$rgrid_file)
    txt <- readLines(
      input$rgrid_file$datapath,
      warn = FALSE,
      encoding = "UTF-8"
    )

    # Parse constructs (lines starting with C) – take last two non-empty fields
    c_lines <- grep("^C\\d+\\t", txt, value = TRUE)
    if (length(c_lines) == 0) return(NULL)
    cons_split <- lapply(c_lines, function(l) {
      toks <- strsplit(l, "\t")[[1]]
      toks[nzchar(toks)]
    })
    left <- vapply(
      cons_split,
      function(p) if (length(p) >= 2) p[length(p) - 1] else NA_character_,
      character(1)
    )
    right <- vapply(
      cons_split,
      function(p) if (length(p) >= 1) p[length(p)] else NA_character_,
      character(1)
    )
    n_c <- length(left)

    # Parse elements (lines starting with E) – name last; scores are last n_c before name
    e_lines <- grep("^E\\d+\\t", txt, value = TRUE)
    if (length(e_lines) == 0) return(NULL)
    n_e <- length(e_lines)
    elements <- character(n_e)
    scores_mat <- matrix(NA_real_, nrow = n_e, ncol = n_c)

    for (i in seq_len(n_e)) {
      toks <- strsplit(e_lines[i], "\t")[[1]]
      toks <- toks[nzchar(toks)]
      if (length(toks) < (n_c + 1)) next
      elements[i] <- toks[length(toks)]
      start <- (length(toks) - 1) - n_c + 1
      end   <- length(toks) - 1
      if (start >= 1 && end >= start) {
        sc <- suppressWarnings(as.numeric(toks[start:end]))
        scores_mat[i, ] <- sc
      }
    }

    rv$elements <- elements
    rv$constructs <- data.frame(
      left = left,
      right = right,
      stringsAsFactors = FALSE
    )
    labels <- paste(left, "-", right)
    rv$ratings <- data.frame(
      element   = rep(elements, times = n_c),
      construct = rep(labels,   each  = n_e),
      rating    = as.vector(scores_mat),
      stringsAsFactors = FALSE
    )
  })

  # Analyze
  observeEvent(input$analyze, {
    req(nrow(rv$ratings) > 0)
    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)
    n_e <- length(rv$elements)
    n_c <- length(construct_labels)
    scores_mat <- matrix(NA_real_, nrow = n_e, ncol = n_c)

    for (i in seq_len(n_e)) {
      for (j in seq_len(n_c)) {
        match_idx <- rv$ratings$element == rv$elements[i] &
          rv$ratings$construct == construct_labels[j]
        scores_mat[i, j] <- rv$ratings$rating[match_idx][1]
      }
    }

    # Handle missing values: abort (strict) or impute midpoint
    if (any(is.na(scores_mat))) {
      if (!isTRUE(input$impute_missing)) {
        output$analysis_summary <- renderPrint({
          cat(
            "Analysis aborted: some ratings are missing.\n",
            "Tick 'Impute missing ratings (use 4)' or complete all ratings."
          )
        })
        output$pca_biplot <- renderPlot({
          plot.new()
          text(
            0.5, 0.5,
            "Missing ratings detected – complete grid or enable imputation",
            cex = 1.1
          )
        })
        output$dend_elements <- renderPlot({
          plot.new()
          text(
            0.5, 0.5,
            "Missing ratings detected – complete grid or enable imputation",
            cex = 1.1
          )
        })
        output$dend_constructs <- renderPlot({
          plot.new()
          text(
            0.5, 0.5,
            "Missing ratings detected – complete grid or enable imputation",
            cex = 1.1
          )
        })
        return()
      } else {
        scores_mat[is.na(scores_mat)] <- 4
        imputed <- TRUE
      }
    } else {
      imputed <- FALSE
    }

    rv$scores_mat_last <- scores_mat

    scores_vec <- as.vector(t(scores_mat))
    repgrid_obj <- makeRepgrid(list(
      name = rv$elements,
      l.name = rv$constructs$left,
      r.name = rv$constructs$right,
      scores = scores_vec
    ))

    rv$repgrid_last <- repgrid_obj

    output$analysis_summary <- renderPrint({
      if (isTRUE(imputed)) {
        cat("Note: Missing ratings were imputed with 4 (midpoint).\n\n")
      }
      print(summary(repgrid_obj))
    })

    output$pca_biplot <- renderPlot({
      sm <- rv$scores_mat_last
      if (is.null(sm)) return()
      # PCA on elements (rows)
      pc <- prcomp(sm, scale. = TRUE)
      ex <- pc$x[, 1:2]
      # construct loadings (approx via correlations)
      load <- cor(sm, pc$x)[, 1:2]
      plot(ex, type = "n", xlab = "PC1", ylab = "PC2")
      points(ex, pch = 19, col = input$col_elements)
      text(ex, labels = rv$elements, pos = 3, col = input$col_elements)
      # arrows for constructs
      arrows(0, 0, load[,1], load[,2], length = 0.1, col = input$col_constructs)
      text(load[,1], load[,2], labels = paste(rv$constructs$left, "-", rv$constructs$right),
           pos = 4, col = input$col_constructs)
      abline(h = 0, v = 0, lty = 3)
    })

    output$heatmap_plot <- renderPlot({
      sm <- rv$scores_mat_last
      if (is.null(sm)) return()
      # Build palette
      pal <- switch(
        input$heat_palette,
        "Blue-White-Red" = colorRampPalette(c("#2166AC", "#FFFFFF", "#B2182B"))(100),
        "Greys" = gray.colors(100, start = 0.95, end = 0.2),
        "Terrain" = terrain.colors(100)
      )
      # Flip rows so first element appears at top
      z <- t(sm[nrow(sm):1, , drop = FALSE])
      image(
        x = 1:ncol(sm), y = 1:nrow(sm), z = z,
        col = pal, axes = FALSE, xlab = "Elements", ylab = "Constructs"
      )
      axis(1, at = 1:ncol(sm), labels = rv$elements, las = 2, cex.axis = 0.8)
      labs <- paste(rv$constructs$left, "-", rv$constructs$right)
      axis(2, at = 1:nrow(sm), labels = rev(labs), las = 2, cex.axis = 0.8)
      box()
    })

    output$dend_elements <- renderPlot({
      sm <- rv$scores_mat_last
      if (is.null(sm) || nrow(sm) < 2) return()
      hc <- hclust(dist(sm))
      plot(hc, main = "Elements", xlab = "", sub = "")
    })

    output$dend_constructs <- renderPlot({
      sm <- rv$scores_mat_last
      if (is.null(sm) || ncol(sm) < 2) return()
      hc <- hclust(dist(t(sm)))
      labs <- paste(rv$constructs$left, "-", rv$constructs$right)
      plot(hc, labels = labs, main = "Constructs", xlab = "", sub = "")
    })
  })

  # Downloads
  output$download_grid <- downloadHandler(
    filename = function() paste0("repgrid-", Sys.Date(), ".csv"),
    content = function(file) {
      write.csv(rv$ratings, file, row.names = FALSE)
    }
  )

  output$download_rgrid <- downloadHandler(
    filename = function() paste0("grid-", Sys.Date(), ".rgrid"),
    content = function(file) {
      con <- file(file, open = "w", encoding = "UTF-8")
      on.exit(close(con), add = TRUE)

      nE <- length(rv$elements)
      nC <- nrow(rv$constructs)
      nR <- nrow(rv$ratings)
      now <- Sys.time()
      hdr <- paste(
        "", "Grid", nE, nC, nR, "YourTitle", "", "1",
        format(Sys.Date(), "%d-%b-%Y"), format(now, "%H:%M"),
        "local", "Rep IV 2.00", "RepGrid",
        sep = "\t"
      )
      writeLines(hdr, con)

      for (i in seq_len(nC)) {
        L <- rv$constructs$left[i]
        R <- rv$constructs$right[i]
        writeLines(paste0(
          "C", i - 1, "\tR\t100\t0\t1\t1\t5\t", L, "\t", R, "\t"
        ), con)
      }

      construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)
      scores_mat <- matrix(NA, nrow = nE, ncol = nC)
      for (e in seq_len(nE)) {
        for (c in seq_len(nC)) {
          match_idx <- rv$ratings$element == rv$elements[e] &
            rv$ratings$construct == construct_labels[c]
          scores_mat[e, c] <- rv$ratings$rating[match_idx][1]
        }
      }

      for (e in seq_len(nE)) {
        row <- paste0(
          "E", e - 1, "\t100\t0\t1\t1\t4\t",
          paste(scores_mat[e, ], collapse = "\t"), "\t",
          rv$elements[e]
        )
        writeLines(row, con)
      }

      writeLines(paste("_UID", uuid::UUIDgenerate(), sep = "\t"), con)
      writeLines(paste("_Date", format(Sys.Date(), "%d-%b-%Y"), sep = "\t"), con)
      writeLines(paste("_Time", format(now, "%H:%M"), sep = "\t"), con)
    }
  )
}

shinyApp(ui, server)
