# WebGrid.Online

A Shiny web application for eliciting, rating, and analysing repertory grids using the [OpenRepGrid](https://docs.openrepgrid.org/) R package and Personal Construct Theory.
Outputs are interoperable with **RepPlus** (`.rgrid` format).

**Live**: https://webgrid.online | **Version**: 2.2.0

---

## ✨ Features

### Guided Onboarding (7-Step Wizard)
- **Step 1**: Welcome screen with pseudonym generation
- **Step 2**: Enter 5 elements manually or load pre-configured preset grid
- **Step 3**: Triadic elicitation with visual progress tracking
- **Step 4**: Construct summary with email export
- **Step 5**: One-construct-at-a-time rating (1-7 scale)
- **Step 6**: Post-rating biplot preview with chart download
- **Step 7**: Auto-transition to full application with analysis enabled

### Grid Elicitation
- Add elements and bipolar constructs interactively
- Element attachments: upload images/files, add URLs
- Preset element sets (careers, learning situations, biscuits walkthrough, school subjects)
- Triadic comparison for construct elicitation (2 similar + 1 different)
- Collect ratings for each element–construct pair (1-7 scale)
- View live element/construct/rating tables
- Remove or edit ratings
- Load sample data for quick testing
- Import/export grids as `.rgrid` (RepPlus-compatible), `.csv`, or `.json`

### Single-Grid Analysis & Visualization (10 tabs)
- **Build Grid**: Element entry, triadic elicitation, construct management
- **Grid Summary**: Overview of elements, constructs, and missing ratings analysis
- **Biplot**: 2D PCA visualization showing element points and construct vectors
- **Crossplot**: 2D scatter plot of elements on two selected constructs
  - Interactive X and Y construct selection
  - Optional element labels and grid lines
  - 1:1 aspect ratio for equal scaling
  - Midpoint emphasis at rating = 4
  - Downloadable high-resolution plots (1200×1200 PNG)
- **Synopsis**: Rating distribution histograms and variance analysis
  - Overall rating distribution with mean/median
  - Individual element distributions
  - Individual construct distributions
  - Scree plot showing variance explained by principal components
  - Adjustable histogram bins, greyscale/color toggle
  - Downloadable plots
- **Heatmap**: Color-coded grid visualization with row/column clustering
- **Dendrograms**: Hierarchical clustering trees for elements and constructs
- **Focus Cluster Analysis**: Shaw's (1980) FOCUS algorithm for sorting by similarity
  - Automatic hierarchical clustering of elements and constructs
  - Configurable Minkowski distance metric (city block or Euclidean)
  - SPACED variant with proportional cluster spacing
  - Greyscale publication-ready output (color toggle available)
  - 1:1 aspect ratio for consistent proportions
  - Adaptive text sizing for grids of any size
  - Element similarity statistics panel
  - Downloadable high-resolution plots (1200×900 PNG)
- **Statistics**: Comprehensive element and construct descriptive statistics

### Multi-Grid Analysis (9 tabs via Multi-Grid Menu)
- **Collect Grids**: Import and manage multiple grids, grid collection interface
- **Socionets**: Network visualization of grid relationships (igraph)
- **Mode Grid**: Consensus grid from multiple grids (average/median ratings)
- **Composite Grid**: Merged grid combining elements and/or constructs from multiple grids
- **Comparison**: Compare two grids side-by-side (grid difference analysis)
- **MINUS**: Detailed grid difference analysis (Shaw's MINUS protocol)
- **CORE**: Shared construing analysis (iterative comparison across multiple grids)
- **Trajectories**: PrinGrid trajectories showing PCA changes over sequence/time
- **Exchange Grids**: 6-grid exchange protocol analysis (agreement & understanding between two people)
- **Class Metagrids**: Metagrid classification across multiple grids

### Claude AI Integration
- Chat button on every visualization tab
- Ask questions about grid analysis and interpretation
- Two modes: Direct API (requires ANTHROPIC_API_KEY) or copy-to-clipboard for manual Claude.ai
- RAG (Retrieval Augmented Generation) using RepPlus documentation
- Context-aware prompts with grid data and visualization parameters
- Model: claude-sonnet-4-20250514 (configurable)

### Imputation
- Optional missing data imputation (midpoint = 4 for 1-7 scale)
- Analysis works with complete or incomplete grids

---

## 🛠️ Setup

### Prerequisites
1. Install [R](https://cran.r-project.org/)  
2. Install [RStudio Desktop](https://posit.co/download/rstudio-desktop/)  
3. Install [Git](https://git-scm.com/)  

### Clone the repo
In RStudio: **File → New Project → Version Control → Git**.  
Repo URL:
git@github.com:ech08ravo/repplus2025.git

---

## 📦 Install dependencies

Open the **Console** in RStudio and run:

```r
install.packages("pak")
pak::pak(c(
  "shiny","DT","uuid",
  "igraph","psych","pvclust","openxlsx","rmarkdown",
  "ech08ravo/OpenRepGrid"
))

```

(Optional: use `renv::init(); renv::snapshot()` to lock exact versions.)

---

## ▶️ Run the app

In RStudio:

```r
shiny::runApp()
```

## 🖥️ How the app works

### Quickstart: Guided Wizard (Recommended for new users)

On first load, you'll enter a 7-step wizard:

1. **Welcome** — Brief introduction with pseudonym generation
2. **Enter Elements** — Type 5 element names OR click "Use Preset" to load pre-configured elements (Careers, Biscuits, Learning Situations, School Subjects)
3. **Triadic Elicitation** — Shown triads of 3 elements; pick which 2 are similar and 1 is different; enter bipolar construct poles. Progress bar tracks completion.
4. **Construct Summary** — Review all generated constructs in a numbered table. "Email My Constructs" button to send data.
5. **Rate Elements** — Rate each element on each construct (1-7 scale), one construct at a time with back/next navigation.
6. **Results Preview** — See a biplot of your grid. "Download Chart" and "Email My Chart" buttons.
7. **Full App** — Auto-transitions to the complete application with analysis automatically enabled.

### Full App: Build Your Grid Manually

If you skip the wizard or reload the app:

#### Elements
- Click **Build Grid** tab
- Enter a name (e.g., "Mother", "My Boss") and click **Add element**
- Optional: attach image, file, or URL to each element
- All elements list in sidebar

#### Constructs (Two methods)

**Method 1: Triadic Elicitation (Recommended)**
- Click **Begin Elicitation**
- Follow the triadic comparison process (see Wizard, Step 3)

**Method 2: Manual Entry**
- Enter a **left pole** (e.g., friendly) and a **right pole** (e.g., unfriendly)
- Click **Add construct**
- Constructs appear as `left - right`

#### Ratings
- Select an element and a construct from dropdowns
- Use the slider (1–7) to assign a rating (1 = left pole, 7 = right pole)
- Click **Add rating**
- Ratings shown in live table
- To remove: select a row → **Remove selected rating**

#### Sample Data
- Click **Load Sample Data** to instantly add:
  - Elements: e1, e2, e3 (with fruit icons)
  - Constructs: fresh–stale, healthy–unhealthy, tasty–bland
  - Pre-filled ratings

### 2. Analyze Your Grid

Click **Analyze Grid** (requires ≥3 elements & ≥3 constructs)

Navigate through the single-grid analysis tabs:

#### Build Grid Tab
- Add/remove elements with optional attachments (images, files, URLs)
- Begin triadic elicitation or add constructs manually
- View and edit ratings table
- Download data as CSV, .rgrid, or JSON

#### Grid Summary Tab
- Overview of elements and constructs
- Analysis of missing ratings
- Data quality indicators
- Summary statistics

#### Biplot Tab
- 2D PCA visualization showing element and construct relationships
- Elements plotted as colored points
- Constructs as vectors from origin
- Palette selector (wong, classic, earth, contrast, greyscale)
- Help and Claude AI chat buttons
- Downloadable as PNG

#### Crossplot Tab
- Plot elements as points on two selected constructs
- **Controls**:
  - **X-axis Construct**: Select which construct to plot horizontally
  - **Y-axis Construct**: Select which construct to plot vertically
  - **Show Element Labels**: Display element names above points (default: on)
  - **Show Grid Lines**: Display 1-7 grid with midpoint emphasis (default: on)
- 1:1 aspect ratio ensures equal scaling on both axes
- Overlap handling with opacity and directional labels
- Palette selector, help and chat buttons
- Download as PNG

#### Synopsis Tab
- View rating distributions and variance analysis
- **Display options**:
  - **Overall Distribution**: Histogram of all ratings with mean and median lines
  - **Element Distributions**: Individual histograms for each element showing rating patterns
  - **Construct Distributions**: Individual histograms for each construct
  - **Scree Plot**: Variance explained by principal components (bar chart + cumulative line)
- Adjustable number of histogram bins (3-20)
- Greyscale by default (color toggle available)
- Palette selector, help and chat buttons
- Download as PNG

#### Heatmap Tab
- Color-coded grid (greyscale default, color toggle available)
- Row and column clustering via dendrograms
- Shows rating patterns at a glance
- Interactive cell values
- Palette selector (wong, classic, earth, contrast)
- Downloadable as PNG

#### Dendrograms Tab
- **Element Dendrogram**: Hierarchical clustering tree of elements
- **Construct Dendrogram**: Hierarchical clustering tree of constructs
- Shows which items are most similar based on rating patterns
- Complete linkage hierarchical clustering

#### Focus Cluster Tab
- **Run Focus Analysis** to automatically sort your grid by similarity (Shaw's FOCUS algorithm)
- Displays sorted grid with dendrograms on top and left
- Shows element and construct similarity statistics in right panel
- Configurable parameters:
  - **Minkowski Power**: 1.0 (city block) or 2.0 (Euclidean distance)
  - **Match Cutoff**: Minimum similarity % to display (default 80%)
  - **Show Rating Values**: Toggle numeric display in cells
  - **Show Shading**: Toggle greyscale/color gradient
  - **Use SPACED variant**: Toggle between standard and proportionally-spaced dendrograms
  - **Color Palette**: Select from wong, classic, earth, contrast, greyscale
  - **Text Size** and **Cell Size**: Scaling factors for large/small grids
- Adaptive margins and text sizing for readability
- **Download Focus Plot** for high-resolution PNG (1200×900)

See [FOCUS_USER_GUIDE.md](FOCUS_USER_GUIDE.md) for detailed Focus analysis instructions.

#### Statistics Tab
- Element statistics: mean, SD, range, median per element
- Construct statistics: mean, SD, range, median per construct
- Element/construct frequency distributions
- Useful for identifying patterns, outliers, and construct usage

### 3. Export Your Data

- **Download as CSV**: Ratings table for spreadsheet analysis
- **Download as .rgrid**: RepPlus-compatible file for use in other RepGrid software
- **Download plots**: High-resolution PNG images of visualizations

⸻

## 📂 File structure

```
WebGrid.Online/
├── app.R                              # Main Shiny application (6612 lines)
├── R/
│   ├── focus_analysis.r               # Focus clustering algorithm (Shaw 1980)
│   ├── multigrid_analysis.r           # Multi-grid analysis (SOCIOGRIDS)
│   ├── claude_api.R                   # Claude AI integration
│   ├── triadic_elicitation.r          # Triadic elicitation helpers
│   └── score_matrix_helper.r          # Utility functions
├── dataExamples/
│   ├── *.rgrid                        # Sample grid files (9 examples)
│   ├── *.csv                          # Sample data in CSV format
│   ├── presets/                       # Preset element sets (JSON)
│   │   ├── biscuits_walkthrough.json
│   │   ├── careers.json
│   │   ├── learning_situations.json
│   │   └── school_subjects.json
│   ├── QUICK_START.md                 # Quick start guide
│   └── CONTACT_LENS_INSTRUCTIONS.md   # Sample exercise
├── RepPlusDocs/
│   ├── WebGrid-Online-Manual.md       # User manual
│   └── *.pdf, *.txt                   # Documentation and manuals
├── README.md                          # This documentation
├── CLAUDE_PROJECT_DOCS.md             # Developer reference (deployment, reactive values, functions)
├── CHANGELOG.md                       # Release notes
├── FOCUS_USER_GUIDE.md                # Guide to Focus cluster analysis
├── FOCUS_IMPLEMENTATION.md            # Technical Focus algorithm details
├── LICENCE.md                         # License information
├── .gitignore                         # Git ignore patterns
├── Dockerfile                         # Docker image configuration
├── docker-compose.yml                 # Docker compose configuration
├── shiny-server.conf                  # Shiny server configuration
├── renv.lock                          # Reproducible R environment
└── renv/                              # R package dependencies
```

---

## 📊 WebGrid.Online Feature Coverage

WebGrid.Online implements core repertory grid analysis functionality:

**✅ Implemented (v2.2.0):**

*Single-Grid Analysis:*
- Interactive grid elicitation (elements, constructs, ratings)
- Element attachments (images, files, URLs)
- Triadic elicitation with visual card interface
- Import/export (.rgrid, .csv, .json)
- Rating distributions and scree plot (Synopsis)
- 2D scatter plot on construct pairs (Crossplot)
- PCA biplot visualization
- Heatmap with row/column clustering
- Hierarchical dendrograms (elements and constructs)
- Focus cluster analysis (Shaw's 1980 algorithm + SPACED variant)
- Descriptive statistics
- Missing data imputation
- Per-visualization color palettes (wong, classic, earth, contrast, greyscale)
- Claude AI integration for interpretation help

*Multi-Grid Analysis:*
- Grid collection management
- Grid-to-grid similarity (Socionets network visualization)
- Mode Grid (consensus from multiple grids)
- Composite Grid (merge elements/constructs)
- Grid Comparison (side-by-side analysis)
- MINUS analysis (grid difference)
- CORE analysis (shared construing)
- Trajectories (PCA changes over sequence)
- Exchange Grid protocol (6-grid analysis for agreement & understanding)
- Class Metagrids (classification across multiple grids)

**❌ Not Yet Implemented:**
- **Single Grid:**
  - PrinGrid 3D plots and Voronoi diagrams
  - Weighted analysis
  - Slater and Intensity distance metrics
- **Multiple Grid:**
  - Implication grids (Hinkle laddering)
  - Resistance to change grids
  - Dependency grids
  - ARGUS network analysis
  - Batch processing
- **Advanced:**
  - Content analysis and categorization
  - Supra-grid analysis
  - INGRID PCA variants
  - PREFAN analysis
  - Automated construct elicitation

For full RepGrid documentation, see the [RepPlusDocs](RepPlusDocs/) directory.

---

## 🚀 Deployment

**Primary Deployment**: https://webgrid.online (DreamCompute)

- **Server**: Ubuntu 24.04, 8GB RAM (208.113.135.63)
- **Stack**: Docker (rocker/shiny) + Nginx reverse proxy + Let's Encrypt SSL
- **Redeploy**: `ssh ubuntu@208.113.135.63 "cd repplus2025 && git pull && docker build -t webgrid . && docker rm -f webgrid && docker run -d --name webgrid --restart unless-stopped -p 3838:3838 webgrid"`

**Backup Deployment**: https://ech08ravo.shinyapps.io/repplus2025/ (shinyapps.io)

For deployment details, see [CLAUDE_PROJECT_DOCS.md](CLAUDE_PROJECT_DOCS.md).

---

## 🧑‍💻 Contributing

1. Fork the repo
2. Make your changes in a new branch
3. Submit a Pull Request

---

## 📜 License

Open-source under MIT License.