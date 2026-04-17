# Changelog

All notable changes to WebGrid.Online are documented in this file.

## [2.2.0] - 2026-04-16

### Added
- **Wizard Onboarding (7 steps)**
  - Step 1: Welcome with pseudonym generation and 6 numbered element inputs
  - Step 2: Preset picker (load pre-configured element sets from `dataExamples/presets/`)
  - Step 3: Triadic elicitation with progress tracking
  - Step 4: Construct summary with email export
  - Step 5: One-construct-at-a-time rating with back/next navigation
  - Step 6: Post-rating biplot preview with chart export
  - Step 7: Auto-transition to full app with analysis enabled

- **Element Attachments**
  - File upload support (images, PDFs, documents)
  - URL attachment support (webpages, images)
  - Client-side image resizing (max 2MB, resized to 800px)
  - File preview in triad cards and rating screens
  - Thumbnail display in element entries

- **Preset System**
  - JSON preset files in `dataExamples/presets/` with element sets
  - Automatic preset discovery and loading
  - Preset picker UI on landing page

- **Multi-Grid Analysis (9 tabs via navbarMenu)**
  - **Collect Grids**: Import and manage multiple grids
  - **Socionets**: Network visualization of grid relationships (igraph)
  - **Mode Grid**: Consensus grid (average/median ratings)
  - **Composite Grid**: Merged grid combining elements/constructs
  - **MINUS**: Grid difference analysis (comparing two grids)
  - **CORE**: Shared construing analysis (iterative comparison)
  - **PrinGrid Trajectories**: PCA trajectory visualization over sequence/time
  - **Exchange Grids**: 6-grid exchange protocol analysis
  - **Class Metagrids**: Metagrid classification across multiple grids
  - All analyses normalize to c(1,7) scale

- **Focus Algorithm Enhancement**
  - `plot_focus_spaced()` function for SPACED variant with proportional spacing
  - Cophenetic distance-based spacing visualization
  - Adaptive dendrogram margins
  - Enhanced element match statistics panel

- **Claude AI Integration**
  - Chat button on all visualization tabs
  - API mode (requires ANTHROPIC_API_KEY) for direct Claude queries
  - Copy-to-clipboard mode for manual Claude.ai paste
  - RAG (Retrieval Augmented Generation) using RepPlus documentation
  - Context-aware prompts with grid data and visualization details
  - Model: claude-sonnet-4-20250514 (can be configured)

- **Display & Export Enhancements**
  - Per-visualization color palettes: wong (accessible), classic, earth, contrast, greyscale
  - Adjustable text size and cell size for large/small grids
  - Email export via mailto links (constructs and charts as JSON)
  - JSON format export (in addition to .rgrid and .csv)
  - Improved element image handling with fallback to paperclip icon

- **Triadic Elicitation Features**
  - Safe triads generation (samples when combinatorial count exceeds MAX_TRIADS=30)
  - Visual progress tracking during elicitation
  - Image display in triad comparison cards
  - Construct validation (poles must be different)

### Changed
- Rebranded as "WebGrid.Online" (from "RepPlusApp")
- app.R expanded from ~5800 to 6612 lines with wizard and multi-grid features
- Sidebar width reduced to 2 (from default 3) for more main content space
- Main panel width increased to 10
- Single-grid tabs now 10 (added "Grid Summary" tab with Dendrograms combined)
- UI tabs reorganized: Build Grid → Grid Summary → Biplot → Crossplot → Synopsis → Heatmap → Dendrograms → Focus Cluster → Statistics
- Multi-grid analysis now in separate navbarMenu with distinct styling
- Landing page redesigned as 7-step wizard (was simple login)
- Focus cluster tab now includes SPACED variant toggle
- Documentation updated with complete architecture details

### Fixed
- Dendrogram rendering warnings (harmless, cosmetic only)
- Image error handling with MutationObserver for broken images
- Triad card image display with proper fallbacks
- Construct dendrogram orientation and labeling in focus plots

### Improved
- Adaptive text sizing in focus cluster (minimum 1.0 cex for readability)
- Element similarity visualization in focus cluster stats panel
- Crossplot overlap handling with opacity and label positioning
- Grid summary analysis table accuracy
- Missing ratings detection and display

### Security
- Explicit upload size limit (10MB)
- Grid limits: MAX_ELEMENTS=50, MAX_CONSTRUCTS=100, MAX_GRIDS=50, MAX_TRIADS=30
- API key stored in ANTHROPIC_API_KEY environment variable (not in code)
- Client-side file size validation (2MB max per file)

### Technical
- New file: `R/multigrid_analysis.r` (1337 lines) for multi-grid functionality
- Enhanced `R/focus_analysis.r` with plot_focus_spaced variant (381 lines total)
- Enhanced `R/claude_api.R` with multi-model support (245 lines)
- New `R/score_matrix_helper.r` for utility functions (17 lines)
- Deployment config: Docker, Compose, nginx reverse proxy, Let's Encrypt SSL
- Server: DreamCompute Ubuntu 24.04, 8GB RAM

### Documentation
- New: ARCHITECTURE.md (Developer guide with rv structure, algorithms, integration)
- New: CHANGELOG.md (This file)
- Updated: README.md (Complete feature list, file structure, wizard flow)
- Updated: CLAUDE_PROJECT_DOCS.md (Reactive values, wizard flow, landing steps)
- Existing: FOCUS_USER_GUIDE.md (Detailed Focus analysis guide)
- Existing: FOCUS_IMPLEMENTATION.md (Focus algorithm technical details)
- Existing: RepPlusDocs/WebGrid-Online-Manual.md (User manual)
- Existing: dataExamples/QUICK_START.md (Quick start guide)
- Existing: dataExamples/CONTACT_LENS_INSTRUCTIONS.md (Sample exercise)

### Deployment
- Live URL: https://webgrid.online
- Docker image: rocker/shiny with OpenRepGrid and dependencies
- Nginx reverse proxy with Let's Encrypt SSL (auto-renewing)
- Redeploy via: `git pull && docker build && docker run`

---

## [2.1.x] - Previous releases

See commit history for earlier versions.

---

## [2.0.0] - Initial release

Original RepPlusApp with single-grid analysis only (10 tabs).
