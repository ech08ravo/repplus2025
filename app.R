library(shiny)
library(OpenRepGrid)
library(DT)
library(uuid)

# Source the focus analysis functions
source("R/focus_analysis.r")
source("R/claude_api.R")

ui <- fluidPage(
  tags$head(
    tags$style(HTML('
      .container-fluid { max-width: 1400px; }
      body { font-size: 13px; }
      .form-group { margin-bottom: 8px; }
      .form-control { padding: 4px 8px; height: auto; font-size: 13px; }
      .btn { padding: 4px 10px; font-size: 12px; margin: 2px 0; }
      .btn-sm { padding: 2px 6px; font-size: 11px; }
      label { margin-bottom: 2px; font-size: 12px; }
      h4 { font-size: 16px; margin: 8px 0; }
      h5 { font-size: 14px; margin: 6px 0; }
      p { margin-bottom: 6px; font-size: 13px; }
      hr { margin: 8px 0; }
      .sidebar { padding: 8px; }
      .well { padding: 10px; }
      .dataTables_wrapper { overflow-x: auto; font-size: 12px; }
      .help-btn { margin: 2px 4px 2px 0; }
      .help-content { background: #f8f9fa; padding: 10px; border-radius: 4px; margin-top: 6px; border: 1px solid #dee2e6; font-size: 12px; }
      .help-content h5 { margin-top: 8px; color: #495057; }
      .help-content ul { margin-bottom: 6px; padding-left: 20px; }
      .help-content li { margin-bottom: 3px; }
      .chat-btn { margin: 2px 4px; }
      .chat-panel { background: #e7f3ff; padding: 10px; border-radius: 4px; margin-top: 6px; border: 1px solid #b3d7ff; }
      .elicit-panel { background: #fff8e6; padding: 10px; border-radius: 4px; border: 1px solid #ffc107; margin-bottom: 10px; }
      .elicit-panel h4 { margin-top: 0; }
      .elicit-panel h5 { color: #856404; margin-top: 0; font-size: 13px; }
      .elicit-panel p { margin-bottom: 8px; }
      .elicit-section { background: #fffdf5; padding: 8px; border-radius: 4px; margin-bottom: 6px; }
      .elicit-section hr { margin: 6px 0; }
      .elicit-section textarea { font-size: 11px; }
      .chat-response { background: #fff; padding: 10px; border: 1px solid #ccc; border-radius: 4px; margin-top: 6px; white-space: pre-wrap; max-height: 300px; overflow-y: auto; font-size: 12px; }
      .chat-error { background: #fee; padding: 8px; border: 1px solid #fcc; border-radius: 4px; color: #c00; margin-top: 6px; font-size: 12px; }
      .chat-loading { color: #666; font-style: italic; padding: 6px; font-size: 12px; }
      .copy-success { color: #28a745; font-weight: bold; margin-left: 6px; font-size: 11px; }
      .btn-group-chat { display: flex; gap: 4px; margin-top: 6px; flex-wrap: wrap; }
      .shiny-input-container { margin-bottom: 6px; }
      .selectize-input { padding: 4px 8px; min-height: 28px; font-size: 12px; }
      .slider-container { margin-bottom: 6px; }
      .irs { font-size: 11px; }
      .tab-content { padding-top: 10px; }
      .nav-tabs > li > a { padding: 6px 12px; font-size: 12px; }
      .col-sm-4, .col-sm-3, .col-sm-6 { padding-left: 8px; padding-right: 8px; }
      .row { margin-left: -8px; margin-right: -8px; }
    ')),
    tags$script(HTML('
      Shiny.addCustomMessageHandler("copyToClipboard", function(text) {
        navigator.clipboard.writeText(text).then(function() {
          // Show success message
          var btn = document.querySelector(".copy-feedback");
          if (btn) {
            btn.textContent = "Copied! Now paste into Claude.ai";
            btn.style.display = "inline";
            setTimeout(function() { btn.style.display = "none"; }, 3000);
          }
        });
      });
      Shiny.addCustomMessageHandler("clearTextarea", function(id) {
        var el = document.getElementById(id);
        if (el) el.value = "";
      });
    '))
  ),
  titlePanel("RepGrid Elicitation"),
  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("File Operations"),
      fileInput("rgrid_file", "Import .rgrid", accept = ".rgrid"),
      actionButton("import_rgrid", "Load Grid"),
      tags$hr(),
      actionButton("load_sample", "Load Sample Data"),
      tags$hr(),
      h4("Analysis"),
      actionButton("analyze", "Analyze Grid", class = "btn-primary"),
      checkboxInput("impute_missing", "Impute missing ratings (use 4)", value = FALSE),
      tags$hr(),
      h4("Display Options"),
      selectInput("col_elements", "Element color", choices = c("black","blue","red","darkgreen","purple"), selected = "blue"),
      selectInput("col_constructs", "Construct color", choices = c("black","red","orange","darkgreen","brown"), selected = "red"),
      checkboxInput("heatmap_color", "Use color heatmap", value = FALSE),
      tags$hr(),
      h4("Export"),
      downloadButton("download_grid", "Download Grid as CSV"),
      downloadButton("download_rgrid", "Download Grid as .rgrid")
    ),
    mainPanel(
      width = 9,
      tabsetPanel(
        tabPanel(
          "Build Grid",
          div(class = "elicit-panel",
            h4("Build Your Repertory Grid"),
            fluidRow(
              column(4,
                div(class = "elicit-section",
                  h5("1. Elements"),
                  textInput("element_name", NULL, placeholder = "Single element"),
                  actionButton("add_element", "Add", class = "btn-warning btn-sm"),
                  tags$hr(),
                  tags$small("Paste list (one per line or comma-separated):"),
                  tags$textarea(id = "elements_bulk", rows = 3, style = "width: 100%; margin-top: 3px; font-size: 11px;", placeholder = "Mother\nFather\nBest friend"),
                  actionButton("add_elements_bulk", "Add All", class = "btn-warning btn-sm", style = "margin-top: 3px;")
                )
              ),
              column(4,
                div(class = "elicit-section",
                  h5("2. Constructs"),
                  fluidRow(
                    column(6, style = "padding-right: 2px;", textInput("construct_left", NULL, placeholder = "Left pole")),
                    column(6, style = "padding-left: 2px;", textInput("construct_right", NULL, placeholder = "Right pole"))
                  ),
                  actionButton("add_construct", "Add", class = "btn-warning btn-sm"),
                  tags$hr(),
                  tags$small("Paste list (left - right, one per line):"),
                  tags$textarea(id = "constructs_bulk", rows = 3, style = "width: 100%; margin-top: 3px; font-size: 11px;", placeholder = "friendly - unfriendly\nwarm - cold"),
                  actionButton("add_constructs_bulk", "Add All", class = "btn-warning btn-sm", style = "margin-top: 3px;")
                )
              ),
              column(4,
                div(class = "elicit-section",
                  h5("3. Ratings"),
                  fluidRow(
                    column(6, style = "padding-right: 2px;", selectInput("rating_element", NULL, choices = NULL)),
                    column(6, style = "padding-left: 2px;", selectInput("rating_construct", NULL, choices = NULL))
                  ),
                  sliderInput("rating_score", "1=left, 7=right:", min = 1, max = 7, value = 4, width = "100%"),
                  actionButton("add_rating", "Add Rating", class = "btn-warning btn-sm")
                )
              )
            )
          ),
          h5("Current Ratings"),
          DTOutput("ratings_table"),
          actionButton("remove_rating", "Remove Selected", class = "btn-danger btn-sm")
        ),
        tabPanel(
          "Grid Summary",
          h4("Elements List"), uiOutput("elements_ui"),
          h4("Constructs List"), uiOutput("constructs_ui"),
          tags$hr(), h4("Missing Ratings"), tableOutput("missing_table"),
          tags$hr(), h4("Analysis Summary"), verbatimTextOutput("analysis_summary")
        ),
        tabPanel(
          "Biplot",
          h4("PCA Biplot"),
          p("2D visual map showing element and construct relationships using Principal Component Analysis"),
          plotOutput("pca_biplot", height = 600),
          tags$hr(),
          actionButton("help_biplot", "Help me understand this visualisation", class = "btn-info help-btn"),
          actionButton("chat_biplot", "Chat about this data", class = "btn-success chat-btn"),
          conditionalPanel(
            condition = "input.help_biplot % 2 == 1",
            div(class = "help-content",
              h5("PCA Biplot"),
              p("A 2D visual map showing how elements and constructs relate to each other using Principal Component Analysis (PCA)."),
              tags$ul(
                tags$li(tags$strong("Elements"), " are plotted as points - elements close together were rated similarly across constructs."),
                tags$li(tags$strong("Constructs"), " are shown as arrows (vectors) from the origin - arrows pointing in similar directions measure similar things."),
                tags$li(tags$strong("PC1 and PC2"), " are the two main dimensions that explain the most variance in your ratings.")
              ),
              h5("How to interpret"),
              tags$ul(
                tags$li("Elements near each other = similar rating patterns"),
                tags$li("Constructs pointing same direction = correlated (measure similar things)"),
                tags$li("Constructs pointing opposite directions = negatively correlated"),
                tags$li("Elements in the direction of a construct arrow = rated high on that construct")
              )
            )
          ),
          conditionalPanel(
            condition = "input.chat_biplot % 2 == 1",
            div(class = "chat-panel",
              h5("Ask Claude about your PCA Biplot"),
              textInput("chat_biplot_question", "Your question:", placeholder = "e.g., Why are elements A and B so close together?"),
              div(class = "btn-group-chat",
                actionButton("ask_biplot", "Ask Claude (API)", class = "btn-primary"),
                actionButton("copy_biplot", "Copy to Clipboard", class = "btn-secondary"),
                tags$a(href = "https://claude.ai", target = "_blank", class = "btn btn-outline-secondary", "Open Claude.ai"),
                span(class = "copy-feedback", style = "display:none;")
              ),
              uiOutput("biplot_response")
            )
          )
        ),
        tabPanel("Crossplot",
                 fluidRow(
                   column(12,
                          h4("Crossplot Analysis"),
                          p("Plot elements on two selected constructs as X and Y axes")
                   )
                 ),
                 fluidRow(
                   column(4,
                          selectInput("crossplot_x", "X-axis Construct:",
                                    choices = NULL)
                   ),
                   column(4,
                          selectInput("crossplot_y", "Y-axis Construct:",
                                    choices = NULL)
                   ),
                   column(4,
                          checkboxInput("crossplot_labels", "Show Element Labels", value = TRUE),
                          checkboxInput("crossplot_grid", "Show Grid Lines", value = TRUE),
                          downloadButton("download_crossplot", "Download Crossplot")
                   )
                 ),
                 tags$hr(),
                 plotOutput("crossplot_plot", height = 600),
                 tags$hr(),
                 actionButton("help_crossplot", "Help me understand this visualisation", class = "btn-info help-btn"),
                 actionButton("chat_crossplot", "Chat about this data", class = "btn-success chat-btn"),
                 conditionalPanel(
                   condition = "input.help_crossplot % 2 == 1",
                   div(class = "help-content",
                     h5("Crossplot Analysis"),
                     p("A scatter plot showing where each element falls on two constructs of your choice."),
                     tags$ul(
                       tags$li(tags$strong("X-axis"), " = ratings on the first construct (1 = left pole, 7 = right pole)"),
                       tags$li(tags$strong("Y-axis"), " = ratings on the second construct"),
                       tags$li(tags$strong("Each point"), " = one element from your grid")
                     ),
                     h5("How to interpret"),
                     tags$ul(
                       tags$li("Elements in the same quadrant share similar ratings on both constructs"),
                       tags$li("The midpoint (4) is marked with dashed lines - this divides the plot into four quadrants"),
                       tags$li("Use this to explore relationships between specific construct pairs"),
                       tags$li("Try different construct combinations to find meaningful patterns")
                     ),
                     h5("Example use"),
                     p("If your constructs are 'friendly-unfriendly' (X) and 'competent-incompetent' (Y), elements in the top-right are seen as both unfriendly AND incompetent.")
                   )
                 ),
                 conditionalPanel(
                   condition = "input.chat_crossplot % 2 == 1",
                   div(class = "chat-panel",
                     h5("Ask Claude about your Crossplot"),
                     textInput("chat_crossplot_question", "Your question:", placeholder = "e.g., Why is element X in that quadrant?"),
                     div(class = "btn-group-chat",
                       actionButton("ask_crossplot", "Ask Claude (API)", class = "btn-primary"),
                       actionButton("copy_crossplot", "Copy to Clipboard", class = "btn-secondary"),
                       tags$a(href = "https://claude.ai", target = "_blank", class = "btn btn-outline-secondary", "Open Claude.ai"),
                       span(class = "copy-feedback", style = "display:none;")
                     ),
                     uiOutput("crossplot_response")
                   )
                 )
        ),
        tabPanel("Synopsis",
                 fluidRow(
                   column(12,
                          h4("Synopsis Analysis"),
                          p("Rating distributions and variance analysis (scree plot)")
                   )
                 ),
                 fluidRow(
                   column(4,
                          selectInput("synopsis_type", "Display:",
                                    choices = c("Overall Distribution" = "overall",
                                              "Element Distributions" = "elements",
                                              "Construct Distributions" = "constructs",
                                              "Scree Plot" = "scree"),
                                    selected = "overall")
                   ),
                   column(4,
                          numericInput("synopsis_bins", "Number of Bins:",
                                     value = 7, min = 3, max = 20, step = 1),
                          helpText("For histograms only")
                   ),
                   column(4,
                          downloadButton("download_synopsis", "Download Synopsis Plot"),
                          tags$br(), tags$br(),
                          checkboxInput("synopsis_color", "Use color", value = FALSE)
                   )
                 ),
                 tags$hr(),
                 plotOutput("synopsis_plot", height = 600),
                 tags$hr(),
                 actionButton("help_synopsis", "Help me understand this visualisation", class = "btn-info help-btn"),
                 actionButton("chat_synopsis", "Chat about this data", class = "btn-success chat-btn"),
                 conditionalPanel(
                   condition = "input.help_synopsis % 2 == 1",
                   div(class = "help-content",
                     h5("Synopsis Analysis"),
                     p("Summarises your rating patterns through histograms and variance analysis."),
                     h5("Display options"),
                     tags$ul(
                       tags$li(tags$strong("Overall Distribution"), " - Histogram of ALL ratings in your grid. Shows if you tend to use certain parts of the scale more than others. Red line = mean, blue line = median."),
                       tags$li(tags$strong("Element Distributions"), " - Separate histogram for each element. Shows how each element was rated across all constructs."),
                       tags$li(tags$strong("Construct Distributions"), " - Separate histogram for each construct. Shows how ratings vary across elements for each construct."),
                       tags$li(tags$strong("Scree Plot"), " - Shows how much variance each principal component explains. Helps determine how many dimensions are meaningful in your data.")
                     ),
                     h5("How to interpret"),
                     tags$ul(
                       tags$li("Skewed distributions may indicate response bias or genuine patterns"),
                       tags$li("Flat distributions suggest differentiated ratings"),
                       tags$li("In the scree plot, look for an 'elbow' where variance drops off - components before the elbow are most meaningful")
                     )
                   )
                 ),
                 conditionalPanel(
                   condition = "input.chat_synopsis % 2 == 1",
                   div(class = "chat-panel",
                     h5("Ask Claude about your Synopsis"),
                     textInput("chat_synopsis_question", "Your question:", placeholder = "e.g., Why is my distribution skewed?"),
                     div(class = "btn-group-chat",
                       actionButton("ask_synopsis", "Ask Claude (API)", class = "btn-primary"),
                       actionButton("copy_synopsis", "Copy to Clipboard", class = "btn-secondary"),
                       tags$a(href = "https://claude.ai", target = "_blank", class = "btn btn-outline-secondary", "Open Claude.ai"),
                       span(class = "copy-feedback", style = "display:none;")
                     ),
                     uiOutput("synopsis_response")
                   )
                 )
        ),
        tabPanel("Heatmap",
                 plotOutput("heatmap_plot", height = 500),
                 tags$hr(),
                 actionButton("help_heatmap", "Help me understand this visualisation", class = "btn-info help-btn"),
                 actionButton("chat_heatmap", "Chat about this data", class = "btn-success chat-btn"),
                 conditionalPanel(
                   condition = "input.help_heatmap % 2 == 1",
                   div(class = "help-content",
                     h5("Heatmap"),
                     p("A color-coded grid showing all your ratings at a glance."),
                     tags$ul(
                       tags$li(tags$strong("Rows"), " = Elements"),
                       tags$li(tags$strong("Columns"), " = Constructs"),
                       tags$li(tags$strong("Colors"), " = Rating values (darker = higher ratings by default, or use color toggle for blue-white-red)")
                     ),
                     h5("How to interpret"),
                     tags$ul(
                       tags$li("Look for patterns - rows or columns with similar shading"),
                       tags$li("Dark/red regions indicate high ratings (toward right pole)"),
                       tags$li("Light/blue regions indicate low ratings (toward left pole)"),
                       tags$li("Uniform rows = element rated similarly across all constructs"),
                       tags$li("Uniform columns = construct doesn't differentiate between elements")
                     )
                   )
                 ),
                 conditionalPanel(
                   condition = "input.chat_heatmap % 2 == 1",
                   div(class = "chat-panel",
                     h5("Ask Claude about your Heatmap"),
                     textInput("chat_heatmap_question", "Your question:", placeholder = "e.g., Why does this row look different?"),
                     div(class = "btn-group-chat",
                       actionButton("ask_heatmap", "Ask Claude (API)", class = "btn-primary"),
                       actionButton("copy_heatmap", "Copy to Clipboard", class = "btn-secondary"),
                       tags$a(href = "https://claude.ai", target = "_blank", class = "btn btn-outline-secondary", "Open Claude.ai"),
                       span(class = "copy-feedback", style = "display:none;")
                     ),
                     uiOutput("heatmap_response")
                   )
                 )
        ),
        tabPanel("Element Dendrogram",
                 plotOutput("dend_elements"),
                 tags$hr(),
                 actionButton("help_dend_elem", "Help me understand this visualisation", class = "btn-info help-btn"),
                 actionButton("chat_dend_elem", "Chat about this data", class = "btn-success chat-btn"),
                 conditionalPanel(
                   condition = "input.help_dend_elem % 2 == 1",
                   div(class = "help-content",
                     h5("Element Dendrogram"),
                     p("A tree diagram showing which elements are most similar to each other based on their rating patterns."),
                     h5("How to read it"),
                     tags$ul(
                       tags$li(tags$strong("Elements that join early"), " (close to the left) are very similar - they were rated similarly across most constructs"),
                       tags$li(tags$strong("Elements that join late"), " (further right) are more different from each other"),
                       tags$li(tags$strong("Branch length"), " indicates degree of difference")
                     ),
                     h5("Example interpretation"),
                     p("If elements A and B join together before connecting to C, this means A and B have more similar rating profiles than either has with C.")
                   )
                 ),
                 conditionalPanel(
                   condition = "input.chat_dend_elem % 2 == 1",
                   div(class = "chat-panel",
                     h5("Ask Claude about your Element Dendrogram"),
                     textInput("chat_dend_elem_question", "Your question:", placeholder = "e.g., Why do A and B cluster together?"),
                     div(class = "btn-group-chat",
                       actionButton("ask_dend_elem", "Ask Claude (API)", class = "btn-primary"),
                       actionButton("copy_dend_elem", "Copy to Clipboard", class = "btn-secondary"),
                       tags$a(href = "https://claude.ai", target = "_blank", class = "btn btn-outline-secondary", "Open Claude.ai"),
                       span(class = "copy-feedback", style = "display:none;")
                     ),
                     uiOutput("dend_elem_response")
                   )
                 )
        ),
        tabPanel("Construct Dendrogram",
                 plotOutput("dend_constructs"),
                 tags$hr(),
                 actionButton("help_dend_const", "Help me understand this visualisation", class = "btn-info help-btn"),
                 actionButton("chat_dend_const", "Chat about this data", class = "btn-success chat-btn"),
                 conditionalPanel(
                   condition = "input.help_dend_const % 2 == 1",
                   div(class = "help-content",
                     h5("Construct Dendrogram"),
                     p("A tree diagram showing which constructs are most similar based on how elements were rated on them."),
                     h5("How to read it"),
                     tags$ul(
                       tags$li(tags$strong("Constructs that join early"), " (close to the left) essentially measure the same thing - elements received similar ratings on both"),
                       tags$li(tags$strong("Constructs that join late"), " (further right) measure different dimensions"),
                       tags$li("Very similar constructs may be redundant - consider if you need both")
                     ),
                     h5("Example interpretation"),
                     p("If 'friendly-unfriendly' and 'warm-cold' join early, you may be using these constructs interchangeably. They represent the same underlying dimension in your thinking.")
                   )
                 ),
                 conditionalPanel(
                   condition = "input.chat_dend_const % 2 == 1",
                   div(class = "chat-panel",
                     h5("Ask Claude about your Construct Dendrogram"),
                     textInput("chat_dend_const_question", "Your question:", placeholder = "e.g., Are these constructs redundant?"),
                     div(class = "btn-group-chat",
                       actionButton("ask_dend_const", "Ask Claude (API)", class = "btn-primary"),
                       actionButton("copy_dend_const", "Copy to Clipboard", class = "btn-secondary"),
                       tags$a(href = "https://claude.ai", target = "_blank", class = "btn btn-outline-secondary", "Open Claude.ai"),
                       span(class = "copy-feedback", style = "display:none;")
                     ),
                     uiOutput("dend_const_response")
                   )
                 )
        ),
        tabPanel("Focus Cluster",
                 fluidRow(
                   column(12,
                          h4("Focus Cluster Analysis"),
                          p("Shaw's (1980) Focus algorithm sorts elements and constructs by similarity, showing hierarchical structure.")
                   )
                 ),
                 fluidRow(
                   column(3,
                          sliderInput("focus_power", "Minkowski Power:",
                                    min = 0.5, max = 3.0, value = 1.0, step = 0.1),
                          helpText("1.0 = City block metric (default), 2.0 = Euclidean")
                   ),
                   column(3,
                          sliderInput("focus_cutoff", "Match Cutoff (%):",
                                    min = 0, max = 100, value = 80, step = 5),
                          helpText("Minimum similarity to display in clusters")
                   ),
                   column(3,
                          checkboxInput("focus_show_values", "Show Rating Values", value = TRUE),
                          checkboxInput("focus_show_shading", "Show Shading", value = TRUE),
                          checkboxInput("focus_use_color", "Use color palette", value = FALSE)
                   ),
                   column(3,
                          actionButton("run_focus", "Run Focus Analysis", class = "btn-primary"),
                          tags$br(), tags$br(),
                          downloadButton("download_focus", "Download Focus Plot")
                   )
                 ),
                 tags$hr(),
                 plotOutput("focus_plot", height = 700),
                 tags$hr(),
                 h4("Match Data"),
                 fluidRow(
                   column(6,
                          h5("Element Matches"),
                          verbatimTextOutput("focus_element_matches")
                   ),
                   column(6,
                          h5("Construct Matches"),
                          verbatimTextOutput("focus_construct_matches")
                   )
                 ),
                 tags$hr(),
                 actionButton("help_focus", "Help me understand this visualisation", class = "btn-info help-btn"),
                 actionButton("chat_focus", "Chat about this data", class = "btn-success chat-btn"),
                 conditionalPanel(
                   condition = "input.help_focus % 2 == 1",
                   div(class = "help-content",
                     h5("Focus Cluster Analysis"),
                     p("Focus automatically sorts your grid to reveal patterns. Similar elements appear together, and similar constructs appear together."),
                     h5("The display shows 4 parts"),
                     tags$ul(
                       tags$li(tags$strong("Top dendrogram"), " - shows how constructs (columns) cluster together"),
                       tags$li(tags$strong("Left dendrogram"), " - shows how elements (rows) cluster together"),
                       tags$li(tags$strong("Center grid"), " - your ratings, reordered so similar items are adjacent"),
                       tags$li(tags$strong("Match statistics"), " - similarity percentages for elements and constructs")
                     ),
                     h5("Reading the dendrograms"),
                     tags$ul(
                       tags$li("Short connections = very similar items"),
                       tags$li("Long connections = less similar items"),
                       tags$li("Items that join low on the tree are more similar than those joining higher up")
                     ),
                     h5("Parameters"),
                     tags$ul(
                       tags$li(tags$strong("Minkowski Power"), " - 1.0 (city block, default) treats all differences equally; 2.0 (Euclidean) emphasizes larger differences"),
                       tags$li(tags$strong("Match Cutoff"), " - only shows matches above this similarity threshold")
                     ),
                     h5("Common uses"),
                     tags$ul(
                       tags$li("Finding element groups that cluster together"),
                       tags$li("Identifying redundant constructs (matches > 90%)"),
                       tags$li("Discovering main conceptual dimensions")
                     )
                   )
                 ),
                 conditionalPanel(
                   condition = "input.chat_focus % 2 == 1",
                   div(class = "chat-panel",
                     h5("Ask Claude about your Focus Cluster Analysis"),
                     textInput("chat_focus_question", "Your question:", placeholder = "e.g., What does this cluster pattern mean?"),
                     div(class = "btn-group-chat",
                       actionButton("ask_focus", "Ask Claude (API)", class = "btn-primary"),
                       actionButton("copy_focus", "Copy to Clipboard", class = "btn-secondary"),
                       tags$a(href = "https://claude.ai", target = "_blank", class = "btn btn-outline-secondary", "Open Claude.ai"),
                       span(class = "copy-feedback", style = "display:none;")
                     ),
                     uiOutput("focus_response")
                   )
                 )
        ),
        tabPanel("Statistics",
                 h4("Descriptive Statistics"),
                 h5("Element Statistics"),
                 verbatimTextOutput("stats_elements"),
                 tags$hr(),
                 h5("Construct Statistics"),
                 verbatimTextOutput("stats_constructs"),
                 tags$hr(),
                 actionButton("help_stats", "Help me understand this visualisation", class = "btn-info help-btn"),
                 actionButton("chat_stats", "Chat about this data", class = "btn-success chat-btn"),
                 conditionalPanel(
                   condition = "input.help_stats % 2 == 1",
                   div(class = "help-content",
                     h5("Descriptive Statistics"),
                     p("Summary statistics for your grid data, showing patterns in how elements and constructs were rated."),
                     h5("Element Statistics"),
                     tags$ul(
                       tags$li(tags$strong("Mean"), " - average rating for this element across all constructs. High means = element rated toward right poles; low means = toward left poles."),
                       tags$li(tags$strong("SD (Standard Deviation)"), " - how much ratings varied. Low SD = element rated consistently; high SD = element rated very differently on different constructs.")
                     ),
                     h5("Construct Statistics"),
                     tags$ul(
                       tags$li(tags$strong("Mean"), " - average rating on this construct across all elements. Near 4 = construct differentiates well; extreme values may indicate bias."),
                       tags$li(tags$strong("SD"), " - how much this construct differentiates between elements. Low SD = construct doesn't distinguish elements well; high SD = good differentiation.")
                     ),
                     h5("What to look for"),
                     tags$ul(
                       tags$li("Constructs with very low SD may not be useful - they rate all elements the same"),
                       tags$li("Elements with extreme means may be outliers worth examining"),
                       tags$li("Compare means to identify patterns in how you perceive different elements")
                     )
                   )
                 ),
                 conditionalPanel(
                   condition = "input.chat_stats % 2 == 1",
                   div(class = "chat-panel",
                     h5("Ask Claude about your Statistics"),
                     textInput("chat_stats_question", "Your question:", placeholder = "e.g., Why is this element's SD so high?"),
                     div(class = "btn-group-chat",
                       actionButton("ask_stats", "Ask Claude (API)", class = "btn-primary"),
                       actionButton("copy_stats", "Copy to Clipboard", class = "btn-secondary"),
                       tags$a(href = "https://claude.ai", target = "_blank", class = "btn btn-outline-secondary", "Open Claude.ai"),
                       span(class = "copy-feedback", style = "display:none;")
                     ),
                     uiOutput("stats_response")
                   )
                 )
        )
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

  # Bulk add elements from pasted list
  observeEvent(input$add_elements_bulk, {
    req(input$elements_bulk)
    # Split by newlines or commas
    raw_text <- input$elements_bulk
    # First split by newlines, then by commas if needed
    elements <- unlist(strsplit(raw_text, "[\n\r]+"))
    elements <- unlist(strsplit(elements, ","))
    # Trim whitespace and filter empty strings
    elements <- trimws(elements)
    elements <- elements[elements != ""]
    if (length(elements) > 0) {
      rv$elements <- c(rv$elements, elements)
      # Clear the textarea using JavaScript
      session$sendCustomMessage("clearTextarea", "elements_bulk")
    }
  })

  # Bulk add constructs from pasted list (format: "left - right" or "left, right")
  observeEvent(input$add_constructs_bulk, {
    req(input$constructs_bulk)
    raw_text <- input$constructs_bulk
    # Split by newlines
    lines <- unlist(strsplit(raw_text, "[\n\r]+"))
    lines <- trimws(lines)
    lines <- lines[lines != ""]

    for (line in lines) {
      # Try splitting by " - " first, then by ","
      if (grepl(" - ", line)) {
        parts <- strsplit(line, " - ")[[1]]
      } else if (grepl(",", line)) {
        parts <- strsplit(line, ",")[[1]]
      } else {
        next  # Skip lines that don't have a separator
      }

      if (length(parts) >= 2) {
        left_pole <- trimws(parts[1])
        right_pole <- trimws(parts[2])
        if (left_pole != "" && right_pole != "") {
          rv$constructs <- rbind(
            rv$constructs,
            data.frame(left = left_pole, right = right_pole, stringsAsFactors = FALSE)
          )
        }
      }
    }
    # Clear the textarea using JavaScript
    session$sendCustomMessage("clearTextarea", "constructs_bulk")
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

      # Calculate expanded plot limits to accommodate labels
      all_points <- rbind(ex, load)
      x_range <- range(all_points[, 1])
      y_range <- range(all_points[, 2])
      x_expand <- diff(x_range) * 0.25  # 25% padding
      y_expand <- diff(y_range) * 0.25
      xlim <- c(x_range[1] - x_expand, x_range[2] + x_expand)
      ylim <- c(y_range[1] - y_expand, y_range[2] + y_expand)

      # Set margins for better label display
      par(mar = c(4, 4, 2, 2))

      plot(ex, type = "n", xlab = "PC1", ylab = "PC2", xlim = xlim, ylim = ylim)
      points(ex, pch = 19, col = input$col_elements)
      text(ex, labels = rv$elements, pos = 3, col = input$col_elements, cex = 0.9)
      # arrows for constructs
      arrows(0, 0, load[,1], load[,2], length = 0.1, col = input$col_constructs)
      text(load[,1], load[,2], labels = paste(rv$constructs$left, "-", rv$constructs$right),
           pos = 4, col = input$col_constructs, cex = 0.9)
      abline(h = 0, v = 0, lty = 3)
    })

    output$heatmap_plot <- renderPlot({
      sm <- rv$scores_mat_last
      if (is.null(sm)) return()
      # Build palette - greyscale by default, color if toggled
      if (input$heatmap_color) {
        pal <- colorRampPalette(c("#2166AC", "#FFFFFF", "#B2182B"))(100)
      } else {
        pal <- gray.colors(100, start = 0.95, end = 0.2)
      }
      # sm is elements (rows) × constructs (cols)
      n_elem <- nrow(sm)
      n_cons <- ncol(sm)
      # Flip elements so first appears at top
      z <- sm[n_elem:1, ]

      # Set margins to accommodate labels
      par(mar = c(8, 12, 2, 2))

      # Draw heatmap
      image(
        x = 1:n_elem, y = 1:n_cons, z = z,
        col = pal, axes = FALSE, xlab = "", ylab = ""
      )

      # Add rating values as text in each cell
      for (i in 1:n_elem) {
        for (j in 1:n_cons) {
          val <- z[i, j]
          if (!is.na(val)) {
            # Choose text color based on value for readability
            text_col <- if (val > 2.5) "white" else "black"
            text(i, j, sprintf("%.0f", val), col = text_col, cex = 1.2)
          }
        }
      }

      # Add axes with labels
      axis(1, at = 1:n_elem, labels = rev(rv$elements), las = 2, cex.axis = 0.8)
      labs <- paste(rv$constructs$left, "-", rv$constructs$right)
      axis(2, at = 1:n_cons, labels = labs, las = 1, cex.axis = 0.8)
      box()

      # Add axis titles
      mtext("Elements", side = 1, line = 6.5)
      mtext("Constructs", side = 2, line = 10.5)
    })

    output$dend_elements <- renderPlot({
      sm <- rv$scores_mat_last
      if (is.null(sm) || nrow(sm) < 2) return()
      hc <- hclust(dist(sm))
      par(mar = c(2, 8, 2, 2))  # Increase left margin for labels
      plot(hc, labels = rv$elements, main = "Elements", xlab = "", sub = "", horiz = TRUE)
    })

    output$dend_constructs <- renderPlot({
      sm <- rv$scores_mat_last
      if (is.null(sm) || ncol(sm) < 2) return()
      hc <- hclust(dist(t(sm)))
      labs <- paste(rv$constructs$left, "-", rv$constructs$right)
      par(mar = c(2, 12, 2, 2))  # Increase left margin for longer construct labels
      plot(hc, labels = labs, main = "Constructs", xlab = "", sub = "", horiz = TRUE)
    })

    # Statistics outputs
    output$stats_elements <- renderPrint({
      repgrid_obj <- rv$repgrid_last
      if (is.null(repgrid_obj)) return()
      statsElements(repgrid_obj, trim = 30)
    })

    output$stats_constructs <- renderPrint({
      repgrid_obj <- rv$repgrid_last
      if (is.null(repgrid_obj)) return()
      statsConstructs(repgrid_obj, trim = 30)
    })
  })

  # Crossplot Analysis
  # Update construct choices when grid is analyzed
  observe({
    req(rv$constructs)
    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)

    updateSelectInput(session, "crossplot_x",
                     choices = construct_labels,
                     selected = construct_labels[1])

    updateSelectInput(session, "crossplot_y",
                     choices = construct_labels,
                     selected = if(length(construct_labels) > 1) construct_labels[2] else construct_labels[1])
  })

  output$crossplot_plot <- renderPlot({
    req(rv$scores_mat_last)
    req(input$crossplot_x, input$crossplot_y)

    sm <- rv$scores_mat_last
    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)

    # Find indices of selected constructs
    x_idx <- which(construct_labels == input$crossplot_x)
    y_idx <- which(construct_labels == input$crossplot_y)

    if(length(x_idx) == 0 || length(y_idx) == 0) return()

    # Extract ratings for selected constructs
    x_ratings <- sm[, x_idx]
    y_ratings <- sm[, y_idx]

    # Set up plot
    par(mar = c(5, 5, 3, 2))

    plot(x_ratings, y_ratings,
         xlim = c(1, 7), ylim = c(1, 7),
         xlab = input$crossplot_x,
         ylab = input$crossplot_y,
         main = "Crossplot: Element Positions",
         pch = 19, col = "blue", cex = 1.5,
         asp = 1)  # 1:1 aspect ratio for equal scaling

    # Add grid lines if requested
    if (input$crossplot_grid) {
      abline(h = 1:7, v = 1:7, col = "gray90", lty = 1)
      abline(h = 4, v = 4, col = "gray60", lty = 2, lwd = 1.5)
    }

    # Add element labels if requested
    if (input$crossplot_labels) {
      text(x_ratings, y_ratings, labels = rv$elements,
           pos = 3, cex = 0.8, col = "darkblue")
    }

    # Add box around plot
    box()
  })

  output$download_crossplot <- downloadHandler(
    filename = function() paste0("crossplot-", Sys.Date(), ".png"),
    content = function(file) {
      req(rv$scores_mat_last)
      req(input$crossplot_x, input$crossplot_y)

      sm <- rv$scores_mat_last
      construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)

      x_idx <- which(construct_labels == input$crossplot_x)
      y_idx <- which(construct_labels == input$crossplot_y)

      if(length(x_idx) == 0 || length(y_idx) == 0) return()

      x_ratings <- sm[, x_idx]
      y_ratings <- sm[, y_idx]

      png(file, width = 1200, height = 1200, res = 120)

      par(mar = c(5, 5, 3, 2))

      plot(x_ratings, y_ratings,
           xlim = c(1, 7), ylim = c(1, 7),
           xlab = input$crossplot_x,
           ylab = input$crossplot_y,
           main = "Crossplot: Element Positions",
           pch = 19, col = "blue", cex = 1.5,
           asp = 1)

      if (input$crossplot_grid) {
        abline(h = 1:7, v = 1:7, col = "gray90", lty = 1)
        abline(h = 4, v = 4, col = "gray60", lty = 2, lwd = 1.5)
      }

      if (input$crossplot_labels) {
        text(x_ratings, y_ratings, labels = rv$elements,
             pos = 3, cex = 0.8, col = "darkblue")
      }

      box()

      dev.off()
    }
  )

  # Synopsis Analysis
  output$synopsis_plot <- renderPlot({
    req(rv$scores_mat_last)
    sm <- rv$scores_mat_last

    # Choose color scheme
    bar_color <- if (input$synopsis_color) "#2166AC" else "gray50"

    if (input$synopsis_type == "overall") {
      # Overall rating distribution
      all_ratings <- as.vector(sm)
      all_ratings <- all_ratings[!is.na(all_ratings)]

      hist(all_ratings,
           breaks = input$synopsis_bins,
           main = "Overall Rating Distribution",
           xlab = "Rating",
           ylab = "Frequency",
           col = bar_color,
           border = "white")

      # Add mean and median lines
      abline(v = mean(all_ratings), col = "red", lwd = 2, lty = 2)
      abline(v = median(all_ratings), col = "blue", lwd = 2, lty = 2)
      legend("topright",
             legend = c(paste("Mean =", round(mean(all_ratings), 2)),
                       paste("Median =", round(median(all_ratings), 2))),
             col = c("red", "blue"), lty = 2, lwd = 2)

    } else if (input$synopsis_type == "elements") {
      # Element distributions
      n_elem <- nrow(sm)
      par(mfrow = c(ceiling(n_elem / 3), 3))
      par(mar = c(4, 4, 2, 1))

      for (i in 1:n_elem) {
        elem_ratings <- sm[i, ]
        elem_ratings <- elem_ratings[!is.na(elem_ratings)]

        hist(elem_ratings,
             breaks = input$synopsis_bins,
             main = rv$elements[i],
             xlab = "Rating",
             ylab = "Frequency",
             col = bar_color,
             border = "white",
             xlim = c(min(sm, na.rm = TRUE), max(sm, na.rm = TRUE)))

        abline(v = mean(elem_ratings), col = "red", lwd = 2, lty = 2)
      }

    } else if (input$synopsis_type == "constructs") {
      # Construct distributions
      n_const <- ncol(sm)
      par(mfrow = c(ceiling(n_const / 3), 3))
      par(mar = c(4, 4, 3, 1))

      construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)

      for (i in 1:n_const) {
        const_ratings <- sm[, i]
        const_ratings <- const_ratings[!is.na(const_ratings)]

        hist(const_ratings,
             breaks = input$synopsis_bins,
             main = construct_labels[i],
             xlab = "Rating",
             ylab = "Frequency",
             col = bar_color,
             border = "white",
             xlim = c(min(sm, na.rm = TRUE), max(sm, na.rm = TRUE)),
             cex.main = 0.9)

        abline(v = mean(const_ratings), col = "red", lwd = 2, lty = 2)
      }

    } else if (input$synopsis_type == "scree") {
      # Scree plot
      pca_result <- prcomp(sm, scale. = TRUE)
      variance_explained <- (pca_result$sdev^2) / sum(pca_result$sdev^2) * 100
      cumulative_var <- cumsum(variance_explained)

      n_components <- min(10, length(variance_explained))

      par(mar = c(5, 4, 4, 5))

      # Bar plot for variance explained
      barplot(variance_explained[1:n_components],
              names.arg = 1:n_components,
              main = "Scree Plot - Variance Explained by Components",
              xlab = "Principal Component",
              ylab = "Variance Explained (%)",
              col = bar_color,
              border = "white",
              ylim = c(0, max(variance_explained[1:n_components]) * 1.2))

      # Add cumulative line on secondary axis
      par(new = TRUE)
      plot(1:n_components, cumulative_var[1:n_components],
           type = "b", pch = 19, col = "red", lwd = 2,
           axes = FALSE, xlab = "", ylab = "",
           ylim = c(0, 100))

      axis(4, col = "red", col.axis = "red")
      mtext("Cumulative Variance (%)", side = 4, line = 3, col = "red")

      legend("right",
             legend = c("Individual", "Cumulative"),
             col = c(bar_color, "red"),
             lty = c(NA, 1), pch = c(15, 19),
             pt.cex = c(2, 1))
    }
  })

  output$download_synopsis <- downloadHandler(
    filename = function() paste0("synopsis-", Sys.Date(), ".png"),
    content = function(file) {
      req(rv$scores_mat_last)
      sm <- rv$scores_mat_last

      png(file, width = 1200, height = 900, res = 120)

      bar_color <- if (input$synopsis_color) "#2166AC" else "gray50"

      if (input$synopsis_type == "overall") {
        all_ratings <- as.vector(sm)
        all_ratings <- all_ratings[!is.na(all_ratings)]

        hist(all_ratings,
             breaks = input$synopsis_bins,
             main = "Overall Rating Distribution",
             xlab = "Rating",
             ylab = "Frequency",
             col = bar_color,
             border = "white")

        abline(v = mean(all_ratings), col = "red", lwd = 2, lty = 2)
        abline(v = median(all_ratings), col = "blue", lwd = 2, lty = 2)
        legend("topright",
               legend = c(paste("Mean =", round(mean(all_ratings), 2)),
                         paste("Median =", round(median(all_ratings), 2))),
               col = c("red", "blue"), lty = 2, lwd = 2)

      } else if (input$synopsis_type == "elements") {
        n_elem <- nrow(sm)
        par(mfrow = c(ceiling(n_elem / 3), 3))
        par(mar = c(4, 4, 2, 1))

        for (i in 1:n_elem) {
          elem_ratings <- sm[i, ]
          elem_ratings <- elem_ratings[!is.na(elem_ratings)]

          hist(elem_ratings,
               breaks = input$synopsis_bins,
               main = rv$elements[i],
               xlab = "Rating",
               ylab = "Frequency",
               col = bar_color,
               border = "white",
               xlim = c(min(sm, na.rm = TRUE), max(sm, na.rm = TRUE)))

          abline(v = mean(elem_ratings), col = "red", lwd = 2, lty = 2)
        }

      } else if (input$synopsis_type == "constructs") {
        n_const <- ncol(sm)
        par(mfrow = c(ceiling(n_const / 3), 3))
        par(mar = c(4, 4, 3, 1))

        construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)

        for (i in 1:n_const) {
          const_ratings <- sm[, i]
          const_ratings <- const_ratings[!is.na(const_ratings)]

          hist(const_ratings,
               breaks = input$synopsis_bins,
               main = construct_labels[i],
               xlab = "Rating",
               ylab = "Frequency",
               col = bar_color,
               border = "white",
               xlim = c(min(sm, na.rm = TRUE), max(sm, na.rm = TRUE)),
               cex.main = 0.9)

          abline(v = mean(const_ratings), col = "red", lwd = 2, lty = 2)
        }

      } else if (input$synopsis_type == "scree") {
        pca_result <- prcomp(sm, scale. = TRUE)
        variance_explained <- (pca_result$sdev^2) / sum(pca_result$sdev^2) * 100
        cumulative_var <- cumsum(variance_explained)

        n_components <- min(10, length(variance_explained))

        par(mar = c(5, 4, 4, 5))

        barplot(variance_explained[1:n_components],
                names.arg = 1:n_components,
                main = "Scree Plot - Variance Explained by Components",
                xlab = "Principal Component",
                ylab = "Variance Explained (%)",
                col = bar_color,
                border = "white",
                ylim = c(0, max(variance_explained[1:n_components]) * 1.2))

        par(new = TRUE)
        plot(1:n_components, cumulative_var[1:n_components],
             type = "b", pch = 19, col = "red", lwd = 2,
             axes = FALSE, xlab = "", ylab = "",
             ylim = c(0, 100))

        axis(4, col = "red", col.axis = "red")
        mtext("Cumulative Variance (%)", side = 4, line = 3, col = "red")

        legend("right",
               legend = c("Individual", "Cumulative"),
               col = c(bar_color, "red"),
               lty = c(NA, 1), pch = c(15, 19),
               pt.cex = c(2, 1))
      }

      dev.off()
    }
  )

  # Focus Cluster Analysis
  focus_result <- reactiveVal(NULL)

  observeEvent(input$run_focus, {
    req(rv$scores_mat_last)
    sm <- rv$scores_mat_last

    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)

    result <- focus_cluster(
      scores_matrix = sm,
      element_names = rv$elements,
      construct_names = construct_labels,
      power = input$focus_power
    )

    focus_result(result)
  })

  output$focus_plot <- renderPlot({
    req(focus_result())
    result <- focus_result()

    plot_focus_cluster(
      focus_result = result,
      title = "Focus Cluster Analysis",
      show_values = input$focus_show_values,
      show_shading = input$focus_show_shading,
      use_color = input$focus_use_color
    )
  })

  output$focus_element_matches <- renderPrint({
    req(focus_result())
    result <- focus_result()
    elem_sim <- result$element_similarities

    cat("Element Similarity Matrix (%):\n\n")
    rownames(elem_sim) <- rv$elements
    colnames(elem_sim) <- rv$elements
    print(round(elem_sim, 1))

    cat("\n\nTop Element Matches (excluding self):\n")
    elem_sim_no_diag <- elem_sim
    diag(elem_sim_no_diag) <- 0

    matches <- which(elem_sim_no_diag >= input$focus_cutoff, arr.ind = TRUE)
    if (nrow(matches) > 0) {
      for (i in seq_len(min(10, nrow(matches)))) {
        r <- matches[i, 1]
        c <- matches[i, 2]
        if (r < c) {
          cat(sprintf("  %s - %s: %.1f%%\n",
                     rv$elements[r],
                     rv$elements[c],
                     elem_sim[r, c]))
        }
      }
    } else {
      cat("  No matches above cutoff threshold\n")
    }
  })

  output$focus_construct_matches <- renderPrint({
    req(focus_result())
    result <- focus_result()
    const_sim <- result$construct_similarities

    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)

    cat("Construct Similarity Matrix (%):\n\n")
    rownames(const_sim) <- construct_labels
    colnames(const_sim) <- construct_labels
    print(round(const_sim, 1))

    cat("\n\nTop Construct Matches (excluding self):\n")
    const_sim_no_diag <- const_sim
    diag(const_sim_no_diag) <- 0

    matches <- which(const_sim_no_diag >= input$focus_cutoff, arr.ind = TRUE)
    if (nrow(matches) > 0) {
      for (i in seq_len(min(10, nrow(matches)))) {
        r <- matches[i, 1]
        c <- matches[i, 2]
        if (r < c) {
          cat(sprintf("  %s - %s: %.1f%%\n",
                     construct_labels[r],
                     construct_labels[c],
                     const_sim[r, c]))
        }
      }
    } else {
      cat("  No matches above cutoff threshold\n")
    }
  })

  output$download_focus <- downloadHandler(
    filename = function() paste0("focus-cluster-", Sys.Date(), ".png"),
    content = function(file) {
      req(focus_result())
      result <- focus_result()

      png(file, width = 1200, height = 900, res = 120)
      plot_focus_cluster(
        focus_result = result,
        title = "Focus Cluster Analysis",
        show_values = input$focus_show_values,
        show_shading = input$focus_show_shading,
        use_color = input$focus_use_color
      )
      dev.off()
    }
  )

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

  # Helper function to generate grid data summary for chat prompts
  generate_grid_summary <- reactive({
    if (length(rv$elements) == 0 || nrow(rv$constructs) == 0) {
      return("No grid data available yet. Please load or create a grid first.")
    }

    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)

    # Build ratings matrix text
    sm <- rv$scores_mat_last
    if (is.null(sm)) {
      matrix_text <- "Grid has not been analyzed yet."
    } else {
      # Create a readable matrix format
      col_header <- paste(c("Element", construct_labels), collapse = " | ")
      rows <- sapply(seq_len(nrow(sm)), function(i) {
        paste(c(rv$elements[i], sm[i, ]), collapse = " | ")
      })
      matrix_text <- paste(c(col_header, rows), collapse = "\n")
    }

    paste0(
      "REPERTORY GRID DATA:\n",
      "Elements: ", paste(rv$elements, collapse = ", "), "\n",
      "Constructs (left pole - right pole):\n",
      paste(paste0("  - ", construct_labels), collapse = "\n"), "\n\n",
      "Rating scale: 1 (left pole) to 7 (right pole)\n\n",
      "RATINGS MATRIX:\n", matrix_text
    )
  })

  # Load RepPlus documentation once at startup
  repplus_docs <- tryCatch(load_repplus_docs(), error = function(e) list())

  # Reactive values to store chat responses
  chat_responses <- reactiveValues(
    biplot = NULL,
    crossplot = NULL,
    synopsis = NULL,
    heatmap = NULL,
    dend_elem = NULL,
    dend_const = NULL,
    focus = NULL,
    stats = NULL
  )

  # Helper to render chat response UI
  render_chat_response <- function(response) {
    if (is.null(response)) {
      return(NULL)
    }
    if (response$loading) {
      return(div(class = "chat-loading", "Asking Claude... please wait."))
    }
    if (!response$success) {
      # Check if it's just missing API key - show helpful message
      if (!is.null(response$error) && response$error == "NO_API_KEY") {
        return(div(class = "chat-panel",
          p("No API key configured. You can either:"),
          tags$ol(
            tags$li("Set ANTHROPIC_API_KEY in your .Renviron file for direct API access"),
            tags$li("Click 'Copy to Clipboard' and paste into ", tags$a(href = "https://claude.ai", target = "_blank", "Claude.ai"))
          ),
          p(tags$em("Your question and grid data are ready to copy below."))
        ))
      }
      return(div(class = "chat-error", response$error))
    }
    return(div(class = "chat-response", response$response))
  }

  # Biplot chat
  output$biplot_response <- renderUI({
    render_chat_response(chat_responses$biplot)
  })

  observeEvent(input$ask_biplot, {
    chat_responses$biplot <- list(loading = TRUE, success = FALSE)
    question <- if (is.null(input$chat_biplot_question) || input$chat_biplot_question == "") {
      "What patterns do you see in this PCA Biplot?"
    } else {
      input$chat_biplot_question
    }
    extra <- "The PCA Biplot shows elements as points and constructs as arrows.\n\n"
    result <- ask_claude_about_grid("PCA Biplot", question, generate_grid_summary(), repplus_docs, extra)
    chat_responses$biplot <- list(loading = FALSE, success = result$success, response = result$response, error = result$error)
  })

  observeEvent(input$copy_biplot, {
    question <- if (is.null(input$chat_biplot_question) || input$chat_biplot_question == "") {
      "What patterns do you see in this PCA Biplot?"
    } else {
      input$chat_biplot_question
    }
    extra <- "The PCA Biplot shows elements as points and constructs as arrows.\n\n"
    context <- generate_claude_context("PCA Biplot", question, generate_grid_summary(), extra)
    session$sendCustomMessage("copyToClipboard", context)
  })

  # Crossplot chat
  output$crossplot_response <- renderUI({
    render_chat_response(chat_responses$crossplot)
  })

  observeEvent(input$ask_crossplot, {
    chat_responses$crossplot <- list(loading = TRUE, success = FALSE)
    question <- if (is.null(input$chat_crossplot_question) || input$chat_crossplot_question == "") {
      "What patterns do you see in this Crossplot?"
    } else {
      input$chat_crossplot_question
    }
    extra <- paste0("Currently viewing crossplot with X-axis: ", input$crossplot_x, " and Y-axis: ", input$crossplot_y, "\n\n")
    result <- ask_claude_about_grid("Crossplot", question, generate_grid_summary(), repplus_docs, extra)
    chat_responses$crossplot <- list(loading = FALSE, success = result$success, response = result$response, error = result$error)
  })

  observeEvent(input$copy_crossplot, {
    question <- if (is.null(input$chat_crossplot_question) || input$chat_crossplot_question == "") {
      "What patterns do you see in this Crossplot?"
    } else {
      input$chat_crossplot_question
    }
    extra <- paste0("Currently viewing crossplot with X-axis: ", input$crossplot_x, " and Y-axis: ", input$crossplot_y, "\n\n")
    context <- generate_claude_context("Crossplot", question, generate_grid_summary(), extra)
    session$sendCustomMessage("copyToClipboard", context)
  })

  # Synopsis chat
  output$synopsis_response <- renderUI({
    render_chat_response(chat_responses$synopsis)
  })

  observeEvent(input$ask_synopsis, {
    chat_responses$synopsis <- list(loading = TRUE, success = FALSE)
    question <- if (is.null(input$chat_synopsis_question) || input$chat_synopsis_question == "") {
      "What patterns do you see in this Synopsis?"
    } else {
      input$chat_synopsis_question
    }
    extra <- paste0("Currently viewing: ", input$synopsis_type, " display.\n\n")
    result <- ask_claude_about_grid("Synopsis", question, generate_grid_summary(), repplus_docs, extra)
    chat_responses$synopsis <- list(loading = FALSE, success = result$success, response = result$response, error = result$error)
  })

  observeEvent(input$copy_synopsis, {
    question <- if (is.null(input$chat_synopsis_question) || input$chat_synopsis_question == "") {
      "What patterns do you see in this Synopsis?"
    } else {
      input$chat_synopsis_question
    }
    extra <- paste0("Currently viewing: ", input$synopsis_type, " display.\n\n")
    context <- generate_claude_context("Synopsis", question, generate_grid_summary(), extra)
    session$sendCustomMessage("copyToClipboard", context)
  })

  # Heatmap chat
  output$heatmap_response <- renderUI({
    render_chat_response(chat_responses$heatmap)
  })

  observeEvent(input$ask_heatmap, {
    chat_responses$heatmap <- list(loading = TRUE, success = FALSE)
    question <- if (is.null(input$chat_heatmap_question) || input$chat_heatmap_question == "") {
      "What patterns do you see in this Heatmap?"
    } else {
      input$chat_heatmap_question
    }
    extra <- "The heatmap shows all ratings as a color-coded grid (rows = elements, columns = constructs).\n\n"
    result <- ask_claude_about_grid("Heatmap", question, generate_grid_summary(), repplus_docs, extra)
    chat_responses$heatmap <- list(loading = FALSE, success = result$success, response = result$response, error = result$error)
  })

  observeEvent(input$copy_heatmap, {
    question <- if (is.null(input$chat_heatmap_question) || input$chat_heatmap_question == "") {
      "What patterns do you see in this Heatmap?"
    } else {
      input$chat_heatmap_question
    }
    extra <- "The heatmap shows all ratings as a color-coded grid (rows = elements, columns = constructs).\n\n"
    context <- generate_claude_context("Heatmap", question, generate_grid_summary(), extra)
    session$sendCustomMessage("copyToClipboard", context)
  })

  # Element Dendrogram chat
  output$dend_elem_response <- renderUI({
    render_chat_response(chat_responses$dend_elem)
  })

  observeEvent(input$ask_dend_elem, {
    chat_responses$dend_elem <- list(loading = TRUE, success = FALSE)
    question <- if (is.null(input$chat_dend_elem_question) || input$chat_dend_elem_question == "") {
      "What patterns do you see in this Element Dendrogram?"
    } else {
      input$chat_dend_elem_question
    }
    extra <- "The element dendrogram shows hierarchical clustering of elements based on rating similarity.\n\n"
    result <- ask_claude_about_grid("Element Dendrogram", question, generate_grid_summary(), repplus_docs, extra)
    chat_responses$dend_elem <- list(loading = FALSE, success = result$success, response = result$response, error = result$error)
  })

  observeEvent(input$copy_dend_elem, {
    question <- if (is.null(input$chat_dend_elem_question) || input$chat_dend_elem_question == "") {
      "What patterns do you see in this Element Dendrogram?"
    } else {
      input$chat_dend_elem_question
    }
    extra <- "The element dendrogram shows hierarchical clustering of elements based on rating similarity.\n\n"
    context <- generate_claude_context("Element Dendrogram", question, generate_grid_summary(), extra)
    session$sendCustomMessage("copyToClipboard", context)
  })

  # Construct Dendrogram chat
  output$dend_const_response <- renderUI({
    render_chat_response(chat_responses$dend_const)
  })

  observeEvent(input$ask_dend_const, {
    chat_responses$dend_const <- list(loading = TRUE, success = FALSE)
    question <- if (is.null(input$chat_dend_const_question) || input$chat_dend_const_question == "") {
      "What patterns do you see in this Construct Dendrogram?"
    } else {
      input$chat_dend_const_question
    }
    extra <- "The construct dendrogram shows hierarchical clustering of constructs.\n\n"
    result <- ask_claude_about_grid("Construct Dendrogram", question, generate_grid_summary(), repplus_docs, extra)
    chat_responses$dend_const <- list(loading = FALSE, success = result$success, response = result$response, error = result$error)
  })

  observeEvent(input$copy_dend_const, {
    question <- if (is.null(input$chat_dend_const_question) || input$chat_dend_const_question == "") {
      "What patterns do you see in this Construct Dendrogram?"
    } else {
      input$chat_dend_const_question
    }
    extra <- "The construct dendrogram shows hierarchical clustering of constructs.\n\n"
    context <- generate_claude_context("Construct Dendrogram", question, generate_grid_summary(), extra)
    session$sendCustomMessage("copyToClipboard", context)
  })

  # Focus Cluster chat
  output$focus_response <- renderUI({
    render_chat_response(chat_responses$focus)
  })

  observeEvent(input$ask_focus, {
    chat_responses$focus <- list(loading = TRUE, success = FALSE)
    question <- if (is.null(input$chat_focus_question) || input$chat_focus_question == "") {
      "What patterns do you see in this Focus Cluster analysis?"
    } else {
      input$chat_focus_question
    }
    extra <- paste0("Focus parameters: Minkowski power = ", input$focus_power, ", Match cutoff = ", input$focus_cutoff, "%\n\n")
    result <- ask_claude_about_grid("Focus Cluster", question, generate_grid_summary(), repplus_docs, extra)
    chat_responses$focus <- list(loading = FALSE, success = result$success, response = result$response, error = result$error)
  })

  observeEvent(input$copy_focus, {
    question <- if (is.null(input$chat_focus_question) || input$chat_focus_question == "") {
      "What patterns do you see in this Focus Cluster analysis?"
    } else {
      input$chat_focus_question
    }
    extra <- paste0("Focus parameters: Minkowski power = ", input$focus_power, ", Match cutoff = ", input$focus_cutoff, "%\n\n")
    context <- generate_claude_context("Focus Cluster", question, generate_grid_summary(), extra)
    session$sendCustomMessage("copyToClipboard", context)
  })

  # Statistics chat
  output$stats_response <- renderUI({
    render_chat_response(chat_responses$stats)
  })

  observeEvent(input$ask_stats, {
    chat_responses$stats <- list(loading = TRUE, success = FALSE)
    question <- if (is.null(input$chat_stats_question) || input$chat_stats_question == "") {
      "What patterns do you see in these Statistics?"
    } else {
      input$chat_stats_question
    }
    extra <- "Viewing element and construct statistics (means, standard deviations, etc.).\n\n"
    result <- ask_claude_about_grid("Statistics", question, generate_grid_summary(), repplus_docs, extra)
    chat_responses$stats <- list(loading = FALSE, success = result$success, response = result$response, error = result$error)
  })

  observeEvent(input$copy_stats, {
    question <- if (is.null(input$chat_stats_question) || input$chat_stats_question == "") {
      "What patterns do you see in these Statistics?"
    } else {
      input$chat_stats_question
    }
    extra <- "Viewing element and construct statistics (means, standard deviations, etc.).\n\n"
    context <- generate_claude_context("Statistics", question, generate_grid_summary(), extra)
    session$sendCustomMessage("copyToClipboard", context)
  })
}

shinyApp(ui, server)
