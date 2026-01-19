# RepPlusApp

A Shiny app for eliciting, rating, and analysing repertory grids using the [OpenRepGrid](https://docs.openrepgrid.org/) R package.
Outputs are interoperable with **RepPlus** (`.rgrid` format).

---

## ✨ Features

### Grid Elicitation
- Add elements and bipolar constructs interactively
- Collect ratings for each element–construct pair (1-7 scale)
- View live element/construct/rating tables
- Remove or edit ratings
- Load sample data for quick testing
- Import/export grids as `.rgrid` (RepPlus-compatible) or `.csv`

### Analysis & Visualization
- **Synopsis**: Rating distribution histograms and variance analysis
  - Overall rating distribution with mean/median
  - Individual element distributions
  - Individual construct distributions
  - Scree plot showing variance explained by principal components
  - Downloadable plots
- **Crossplot**: 2D scatter plot of elements on two selected constructs
  - Interactive X and Y construct selection
  - Optional element labels and grid lines
  - 1:1 aspect ratio for equal scaling
  - Midpoint emphasis at rating = 4
  - Downloadable high-resolution plots (1200×1200 PNG)
- **PCA Biplot**: 2D visual map of constructs and elements using Principal Component Analysis
- **Heatmap**: Color-coded (greyscale default) grid visualization with row/column clustering
- **Dendrograms**: Hierarchical clustering trees for both elements and constructs
- **Focus Cluster Analysis**: Shaw's (1980) FOCUS algorithm for sorting by similarity
  - Automatic hierarchical clustering of elements and constructs
  - Configurable Minkowski distance metric (city block or Euclidean)
  - Greyscale publication-ready output (color toggle available)
  - 1:1 aspect ratio for consistent proportions
  - Adaptive text sizing for grids of any size
  - Downloadable high-resolution plots (1200×900 PNG)
- **Statistics**: Comprehensive element and construct descriptive statistics

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

### 1. Build Your Grid

#### Elements
- Enter a name (e.g., e1, e2, e3) and click **Add element**
- All elements will list in the sidebar

#### Constructs
- Enter a **left pole** (e.g., friendly) and a **right pole** (e.g., unfriendly)
- Click **Add construct**
- Constructs appear as `left - right`

#### Ratings
- Select an element and a construct
- Use the slider (1–7) to assign a rating (1 = left pole, 7 = right pole)
- Click **Add rating**
- Ratings are shown in a live table
- To remove a rating: select a row → **Remove selected rating**

#### Sample Data
- Click **Load Sample Data** to instantly add:
  - Elements: e1, e2, e3
  - Constructs: left–right, black–white, high–low
  - Pre-filled ratings

### 2. Analyze Your Grid

Click **Analyze Grid** (requires ≥3 elements & ≥3 constructs)

Navigate through the analysis tabs:

#### Synopsis Tab
- View rating distributions and variance analysis
- **Display options**:
  - **Overall Distribution**: Histogram of all ratings with mean and median lines
  - **Element Distributions**: Individual histograms for each element showing rating patterns
  - **Construct Distributions**: Individual histograms for each construct
  - **Scree Plot**: Variance explained by principal components (bar chart + cumulative line)
- Adjustable number of histogram bins (3-20)
- Greyscale by default (color toggle available)
- Download as PNG

#### Crossplot Tab
- Plot elements as points on two selected constructs
- **Controls**:
  - **X-axis Construct**: Select which construct to plot horizontally
  - **Y-axis Construct**: Select which construct to plot vertically
  - **Show Element Labels**: Display element names above points (default: on)
  - **Show Grid Lines**: Display 1-7 grid with midpoint emphasis (default: on)
- 1:1 aspect ratio ensures equal scaling on both axes
- Useful for identifying element relationships on specific construct dimensions
- Download as PNG

#### Biplot Tab
- 2D PCA visualization showing element and construct relationships
- Elements plotted as points, constructs as vectors
- Downloadable as PNG

#### Heatmap Tab
- Color-coded grid (greyscale default, color toggle available)
- Row and column clustering
- Shows rating patterns at a glance

#### Dendrogram Tabs
- **Element Dendrogram**: Hierarchical clustering tree of elements
- **Construct Dendrogram**: Hierarchical clustering tree of constructs
- Shows which items are most similar

#### Focus Cluster Tab
- **Run Focus Analysis** to automatically sort your grid by similarity
- Displays sorted grid with dendrograms on top and left
- Shows element and construct match statistics
- Configurable parameters:
  - **Minkowski Power**: 1.0 (city block) or 2.0 (Euclidean)
  - **Match Cutoff**: Minimum similarity % to display (default 80%)
  - **Show Rating Values**: Toggle numeric display
  - **Show Shading**: Toggle greyscale/color
  - **Use color palette**: Toggle color (default: greyscale for publications)
- **Download Focus Plot** for high-resolution PNG (1200×900)

See [FOCUS_USER_GUIDE.md](FOCUS_USER_GUIDE.md) for detailed Focus analysis instructions.

#### Statistics Tab
- Element statistics (means, SD, etc.)
- Construct statistics (means, SD, etc.)
- Useful for identifying patterns and outliers

### 3. Export Your Data

- **Download as CSV**: Ratings table for spreadsheet analysis
- **Download as .rgrid**: RepPlus-compatible file for use in other RepGrid software
- **Download plots**: High-resolution PNG images of visualizations

⸻

## 📂 File structure

- `app.R` → Main Shiny application code
- `R/focus_analysis.r` → Focus cluster analysis functions
- `test_focus.R` → Test script for Focus analysis
- `README.md` → This documentation
- `FOCUS_USER_GUIDE.md` → Detailed guide to Focus cluster analysis
- `FOCUS_IMPLEMENTATION.md` → Technical implementation details
- `LICENCE.md` → License information
- `RepPlusDocs/` → Documentation files (text versions of RepGrid manuals)
- `renv.lock` (optional) → Reproducible package versions

---

## 📊 RepGrid Feature Coverage

RepPlusApp implements a **core subset** of the full RepGrid suite functionality. Currently implemented:

**✅ Implemented:**
- Grid elicitation (elements, constructs, ratings)
- Import/export (.rgrid, .csv)
- **Synopsis analysis** (rating distributions and scree plot)
- **Crossplot** (2D scatter plot on selected constructs)
- PCA biplot visualization
- Heatmap with clustering
- Element and construct dendrograms
- **Focus cluster analysis** (Shaw's 1980 algorithm)
- Descriptive statistics
- Missing data imputation

**❌ Not Yet Implemented** (from original RepGrid suite):
- **Single Grid Analyses:**
  - Match analysis (standalone similarity matrices)
  - PrinGrid 3D plot and Voronoi diagrams
  - Weighted analysis
- **Multiple Grid Analyses:**
  - Implication grids (Hinkle laddering)
  - Resistance to change grids
  - Dependency grids
  - Exchange grids (multi-person analysis)
  - SOCIOGRID and ARGUS network analysis
  - Grid comparison utilities
  - Batch processing
- **Advanced Features:**
  - Content analysis and categorization
  - Advanced distance metrics (Slater, Intensity)
  - Supra-grid analysis
  - Principal Component Analysis variants (INGRID)
  - PREFAN analysis
  - Automated construct elicitation

For full RepGrid documentation, see the [RepPlusDocs](RepPlusDocs/) directory.

---

## 🧑‍💻 Contributing

1. Fork the repo
2. Make your changes in a new branch
3. Submit a Pull Request

---

## 📜 License

Open-source under MIT License.