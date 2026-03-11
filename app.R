library(shiny)
library(OpenRepGrid)
library(DT)
library(uuid)
library(jsonlite)
library(igraph)

# Source the focus analysis functions
source("R/focus_analysis.r")
source("R/claude_api.R")
source("R/multigrid_analysis.r")

ui <- fluidPage(
  tags$head(
        tags$script(HTML('
      Shiny.addCustomMessageHandler("click_analyze", function(msg) {
        setTimeout(function() {
          var btn = document.getElementById("analyze");
          if (btn) btn.click();
        }, 500);
      });
    ')),
        tags$style(HTML('
      .container-fluid { max-width: 1400px; }
      body { font-size: 13px; }
      .form-group { margin-bottom: 8px; }
      .form-control { padding: 4px 8px; height: auto; font-size: 13px; }
      .btn { padding: 4px 10px; font-size: 12px; margin: 5px 0; }
      .btn-sm { padding: 4px 10px; font-size: 11px; }
      .sidebar .btn, .sidebar .btn-sm { display: block; width: 100%; margin-bottom: 10px; }
      .sidebar .shiny-input-container { margin-bottom: 10px; }
      .sidebar .form-group { margin-bottom: 10px; }
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
      .info-btn { padding: 0 6px; font-size: 11px; border-radius: 50%; margin-left: 4px; vertical-align: middle; }
      .info-popup { background: #d4edda; padding: 8px 10px; border-radius: 4px; border: 1px solid #c3e6cb; font-size: 12px; margin-bottom: 8px; color: #155724; }
      .info-popup strong { color: #0c5460; }
      .step-header { display: flex; align-items: center; margin-bottom: 6px; }
      .step-header h5 { margin: 0; }
      .ratings-section { background: #f0f7ff; padding: 10px; border-radius: 4px; border: 1px solid #b8daff; margin-top: 10px; }
      .ratings-section h5 { color: #004085; margin-top: 0; }
      .element-btn { margin: 2px; padding: 4px 8px; font-size: 11px; }
      .element-btn.selected-similar { background: #28a745; color: white; border-color: #28a745; }
      .element-btn.selected-different { background: #dc3545; color: white; border-color: #dc3545; }
      .triad-instruction { background: #fff3cd; padding: 8px; border-radius: 4px; border: 1px solid #ffc107; margin-bottom: 8px; font-size: 12px; }
      .triad-elements { margin: 8px 0; }
      .pole-label { font-size: 11px; color: #666; margin-bottom: 4px; }
      .pole-box { background: #f8f9fa; padding: 6px; border-radius: 4px; min-height: 36px; margin-bottom: 6px; border: 1px dashed #ccc; }
      .pole-box.similar { border-color: #28a745; background: #f0fff0; }
      .pole-box.different { border-color: #dc3545; background: #fff0f0; }
      .construct-section { display: none; }
      .construct-section.visible { display: block; }
      .next-step-buttons { text-align: center; margin-top: 10px; padding-top: 10px; border-top: 1px solid #ddd; }
      .sidebar hr { margin: 10px 0; }
      /* Multi-grid tab styling */
      .nav-tabs > li > a[data-value="Grid Collection"],
      .nav-tabs > li > a[data-value="Socionets"],
      .nav-tabs > li > a[data-value="Mode Grid"],
      .nav-tabs > li > a[data-value="Composite Grid"],
      .nav-tabs > li > a[data-value="MINUS"],
      .nav-tabs > li > a[data-value="CORE"],
      .nav-tabs > li > a[data-value="PrinGrid Trajectories"],
      .nav-tabs > li > a[data-value="Exchange Grids"],
      .nav-tabs > li > a[data-value="Class Metagrids"] {
        background: linear-gradient(135deg, #e8f4f8 0%, #d4e8ed 100%);
        border-color: #b8d4dc;
      }
      .nav-tabs > li.active > a[data-value="Grid Collection"],
      .nav-tabs > li.active > a[data-value="Socionets"],
      .nav-tabs > li.active > a[data-value="Mode Grid"],
      .nav-tabs > li.active > a[data-value="Composite Grid"],
      .nav-tabs > li.active > a[data-value="MINUS"],
      .nav-tabs > li.active > a[data-value="CORE"],
      .nav-tabs > li.active > a[data-value="PrinGrid Trajectories"],
      .nav-tabs > li.active > a[data-value="Exchange Grids"],
      .nav-tabs > li.active > a[data-value="Class Metagrids"] {
        background: #fff;
        border-bottom-color: #fff;
      }
      .multigrid-icon { margin-right: 4px; font-size: 10px; }
      /* Landing page styles */
      .landing-page { max-width: 600px; margin: 60px auto; padding: 40px; background: #fff; border-radius: 12px; box-shadow: 0 2px 20px rgba(0,0,0,0.08); }
      .landing-page h2 { margin-bottom: 8px; color: #333; }
      .landing-page p.subtitle { color: #666; margin-bottom: 24px; font-size: 15px; }
      .landing-page .item-row { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; }
      .landing-page .item-number { font-size: 18px; font-weight: bold; color: #0072B2; min-width: 28px; text-align: center; }
      .landing-page .item-input { flex: 1; }
      .landing-page .item-input .form-control { font-size: 15px; padding: 8px 12px; height: auto; }
      .landing-page .continue-btn { margin-top: 24px; text-align: center; }
      .landing-page .continue-btn .btn { font-size: 16px; padding: 10px 40px; }
      /* Rating page styles */
      .rating-page { max-width: 650px; }
      .rating-construct { font-size: 16px; font-weight: 600; color: #333; margin-bottom: 24px; text-align: center; padding: 12px; background: #f8f9fa; border-radius: 8px; }
      .rating-element { margin-bottom: 20px; }
      .rating-element-name { font-size: 15px; font-weight: 600; margin-bottom: 8px; color: #333; }
      .rating-scale { display: flex; align-items: center; gap: 0; }
      .rating-scale-track { flex: 1; display: flex; justify-content: space-between; align-items: center; position: relative; }
      .rating-scale-track::before { content: ""; position: absolute; top: 50%; left: 16px; right: 16px; height: 3px; background: #ddd; transform: translateY(-50%); z-index: 0; }
      .rating-btn { width: 36px; height: 36px; border: 2px solid #ddd; border-radius: 50%; background: #fff; cursor: pointer; font-size: 14px; font-weight: 600; color: #999; transition: all 0.15s; padding: 0; z-index: 1; position: relative; }
      .rating-btn:hover { border-color: #0072B2; color: #0072B2; transform: scale(1.1); }
      .rating-btn.selected { background: #0072B2; color: #fff; border-color: #0072B2; transform: scale(1.15); }
      .rating-scale-labels { display: flex; justify-content: space-between; font-size: 11px; color: #888; margin-top: 2px; padding: 0 6px; }
      .rating-progress-bar { height: 6px; background: #e9ecef; border-radius: 3px; margin-bottom: 20px; overflow: hidden; }
      .rating-progress-fill { height: 100%; background: #0072B2; border-radius: 3px; transition: width 0.3s; }
      .preset-card { border: 2px solid #ddd; border-radius: 10px; padding: 16px 20px; margin-bottom: 12px; cursor: pointer; transition: all 0.15s; background: #fff; }
      .preset-card:hover { border-color: #0072B2; background: #f0f8ff; }
      .preset-card h4 { margin: 0 0 6px 0; color: #333; }
      .preset-card .preset-detail { color: #666; font-size: 12px; margin: 0; }
      /* Triads wizard page */
      .triad-wizard .progress-text { color: #666; font-size: 13px; margin-bottom: 16px; }
      .triad-wizard .triad-cards { display: flex; gap: 16px; margin: 20px 0; justify-content: center; flex-wrap: wrap; }
      .triad-wizard .triad-card { border: 2px solid #ddd; border-radius: 10px; padding: 16px 20px; min-width: 120px; text-align: center; cursor: pointer; font-size: 16px; font-weight: 500; transition: all 0.15s; background: #fff; user-select: none; }
      .triad-wizard .triad-card:hover { border-color: #999; }
      .triad-wizard .triad-card.is-similar { border-color: #28a745; background: #e8f5e9; color: #1b5e20; }
      .triad-wizard .triad-card.is-different { border-color: #dc3545; background: #fce4ec; color: #b71c1c; }
      .triad-wizard .pole-inputs { margin-top: 20px; }
      .triad-wizard .pole-inputs label { font-size: 13px; font-weight: 600; }
      .triad-wizard .pole-inputs .form-control { font-size: 15px; padding: 8px 12px; height: auto; }
      .triad-wizard .wizard-buttons { margin-top: 24px; display: flex; gap: 10px; justify-content: center; flex-wrap: wrap; }
      .triad-wizard .instruction-text { background: #fff3cd; padding: 10px 14px; border-radius: 6px; border: 1px solid #ffc107; font-size: 13px; margin-bottom: 16px; }
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
      Shiny.addCustomMessageHandler("openMailto", function(url) {
        window.location.href = url;
      });
      Shiny.addCustomMessageHandler("clickButton", function(id) {
        var btn = document.getElementById(id);
        if (btn) btn.click();
      });
      Shiny.addCustomMessageHandler("scrollToElement", function(id) {
        var el = document.getElementById(id);
        if (el) {
          el.scrollIntoView({ behavior: "smooth", block: "start" });
        }
      });
    '))
  ),
  titlePanel("WebGrid.Online"),
  # Landing page - shown initially
  conditionalPanel(
    condition = "output.landing_step == 'elements'",
    div(class = "landing-page",
      h2("Welcome to WebGrid.Online"),
      p(class = "subtitle", "A repertory grid helps you explore how you think about things by comparing them."),
      p("To get started, list 5 things you'd like to compare. They could be people, places, products, ideas — anything in the same category."),
      p(tags$em("For example: 5 friends, 5 cities you've lived in, 5 programming languages, 5 foods you eat regularly."), style = "color: #888; font-size: 12px;"),
      div(class = "item-row", span(class = "item-number", "1."), div(class = "item-input", textInput("landing_item1", NULL, placeholder = "e.g. Pizza"))),
      div(class = "item-row", span(class = "item-number", "2."), div(class = "item-input", textInput("landing_item2", NULL, placeholder = "e.g. Sushi"))),
      div(class = "item-row", span(class = "item-number", "3."), div(class = "item-input", textInput("landing_item3", NULL, placeholder = "e.g. Tacos"))),
      div(class = "item-row", span(class = "item-number", "4."), div(class = "item-input", textInput("landing_item4", NULL, placeholder = "e.g. Pasta"))),
      div(class = "item-row", span(class = "item-number", "5."), div(class = "item-input", textInput("landing_item5", NULL, placeholder = "e.g. Curry"))),
      div(class = "continue-btn",
        actionButton("landing_continue", "Continue", class = "btn-success btn-lg"),
        div(style = "margin-top: 12px;",
          actionButton("landing_existing", "Use an Existing Grid", class = "btn-outline-primary")
        )
      )
    )
  ),
  # Preset picker page
  conditionalPanel(
    condition = "output.landing_step == 'presets'",
    div(class = "landing-page",
      h2("Choose a Grid"),
      p(class = "subtitle", "Select a pre-built grid with elements and constructs ready to rate."),
      uiOutput("preset_list"),
      div(class = "continue-btn", style = "margin-top: 16px;",
        actionButton("landing_back", "Back", class = "btn-outline-secondary")
      )
    )
  ),
  # Triads wizard page
  conditionalPanel(
    condition = "output.landing_step == 'triads'",
    div(class = "landing-page triad-wizard",
      h2("How do these compare?"),
      p(class = "subtitle", "We'll show you 3 items at a time. Tap 2 that are similar, and 1 that is different."),
      uiOutput("wizard_progress"),
      div(class = "instruction-text",
        "Click each card to mark it as ", tags$strong("Similar"), " (green) or ", tags$strong("Different"), " (red). Pick 2 similar and 1 different."
      ),
      uiOutput("wizard_triad_cards"),
      div(class = "pole-inputs",
        textInput("wizard_left_pole", "How are the two similar ones alike?", placeholder = "e.g. sweet"),
        textInput("wizard_right_pole", "How is the different one different?", placeholder = "e.g. savoury")
      ),
      div(class = "wizard-buttons",
        actionButton("wizard_next", "Next", class = "btn-success btn-lg"),
        actionButton("wizard_skip", "Skip", class = "btn-outline-secondary"),
        actionButton("wizard_finish", "Finish & See Results", class = "btn-outline-primary")
      )
    )
  ),
  # Constructs summary page - after elicitation
  conditionalPanel(
    condition = "output.landing_step == 'results'",
    div(class = "landing-page", style = "max-width: 700px;",
      uiOutput("wizard_results_heading"),
      uiOutput("wizard_results_summary"),
      div(class = "continue-btn", style = "margin-top: 24px;",
        uiOutput("wizard_mailto_constructs"),
        div(style = "margin-top: 12px;",
          actionButton("results_to_app", "Continue to Rating",
                       class = "btn-success btn-lg")
        )
      )
    )
  ),
  # Rating page - one construct at a time
  conditionalPanel(
    condition = "output.landing_step == 'rating'",
    div(class = "landing-page rating-page",
      uiOutput("rating_overall_progress"),
      uiOutput("rating_construct_label"),
      uiOutput("rating_elements_ui"),
      div(class = "continue-btn", style = "margin-top: 24px;",
        actionButton("rating_prev", "Back", class = "btn-outline-secondary",
                     style = "margin-right: 10px;"),
        actionButton("rating_next", "Next Construct", class = "btn-success btn-lg")
      )
    )
  ),
  # Post-rating summary - visualization + email
  conditionalPanel(
    condition = "output.landing_step == 'post_rating'",
    div(class = "landing-page", style = "max-width: 700px;",
      h2("Your Grid"),
      p(class = "subtitle", "Here's a preview of your repertory grid analysis."),
      plotOutput("wizard_preview_plot", height = "400px"),
      div(class = "continue-btn", style = "margin-top: 24px;",
        uiOutput("wizard_mailto_ratings"),
        div(style = "margin-top: 16px;",
          p(style = "color: #666; font-size: 13px;",
            "Want to explore more? The full app includes heatmaps, dendrograms, Focus clusters, and more."),
          actionButton("post_rating_continue", "Explore Other Visualisations",
                       class = "btn-success btn-lg")
        )
      )
    )
  ),
  # Main app - shown after results
  conditionalPanel(
    condition = "output.landing_step == 'done'",
  sidebarLayout(
    sidebarPanel(
      width = 2,
      class = "sidebar",
      actionButton("goto_simple_start", "Simple Start",
                   class = "btn-success btn-sm btn-block",
                   style = "margin-bottom: 16px; width: 100%;"),
      h4("File Operations"),
      fileInput("import_file", "Select Grid File", accept = c(".rgrid", ".json")),
      uiOutput("load_grid_prompt"),
      div(style = "margin-top: -20px;",
        actionButton("import_grid", "Load to Editor", class = "btn-secondary btn-sm")
      ),
      tags$small(class = "text-muted", "Accepts .rgrid or .json files"),
      actionButton("load_sample", "Load Sample Data", class = "btn-outline-info btn-sm", style = "margin-top: 8px;"),
      div(style = "margin-top: 12px; padding-top: 8px; border-top: 1px dashed #ccc;",
        tags$strong("Grid Collection", style = "font-size: 12px;"),
        fileInput("import_multi_grid", "Select Grid File(s)",
                  accept = c(".rgrid", ".json"), multiple = TRUE),
        div(style = "margin-top: -20px;",
          actionButton("add_files_to_collection", "Add to Collection", class = "btn-secondary btn-sm"),
          actionButton("add_current_grid", "Add Current Grid",
                       class = "btn-outline-success btn-sm", style = "margin-left: 4px;")
        ),
        uiOutput("grid_collection_summary")
      ),
      tags$hr(),
      h4("Analysis"),
      uiOutput("analyse_button_ui"),
      div(style = "display: flex; align-items: center; gap: 6px; margin-top: 8px;",
        checkboxInput("impute_missing", "Impute missing", value = FALSE),
        actionButton("info_impute", "?", class = "btn-info",
                     style = "width: 18px; height: 18px; padding: 0; font-size: 11px; line-height: 18px; border-radius: 50%; margin-top: -20px;")
      ),
      conditionalPanel(
        condition = "input.info_impute % 2 == 1",
        div(class = "info-popup", style = "font-size: 11px;",
          tags$strong("Impute Missing Ratings"), tags$br(),
          "When checked, any missing ratings will be replaced with the midpoint value (4 on a 1-7 scale) before analysis.",
          tags$br(), tags$br(),
          tags$em("Use this when: "), "You have incomplete ratings but want to run analysis anyway. The imputed values are neutral and won't strongly influence results."
        )
      ),
      tags$hr(),
      h4("Display Options"),
      p("Each visualization has its own color palette selector.", style = "font-size: 11px; color: #666;"),
      # Text size control
      sliderInput("text_size", "Text Size", min = 0.8, max = 1.6, value = 1.2, step = 0.1),
      # Grid cell size for heatmap/focus
      sliderInput("grid_cell_size", "Heatmap/Focus Cell Size", min = 0.8, max = 2.0, value = 1.2, step = 0.1),
      tags$hr(),
      h4("Export"),
      downloadButton("download_grid", "Download Grid as CSV"),
      downloadButton("download_rgrid", "Download Grid as .rgrid"),
      tags$hr(),
      actionButton("clear_all", "Clear All Data", class = "btn-outline-danger btn-sm")
    ),
    mainPanel(
      width = 10,
      tabsetPanel(id = "main_tabs",
        tabPanel(
          "Build Grid",
          div(class = "elicit-panel",
            h4("Build Your Repertory Grid"),

            # Step 1: Elements (always visible)
            div(class = "elicit-section",
              div(class = "step-header",
                h5("Step 1: Add Elements"),
                actionButton("info_elements", "?", class = "btn-info info-btn"),
                actionButton("load_sample_elements", "Try Sample Fruits", class = "btn-outline-secondary btn-sm", style = "margin-left: 8px; font-size: 10px;")
              ),
              conditionalPanel(
                condition = "input.info_elements % 2 == 1",
                div(class = "info-popup",
                  tags$strong("Elements"), " are the things you want to compare - people, objects, situations, etc.",
                  tags$br(),
                  "Examples: Mother, Father, Best friend, Ideal self, Boss",
                  tags$br(),
                  tags$em("Tip: Add at least 6-12 elements for meaningful analysis.")
                )
              ),
              fluidRow(
                column(6,
                  textInput("element_name", NULL, placeholder = "Type element name"),
                  actionButton("add_element", "Add", class = "btn-warning btn-sm")
                ),
                column(6,
                  tags$small("Or paste list:"),
                  tags$textarea(id = "elements_bulk", rows = 2, style = "width: 100%; font-size: 11px;", placeholder = "One per line"),
                  actionButton("add_elements_bulk", "Add All", class = "btn-warning btn-sm", style = "margin-top: 2px;")
                )
              ),
              uiOutput("elements_display"),
              div(class = "next-step-buttons",
                actionButton("begin_elicitation", "Begin Guided Elicitation", class = "btn-success"),
                actionButton("show_manual_constructs", "Add Constructs Manually", class = "btn-outline-primary", style = "margin-left: 8px;")
              )
            ),

            # Step 2: Constructs - shown via UI output based on mode
            uiOutput("constructs_section_ui")
          ),

          # Step 3: Ratings - only show when constructs exist
          uiOutput("ratings_section_ui")
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
          fluidRow(
            column(4,
              selectInput("biplot_palette", "Color Palette",
                          choices = c(
                            "Accessible (Wong)" = "wong",
                            "Classic (Blue/Red)" = "classic",
                            "Earth Tones" = "earth",
                            "High Contrast" = "contrast",
                            "Greyscale" = "greyscale"
                          ),
                          selected = "wong")
            )
          ),
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
              ),
              h5("Understanding construct arrow labels"),
              div(style = "background: #fff3cd; padding: 8px; border-radius: 4px; border: 1px solid #ffc107; margin-top: 6px;",
                p(style = "margin: 0;", tags$strong("Arrow labels show the HIGH-SCORING pole (rating = 7).")),
                p(style = "margin: 6px 0 0 0; font-size: 11px;",
                  "Each construct has two poles: LEFT (rating 1) and RIGHT (rating 7). ",
                  "The arrow points toward elements rated HIGH (7) on that construct. ",
                  "For example, if your construct is 'cheap - expensive' and the arrow label shows 'expensive', ",
                  "elements near the arrow tip were rated as more expensive (closer to 7)."
                ),
                p(style = "margin: 6px 0 0 0; font-size: 11px;",
                  "Elements in the ", tags$em("opposite"), " direction from the arrow were rated LOW (closer to 1, the left pole)."
                )
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
                   column(2,
                          checkboxInput("crossplot_labels", "Show Element Labels", value = TRUE),
                          checkboxInput("crossplot_grid", "Show Grid Lines", value = TRUE)
                   ),
                   column(2,
                          selectInput("crossplot_palette", "Color Palette",
                                      choices = c(
                                        "Accessible (Wong)" = "wong",
                                        "Classic (Blue/Red)" = "classic",
                                        "Earth Tones" = "earth",
                                        "High Contrast" = "contrast",
                                        "Greyscale" = "greyscale"
                                      ),
                                      selected = "wong"),
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
                 fluidRow(
                   column(4,
                     checkboxInput("heatmap_use_color", "Use color shading", value = TRUE)
                   ),
                   column(4,
                     selectInput("heatmap_palette", "Color Palette",
                                 choices = c(
                                   "Accessible (Wong)" = "wong",
                                   "Classic (Blue/Red)" = "classic",
                                   "Earth Tones" = "earth",
                                   "High Contrast" = "contrast",
                                   "Greyscale" = "greyscale"
                                 ),
                                 selected = "wong")
                   )
                 ),
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
                          div(style = "display: flex; align-items: center;",
                            tags$label("Minkowski Power:", style = "margin-right: 4px;"),
                            actionButton("info_minkowski", "?", class = "btn-info info-btn")
                          ),
                          sliderInput("focus_power", NULL,
                                    min = 0.5, max = 3.0, value = 1.0, step = 0.1),
                          conditionalPanel(
                            condition = "input.info_minkowski % 2 == 1",
                            div(class = "info-popup", style = "font-size: 11px;",
                              tags$strong("Minkowski Power"), " controls how differences are measured:",
                              tags$ul(style = "margin: 4px 0; padding-left: 18px;",
                                tags$li(tags$strong("1.0 (City block/Manhattan):"), " Treats all rating differences equally. A difference of 2 on one construct = two differences of 1. Good default for most grids."),
                                tags$li(tags$strong("2.0 (Euclidean):"), " Larger differences count more. A difference of 2 counts as 4, not 2. Use when big differences are more meaningful than small ones."),
                                tags$li(tags$strong("< 1.0:"), " Reduces impact of large differences. Use when you want to emphasise overall patterns over extreme ratings."),
                                tags$li(tags$strong("> 2.0:"), " Amplifies large differences further. Clusters become dominated by the biggest rating gaps.")
                              ),
                              tags$em("Recommendation: Start with 1.0, try 2.0 if clusters seem too loose.")
                            )
                          )
                   ),
                   column(3,
                          div(style = "display: flex; align-items: center;",
                            tags$label("Match Cutoff (%):", style = "margin-right: 4px;"),
                            actionButton("info_cutoff", "?", class = "btn-info info-btn")
                          ),
                          sliderInput("focus_cutoff", NULL,
                                    min = 0, max = 100, value = 80, step = 5),
                          conditionalPanel(
                            condition = "input.info_cutoff % 2 == 1",
                            div(class = "info-popup", style = "font-size: 11px;",
                              tags$strong("Match Cutoff"), " filters which similarity scores are shown:",
                              tags$ul(style = "margin: 4px 0; padding-left: 18px;",
                                tags$li(tags$strong("80% (default):"), " Shows only strong matches. Elements/constructs must be 80%+ similar to appear as a match."),
                                tags$li(tags$strong("90%+:"), " Very strict - only near-identical items shown. Useful for finding redundant constructs."),
                                tags$li(tags$strong("60-70%:"), " More lenient - shows moderate similarities. Good for exploring broader patterns."),
                                tags$li(tags$strong("0%:"), " Shows all matches regardless of strength.")
                              ),
                              tags$em("Note: This only affects the match statistics below, not the dendrogram structure.")
                            )
                          )
                   ),
                   column(3,
                          checkboxInput("focus_show_values", "Show Rating Values", value = TRUE),
                          checkboxInput("focus_show_shading", "Show Shading", value = TRUE),
                          checkboxInput("focus_use_color", "Use color shading", value = TRUE),
                          checkboxInput("focus_spaced", "SPACED: Proportional Spacing", value = FALSE),
                          selectInput("focus_palette", "Color Palette",
                                      choices = c(
                                        "Accessible (Wong)" = "wong",
                                        "Classic (Blue/Red)" = "classic",
                                        "Earth Tones" = "earth",
                                        "High Contrast" = "contrast",
                                        "Greyscale" = "greyscale"
                                      ),
                                      selected = "wong")
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
                 ),
                 tags$hr(),
                 actionButton("foci_interpret", "FOCI: Generate Interpretation", class = "btn-warning"),
                 conditionalPanel(
                   condition = "input.foci_interpret % 2 == 1",
                   div(class = "chat-panel", style = "background: #fff3cd; padding: 15px; border-radius: 8px; margin-top: 10px;",
                     h5("FOCI: Automated Focus Interpretation"),
                     p("Sends your Focus analysis data to Claude for structured interpretation of clusters and patterns."),
                     div(class = "btn-group-chat",
                       actionButton("run_foci", "Generate Interpretation", class = "btn-primary"),
                       actionButton("copy_foci", "Copy Context to Clipboard", class = "btn-secondary"),
                       tags$a(href = "https://claude.ai", target = "_blank", class = "btn btn-outline-secondary", "Open Claude.ai")
                     ),
                     uiOutput("foci_response")
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
      ),  # end single-grid tabsetPanel

      # ===== MULTI-GRID TABS =====
      tabsetPanel(id = "multi_tabs",
        tabPanel(title = tagList(tags$span(class = "multigrid-icon", "\U0001F4CA\U0001F4CA"), "Grid Collection"),
                 value = "Grid Collection",
                 h4("Manage Grid Collection"),
                 p("Upload multiple grids to compare and analyze relationships between them."),
                 fluidRow(
                   column(6,
                          h5("Loaded Grids"),
                          DTOutput("grid_collection_table"),
                          div(style = "margin-top: 10px;",
                            actionButton("select_all_grids", "Select All", class = "btn-outline-primary btn-sm"),
                            actionButton("deselect_all_grids", "Deselect All", class = "btn-outline-secondary btn-sm"),
                            actionButton("remove_selected_grids", "Remove Selected", class = "btn-outline-danger btn-sm")
                          )
                   ),
                   column(6,
                          h5("Common Structure"),
                          uiOutput("common_structure_info"),
                          tags$hr(),
                          h5("Multi-Grid Analysis Options"),
                          div(style = "margin-bottom: 8px;",
                            actionLink("goto_socionets", "Socionets", style = "font-weight: bold;"),
                            actionButton("info_socionets", "i", class = "btn-info btn-xs",
                                        style = "width: 16px; height: 16px; padding: 0; font-size: 10px; line-height: 16px; border-radius: 50%; margin-left: 4px;"),
                            conditionalPanel(
                              condition = "input.info_socionets % 2 == 1",
                              tags$small(class = "text-muted", style = "display: block; margin-left: 10px;",
                                        "Shows a network diagram of how similar each participant's grid is to others. Nodes are grids, edges show match percentages.")
                            )
                          ),
                          div(style = "margin-bottom: 8px;",
                            actionLink("goto_mode", "Mode Grid", style = "font-weight: bold;"),
                            actionButton("info_mode_link", "i", class = "btn-info btn-xs",
                                        style = "width: 16px; height: 16px; padding: 0; font-size: 10px; line-height: 16px; border-radius: 50%; margin-left: 4px;"),
                            conditionalPanel(
                              condition = "input.info_mode_link % 2 == 1",
                              tags$small(class = "text-muted", style = "display: block; margin-left: 10px;",
                                        "Creates a consensus grid representing the 'typical' view across all participants by averaging or taking the median of ratings.")
                            )
                          ),
                          div(style = "margin-bottom: 8px;",
                            actionLink("goto_composite", "Composite Grid", style = "font-weight: bold;"),
                            actionButton("info_composite_link", "i", class = "btn-info btn-xs",
                                        style = "width: 16px; height: 16px; padding: 0; font-size: 10px; line-height: 16px; border-radius: 50%; margin-left: 4px;"),
                            conditionalPanel(
                              condition = "input.info_composite_link % 2 == 1",
                              tags$small(class = "text-muted", style = "display: block; margin-left: 10px;",
                                        "Merges all grids into one large grid, combining constructs from all participants for unified analysis.")
                            )
                          ),
                          div(style = "margin-bottom: 8px;",
                            actionLink("goto_minus", "MINUS Analysis", style = "font-weight: bold;"),
                            actionButton("info_minus_link", "i", class = "btn-info btn-xs",
                                        style = "width: 16px; height: 16px; padding: 0; font-size: 10px; line-height: 16px; border-radius: 50%; margin-left: 4px;"),
                            conditionalPanel(
                              condition = "input.info_minus_link % 2 == 1",
                              tags$small(class = "text-muted", style = "display: block; margin-left: 10px;",
                                        "Subtracts one grid from another to show cell-by-cell differences. Requires grids with shared elements AND constructs.")
                            )
                          ),
                          div(style = "margin-bottom: 8px;",
                            actionLink("goto_core", "CORE Analysis", style = "font-weight: bold;"),
                            actionButton("info_core_link", "i", class = "btn-info btn-xs",
                                        style = "width: 16px; height: 16px; padding: 0; font-size: 10px; line-height: 16px; border-radius: 50%; margin-left: 4px;"),
                            conditionalPanel(
                              condition = "input.info_core_link % 2 == 1",
                              tags$small(class = "text-muted", style = "display: block; margin-left: 10px;",
                                        "Iteratively removes least-agreed items to reveal the core of shared construing between two grids.")
                            )
                          ),
                          div(style = "margin-bottom: 8px;",
                            actionLink("goto_trajectories", "PrinGrid Trajectories", style = "font-weight: bold;"),
                            actionButton("info_traj_link", "i", class = "btn-info btn-xs",
                                        style = "width: 16px; height: 16px; padding: 0; font-size: 10px; line-height: 16px; border-radius: 50%; margin-left: 4px;"),
                            conditionalPanel(
                              condition = "input.info_traj_link % 2 == 1",
                              tags$small(class = "text-muted", style = "display: block; margin-left: 10px;",
                                        "PCA biplot showing how elements move across grids, with trajectory arrows connecting same elements.")
                            )
                          ),
                          div(style = "margin-bottom: 8px;",
                            actionLink("goto_exchange", "Exchange Grids", style = "font-weight: bold;"),
                            actionButton("info_exchange_link", "i", class = "btn-info btn-xs",
                                        style = "width: 16px; height: 16px; padding: 0; font-size: 10px; line-height: 16px; border-radius: 50%; margin-left: 4px;"),
                            conditionalPanel(
                              condition = "input.info_exchange_link % 2 == 1",
                              tags$small(class = "text-muted", style = "display: block; margin-left: 10px;",
                                        "6-grid protocol measuring agreement and understanding between two people using CORE analysis.")
                            )
                          ),
                          div(style = "margin-bottom: 8px;",
                            actionLink("goto_metagrids", "Class Metagrids", style = "font-weight: bold;"),
                            actionButton("info_metagrid_link", "i", class = "btn-info btn-xs",
                                        style = "width: 16px; height: 16px; padding: 0; font-size: 10px; line-height: 16px; border-radius: 50%; margin-left: 4px;"),
                            conditionalPanel(
                              condition = "input.info_metagrid_link % 2 == 1",
                              tags$small(class = "text-muted", style = "display: block; margin-left: 10px;",
                                        "Create a higher-order grid where your grids become elements, rated on custom constructs for classification.")
                            )
                          ),
                          tags$hr(),
                          h5("Open Grid for Editing"),
                          selectInput("preview_grid_select", "Select Grid:", choices = NULL),
                          actionButton("load_preview_to_editor", "Load to Editor", class = "btn-primary btn-sm"),
                          tags$small(class = "text-muted", "Opens selected grid in Build Grid tab for viewing and analysis")
                   )
                 ),
                 tags$hr(),
                 actionButton("help_collection", "Help me understand this", class = "btn-info help-btn"),
                 conditionalPanel(
                   condition = "input.help_collection % 2 == 1",
                   div(class = "help-content",
                     h5("What is a Grid Collection?"),
                     p("A grid collection allows you to compare multiple repertory grids from different participants who rated the same elements. This enables group-level analysis using Shaw's (1980) SOCIOGRIDS methodology."),
                     h5("How to use"),
                     tags$ol(
                       tags$li(tags$strong("Add grids"), " - Use 'Add Grid(s) to Collection' in the sidebar to upload multiple .rgrid files, or add your current grid"),
                       tags$li(tags$strong("Select grids"), " - Click rows in the table to select which grids to include in analysis"),
                       tags$li(tags$strong("Check common elements"), " - The system detects elements shared across grids (needed for comparison)"),
                       tags$li(tags$strong("Run analysis"), " - Use the Socionets, Mode Grid, or Composite Grid tabs")
                     ),
                     h5("Opening a grid for detailed view"),
                     p("Select a grid from the dropdown and click 'Load to Editor' to open it in the Build Grid tab for full viewing and analysis."),
                     h5("Requirements"),
                     tags$ul(
                       tags$li("At least 2 grids selected"),
                       tags$li("At least 2 common elements across selected grids"),
                       tags$li("Grids should ideally share the same elements (e.g., same interview protocol)")
                     )
                   )
                 )
        ),

        tabPanel(title = tagList(tags$span(class = "multigrid-icon", "\U0001F4CA\U0001F4CA"), "Socionets"),
                 value = "Socionets",
                 h4("Socionets Analysis"),
                 p("Network visualization showing relationships between grids based on construct matching."),
                 fluidRow(
                   column(8,
                          plotOutput("socionet_plot", height = "500px")
                   ),
                   column(4,
                          sliderInput("socionet_cutoff", "Match Cutoff (%)",
                                      min = 0, max = 100, value = 70, step = 5),
                          checkboxInput("socionet_symmetric", "Symmetric Matching", value = FALSE),
                          checkboxInput("socionet_show_weights", "Show Match Percentages", value = TRUE),
                          sliderInput("socionet_text_size", "Text Size",
                                      min = 0.8, max = 2.0, value = 1.2, step = 0.1),
                          selectInput("socionet_node_color", "Node Color:",
                                      choices = c("Steel Blue" = "steelblue",
                                                 "Forest Green" = "forestgreen",
                                                 "Coral" = "coral",
                                                 "Purple" = "mediumpurple",
                                                 "Gold" = "goldenrod")),
                          selectInput("socionet_edge_color", "Edge Color:",
                                      choices = c("Dark Grey" = "darkgrey",
                                                 "Navy" = "navy",
                                                 "Dark Red" = "darkred",
                                                 "Dark Green" = "darkgreen")),
                          actionButton("compute_socionets", "Compute Matches", class = "btn-primary"),
                          tags$hr(),
                          downloadButton("download_match_matrix", "Download Match Matrix (CSV)"),
                          downloadButton("download_socionets_plot", "Download Plot")
                   )
                 ),
                 tags$hr(),
                 h5("Match Matrix"),
                 DTOutput("match_matrix_table"),
                 tags$hr(),
                 actionButton("help_socionets", "Help me understand this visualisation", class = "btn-info help-btn"),
                 conditionalPanel(
                   condition = "input.help_socionets % 2 == 1",
                   div(class = "help-content",
                     h5("Socionets Analysis"),
                     p("Socionets (Shaw, 1980) shows how similar different grids are based on construct matching."),
                     tags$ul(
                       tags$li(tags$strong("Nodes"), " represent individual grids (participants)"),
                       tags$li(tags$strong("Edges"), " show match percentages - how well one person could understand another's constructs"),
                       tags$li(tags$strong("Arrow direction"), " indicates asymmetric matching: A->B means A's constructs match B's ratings"),
                       tags$li(tags$strong("Edge thickness"), " indicates strength of match")
                     ),
                     h5("Parameters"),
                     tags$ul(
                       tags$li(tags$strong("Match Cutoff"), " - only show connections above this similarity threshold"),
                       tags$li(tags$strong("Symmetric Matching"), " - average bidirectional matches (A->B and B->A)")
                     ),
                     h5("Interpretation"),
                     tags$ul(
                       tags$li("High match % = similar way of construing the elements"),
                       tags$li("Clusters of connected grids = groups with shared understanding"),
                       tags$li("Isolated nodes = outliers with different perspective")
                     )
                   )
                 )
        ),

        tabPanel(title = tagList(tags$span(class = "multigrid-icon", "\U0001F4CA\U0001F4CA"), "Mode Grid"),
                 value = "Mode Grid",
                 h4("Mode (Consensus) Grid"),
                 p("Generate a consensus grid representing commonality across multiple participants."),
                 fluidRow(
                   column(8,
                          plotOutput("mode_grid_heatmap", height = "450px")
                   ),
                   column(4,
                          selectInput("mode_method", "Consensus Method:",
                                      choices = c("Average" = "average", "Median" = "median")),
                          selectInput("mode_construct_handling", "Construct Handling:",
                                      choices = c("Fold Identical" = "fold", "Collect All" = "collect")),
                          selectInput("mode_palette", "Color Palette",
                                      choices = c(
                                        "Accessible (Wong)" = "wong",
                                        "Classic (Blue/Red)" = "classic",
                                        "Earth Tones" = "earth",
                                        "High Contrast" = "contrast",
                                        "Greyscale" = "greyscale"
                                      ),
                                      selected = "wong"),
                          checkboxInput("mode_show_values", "Show Rating Values", value = TRUE),
                          sliderInput("mode_text_size", "Text Size",
                                      min = 0.8, max = 2.0, value = 1.2, step = 0.1),
                          actionButton("generate_mode_grid", "Generate Mode Grid", class = "btn-primary"),
                          tags$hr(),
                          actionButton("use_mode_as_current", "Use as Current Grid", class = "btn-success btn-sm"),
                          downloadButton("download_mode_grid", "Download Mode Grid (.rgrid)")
                   )
                 ),
                 fluidRow(
                   column(12,
                          h5("Mode Grid Summary"),
                          verbatimTextOutput("mode_grid_summary")
                   )
                 ),
                 tags$hr(),
                 actionButton("help_mode", "Help me understand this", class = "btn-info help-btn"),
                 conditionalPanel(
                   condition = "input.help_mode % 2 == 1",
                   div(class = "help-content",
                     h5("Mode Grid"),
                     p("A Mode Grid represents the consensus or 'typical' grid from a group of participants."),
                     h5("Consensus Method"),
                     tags$ul(
                       tags$li(tags$strong("Average"), " - mean of ratings across all grids"),
                       tags$li(tags$strong("Median"), " - middle value, more robust to outliers")
                     ),
                     h5("Construct Handling"),
                     tags$ul(
                       tags$li(tags$strong("Fold Identical"), " - combine constructs with same labels, average their ratings"),
                       tags$li(tags$strong("Collect All"), " - include all constructs from all grids (labeled by source)")
                     ),
                     h5("Use cases"),
                     tags$ul(
                       tags$li("Identifying shared understanding in a team"),
                       tags$li("Creating a baseline for comparison"),
                       tags$li("Reducing multiple perspectives to a single representation")
                     )
                   )
                 )
        ),

        tabPanel(title = tagList(tags$span(class = "multigrid-icon", "\U0001F4CA\U0001F4CA"), "Composite Grid"),
                 value = "Composite Grid",
                 h4("Composite Grid"),
                 p("Merge multiple grids into a single combined grid for unified analysis."),
                 fluidRow(
                   column(8,
                          DTOutput("composite_grid_table")
                   ),
                   column(4,
                          radioButtons("composite_merge_on", "Merge Strategy:",
                                       choices = c("Common Elements + All Constructs" = "elements",
                                                  "Common Constructs + All Elements" = "constructs")),
                          checkboxInput("composite_label_source", "Label Items by Source Grid", value = TRUE),
                          actionButton("generate_composite_grid", "Generate Composite Grid", class = "btn-primary"),
                          tags$hr(),
                          actionButton("use_composite_as_current", "Use as Current Grid", class = "btn-success btn-sm"),
                          downloadButton("download_composite_grid", "Download Composite Grid (.rgrid)")
                   )
                 ),
                 fluidRow(
                   column(12,
                          h5("Composite Grid Summary"),
                          verbatimTextOutput("composite_grid_summary")
                   )
                 ),
                 tags$hr(),
                 actionButton("help_composite", "Help me understand this", class = "btn-info help-btn"),
                 conditionalPanel(
                   condition = "input.help_composite % 2 == 1",
                   div(class = "help-content",
                     h5("Composite Grid"),
                     p("A Composite Grid merges data from multiple grids into one for unified analysis."),
                     h5("Merge Strategies"),
                     tags$ul(
                       tags$li(tags$strong("Common Elements + All Constructs"), " - Use shared elements as rows, include all constructs from all grids as columns. Good for comparing how different people construe the same elements."),
                       tags$li(tags$strong("Common Constructs + All Elements"), " - Use shared constructs as columns, include all elements from all grids as rows. Good for comparing how the same dimensions apply to different elements.")
                     ),
                     h5("Source Labeling"),
                     p("When enabled, constructs/elements are labeled with their source grid name (e.g., 'friendly [Grid1]') to track origin."),
                     h5("Use cases"),
                     tags$ul(
                       tags$li("PrinGrid trajectories showing change over time"),
                       tags$li("Comparing perspectives on shared elements"),
                       tags$li("Focus analysis across multiple participants")
                     )
                   )
                 )
        ),

        # ===== MINUS Analysis Tab =====
        tabPanel(title = tagList(tags$span(class = "multigrid-icon", "\U0001F4CA\U0001F4CA"), "MINUS"),
                 value = "MINUS",
                 h4("MINUS Analysis: Grid Differences"),
                 p("Subtract one grid from another to see differences in construing. Requires two grids with shared elements AND constructs."),
                 fluidRow(
                   column(8,
                          plotOutput("minus_plot", height = "500px")
                   ),
                   column(4,
                          selectInput("minus_grid_a", "Grid A:", choices = NULL),
                          selectInput("minus_grid_b", "Grid B:", choices = NULL),
                          checkboxInput("minus_show_values", "Show Difference Values", value = TRUE),
                          checkboxInput("minus_show_pct", "Show as Percentage", value = FALSE),
                          sliderInput("minus_text_size", "Text Size",
                                      min = 0.8, max = 2.0, value = 1.2, step = 0.1),
                          actionButton("compute_minus", "Compute MINUS", class = "btn-primary"),
                          tags$hr(),
                          downloadButton("download_minus_plot", "Download Plot"),
                          downloadButton("download_minus_csv", "Download Differences (CSV)")
                   )
                 ),
                 tags$hr(),
                 h5("Difference Summary"),
                 verbatimTextOutput("minus_summary"),
                 tags$hr(),
                 actionButton("help_minus", "Help me understand this", class = "btn-info help-btn"),
                 conditionalPanel(
                   condition = "input.help_minus % 2 == 1",
                   div(class = "help-content",
                     h5("MINUS Analysis"),
                     p("MINUS subtracts ratings in Grid B from Grid A, cell by cell, to show where two people (or the same person at different times) differ in their construing."),
                     h5("Reading the plot"),
                     tags$ul(
                       tags$li(tags$strong("Blue cells"), " - Grid A rated lower than Grid B on this element/construct"),
                       tags$li(tags$strong("White cells"), " - No difference (identical ratings)"),
                       tags$li(tags$strong("Orange cells"), " - Grid A rated higher than Grid B")
                     ),
                     h5("Requirements"),
                     tags$ul(
                       tags$li("Exactly 2 grids selected"),
                       tags$li("Grids must share both elements AND constructs")
                     )
                   )
                 )
        ),

        # ===== CORE Analysis Tab =====
        tabPanel(title = tagList(tags$span(class = "multigrid-icon", "\U0001F4CA\U0001F4CA"), "CORE"),
                 value = "CORE",
                 h4("CORE Analysis: Shared Construing"),
                 p("Iteratively removes the least agreed-upon elements and constructs, revealing the core of shared understanding between two grids."),
                 fluidRow(
                   column(8,
                          plotOutput("core_plot", height = "450px"),
                          tags$hr(),
                          h5("Removal Log"),
                          DTOutput("core_steps_table")
                   ),
                   column(4,
                          selectInput("core_grid_a", "Grid A:", choices = NULL),
                          selectInput("core_grid_b", "Grid B:", choices = NULL),
                          sliderInput("core_min_elements", "Minimum Elements to Retain",
                                      min = 2, max = 10, value = 2, step = 1),
                          sliderInput("core_min_constructs", "Minimum Constructs to Retain",
                                      min = 1, max = 10, value = 1, step = 1),
                          sliderInput("core_text_size", "Text Size",
                                      min = 0.8, max = 2.0, value = 1.2, step = 0.1),
                          actionButton("compute_core", "Run CORE Analysis", class = "btn-primary"),
                          tags$hr(),
                          actionButton("core_to_focus", "Analyse Core with FOCUS", class = "btn-success btn-sm"),
                          downloadButton("download_core_plot", "Download Plot"),
                          downloadButton("download_core_csv", "Download Removal Log (CSV)")
                   )
                 ),
                 tags$hr(),
                 h5("Core Grid Summary"),
                 verbatimTextOutput("core_summary"),
                 tags$hr(),
                 actionButton("help_core", "Help me understand this", class = "btn-info help-btn"),
                 conditionalPanel(
                   condition = "input.help_core % 2 == 1",
                   div(class = "help-content",
                     h5("CORE Analysis"),
                     p("CORE (Shaw, 1980) finds the core of shared construing between two grids by iteratively removing elements or constructs that contribute most to disagreement."),
                     h5("How it works"),
                     tags$ol(
                       tags$li("Start with all common elements and constructs"),
                       tags$li("Calculate overall match percentage"),
                       tags$li("Try removing each element/construct and see which removal improves the match most"),
                       tags$li("Remove that item and record the improvement"),
                       tags$li("Repeat until minimum size is reached or no improvement possible")
                     ),
                     h5("Interpretation"),
                     tags$ul(
                       tags$li("Elements/constructs removed early = greatest sources of disagreement"),
                       tags$li("The final remaining grid = the core of shared construing"),
                       tags$li("Use 'Analyse Core with FOCUS' to examine the shared structure in detail")
                     )
                   )
                 )
        ),

        # ===== PrinGrid Trajectories Tab =====
        tabPanel(title = tagList(tags$span(class = "multigrid-icon", "\U0001F4CA\U0001F4CA"), "PrinGrid Trajectories"),
                 value = "PrinGrid Trajectories",
                 h4("PrinGrid Trajectories"),
                 p("PCA-based visualisation showing how elements move in construct space across multiple grids (e.g., over time or between people)."),
                 fluidRow(
                   column(8,
                          plotOutput("pringrid_traj_plot", height = "600px")
                   ),
                   column(4,
                          checkboxInput("traj_show_arrows", "Show Movement Arrows", value = TRUE),
                          checkboxInput("traj_show_labels", "Show Element Labels", value = TRUE),
                          checkboxInput("traj_show_constructs", "Show Construct Lines", value = TRUE),
                          sliderInput("traj_text_size", "Text Size",
                                      min = 0.8, max = 2.0, value = 1.2, step = 0.1),
                          actionButton("compute_trajectories", "Compute Trajectories", class = "btn-primary"),
                          tags$hr(),
                          downloadButton("download_traj_plot", "Download Plot"),
                          downloadButton("download_traj_csv", "Download Positions (CSV)")
                   )
                 ),
                 tags$hr(),
                 h5("Variance Explained"),
                 verbatimTextOutput("traj_variance"),
                 tags$hr(),
                 actionButton("help_trajectories", "Help me understand this", class = "btn-info help-btn"),
                 conditionalPanel(
                   condition = "input.help_trajectories % 2 == 1",
                   div(class = "help-content",
                     h5("PrinGrid Trajectories"),
                     p("Trajectories extend the PCA biplot to show how the same elements are positioned differently across multiple grids."),
                     h5("Reading the plot"),
                     tags$ul(
                       tags$li("Each grid's elements are shown in a different colour"),
                       tags$li("Arrows connect the same element across grids, showing movement in construct space"),
                       tags$li("Long arrows = large changes in how that element is construed"),
                       tags$li("Short/no arrows = stable, consistent construing")
                     ),
                     h5("Use cases"),
                     tags$ul(
                       tags$li("Tracking change over time (pre/post interventions)"),
                       tags$li("Comparing different perspectives on the same elements"),
                       tags$li("Identifying which elements changed most in a learning context")
                     )
                   )
                 )
        ),

        # ===== Exchange Grids Tab =====
        tabPanel(title = tagList(tags$span(class = "multigrid-icon", "\U0001F4CA\U0001F4CA"), "Exchange Grids"),
                 value = "Exchange Grids",
                 h4("Exchange Grid Analysis"),
                 p("Structured protocol for measuring agreement and understanding between two people using Shaw's (1980) exchange procedure."),
                 fluidRow(
                   column(8,
                     h5("Protocol Setup"),
                     p("Assign each grid to its role in the exchange protocol:"),
                     fluidRow(
                       column(6,
                         h5("Person A"),
                         selectInput("exchange_1", "1. A's own grid:", choices = NULL),
                         selectInput("exchange_4", "4. A fills B's grid (as A wants):", choices = NULL),
                         selectInput("exchange_6", "6. A predicts B's ratings:", choices = NULL)
                       ),
                       column(6,
                         h5("Person B"),
                         selectInput("exchange_2", "2. B's own grid:", choices = NULL),
                         selectInput("exchange_3", "3. B fills A's grid (as B wants):", choices = NULL),
                         selectInput("exchange_5", "5. B predicts A's ratings:", choices = NULL)
                       )
                     ),
                     tags$hr(),
                     h5("Results"),
                     plotOutput("exchange_plot", height = "400px"),
                     DTOutput("exchange_results_table")
                   ),
                   column(4,
                     actionButton("compute_exchange", "Run Exchange Analysis", class = "btn-primary"),
                     tags$hr(),
                     h5("Quick Summary"),
                     verbatimTextOutput("exchange_summary"),
                     tags$hr(),
                     downloadButton("download_exchange_plot", "Download Plot"),
                     downloadButton("download_exchange_csv", "Download Results (CSV)")
                   )
                 ),
                 tags$hr(),
                 actionButton("help_exchange", "Help me understand this", class = "btn-info help-btn"),
                 conditionalPanel(
                   condition = "input.help_exchange % 2 == 1",
                   div(class = "help-content",
                     h5("Exchange Grid Protocol"),
                     p("The Exchange Grid protocol (Shaw, 1980) measures both agreement and understanding between two people."),
                     h5("The 6 grids"),
                     tags$ol(
                       tags$li("A's own grid - A rates elements on A's constructs"),
                       tags$li("B's own grid - B rates elements on B's constructs"),
                       tags$li("B fills A's grid as B would - shows B's perspective on A's constructs"),
                       tags$li("A fills B's grid as A would - shows A's perspective on B's constructs"),
                       tags$li("B predicts A's ratings - shows B's understanding of how A construes"),
                       tags$li("A predicts B's ratings - shows A's understanding of how B construes")
                     ),
                     h5("Measurements"),
                     tags$ul(
                       tags$li(tags$strong("Agreement (grids 1&3, 2&4):"), " Do they construe elements similarly?"),
                       tags$li(tags$strong("Understanding (grids 1&5, 2&6):"), " Can they predict how the other person rates elements?")
                     )
                   )
                 )
        ),

        # ===== Class Metagrids Tab =====
        tabPanel(title = tagList(tags$span(class = "multigrid-icon", "\U0001F4CA\U0001F4CA"), "Class Metagrids"),
                 value = "Class Metagrids",
                 h4("Class Metagrids"),
                 p("Create a higher-order grid where your grids become elements, rated on user-defined constructs for classification and comparison."),
                 fluidRow(
                   column(8,
                     h5("Grid Elements (from your collection)"),
                     DTOutput("metagrid_grids_table"),
                     tags$hr(),
                     h5("Define Meta-Constructs"),
                     fluidRow(
                       column(5, textInput("meta_left_pole", "Left Pole:", placeholder = "e.g., Expert perspective")),
                       column(5, textInput("meta_right_pole", "Right Pole:", placeholder = "e.g., Novice perspective")),
                       column(2, actionButton("add_meta_construct", "Add", class = "btn-primary btn-sm",
                                              style = "margin-top: 24px;"))
                     ),
                     DTOutput("meta_constructs_table"),
                     tags$hr(),
                     h5("Rate Grids on Meta-Constructs"),
                     uiOutput("meta_ratings_ui")
                   ),
                   column(4,
                     actionButton("build_metagrid", "Build Metagrid", class = "btn-primary"),
                     tags$hr(),
                     actionButton("use_metagrid_as_current", "Analyse as Current Grid", class = "btn-success btn-sm"),
                     tags$small(class = "text-muted", "Loads the metagrid into the editor for full analysis with all single-grid tools."),
                     tags$hr(),
                     downloadButton("download_metagrid", "Download Metagrid (.rgrid)")
                   )
                 ),
                 tags$hr(),
                 h5("Metagrid Preview"),
                 DTOutput("metagrid_preview"),
                 tags$hr(),
                 actionButton("help_metagrid", "Help me understand this", class = "btn-info help-btn"),
                 conditionalPanel(
                   condition = "input.help_metagrid % 2 == 1",
                   div(class = "help-content",
                     h5("Class Metagrids"),
                     p("A metagrid treats your grid collection as a set of elements and lets you classify them using new constructs."),
                     h5("How to use"),
                     tags$ol(
                       tags$li("Your loaded grids automatically become the elements"),
                       tags$li("Define bipolar constructs for classifying grids (e.g., 'Expert - Novice')"),
                       tags$li("Rate each grid on each construct using the 1-7 scale"),
                       tags$li("Click 'Build Metagrid' to create the higher-order grid"),
                       tags$li("Click 'Analyse as Current Grid' to run FOCUS, PCA, etc. on the metagrid")
                     ),
                     h5("Example constructs"),
                     tags$ul(
                       tags$li("'Expert perspective - Novice perspective'"),
                       tags$li("'Detailed grid - Sparse grid'"),
                       tags$li("'Positive overall - Negative overall'")
                     )
                   )
                 )
        )
      )  # end multi-grid tabsetPanel
    )
  )
  )  # end conditionalPanel for main app
)

server <- function(input, output, session) {

  # Non-reactive palette function for use with specific palette names
  get_palette_colors <- function(palette) {
    if (is.null(palette)) palette <- "wong"
    switch(palette,
      "wong" = list(
        element = "#0072B2",      # Dark blue
        construct = "#D55E00",    # Vermillion
        highlight = "#009E73",    # Teal
        accent = "#CC79A7",       # Reddish purple
        heat_low = "#0072B2",     # Blue
        heat_high = "#D55E00"     # Orange
      ),
      "classic" = list(
        element = "#2166AC",      # Blue
        construct = "#B2182B",    # Red
        highlight = "#4DAF4A",    # Green
        accent = "#984EA3",       # Purple
        heat_low = "#2166AC",
        heat_high = "#B2182B"
      ),
      "earth" = list(
        element = "#8B4513",      # Saddle brown
        construct = "#228B22",    # Forest green
        highlight = "#DAA520",    # Goldenrod
        accent = "#4682B4",       # Steel blue
        heat_low = "#F5DEB3",     # Wheat
        heat_high = "#8B4513"     # Brown
      ),
      "contrast" = list(
        element = "#000000",      # Black
        construct = "#E69F00",    # Orange
        highlight = "#56B4E9",    # Sky blue
        accent = "#F0E442",       # Yellow
        heat_low = "#FFFFFF",
        heat_high = "#000000"
      ),
      "greyscale" = list(
        element = "#000000",      # Black (0%)
        construct = "#333333",    # Dark grey (20%)
        highlight = "#666666",    # Mid grey (40%)
        accent = "#999999",       # Light grey (60%)
        heat_low = "#FFFFFF",     # White
        heat_high = "#000000"     # Black
      )
    )
  }

  # Reactive wrapper using global palette (kept for backward compatibility)
  get_colors <- reactive({
    palette <- input$color_palette
    get_palette_colors(palette)
  })

  # Landing page state
  landing <- reactiveValues(step = "elements")

  # Check URL query parameters on startup
  observe({
    query <- parseQueryString(session$clientData$url_search)
    if (!is.null(query$mode) && query$mode == "full") {
      landing$step <- "done"
    }
  }) |> bindEvent(session$clientData$url_search, once = TRUE)

  # Output flag for conditionalPanel
  output$landing_step <- reactive({ landing$step })
  outputOptions(output, "landing_step", suspendWhenHidden = FALSE)

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
    repgrid_last = NULL,
    imputed_last = FALSE,
    elicitation_active = FALSE,
    show_constructs = FALSE,
    manual_mode = FALSE,
    # Triadic elicitation tracking
    all_triads = list(),        # List of all unique triads (each is vector of 3 element names)
    current_triad_idx = 0,      # Current triad index (1-based)
    triad_similar = character(), # Which 2 elements in current triad are similar
    triad_different = NULL,      # Which 1 element in current triad is different

    # Multi-grid storage
    grid_collection = list(),    # Named list of grid objects
    grid_metadata = data.frame(  # Metadata for each grid
      grid_id = character(0),
      name = character(0),
      n_elements = numeric(0),
      n_constructs = numeric(0),
      scale_min = numeric(0),
      scale_max = numeric(0),
      imported_at = character(0),
      stringsAsFactors = FALSE
    ),
    selected_grids = character(),    # Vector of selected grid_ids for analysis
    common_elements = character(),   # Elements shared across selected grids
    common_constructs = character(), # Constructs shared (by label match)

    # Multi-grid analysis results
    match_matrix = NULL,             # Grid-to-grid match percentages
    socionet_data = NULL,            # Network data for visualization
    mode_grid = NULL,                # Generated Mode (consensus) grid
    composite_grid = NULL,           # Generated Composite grid

    # New analysis results
    minus_result = NULL,             # MINUS grid differences
    core_result = NULL,              # CORE iterative comparison
    traj_result = NULL,              # PrinGrid Trajectories PCA
    exchange_result = NULL,          # Exchange Grid 6-grid protocol
    metagrid = NULL,                 # Class Metagrid
    meta_constructs = data.frame(left = character(), right = character(), stringsAsFactors = FALSE)
  )

  # "Use an Existing Grid" button -> show presets
  observeEvent(input$landing_existing, {
    landing$step <- "presets"
  })

  # Back button from presets page
  observeEvent(input$landing_back, {
    landing$step <- "elements"
  })

  # Render preset list from JSON files in dataExamples/presets/
  output$preset_list <- renderUI({
    preset_dir <- "dataExamples/presets"
    files <- list.files(preset_dir, pattern = "\\.json$", full.names = TRUE)
    if (length(files) == 0) {
      return(p("No presets available.", style = "color: #999;"))
    }
    preset_cards <- lapply(files, function(f) {
      preset <- jsonlite::fromJSON(f)
      preset_id <- tools::file_path_sans_ext(basename(f))
      n_elem <- length(preset$elements)
      elements_preview <- paste(preset$elements, collapse = ", ")
      actionButton(
        paste0("preset_", preset_id),
        div(class = "preset-card",
          h4(preset$name %||% preset_id),
          p(class = "preset-detail", paste0(n_elem, " elements: ", elements_preview))
        ),
        style = "all: unset; display: block; width: 100%; text-align: left;"
      )
    })
    tagList(preset_cards)
  })

  # Observe clicks on any preset button
  observe({
    preset_dir <- "dataExamples/presets"
    files <- list.files(preset_dir, pattern = "\\.json$", full.names = FALSE)
    preset_ids <- tools::file_path_sans_ext(files)
    lapply(preset_ids, function(pid) {
      observeEvent(input[[paste0("preset_", pid)]], {
        preset_file <- file.path(preset_dir, paste0(pid, ".json"))
        preset <- jsonlite::fromJSON(preset_file)
        rv$elements <- preset$elements
        # Set up triadic elicitation with the loaded elements
        triads <- combn(preset$elements, 3, simplify = FALSE)
        rv$all_triads <- triads
        rv$current_triad_idx <- 1
        rv$triad_similar <- character()
        rv$triad_different <- NULL
        landing$step <- "triads"
        showNotification(
          paste0("Loaded: ", preset$name %||% pid),
          type = "message"
        )
      }, ignoreInit = TRUE)
    })
  })

  # Handle landing page continue button
  observeEvent(input$landing_continue, {
    items <- c(input$landing_item1, input$landing_item2,
               input$landing_item3, input$landing_item4,
               input$landing_item5)
    items <- trimws(items)
    items <- items[items != ""]
    if (length(items) >= 3) {
      rv$elements <- items
      triads <- combn(items, 3, simplify = FALSE)
      rv$all_triads <- triads
      rv$current_triad_idx <- 1
      rv$triad_similar <- character()
      rv$triad_different <- NULL
      landing$step <- "triads"
    } else {
      showNotification("Please enter at least 3 items.",
                       type = "warning")
    }
  })

  # Wizard: progress indicator
  output$wizard_progress <- renderUI({
    req(rv$current_triad_idx > 0, length(rv$all_triads) > 0)
    total <- length(rv$all_triads)
    idx <- rv$current_triad_idx
    pct <- round(100 * (idx - 1) / total)
    tagList(
      p(class = "progress-text",
        paste0("Triad ", idx, " of ", total)),
      div(style = paste0(
        "background: #e0e0e0; border-radius: 4px; height: 6px; ",
        "margin-bottom: 16px;"),
        div(style = paste0(
          "background: #28a745; height: 6px; border-radius: 4px; ",
          "width: ", pct, "%;"))
      )
    )
  })

  # Wizard: render 3 triad cards
  output$wizard_triad_cards <- renderUI({
    req(rv$current_triad_idx > 0)
    req(length(rv$all_triads) >= rv$current_triad_idx)
    triad <- rv$all_triads[[rv$current_triad_idx]]
    cards <- lapply(seq_along(triad), function(i) {
      elem <- triad[i]
      cls <- "triad-card"
      if (elem %in% rv$triad_similar) cls <- paste(cls, "is-similar")
      if (identical(rv$triad_different, elem)) {
        cls <- paste(cls, "is-different")
      }
      actionButton(
        paste0("wiz_card_", i),
        elem,
        class = cls
      )
    })
    div(class = "triad-cards", cards)
  })

  # Wizard: card click handlers (toggle similar/different)
  lapply(1:3, function(i) {
    observeEvent(input[[paste0("wiz_card_", i)]], {
      req(rv$current_triad_idx > 0)
      req(length(rv$all_triads) >= rv$current_triad_idx)
      triad <- rv$all_triads[[rv$current_triad_idx]]
      elem <- triad[i]
      if (elem %in% rv$triad_similar) {
        rv$triad_similar <- setdiff(rv$triad_similar, elem)
      } else if (identical(rv$triad_different, elem)) {
        rv$triad_different <- NULL
      } else if (length(rv$triad_similar) < 2) {
        rv$triad_similar <- c(rv$triad_similar, elem)
      } else {
        rv$triad_different <- elem
      }
    }, ignoreInit = TRUE)
  })

  # Wizard: Next button - save construct and advance
  observeEvent(input$wizard_next, {
    left <- trimws(input$wizard_left_pole)
    right <- trimws(input$wizard_right_pole)
    if (length(rv$triad_similar) != 2 ||
        is.null(rv$triad_different)) {
      showNotification("Pick 2 similar and 1 different.",
                       type = "warning")
      return()
    }
    if (left == "" || right == "") {
      showNotification("Enter both poles.", type = "warning")
      return()
    }
    rv$constructs <- rbind(rv$constructs,
      data.frame(left = left, right = right,
                 stringsAsFactors = FALSE))
    updateTextInput(session, "wizard_left_pole", value = "")
    updateTextInput(session, "wizard_right_pole", value = "")
    if (rv$current_triad_idx < length(rv$all_triads)) {
      rv$current_triad_idx <- rv$current_triad_idx + 1
      rv$triad_similar <- character()
      rv$triad_different <- NULL
    } else {
      landing$step <- "results"
    }
  })

  # Wizard: Skip button
  observeEvent(input$wizard_skip, {
    if (rv$current_triad_idx < length(rv$all_triads)) {
      rv$current_triad_idx <- rv$current_triad_idx + 1
      rv$triad_similar <- character()
      rv$triad_different <- NULL
      updateTextInput(session, "wizard_left_pole", value = "")
      updateTextInput(session, "wizard_right_pole", value = "")
    } else {
      landing$step <- "results"
    }
  })

  # Wizard: Finish early button
  observeEvent(input$wizard_finish, {
    landing$step <- "results"
  })

  # Results page: heading
  output$wizard_results_heading <- renderUI({
    n_const <- if (is.data.frame(rv$constructs)) nrow(rv$constructs) else 0
    tagList(
      h2("Your Constructs"),
      p(class = "subtitle", paste0(
        "You generated ", n_const, " construct", if (n_const != 1) "s",
        " from ", length(rv$elements), " elements. Here's a preview of your grid."
      ))
    )
  })

  # Results page: construct summary table
  output$wizard_results_summary <- renderUI({
    n_const <- if (is.data.frame(rv$constructs)) nrow(rv$constructs) else 0
    if (n_const == 0) return(p(tags$em("No constructs generated."), style = "color: #888;"))

    tags$table(
      style = "width: 100%; border-collapse: collapse; margin-top: 8px; margin-bottom: 16px;",
      tags$thead(tags$tr(
        tags$th("#", style = "text-align: center; padding: 4px 8px; border-bottom: 2px solid #ddd; font-size: 12px; color: #666; width: 30px;"),
        tags$th("Pole 1 (left)", style = "text-align: left; padding: 4px 8px; border-bottom: 2px solid #ddd; font-size: 12px; color: #B2182B;"),
        tags$th("Pole 2 (right)", style = "text-align: right; padding: 4px 8px; border-bottom: 2px solid #ddd; font-size: 12px; color: #2166AC;")
      )),
      tags$tbody(lapply(seq_len(n_const), function(i) {
        tags$tr(
          tags$td(i, style = "text-align: center; padding: 4px 8px; border-bottom: 1px solid #eee; color: #999; font-size: 12px;"),
          tags$td(rv$constructs$left[i], style = "padding: 4px 8px; border-bottom: 1px solid #eee;"),
          tags$td(rv$constructs$right[i], style = "text-align: right; padding: 4px 8px; border-bottom: 1px solid #eee;")
        )
      }))
    )
  })

  # Results page: preview biplot with midpoint ratings
  output$wizard_preview_plot <- renderPlot({
    req(is.data.frame(rv$constructs), nrow(rv$constructs) >= 2)
    req(length(rv$elements) >= 2)
    n_e <- length(rv$elements)
    n_c <- nrow(rv$constructs)
    # Use midpoint ratings (all 4s) as placeholder
    sm <- matrix(4, nrow = n_e, ncol = n_c)
    # Check if any real ratings exist and use them
    if (is.data.frame(rv$ratings) && nrow(rv$ratings) > 0) {
      construct_labels <- paste(rv$constructs$left, "-",
                                rv$constructs$right)
      for (i in seq_len(n_e)) {
        for (j in seq_len(n_c)) {
          idx <- rv$ratings$element == rv$elements[i] &
            rv$ratings$construct == construct_labels[j]
          if (any(idx)) sm[i, j] <- rv$ratings$rating[idx][1]
        }
      }
    }
    # Can't do PCA on constant matrix - add small jitter
    if (sd(sm) == 0) sm <- sm + matrix(
      rnorm(n_e * n_c, 0, 0.1), nrow = n_e)
    pc <- prcomp(sm, scale. = TRUE)
    ex <- pc$x[, 1:min(2, ncol(pc$x))]
    if (is.null(dim(ex))) return()
    load <- cor(sm, pc$x)[, 1:min(2, ncol(pc$x))]
    if (is.null(dim(load))) return()
    par(mar = c(4, 6, 3, 6))
    all_pts <- rbind(ex, load, -load)
    xr <- range(all_pts[, 1]) * 1.5
    yr <- range(all_pts[, 2]) * 1.5
    title_text <- if (is.data.frame(rv$ratings) && nrow(rv$ratings) > 0)
      "Your Repertory Grid" else "Preview (ratings not yet entered)"
    plot(ex, type = "n", xlab = "PC1", ylab = "PC2",
         xlim = xr, ylim = yr, main = title_text)
    points(ex, pch = 19, col = "#0072B2", cex = 1.3)
    # Offset overlapping element labels
    el_pos <- rep(3, nrow(ex))  # default: above
    pos_cycle <- c(3, 4, 1, 2)  # above, right, below, left
    for (i in seq_len(nrow(ex))) {
      for (j in seq_len(i - 1)) {
        d <- sqrt(sum((ex[i, ] - ex[j, ])^2))
        if (d < diff(xr) * 0.08) {
          el_pos[i] <- pos_cycle[((i - 1) %% 4) + 1]
        }
      }
    }
    text(ex, labels = rv$elements, pos = el_pos,
         col = "#0072B2", font = 2, cex = 0.9)
    for (i in seq_len(nrow(load))) {
      lines(c(-load[i, 1], load[i, 1]),
            c(-load[i, 2], load[i, 2]),
            col = "#D55E00", lwd = 2)
    }
    # Offset overlapping construct labels
    c_pos_r <- rep(4, nrow(load))
    c_pos_l <- rep(2, nrow(load))
    for (i in seq_len(nrow(load))) {
      for (j in seq_len(i - 1)) {
        d <- sqrt(sum((load[i, ] - load[j, ])^2))
        if (d < diff(xr) * 0.08) {
          c_pos_r[i] <- pos_cycle[((i - 1) %% 4) + 1]
          c_pos_l[i] <- pos_cycle[((i + 1) %% 4) + 1]
        }
      }
    }
    text(load[, 1], load[, 2],
         labels = rv$constructs$right,
         pos = c_pos_r, col = "#D55E00", font = 2, cex = 0.85, xpd = TRUE)
    text(-load[, 1], -load[, 2],
         labels = rv$constructs$left,
         pos = c_pos_l, col = "#D55E00", font = 3, cex = 0.85, xpd = TRUE)
    abline(h = 0, v = 0, lty = 3, col = "gray50")
  })

  # Results page: go to rating step
  observeEvent(input$results_to_app, {
    landing$step <- "rating"
  })

  # Results page: go back to add more constructs
  observeEvent(input$results_back, {
    landing$step <- "triads"
  })

  # Constructs page: email constructs
  output$wizard_mailto_constructs <- renderUI({
    req(length(rv$elements) > 0, is.data.frame(rv$constructs), nrow(rv$constructs) > 0)
    body_lines <- c(
      "My Repertory Grid Constructs",
      "",
      paste0("Elements: ", paste(rv$elements, collapse = ", ")),
      "",
      "Constructs:"
    )
    for (i in seq_len(nrow(rv$constructs))) {
      body_lines <- c(body_lines,
        paste0("  ", i, ". ", rv$constructs$left[i], " vs ", rv$constructs$right[i])
      )
    }
    body_text <- paste(body_lines, collapse = "\n")
    mailto_url <- paste0(
      "mailto:?subject=",
      utils::URLencode("My Repertory Grid Constructs - WebGrid.Online", reserved = TRUE),
      "&body=",
      utils::URLencode(body_text, reserved = TRUE)
    )
    tags$button(
      class = "btn btn-outline-primary btn-lg",
      onclick = paste0("window.open('", mailto_url, "','_blank'); return false;"),
      "Email My Constructs"
    )
  })

  # Post-rating page: email chart + download
  output$wizard_mailto_ratings <- renderUI({
    req(length(rv$elements) > 0, is.data.frame(rv$constructs), nrow(rv$constructs) > 0,
        is.data.frame(rv$ratings), nrow(rv$ratings) > 0)
    # Build JSON format for import compatibility
    grid_json <- jsonlite::toJSON(list(
      name = "My Repertory Grid",
      elements = rv$elements,
      constructs = lapply(seq_len(nrow(rv$constructs)), function(i) {
        list(left = rv$constructs$left[i], right = rv$constructs$right[i])
      }),
      ratings = lapply(seq_len(nrow(rv$ratings)), function(i) {
        list(element = rv$ratings$element[i],
             construct = rv$ratings$construct[i],
             rating = rv$ratings$rating[i])
      }),
      scale = c(1, rv$scale %||% 5)
    ), auto_unbox = TRUE, pretty = TRUE)
    body_lines <- c(
      "My Repertory Grid Ratings - WebGrid.Online",
      "",
      "Save the JSON below as a .json file to import into WebGrid.",
      "",
      grid_json
    )
    body_text <- paste(body_lines, collapse = "\n")
    mailto_url <- paste0(
      "mailto:?subject=",
      utils::URLencode("My Repertory Grid Ratings - WebGrid.Online", reserved = TRUE),
      "&body=",
      utils::URLencode(body_text, reserved = TRUE)
    )
    tagList(
      tags$button(
        class = "btn btn-outline-primary btn-lg",
        onclick = paste0("window.open('", mailto_url, "','_blank'); return false;"),
        "Email My Ratings"
      ),
      downloadButton("download_preview_chart", "Download Chart",
                     class = "btn btn-outline-secondary btn-lg",
                     style = "margin-left: 10px;")
    )
  })

  # Post-rating page: download chart as PNG
  output$download_preview_chart <- downloadHandler(
    filename = function() paste0("my-grid-", Sys.Date(), ".png"),
    content = function(file) {
      png(file, width = 800, height = 600, res = 120)
      req(is.data.frame(rv$constructs), nrow(rv$constructs) >= 2)
      req(length(rv$elements) >= 2)
      n_e <- length(rv$elements)
      n_c <- nrow(rv$constructs)
      sm <- matrix(3, nrow = n_e, ncol = n_c)
      if (is.data.frame(rv$ratings) && nrow(rv$ratings) > 0) {
        construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)
        for (i in seq_len(n_e)) {
          for (j in seq_len(n_c)) {
            idx <- rv$ratings$element == rv$elements[i] &
              rv$ratings$construct == construct_labels[j]
            if (any(idx)) sm[i, j] <- rv$ratings$rating[idx][1]
          }
        }
      }
      if (sd(sm) == 0) sm <- sm + matrix(rnorm(n_e * n_c, 0, 0.1), nrow = n_e)
      pc <- prcomp(sm, scale. = TRUE)
      ex <- pc$x[, 1:min(2, ncol(pc$x))]
      load <- cor(sm, pc$x)[, 1:min(2, ncol(pc$x))]
      par(mar = c(4, 4, 2, 2))
      all_pts <- rbind(ex, load, -load)
      xr <- range(all_pts[, 1]) * 1.3
      yr <- range(all_pts[, 2]) * 1.3
      plot(ex, type = "n", xlab = "PC1", ylab = "PC2",
           xlim = xr, ylim = yr, main = "My Repertory Grid")
      points(ex, pch = 19, col = "#0072B2", cex = 1.3)
      text(ex, labels = rv$elements, pos = 3, col = "#0072B2", font = 2)
      for (i in seq_len(nrow(load))) {
        lines(c(-load[i, 1], load[i, 1]), c(-load[i, 2], load[i, 2]),
              col = "#D55E00", lwd = 2)
      }
      text(load[, 1], load[, 2], labels = rv$constructs$right,
           pos = 4, col = "#D55E00", font = 2)
      text(-load[, 1], -load[, 2], labels = rv$constructs$left,
           pos = 2, col = "#D55E00", font = 3)
      abline(h = 0, v = 0, lty = 3, col = "gray50")
      dev.off()
    }
  )

  # Post-rating page: continue to full app and auto-analyze
  # Simple Start tab: return to wizard landing
  observeEvent(input$goto_simple_start, {
    landing$step <- "landing"
  })

  observeEvent(input$post_rating_continue, {
    landing$step <- "done"
    # Enable imputation for any missing ratings, then auto-analyze
    if (length(rv$elements) >= 2 &&
        is.data.frame(rv$constructs) && nrow(rv$constructs) >= 2 &&
        is.data.frame(rv$ratings) && nrow(rv$ratings) > 0) {
      updateCheckboxInput(session, "impute_missing", value = TRUE)
      session$sendCustomMessage("click_analyze", list())
      # Switch to Biplot tab after analysis
      updateTabsetPanel(session, "main_tabs", selected = "Biplot")
    }
  })

  # Rating page: track current construct index
  rv_rating <- reactiveValues(construct_idx = 1)

  # Rating page: overall progress bar
  output$rating_overall_progress <- renderUI({
    req(is.data.frame(rv$constructs), nrow(rv$constructs) > 0)
    n_c <- nrow(rv$constructs)
    ci <- rv_rating$construct_idx
    pct <- round(100 * (ci - 1) / n_c)
    tagList(
      p(class = "subtitle", paste0("Construct ", ci, " of ", n_c)),
      div(class = "rating-progress-bar",
        div(class = "rating-progress-fill", style = paste0("width: ", pct, "%;"))
      )
    )
  })

  # Rating page: show current construct
  output$rating_construct_label <- renderUI({
    req(is.data.frame(rv$constructs), nrow(rv$constructs) > 0)
    ci <- rv_rating$construct_idx
    constructs <- rv$constructs
    div(class = "rating-construct",
      div(style = "display: flex; justify-content: space-between; align-items: center;",
        span(style = "color: #B2182B; font-weight: 700;",
          paste0("1 = ", constructs$left[ci])),
        span(style = "color: #2166AC; font-weight: 700;",
          paste0(constructs$right[ci], " = 5"))
      )
    )
  })

  # Rating page: render element rating scales for current construct
  output$rating_elements_ui <- renderUI({
    req(length(rv$elements) > 0, is.data.frame(rv$constructs), nrow(rv$constructs) > 0)
    ci <- rv_rating$construct_idx
    elements <- rv$elements

    element_rows <- lapply(seq_along(elements), function(ei) {
      input_id <- paste0("rate_", ci, "_", ei)
      btns <- lapply(1:5, function(v) {
        tags$button(
          as.character(v),
          class = "rating-btn",
          id = paste0(input_id, "_", v),
          onclick = sprintf(
            "Shiny.setInputValue('%s', %d, {priority: 'event'}); document.querySelectorAll('[id^=\"%s_\"].rating-btn').forEach(b => b.classList.remove('selected')); this.classList.add('selected');",
            input_id, v, input_id
          )
        )
      })
      div(class = "rating-element",
        div(class = "rating-element-name", elements[ei]),
        div(class = "rating-scale",
          div(class = "rating-scale-track", btns)
        )
      )
    })
    tagList(element_rows)
  })

  # Rating page: Next construct
  observeEvent(input$rating_next, {
    req(is.data.frame(rv$constructs), nrow(rv$constructs) > 0)
    n_c <- nrow(rv$constructs)
    if (rv_rating$construct_idx < n_c) {
      rv_rating$construct_idx <- rv_rating$construct_idx + 1
    } else {
      # Last construct — collect all ratings and proceed
      elements <- rv$elements
      constructs <- rv$constructs
      ratings_list <- list()
      for (ci in seq_len(nrow(constructs))) {
        construct_label <- paste(constructs$left[ci], "-", constructs$right[ci])
        for (ei in seq_along(elements)) {
          val <- input[[paste0("rate_", ci, "_", ei)]]
          if (!is.null(val)) {
            ratings_list <- c(ratings_list, list(data.frame(
              element = elements[ei],
              construct = construct_label,
              rating = as.numeric(val),
              stringsAsFactors = FALSE
            )))
          }
        }
      }
      if (length(ratings_list) > 0) {
        rv$ratings <- do.call(rbind, ratings_list)
      }
      landing$step <- "post_rating"
    }
  })

  # Rating page: Previous construct
  observeEvent(input$rating_prev, {
    if (rv_rating$construct_idx > 1) {
      rv_rating$construct_idx <- rv_rating$construct_idx - 1
    } else {
      landing$step <- "results"
    }
  })

  # Clear all data
  observeEvent(input$clear_all, {
    rv$elements <- character()
    rv$constructs <- data.frame(left = character(), right = character(), stringsAsFactors = FALSE)
    rv$ratings <- data.frame(element = character(), construct = character(), rating = numeric(), stringsAsFactors = FALSE)
    rv$scores_mat_last <- NULL
    rv$repgrid_last <- NULL
    rv$show_constructs <- FALSE
    rv$elicitation_active <- FALSE
    rv$manual_mode <- FALSE
    rv$all_triads <- list()
    rv$current_triad_idx <- 0
    showNotification("All data cleared", type = "message")
  })

  # Dynamic UI: Show prompt when file is uploaded but not loaded
  output$load_grid_prompt <- renderUI({
    if (!is.null(input$import_file) && length(rv$elements) == 0) {
      div(style = "background: #fff3cd; padding: 6px 8px; border-radius: 4px; margin-bottom: 8px; font-size: 11px; border: 1px solid #ffc107;",
        tags$strong("\u2193 Click 'Load Grid' to import your file")
      )
    }
  })

  # Dynamic UI: Analyse button with highlight when grid is loaded
  output$analyse_button_ui <- renderUI({
    has_data <- length(rv$elements) >= 2 && nrow(rv$constructs) >= 2
    has_analysis <- !is.null(rv$scores_mat_last)

    if (has_data && !has_analysis) {
      # Grid loaded but not analysed - highlight the button
      div(
        actionButton("analyze", "Analyse Grid", class = "btn-primary",
                     style = "animation: pulse 1.5s infinite; box-shadow: 0 0 10px #007bff;"),
        tags$style(HTML("
          @keyframes pulse {
            0% { box-shadow: 0 0 5px #007bff; }
            50% { box-shadow: 0 0 15px #007bff; }
            100% { box-shadow: 0 0 5px #007bff; }
          }
        ")),
        div(style = "background: #d4edda; padding: 6px 8px; border-radius: 4px; margin-top: 8px; font-size: 11px; border: 1px solid #c3e6cb;",
          tags$strong("\u2191 Click to analyse your grid")
        )
      )
    } else {
      actionButton("analyze", "Analyse Grid", class = "btn-primary")
    }
  })

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

  # Load sample fruit elements (plain text for compatibility)
  observeEvent(input$load_sample_elements, {
    sample_fruits <- c(
      "Apple",
      "Banana",
      "Grapes",
      "Orange",
      "Strawberry"
    )
    rv$elements <- c(rv$elements, sample_fruits)
  })

  # Begin elicitation - triadic method
  # Show manual constructs mode

  observeEvent(input$show_manual_constructs, {
    rv$show_constructs <- TRUE
    rv$manual_mode <- TRUE
    rv$elicitation_active <- FALSE
  })

  # Begin guided elicitation - generate all unique triads

  observeEvent(input$begin_elicitation, {
    if (length(rv$elements) < 3) {
      showNotification("Need at least 3 elements to begin elicitation", type = "warning")
      return()
    }

    # Generate all unique combinations of 3 elements
    n <- length(rv$elements)
    triads <- combn(rv$elements, 3, simplify = FALSE)

    rv$all_triads <- triads
    rv$current_triad_idx <- 1
    rv$triad_similar <- character()
    rv$triad_different <- NULL
    rv$show_constructs <- TRUE
    rv$manual_mode <- FALSE
    rv$elicitation_active <- TRUE

    showNotification(
      paste0("Generated ", length(triads), " unique triads to explore."),
      type = "message"
    )
  })

  # Stop elicitation
  observeEvent(input$stop_elicitation, {
    rv$elicitation_active <- FALSE
    rv$current_triad_idx <- 0
  })

  # Skip current triad (move to next without adding construct)
  observeEvent(input$skip_triad, {
    if (rv$current_triad_idx < length(rv$all_triads)) {
      rv$current_triad_idx <- rv$current_triad_idx + 1
      rv$triad_similar <- character()
      rv$triad_different <- NULL
    } else {
      showNotification("All triads completed!", type = "message")
      rv$elicitation_active <- FALSE
    }
  })

  # Clear selections for current triad
  observeEvent(input$clear_triad, {
    rv$triad_similar <- character()
    rv$triad_different <- NULL
  })

  # Handle clicking on triad elements to assign as similar or different
  observeEvent(input$triad_elem_1_similar, {
    req(rv$elicitation_active, rv$current_triad_idx > 0)
    triad <- rv$all_triads[[rv$current_triad_idx]]
    elem <- triad[1]
    # Toggle: if already similar, remove; if different, switch; otherwise add
    if (elem %in% rv$triad_similar) {
      rv$triad_similar <- setdiff(rv$triad_similar, elem)
    } else if (identical(rv$triad_different, elem)) {
      rv$triad_different <- NULL
      if (length(rv$triad_similar) < 2) rv$triad_similar <- c(rv$triad_similar, elem)
    } else if (length(rv$triad_similar) < 2) {
      rv$triad_similar <- c(rv$triad_similar, elem)
    }
  })

  observeEvent(input$triad_elem_2_similar, {
    req(rv$elicitation_active, rv$current_triad_idx > 0)
    triad <- rv$all_triads[[rv$current_triad_idx]]
    elem <- triad[2]
    if (elem %in% rv$triad_similar) {
      rv$triad_similar <- setdiff(rv$triad_similar, elem)
    } else if (identical(rv$triad_different, elem)) {
      rv$triad_different <- NULL
      if (length(rv$triad_similar) < 2) rv$triad_similar <- c(rv$triad_similar, elem)
    } else if (length(rv$triad_similar) < 2) {
      rv$triad_similar <- c(rv$triad_similar, elem)
    }
  })

  observeEvent(input$triad_elem_3_similar, {
    req(rv$elicitation_active, rv$current_triad_idx > 0)
    triad <- rv$all_triads[[rv$current_triad_idx]]
    elem <- triad[3]
    if (elem %in% rv$triad_similar) {
      rv$triad_similar <- setdiff(rv$triad_similar, elem)
    } else if (identical(rv$triad_different, elem)) {
      rv$triad_different <- NULL
      if (length(rv$triad_similar) < 2) rv$triad_similar <- c(rv$triad_similar, elem)
    } else if (length(rv$triad_similar) < 2) {
      rv$triad_similar <- c(rv$triad_similar, elem)
    }
  })

  observeEvent(input$triad_elem_1_different, {
    req(rv$elicitation_active, rv$current_triad_idx > 0)
    triad <- rv$all_triads[[rv$current_triad_idx]]
    elem <- triad[1]
    if (identical(rv$triad_different, elem)) {
      rv$triad_different <- NULL
    } else if (!(elem %in% rv$triad_similar)) {
      rv$triad_different <- elem
    }
  })

  observeEvent(input$triad_elem_2_different, {
    req(rv$elicitation_active, rv$current_triad_idx > 0)
    triad <- rv$all_triads[[rv$current_triad_idx]]
    elem <- triad[2]
    if (identical(rv$triad_different, elem)) {
      rv$triad_different <- NULL
    } else if (!(elem %in% rv$triad_similar)) {
      rv$triad_different <- elem
    }
  })

  observeEvent(input$triad_elem_3_different, {
    req(rv$elicitation_active, rv$current_triad_idx > 0)
    triad <- rv$all_triads[[rv$current_triad_idx]]
    elem <- triad[3]
    if (identical(rv$triad_different, elem)) {
      rv$triad_different <- NULL
    } else if (!(elem %in% rv$triad_similar)) {
      rv$triad_different <- elem
    }
  })

  # Handle element clicks using input$last_clicked pattern
  # We'll use a hidden input to track which element was clicked

  # Create observers for each possible element button (up to 20 elements)
  lapply(1:20, function(i) {
    # Similar button observer
    observeEvent(input[[paste0("elem_similar_", i)]], {
      req(rv$elicitation_active)
      req(i <= length(rv$elements))
      elem <- rv$elements[i]

      if (elem %in% rv$similar_elements) {
        # Deselect
        rv$similar_elements <- setdiff(rv$similar_elements, elem)
      } else if (length(rv$similar_elements) < 2) {
        # Select if not already different
        diff_elem <- rv$different_element
        if (is.null(diff_elem) || elem != diff_elem) {
          rv$similar_elements <- c(rv$similar_elements, elem)
        }
      }
    }, ignoreInit = TRUE)

    # Different button observer
    observeEvent(input[[paste0("elem_different_", i)]], {
      req(rv$elicitation_active)
      req(i <= length(rv$elements))
      elem <- rv$elements[i]

      diff_elem <- rv$different_element
      if (!is.null(diff_elem) && elem == diff_elem) {
        # Deselect
        rv$different_element <- NULL
      } else if (!(elem %in% rv$similar_elements)) {
        # Select
        rv$different_element <- elem
      }
    }, ignoreInit = TRUE)
  })

  # Add construct from triadic elicitation
  observeEvent(input$add_elicited_construct, {
    req(input$elicit_left, input$elicit_right)

    # Validate that 2 similar and 1 different are selected
    if (length(rv$triad_similar) != 2) {
      showNotification("Please select exactly 2 SIMILAR elements", type = "warning")
      return()
    }
    if (is.null(rv$triad_different)) {
      showNotification("Please select 1 DIFFERENT element", type = "warning")
      return()
    }

    # Add the construct
    new_construct_label <- paste(input$elicit_left, "-", input$elicit_right)
    rv$constructs <- rbind(
      rv$constructs,
      data.frame(left = input$elicit_left, right = input$elicit_right, stringsAsFactors = FALSE)
    )

    # Clear inputs
    updateTextInput(session, "elicit_left", value = "")
    updateTextInput(session, "elicit_right", value = "")

    # Select the new construct in the ratings dropdown
    updateSelectInput(session, "rating_construct", selected = new_construct_label)
    if (length(rv$elements) > 0) {
      updateSelectInput(session, "rating_element", selected = rv$elements[1])
    }

    # Advance to next triad
    if (rv$current_triad_idx < length(rv$all_triads)) {
      rv$current_triad_idx <- rv$current_triad_idx + 1
      rv$triad_similar <- character()
      rv$triad_different <- NULL
    } else {
      # All triads done
      showNotification("All triads completed! You can now add ratings or continue adding constructs manually.", type = "message")
      rv$elicitation_active <- FALSE
      rv$manual_mode <- TRUE
    }
  })

  # Elements display with count
  output$elements_display <- renderUI({
    if (length(rv$elements) == 0) {
      return(tags$div(style = "margin-top: 8px; color: #666; font-size: 12px;",
        tags$em("No elements added yet. Add elements above or try sample fruits.")
      ))
    }
    tags$div(style = "margin-top: 8px;",
      tags$strong(paste0(length(rv$elements), " elements: "), style = "font-size: 11px;"),
      tags$span(paste(rv$elements, collapse = ", "), style = "font-size: 11px; color: #666;")
    )
  })

  # Triad cards UI - separate so clicking buttons doesn't reset text inputs

  output$triad_cards_ui <- renderUI({
    req(rv$elicitation_active, rv$current_triad_idx > 0)
    req(length(rv$all_triads) >= rv$current_triad_idx)

    current_triad <- rv$all_triads[[rv$current_triad_idx]]

    # Three element cards side by side
    fluidRow(
      lapply(1:3, function(i) {
        elem <- current_triad[i]
        is_similar <- elem %in% rv$triad_similar
        is_different <- identical(rv$triad_different, elem)

        # Determine card style
        card_style <- if (is_similar) {
          "background: #d4edda; border: 2px solid #28a745; padding: 10px; border-radius: 8px; text-align: center; min-height: 120px;"
        } else if (is_different) {
          "background: #f8d7da; border: 2px solid #dc3545; padding: 10px; border-radius: 8px; text-align: center; min-height: 120px;"
        } else {
          "background: #f8f9fa; border: 2px solid #dee2e6; padding: 10px; border-radius: 8px; text-align: center; min-height: 120px;"
        }

        column(4,
          div(style = card_style,
            tags$div(style = "font-size: 14px; font-weight: bold; margin-bottom: 8px;", elem),
            tags$div(style = "margin-top: 8px;",
              actionButton(paste0("triad_elem_", i, "_similar"), "Similar",
                class = if (is_similar) "btn btn-success btn-sm" else "btn btn-outline-success btn-sm",
                style = "margin: 2px;"),
              actionButton(paste0("triad_elem_", i, "_different"), "Different",
                class = if (is_different) "btn btn-danger btn-sm" else "btn btn-outline-danger btn-sm",
                style = "margin: 2px;")
            ),
            if (is_similar) tags$div(style = "color: #28a745; font-size: 11px; margin-top: 4px;", "SIMILAR")
            else if (is_different) tags$div(style = "color: #dc3545; font-size: 11px; margin-top: 4px;", "DIFFERENT")
          )
        )
      })
    )
  })

  # Constructs section UI - only shown after user clicks a button
  output$constructs_section_ui <- renderUI({
    if (!rv$show_constructs) return(NULL)

    # Only depend on these values - NOT triad_similar/triad_different
    elicit_active <- rv$elicitation_active
    manual <- rv$manual_mode
    triad_idx <- rv$current_triad_idx

    if (elicit_active && !manual && triad_idx > 0) {
      # Guided elicitation mode - show current triad
      total_triads <- length(rv$all_triads)
      progress_pct <- round(100 * (triad_idx - 1) / total_triads)

      div(id = "constructs_section", class = "elicit-section", style = "margin-top: 10px; background: #fff8e6;",
        div(class = "step-header",
          h5("Step 2: Create Constructs (Triadic Elicitation)"),
          actionButton("info_constructs", "?", class = "btn-info info-btn")
        ),
        conditionalPanel(
          condition = "input.info_constructs % 2 == 1",
          div(class = "info-popup",
            tags$strong("Triadic elicitation: "), "For each triad of 3 elements, decide which 2 are SIMILAR and which 1 is DIFFERENT.",
            tags$br(),
            "Then describe what makes them similar (left pole) and different (right pole)."
          )
        ),

        # Progress indicator
        div(style = "margin-bottom: 10px;",
          tags$div(style = "font-size: 12px; font-weight: bold; margin-bottom: 4px;",
            paste0("Triad ", triad_idx, " of ", total_triads)
          ),
          tags$div(style = "background: #e9ecef; border-radius: 4px; height: 6px;",
            tags$div(style = paste0("background: #ffc107; width: ", progress_pct, "%; height: 100%; border-radius: 4px;"))
          )
        ),

        # Current triad display
        div(class = "triad-instruction",
          tags$strong("Current Triad: "), "Click to mark 2 as SIMILAR (green) and 1 as DIFFERENT (red)"
        ),

        # Triad cards - separate uiOutput so text inputs don't reset
        uiOutput("triad_cards_ui"),

        # Construct poles input - these are OUTSIDE the reactive triad cards
        fluidRow(style = "margin-top: 12px;",
          column(6,
            tags$label(style = "color: #28a745; font-weight: bold; font-size: 12px;",
              "What makes the 2 SIMILAR? (Left pole)"),
            textInput("elicit_left", NULL, placeholder = "e.g., friendly, warm, modern...")
          ),
          column(6,
            tags$label(style = "color: #dc3545; font-weight: bold; font-size: 12px;",
              "What makes the 1 DIFFERENT? (Right pole)"),
            textInput("elicit_right", NULL, placeholder = "e.g., unfriendly, cold, traditional...")
          )
        ),

        # Action buttons
        fluidRow(
          column(12, style = "text-align: center; margin-top: 8px;",
            actionButton("add_elicited_construct", "Add Construct & Next Triad", class = "btn-warning"),
            actionButton("skip_triad", "Skip This Triad", class = "btn-outline-secondary btn-sm", style = "margin-left: 8px;"),
            actionButton("clear_triad", "Clear Selection", class = "btn-outline-secondary btn-sm", style = "margin-left: 8px;"),
            actionButton("stop_elicitation", "Done with Constructs", class = "btn-outline-danger btn-sm", style = "margin-left: 8px;")
          )
        ),

        tags$div(style = "margin-top: 8px; font-size: 11px; color: #666;",
          tags$strong("Constructs added: "), textOutput("constructs_count", inline = TRUE)
        )
      )
    } else if (!elicit_active || manual) {
      # Manual mode
      div(class = "elicit-section", style = "margin-top: 10px;",
        div(class = "step-header",
          h5("Step 2: Add Constructs"),
          actionButton("info_constructs", "?", class = "btn-info info-btn"),
          actionButton("begin_elicitation", "Switch to Guided Mode", class = "btn-outline-success btn-sm", style = "margin-left: 8px;")
        ),
        conditionalPanel(
          condition = "input.info_constructs % 2 == 1",
          div(class = "info-popup",
            tags$strong("Constructs"), " are bipolar dimensions with two opposite poles.",
            tags$br(),
            "Example: friendly - unfriendly, warm - cold"
          )
        ),
        fluidRow(
          column(6,
            textInput("construct_left", NULL, placeholder = "Left pole"),
            textInput("construct_right", NULL, placeholder = "Right pole"),
            actionButton("add_construct", "Add", class = "btn-warning btn-sm")
          ),
          column(6,
            tags$small("Or paste list (left - right):"),
            tags$textarea(id = "constructs_bulk", rows = 2, style = "width: 100%; font-size: 11px;", placeholder = "friendly - unfriendly"),
            actionButton("add_constructs_bulk", "Add All", class = "btn-warning btn-sm", style = "margin-top: 2px;")
          )
        ),
        tags$div(style = "margin-top: 6px; font-size: 11px; color: #666;",
          tags$strong("Added: "), textOutput("constructs_count", inline = TRUE)
        )
      )
    }
  })

  # Ratings section UI - only shown when constructs exist
  output$ratings_section_ui <- renderUI({
    if (nrow(rv$constructs) == 0) return(NULL)

    construct_choices <- paste(rv$constructs$left, "-", rv$constructs$right)

    # Calculate progress
    n_elements <- length(rv$elements)
    n_constructs <- nrow(rv$constructs)
    total_needed <- n_elements * n_constructs
    n_rated <- nrow(rv$ratings)
    pct_complete <- if (total_needed > 0) round(100 * n_rated / total_needed) else 0

    # Check completion per construct
    construct_completion <- sapply(construct_choices, function(c) {
      sum(rv$ratings$construct == c)
    })
    all_constructs_complete <- all(construct_completion >= n_elements)

    div(class = "ratings-section",
      div(class = "step-header",
        h5("Step 3: Rate Each Element on Each Construct"),
        actionButton("info_ratings", "?", class = "btn-info info-btn")
      ),
      conditionalPanel(
        condition = "input.info_ratings % 2 == 1",
        div(class = "info-popup",
          tags$strong("Rating: "), "For each element-construct pair, rate where the element falls.",
          tags$br(),
          "1 = strongly LEFT pole, 4 = neutral, 7 = strongly RIGHT pole"
        )
      ),

      # Progress bar
      div(style = "margin-bottom: 10px;",
        tags$div(style = "font-size: 11px; margin-bottom: 4px;",
          paste0("Progress: ", n_rated, " / ", total_needed, " ratings (", pct_complete, "%)")
        ),
        tags$div(style = "background: #e9ecef; border-radius: 4px; height: 8px;",
          tags$div(style = paste0("background: ", if(pct_complete == 100) "#28a745" else "#007bff", "; width: ", pct_complete, "%; height: 100%; border-radius: 4px;"))
        )
      ),

      # Guidance panel when construct is complete
      uiOutput("rating_guidance_ui"),

      fluidRow(
        column(3, selectInput("rating_element", "Element:", choices = rv$elements)),
        column(3, selectInput("rating_construct", "Construct:", choices = construct_choices))
      ),
      fluidRow(
        column(10,
          uiOutput("rating_slider_ui")
        ),
        column(2, tags$div(style = "margin-top: 20px;", actionButton("add_rating", "Add", class = "btn-warning")))
      ),
      h5("Ratings Table"),
      DTOutput("ratings_table"),
      fluidRow(
        column(6, actionButton("remove_rating", "Remove Selected", class = "btn-danger btn-sm")),
        column(6, style = "text-align: right;",
          downloadButton("save_grid_json", "Save Grid", class = "btn-sm"),
          actionButton("email_grid", "Email to Self", class = "btn-outline-primary btn-sm", style = "margin-left: 4px;")
        )
      )
    )
  })

  # Guidance UI based on progress
  output$rating_guidance_ui <- renderUI({
    req(input$rating_construct)
    n_elements <- length(rv$elements)
    current_construct <- input$rating_construct

    # Count ratings for current construct
    n_rated_this_construct <- sum(rv$ratings$construct == current_construct)

    if (n_rated_this_construct >= n_elements) {
      # This construct is complete
      n_constructs <- nrow(rv$constructs)
      construct_choices <- paste(rv$constructs$left, "-", rv$constructs$right)
      construct_completion <- sapply(construct_choices, function(c) sum(rv$ratings$construct == c))
      all_complete <- all(construct_completion >= n_elements)

      if (all_complete) {
        # All done!
        div(class = "info-popup", style = "background: #d4edda; border-color: #28a745;",
          tags$strong("\u2705 All ratings complete!"),
          tags$br(),
          "You can now:",
          tags$ul(style = "margin: 6px 0;",
            tags$li(actionLink("goto_analysis", "Run Analysis"), " - See your results in the analysis tabs"),
            tags$li(actionLink("add_more_constructs", "Add More Constructs"), " - Enrich your grid with additional dimensions"),
            tags$li("Save or email your grid using the buttons below")
          )
        )
      } else {
        # Find incomplete constructs
        incomplete <- construct_choices[construct_completion < n_elements]
        div(class = "info-popup", style = "background: #fff3cd; border-color: #ffc107;",
          tags$strong("\u2705 This construct is complete!"),
          tags$br(),
          "Choose your next step:",
          tags$ul(style = "margin: 6px 0;",
            tags$li(tags$strong("Rate another construct: "), paste(incomplete[1:min(2, length(incomplete))], collapse = ", "),
                   if(length(incomplete) > 2) paste0(" (+ ", length(incomplete)-2, " more)")),
            tags$li(actionLink("add_more_constructs2", "Add more constructs"), " to capture additional dimensions"),
            tags$li(actionLink("goto_analysis2", "Run analysis"), " with current data (you can add more later)")
          )
        )
      }
    } else {
      # Show remaining count
      remaining <- n_elements - n_rated_this_construct
      NULL
    }
  })

  # Dynamic pole labels that update when construct changes
  output$pole_labels_ui <- renderUI({
    req(input$rating_construct)
    req(nrow(rv$constructs) > 0)

    # Find the selected construct's poles
    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)
    idx <- match(input$rating_construct, construct_labels)

    if (is.na(idx)) {
      left_pole <- "Left"
      right_pole <- "Right"
    } else {
      left_pole <- rv$constructs$left[idx]
      right_pole <- rv$constructs$right[idx]
    }

    fluidRow(
      column(4, tags$div(style = "text-align: left; font-weight: bold; color: #28a745; font-size: 12px;", paste0("1 = ", left_pole))),
      column(4, tags$div(style = "text-align: center; color: #666; font-size: 11px;", "4 = neutral")),
      column(4, tags$div(style = "text-align: right; font-weight: bold; color: #dc3545; font-size: 12px;", paste0(right_pole, " = 7")))
    )
  })

  # Slider UI (separate so it doesn't reset when labels change)
  output$rating_slider_ui <- renderUI({
    req(nrow(rv$constructs) > 0)

    div(
      uiOutput("pole_labels_ui"),
      sliderInput("rating_score", NULL, min = 1, max = 7, value = 4, width = "100%", ticks = TRUE)
    )
  })

  observeEvent(input$add_construct, {
    req(input$construct_left, input$construct_right)
    new_construct_label <- paste(input$construct_left, "-", input$construct_right)
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
    # Select the new construct in the ratings dropdown
    updateSelectInput(session, "rating_construct", selected = new_construct_label)
    # Reset to first element
    if (length(rv$elements) > 0) {
      updateSelectInput(session, "rating_element", selected = rv$elements[1])
    }
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

    # Store current construct to preserve it
    current_construct <- input$rating_construct

    # Check if this element-construct pair already exists (update instead of add)
    existing_key <- paste(rv$ratings$element, rv$ratings$construct, sep = "||")
    new_key <- paste(input$rating_element, input$rating_construct, sep = "||")
    existing_idx <- which(existing_key == new_key)

    if (length(existing_idx) > 0) {
      # Update existing rating
      rv$ratings$rating[existing_idx[1]] <- input$rating_score
    } else {
      # Add new rating
      rv$ratings <- rbind(
        rv$ratings,
        data.frame(
          element = input$rating_element,
          construct = input$rating_construct,
          rating = input$rating_score,
          stringsAsFactors = FALSE
        )
      )
    }

    # Auto-advance to next UNRATED element for this construct (stay on same construct)
    current_elem <- input$rating_element
    elem_idx <- match(current_elem, rv$elements)

    # Find elements not yet rated on this construct
    rated_elements <- rv$ratings$element[rv$ratings$construct == current_construct]
    unrated_elements <- setdiff(rv$elements, rated_elements)

    if (length(unrated_elements) > 0) {
      # Move to first unrated element
      updateSelectInput(session, "rating_element", selected = unrated_elements[1])
    } else if (!is.na(elem_idx) && elem_idx < length(rv$elements)) {
      # All rated for this construct - just move to next element in list
      next_elem <- rv$elements[elem_idx + 1]
      updateSelectInput(session, "rating_element", selected = next_elem)
    }

    # Keep the construct dropdown on the same construct
    updateSelectInput(session, "rating_construct", selected = current_construct)

    # Reset slider to middle
    updateSliderInput(session, "rating_score", value = 4)
  })

  # Action link handlers for guidance panel
  # Use JavaScript to click the analyze button
  observeEvent(input$goto_analysis, {
    session$sendCustomMessage("clickButton", "analyze")
  })

  observeEvent(input$goto_analysis2, {
    session$sendCustomMessage("clickButton", "analyze")
  })

  observeEvent(input$add_more_constructs, {
    rv$show_constructs <- TRUE
    rv$elicitation_active <- TRUE
    rv$manual_mode <- FALSE
    session$sendCustomMessage("scrollToElement", "constructs_section")
  })

  observeEvent(input$add_more_constructs2, {
    rv$show_constructs <- TRUE
    rv$elicitation_active <- TRUE
    rv$manual_mode <- FALSE
    session$sendCustomMessage("scrollToElement", "constructs_section")
  })

  # Save grid as JSON
  output$save_grid_json <- downloadHandler(
    filename = function() {
      paste0("repgrid_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".json")
    },
    content = function(file) {
      grid_data <- list(
        elements = rv$elements,
        constructs = rv$constructs,
        ratings = rv$ratings,
        timestamp = Sys.time(),
        version = "1.0"
      )
      jsonlite::write_json(grid_data, file, pretty = TRUE, auto_unbox = TRUE)
    }
  )

  # Email grid to self - show modal with email form
 observeEvent(input$email_grid, {
    showModal(modalDialog(
      title = "Email Grid to Yourself",
      textInput("email_address", "Your email address:", placeholder = "you@example.com"),
      tags$hr(),
      tags$p(style = "font-size: 12px; color: #666;",
        "This will generate a mailto: link with your grid data. ",
        "Click the button below to open your email client with the data attached."
      ),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("send_email", "Open Email Client", class = "btn-primary")
      )
    ))
  })

  observeEvent(input$send_email, {
    req(input$email_address)

    # Create grid summary for email body
    grid_summary <- paste0(
      "RepGrid Data Export\n",
      "==================\n\n",
      "Elements (", length(rv$elements), "): ", paste(rv$elements, collapse = ", "), "\n\n",
      "Constructs (", nrow(rv$constructs), "):\n",
      paste(paste0("  - ", rv$constructs$left, " - ", rv$constructs$right), collapse = "\n"), "\n\n",
      "Ratings (", nrow(rv$ratings), "):\n",
      paste(apply(rv$ratings, 1, function(r) paste0("  ", r["element"], " | ", r["construct"], " | ", r["rating"])), collapse = "\n"),
      "\n\n---\nGenerated by RepPlus App"
    )

    # URL encode the body
    email_body <- utils::URLencode(grid_summary, reserved = TRUE)
    email_subject <- utils::URLencode("My RepGrid Data", reserved = TRUE)
    mailto_url <- paste0("mailto:", input$email_address, "?subject=", email_subject, "&body=", email_body)

    # Use JavaScript to open mailto link
    session$sendCustomMessage("openMailto", mailto_url)
    removeModal()
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

  # Element and construct counts for Build Grid tab

  output$elements_count <- renderText({
    n <- length(rv$elements)
    if (n == 0) "None yet"
    else paste(n, "elements:", paste(rv$elements, collapse = ", "))
  })

  output$constructs_count <- renderText({
    n <- nrow(rv$constructs)
    if (n == 0) "None yet"
    else {
      labels <- paste(rv$constructs$left, "-", rv$constructs$right)
      paste0(n, " (", paste(labels, collapse = "; "), ")")
    }
  })

  output$ratings_table <- renderDT({
    datatable(
      rv$ratings,
      selection = "single",
      rownames = FALSE,
      options = list(
        scrollX = TRUE,
        autoWidth = FALSE,
        pageLength = 15,
        columnDefs = list(
          list(className = 'dt-left', targets = '_all')
        )
      )
    )
  })

  # Click on row to edit that rating
  observeEvent(input$ratings_table_rows_selected, {
    sel <- input$ratings_table_rows_selected
    if (length(sel) && sel <= nrow(rv$ratings)) {
      row <- rv$ratings[sel, ]
      updateSelectInput(session, "rating_element", selected = row$element)
      updateSelectInput(session, "rating_construct", selected = row$construct)
      updateSliderInput(session, "rating_score", value = row$rating)
    }
  })

  observeEvent(input$remove_rating, {
    sel <- input$ratings_table_rows_selected
    if (length(sel)) {
      rv$ratings <- rv$ratings[-sel, , drop = FALSE]
    }
  })

  # Import grid (supports .rgrid and .json formats)
  observeEvent(input$import_grid, {
    req(input$import_file)

    file_path <- input$import_file$datapath
    file_name <- input$import_file$name
    file_ext <- tolower(tools::file_ext(file_name))

    tryCatch({
      if (file_ext == "json") {
        # Import JSON format (exported from this app)
        grid_data <- jsonlite::read_json(file_path)

        # Validate required fields
        if (is.null(grid_data$elements) || is.null(grid_data$constructs)) {
          showNotification("Invalid JSON file: missing elements or constructs", type = "error")
          return()
        }

        rv$elements <- as.character(grid_data$elements)

        # Handle constructs - could be list or data frame
        if (is.data.frame(grid_data$constructs)) {
          rv$constructs <- grid_data$constructs
        } else {
          rv$constructs <- data.frame(
            left = sapply(grid_data$constructs, function(x) x$left),
            right = sapply(grid_data$constructs, function(x) x$right),
            stringsAsFactors = FALSE
          )
        }

        # Handle ratings
        if (!is.null(grid_data$ratings) && length(grid_data$ratings) > 0) {
          if (is.data.frame(grid_data$ratings)) {
            rv$ratings <- grid_data$ratings
          } else {
            rv$ratings <- data.frame(
              element = sapply(grid_data$ratings, function(x) x$element),
              construct = sapply(grid_data$ratings, function(x) x$construct),
              rating = sapply(grid_data$ratings, function(x) x$rating),
              stringsAsFactors = FALSE
            )
          }
        } else {
          rv$ratings <- data.frame(
            element = character(),
            construct = character(),
            rating = numeric(),
            stringsAsFactors = FALSE
          )
        }

        showNotification(
          paste0("Loaded ", length(rv$elements), " elements, ",
                 nrow(rv$constructs), " constructs, ",
                 nrow(rv$ratings), " ratings from JSON"),
          type = "message"
        )

      } else if (file_ext == "rgrid") {
        # Import .rgrid format
        txt <- readLines(file_path, warn = FALSE, encoding = "UTF-8")

        # Parse constructs (lines starting with C) – take last two non-empty fields
        c_lines <- grep("^C\\d+\\t", txt, value = TRUE)
        if (length(c_lines) == 0) {
          showNotification("Invalid .rgrid file: no constructs found", type = "error")
          return()
        }
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
        if (length(e_lines) == 0) {
          showNotification("Invalid .rgrid file: no elements found", type = "error")
          return()
        }
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

        showNotification(
          paste0("Loaded ", n_e, " elements, ", n_c, " constructs from .rgrid"),
          type = "message"
        )

      } else {
        showNotification("Unsupported file format. Please use .json or .rgrid", type = "error")
      }
    }, error = function(e) {
      showNotification(paste("Error importing file:", e$message), type = "error")
    })
  })

  # Analyze
  observeEvent(input$analyze, {
    showNotification("Starting analysis...", type = "message", duration = 2)

    tryCatch({
      # Validation: need at least some data
      n_elem <- length(rv$elements)
      n_const <- if (is.null(rv$constructs) || !is.data.frame(rv$constructs)) 0 else nrow(rv$constructs)
      n_ratings <- if (is.null(rv$ratings) || !is.data.frame(rv$ratings)) 0 else nrow(rv$ratings)

      if (n_elem < 2) {
        showNotification("Need at least 2 elements to run analysis.", type = "error")
        return()
      }
      if (n_const < 2) {
        showNotification("Need at least 2 constructs to run analysis.", type = "error")
        return()
      }
      if (n_ratings == 0) {
        showNotification("No ratings found. Please rate elements on constructs first.", type = "error")
        return()
      }

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
        showNotification(
          "Analysis aborted: some ratings are missing. Tick 'Impute missing ratings' or complete all ratings.",
          type = "error"
        )
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
    rv$imputed_last <- imputed

    showNotification("Analysis complete!", type = "message", duration = 2)
    }, error = function(e) {
      showNotification(paste("Analysis error:", e$message), type = "error")
    })
  })

  # ---- Analysis Output Plots (outside observeEvent so they react to color changes) ----

  output$analysis_summary <- renderPrint({
    req(rv$repgrid_last)
    if (isTRUE(rv$imputed_last)) {
      cat("Note: Missing ratings were imputed with 4 (midpoint).\n\n")
    }
    print(summary(rv$repgrid_last))
  })

  output$pca_biplot <- renderPlot({
    sm <- rv$scores_mat_last
    if (is.null(sm)) return()
    # PCA on elements (rows)
    pc <- prcomp(sm, scale. = TRUE)
    ex <- pc$x[, 1:2]
    # construct loadings (approx via correlations)
    load <- cor(sm, pc$x)[, 1:2]

    # Get colors from biplot-specific palette
    colors <- get_palette_colors(input$biplot_palette)
    txt_size <- input$text_size

    # PrinGrid format: show both poles (left at negative end, right at positive end)
    # Include both positive and negative endpoints for construct lines
    all_points <- rbind(ex, load, -load)
    x_range <- range(all_points[, 1])
    y_range <- range(all_points[, 2])
    x_expand <- diff(x_range) * 0.25  # 25% padding
    y_expand <- diff(y_range) * 0.25
    xlim <- c(x_range[1] - x_expand, x_range[2] + x_expand)
    ylim <- c(y_range[1] - y_expand, y_range[2] + y_expand)

    # Set margins for better label display
    par(mar = c(4, 6, 2, 6), cex.axis = txt_size, cex.lab = txt_size * 1.1)

    plot(ex, type = "n", xlab = "PC1", ylab = "PC2", xlim = xlim, ylim = ylim)
    points(ex, pch = 19, col = colors$element, cex = txt_size * 1.3)

    # Offset overlapping element labels
    el_pos <- rep(3, nrow(ex))
    pos_cycle <- c(3, 4, 1, 2)
    thresh <- diff(range(xlim)) * 0.08
    for (i in seq_len(nrow(ex))) {
      for (j in seq_len(i - 1)) {
        d <- sqrt(sum((ex[i, ] - ex[j, ])^2))
        if (d < thresh) {
          el_pos[i] <- pos_cycle[((i - 1) %% 4) + 1]
        }
      }
    }
    # Scale text down when many elements/constructs overlap
    n_items <- nrow(ex) + nrow(load)
    label_scale <- if (n_items > 10) 0.8 else if (n_items > 7) 0.9 else 1.0
    text(ex, labels = rv$elements, pos = el_pos,
         col = colors$element, cex = txt_size * label_scale, font = 2)

    # PrinGrid format: draw lines through origin with both poles labeled
    for (i in 1:nrow(load)) {
      lines(c(-load[i, 1], load[i, 1]), c(-load[i, 2], load[i, 2]),
            col = colors$construct, lwd = 2)
      points(load[i, 1], load[i, 2], pch = 4, col = colors$construct, cex = 0.8)
      points(-load[i, 1], -load[i, 2], pch = 4, col = colors$construct, cex = 0.8)
    }

    # Offset overlapping construct labels
    c_pos_r <- rep(4, nrow(load))
    c_pos_l <- rep(2, nrow(load))
    for (i in seq_len(nrow(load))) {
      for (j in seq_len(i - 1)) {
        d <- sqrt(sum((load[i, ] - load[j, ])^2))
        if (d < thresh) {
          c_pos_r[i] <- pos_cycle[((i - 1) %% 4) + 1]
          c_pos_l[i] <- pos_cycle[((i + 1) %% 4) + 1]
        }
      }
    }
    # Label RIGHT pole at positive direction
    text(load[, 1], load[, 2], labels = rv$constructs$right,
         pos = c_pos_r, col = colors$construct, cex = txt_size * label_scale, font = 2, xpd = TRUE)
    # Label LEFT pole at negative direction
    text(-load[, 1], -load[, 2], labels = rv$constructs$left,
         pos = c_pos_l, col = colors$construct, cex = txt_size * label_scale, font = 3, xpd = TRUE)

    abline(h = 0, v = 0, lty = 3, col = "gray50")
  })

  output$heatmap_plot <- renderPlot({
    sm <- rv$scores_mat_last
    if (is.null(sm)) return()

    # Get colors from heatmap-specific palette
    colors <- get_palette_colors(input$heatmap_palette)
    txt_size <- input$text_size
    cell_size <- input$grid_cell_size

    # Build palette - use selected color palette
    if (isTRUE(input$heatmap_use_color)) {
      # Use palette colors for diverging heatmap
      pal <- colorRampPalette(c(colors$heat_low, "#FFFFFF", colors$heat_high))(100)
    } else {
      pal <- gray.colors(100, start = 0.95, end = 0.2)
    }
    # sm is elements (rows) × constructs (cols)
    n_elem <- nrow(sm)
    n_cons <- ncol(sm)
    # Flip elements so first appears at top
    z <- sm[n_elem:1, ]

    # Set margins to accommodate labels - scale with text size
    par(mar = c(8 * txt_size, 14 * txt_size, 2, 2))

    # Draw heatmap
    image(
      x = 1:n_elem, y = 1:n_cons, z = z,
      col = pal, axes = FALSE, xlab = "", ylab = ""
    )

    # Add rating values as text in each cell - scale with cell_size
    for (i in 1:n_elem) {
      for (j in 1:n_cons) {
        val <- z[i, j]
        if (!is.na(val)) {
          # Choose text color based on value for readability
          text_col <- if (val > 4) "white" else "black"
          text(i, j, sprintf("%.0f", val), col = text_col, cex = cell_size * 1.2, font = 2)
        }
      }
    }

    # Add axes with labels - scale with text_size
    axis(1, at = 1:n_elem, labels = rev(rv$elements), las = 2, cex.axis = txt_size)
    labs <- paste(rv$constructs$left, "-", rv$constructs$right)
    axis(2, at = 1:n_cons, labels = labs, las = 1, cex.axis = txt_size)
    box()

    # Add axis titles at ends - scale with text_size
    mtext("Elements", side = 1, line = 6 * txt_size, cex = txt_size * 1.1, adj = 1)
    mtext("Constructs", side = 2, line = 11 * txt_size, cex = txt_size * 1.1, adj = 1)
  })

  output$dend_elements <- renderPlot({
    sm <- rv$scores_mat_last
    if (is.null(sm)) {
      plot.new()
      text(0.5, 0.5, "No data available. Run analysis first.", cex = 1.2)
      return()
    }
    if (nrow(sm) < 2) {
      plot.new()
      text(0.5, 0.5, "Need at least 2 elements for dendrogram.", cex = 1.2)
      return()
    }
    d <- dist(sm)
    if (any(is.na(d)) || length(d) == 0) {
      plot.new()
      text(0.5, 0.5, "Cannot compute distances. Check your data.", cex = 1.2)
      return()
    }

    # Get colors and text size from settings
    colors <- get_colors()
    txt_size <- input$text_size

    hc <- hclust(d)
    par(mar = c(2, 10 * txt_size, 2, 2), cex = txt_size)
    plot(hc, labels = rv$elements, main = "Elements", xlab = "", sub = "",
         ylab = "Distance (Euclidean)", hang = -1, cex = txt_size)
  })

  output$dend_constructs <- renderPlot({
    sm <- rv$scores_mat_last
    if (is.null(sm)) {
      plot.new()
      text(0.5, 0.5, "No data available. Run analysis first.", cex = 1.2)
      return()
    }
    if (ncol(sm) < 2) {
      plot.new()
      text(0.5, 0.5, "Need at least 2 constructs for dendrogram.", cex = 1.2)
      return()
    }
    # Calculate distance matrix for constructs (columns)
    d <- dist(t(sm))
    # Check if distance matrix is valid
    if (any(is.na(d)) || length(d) == 0) {
      plot.new()
      text(0.5, 0.5, "Cannot compute distances. Check your data.", cex = 1.2)
      return()
    }

    # Get colors and text size from settings
    colors <- get_colors()
    txt_size <- input$text_size

    hc <- hclust(d)
    labs <- paste(rv$constructs$left, "-", rv$constructs$right)
    max_lab_len <- max(nchar(labs), na.rm = TRUE)
    left_mar <- max(14, max_lab_len * 0.5) * txt_size
    par(mar = c(2, left_mar, 2, 2), cex = txt_size)
    plot(hc, labels = labs, main = "Constructs", xlab = "", sub = "",
         ylab = "Distance (Euclidean)", hang = -1, cex = txt_size * 0.9)
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

    # Get colors from crossplot-specific palette
    colors <- get_palette_colors(input$crossplot_palette)
    txt_size <- input$text_size

    # Set up plot with scalable text
    par(mar = c(5, 5, 3, 2), cex.axis = txt_size, cex.lab = txt_size * 1.1, cex.main = txt_size * 1.2)

    # Use palette element color
    base_col <- colors$element

    # Calculate opacity based on proximity - elements close together get different opacities
    n_elem <- length(x_ratings)
    opacities <- rep(1, n_elem)  # Start with full opacity

    # Find clusters of overlapping points (within 0.3 units)
    threshold <- 0.3
    for (i in 1:n_elem) {
      # Count how many points are close to this one
      close_count <- sum(abs(x_ratings - x_ratings[i]) < threshold &
                        abs(y_ratings - y_ratings[i]) < threshold)
      if (close_count > 1) {
        # Find rank within cluster for staggered opacity
        cluster_indices <- which(abs(x_ratings - x_ratings[i]) < threshold &
                                abs(y_ratings - y_ratings[i]) < threshold)
        rank_in_cluster <- which(cluster_indices == i)
        # Decrease opacity by 15% for each overlapping element
        opacities[i] <- max(0.4, 1 - (rank_in_cluster - 1) * 0.15)
      }
    }

    # Convert hex color to RGB and apply opacity
    rgb_vals <- col2rgb(base_col)
    point_cols <- sapply(opacities, function(alpha) {
      rgb(rgb_vals[1], rgb_vals[2], rgb_vals[3], alpha = alpha * 255, maxColorValue = 255)
    })

    # Get pole labels for selected constructs
    x_left_pole <- rv$constructs$left[x_idx]
    x_right_pole <- rv$constructs$right[x_idx]
    y_left_pole <- rv$constructs$left[y_idx]
    y_right_pole <- rv$constructs$right[y_idx]

    # Create empty plot first
    plot(NULL, xlim = c(1, 7), ylim = c(1, 7),
         xlab = "",
         ylab = "",
         main = "Crossplot: Element Positions",
         asp = 1)

    # Add pole labels at axis ends - x-axis at ends, y-axis at origin with arrows
    mtext(x_left_pole, side = 1, at = 1, line = 2.5, cex = txt_size * 0.9, adj = 0, font = 3)
    mtext(x_right_pole, side = 1, at = 7, line = 2.5, cex = txt_size * 0.9, adj = 1, font = 3)
    # Y-axis labels at origin (bottom) with arrow indicating direction
    mtext(paste0(y_left_pole, " \u2192 ", y_right_pole), side = 2, line = 3, cex = txt_size * 0.85, font = 3)

    # Add grid lines if requested (before points so they're behind)
    if (input$crossplot_grid) {
      abline(h = 1:7, v = 1:7, col = "gray90", lty = 1)
      abline(h = 4, v = 4, col = "gray60", lty = 2, lwd = 1.5)
    }

    # Plot points with varying opacity
    points(x_ratings, y_ratings, pch = 19, col = point_cols, cex = txt_size * 1.6)

    # Add element labels if requested
    if (input$crossplot_labels) {
      # Offset labels slightly for overlapping points
      label_offsets <- rep(3, n_elem)  # Default: above
      for (i in 1:n_elem) {
        close_indices <- which(abs(x_ratings - x_ratings[i]) < threshold &
                              abs(y_ratings - y_ratings[i]) < threshold)
        if (length(close_indices) > 1) {
          rank <- which(close_indices == i)
          # Cycle through positions: above, right, below, left
          label_offsets[i] <- ((rank - 1) %% 4) + 1
        }
      }
      # Create label colors with same opacity
      label_cols <- sapply(opacities, function(alpha) {
        rgb(rgb_vals[1], rgb_vals[2], rgb_vals[3], alpha = alpha * 255, maxColorValue = 255)
      })
      for (i in 1:n_elem) {
        text(x_ratings[i], y_ratings[i], labels = rv$elements[i],
             pos = label_offsets[i], cex = txt_size, col = label_cols[i], font = 2)
      }
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

      # Get colors from crossplot-specific palette
      colors <- get_palette_colors(input$crossplot_palette)
      txt_size <- input$text_size
      base_col <- colors$element

      # Calculate opacity based on proximity
      n_elem <- length(x_ratings)
      opacities <- rep(1, n_elem)
      threshold <- 0.3
      for (i in 1:n_elem) {
        close_count <- sum(abs(x_ratings - x_ratings[i]) < threshold &
                          abs(y_ratings - y_ratings[i]) < threshold)
        if (close_count > 1) {
          cluster_indices <- which(abs(x_ratings - x_ratings[i]) < threshold &
                                  abs(y_ratings - y_ratings[i]) < threshold)
          rank_in_cluster <- which(cluster_indices == i)
          opacities[i] <- max(0.4, 1 - (rank_in_cluster - 1) * 0.15)
        }
      }

      rgb_vals <- col2rgb(base_col)
      point_cols <- sapply(opacities, function(alpha) {
        rgb(rgb_vals[1], rgb_vals[2], rgb_vals[3], alpha = alpha * 255, maxColorValue = 255)
      })

      # Get pole labels
      x_left_pole <- rv$constructs$left[x_idx]
      x_right_pole <- rv$constructs$right[x_idx]
      y_left_pole <- rv$constructs$left[y_idx]
      y_right_pole <- rv$constructs$right[y_idx]

      png(file, width = 1200, height = 1200, res = 120)

      par(mar = c(5, 5, 3, 2), cex.axis = txt_size, cex.lab = txt_size * 1.1, cex.main = txt_size * 1.2)

      plot(NULL, xlim = c(1, 7), ylim = c(1, 7),
           xlab = "",
           ylab = "",
           main = "Crossplot: Element Positions",
           asp = 1)

      # Add pole labels at axis ends - x-axis at ends, y-axis at origin with arrows
      mtext(x_left_pole, side = 1, at = 1, line = 2.5, cex = txt_size * 0.9, adj = 0, font = 3)
      mtext(x_right_pole, side = 1, at = 7, line = 2.5, cex = txt_size * 0.9, adj = 1, font = 3)
      # Y-axis labels at origin (bottom) with arrow indicating direction
      mtext(paste0(y_left_pole, " \u2192 ", y_right_pole), side = 2, line = 3, cex = txt_size * 0.85, font = 3)

      if (input$crossplot_grid) {
        abline(h = 1:7, v = 1:7, col = "gray90", lty = 1)
        abline(h = 4, v = 4, col = "gray60", lty = 2, lwd = 1.5)
      }

      points(x_ratings, y_ratings, pch = 19, col = point_cols, cex = txt_size * 1.5)

      if (input$crossplot_labels) {
        label_offsets <- rep(3, n_elem)
        for (i in 1:n_elem) {
          close_indices <- which(abs(x_ratings - x_ratings[i]) < threshold &
                                abs(y_ratings - y_ratings[i]) < threshold)
          if (length(close_indices) > 1) {
            rank <- which(close_indices == i)
            label_offsets[i] <- ((rank - 1) %% 4) + 1
          }
        }
        label_cols <- sapply(opacities, function(alpha) {
          rgb(rgb_vals[1], rgb_vals[2], rgb_vals[3], alpha = alpha * 255, maxColorValue = 255)
        })
        for (i in 1:n_elem) {
          text(x_ratings[i], y_ratings[i], labels = rv$elements[i],
               pos = label_offsets[i], cex = txt_size * 0.8, col = label_cols[i], font = 2)
        }
      }

      box()

      dev.off()
    }
  )

  # Synopsis Analysis
  output$synopsis_plot <- renderPlot({
    req(rv$scores_mat_last)
    sm <- rv$scores_mat_last

    # Get colors and text size from settings
    colors <- get_colors()
    txt_size <- input$text_size

    # Choose color scheme based on palette
    bar_color <- if (input$synopsis_color) colors$element else "gray50"
    mean_color <- colors$construct  # Vermillion-like
    median_color <- colors$highlight  # Teal-like

    if (input$synopsis_type == "overall") {
      # Overall rating distribution
      all_ratings <- as.vector(sm)
      all_ratings <- all_ratings[!is.na(all_ratings)]

      par(cex.axis = txt_size, cex.lab = txt_size * 1.1, cex.main = txt_size * 1.2)
      hist(all_ratings,
           breaks = input$synopsis_bins,
           main = "Overall Rating Distribution",
           xlab = "Rating",
           ylab = "Frequency",
           col = bar_color,
           border = "white")

      # Add mean and median lines with palette colors
      abline(v = mean(all_ratings), col = mean_color, lwd = 3, lty = 2)
      abline(v = median(all_ratings), col = median_color, lwd = 3, lty = 2)
      legend("topright",
             legend = c(paste("Mean =", round(mean(all_ratings), 2)),
                       paste("Median =", round(median(all_ratings), 2))),
             col = c(mean_color, median_color), lty = 2, lwd = 3, cex = txt_size)

    } else if (input$synopsis_type == "elements") {
      # Element distributions
      n_elem <- nrow(sm)
      par(mfrow = c(ceiling(n_elem / 3), 3))
      par(mar = c(4, 4, 2, 1), cex.axis = txt_size * 0.9, cex.lab = txt_size, cex.main = txt_size * 1.1)

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

        abline(v = mean(elem_ratings), col = mean_color, lwd = 2, lty = 2)
      }

    } else if (input$synopsis_type == "constructs") {
      # Construct distributions
      n_const <- ncol(sm)
      par(mfrow = c(ceiling(n_const / 3), 3))
      par(mar = c(4, 4, 3, 1), cex.axis = txt_size * 0.9, cex.lab = txt_size, cex.main = txt_size)

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
             cex.main = txt_size * 0.75)

        abline(v = mean(const_ratings), col = mean_color, lwd = 2, lty = 2)
      }

    } else if (input$synopsis_type == "scree") {
      # Scree plot
      pca_result <- prcomp(sm, scale. = TRUE)
      variance_explained <- (pca_result$sdev^2) / sum(pca_result$sdev^2) * 100
      cumulative_var <- cumsum(variance_explained)

      n_components <- min(10, length(variance_explained))

      par(mar = c(5, 4, 4, 5), cex.axis = txt_size, cex.lab = txt_size * 1.1, cex.main = txt_size * 1.2)

      # Line plot for variance explained (scree plot style)
      plot(1:n_components, variance_explained[1:n_components],
           type = "b", pch = 19, col = bar_color, lwd = 2, cex = 1.5,
           main = "Scree Plot - Variance Explained by Components",
           xlab = "Principal Component",
           ylab = "Variance Explained (%)",
           ylim = c(0, max(variance_explained[1:n_components]) * 1.2),
           xaxt = "n")
      axis(1, at = 1:n_components)

      # Add cumulative line on secondary axis
      par(new = TRUE)
      plot(1:n_components, cumulative_var[1:n_components],
           type = "b", pch = 17, col = mean_color, lwd = 2, cex = 1.2,
           axes = FALSE, xlab = "", ylab = "",
           ylim = c(0, 100))

      axis(4, col = mean_color, col.axis = mean_color, cex.axis = txt_size)
      mtext("Cumulative Variance (%)", side = 4, line = 3, col = mean_color, cex = txt_size)

      legend("right",
             legend = c("Individual", "Cumulative"),
             col = c(bar_color, mean_color),
             lty = 1, pch = c(19, 17),
             pt.cex = c(1.5, 1.2), cex = txt_size * 0.9)
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

        # Line plot for variance explained (scree plot style)
        plot(1:n_components, variance_explained[1:n_components],
             type = "b", pch = 19, col = bar_color, lwd = 2, cex = 1.5,
             main = "Scree Plot - Variance Explained by Components",
             xlab = "Principal Component",
             ylab = "Variance Explained (%)",
             ylim = c(0, max(variance_explained[1:n_components]) * 1.2),
             xaxt = "n")
        axis(1, at = 1:n_components)

        par(new = TRUE)
        plot(1:n_components, cumulative_var[1:n_components],
             type = "b", pch = 17, col = "red", lwd = 2, cex = 1.2,
             axes = FALSE, xlab = "", ylab = "",
             ylim = c(0, 100))

        axis(4, col = "red", col.axis = "red")
        mtext("Cumulative Variance (%)", side = 4, line = 3, col = "red")

        legend("right",
               legend = c("Individual", "Cumulative"),
               col = c(bar_color, "red"),
               lty = 1, pch = c(19, 17),
               pt.cex = c(1.5, 1.2))
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

    # Get colors from focus-specific palette
    colors <- get_palette_colors(input$focus_palette)

    # Explicitly capture reactive inputs to ensure dependency tracking
    txt_size <- input$text_size
    cell_size <- input$grid_cell_size
    show_vals <- input$focus_show_values
    show_shade <- input$focus_show_shading
    use_col <- input$focus_use_color
    use_spaced <- isTRUE(input$focus_spaced)

    if (use_spaced) {
      plot_focus_spaced(
        focus_result = result,
        title = "SPACED: Focus Cluster Analysis",
        show_values = show_vals,
        show_shading = show_shade,
        use_color = use_col,
        text_size = txt_size,
        cell_size = cell_size,
        heat_low = colors$heat_low,
        heat_high = colors$heat_high
      )
    } else {
      plot_focus_cluster(
        focus_result = result,
        title = "Focus Cluster Analysis",
        show_values = show_vals,
        show_shading = show_shade,
        use_color = use_col,
        text_size = txt_size,
        cell_size = cell_size,
        heat_low = colors$heat_low,
        heat_high = colors$heat_high
      )
    }
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

      # Get colors from focus-specific palette
      colors <- get_palette_colors(input$focus_palette)
      txt_size <- input$text_size
      cell_size <- input$grid_cell_size
      use_spaced <- isTRUE(input$focus_spaced)

      png(file, width = 1200, height = 900, res = 120)
      if (use_spaced) {
        plot_focus_spaced(
          focus_result = result,
          title = "SPACED: Focus Cluster Analysis",
          show_values = input$focus_show_values,
          show_shading = input$focus_show_shading,
          use_color = input$focus_use_color,
          text_size = txt_size,
          cell_size = cell_size,
          heat_low = colors$heat_low,
          heat_high = colors$heat_high
        )
      } else {
        plot_focus_cluster(
          focus_result = result,
          title = "Focus Cluster Analysis",
          show_values = input$focus_show_values,
          show_shading = input$focus_show_shading,
          use_color = input$focus_use_color,
          text_size = txt_size,
          cell_size = cell_size,
          heat_low = colors$heat_low,
          heat_high = colors$heat_high
        )
      }
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
    stats = NULL,
    foci = NULL
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

  # ===== MULTI-GRID SERVER LOGIC =====

  # Helper function to parse grid file (reused from import_grid observer)
  parse_grid_file <- function(file_path, file_name) {
    ext <- tolower(tools::file_ext(file_name))
    grid_data <- list(
      name = tools::file_path_sans_ext(file_name),
      elements = character(),
      constructs = data.frame(left = character(), right = character(), stringsAsFactors = FALSE),
      ratings = data.frame(element = character(), construct = character(), rating = numeric(), stringsAsFactors = FALSE),
      scores_mat = NULL,
      scale = c(1, 7)
    )

    if (ext == "json") {
      json_data <- tryCatch(fromJSON(file_path), error = function(e) NULL)
      if (is.null(json_data)) stop("Failed to parse JSON file")

      grid_data$elements <- json_data$elements
      if (is.list(json_data$constructs) && !is.data.frame(json_data$constructs)) {
        grid_data$constructs <- data.frame(
          left = sapply(json_data$constructs, function(x) x$left),
          right = sapply(json_data$constructs, function(x) x$right),
          stringsAsFactors = FALSE
        )
      } else {
        grid_data$constructs <- as.data.frame(json_data$constructs)
      }
      if (!is.null(json_data$ratings)) {
        grid_data$ratings <- as.data.frame(json_data$ratings)
      }
      if (!is.null(json_data$name)) grid_data$name <- json_data$name

    } else if (ext == "rgrid") {
      # Use same parsing logic as the working single-grid import
      txt <- readLines(file_path, warn = FALSE, encoding = "UTF-8")

      # Parse constructs (lines starting with C) - take last two non-empty fields
      c_lines <- grep("^C\\d+\\t", txt, value = TRUE)
      if (length(c_lines) == 0) stop("Invalid .rgrid file: no constructs found")

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

      grid_data$constructs <- data.frame(left = left, right = right, stringsAsFactors = FALSE)

      # Parse elements (lines starting with E) - name last; scores are last n_c before name
      e_lines <- grep("^E\\d+\\t", txt, value = TRUE)
      if (length(e_lines) == 0) stop("Invalid .rgrid file: no elements found")

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

      grid_data$elements <- elements
      grid_data$scores_mat <- scores_mat
      rownames(grid_data$scores_mat) <- elements
      colnames(grid_data$scores_mat) <- paste(left, "-", right)

      # Build ratings data frame
      labels <- paste(left, "-", right)
      grid_data$ratings <- data.frame(
        element   = rep(elements, times = n_c),
        construct = rep(labels,   each  = n_e),
        rating    = as.vector(scores_mat),
        stringsAsFactors = FALSE
      )

      # Try to detect scale from ratings
      all_ratings <- grid_data$scores_mat[!is.na(grid_data$scores_mat)]
      if (length(all_ratings) > 0) {
        grid_data$scale <- c(min(all_ratings), max(all_ratings))
      }

    }

    # Build scores_mat if not already done
    if (is.null(grid_data$scores_mat) && nrow(grid_data$ratings) > 0) {
      n_e <- length(grid_data$elements)
      n_c <- nrow(grid_data$constructs)
      construct_labels <- paste(grid_data$constructs$left, "-", grid_data$constructs$right)
      grid_data$scores_mat <- matrix(NA_real_, nrow = n_e, ncol = n_c)
      rownames(grid_data$scores_mat) <- grid_data$elements
      colnames(grid_data$scores_mat) <- construct_labels

      for (i in seq_len(n_e)) {
        for (j in seq_len(n_c)) {
          idx <- which(grid_data$ratings$element == grid_data$elements[i] &
                       grid_data$ratings$construct == construct_labels[j])
          if (length(idx) > 0) {
            grid_data$scores_mat[i, j] <- grid_data$ratings$rating[idx[1]]
          }
        }
      }
    }

    grid_data
  }

  # Add grids from file upload - triggered by button click
  observeEvent(input$add_files_to_collection, {
    req(input$import_multi_grid)

    # Get file info - handle both single and multiple files
    file_info <- input$import_multi_grid
    n_files <- length(file_info$name)

    message(paste("Multi-grid upload: Processing", n_files, "file(s)"))

    for (i in seq_len(n_files)) {
      file_path <- file_info$datapath[i]
      file_name <- file_info$name[i]

      message(paste("Processing file", i, ":", file_name))

      tryCatch({
        grid_data <- parse_grid_file(file_path, file_name)
        grid_id <- uuid::UUIDgenerate()
        grid_data$id <- grid_id
        grid_data$source <- "imported"

        # Add to collection
        rv$grid_collection[[grid_id]] <- grid_data

        # Update metadata - use character for timestamp to avoid type issues
        new_row <- data.frame(
          grid_id = grid_id,
          name = grid_data$name,
          n_elements = length(grid_data$elements),
          n_constructs = nrow(grid_data$constructs),
          scale_min = grid_data$scale[1],
          scale_max = grid_data$scale[2],
          imported_at = as.character(Sys.time()),
          stringsAsFactors = FALSE
        )
        rv$grid_metadata <- rbind(rv$grid_metadata, new_row)

        message(paste("Successfully added:", grid_data$name, "- Collection now has", nrow(rv$grid_metadata), "grids"))

        showNotification(paste("Added:", grid_data$name), type = "message")
      }, error = function(e) {
        message(paste("Error loading", file_name, ":", e$message))
        showNotification(paste("Error loading", file_name, ":", e$message), type = "error")
      })
    }
  })

  # Add current grid to collection
  observeEvent(input$add_current_grid, {
    req(length(rv$elements) >= 2, nrow(rv$constructs) >= 2)

    if (is.null(rv$scores_mat_last)) {
      showNotification("Please run 'Analyse Grid' first before adding to collection", type = "warning")
      return()
    }

    grid_id <- uuid::UUIDgenerate()
    grid_name <- paste("Current Grid", format(Sys.time(), "%H:%M"))

    grid_data <- list(
      id = grid_id,
      name = grid_name,
      elements = rv$elements,
      constructs = rv$constructs,
      ratings = rv$ratings,
      scores_mat = rv$scores_mat_last,
      scale = c(1, 7),
      source = "current"
    )

    rv$grid_collection[[grid_id]] <- grid_data

    rv$grid_metadata <- rbind(rv$grid_metadata, data.frame(
      grid_id = grid_id,
      name = grid_name,
      n_elements = length(rv$elements),
      n_constructs = nrow(rv$constructs),
      scale_min = 1,
      scale_max = 7,
      imported_at = Sys.time(),
      stringsAsFactors = FALSE
    ))

    showNotification(paste("Added current grid as:", grid_name), type = "message")
  })

  # Grid collection summary in sidebar
  output$grid_collection_summary <- renderUI({
    n_grids <- nrow(rv$grid_metadata)
    if (n_grids == 0) {
      tags$small(class = "text-muted", "No grids in collection")
    } else {
      tags$small(class = "text-muted", paste(n_grids, "grid(s) in collection"))
    }
  })

  # Grid collection table
  output$grid_collection_table <- renderDT({
    req(nrow(rv$grid_metadata) > 0)
    df <- rv$grid_metadata[, c("name", "n_elements", "n_constructs")]
    colnames(df) <- c("Name", "Elements", "Constructs")
    datatable(df, selection = "multiple", options = list(pageLength = 10, dom = "t"))
  })

  # Track selected grids from table
  observe({
    selected_rows <- input$grid_collection_table_rows_selected
    if (length(selected_rows) > 0) {
      rv$selected_grids <- rv$grid_metadata$grid_id[selected_rows]
    } else {
      rv$selected_grids <- character()
    }
  })

  # Select/deselect all grids
  observeEvent(input$select_all_grids, {
    proxy <- dataTableProxy("grid_collection_table")
    selectRows(proxy, seq_len(nrow(rv$grid_metadata)))
  })

  observeEvent(input$deselect_all_grids, {
    proxy <- dataTableProxy("grid_collection_table")
    selectRows(proxy, NULL)
  })

  # Remove selected grids
  observeEvent(input$remove_selected_grids, {
    req(length(rv$selected_grids) > 0)
    for (gid in rv$selected_grids) {
      rv$grid_collection[[gid]] <- NULL
    }
    rv$grid_metadata <- rv$grid_metadata[!rv$grid_metadata$grid_id %in% rv$selected_grids, ]
    rv$selected_grids <- character()
    rv$match_matrix <- NULL
    rv$socionet_data <- NULL
    showNotification("Selected grids removed", type = "message")
  })

  # Update common elements/constructs when selection changes
  observe({
    if (length(rv$selected_grids) >= 2) {
      selected <- rv$grid_collection[rv$selected_grids]
      rv$common_elements <- Reduce(intersect, lapply(selected, function(g) g$elements))

      all_labels <- lapply(selected, function(g) {
        paste(g$constructs$left, "-", g$constructs$right)
      })
      rv$common_constructs <- Reduce(intersect, all_labels)
    } else {
      rv$common_elements <- character()
      rv$common_constructs <- character()
    }
  })

  # Common structure info display
  output$common_structure_info <- renderUI({
    n_selected <- length(rv$selected_grids)
    n_common_elem <- length(rv$common_elements)
    n_common_const <- length(rv$common_constructs)

    if (n_selected < 2) {
      div(class = "info-popup", style = "background: #fff3cd;",
        tags$strong("Select at least 2 grids"), tags$br(),
        "Click rows in the grid table to select grids for analysis."
      )
    } else {
      div(class = "info-popup",
        tags$strong(n_selected, " grids selected"), tags$br(),
        tags$strong("Common elements: "), n_common_elem,
        if (n_common_elem > 0) paste0(" (", paste(head(rv$common_elements, 3), collapse = ", "),
                                      if (n_common_elem > 3) "..." else "", ")") else "",
        tags$br(),
        tags$strong("Common constructs: "), n_common_const
      )
    }
  })

  # Grid preview dropdown choices
  observe({
    choices <- setNames(rv$grid_metadata$grid_id, rv$grid_metadata$name)
    updateSelectInput(session, "preview_grid_select", choices = choices)
  })

  # Load selected grid from collection into editor
  observeEvent(input$load_preview_to_editor, {
    req(input$preview_grid_select)
    req(input$preview_grid_select %in% names(rv$grid_collection))

    g <- rv$grid_collection[[input$preview_grid_select]]

    # Load into editor
    rv$elements <- g$elements
    rv$constructs <- g$constructs
    rv$ratings <- g$ratings
    rv$scores_mat_last <- g$scores_mat

    # Switch to Build Grid tab
    updateTabsetPanel(session, "main_tabs", selected = "Build Grid")

    showNotification(paste("Loaded", g$name, "to editor"), type = "message")
  })

  # Navigation links from Grid Collection to analysis tabs - also trigger analysis
  observeEvent(input$goto_socionets, {
    # Trigger socionets analysis if grids are selected
    if (length(rv$selected_grids) >= 2 && length(rv$common_elements) >= 1) {
      selected_grids <- rv$grid_collection[rv$selected_grids]
      names(selected_grids) <- sapply(selected_grids, function(g) g$name)

      rv$match_matrix <- compute_match_matrix(
        selected_grids,
        rv$common_elements,
        power = 1.0
      )

      rv$socionet_data <- prepare_socionet_data(
        rv$match_matrix,
        cutoff = input$socionet_cutoff,
        symmetric = input$socionet_symmetric
      )
    }
    updateTabsetPanel(session, "main_tabs", selected = "Socionets")
  })

  observeEvent(input$goto_mode, {
    # Trigger mode grid generation if grids are selected
    if (length(rv$selected_grids) >= 2 && length(rv$common_elements) >= 2) {
      selected_grids <- rv$grid_collection[rv$selected_grids]
      names(selected_grids) <- sapply(selected_grids, function(g) g$name)

      tryCatch({
        rv$mode_grid <- generate_mode_grid(
          selected_grids,
          common_elements = rv$common_elements,
          method = input$mode_method,
          construct_handling = input$mode_construct_handling
        )
      }, error = function(e) {
        showNotification(paste("Error generating mode grid:", e$message), type = "error")
      })
    }
    updateTabsetPanel(session, "main_tabs", selected = "Mode Grid")
  })

  observeEvent(input$goto_composite, {
    # Trigger composite grid generation if grids are selected
    if (length(rv$selected_grids) >= 2) {
      selected_grids <- rv$grid_collection[rv$selected_grids]
      names(selected_grids) <- sapply(selected_grids, function(g) g$name)

      tryCatch({
        rv$composite_grid <- generate_composite_grid(
          selected_grids,
          merge_on = input$composite_merge_on,
          label_source = input$composite_label_source
        )
      }, error = function(e) {
        showNotification(paste("Error generating composite grid:", e$message), type = "error")
      })
    }
    updateTabsetPanel(session, "main_tabs", selected = "Composite Grid")
  })

  # ===== SOCIONETS ANALYSIS =====

  observeEvent(input$compute_socionets, {
    req(length(rv$selected_grids) >= 2)
    req(length(rv$common_elements) >= 1)

    selected_grids <- rv$grid_collection[rv$selected_grids]
    names(selected_grids) <- sapply(selected_grids, function(g) g$name)

    # Compute match matrix
    rv$match_matrix <- compute_match_matrix(
      selected_grids,
      rv$common_elements,
      power = 1.0
    )

    # Prepare network data
    rv$socionet_data <- prepare_socionet_data(
      rv$match_matrix,
      cutoff = input$socionet_cutoff,
      symmetric = input$socionet_symmetric
    )

    showNotification("Socionets analysis complete", type = "message")
  })

  # Update network when cutoff changes (no recomputation)
  observe({
    req(rv$match_matrix)
    rv$socionet_data <- prepare_socionet_data(
      rv$match_matrix,
      cutoff = input$socionet_cutoff,
      symmetric = input$socionet_symmetric
    )
  })

  # Socionets plot
  output$socionet_plot <- renderPlot({
    req(rv$socionet_data)
    plot_socionets(
      rv$socionet_data,
      title = "Socionets: Grid Relationships",
      show_weights = input$socionet_show_weights,
      node_color = input$socionet_node_color,
      edge_color = input$socionet_edge_color,
      text_size = input$socionet_text_size
    )
  })

  # Match matrix table
  output$match_matrix_table <- renderDT({
    req(rv$match_matrix)
    df <- as.data.frame(round(rv$match_matrix, 1))
    datatable(df, options = list(pageLength = 20, dom = "t", scrollX = TRUE))
  })

  # Download match matrix
  output$download_match_matrix <- downloadHandler(
    filename = function() paste0("match-matrix-", Sys.Date(), ".csv"),
    content = function(file) {
      req(rv$match_matrix)
      write.csv(rv$match_matrix, file)
    }
  )

  # Download socionets plot
  output$download_socionets_plot <- downloadHandler(
    filename = function() paste0("socionets-", Sys.Date(), ".png"),
    content = function(file) {
      req(rv$socionet_data)
      png(file, width = 800, height = 600)
      plot_socionets(
        rv$socionet_data,
        title = "Socionets: Grid Relationships",
        show_weights = input$socionet_show_weights
      )
      dev.off()
    }
  )

  # ===== MODE GRID GENERATION =====

  observeEvent(input$generate_mode_grid, {
    req(length(rv$selected_grids) >= 2)
    req(length(rv$common_elements) >= 2)

    selected_grids <- rv$grid_collection[rv$selected_grids]
    names(selected_grids) <- sapply(selected_grids, function(g) g$name)

    tryCatch({
      rv$mode_grid <- generate_mode_grid(
        selected_grids,
        common_elements = rv$common_elements,
        method = input$mode_method,
        construct_handling = input$mode_construct_handling
      )
      showNotification("Mode grid generated", type = "message")
    }, error = function(e) {
      showNotification(paste("Error generating mode grid:", e$message), type = "error")
    })
  })

  # Mode grid summary
  output$mode_grid_summary <- renderPrint({
    req(rv$mode_grid)
    g <- rv$mode_grid
    cat("Mode Grid:", g$name, "\n")
    cat("Source grids:", paste(g$source_grids, collapse = ", "), "\n\n")
    cat("Elements (", length(g$elements), "):", paste(g$elements, collapse = ", "), "\n")
    cat("Constructs:", nrow(g$constructs), "\n")
  })

  # Mode grid heatmap
  output$mode_grid_heatmap <- renderPlot({
    req(rv$mode_grid)
    g <- rv$mode_grid

    text_size <- if (!is.null(input$mode_text_size)) input$mode_text_size else 1.2
    show_values <- if (!is.null(input$mode_show_values)) input$mode_show_values else TRUE

    n_elem <- nrow(g$scores_mat)
    n_const <- ncol(g$scores_mat)

    # Get scale range
    scale_min <- g$scale[1]
    scale_max <- g$scale[2]

    # Set up layout: main heatmap + color legend
    layout(matrix(c(1, 2), nrow = 1), widths = c(5, 1))

    # Main heatmap
    par(mar = c(10, 12, 5, 1), family = "sans")
    mode_colors <- get_palette_colors(input$mode_palette)
    colors <- colorRampPalette(c(mode_colors$heat_low, "#FFFFFF", mode_colors$heat_high))(100)

    image(1:n_const, 1:n_elem,
          t(g$scores_mat[n_elem:1, , drop = FALSE]),
          col = colors,
          axes = FALSE, xlab = "", ylab = "",
          main = paste("Mode Grid:", g$name),
          cex.main = text_size * 1.1,
          zlim = c(scale_min, scale_max))

    # Add rating values if requested
    if (show_values) {
      for (i in 1:n_elem) {
        for (j in 1:n_const) {
          val <- g$scores_mat[i, j]
          if (!is.na(val)) {
            text(j, n_elem - i + 1, round(val),
                 cex = 0.8 * text_size, family = "sans")
          }
        }
      }
    }

    # Bottom axis: left poles (low rating end)
    axis(1, at = 1:n_const, labels = g$constructs$left, las = 2,
         cex.axis = 0.7 * text_size, family = "sans")
    # Top axis: right poles (high rating end)
    axis(3, at = 1:n_const, labels = g$constructs$right, las = 2,
         cex.axis = 0.7 * text_size, family = "sans", tick = FALSE, line = -0.5)
    # Left axis: elements
    axis(2, at = 1:n_elem, labels = rev(g$elements), las = 2,
         cex.axis = 0.8 * text_size, family = "sans")
    box()

    # Add scale indicator
    mtext(paste0("Blue = low (", scale_min, ", left pole)    White = mid    Orange = high (", scale_max, ", right pole)"),
          side = 1, line = 8, cex = 0.8 * text_size, family = "sans")

    # Color legend
    par(mar = c(10, 0.5, 5, 3), family = "sans")
    legend_vals <- seq(scale_min, scale_max, length.out = 100)
    image(1, legend_vals, t(as.matrix(legend_vals)), col = colors,
          axes = FALSE, xlab = "", ylab = "")
    axis(4, at = c(scale_min, (scale_min + scale_max) / 2, scale_max),
         labels = c(scale_min, round((scale_min + scale_max) / 2, 1), scale_max),
         las = 2, cex.axis = 0.8 * text_size, family = "sans")
    mtext("Rating", side = 3, line = 0.5, cex = 0.8 * text_size, family = "sans")
    box()
  })

  # Use mode grid as current
  observeEvent(input$use_mode_as_current, {
    req(rv$mode_grid)
    g <- rv$mode_grid

    rv$elements <- g$elements
    rv$constructs <- g$constructs[, c("left", "right")]
    rv$ratings <- g$ratings
    rv$scores_mat_last <- g$scores_mat
    rv$repgrid_last <- NULL

    showNotification("Mode grid loaded as current grid", type = "message")
  })

  # Download mode grid
  output$download_mode_grid <- downloadHandler(
    filename = function() paste0("mode-grid-", Sys.Date(), ".rgrid"),
    content = function(file) {
      req(rv$mode_grid)
      g <- rv$mode_grid

      lines <- character()
      # Write constructs
      for (i in seq_len(nrow(g$constructs))) {
        lines <- c(lines, paste0("C", i - 1, "\t", g$constructs$left[i], "\t", g$constructs$right[i]))
      }
      # Write elements with ratings
      for (i in seq_along(g$elements)) {
        scores_str <- paste(round(g$scores_mat[i, ], 1), collapse = "\t")
        lines <- c(lines, paste0("E", i - 1, "\t", g$elements[i], "\t", scores_str))
      }
      # Write metadata
      lines <- c(lines, paste0("_UID\t", g$id))
      lines <- c(lines, paste0("_Date\t", format(Sys.time(), "%Y-%m-%d")))
      lines <- c(lines, paste0("_Time\t", format(Sys.time(), "%H:%M:%S")))

      writeLines(lines, file)
    }
  )

  # ===== COMPOSITE GRID GENERATION =====

  observeEvent(input$generate_composite_grid, {
    req(length(rv$selected_grids) >= 2)

    selected_grids <- rv$grid_collection[rv$selected_grids]
    names(selected_grids) <- sapply(selected_grids, function(g) g$name)

    tryCatch({
      rv$composite_grid <- generate_composite_grid(
        selected_grids,
        merge_on = input$composite_merge_on,
        label_source = input$composite_label_source
      )
      showNotification("Composite grid generated", type = "message")
    }, error = function(e) {
      showNotification(paste("Error generating composite grid:", e$message), type = "error")
    })
  })

  # Composite grid summary
  output$composite_grid_summary <- renderPrint({
    req(rv$composite_grid)
    g <- rv$composite_grid
    cat("Composite Grid:", g$name, "\n")
    cat("Source grids:", paste(g$source_grids, collapse = ", "), "\n\n")
    cat("Elements:", length(g$elements), "\n")
    cat("Constructs:", nrow(g$constructs), "\n")
  })

  # Composite grid table
  output$composite_grid_table <- renderDT({
    req(rv$composite_grid)
    g <- rv$composite_grid

    df <- as.data.frame(round(g$scores_mat, 1))
    construct_labels <- paste(g$constructs$left, "-", g$constructs$right)
    colnames(df) <- construct_labels
    df <- cbind(Element = g$elements, df)

    datatable(df, options = list(pageLength = 20, scrollX = TRUE, dom = "t"))
  })

  # Use composite grid as current
  observeEvent(input$use_composite_as_current, {
    req(rv$composite_grid)
    g <- rv$composite_grid

    rv$elements <- g$elements
    rv$constructs <- g$constructs[, c("left", "right")]
    rv$ratings <- g$ratings
    rv$scores_mat_last <- g$scores_mat
    rv$repgrid_last <- NULL

    showNotification("Composite grid loaded as current grid", type = "message")
  })

  # Download composite grid
  output$download_composite_grid <- downloadHandler(
    filename = function() paste0("composite-grid-", Sys.Date(), ".rgrid"),
    content = function(file) {
      req(rv$composite_grid)
      g <- rv$composite_grid

      lines <- character()
      # Write constructs
      for (i in seq_len(nrow(g$constructs))) {
        lines <- c(lines, paste0("C", i - 1, "\t", g$constructs$left[i], "\t", g$constructs$right[i]))
      }
      # Write elements with ratings
      for (i in seq_along(g$elements)) {
        scores_str <- paste(round(g$scores_mat[i, ], 1), collapse = "\t")
        lines <- c(lines, paste0("E", i - 1, "\t", g$elements[i], "\t", scores_str))
      }
      # Write metadata
      lines <- c(lines, paste0("_UID\t", g$id))
      lines <- c(lines, paste0("_Date\t", format(Sys.time(), "%Y-%m-%d")))
      lines <- c(lines, paste0("_Time\t", format(Sys.time(), "%H:%M:%S")))

      writeLines(lines, file)
    }
  )

  # ===== NAVIGATION LINKS FOR NEW ANALYSES =====

  observeEvent(input$goto_minus, {
    updateTabsetPanel(session, "main_tabs", selected = "MINUS")
  })

  observeEvent(input$goto_core, {
    updateTabsetPanel(session, "main_tabs", selected = "CORE")
  })

  observeEvent(input$goto_trajectories, {
    updateTabsetPanel(session, "main_tabs", selected = "PrinGrid Trajectories")
  })

  observeEvent(input$goto_exchange, {
    updateTabsetPanel(session, "main_tabs", selected = "Exchange Grids")
  })

  observeEvent(input$goto_metagrids, {
    updateTabsetPanel(session, "main_tabs", selected = "Class Metagrids")
  })

  # ===== FOCI: Interpretive FOCUS =====

  output$foci_response <- renderUI({
    render_chat_response(chat_responses$foci)
  })

  observeEvent(input$run_foci, {
    req(focus_result())
    chat_responses$foci <- list(loading = TRUE, success = FALSE)

    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)
    extra <- generate_focus_interpretation_context(
      focus_result(), rv$elements, construct_labels,
      cutoff = if (!is.null(input$focus_cutoff)) input$focus_cutoff else 80
    )

    question <- "Please provide a comprehensive interpretation of this FOCUS cluster analysis. Identify the main element clusters and construct clusters, explain what they mean in terms of how this person construes these elements, and note any constructs that may be redundant or closely related."

    result <- ask_claude_about_grid("Focus Cluster", question,
                                    generate_grid_summary(), repplus_docs, extra)
    chat_responses$foci <- list(loading = FALSE, success = result$success,
                                 response = result$response, error = result$error)
  })

  observeEvent(input$copy_foci, {
    req(focus_result())

    construct_labels <- paste(rv$constructs$left, "-", rv$constructs$right)
    extra <- generate_focus_interpretation_context(
      focus_result(), rv$elements, construct_labels,
      cutoff = if (!is.null(input$focus_cutoff)) input$focus_cutoff else 80
    )

    question <- "Please provide a comprehensive interpretation of this FOCUS cluster analysis. Identify the main element clusters and construct clusters, explain what they mean, and note any constructs that may be redundant."
    context <- generate_claude_context("Focus Cluster", question,
                                       generate_grid_summary(), extra)
    session$sendCustomMessage("copyToClipboard", context)
  })

  # ===== MINUS ANALYSIS =====

  # Populate grid dropdowns for MINUS
  observe({
    req(nrow(rv$grid_metadata) > 0)
    choices <- setNames(rv$grid_metadata$grid_id, rv$grid_metadata$name)
    updateSelectInput(session, "minus_grid_a", choices = choices)
    updateSelectInput(session, "minus_grid_b", choices = choices)
  })

  observeEvent(input$compute_minus, {
    req(input$minus_grid_a, input$minus_grid_b)
    req(input$minus_grid_a != input$minus_grid_b)

    grid_a <- rv$grid_collection[[input$minus_grid_a]]
    grid_b <- rv$grid_collection[[input$minus_grid_b]]

    # Compute common elements AND constructs
    common_elem <- intersect(grid_a$elements, grid_b$elements)
    labels_a <- paste(grid_a$constructs$left, "-", grid_a$constructs$right)
    labels_b <- paste(grid_b$constructs$left, "-", grid_b$constructs$right)
    common_const <- intersect(labels_a, labels_b)

    if (length(common_elem) < 2) {
      showNotification("Grids need at least 2 common elements", type = "error")
      return()
    }
    if (length(common_const) < 1) {
      showNotification("Grids need at least 1 common construct", type = "error")
      return()
    }

    tryCatch({
      rv$minus_result <- compute_minus_grid(grid_a, grid_b, common_elem, common_const)
      showNotification("MINUS analysis complete", type = "message")
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  output$minus_plot <- renderPlot({
    req(rv$minus_result)
    plot_minus_grid(rv$minus_result,
                    show_values = input$minus_show_values,
                    show_pct = input$minus_show_pct,
                    text_size = input$minus_text_size)
  })

  output$minus_summary <- renderPrint({
    req(rv$minus_result)
    r <- rv$minus_result
    cat("MINUS Analysis:", r$grid_a_name, "-", r$grid_b_name, "\n\n")
    cat("Common elements:", length(r$elements), "\n")
    cat("Common constructs:", length(r$construct_labels), "\n\n")
    cat("Mean absolute difference:", round(r$mean_abs_diff, 2), "\n")
    cat("Maximum absolute difference:", round(r$max_diff, 2), "\n\n")

    # Find location of max difference
    max_idx <- which(abs(r$diff_mat) == r$max_diff, arr.ind = TRUE)[1, ]
    cat("Largest difference at:\n")
    cat("  Element:", r$elements[max_idx[1]], "\n")
    cat("  Construct:", r$construct_labels[max_idx[2]], "\n")
    cat("  Difference:", round(r$diff_mat[max_idx[1], max_idx[2]], 1), "\n")
  })

  output$download_minus_plot <- downloadHandler(
    filename = function() paste0("minus-analysis-", Sys.Date(), ".png"),
    content = function(file) {
      req(rv$minus_result)
      png(file, width = 1000, height = 700, res = 120)
      plot_minus_grid(rv$minus_result,
                      show_values = input$minus_show_values,
                      show_pct = input$minus_show_pct,
                      text_size = input$minus_text_size)
      dev.off()
    }
  )

  output$download_minus_csv <- downloadHandler(
    filename = function() paste0("minus-differences-", Sys.Date(), ".csv"),
    content = function(file) {
      req(rv$minus_result)
      write.csv(rv$minus_result$diff_mat, file)
    }
  )

  # ===== CORE ANALYSIS =====

  # Populate grid dropdowns for CORE
  observe({
    req(nrow(rv$grid_metadata) > 0)
    choices <- setNames(rv$grid_metadata$grid_id, rv$grid_metadata$name)
    updateSelectInput(session, "core_grid_a", choices = choices)
    updateSelectInput(session, "core_grid_b", choices = choices)
  })

  observeEvent(input$compute_core, {
    req(input$core_grid_a, input$core_grid_b)
    req(input$core_grid_a != input$core_grid_b)

    grid_a <- rv$grid_collection[[input$core_grid_a]]
    grid_b <- rv$grid_collection[[input$core_grid_b]]

    common_elem <- intersect(grid_a$elements, grid_b$elements)
    labels_a <- paste(grid_a$constructs$left, "-", grid_a$constructs$right)
    labels_b <- paste(grid_b$constructs$left, "-", grid_b$constructs$right)
    common_const <- intersect(labels_a, labels_b)

    if (length(common_elem) < 2) {
      showNotification("Grids need at least 2 common elements", type = "error")
      return()
    }
    if (length(common_const) < 1) {
      showNotification("Grids need at least 1 common construct", type = "error")
      return()
    }

    tryCatch({
      rv$core_result <- compute_core_analysis(grid_a, grid_b, common_elem, common_const,
                                               min_elements = input$core_min_elements,
                                               min_constructs = input$core_min_constructs)
      showNotification("CORE analysis complete", type = "message")
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  output$core_plot <- renderPlot({
    req(rv$core_result)
    plot_core_analysis(rv$core_result, text_size = input$core_text_size)
  })

  output$core_steps_table <- renderDT({
    req(rv$core_result)
    if (nrow(rv$core_result$steps) == 0) {
      return(datatable(data.frame(Message = "No removals needed - grids already maximally similar"),
                       options = list(dom = "t")))
    }
    datatable(rv$core_result$steps,
              options = list(pageLength = 20, dom = "t", scrollX = TRUE),
              colnames = c("Step", "Type", "Removed", "Similarity Before (%)", "Similarity After (%)"))
  })

  output$core_summary <- renderPrint({
    req(rv$core_result)
    r <- rv$core_result
    cat("CORE Analysis:", r$grid_a_name, "vs", r$grid_b_name, "\n\n")
    cat("Initial similarity:", round(r$initial_similarity, 1), "%\n")
    cat("Core similarity:", round(r$core_similarity, 1), "%\n\n")
    cat("Elements removed:", r$n_elements_removed, "\n")
    cat("Constructs removed:", r$n_constructs_removed, "\n\n")
    cat("Core elements (", length(r$core_elements), "):", paste(r$core_elements, collapse = ", "), "\n")
    cat("Core constructs (", length(r$core_constructs), "):", paste(r$core_constructs, collapse = ", "), "\n")
  })

  # Load core grid into editor and switch to Focus
  observeEvent(input$core_to_focus, {
    req(rv$core_result)
    r <- rv$core_result

    # Build grid from core (average of A and B)
    core_avg <- (r$core_mat_a + r$core_mat_b) / 2
    constructs_df <- data.frame(
      left = sapply(strsplit(r$core_constructs, " - "), `[`, 1),
      right = sapply(strsplit(r$core_constructs, " - "), function(x) if (length(x) > 1) x[2] else ""),
      stringsAsFactors = FALSE
    )

    rv$elements <- r$core_elements
    rv$constructs <- constructs_df
    rv$scores_mat_last <- core_avg
    rv$repgrid_last <- NULL

    # Build ratings data frame
    construct_labels <- paste(constructs_df$left, "-", constructs_df$right)
    ratings_list <- list()
    for (i in seq_along(r$core_elements)) {
      for (j in seq_along(construct_labels)) {
        ratings_list[[length(ratings_list) + 1]] <- data.frame(
          element = r$core_elements[i],
          construct = construct_labels[j],
          rating = round(core_avg[i, j], 1),
          stringsAsFactors = FALSE
        )
      }
    }
    rv$ratings <- do.call(rbind, ratings_list)

    showNotification("Core grid loaded - running Focus analysis", type = "message")
    updateTabsetPanel(session, "main_tabs", selected = "Focus Cluster")
  })

  output$download_core_plot <- downloadHandler(
    filename = function() paste0("core-analysis-", Sys.Date(), ".png"),
    content = function(file) {
      req(rv$core_result)
      png(file, width = 1200, height = 700, res = 120)
      plot_core_analysis(rv$core_result, text_size = input$core_text_size)
      dev.off()
    }
  )

  output$download_core_csv <- downloadHandler(
    filename = function() paste0("core-removal-log-", Sys.Date(), ".csv"),
    content = function(file) {
      req(rv$core_result)
      write.csv(rv$core_result$steps, file, row.names = FALSE)
    }
  )

  # ===== PRINGRID TRAJECTORIES =====

  observeEvent(input$compute_trajectories, {
    req(length(rv$selected_grids) >= 2)
    req(length(rv$common_elements) >= 2)

    selected_grids <- rv$grid_collection[rv$selected_grids]
    names(selected_grids) <- sapply(selected_grids, function(g) g$name)

    tryCatch({
      rv$traj_result <- compute_pringrid_trajectories(selected_grids, rv$common_elements)
      showNotification("Trajectories computed", type = "message")
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  output$pringrid_traj_plot <- renderPlot({
    req(rv$traj_result)
    plot_pringrid_trajectories(rv$traj_result,
      show_arrows = input$traj_show_arrows,
      show_labels = input$traj_show_labels,
      show_constructs = input$traj_show_constructs,
      text_size = input$traj_text_size)
  })

  output$traj_variance <- renderPrint({
    req(rv$traj_result)
    cat("Variance explained by principal components:\n")
    ve <- rv$traj_result$variance_explained
    for (i in seq_along(ve)) {
      cat(sprintf("  PC%d: %.1f%%\n", i, ve[i]))
    }
    cat(sprintf("\nTotal (PC1+PC2): %.1f%%\n", sum(ve[1:min(2, length(ve))])))
  })

  output$download_traj_plot <- downloadHandler(
    filename = function() paste0("pringrid-trajectories-", Sys.Date(), ".png"),
    content = function(file) {
      req(rv$traj_result)
      png(file, width = 1200, height = 900, res = 120)
      plot_pringrid_trajectories(rv$traj_result,
        show_arrows = input$traj_show_arrows,
        show_labels = input$traj_show_labels,
        show_constructs = input$traj_show_constructs,
        text_size = input$traj_text_size)
      dev.off()
    }
  )

  output$download_traj_csv <- downloadHandler(
    filename = function() paste0("pringrid-positions-", Sys.Date(), ".csv"),
    content = function(file) {
      req(rv$traj_result)
      all_positions <- do.call(rbind, rv$traj_result$element_positions)
      write.csv(all_positions, file, row.names = FALSE)
    }
  )

  # ===== EXCHANGE GRIDS =====

  # Populate exchange grid dropdowns
  observe({
    req(nrow(rv$grid_metadata) > 0)
    choices <- setNames(rv$grid_metadata$grid_id, rv$grid_metadata$name)
    updateSelectInput(session, "exchange_1", choices = choices)
    updateSelectInput(session, "exchange_2", choices = choices)
    updateSelectInput(session, "exchange_3", choices = choices)
    updateSelectInput(session, "exchange_4", choices = choices)
    updateSelectInput(session, "exchange_5", choices = choices)
    updateSelectInput(session, "exchange_6", choices = choices)
  })

  observeEvent(input$compute_exchange, {
    req(input$exchange_1, input$exchange_2, input$exchange_3,
        input$exchange_4, input$exchange_5, input$exchange_6)

    # Collect the 6 grids in protocol order
    grid_ids <- c(input$exchange_1, input$exchange_2, input$exchange_3,
                  input$exchange_4, input$exchange_5, input$exchange_6)

    grids <- lapply(grid_ids, function(id) rv$grid_collection[[id]])

    tryCatch({
      rv$exchange_result <- compute_exchange_analysis(grids)
      showNotification("Exchange analysis complete", type = "message")
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  output$exchange_plot <- renderPlot({
    req(rv$exchange_result)
    s <- rv$exchange_result$summary

    par(mar = c(8, 5, 4, 2), family = "sans")

    # Bar chart: initial vs core similarity for each pair
    bar_data <- rbind(s$Initial, s$Core)
    colnames(bar_data) <- s$Pair

    barplot(bar_data, beside = TRUE, col = c("#0072B2", "#D55E00"),
            main = "Exchange Grid Analysis: Agreement & Understanding",
            ylab = "Similarity (%)", ylim = c(0, 100),
            las = 2, cex.names = 0.8, cex.main = 1.2)

    legend("topright", legend = c("Initial", "Core"),
           fill = c("#0072B2", "#D55E00"), cex = 0.9)

    abline(h = 50, lty = 2, col = "gray60")
  })

  output$exchange_results_table <- renderDT({
    req(rv$exchange_result)
    s <- rv$exchange_result$summary
    s$Initial <- round(s$Initial, 1)
    s$Core <- round(s$Core, 1)
    datatable(s, options = list(dom = "t", scrollX = TRUE),
              colnames = c("Pair", "Description", "Initial Similarity (%)", "Core Similarity (%)"))
  })

  output$exchange_summary <- renderPrint({
    req(rv$exchange_result)
    s <- rv$exchange_result$summary
    cat("Exchange Grid Analysis Summary\n")
    cat("==============================\n\n")
    cat("Agreement:\n")
    cat(sprintf("  A's construing: %.1f%% -> %.1f%% (core)\n", s$Initial[1], s$Core[1]))
    cat(sprintf("  B's construing: %.1f%% -> %.1f%% (core)\n", s$Initial[2], s$Core[2]))
    cat("\nUnderstanding:\n")
    cat(sprintf("  B understands A: %.1f%% -> %.1f%% (core)\n", s$Initial[3], s$Core[3]))
    cat(sprintf("  A understands B: %.1f%% -> %.1f%% (core)\n", s$Initial[4], s$Core[4]))
  })

  output$download_exchange_plot <- downloadHandler(
    filename = function() paste0("exchange-analysis-", Sys.Date(), ".png"),
    content = function(file) {
      req(rv$exchange_result)
      s <- rv$exchange_result$summary
      png(file, width = 1000, height = 600, res = 120)
      par(mar = c(8, 5, 4, 2), family = "sans")
      bar_data <- rbind(s$Initial, s$Core)
      colnames(bar_data) <- s$Pair
      barplot(bar_data, beside = TRUE, col = c("#0072B2", "#D55E00"),
              main = "Exchange Grid Analysis: Agreement & Understanding",
              ylab = "Similarity (%)", ylim = c(0, 100),
              las = 2, cex.names = 0.8, cex.main = 1.2)
      legend("topright", legend = c("Initial", "Core"),
             fill = c("#0072B2", "#D55E00"), cex = 0.9)
      dev.off()
    }
  )

  output$download_exchange_csv <- downloadHandler(
    filename = function() paste0("exchange-results-", Sys.Date(), ".csv"),
    content = function(file) {
      req(rv$exchange_result)
      write.csv(rv$exchange_result$summary, file, row.names = FALSE)
    }
  )

  # ===== CLASS METAGRIDS =====

  output$metagrid_grids_table <- renderDT({
    req(nrow(rv$grid_metadata) > 0)
    df <- rv$grid_metadata[, c("name", "n_elements", "n_constructs")]
    colnames(df) <- c("Grid Name", "Elements", "Constructs")
    datatable(df, options = list(pageLength = 20, dom = "t"), selection = "none")
  })

  observeEvent(input$add_meta_construct, {
    req(input$meta_left_pole != "", input$meta_right_pole != "")
    rv$meta_constructs <- rbind(rv$meta_constructs, data.frame(
      left = trimws(input$meta_left_pole),
      right = trimws(input$meta_right_pole),
      stringsAsFactors = FALSE
    ))
    updateTextInput(session, "meta_left_pole", value = "")
    updateTextInput(session, "meta_right_pole", value = "")
  })

  output$meta_constructs_table <- renderDT({
    req(nrow(rv$meta_constructs) > 0)
    datatable(rv$meta_constructs,
              colnames = c("Left Pole", "Right Pole"),
              options = list(dom = "t"), selection = "none")
  })

  # Dynamic rating UI: sliders for each grid x construct
  output$meta_ratings_ui <- renderUI({
    req(nrow(rv$grid_metadata) > 0, nrow(rv$meta_constructs) > 0)
    grid_names <- rv$grid_metadata$name
    construct_labels <- paste(rv$meta_constructs$left, "-", rv$meta_constructs$right)

    tagList(
      lapply(seq_along(construct_labels), function(j) {
        tagList(
          h5(construct_labels[j]),
          lapply(seq_along(grid_names), function(i) {
            input_id <- paste0("meta_rate_", i, "_", j)
            sliderInput(input_id, grid_names[i],
                        min = 1, max = 7, value = 4, step = 1)
          })
        )
      })
    )
  })

  observeEvent(input$build_metagrid, {
    req(nrow(rv$grid_metadata) > 0, nrow(rv$meta_constructs) > 0)

    grid_names <- rv$grid_metadata$name
    construct_labels <- paste(rv$meta_constructs$left, "-", rv$meta_constructs$right)

    # Collect ratings from dynamic inputs
    scores_mat <- matrix(NA_real_, nrow = length(grid_names), ncol = length(construct_labels))

    for (i in seq_along(grid_names)) {
      for (j in seq_along(construct_labels)) {
        input_id <- paste0("meta_rate_", i, "_", j)
        val <- input[[input_id]]
        if (!is.null(val)) scores_mat[i, j] <- val
      }
    }

    tryCatch({
      rv$metagrid <- create_metagrid(grid_names, rv$meta_constructs, scores_mat)
      showNotification("Metagrid built", type = "message")
    }, error = function(e) {
      showNotification(paste("Error:", e$message), type = "error")
    })
  })

  output$metagrid_preview <- renderDT({
    req(rv$metagrid)
    df <- as.data.frame(rv$metagrid$scores_mat)
    df <- cbind(Grid = rv$metagrid$elements, df)
    datatable(df, options = list(dom = "t", scrollX = TRUE))
  })

  # Load metagrid as current grid for full analysis
  observeEvent(input$use_metagrid_as_current, {
    req(rv$metagrid)
    g <- rv$metagrid
    rv$elements <- g$elements
    rv$constructs <- g$constructs[, c("left", "right")]
    rv$ratings <- g$ratings
    rv$scores_mat_last <- g$scores_mat
    rv$repgrid_last <- NULL
    showNotification("Metagrid loaded as current grid - use analysis tabs to explore", type = "message")
    updateTabsetPanel(session, "main_tabs", selected = "Focus Cluster")
  })

  output$download_metagrid <- downloadHandler(
    filename = function() paste0("class-metagrid-", Sys.Date(), ".rgrid"),
    content = function(file) {
      req(rv$metagrid)
      g <- rv$metagrid

      lines <- character()
      for (i in seq_len(nrow(g$constructs))) {
        lines <- c(lines, paste0("C", i - 1, "\t", g$constructs$left[i], "\t", g$constructs$right[i]))
      }
      for (i in seq_along(g$elements)) {
        scores_str <- paste(round(g$scores_mat[i, ], 1), collapse = "\t")
        lines <- c(lines, paste0("E", i - 1, "\t", g$elements[i], "\t", scores_str))
      }
      lines <- c(lines, paste0("_UID\t", g$id))
      lines <- c(lines, paste0("_Date\t", format(Sys.time(), "%Y-%m-%d")))
      lines <- c(lines, paste0("_Time\t", format(Sys.time(), "%H:%M:%S")))

      writeLines(lines, file)
    }
  )
}

shinyApp(ui, server)
