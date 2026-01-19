# Quick Start Guide: Testing RepPlusApp with Contact Lens Data

## 1. Start the App

In RStudio Console:
```r
shiny::runApp()
```

The app will open in your browser at http://127.0.0.1:3838

## 2. Load the Contact Lens Dataset

1. In the left sidebar, find **"Import .rgrid"**
2. Click **"Choose File"** (or "Browse...")
3. Navigate to: `dataExamples/contact_lens.rgrid`
4. Click **"Load Grid"** button

The grid will load instantly with:
- **24 elements** (Case 1 through Case 24)
- **4 constructs** (age, prescription, astigmatism, tear production)
- **96 ratings** (complete grid, no missing data)

## 3. Analyze the Grid

Click the **"Analyze Grid"** button in the sidebar.

## 4. Explore the Visualizations

Navigate through the tabs to see different analyses:

### Summary & Biplot Tab
- View the list of elements and constructs
- Check the analysis summary statistics
- See the **PCA Biplot** showing element positions and construct vectors

### Crossplot Tab
- Select two constructs from the dropdowns (e.g., X: age, Y: tear_production)
- View elements plotted in 2D space
- Toggle element labels and grid lines
- Download as PNG

### Synopsis Tab
Choose from the Display dropdown:
- **Overall Distribution**: Histogram of all 96 ratings
- **Element Distributions**: Individual histograms for each of 24 cases
- **Construct Distributions**: Individual histograms for each of 4 constructs
- **Scree Plot**: Variance explained by principal components

### Heatmap Tab
- View the 24×4 grid with color-coded ratings
- Elements are clustered by similarity
- Toggle "Use color heatmap" checkbox for different color schemes

### Element Dendrogram Tab
- Hierarchical clustering tree showing which patient cases are most similar
- Cases with similar attribute profiles cluster together

### Construct Dendrogram Tab
- Hierarchical clustering tree showing which attributes co-vary
- Shows relationships between the 4 patient attributes

### Focus Cluster Tab
1. Click **"Run Focus Analysis"** button
2. The plot will show:
   - Dendrograms on top (elements) and left (constructs)
   - Sorted grid with similar elements/constructs grouped together
   - Rating values displayed in cells
3. Adjust parameters:
   - **Minkowski Power**: 1.0 (city block) or 2.0 (Euclidean)
   - **Match Cutoff**: Filter similarity percentages (try 80%)
   - Toggle rating values and shading
4. View **Match Data** below the plot to see similarity percentages
5. Download as high-resolution PNG

### Statistics Tab
- Element statistics (mean, SD, etc. for each case)
- Construct statistics (mean, SD, etc. for each attribute)

## 5. Export Your Analysis

In the sidebar:
- **Download Grid as CSV**: Export ratings table
- **Download Grid as .rgrid**: Export in RepPlus format
- **Download [Plot Name]**: Available on Crossplot, Synopsis, and Focus tabs

## Expected Results

The contact lens dataset has interesting characteristics:

- **Binary constructs**: Most constructs only use values 1 or 7 (yes/no, myope/hypermetrope)
- **Ternary age construct**: Uses 1, 4, and 7 (young, pre-presbyopic, presbyopic)
- **Distinct clusters**: Elements form clear groups based on shared attributes
- **High variance**: First 2 PCs typically explain ~75% of variance
- **Perfect data**: No missing ratings, no need for imputation

## Troubleshooting

**Error: "Some ratings are missing"**
- Make sure you clicked "Load Grid" after selecting the file
- The contact lens dataset is complete, so this shouldn't occur

**Nothing happens when I click Analyze**
- Make sure the grid loaded successfully (check Summary & Biplot tab for element/construct lists)
- Try clicking "Load Grid" again

**Visualizations look wrong**
- Try toggling the color options (element color, construct color, heatmap color)
- Download the plot and view it separately if the browser rendering is unclear

## Next Steps

After exploring the contact lens data:
1. Try loading other example grids from `dataExamples/` (binit.rgrid, budhawa.rgrid, etc.)
2. Create your own grid using the manual entry tools in the sidebar
3. Use "Load Sample Data" to see a minimal 3×3 grid example
4. Import your own .rgrid files or create new grids from scratch

For more details, see [CONTACT_LENS_INSTRUCTIONS.md](CONTACT_LENS_INSTRUCTIONS.md)
