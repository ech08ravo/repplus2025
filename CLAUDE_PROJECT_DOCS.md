# WebGrid.Online - Claude Project Documentation

## Deployment (Primary: DreamCompute)

- **Live URL**: https://webgrid.online
- **Server**: 208.113.135.63 (DreamCompute Ubuntu 24.04, 8GB RAM)
- **SSH**: `ssh ubuntu@208.113.135.63` (key: `~/.ssh/council_api_rsa`)
- **Stack**: Docker (rocker/shiny) + nginx reverse proxy + Let's Encrypt SSL
- **SSL cert**: Auto-renewing, expires Apr 28 2026
- **Repo on server**: `/home/ubuntu/repplus2025`
- **Nginx config**: `/home/ubuntu/nginx/webgrid.conf`
- **Redeploy command**:
  ```bash
  ssh ubuntu@208.113.135.63 "cd /home/ubuntu/repplus2025 && git pull && sudo docker build -t webgrid-online . && sudo docker rm -f webgrid && sudo docker run -d --name webgrid --restart unless-stopped -p 3838:3838 webgrid-online"
  ```

### Backup: shinyapps.io (inactive)

- **Account**: ech08ravo
- **App URL**: https://ech08ravo.shinyapps.io/repplus2025/
- **Deploy command**: `rsconnect::deployApp(appName = "repplus2025")`

## Overview

WebGrid.Online (formerly RepPlusApp) is a Shiny application for Repertory Grid analysis, a psychological research method developed by George Kelly. The app allows users to elicit personal constructs through triadic comparison of elements, rate elements on bipolar construct scales, and analyze the resulting grid using various statistical and visual methods.

**Key Features**:
- Single grid elicitation and analysis (10 tabs)
- Multi-grid analysis with Shaw's SOCIOGRIDS methodology (9 tabs)
- Socionets, Mode Grid, Composite Grid, MINUS, CORE, PrinGrid Trajectories, Exchange Grids, and Metagrid visualizations
- Claude AI integration for interpretation assistance

## Project Structure

```
RepPlusApp/
├── app.R                        # Main Shiny application (~5000 lines, UI + Server)
├── R/
│   ├── focus_analysis.r         # Focus clustering algorithm (Shaw 1980)
│   ├── multigrid_analysis.r     # Multi-grid analysis (SOCIOGRIDS)
│   ├── claude_api.R             # Claude API integration for chat features
│   └── triadic_elicitation.r    # Triadic elicitation helper functions
├── dataExamples/                # Sample grid data files
├── RepPlusDocs/                 # Documentation directory
├── CLAUDE_PROJECT_DOCS.md       # This documentation
├── Dockerfile                   # Docker deployment config
├── docker-compose.yml           # Docker compose config
├── deploy.sh                    # Deployment script
├── renv/                        # R environment management
└── rsconnect/                   # Shiny deployment config
```

## Key Concepts

### Repertory Grid Components
- **Elements**: The items being compared (e.g., people, concepts, products)
- **Constructs**: Bipolar dimensions (left pole vs right pole) that differentiate elements
- **Ratings**: Scores (1-7) indicating where each element falls on each construct

### Triadic Elicitation
The app uses triadic elicitation to help users generate constructs:
1. Three elements are presented at a time
2. User selects which two are SIMILAR and which one is DIFFERENT
3. User describes WHY they're similar (left pole) and different (right pole)
4. This creates a bipolar construct

## Application Architecture

### UI Structure (app.R)

The UI uses `fluidPage` with a sidebar layout:

**Sidebar (width=2)**:
- File import (.rgrid, .json)
- Sample data loader
- Analysis button
- Impute missing checkbox
- Display options (text size, cell size)
- Export buttons (CSV, .rgrid)

**Main Panel (width=10)** - Tabset with:

*Single-Grid Tabs:*
1. **Build Grid** - Element entry, triadic elicitation, construct management
2. **Grid Summary** - Elements list, analysis summary, missing ratings
3. **Biplot** - PCA visualization with element points and construct arrows
4. **Crossplot** - 2D scatter plot on two selected constructs
5. **Synopsis** - Grid overview visualization
6. **Heatmap** - Color-coded rating matrix with dendrograms
7. **Element Dendrogram** - Hierarchical clustering of elements
8. **Construct Dendrogram** - Hierarchical clustering of constructs
9. **Focus Cluster** - Shaw's FOCUS algorithm with dendrograms
10. **Statistics** - Detailed element and construct statistics

*Multi-Grid Tabs (styled with gradient CSS icons):*
1. **Grid Collection** - Import, manage, and organize grid collection
2. **Socionets** - Network visualization of grid relationships
3. **Mode Grid** - Consensus grid (average/median ratings)
4. **Composite Grid** - Merged grid combining elements/constructs
5. **MINUS** - Grid difference analysis (comparing two grids)
6. **CORE** - Shared construing analysis (iterative comparison)
7. **PrinGrid Trajectories** - PCA trajectory visualization over time/sequence
8. **Exchange Grids** - 6-grid exchange protocol analysis
9. **Class Metagrids** - Metagrid classification across multiple grids

### Server Components (app.R)

**Reactive Values (rv)**:
```r
rv <- reactiveValues(
  # Single-grid data
  elements = character(),           # Vector of element names
  constructs = data.frame(          # Constructs with left/right poles
    left = character(),
    right = character()
  ),
  ratings = data.frame(             # All ratings
    element = character(),
    construct = character(),
    rating = numeric()
  ),
  scores_mat_last = NULL,           # Matrix form of ratings (elements x constructs)
  repgrid_last = NULL,              # OpenRepGrid object
  imputed_last = FALSE,             # Whether imputation was used
  elicitation_active = FALSE,       # Triadic elicitation in progress
  show_constructs = FALSE,          # UI state for construct display
  manual_mode = FALSE,              # Manual construct entry mode

  # Triadic elicitation tracking
  all_triads = list(),              # All unique triads for elicitation
  current_triad_idx = 0,            # Current triad being shown
  triad_similar = character(),      # Selected similar elements
  triad_different = NULL,           # Selected different element

  # Multi-grid storage
  grid_collection = list(),         # Named list of grids by UUID
  grid_metadata = data.frame(),     # Grid metadata (id, name, n_elements, n_constructs, scale)
  selected_grids = character(),     # Vector of selected grid_ids
  common_elements = character(),    # Elements shared across selected grids
  common_constructs = character(),  # Construct labels shared across grids

  # Multi-grid analysis results
  match_matrix = NULL,              # Grid-to-grid similarity matrix
  socionet_data = NULL,             # Network graph data
  mode_grid = NULL,                 # Consensus grid result
  composite_grid = NULL,            # Merged grid result
  minus_result = NULL,              # MINUS grid difference result
  core_result = NULL,               # CORE shared construing result
  traj_result = NULL,               # PrinGrid trajectory result
  exchange_result = NULL,           # Exchange analysis result
  metagrid = NULL,                  # Metagrid result
  meta_constructs = data.frame()    # Metagrid construct definitions
)
```

**Other Reactive Values**:
- `landing` - Landing page state: `step = "elements"` | `"triads"` | `"rating"` | `"done"`
- `chat_responses` - Chat response storage with keys per tab (biplot, crossplot, synopsis, etc.)

**Key Functions**:
- `get_palette_colors(palette)` - Returns color list for a named palette
- `get_colors()` - Reactive wrapper using global palette
- `focus_result()` - Reactive value storing Focus analysis results

### Color Palettes

Each visualization has its own palette selector. Available palettes:
- **wong** (Accessible): Blue (#0072B2) / Orange (#D55E00)
- **classic**: Blue (#2166AC) / Red (#B2182B)
- **earth**: Wheat (#F5DEB3) / Brown (#8B4513)
- **contrast**: White (#FFFFFF) / Black (#000000)

Palette structure:
```r
list(
  element = "#...",      # Color for element points/labels
  construct = "#...",    # Color for construct arrows/labels
  highlight = "#...",    # Accent color
  accent = "#...",       # Secondary accent
  heat_low = "#...",     # Low end of heatmap gradient
  heat_high = "#..."     # High end of heatmap gradient
)
```

## Focus Analysis (R/focus_analysis.r)

Implements Shaw's (1980) FOCUS algorithm for clustering and sorting repertory grids.

### Functions

**`compute_element_similarities(scores_matrix, power = 1.0)`**
- Computes element-element similarity matrix
- Uses Minkowski distance (power=1 for Manhattan, power=2 for Euclidean)
- Returns 0-100% similarity scores

**`compute_construct_similarities(scores_matrix, power = 1.0)`**
- Computes construct-construct similarity matrix
- Considers both normal and reversed constructs (takes better match)
- Returns 0-100% similarity scores

**`focus_cluster(scores_matrix, element_names, construct_names, power = 1.0)`**
- Performs hierarchical clustering on both elements and constructs
- Returns sorted matrix and clustering results:
  - `sorted_matrix`, `sorted_elements`, `sorted_constructs`
  - `element_hclust`, `construct_hclust`
  - `element_similarities`, `construct_similarities`
  - `element_order`, `construct_order`

**`plot_focus_cluster(focus_result, ...)`**
- Creates 4-panel plot: top dendrogram, left dendrogram, main grid, stats panel
- Adaptive margins calculated before layout to ensure dendrogram alignment
- Parameters:
  - `show_values`: Display rating numbers in cells
  - `show_shading`: Use color/grey shading
  - `use_color`: Use color palette (vs greyscale)
  - `text_size`, `cell_size`: Scaling factors
  - `heat_low`, `heat_high`: Gradient colors

**`plot_focus_spaced(focus_result, ...)`**
- SPACED variant of Focus cluster plot
- Uses proportional spacing based on cophenetic distances between clusters
- Same parameters as `plot_focus_cluster`

## Triadic Elicitation (R/triadic_elicitation.r)

Helper functions for the triadic elicitation process.

### Functions

- **`generate_triads(elements)`** - Generate all unique triadic combinations
- **`get_next_triad(triads, current_idx)`** - Get next uncompleted triad
- **`get_elicitation_progress(current_idx, total)`** - Calculate progress percentage
- **`validate_construct(left, right)`** - Validate left/right pole input
- **`all_elements_rated(ratings, construct, elements)`** - Check if construct is fully rated

## Claude API Integration (R/claude_api.R)

Handles Claude AI chat features across visualization tabs.

### Functions

- **`load_repplus_docs()`** - Load RepPlus documentation for context
- **`get_relevant_docs(viz_type)`** - Get docs relevant to visualization type
- **`has_api_key()`** - Check if Claude API key is configured
- **`generate_claude_context(grid, viz_type)`** - Generate context for API calls
- **`call_claude_api(prompt, context)`** - Make API calls to Claude
- **`ask_claude_about_grid(question, grid, viz_type)`** - Ask Claude questions about grid analysis
- **`generate_focus_interpretation_context(focus_result)`** - Generate context for Focus interpretation

## File Formats

### .rgrid Format
Plain text format for saving/loading grids:
```
ELEMENTS
element1
element2
...
CONSTRUCTS
left_pole1 | right_pole1
left_pole2 | right_pole2
...
RATINGS
element1 | construct_label | rating
...
```

### JSON Format
Standard JSON with arrays:
```json
{
  "elements": ["element1", "element2", ...],
  "constructs": [
    {"left": "pole1", "right": "pole2"},
    ...
  ],
  "ratings": [
    {"element": "element1", "construct": "pole1 - pole2", "rating": 5},
    ...
  ]
}
```

## Visualization Details

### Biplot (PCA)
- Uses `prcomp()` with scaling
- Elements plotted as colored points
- Constructs as arrows from origin (labeled with RIGHT pole - high rating direction)
- Palette: `biplot_palette`

### Heatmap
- Elements as rows, constructs as columns
- Color gradient from `heat_low` through white to `heat_high`
- Rating values displayed in cells
- Palette: `heatmap_palette`, toggle: `heatmap_use_color`

### Crossplot
- Scatter plot of elements on two selected constructs
- **Overlap handling**: Elements within 0.3 units get:
  - Decreasing opacity (100%, 85%, 70%, 55%, 40% min)
  - Labels positioned in different directions (above, right, below, left)
- Grid lines at integer values, midpoint (4) highlighted
- Palette: `crossplot_palette`

### Dendrograms
- Hierarchical clustering using `hclust()` with complete linkage
- Distance matrix from Euclidean distance
- Elements dendrogram: rows of rating matrix
- Constructs dendrogram: columns of rating matrix

### Focus Cluster
- Combined view with dendrograms aligned to sorted grid
- Constructs dendrogram at top, elements dendrogram at left
- Main grid shows sorted ratings with optional shading
- Right panel shows top element matches
- Adaptive margins ensure proper dendrogram-to-grid alignment
- Palette: `focus_palette`, toggle: `focus_use_color`

## Preset Grid System

Pre-configured element sets can be loaded via the wizard landing page.

### Preset Files
Stored as JSON in `dataExamples/presets/`:
```json
{
  "name": "Careers Study",
  "elements": ["Scientist", "Sociologist", "Doctor", "Librarian", "Artist"]
}
```

### Preset Picker
- "Use an Existing Grid" button on the landing page
- Shows cards for each preset in `dataExamples/presets/`
- Selecting a preset loads elements and starts triadic elicitation

### Adding a New Preset
1. Create a JSON file in `dataExamples/presets/` with `name` and `elements` array
2. The preset will automatically appear in the picker

## Wizard Flow (Simple Interface)

The app has a guided wizard for new users and student exercises:

1. **Landing Page** — Enter 5 elements manually OR pick a preset grid
2. **Triadic Elicitation** — Triads of 3 elements presented; pick 2 similar, 1 different; enter bipolar construct poles. Progress bar shows completion.
3. **Constructs Summary** — Numbered table of generated constructs (red = Pole 1, blue = Pole 2). Preview biplot not shown here. **"Email My Constructs"** mailto button.
4. **Rating** (one construct at a time) — 1-5 linear scale with circular buttons per element. Construct poles shown in color at top. Back/Next navigation between constructs.
5. **Post-Rating Summary** — Preview biplot visualisation. **"Email My Chart"** mailto button + **"Download Chart"** PNG download. Instruction to explore other visualisations.
6. **Full App** — Auto-triggers analysis with imputation enabled. All visualisation tabs available.

### Email Touchpoints
- After constructs: "Email My Constructs" (elements + construct list)
- After ratings: "Email My Chart" (elements + all ratings)
- In full app: per-visualisation email (planned)

## Analysis Flow (Full App)

1. **Enter Elements** (Build Grid tab)
   - Manual entry or paste multiple
   - Sample data available (fruits with icons)

2. **Generate Constructs** (Triadic Elicitation)
   - Click "Begin Elicitation"
   - All unique triads presented systematically
   - Select 2 similar, 1 different
   - Enter construct poles
   - Rate elements on 1-5 scale

3. **Run Analysis** (Analyze button)
   - Validates minimum 2 elements, 2 constructs
   - Creates score matrix
   - Optional: impute missing ratings with midpoint
   - Generates all visualizations

4. **Explore Results** (Analysis tabs)
   - Each tab shows different perspective on the data
   - Help buttons explain each visualization
   - Chat buttons for Claude AI interpretation

## Claude AI Integration

Each visualization tab includes:
- **Help button**: Static explanation of the visualization
- **Chat button**: Expandable panel with:
  - Text input for questions
  - "Ask Claude (API)" - Direct API call (requires key)
  - "Copy to Clipboard" - Copy context for manual paste
  - Link to Claude.ai

Context generation includes:
- Current grid summary (elements, constructs, ratings)
- Visualization-specific parameters
- RepPlus documentation excerpt

## Dependencies

```r
library(shiny)           # Web application framework
library(OpenRepGrid)     # For makeRepgrid(), statsElements(), statsConstructs()
library(DT)              # Interactive data tables
library(uuid)            # UUID generation for grid IDs
library(jsonlite)        # JSON serialization
library(igraph)          # Network graph analysis and visualization (socionets)
```

## Common Patterns

### Adding a New Visualization Tab

1. Add UI tab in `tabsetPanel`:
```r
tabPanel("NewViz",
  fluidRow(
    column(4, selectInput("newviz_palette", "Color Palette", ...))
  ),
  plotOutput("newviz_plot"),
  actionButton("help_newviz", "Help..."),
  actionButton("chat_newviz", "Chat...")
)
```

2. Add server renderPlot:
```r
output$newviz_plot <- renderPlot({
  req(rv$scores_mat_last)
  colors <- get_palette_colors(input$newviz_palette)
  # ... plotting code
})
```

### Multi-Grid Tab Layout Pattern
Multi-grid tabs use an 8/4 column split:
```r
fluidRow(
  column(8, plotOutput("viz_plot")),    # Plot left (66.67%)
  column(4, # Controls right (33.33%)
    selectInput(...),
    actionButton(...)
  )
)
```

### Reactive Plot Updates
Plots defined outside `observeEvent(input$analyze, ...)` will automatically update when:
- Data changes (`rv$scores_mat_last`)
- Palette changes (`input$*_palette`)
- Display settings change (`input$text_size`, etc.)

## Multi-Grid Analysis (R/multigrid_analysis.r)

Implements Shaw's (1980) SOCIOGRIDS methodology for comparing multiple repertory grids.
All multi-grid operations normalize to c(1,7) scale before comparison.

### Key Functions

**Grid Comparison:**
- `normalize_scale(ratings, from_min, from_max)` - Normalize ratings between scales
- `compute_grid_match(grid1, grid2)` - Calculate match percentage between two grids
- `compute_directional_match(grid1, grid2)` - Compute directional match scores
- `compute_match_matrix(grids)` - Pairwise grid similarity using Minkowski distance
- `find_similar_constructs(grid1, grid2)` - Find matching constructs across grids

**Grid Synthesis:**
- `generate_mode_grid(grids)` - Creates consensus grid from multiple grids
- `generate_composite_grid(grids)` - Merges grids by elements or constructs

**Network Visualization:**
- `prepare_socionet_data(match_matrix)` - Prepares network data for visualization
- `plot_socionets(socionet_data)` - Network graph showing grid relationships

**Advanced Multi-Grid:**
- `compute_minus_grid(grid1, grid2)` - Grid difference analysis
- `plot_minus_grid(minus_result)` - Plot MINUS heatmap with dendrograms
- `compute_core_analysis(grids)` - Shared construing analysis (iterative)
- `plot_core_analysis(core_result)` - Plot CORE visualization
- `compute_pringrid_trajectories(grids)` - PCA trajectories over sequence
- `plot_pringrid_trajectories(traj_result)` - Plot trajectory visualization
- `compute_exchange_analysis(grids)` - 6-grid exchange protocol analysis
- `create_metagrid(grids, meta_constructs)` - Create metagrid from collection

## Known Issues / Future Enhancements

- Focus cluster dendrograms generate harmless `horiz` warnings (cosmetic only)
- Consider adding: export to PDF, more clustering methods, statistical tests
- Grid completion tracking could be more prominent

## References

- Kelly, G.A. (1955). The Psychology of Personal Constructs
- Shaw, M.L.G. (1980). On Becoming a Personal Scientist
- Shaw, M.L.G. (1980). SOCIOGRIDS methodology for multi-grid comparison
- OpenRepGrid R package documentation
