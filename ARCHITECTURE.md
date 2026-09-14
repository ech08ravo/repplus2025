# WebGrid.Online - Architecture Guide

A comprehensive developer guide to WebGrid.Online v2.4.0 architecture, data structures, algorithms, and integration points.

## Quick Overview

**WebGrid.Online** is a Shiny web application for Repertory Grid analysis (Personal Construct Theory). Users elicit constructs through triadic comparison, rate elements on bipolar scales, and analyze grids using PCA, clustering, and AI-assisted interpretation.

- **Frontend**: Shiny UI (R + JavaScript)
- **Backend**: R with OpenRepGrid, igraph, httr2 libraries
- **AI**: Claude Sonnet 4 API (optional)
- **Deployment**: Docker + Shiny Server + Nginx + Let's Encrypt
- **Live**: https://webgrid.online

---

## Code Organization

```
WebGrid.Online/
├── app.R                           # 6627 lines: UI + Server (monolithic Shiny app)
├── R/
│   ├── rgrid_io.R                  # 130 lines: .rgrid parsing (Rep IV / Rep Plus V1.1 / V2.0)
│   ├── focus_analysis.r            # 607 lines: Shaw FOCUS algorithm + plotting
│   ├── multigrid_analysis.r        # 1337 lines: Multi-grid analyses (SOCIOGRIDS)
│   ├── claude_api.R                # 261 lines: Claude API integration
│   ├── triadic_elicitation.r       # 105 lines: Triadic helpers
│   └── score_matrix_helper.r       # 17 lines: Utility functions
├── dataExamples/
│   ├── *.rgrid                     # Sample grid files
│   ├── presets/                    # JSON preset element sets
│   ├── QUICK_START.md
│   └── CONTACT_LENS_INSTRUCTIONS.md
├── RepPlusDocs/                    # Documentation and manuals
├── docker/                         # Deployment configs
└── [Config files: Dockerfile, docker-compose.yml, shiny-server.conf, deploy.sh]
```

---

## Data Model

### Repertory Grid (Core Structure)

A repertory grid consists of three components:

1. **Elements** (`rv$elements`): Character vector of item names (6-50 items)
   - Examples: "Mother", "Best Friend", "Ideal Self"
   - Metadata: Element images, URLs, file attachments (stored in `rv$element_images`, `rv$element_urls`, `rv$element_files`)

2. **Constructs** (`rv$constructs`): Data frame with columns:
   ```r
   left: character()      # Left pole label (similarity in triadic elicitation)
   right: character()     # Right pole label (difference/contrast)
   ```
   - Example: "friendly - unfriendly", "intelligent - unintelligent"

3. **Ratings** (`rv$ratings`): Data frame with columns:
   ```r
   element: character()
   construct: character()
   rating: numeric()      # 1-7 scale (or custom)
   ```

### Score Matrix (Computed)

From ratings, create a matrix:
```r
scores_mat <- matrix(ratings$rating, nrow=n_elements, ncol=n_constructs)
rownames(scores_mat) <- element_names
colnames(scores_mat) <- construct_names
```

- **Stored as**: `rv$scores_mat_last` (after "Analyze Grid")
- **Dimensions**: n_elements rows × n_constructs columns
- **Values**: 1-7 scale (or imputed if missing)

### OpenRepGrid Object

After analysis, create an OpenRepGrid object:
```r
rv$repgrid_last <- makeRepgrid(
  elements = rv$elements,
  constructs = paste0(rv$constructs$left, " - ", rv$constructs$right),
  ratings = rv$ratings
)
```

- Used by OpenRepGrid package for PCA, statistics, clustering
- Contains full grid metadata

### File Formats

#### .rgrid (Rep Plus / Rep IV format - tab separated)

A header line, one `C` line per construct, one `E` line per element, then
`_Key value` metadata. Tabs shown as arrows:

```
→Grid→9#→3→9→yurungi→A→3→2019-04-02→03:29:06→...→Rep Plus V1.1→RepGrid
C0→R→1→0→1→1→5→→Social→goal
E0→1→0→3→0→4→Canvas
_UID→52540087A7DEED4F03702
```

Three construct-line layouts exist, distinguished by field 5 (the number of
tokens per pole group): Rep IV and Rep Plus V1.1 write the label alone, Rep Plus
V2.0 prefixes each pole with the ratings it covers
(`1*→2→Social→4*→5→goal`). Rep Plus also stores ratings **0-based**
while declaring a 1-based scale, so they are shifted on import.

Parsing, the offset rule and how Rep Plus assigns ratings to poles and the
midpoint are documented in [RGRID_FORMAT.md](RGRID_FORMAT.md); the
implementation is `R/rgrid_io.R`, shared by both import paths.

#### .json (WebGrid Format)
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

#### Presets (JSON, in dataExamples/presets/)
```json
{
  "name": "Careers Study",
  "elements": ["Scientist", "Sociologist", "Doctor", "Librarian", "Artist"]
}
```

---

## Reactive Values (rv Structure)

The main `rv` reactiveValues object holds all state:

```r
rv <- reactiveValues(
  # === SINGLE-GRID DATA ===
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
  scores_mat_last = NULL,           # Matrix form (elements × constructs)
  repgrid_last = NULL,              # OpenRepGrid object
  imputed_last = FALSE,             # Whether imputation was used
  
  # === ELICITATION STATE ===
  elicitation_active = FALSE,       # Triadic elicitation in progress
  show_constructs = FALSE,          # UI display toggle
  manual_mode = FALSE,              # Manual vs triadic mode
  
  # === ELEMENT ATTACHMENTS ===
  element_images = list(),          # Base64-encoded images by element
  element_urls = list(),            # URLs by element
  element_files = list(),           # Base64-encoded files by element
  
  # === TRIADIC TRACKING ===
  all_triads = list(),              # All unique triads
  current_triad_idx = 0,            # Current triad index
  triad_similar = character(),      # Similar elements in current triad
  triad_different = NULL,           # Different element in current triad
  
  # === MULTI-GRID STORAGE ===
  grid_collection = list(),         # Named list of grids by UUID
  grid_metadata = data.frame(),     # Grid metadata (id, name, n_elem, n_const, scale)
  selected_grids = character(),     # Vector of selected grid IDs
  common_elements = character(),    # Elements shared across selected grids
  common_constructs = character(),  # Construct labels shared across grids
  
  # === MULTI-GRID RESULTS ===
  match_matrix = NULL,              # Grid-to-grid similarity matrix
  socionet_data = NULL,             # Network graph data
  mode_grid = NULL,                 # Consensus grid
  composite_grid = NULL,            # Merged grid
  minus_result = NULL,              # MINUS difference result
  core_result = NULL,               # CORE shared construing result
  traj_result = NULL,               # PrinGrid trajectory result
  exchange_result = NULL,           # Exchange analysis result
  metagrid = NULL,                  # Metagrid result
  meta_constructs = data.frame()    # Metagrid construct definitions
)
```

### Other Reactive Objects

- **`landing`**: Wizard page state (steps: "elements" → "presets" → "triads" → "results" → "rating" → "post_rating" → "done")
- **`chat_responses`**: Chat response storage with keys per tab
- **`focus_result`**: Focus analysis output (shared across tabs)

---

## Wizard Flow (7 Steps)

### Step 1: elements
- **Inputs**: `input$pseudonym`, `input$element_name` (1-6), `input$elements_bulk`
- **Actions**: Add individual elements or bulk paste
- **Buttons**: "Add", "Add All", "Begin Guided Elicitation", "Add Constructs Manually"
- **Next**: Button click → `landing$step = "presets"`

### Step 2: presets
- **UI**: Card picker showing presets from `dataExamples/presets/`
- **Actions**: Click preset card → load elements
- **Next**: Preset selected → `landing$step = "triads"`
- **Alt**: Skip preset → `landing$step = "triads"`

### Step 3: triads
- **Data**: `rv$all_triads` (all unique 3-element combinations)
- **UI**: Display current triad elements with images
- **Actions**: Click 2 similar + 1 different, enter poles, click "Next Triad"
- **Progress**: `current_triad_idx / length(all_triads)`
- **Next**: All triads done → `landing$step = "results"`

### Step 4: results
- **Display**: Numbered table of generated constructs
- **UI**: Red poles (left/similarity), blue poles (right/contrast)
- **Buttons**: "Email My Constructs", "Continue"
- **Email**: Sends `{"elements": [...], "constructs": [...]}`
- **Next**: Click "Continue" → `landing$step = "rating"`

### Step 5: rating
- **Loop**: Rate all elements on one construct at a time
- **UI**: Construct poles in color, circular rating buttons (1-7)
- **Buttons**: "Back", "Next"
- **Progress**: Shows current construct (e.g., 3/5)
- **Next**: Last construct rated → `landing$step = "post_rating"`

### Step 6: post_rating
- **Display**: Biplot preview of current grid
- **Buttons**: "Email My Chart", "Download Chart", "Explore Full App"
- **Email**: Sends full grid as JSON (importable via .json upload)
- **Next**: Click "Explore Full App" → `landing$step = "done"`

### Step 7: done
- **Action**: Auto-trigger analysis with imputation enabled
- **Transition**: Show main app with all tabs available
- **State**: `rv$elicitation_active = FALSE`, all analysis tabs enabled

---

## Single-Grid Analysis Tabs (10 Tabs)

### Tab 1: Build Grid
- Element entry, construct management, triadic elicitation
- Rating table with edit/delete
- Import/export buttons

### Tab 2: Grid Summary
- Elements list (DT table)
- Constructs list (DT table)
- Missing ratings table
- Analysis summary text

### Tab 3: Biplot
- **Computation**: `prcomp(scores_mat, scale=TRUE)`
- **Plot**: Elements as points, constructs as arrows
- **Palette**: `biplot_palette` (configurable)
- **Help/Chat**: Claude AI integration

### Tab 4: Crossplot
- **Inputs**: X-construct selector, Y-construct selector
- **Plot**: Scatter plot with 1:1 aspect ratio
- **Features**: Element labels, grid lines, midpoint emphasis
- **Overlap handling**: Opacity + label positioning
- **Palette**: `crossplot_palette`

### Tab 5: Synopsis
- **Plots**: Overall distribution, element distributions, construct distributions, scree plot
- **Inputs**: Histogram bins (3-20), color toggle
- **Data**: Variance explained by principal components
- **Palette**: `synopsis_palette`

### Tab 6: Heatmap
- **Data**: Score matrix as heatmap
- **Features**: Row/column clustering, color gradient
- **Palette**: `heatmap_palette` with color toggle
- **Dendrograms**: Top and left dendrograms

### Tab 7: Dendrograms
- **Combined view**: Element dendrogram + construct dendrogram
- **Computation**: `hclust()` with complete linkage on Euclidean distances
- **Display**: Vertical (constructs) and horizontal (elements)

### Tab 8: Focus Cluster
- **Algorithm**: Shaw's FOCUS (1980)
- **Steps**:
  1. Compute element-element similarity (Minkowski distance)
  2. Compute construct-construct similarity (with construct reversal)
  3. Hierarchical clustering (complete linkage)
  4. Sort matrix by cluster order
- **Plot**: single-region display layout - constructs as rows (poles flanking the
  ratings box), elements as columns with staircased labels below, element dendrogram
  above the columns, construct dendrogram right of the rows, match caption under the title
- **Variants**: `plot_focus_cluster()` (uniform spacing), `plot_focus_spaced()`
  (proportional spacing) or `plot_display_grid()` (grid as entered, no clustering),
  selected by the `focus_style` radio buttons and drawn through the shared
  `draw_focus_plot()` server helper
- **Palette**: `focus_palette`

### Tab 9: Statistics
- **Element stats**: Mean, SD, range, variance per element
- **Construct stats**: Mean, SD, range, variance per construct
- **Display**: DT tables

### Tab 10 (Bonus): Export
- CSV download
- .rgrid download
- .json download
- PNG plots

---

## Multi-Grid Analysis Tabs (9 Tabs, navbarMenu)

All multi-grid functions normalize ratings to c(1,7) scale before comparison.

### Collect Grids
- Import multiple `.rgrid` or `.json` files
- Manage grid collection (`rv$grid_collection`)
- Select grids for analysis

### Socionets
- **Function**: `plot_socionets(socionet_data)`
- **Data**: Grid-to-grid similarity matrix → network graph
- **Viz**: igraph network with nodes=grids, edges=similarity
- **Coloring**: Green=shared constructs, Gold=any overlap

### Mode Grid
- **Function**: `generate_mode_grid(grids)`
- **Data**: Average or median ratings across grids
- **Result**: Single consensus grid for group

### Composite Grid
- **Function**: `generate_composite_grid(grids)`
- **Data**: Merge elements and constructs from multiple grids
- **Result**: Single grid with all unique elements/constructs

### MINUS
- **Function**: `compute_minus_grid(grid1, grid2)`
- **Data**: Difference between two grids
- **Result**: Heatmap of rating differences

### CORE
- **Function**: `compute_core_analysis(grids)`
- **Data**: Iterative comparison to find shared construing
- **Result**: Progressively filtered constructs

### PrinGrid Trajectories
- **Function**: `compute_pringrid_trajectories(grids)`
- **Data**: PCA trajectories over time/sequence
- **Result**: 2D plot with trajectory paths

### Exchange Grids
- **Function**: `compute_exchange_analysis(grids)`
- **Data**: 6-grid exchange protocol
- **Result**: Analysis of exchange patterns

### Class Metagrids
- **Function**: `create_metagrid(grids, meta_constructs)`
- **Data**: Metagrid classification
- **Result**: High-level construct analysis across grids

---

## Focus Analysis Algorithm (R/focus_analysis.r)

### Similarity Computation

**Elements** (Minkowski distance):
```r
distance(e_i, e_j) = (sum(|r_ik - r_jk|^p))^(1/p)
similarity = 100 * (1 - distance / max_distance)
```
- **p=1**: City block (Manhattan)
- **p=2**: Euclidean

**Constructs** (with reversal):
```r
normal_dist = distance(c_i, c_j) using actual ratings
reversed_dist = distance(c_i_reversed, c_j) where c_i_reversed = 2*mid - c_i
distance = min(normal_dist, reversed_dist)  # Use better match
similarity = 100 * (1 - distance / max_distance)
```

### Clustering & Sorting

`focus_seriate()` implements Shaw's FOCUS sort, which is **not** a linkage rule
fed to `hclust`. It builds a single linear sequence:

1. Every item starts as a run of one.
2. Score each pair of runs by the best match between their **edges** (ends) -
   the RepGrid manual (section 5.3): *"items are matched only against the items
   at the edges of existing clusters"*. The `focus-interior` strategy scores
   against interior items too, then still places the join at the best-matching
   edge.
3. Join the best-scoring pair, reversing either run so the two matching ends
   butt together; the joined run keeps its order.
4. Repeat until one run remains - that run is the display order.

Heights are `100 - match`, so the tree is drawn in match units and is
monotonic (available matches can only shrink as edges become interior). The
result is returned as an `hclust`-compatible object, so `cophenetic()` and the
SPACED spacing work unchanged.

**Tie-breaking**: with few constructs the distances take few distinct values, so
several pairs routinely share the top match (the 9x3 yurungi grid ties at 6 of
its 8 steps). The manual does not say how Rep Plus resolves them; we break ties
on the earliest item in the original grid order, which is deterministic but will
not always reproduce Rep Plus's exact arrangement - see below.

`method` also accepts `complete`, `single`, `average` and `ward.D2`, which route
to `hclust` as before. Complete linkage scores cluster pairs by their *worst*
member, which is why it used to place strongly dissimilar elements adjacent:
across the 11 sample grids it averaged 78.1% similarity between neighbouring
columns against FOCUS's 84.4%, with seams as low as 8%.

### Agreement with Rep Plus

Verified against a Rep Plus desktop Focus plot of the yurungi grid: FOCUS
reproduces its adjacency quality exactly (81.2%) and the same cluster content,
but not its precise arrangement, because the tied joins are resolved
differently. Dendrogram branch rotation is also arbitrary, so plots may appear
mirrored. Resolving the tie-break exactly would need Rep Plus's own Focus
*Data* output (Matches / Links / Sort tables, section 5.3.2 of the manual).

### Plotting

All three plots share `render_grid_display()`, which draws the box, poles,
staircased element labels and both dendrograms in one plot region. Cell size is
capped to the rating digits so the box stays compact; margins are measured in
inches from the actual label metrics, with the right margin settled over a few
passes because staircase overflow depends on the cell width it helps determine.

**plot_focus_cluster()**: Uniform cell spacing
- Optional shading, values, color

**plot_focus_spaced()**: Proportional spacing
- Cophenetic distances between adjacent items (`spaced_positions()`)
- Spacing: `1 + (dist/max_dist) * 1.2` cell units
- Rows, columns and dendrogram leaves all drawn at the non-uniform positions

**plot_display_grid()**: Grid as entered, no clustering or dendrograms

**dendro_segments()**: Dendrogram geometry for arbitrary leaf positions, so the
SPACED variant's dendrograms line up with its non-uniform rows and columns

---

## Triadic Elicitation (R/triadic_elicitation.r)

### Triad Generation

```r
generate_triads(elements) -> list of all C(n,3) combinations
safe_triads(elements, MAX_TRIADS=30) -> sample if > 30 triads
```

### Elicitation Process

1. Show three elements to user (triad)
2. User selects which TWO are similar (left pole) and which ONE is different (right pole)
3. User enters labels for similarity pole and difference pole
4. Construct is created and added to `rv$constructs`
5. Move to next triad

### Progress Tracking

```r
get_elicitation_progress(total, completed)
-> list(percent = ..., message = "X/Y triads (Z%)")
```

---

## Claude AI Integration (R/claude_api.R)

### API Configuration

- **Model**: `claude-sonnet-5` (configurable)
- **API Key**: `ANTHROPIC_API_KEY` environment variable
- **Endpoint**: `https://api.anthropic.com/v1/messages`
- **Headers**: `x-api-key`, `anthropic-version`, `content-type`

### Chat Features

Each visualization tab has:

1. **Help Button** (static explanation)
2. **Chat Button** (expandable panel)
   - Text input for user question
   - "Ask Claude (API)" → Direct API call (requires key)
   - "Copy to Clipboard" → Copy context for manual paste to Claude.ai
   - "Link to Claude.ai"

### Context Generation

```r
generate_claude_context(viz_type, question, grid_summary, extra_context)
-> Paste together:
   - Grid summary (elements, constructs, ratings)
   - Visualization-specific parameters
   - Relevant RepPlus documentation (RAG)
   - User's question
```

### Documentation RAG

- Load all `.txt` files from `RepPlusDocs/` on app startup
- For each question, search docs for relevant keywords
- Extract relevant sections (up to 8000 chars)
- Include in Claude API prompt for context

---

## Color Palettes

Each visualization has its own palette selector:

```r
list(
  element = "#...",      # Element point/label color
  construct = "#...",    # Construct arrow/label color
  highlight = "#...",    # Accent color
  accent = "#...",       # Secondary accent
  heat_low = "#...",     # Low end of heatmap
  heat_high = "#..."     # High end of heatmap
)
```

**Available Palettes**:
- **wong**: Blue (#0072B2) / Orange (#D55E00) — Accessible
- **classic**: Blue (#2166AC) / Red (#B2182B)
- **earth**: Wheat (#F5DEB3) / Brown (#8B4513)
- **contrast**: White (#FFFFFF) / Black (#000000)
- **greyscale**: Black (#000000) / Dark Grey (#333333) — Publication-ready

---

## File Attachments

### Element Images
- **Input**: File upload or URL paste
- **Processing**: 
  - Client-side resize to 800px max (JavaScript)
  - Convert to base64 data URL
  - Store in `rv$element_images[[element_name]]`
- **Display**: Thumbnail in element row (40px), zoomed in triads (60px)

### Element Files (PDFs, Documents)
- **Input**: File upload
- **Processing**: Convert to base64, store in `rv$element_files`
- **Display**: Filename label with paperclip icon
- **Limit**: 2MB max per file

### Element URLs
- **Input**: URL paste via prompt
- **Processing**: Store in `rv$element_urls`
- **Display**: Truncated URL label
- **Use**: Can be clicked to open in new window

---

## Deployment

### Docker stack (production)
- **Base image**: `rocker/shiny:4.5.3`
- **Dockerfile**: installs the R packages straight from CRAN (unpinned - it does
  *not* use `renv.lock`), then copies `app.R`, `R/`, `dataExamples/` and
  `RepPlusDocs/*.txt`
- **Entrypoint**: `docker-entrypoint.sh` promotes `ANTHROPIC_API_KEY` into R's
  `Renviron.site`, because shiny-server does not pass its environment to the R
  workers it spawns
- **Port binding**: `172.17.0.1:3838` - the docker bridge, *not* loopback, so
  nginx can reach it while the host's public interface cannot. `curl
  localhost:3838` will always come back empty; use the bridge address
- **Compose v2 is required** (`docker compose`, with a space). The v1 python
  client crashes with `KeyError: 'ContainerConfig'` when recreating a container
  built by a modern daemon, and the two disagree about image names
  (`repplusapp_repplus` vs `repplusapp-repplus`), so mixing them silently starts
  a stale image

### Nginx reverse proxy
- **Config**: `/home/ubuntu/nginx/webgrid.conf`, mounted into the `nginx`
  container at `/etc/nginx/conf.d/webgrid.conf`
- **Upstream**: `proxy_pass http://172.17.0.1:3838/webgrid/`
- **SSL**: Let's Encrypt (`/etc/letsencrypt`, mounted into the container)
- **URL**: https://webgrid.online

### Server
- **Host**: DreamCompute (208.113.135.63), user `ubuntu`
- **OS**: Ubuntu 24.04.1 LTS, ~8 GB RAM
- **Repo**: `/home/ubuntu/RepPlusApp` — note that a stale clone also exists at
  `/home/ubuntu/repplus2025`; deploying from it ships old code
- **Redeploy**: `cd ~/RepPlusApp && git pull && ./deploy.sh`

`deploy.sh` builds before touching the running container, so the site stays up
for the slow part and is interrupted only for the container swap (a few
seconds - `container_name` is pinned, so there is no rolling replacement). It
clears a leftover container holding the name, then polls the app and reports the
version actually being served.

### shinyapps.io (backup deployment)
https://ech08ravo.shinyapps.io/repplus2025/ - free tier, so it sleeps between
uses and an initial request returns HTTP 202 while it wakes.

Deployed from a developer machine with `rsconnect`. Three flags matter:

```r
rsconnect::deployApp(
  appDir = ".", appName = "repplus2025", account = "ech08ravo",
  appFiles = c("app.R",
               list.files("R", pattern = "\\.[Rr]$", full.names = TRUE),
               list.files("dataExamples", recursive = TRUE, full.names = TRUE),
               Sys.glob("RepPlusDocs/*.txt")),
  dependencyResolution = "library",
  forceUpdate = TRUE
)
```

- **`appFiles`** - without it the whole directory is bundled: 21 MB of
  `RepPlusDocs` PDFs the app never reads, plus `renv/`, `.RData`, `tests/`. The
  list above is 1.1 MB
- **`dependencyResolution = "library"`** - by default rsconnect reads
  `renv.lock` and aborts if the local library has drifted from it. This deploys
  the versions actually installed and tested locally instead
- **No `envVars`** - `ANTHROPIC_API_KEY` is deliberately not uploaded, so the
  "Ask Claude (API)" buttons stay hidden there and Copy-to-Clipboard is the only
  chat path. shinyapps.io has no `.env` or `Renviron.site`, so the Docker
  entrypoint mechanism does not apply

Every package in `renv.lock` must also be installed locally for rsconnect to
read it, even under `dependencyResolution = "library"`, and every `Repository`
source record needs its `Repository` field - a record missing it fails with
`subscript out of bounds`.

---

## Security

### Input Validation
- MAX_ELEMENTS=50, MAX_CONSTRUCTS=100, MAX_GRIDS=50, MAX_TRIADS=30
- File size: 2MB max (client) + 10MB shiny.maxRequestSize
- Element name: Non-empty, unique
- Construct poles: Non-empty, non-identical

### API Security
- API key in environment variable (not in code)
- CORS not explicitly handled (local API calls only)
- No authentication on app (public read-only access can be added)

### Data Privacy
- No data persisted to disk (in-memory only, unless exported)
- Export via mailto (client-side email client)
- No tracking or analytics (can be added)

---

## Testing

### Test Scripts
- `test_focus.R`: Focus algorithm unit tests
- `test_import.R`: Grid import tests
- `test_all_imports.R`: Package dependency check

### Running Tests
```r
source("test_focus.R")
source("test_import.R")
source("test_all_imports.R")
```

---

## Common Development Patterns

### Adding a New Visualization Tab

1. **Add UI in tabsetPanel**:
```r
tabPanel(
  title = tagList(tags$span(class = "sg-dot"), "NewViz"),
  value = "NewViz",
  fluidRow(
    column(4, selectInput("newviz_palette", "Color Palette", 
      choices = c("Wong"="wong", "Classic"="classic", ...)))
  ),
  plotOutput("newviz_plot"),
  actionButton("help_newviz", "Help..."),
  actionButton("chat_newviz", "Chat...")
)
```

2. **Add server rendering**:
```r
output$newviz_plot <- renderPlot({
  req(rv$scores_mat_last)
  colors <- get_palette_colors(input$newviz_palette)
  # ... plot code
})
```

3. **Add help content**:
```r
observeEvent(input$help_newviz, {
  # Show help modal
})
```

4. **Add chat integration**:
```r
observeEvent(input$chat_newviz, {
  # Show chat panel with context
})
```

### Adding a New Multi-Grid Function

1. **Implement in R/multigrid_analysis.r**:
```r
compute_new_analysis <- function(grids, ...) {
  # Normalize scales
  # Compute analysis
  # Return result object
}
```

2. **Add UI tab in navbarMenu**:
```r
tabPanel(
  title = tagList(tags$span(class = "mg-any"), "New Analysis"),
  value = "NewAnalysis",
  # ... UI
)
```

3. **Add server rendering**:
```r
output$newanalysis_plot <- renderPlot({
  req(length(rv$selected_grids) >= 2)
  grids_list <- rv$grid_collection[rv$selected_grids]
  rv$newanalysis_result <- compute_new_analysis(grids_list)
  plot(rv$newanalysis_result)
})
```

---

## Known Limitations & Future Work

- **Limitation**: No 3D PCA visualization (PrinGrid 3D)
- **Planned**: Image elements from mobile photo library
- **Planned**: Per-visualization email buttons in main app
- **Planned**: Additional preset grids for course exercises
- **Planned**: Statistical tests (e.g., correlation, variance analysis)
- **Planned**: Export to PDF format
- **Planned**: Advanced clustering methods (e.g., DBSCAN, GMM)

---

## References

- Kelly, G.A. (1955). *The Psychology of Personal Constructs*
- Shaw, M.L.G. (1980). *On Becoming a Personal Scientist*
- Shaw, M.L.G. (1980). SOCIOGRIDS methodology for multi-grid comparison
- OpenRepGrid R package: https://github.com/markheckmann/OpenRepGrid
- Shiny documentation: https://shiny.posit.co/
- Claude API documentation: https://docs.anthropic.com/
