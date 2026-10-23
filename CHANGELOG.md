# Changelog

All notable changes to WebGrid.Online are documented in this file.

## [2.13.0] - 2026-10-23

### Added
- **Mode Grid construct labels can be coloured by the grid they came from.**
  With several grids merged into one picture there was no way to see whose
  construct was whose. `generate_mode_grid()` already worked out the source of
  each construct when collecting, then discarded it on the way out; it is kept
  now, and recorded when folding too. A construct that folding merged across
  grids is marked "Shared" and drawn in grey rather than credited to whichever
  grid happened to be read first. A key along the bottom says which colour is
  which. "Colour construct labels by source grid" on the Mode Grid tab turns it
  off.
- `draw_grid_heatmap()` accepts one pole colour per construct. `axis()` takes a
  single `col.axis` for a whole axis, so in that case the tick labels are drawn
  individually - with `text()` rather than `mtext()`, since a wrapped pole label
  contains newlines that `mtext()` does not lay out.

## [2.12.0] - 2026-10-23

### Added
- **`./release.sh` is now the way to release.** It refuses to continue unless
  the version in `app.R` matches the newest changelog entry and that entry has
  been written, the version has not already been tagged, the tree is clean and
  level with `origin/master`, and `./tests/run_all.sh` passes. Only then does it
  deploy to webgrid.online and shinyapps.io, poll both until they actually serve
  the expected version, and tag the commit. `--dry-run` runs every check and
  deploys nothing. Tagging had lapsed after v2.2.0; it resumes here.
- **`./bump_version.sh <version>`** raises `APP_VERSION` and opens a changelog
  section for it, refusing a downgrade or a malformed version.
- **`deploy_shinyapps.R`** pins the shinyapps `appId`. `rsconnect/` is
  gitignored, so the record of which app to update existed only on the machine
  that first deployed; a deploy from a fresh clone or the server would have
  created a second app at a new URL rather than updating this one.

### Fixed
- **A deploy can no longer look successful while serving old code.** `deploy.sh`
  accepted any version string from the live site, and a stale container answers
  happily with the old number. It now compares what is served against
  `APP_VERSION` in the checkout and fails if they differ.
- **A forgotten version bump now fails the tests** rather than shipping a
  version string that lies. The release check asserts `app.R` and `CHANGELOG.md`
  agree and that the entry is not still the placeholder.
- Rewrote `DEPLOY_INSTRUCTIONS.md`, which had drifted far enough to name a
  container and image that have not existed for months. It no longer repeats
  what the scripts do - that duplication is why it drifted - and covers only
  access, topology and troubleshooting.

## [2.11.1] - 2026-10-23

### Added
- **A release check suite.** `./tests/run_all.sh` runs every automated check and
  exits non-zero if any fails. The new `tests/test_release_check.R` covers the
  arithmetic: element and construct match percentages, unrated-cell handling,
  the declared scale, construct reversal, the FOCUS sort and its dendrogram
  heights, and a round trip through the file format.
- **Two calibration grids**, `tests/fixtures/calibration_elements.rgrid` and
  `tests/fixtures/calibration_constructs.rgrid`, built so the right answer
  follows by construction: identical elements must match 100%, elements at
  opposite ends of every construct 0%, a mirrored construct 100%. The check
  also compares whole similarity matrices against a second, deliberately naive
  implementation of the formula, so it tests for correct answers rather than
  merely unchanged ones - a snapshot would have frozen the two bugs found
  earlier this month instead of catching them.

### Fixed
- **A grid exported from the app and loaded back came back named after a row
  count.** The grid name was read from header field 5, which holds the number
  of ratings; the name is field 6. Real `.rgrid` files were unaffected because
  they carry a `_Name` line, which is read first - but the app's own export
  wrote no `_Name`, so a reimported grid was titled "6" on every plot. The
  field is corrected, a bare number is no longer accepted as a name, and the
  exporter now writes the grid's real name into both the header and a `_Name`
  line, with `_Context` alongside it when the grid has one.

## [2.11.0] - 2026-10-23

### Added
- **The match boxes can be copied and exported.** Each of the Element and
  Construct match boxes on the Focus tab now carries Copy, Matrix CSV and
  Matches CSV. Copy takes the box exactly as shown, client side. Matrix CSV is
  the full similarity matrix with its labels; Matches CSV is every pair above
  the cutoff, strongest first, as a tidy three-column table rather than the top
  ten the box has room to print.

### Fixed
- **The match boxes scroll instead of overflowing.** The similarity matrices
  are far wider than the half-width column holding them, and construct labels
  make each row longer still, so the text ran out of its box. Both boxes now
  scroll in either direction within a fixed height, and keep `white-space: pre`
  so the matrix columns stay aligned rather than wrapping into a jumble.
- **"Top Matches" now lists the strongest matches.** It listed neither the top
  matches nor all of them: `which(sim >= cutoff, arr.ind = TRUE)` returns each
  pair twice, in column order, and the code took the first ten of those rows
  and then kept only the ones with `r < c` - so it discarded most of what it
  found and never sorted by similarity. On the yurungi sample it showed 2 of
  the 10 qualifying pairs and left out both 100% matches. Pairs are now
  deduplicated, sorted strongest first, and the box says how many more sit
  above the cutoff.

## [2.10.0] - 2026-10-23

### Added
- **Match percentages can be shown on the FOCUS dendrograms.** "Show match % on
  dendrograms" on the Focus tab labels every join on both the element and the
  construct tree with the percentage at which those two clusters merged. FOCUS
  already stores each join's height as 100 - match, so the figure is the one
  the sort itself used, not a recomputation. Off by default, since on a large
  grid the labels crowd. The element labels sit clear above each join; the
  construct ones are left-aligned beyond their join, with room reserved in the
  right margin so the outermost label is not clipped.

## [2.9.1] - 2026-10-23

### Fixed
- **The sidebar sections can be opened from the keyboard.** File Operations,
  Analysis, Display Options and Export were headings with a click handler and
  nothing else - no tab stop, no role, no key handling - so everything inside
  them was unreachable without a mouse, and a screen reader was given no hint
  that they open and close. Each now takes focus, announces itself as a button
  with its open or closed state, responds to Enter and Space, and shows a focus
  ring. Space no longer scrolls the page when used on one. The decorative arrow
  is hidden from screen readers, and the state stays correct when the app opens
  the Analysis section by itself.

## [2.9.0] - 2026-10-23

### Added
- **Plots name the grid they are drawn from.** A `.rgrid` file carries the
  grid's name and the question its constructs were elicited against in its
  trailing `_Name` and `_Context` lines, but the importer was discarding both.
  They are read now, and the heatmap carries the name and date as its title
  with the elicitation context beneath - so `yurungi` prints as
  "yurungi (2019-04-02)" over "Your perception of collaboration platforms...".
  The Focus and Display plots append the name to their own titles, which keep
  their match summaries in the subtitle. "Name the grid on plots" under Display
  Options turns it off. A grid built in the app or imported from JSON carries
  no such metadata and is left untitled, as before.

## [2.8.0] - 2026-10-23

### Added
- **A display options panel for visitors.** A control at the bottom left of
  every page offers larger text, high contrast, underlined links, a plainer
  typeface and reduced motion, remembered in that browser. It is a preferences
  panel, not an accessibility overlay: it changes only what the visitor asks it
  to change and never tries to detect or auto-repair the page. Everything is
  client side - no preference reaches the server. Because every font size in
  the app is set in px, text scaling works by zoom; the text drawn inside the
  plots is separate and stays with the sidebar's Text Size slider.
- **Separate colours for the three parts of the heatmap.** The Heatmap tab now
  takes a colour for the construct pole labels, one for the element labels and
  one for the rating values, alongside the existing cell shading palette, which
  is now labelled "Cell Shading Palette" to tell the two apart. Rating values
  keep following their cell by default; unticking "Rating colour follows the
  cell" hands that choice over. Uses the browser's own colour picker, so no new
  package is needed.

### Fixed
- **The sidebar toggle button works.** Its click handler and the media query
  that hides the control panel on a narrow screen both looked for
  `.col-sm-2.sidebar`, which needs one element carrying both classes.
  `sidebarPanel()` puts the column class on a wrapper div and `sidebar` on the
  form inside it, so the selector matched nothing: `querySelector` returned
  null and the handler threw before it could do anything, which is why the
  button appeared dead, and the panel never hid on a narrow screen either.
  The wrapper is now tagged on load and both work from that. The button also
  reports its state with `aria-expanded` and moves focus into the panel it
  opens, and back to itself on close.

## [2.7.0] - 2026-10-23

### Added
- **The heatmap can be drawn with no shading at all.** A "Show Shading" checkbox
  turns the colour off entirely, leaving white cells carrying only their rating
  values, with cell boundaries drawn so the grid still reads as a grid. The
  existing "Use color shading" checkbox only ever swapped colour for a grey
  ramp - still shading, and already available as the Greyscale palette - so
  there was no way to read the grid as a plain table of numbers. The Heatmap tab
  now offers the same shading controls as the Focus tab.

### Fixed
- **The Heatmap/Focus cell size slider now changes the heatmap's cells.** It was
  wired only to the size of the digits; the plot itself was pinned at 500px
  whether the grid had three constructs or forty, and `image()` stretches its
  cells to fill whatever device it is given, so the cells themselves never
  moved. The plot height now follows both the slider and the number of
  constructs. The PNG download shared the same fixed height, so tall grids
  downloaded squashed; it follows the same rule now.
- **Rating values stay legible on every cell.** The label colour was chosen by a
  fixed `value > 4` test, which assumed a 1-7 scale: it put white digits on the
  pale middle of a diverging palette, black digits on dark greys, and would have
  rendered white on white once shading could be turned off. Each label now takes
  its colour from the cell it actually sits on.
- Corrected a test fixture path left stale by the `bezzi1996_expert` to
  `bezzi1996_nick` rename, which had been failing the grid integrity suite.

## [2.6.0] - 2026-09-14

### Changed
- **Unrated cells are no longer imputed.** Analysis previously refused to run on
  an incomplete grid unless "Impute missing" was ticked, which filled every blank
  with `4` - neither the midpoint of the 1-5 scale nor a "don't know", but a
  rating inside the right pole's band, so each filled cell leaned right. The
  wizard's auto-analysis filled `3`. Blanks now stay blank, and analysis runs.
  A rating is a judgement the participant made; the midpoint is also a judgement
  ("both poles apply equally"), so no value on the scale can stand for "not
  answered".
- Focus, matches, dendrograms and statistics work from the ratings present,
  matching pairwise. **The PCA biplot** is the one analysis that needs a complete
  matrix: elements with unrated cells are omitted from that plot and named
  beneath it, instead of being given invented ratings.
- The "Impute missing" control is replaced by a note explaining how blanks are
  handled in each analysis.

## [2.5.0] - 2026-09-14

### Changed
- **Unrated cells are excluded from matches instead of counting as agreement.**
  Element, construct and multi-grid matching all set a missing difference to zero
  while keeping the full denominator, so an absent rating scored as perfect
  agreement and elements looked more alike the less was known about them. A
  construct now counts towards a comparison only when both items are rated on it,
  with the denominator shrinking to match; items sharing nothing rated score 0.
  Grids with no missing data are unaffected - across the sample grids, pairs
  containing unrated cells had been matching 7-8 percentage points too high.
- **Match percentages and construct reversal use the scale the grid declares**,
  not the range of values that happen to be present. A grid using only 2-4 of a
  1-5 scale previously had its matches rescaled to that narrower range.
- **The rating scale is a property of the grid** (`rv$scale`, as min/max), set
  from the `.rgrid` C-line or a JSON `scale` field and defaulting to 1-5, rather
  than assumed at each point of use. It is carried into `.rgrid` export, so a
  grid keeps its scale across a round trip.
- `.rgrid` export writes `?` for unrated cells, the marker Rep Plus uses;
  previously it wrote `NA`, producing a file that could not be read back.

### Added
- **"0 = N/A" checkbox** on the File Operations panel,
  unticked by default. Rep Plus stores ratings 0-based, so a stored `0` is normally
  the pure left pole; but a grid transcribed the way Bezzi (1996) printed it uses
  `0` for "construct does not apply" alongside 1-5 ratings. Nothing in the data
  distinguishes the two, so the importer asks rather than guesses.
  The checkbox only decides whether zeros are ratings. **Where the ratings start is
  inferred separately**, from whether the grid reaches the top of its declared
  scale: a grid with an element at a pole maximum is already 1-based, one that
  stops a step short is 0-based and gets the scale minimum added. Grids with no
  element at any pole fall back to the file's source string. The import
  notification reports which readings were applied.
- Regression tests for match semantics and for the Bezzi (1996) published grid,
  which the importer reproduces cell for cell including its 12 not-applicable
  cells.

## [2.4.1] - 2026-09-14

### Fixed
- **The Statistics tab reported scrambled numbers.** `makeRepgrid()` fills
  `matrix(scores, ncol = n_elements, byrow = TRUE)`, so it needs ratings
  construct-major; the app passed `as.vector(t(scores_mat))`, which is
  element-major. Every rating landed in the wrong cell. The value count is the
  same either way, so nothing errored and the totals looked plausible - on the
  yurungi grid, Canvas (rated 4, 1, 5) was reported with mean 4.33, min 4.
  Now `as.vector(scores_mat)`, verified cell for cell against the file.
  - Affected: the Statistics tab (element and construct statistics) and the
    analysis summary - the only three consumers of the repgrid object.
  - Not affected: every plot (biplot, crossplot, heatmap, Focus, dendrograms,
    multi-grid), which read `rv$scores_mat_last` directly.

### Added
- [MIDPOINT_DECISIONS.md](MIDPOINT_DECISIONS.md) - written record of the rating-scale
  midpoint decisions: what the Rep Plus format itself declares, the six places the
  app uses a midpoint and the three different answers they gave, and why the
  imputation question is deferred pending the literature.
- `tests/test_grid_integrity.R` - regression tests from `.rgrid` file through to
  the OpenRepGrid object: pole labels, rating offset, cell-for-cell agreement
  with the file, and a round trip over every sample grid.

## [2.4.0] - 2026-09-14

### Changed
- **Focus now runs Shaw's FOCUS sort instead of hclust complete linkage.** FOCUS
  is a seriation, not a linkage rule: each cluster is an ordered run of items, and
  two runs are joined by butting together the ends that match best, per the
  RepGrid manual section 5.3 ("items are matched only against the items at the
  edges of existing clusters"). Complete linkage scores cluster pairs by their
  *worst* member, which placed strongly dissimilar elements side by side - across
  the 11 sample grids it averaged 78.1% similarity between neighbouring columns
  against FOCUS's 84.4%, with seams as low as 8%.
- New **Sort strategy** control on the Focus tab: FOCUS edge matching (default),
  FOCUS interior matching (the manual's Interior option), or complete / single /
  average linkage for comparison. Changing it re-sorts immediately.

### Added
- `focus_seriate()` implementing both FOCUS matching strategies, returning an
  `hclust`-compatible object so the dendrograms and SPACED spacing work unchanged.

### Known limitation
- Ties are frequent (the 9x3 yurungi grid ties at 6 of its 8 joins) and the manual
  does not specify how Rep Plus resolves them. Ours breaks ties on the earliest
  item in grid order. Against a Rep Plus desktop plot of the same grid this
  reproduces the adjacency quality exactly (81.2%) and the same clusters, but not
  the identical arrangement. Branch rotation is also arbitrary, so plots may
  appear mirrored.

## [2.3.1] - 2026-09-11

### Fixed
- **.rgrid import read the wrong construct poles from Rep Plus V2.0 files.**
  V2.0 annotates each pole with the ratings it covers
  (`1* 2 Social  4* 5 goal`), so taking the last two tab fields - correct for
  Rep IV and Rep Plus V1.1 - returned `5` as every left pole. Parsing now uses
  field 5 of the construct line, which is the token count per pole group, with a
  fallback for layouts we have not seen.
- **.rgrid ratings were imported 0-based.** Rep Plus stores ratings 0-based while
  declaring a 1-based scale: a file reading `3 0 4` is displayed as `4 1 5` by the
  Rep Plus desktop app. Ratings are now shifted onto the declared scale, and only
  when they actually fit after shifting, so files that are already 1-based (including
  this app's own exports) are never shifted twice. This was not only cosmetic -
  `rv$scale` is never assigned, so 0-4 data was analysed as 1-5: imputation filled
  the midpoint 3 when the real midpoint was 2, heatmap `zlim` clipped the zeroes,
  and construct reversal reflected around the wrong centre.
- The declared scale is now carried through import instead of being assumed to be 1-5.

### Changed
- Both `.rgrid` import paths (single-grid and multi-grid) now share one parser in
  `R/rgrid_io.R`, replacing two copies of the field-counting logic.

### Fixed
- **renv.lock could not be read by rsconnect.** The `Matrix` and `lattice`
  records declared `"Source": "Repository"` with no `Repository` field, which
  aborts dependency capture with `subscript out of bounds`. Both now carry
  `"Repository": "CRAN"` like every other record.

### Documentation
- Rewrote the ARCHITECTURE deployment section, which named the wrong repo path
  (a stale clone at `/home/ubuntu/repplus2025`), the wrong base image, a renv
  restore the Dockerfile does not do, and `localhost:3838` as the upstream when
  the app binds to the docker bridge. Adds the shinyapps.io procedure.
- New [RGRID_FORMAT.md](RGRID_FORMAT.md): the three construct-line layouts, the
  rating-offset rule with its truth table and worked calculation, how Rep Plus
  assigns ratings to poles and treats the midpoint, and every place the app uses
  a midpoint. Marks which statements are verified against the Rep Plus desktop
  display and which are inferred.
- Corrected the `.rgrid` description in ARCHITECTURE.md, which documented an
  `ELEMENTS`/`CONSTRUCTS`/`RATINGS` block format that no `.rgrid` file uses.
- Documented two unfixed midpoint inconsistencies: imputation fills `4` and the
  crossplot draws its midpoint gridline at `4`, both 1-7 midpoints in an app
  whose scale, axes and help text are 1-5.

## [2.3.0] - 2026-09-11

### Changed
- **Focus Cluster tab redesigned to the WebGrid display layout**
  - Grid transposed: constructs are now rows with their poles either side of the
    ratings box; elements are columns named by staircased labels below, each
    joined to its column by a leader line
  - Ratings box is sized to its contents instead of stretching to fill the panel
  - Element dendrogram moved above the columns, construct dendrogram to the right
    of the rows; sorting, shading, values and SPACED spacing unchanged
  - Top element/construct match now shown as a caption under the title

### Fixed
- **Ask Claude had no manual context in production** - two stacked bugs:
  - The Dockerfile never copied `RepPlusDocs/`, so `load_repplus_docs()` found
    nothing and the `tryCatch` in app.R silently fell back to an empty list.
    The image now includes the eight `.txt` manuals (672K; the PDFs are not read)
  - The manuals are Mac Roman, but `readLines(..., encoding = "UTF-8")` only
    tags strings as UTF-8 without converting them, leaving every doc invalid
    UTF-8. `grepl()` in `get_relevant_docs()` then warned "input string is
    invalid" and matched nothing, so retrieval returned zero characters even
    when the files were present. The loader now converts from Mac Roman

### Changed
- **deploy.sh rewritten** to require compose v2 and verify the result. It builds
  before touching the running container (so the site stays up for the slow part),
  recovers from a leftover `repplus` container, waits for the app to answer on the
  docker bridge address, and fails loudly with the version it ended up serving.
  The old script called compose v1, which crashes on recreate and tags images
  under a name v2 does not look for - the two together could leave the site down
  or silently running a stale image.

### Added
- **Display representation** on the Focus Cluster tab - the grid as entered, with
  no clustering or dendrograms. Selected via the new Representation radio buttons
  (FOCUS / SPACED / Display), which replace the SPACED checkbox.

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
