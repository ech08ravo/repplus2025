# WebGrid.Online User Manual

## Eliciting, Rating and Analyzing Repertory Grids

Updated May 2026 (covers v2.2)

Elizabeth Black, with Claude AI assistance

Based on the RepPlus Conceptual Representation Software by Brian R Gaines and Mildred L G Shaw

https://webgrid.online

---

## What's new since the March 2025 manual

- **Default scale is 1–5** (matching Shaw's original WebGrid). Older `.rgrid` and `.json` files using a 1–7 scale are auto-normalised when loaded.
- **Element attachments** — every element slot (in the wizard, in Build Grid, in any Edit) accepts an image, document, or URL. On phones the picker opens the camera. See section 8.
- **Save Grid on every chart tab** — the JSON save button now sits next to *Download PNG* on Biplot, Crossplot, Synopsis, Heatmap, both Dendrograms, and Focus, so you don't have to hunt in *Export*.
- **Guided Tour** — a *Guided Tour (Biscuits!)* button on the landing page walks brand-new users through a worked example with image cues.
- **Default landing is the full app**. Append `?mode=simple` to the URL to force the wizard for first-time users (Section 1.3).
- **Built-in rate limit on the AI chat** — max 10 *Ask Claude* calls per session per minute (Section 6.1). Hitting the limit shows a yellow notification; the Copy-to-Clipboard fallback is unaffected.
- **More multi-grid analyses** — MINUS, CORE, PrinGrid Trajectories, Exchange Grids, and Class Metagrids are all in the bottom row of tabs.
- **Privacy** — grid data is processed in your browser session and discarded when your tab closes; nothing is stored on the server (Section 9).

---

## Contents

1. Introduction to WebGrid.Online
   1. What is a Repertory Grid?
   2. WebGrid.Online and RepPlus
   3. Accessing WebGrid.Online
2. Getting Started: The Guided Wizard
   1. Entering Elements
   2. Using a Preset Grid
   3. Triadic Elicitation of Constructs
   4. Reviewing Your Constructs
   5. Rating Elements on Constructs
   6. Your First Visualization
   7. Entering the Full Application
3. The Full Application Interface
   1. Sidebar Controls
   2. Single-Grid Analysis Tabs
   3. Multi-Grid Collection Tabs
4. Single-Grid Visualizations
   1. Build Grid
   2. Grid Summary
   3. Biplot (PCA)
   4. Crossplot
   5. Synopsis
   6. Heatmap
   7. Element Dendrogram
   8. Construct Dendrogram
   9. Focus Cluster
   10. Statistics
5. Multi-Grid Analysis
   1. Grid Collection
   2. Socionets
   3. Mode Grid
   4. Composite Grid
   5. MINUS Analysis
   6. CORE Analysis
   7. PrinGrid Trajectories
   8. Exchange Grids
   9. Class Metagrids
6. AI-Assisted Interpretation
   1. Chat with Claude
   2. FOCI: Focus Interpretation
   3. Copy to Clipboard
7. File Formats and Import/Export
   1. Importing Grids
   2. Exporting Grids and Visualizations
   3. Email Features
   4. JSON Format
   5. .rgrid Format
8. References

---

## 1 Introduction to WebGrid.Online

### 1.1 What is a Repertory Grid?

A repertory grid is a structured interview technique developed by George Kelly (1955) as part of his Personal Construct Theory (PCT). It provides a systematic way to explore how people think about a domain by eliciting the personal distinctions (constructs) they use to make sense of a set of items (elements).

A repertory grid has three components:

- **Elements** — the items being compared (e.g., people, careers, products, concepts). These should be drawn from a single domain and be meaningful to the person completing the grid.
- **Constructs** — bipolar dimensions that distinguish between elements. Each construct has a left pole and a right pole representing opposite ends of a personal distinction (e.g., "creative — methodical").
- **Ratings** — numerical scores indicating where each element falls on each construct scale.

The resulting grid (a matrix of elements × constructs) can then be analyzed using a variety of statistical and visual methods to reveal patterns in a person's construing.

### 1.2 WebGrid.Online and RepPlus

WebGrid.Online is the web-based successor to the RepPlus suite of conceptual representation tools developed by Brian Gaines and Mildred Shaw at the University of Calgary. It implements the core functionality of RepGrid and RepGrids (the multi-grid analysis tool) in a modern web application.

Key capabilities carried forward from RepPlus include:

- Triadic elicitation of constructs (Kelly's original method)
- Shaw's (1980) FOCUS algorithm for clustering and sorting grids
- SOCIOGRIDS methodology for comparing multiple grids
- Socionets, Mode Grid, Composite Grid, MINUS, CORE analyses
- Exchange Grid protocol for measuring interpersonal understanding
- PrinGrid trajectory analysis for tracking change over time

New capabilities in WebGrid.Online include:

- Guided wizard interface for new users and student exercises
- AI-assisted interpretation using Claude
- Preset grid system for structured exercises
- Mobile-friendly responsive design
- JSON import/export format

### 1.3 Accessing WebGrid.Online

WebGrid.Online is available at **https://webgrid.online**.

No account or login is required. Grid data is processed locally in your browser session and is not stored on the server (see Section 9 for privacy details).

The **full application is the default** when you visit the URL. To force the **guided wizard** (useful for class exercises or first-time users), append `?mode=simple`:

    https://webgrid.online?mode=simple

There is also a **Simple Start** button in the sidebar of the full app that switches into the wizard from any state.

**Browsers:** Chrome, Edge, Safari, and Firefox are all tested. Mobile Safari and Chrome on Android both work for entering and rating grids; large multi-grid analyses are easier on a desktop because of screen real estate.

---

## 2 Getting Started: The Guided Wizard

The guided wizard walks new users through the complete process of creating and analyzing a repertory grid. It follows Kelly's methodology: elicit elements, generate constructs through triadic comparison, rate elements, and explore the results.

### 2.1 Entering Elements

When you visit WebGrid.Online with `?mode=simple` (or click *Simple Start* in the sidebar), you are presented with the landing page. There are **six element fields** — enter at least four (you'll see a friendly error if you try to continue with fewer). Pick items from the same category:

- 6 career paths you are considering
- 6 people you work with
- 6 cities you have lived in
- 6 products you use regularly

Each field accepts plain text, but you can also:

- **Paste a URL** (anything starting with `http://` or `https://`) — it will be auto-detected and shown as a clickable link in the triad cards and rating screen, so you can pop open the source while you decide.
- **Attach an image, document, or take a photo** by clicking the 📎 paperclip button next to the field. On mobile this opens the camera directly via the OS picker. On desktop it opens a file chooser. Images are resized client-side to 800px max edge before upload, so a phone photo is safe.
- **Paste multiple elements at once** in Build Grid (the full app's data-entry tab) using the "Paste Multiple" textarea. URLs in the pasted text are auto-detected and stored as element links.

Click **Continue** when you're ready.

**Tip:** Choose elements that are meaningful to you and that you can meaningfully distinguish from one another. The constructs you generate will depend entirely on the elements you provide.

**Pseudonym:** The optional name field at the top labels your grid when it's saved or added to a Grid Collection. Leave blank to be assigned a random pseudonym (e.g. *SwiftFalcon42*).

### 2.2 Using a Preset Grid

If you are completing a structured exercise (e.g., a class assignment), click **Use an Existing Grid** on the landing page. This shows a list of preset element sets that have been configured for your course or project.

Select a preset to load its elements automatically. You will then proceed to triadic elicitation to generate your own personal constructs for those elements.

Currently shipped presets (in `dataExamples/presets/`):

- **Careers Study** — Scientist, Sociologist, Doctor, Librarian, Artist
- **School Subjects** — Mathematics, Physics, Chemistry, Biology, Geology, Geography
- **Learning Situations** — based on the Arthur grid (Gaines & Shaw)
- **Time Person of the Year** — historical figures with Wikipedia links
- **Guided Tour: Biscuits!** — a friendly worked example with product images, accessible from the *Guided Tour (Biscuits!)* button on the landing page

Instructors can drop additional `.json` preset files into `dataExamples/presets/` on the server. A preset file just needs `name` and `elements`; optionally `element_urls` (links shown next to each element) and `element_images` (base64 images).

### 2.3 Triadic Elicitation of Constructs

After entering elements, WebGrid.Online presents triads — groups of three elements at a time. For each triad:

1. **Click two cards** that you consider similar in some important way. These will turn green and be marked "Similar."
2. **Click the remaining card** — the one that is different. It will turn red and be marked "Different."
3. **Describe the similarity:** In the first text box, type a word or phrase describing how the two similar elements are alike (e.g., "creative").
4. **Describe the difference:** In the second text box, type a word or phrase describing how the different element contrasts (e.g., "methodical").
5. Click **Next** to proceed to the next triad.

These two descriptions become the left pole and right pole of a bipolar construct.

You can click **Skip** to move past a triad that does not suggest a meaningful distinction. Click **Finish & See Results** when you have generated enough constructs (typically 5–8 is sufficient for a useful analysis).

A progress bar at the top shows how many triads remain.

### 2.4 Reviewing Your Constructs

After elicitation, a summary page lists all the constructs you generated, showing each left pole and right pole.

At this point you can:

- **Email My Constructs** — sends your construct list to your email address for your records (useful for class submissions). The email contains your data in JSON format.
- **Continue to Rating** — proceed to rate each element on each construct.

### 2.5 Rating Elements on Constructs

The rating page presents one construct at a time. For each construct:

- The left pole and right pole are displayed at the top.
- Each element appears with a 1–5 scale (circular buttons).
- **1** means the element is strongly associated with the left pole.
- **5** means the element is strongly associated with the right pole.
- **3** is the midpoint (the element is neither or both).

Click a rating for each element, then click **Next Construct**. Use **Back** to review previous ratings.

### 2.6 Your First Visualization

After completing all ratings, a preview biplot is displayed showing a 2D map of how your elements relate to each other and to your constructs.

From this screen you can:

- **Email My Chart** — send the visualization context to your email
- **Download Chart** — save the biplot as a PNG image
- **Continue to Full App** — enter the full analysis environment

### 2.7 Entering the Full Application

Clicking **Continue to Full App** loads the complete analysis interface with all visualization tabs available. Your grid data is automatically analyzed with imputation enabled for any missing ratings. The Biplot tab is selected by default.

From here you can explore your grid using any of the single-grid visualization tools described in Section 4.

---

## 3 The Full Application Interface

### 3.1 Sidebar Controls

The left sidebar provides global controls and file operations:

**Simple Start** — returns to the guided wizard to create a new grid from scratch.

**File Operations:**
- **Import Grid** — upload a .json or .rgrid file
- **Add to Collection** — upload multiple grids for multi-grid analysis
- **Load Sample Data** — load example grids for experimentation

**Analysis:**
- **Analyse** — run the analysis on the current grid data
- **Impute Missing** — when checked, missing ratings are replaced with the scale midpoint

**Display Settings:**
- **Text Size** — adjusts label size across all visualizations (0.8–1.6×)
- **Cell Size** — adjusts heatmap and Focus cluster cell dimensions (0.8–2.0×)

**Export:**
- **Download Grid (CSV)** — export the rating matrix as a spreadsheet
- **Download Grid (.rgrid)** — export in native RepGrid format

### 3.2 Single-Grid Analysis Tabs

The top row of tabs provides single-grid visualizations:

Build Grid | Grid Summary | Biplot | Crossplot | Synopsis | Heatmap | Element Dendrogram | Construct Dendrogram | Focus Cluster | Statistics

These tabs analyze the currently loaded grid. See Section 4 for detailed descriptions.

### 3.3 Multi-Grid Collection Tabs

The bottom row of tabs provides multi-grid comparative analyses:

Grid Collection | Socionets | Mode Grid | Composite Grid | MINUS | CORE | PrinGrid Trajectories | Exchange Grids | Class Metagrids

These tabs require two or more grids to be loaded into the collection. See Section 5 for detailed descriptions.

---

## 4 Single-Grid Visualizations

### 4.1 Build Grid

The Build Grid tab is the data entry interface for the full application. You can:

- **Add elements** individually by typing a name and clicking Add, or paste multiple elements at once.
- **Generate constructs** using triadic elicitation (click "Begin Elicitation") or add them manually.
- **Edit ratings** directly in the rating matrix table.
- **Try Sample Fruits** — loads a quick example dataset for testing.

This tab is the starting point when using the full application without the guided wizard.

### 4.2 Grid Summary

Displays a summary of the current grid including:

- List of elements
- List of constructs (left pole — right pole)
- Missing ratings table (highlights any elements × constructs without a rating)
- Analysis summary statistics

### 4.3 Biplot (PCA)

The biplot uses Principal Component Analysis (PCA) to project the grid data onto two dimensions. It is one of the most informative single-grid visualizations.

**Reading the biplot:**

- **Element points** (colored dots with labels) show how elements relate to each other. Elements close together are construed similarly; elements far apart are construed differently.
- **Construct arrows** (lines from the origin) show the direction of each construct's influence. The arrow points toward the right pole (high rating end). Elements near the tip of an arrow tend to be rated high on that construct.
- **Variance explained** is shown in the axis labels (e.g., "PC1 (45.2%)"). Higher percentages mean the 2D view captures more of the grid's information.

**Controls:**
- Color Palette selector (Wong, Classic, Earth Tones, Contrast, Greyscale)
- Help button — interpretation guidance
- Chat button — ask Claude AI about the visualization
- Download as PNG

**Overlap handling:** When elements are close together, labels are automatically repositioned and scaled to remain readable.

### 4.4 Crossplot

A scatter plot showing elements positioned on two selected constructs. Unlike the biplot (which uses PCA to combine all constructs), the crossplot shows the raw ratings on exactly two constructs.

**Controls:**
- X-axis construct selector
- Y-axis construct selector
- Show Element Labels toggle
- Show Grid Lines toggle
- Color Palette selector

**Reading the crossplot:**

Each element is plotted at the intersection of its ratings on the two selected constructs. The midpoint of each axis is highlighted. Elements in the same quadrant share similar ratings on both constructs.

### 4.5 Synopsis

A distribution visualization showing the overall pattern of ratings across the grid. Useful for identifying:

- Response bias (tendency to use extremes or midpoint)
- Construct differentiation (how much the ratings vary)
- Overall grid structure

### 4.6 Heatmap

A color-coded matrix showing all ratings with elements as rows and constructs as columns.

**Controls:**
- Color Palette selector
- Show Values toggle — display rating numbers in cells
- Sort by similarity — reorder rows/columns by hierarchical clustering
- Cell Size slider

**Reading the heatmap:**

Dark/saturated colors indicate extreme ratings (1 or 7); light colors indicate midpoint ratings. Color patterns reveal which elements are rated similarly and which constructs co-vary.

### 4.7 Element Dendrogram

A hierarchical clustering tree (dendrogram) showing how elements group by similarity of their rating profiles.

**Controls:**
- Minkowski Power (0.5–3.0) — controls the distance metric. Power=1.0 uses city block (Manhattan) distance; Power=2.0 uses Euclidean distance.
- Match Cutoff (0–100%) — highlights matches above this threshold
- Color Palette selector

**Reading the dendrogram:**

Elements that join at low heights (short branches) are very similar in how they are construed. Elements that join at high heights are more different. The match percentages shown indicate the similarity between pairs or clusters.

### 4.8 Construct Dendrogram

The same hierarchical clustering analysis applied to constructs rather than elements. Shows how constructs group by similarity of their rating patterns across elements.

Note: Construct matching considers both the original and reversed orientation, taking the better match. This means constructs with similar meaning but opposite pole ordering will still cluster together.

### 4.9 Focus Cluster

Implements Shaw's (1980) FOCUS algorithm — the signature analysis of the RepPlus suite. FOCUS simultaneously clusters both elements and constructs and displays the result as a four-panel visualization:

- **Top:** Construct dendrogram (horizontal)
- **Left:** Element dendrogram (vertical)
- **Center:** Reordered rating matrix, sorted to reveal clusters
- **Right:** Match statistics

**Controls:**
- Minkowski Power (0.5–3.0)
- Match Cutoff (0–100%)
- Show Rating Values toggle
- Show Shading toggle
- Use Color Shading toggle
- SPACED variant — uses proportional spacing based on cophenetic distances, giving a more accurate representation of cluster distances
- Color Palette selector

**FOCI (Focus Interpretation):**
Click "Generate Interpretation" to send the Focus analysis to Claude AI for automated structured interpretation. This generates a narrative description of the main clusters, distinguishing constructs, and overall pattern of construing. See Section 6.2.

**Reading the Focus cluster:**

Look for blocks of similar ratings (same color/value) in the center matrix. These blocks represent clusters — groups of elements that are construed similarly on groups of related constructs. The dendrograms show the hierarchical structure of these clusters, and the match statistics quantify the similarity.

### 4.10 Statistics

Displays descriptive statistics for both elements and constructs:

- **Element statistics:** Mean and standard deviation of ratings received across all constructs
- **Construct statistics:** Mean and standard deviation of ratings given across all elements

High standard deviation indicates that a construct differentiates well between elements (or that an element receives varied ratings). Low standard deviation suggests a construct that does not discriminate (or an element rated uniformly).

---

## 5 Multi-Grid Analysis

Multi-grid analysis allows comparison of grids from different participants or the same participant at different times. All multi-grid operations normalize ratings to a common 1–7 scale before comparison.

### 5.1 Grid Collection

The management dashboard for working with multiple grids.

**Adding grids:**
- Use "Add to Collection" in the sidebar to upload multiple .json or .rgrid files
- Use "Add Current Grid" to add the grid currently loaded in the Build Grid tab
- Each grid receives a unique identifier

**Managing grids:**
- View grid metadata (name, number of elements, number of constructs)
- Select/deselect grids for analysis
- Remove grids from the collection
- Load any grid into the editor for inspection

**Common structure analysis:**
The tab displays which elements and constructs are shared across the selected grids. Multi-grid analyses require at least some shared structure.

### 5.2 Socionets

Network visualization showing similarity relationships between grids, based on Shaw's (1980) SOCIOGRIDS methodology.

**Reading socionets:**

- Each node represents one grid (one participant)
- Edges (connections) show match percentages between grids
- Edge thickness indicates match strength
- Directional arrows indicate asymmetric matching (how much of A's construing is shared by B, which may differ from B→A)

**Controls:**
- Match Cutoff — only show connections above this threshold
- Symmetric Matching toggle — use average of both directions
- Show Match Percentages toggle
- Node Color and Edge Color selectors
- Text Size slider

**Outputs:**
- Match Matrix table (all pairwise matches)
- Download match matrix as CSV
- Download network diagram as PNG

### 5.3 Mode Grid

Generates a consensus grid representing the "typical" pattern of construing across all grids in the collection.

**Methods:**
- **Average** — mean rating across all grids for each cell
- **Median** — middle value (more robust to outliers)

**Construct handling:**
- **Fold Identical** — merge constructs with the same poles
- **Collect All** — keep all constructs from all grids

The mode grid can be loaded as the current grid ("Use as Current Grid") for further single-grid analysis, allowing you to apply Focus, biplot, and other visualizations to the consensus pattern.

### 5.4 Composite Grid

Merges multiple grids into a single combined grid.

**Merge strategies:**
- **Common Elements + All Constructs** — keeps elements shared across all grids and combines all constructs
- **Common Constructs + All Elements** — keeps constructs shared across all grids and combines all elements

Useful for creating a comprehensive grid that includes the perspectives of multiple participants.

### 5.5 MINUS Analysis

Compares two grids by subtracting one from the other cell-by-cell. Requires two grids with shared elements AND shared constructs.

**Reading the MINUS grid:**

- Blue cells indicate where Grid A rates lower than Grid B
- White cells indicate agreement (zero difference)
- Orange cells indicate where Grid A rates higher than Grid B
- Larger absolute values indicate greater disagreement

Select Grid A and Grid B from the dropdowns. The difference grid reveals where two people (or the same person at two time points) disagree most.

### 5.6 CORE Analysis

Shaw's (1980) CORE algorithm identifies the shared core of construing between two grids by iteratively removing the elements and constructs with the least agreement.

**Process:**

1. Start with all shared elements and constructs
2. Calculate overall match percentage
3. Remove the element or construct that contributes most to disagreement
4. Recalculate and repeat
5. Stop when minimum thresholds are reached

**Controls:**
- Grid A and Grid B selectors
- Minimum elements (2–10)
- Minimum constructs (1–10)

**Outputs:**
- Core grid heatmap (the remaining elements and constructs after pruning)
- Removal log (step-by-step record of what was removed and the resulting improvement)
- "Analyse Core with FOCUS" button — runs Focus analysis on the remaining core

### 5.7 PrinGrid Trajectories

PCA biplot with trajectory arrows showing how elements move in construct space across multiple grids.

**Use cases:**
- Track how a person's construing changes over time (e.g., before and after an intervention)
- Compare how different participants position the same elements

**Reading the trajectory plot:**

Arrows connect the same element across successive grids. Long arrows indicate substantial change in how that element is construed. Short arrows or no movement indicate stability.

### 5.8 Exchange Grids

Implements Shaw's (1980) 6-grid exchange protocol for measuring agreement and understanding between two people.

The protocol requires six grids:

| Grid | Description |
|------|-------------|
| 1 | A's own grid (A rates elements on A's constructs) |
| 2 | B's own grid (B rates elements on B's constructs) |
| 3 | B fills A's grid (B rates elements on A's constructs as B would) |
| 4 | A fills B's grid (A rates elements on B's constructs as A would) |
| 5 | B predicts A (B predicts how A rated elements on A's constructs) |
| 6 | A predicts B (A predicts how B rated elements on B's constructs) |

**Comparison measures:**

- Grids 1 vs 3: Do A and B agree? (using A's constructs)
- Grids 2 vs 4: Do A and B agree? (using B's constructs)
- Grids 1 vs 5: Does B understand A?
- Grids 2 vs 6: Does A understand B?

### 5.9 Class Metagrids

Creates a higher-order grid where individual grids become the elements. You define bipolar constructs for evaluating grids (e.g., "concrete — abstract" or "focused — broad") and rate each grid on these meta-constructs.

The resulting metagrid can be loaded as the current grid for single-grid analysis, allowing you to use biplots and Focus clustering to explore relationships between participants' grid styles.

---

## 6 AI-Assisted Interpretation

WebGrid.Online integrates Claude AI to help interpret repertory grid analyses.

### 6.1 Chat with Claude

Each single-grid visualization tab includes a Chat button that opens an interpretation panel. You can:

- **Ask Claude (API)** — type a question and get a direct response from Claude. This requires a Claude API key to be configured on the server.
- **Copy to Clipboard** — generates a context prompt including your grid data and the relevant visualization, which you can paste into Claude.ai or another AI tool.
- **Open Claude.ai** — direct link to the Claude web interface.

Claude receives your grid data, the visualization parameters, and relevant RepPlus documentation to provide contextually informed interpretations.

### 6.2 FOCI: Focus Interpretation

The Focus Cluster tab includes a special "Generate Interpretation" button. This sends the full Focus analysis (cluster structure, match percentages, sorted matrix) to Claude and returns a structured narrative interpretation covering:

- Main element clusters and what they share
- Main construct clusters and how they relate
- Key distinguishing constructs
- Overall pattern of construing

### 6.3 Copy to Clipboard

For all chat-enabled visualizations, the "Copy to Clipboard" option generates a complete prompt including:

- Grid summary (elements, constructs, scale)
- Current ratings and statistics
- Visualization-specific data
- Your question

This can be pasted into any AI assistant for interpretation.

---

## 7 File Formats and Import/Export

### 7.1 Importing Grids

WebGrid.Online supports two import formats:

- **.json** — JSON format (see Section 7.4)
- **.rgrid** — RepPlus native format (see Section 7.5)

Use the **Import Grid** button in the sidebar for single-grid import. Use **Add to Collection** for importing multiple grids at once.

### 7.2 Exporting Grids and Visualizations

**Grid data:**
- Download Grid (CSV) — rating matrix as spreadsheet
- Download Grid (.rgrid) — native format for re-import
- Save Grid as JSON — structured format

**Visualizations:**
All plots can be downloaded as PNG images using the Download button on each tab.

**Multi-grid outputs:**
- Match matrices (CSV)
- Mode Grid and Composite Grid (.rgrid)
- Difference and removal logs (CSV)
- Trajectory positions (CSV)
- Exchange results (CSV)

### 7.3 Email Features

The guided wizard provides email buttons at key stages:

- **Email My Constructs** — after triadic elicitation, sends your elements and construct list
- **Email My Chart** — after rating, sends your complete grid data

Email content is formatted as JSON for direct re-import into WebGrid.Online. To import from an email:

1. Copy the JSON content from the email body
2. Paste into a text file and save with a `.json` extension
3. Import using the Import Grid button

### 7.4 JSON Format

```json
{
  "name": "My Repertory Grid",
  "elements": ["Element 1", "Element 2", "Element 3"],
  "constructs": [
    {"left": "creative", "right": "methodical"},
    {"left": "formal", "right": "informal"}
  ],
  "ratings": [
    {"element": "Element 1", "construct": "creative - methodical", "rating": 2},
    {"element": "Element 2", "construct": "creative - methodical", "rating": 4}
  ],
  "scale": [1, 5]
}
```

### 7.5 .rgrid Format

The native RepPlus format stores grids as structured plain text:

```
ELEMENTS
Element 1
Element 2
Element 3
CONSTRUCTS
creative | methodical
formal | informal
RATINGS
Element 1 | creative - methodical | 2
Element 2 | creative - methodical | 4
```

---

## 8 References

Gaines, B.R. & Shaw, M.L.G. (2021). *Rep Plus Conceptual Representation Software.* University of Calgary. http://cpsc.ucalgary.ca/~gaines/repplus/

Kelly, G.A. (1955). *The Psychology of Personal Constructs.* New York: Norton.

Shaw, M.L.G. (1980). *On Becoming a Personal Scientist: Interactive Computer Elicitation of Personal Models of the World.* London: Academic Press.

Shaw, M.L.G. (1980). SOCIOGRIDS methodology for multi-grid comparison. In M.L.G. Shaw (Ed.), *Recent Advances in Personal Construct Technology.* London: Academic Press.

---

*WebGrid.Online is developed by Elizabeth Black, building on the RepPlus suite by Brian R Gaines and Mildred L G Shaw. AI interpretation features powered by Anthropic Claude.*
