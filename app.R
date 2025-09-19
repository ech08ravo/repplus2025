library(shiny)
library(OpenRepGrid)
library(DT)

# Define UI ----
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .container-fluid {
        max-width: 1400px;
      }
      .dataTables_wrapper {
        overflow-x: auto;
      }
    "))
  ),
  titlePanel("RepGrid Elicitation"),
  sidebarLayout(
    sidebarPanel(
      actionButton("load_sample", "Load Sample Data"),
      tags$hr(),
      # Element inputs
      textInput("element_name", "Enter element name:"),
      actionButton("add_element", "Add element"),
      tags$hr(),
      # Bipolar construct inputs
      textInput("construct_left",  "Enter left pole label:"),
      textInput("construct_right", "Enter right pole label:"),
      actionButton("add_construct", "Add construct"),
      tags$hr(),
      # Rating inputs
      selectInput("rating_element",   "Select element:",   choices = NULL),
      selectInput("rating_construct", "Select construct:", choices = NULL),
      sliderInput("rating_score",     "Rating:",           min = 1, max = 7, value = 4),
      actionButton("add_rating",     "Add rating"),
      tags$hr(),
      # Ratings table with delete
      DTOutput("ratings_table"),
      actionButton("remove_rating", "Remove selected rating"),
      tags$hr(),
      # Analyse trigger
      actionButton("analyze", "Analyze Grid"),
      tags$hr(),
      # Download
      downloadButton("download_grid", "Download Grid as CSV")
    , width = 3),
    mainPanel(
      h4("Elements List"),
      uiOutput("elements_ui"),
      h4("Constructs List"),
      uiOutput("constructs_ui"),
      tags$hr(),
      h4("Analysis Summary"),
      verbatimTextOutput("analysis_summary"),
      h4("Construct Biplot"),
      plotOutput("construct_plot")
    , width = 9)
  )
)

# Define server logic ----
server <- function(input, output, session) {
  rv <- reactiveValues(
    elements   = character(),
    constructs = data.frame(left=character(), right=character(), stringsAsFactors=FALSE),
    ratings    = data.frame(element=character(), construct=character(), rating=numeric(), stringsAsFactors=FALSE)
  )
  
  # Load sample data
  observeEvent(input$load_sample, {
    rv$elements <- c("e1", "e2", "e3")
    rv$constructs <- data.frame(
      left = c("left", "black", "high"),
      right = c("right", "white", "low"),
      stringsAsFactors = FALSE
    )
    # Sample ratings: one rating per element-construct pair
    rv$ratings <- data.frame(
      element = rep(rv$elements, times = nrow(rv$constructs)),
      construct = rep(paste(rv$constructs$left, "-", rv$constructs$right), each = length(rv$elements)),
      rating = c(4,2,6, 5,3,7, 6,4,2), # example ratings e1-e3 for each construct
      stringsAsFactors = FALSE
    )
  })
  
  # Add element
  observeEvent(input$add_element, {
    req(input$element_name)
    rv$elements <- c(rv$elements, input$element_name)
    updateTextInput(session, "element_name", value = "")
  })
  
  # Add construct
  observeEvent(input$add_construct, {
    req(input$construct_left, input$construct_right)
    rv$constructs <- rbind(rv$constructs,
                           data.frame(left=input$construct_left,
                                      right=input$construct_right,
                                      stringsAsFactors=FALSE))
    updateTextInput(session, "construct_left",  value="")
    updateTextInput(session, "construct_right", value="")
  })
  
  # Update rating dropdowns
  observe({
    updateSelectInput(session, "rating_element", choices = rv$elements)
    construct_labels <- if(nrow(rv$constructs)>0) {
      paste(rv$constructs$left, "-", rv$constructs$right)
    } else character()
    updateSelectInput(session, "rating_construct", choices = construct_labels)
  })
  
  # Add rating
  observeEvent(input$add_rating, {
    req(input$rating_element, input$rating_construct, input$rating_score)
    rv$ratings <- rbind(rv$ratings,
                        data.frame(element=input$rating_element,
                                   construct=input$rating_construct,
                                   rating=input$rating_score,
                                   stringsAsFactors=FALSE))
  })
  
  # Render elements and constructs lists
  output$elements_ui <- renderUI({
    if(length(rv$elements)==0) p("No elements yet.")
    else tags$ul(lapply(rv$elements, tags$li))
  })
  output$constructs_ui <- renderUI({
    if(nrow(rv$constructs)==0) p("No constructs yet.")
    else tags$ul(lapply(seq_len(nrow(rv$constructs)), function(i) tags$li(
      paste(rv$constructs$left[i], "-", rv$constructs$right[i])
    )))
  })
  
  # Render ratings table with selection
  output$ratings_table <- renderDT({
    datatable(rv$ratings, selection = 'single', rownames = FALSE,
              options = list(scrollX = TRUE, autoWidth = TRUE, pageLength = 15))
  })
  
  # Remove selected rating
  observeEvent(input$remove_rating, {
    sel <- input$ratings_table_rows_selected
    if(length(sel)) {
      rv$ratings <- rv$ratings[-sel, , drop=FALSE]
    }
  })
  
  # Analyse grid
  observeEvent(input$analyze, {
    req(nrow(rv$ratings)>0)
    # build score matrix
    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)
    n_elem <- length(rv$elements)
    n_const <- length(construct_labels)
    scores_mat <- matrix(NA, nrow=n_elem, ncol=n_const)
    for(i in seq_len(n_elem)) {
      for(j in seq_len(n_const)) {
        scores_mat[i,j] <- rv$ratings$rating[
          rv$ratings$element==rv$elements[i] & rv$ratings$construct==construct_labels[j]
        ][1]
      }
    }
    scores_vec <- as.vector(t(scores_mat))
    args <- list(name=rv$elements,
                 l.name=rv$constructs$left,
                 r.name=rv$constructs$right,
                 scores=scores_vec)
    repgrid_obj <- makeRepgrid(args)
    output$analysis_summary <- renderPrint(summary(repgrid_obj))
    output$construct_plot <- renderPlot({
      # Only plot if at least 3 elements AND 3 constructs
      if(length(rv$elements) < 3 || nrow(rv$constructs) < 3) {
        plot.new()
        text(0.5, 0.5,
             "Need at least 3 elements and 3 constructs for a 2D biplot",
             cex = 1.2)
      } else {
        # Default biplot, no cex override
        biplot2d(repgrid_obj, cex = 1)
      }
    })
  })
  
  # Download handler
  output$download_grid <- downloadHandler(
    filename = function() paste0("repgrid-", Sys.Date(), ".csv"),
    content  = function(file) write.csv(rv$ratings, file, row.names=FALSE)
  )
}

# Run the app
shinyApp(ui=ui, server=server)
