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
- Single grid elicitation and analysis
- Multi-grid analysis (Shaw's SOCIOGRIDS methodology)
- Socionets, Mode Grid, and Composite Grid visualizations

## Project Structure

```
RepPlusApp/
├── app.R                    # Main Shiny application (UI + Server)
├── R/
│   ├── focus_analysis.r     # Focus clustering algorithm (Shaw 1980)
│   └── multigrid_analysis.r # Multi-grid analysis (SOCIOGRIDS)
├── CLAUDE_PROJECT_DOCS.md   # This documentation
├── Dockerfile               # Docker deployment config
└── .gitignore
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

**Sidebar (width=3)**:
- File import (.rgrid, .json)
- Sample data loader
- Analysis button
- Impute missing checkbox
- Display options (text size, cell size)
- Export buttons (CSV, .rgrid)

**Main Panel (width=9)** - Tabset with:
1. **Build Grid** - Element entry, triadic elicitation, construct management
2. **Analyze** - Grid summary, elements list, constructs list, missing ratings
3. **Biplot** - PCA visualization with element points and construct arrows
4. **Heatmap** - Color-coded rating matrix
5. **Element Dendrogram** - Hierarchical clustering of elements
6. **Construct Dendrogram** - Hierarchical clustering of constructs
7. **Crossplot** - 2D scatter plot on two selected constructs
8. **Synopsis** - Grid overview visualization
9. **Focus Cluster** - Shaw's FOCUS algorithm with dendrograms
10. **Statistics** - Detailed element and construct statistics

### Server Components (app.R)

**Reactive Values (rv)**:
```r
rv <- reactiveValues(
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
  all_triads = list(),              # All unique triads for elicitation
  current_triad_idx = 0,            # Current triad being shown
  triad_similar = character(),      # Selected similar elements
  triad_different = NULL            # Selected different element
)
```

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
- Parameters:
  - `show_values`: Display rating numbers in cells
  - `show_shading`: Use color/grey shading
  - `use_color`: Use color palette (vs greyscale)
  - `text_size`, `cell_size`: Scaling factors
  - `heat_low`, `heat_high`: Gradient colors

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
- Palette: `focus_palette`, toggle: `focus_use_color`

## Analysis Flow

1. **Enter Elements** (Build Grid tab)
   - Manual entry or paste multiple
   - Sample data available (fruits with icons)

2. **Generate Constructs** (Triadic Elicitation)
   - Click "Begin Elicitation"
   - All unique triads presented systematically
   - Select 2 similar, 1 different
   - Enter construct poles
   - Rate elements on 1-7 scale

3. **Run Analysis** (Analyze button)
   - Validates minimum 2 elements, 2 constructs
   - Creates score matrix
   - Optional: impute missing ratings with midpoint (4)
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
library(shiny)
library(OpenRepGrid)   # For makeRepgrid(), statsElements(), statsConstructs()
library(jsonlite)      # For JSON import/export
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

### Reactive Plot Updates
Plots defined outside `observeEvent(input$analyze, ...)` will automatically update when:
- Data changes (`rv$scores_mat_last`)
- Palette changes (`input$*_palette`)
- Display settings change (`input$text_size`, etc.)

## Known Issues / Future Enhancements

- **Focus cluster dendrogram alignment** - The dendrograms are currently out of alignment with the main grid; needs fixing
- Focus cluster dendrograms generate harmless `horiz` warnings (cosmetic only)
- Consider adding: export to PDF, more clustering methods, statistical tests
- Grid completion tracking could be more prominent

## Multi-Grid Analysis (R/multigrid_analysis.r)

Implements Shaw's (1980) SOCIOGRIDS methodology for comparing multiple repertory grids.

### Key Functions

- `compute_match_matrix()` - Pairwise grid similarity using Minkowski distance
- `prepare_socionet_data()` - Prepares network data for visualization
- `plot_socionets()` - Network graph showing grid relationships
- `generate_mode_grid()` - Creates consensus grid from multiple grids
- `generate_composite_grid()` - Merges grids by elements or constructs

### Multi-Grid Tabs

- **Grid Collection** - Upload and manage multiple .rgrid files
- **Socionets** - Network visualization of grid similarities
- **Mode Grid** - Consensus/average grid heatmap
- **Composite Grid** - Merged grid combining all constructs/elements

## References

- Kelly, G.A. (1955). The Psychology of Personal Constructs
- Shaw, M.L.G. (1980). On Becoming a Personal Scientist
- Shaw, M.L.G. (1980). SOCIOGRIDS methodology for multi-grid comparison
- OpenRepGrid R package documentation
