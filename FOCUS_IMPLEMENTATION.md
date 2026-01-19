# Focus Cluster Analysis - Implementation Summary

## Overview
Successfully implemented Shaw's (1980) Focus algorithm for RepPlusApp. The Focus analysis sorts elements and constructs by similarity and displays them with hierarchical cluster dendrograms.

## What Was Added

### 1. **UI Components** ([app.R](app.R) lines 65-107)
- New "Focus Cluster" tab in the main tabset panel
- Interactive controls:
  - **Minkowski Power slider**: Adjusts distance metric (0.5 to 3.0, default 1.0)
    - 1.0 = City block metric (Manhattan distance) - default
    - 2.0 = Euclidean metric
  - **Match Cutoff slider**: Sets minimum similarity % to display (0-100%, default 80%)
  - **Show Rating Values checkbox**: Toggles display of numeric values in grid
  - **Show Color Shading checkbox**: Toggles color-coded heatmap
  - **Run Focus Analysis button**: Triggers the analysis
  - **Download Focus Plot button**: Exports plot as PNG

### 2. **Server Logic** ([app.R](app.R) lines 494-604)
- **Focus computation**: Reactive event handler for `run_focus` button
- **Plot rendering**: Displays sorted grid with dendrograms
- **Match data output**: Shows element and construct similarity matrices
- **Download handler**: Exports high-resolution PNG (1200x900, 120 DPI)

### 3. **Core Analysis Functions** ([R/focus_analysis.r](R/focus_analysis.r))

#### `compute_element_similarities(scores_matrix, power = 1.0)`
- Calculates element-element similarity matrix
- Uses Minkowski distance metric with configurable power
- Returns similarity as percentage (0-100%)

#### `compute_construct_similarities(scores_matrix, power = 1.0)`
- Calculates construct-construct similarity matrix
- **Special feature**: Tests both normal and reversed constructs
- Automatically finds best match (normal or reversed)
- Returns similarity as percentage (0-100%)

#### `focus_cluster(scores_matrix, element_names, construct_names, power = 1.0)`
- Main clustering function
- Performs hierarchical clustering on elements and constructs
- Sorts matrix rows and columns by cluster order
- Returns complete result object with:
  - Sorted matrix
  - Sorted element/construct names
  - Hierarchical cluster objects
  - Similarity matrices
  - Sort orders

#### `plot_focus_cluster(focus_result, title, show_values, show_shading)`
- Visualization function
- Creates 4-panel layout:
  1. Top: Construct dendrogram
  2. Left: Element dendrogram
  3. Center: Sorted grid matrix (with optional values/shading)
  4. Right: Match statistics panel
- Color-coded heatmap option (blue-white-red palette)
- Displays top element matches

## How It Works

### The Focus Algorithm (Shaw, 1980)
1. **Calculate Similarities**: Compute distance-based similarities between all pairs of elements and all pairs of constructs
2. **Hierarchical Clustering**: Apply hierarchical clustering (complete linkage) to both dimensions
3. **Sort**: Reorder matrix rows (elements) and columns (constructs) according to cluster dendrograms
4. **Display**: Show sorted matrix with dendrograms showing hierarchical structure

### Key Features Matching RepGrid Documentation
✅ Minkowski distance metric with configurable power
✅ Construct reversal (matches constructs in normal or reversed form)
✅ Hierarchical cluster trees displayed with sorted grid
✅ Similarity matrix as percentages
✅ Configurable cutoff for displaying matches
✅ Color shading for high/low values
✅ Optional display of numeric ratings

## Usage

### In the Shiny App:
1. Load or create a grid (elements, constructs, ratings)
2. Click "Analyze Grid" to prepare the data
3. Navigate to the "Focus Cluster" tab
4. Adjust parameters as desired (power, cutoff, display options)
5. Click "Run Focus Analysis"
6. View the sorted grid with dendrograms
7. Examine element and construct match data below the plot
8. Download the plot using "Download Focus Plot" button

### Example Data Flow:
```r
# User loads sample data
# Grid: 3 elements × 3 constructs with ratings 1-7

# Focus analysis:
# - Calculates 3×3 element similarity matrix
# - Calculates 3×3 construct similarity matrix
# - Clusters both dimensions
# - Reorders to show: similar elements together, similar constructs together
# - Displays with dendrograms showing cluster hierarchy
```

## Testing

A test script is provided: [test_focus.R](test_focus.R)

```bash
Rscript test_focus.R
```

This creates a sample 4×5 grid, runs Focus clustering, and generates a test plot.

## Technical Details

### Similarity Calculation
- **Distance**: Minkowski metric with power p: `d = (Σ|xi - yi|^p)^(1/p)`
- **Similarity**: Converted to percentage: `sim = 100 × (1 - d/max_d)`
- **Construct matching**: Tests both normal and reversed, uses better match

### Clustering Method
- Algorithm: Hierarchical agglomerative clustering
- Linkage: Complete linkage (maximum distance)
- Distance: `100 - similarity` (converts similarity to distance)

### Visualization Layout
- 4-panel grid layout using base R graphics `layout()`
- Proportions: dendrograms 20%, main plot 80%
- Color palette: Blue-White-Red diverging for heatmap
- Text overlays for rating values (optional)

## Files Modified/Created

### Modified:
- **[app.R](app.R)**: Added Focus UI tab and server logic

### Existing (already present):
- **[R/focus_analysis.r](R/focus_analysis.r)**: Core Focus algorithm implementation

### Created:
- **[test_focus.R](test_focus.R)**: Test script for Focus functions
- **[FOCUS_IMPLEMENTATION.md](FOCUS_IMPLEMENTATION.md)**: This documentation

## References

- Shaw, M. L. G. (1980). *On Becoming a Personal Scientist: Interactive Computer Elicitation of Personal Models of the World*. Academic Press, London.
- RepGrid Manual sections 5.3 (Focus: Sorting by similarity and hierarchical clustering)

## Next Steps (Optional Enhancements)

Potential future improvements:
- [ ] Interior matching option (match against interior cluster items, not just edges)
- [ ] Alternative linkage methods (single, average, Ward's)
- [ ] Interactive dendrogram (click to expand/collapse branches)
- [ ] Export sorted matrix as CSV
- [ ] Comparison with original (unsorted) grid
- [ ] Highlight matches above cutoff threshold in matrix
- [ ] Show R-value indicators in construct labels (reversed constructs)

---

**Implementation completed**: November 19, 2024
**Status**: ✅ Fully functional and tested
