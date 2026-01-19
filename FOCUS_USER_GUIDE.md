# Focus Cluster Analysis - User Guide

## What is Focus Analysis?

Focus analysis automatically **sorts your repertory grid** to show patterns in your data. Elements that are similar appear together, and constructs that are similar appear together. This makes it much easier to see:
- Which elements cluster together (similar items)
- Which constructs cluster together (similar ways of thinking)
- The hierarchical structure of your conceptual space

## Quick Start

### Step 1: Prepare Your Grid
1. Click "Load Sample Data" or import your own .rgrid file
2. Or build a grid manually by adding elements, constructs, and ratings
3. Click "Analyze Grid" button

### Step 2: Run Focus Analysis
1. Navigate to the **"Focus Cluster"** tab
2. Click the **"Run Focus Analysis"** button
3. View your sorted grid with cluster trees

That's it! The grid is now sorted to show similar items together.

## Understanding the Display

### The Focus Plot Shows 4 Parts:

```
┌─────────────────────────────────┐
│   Construct Dendrogram (top)   │ ← Shows how constructs cluster
├────┬────────────────────┬───────┤
│ E  │                    │ Match │
│ l  │   Sorted Grid      │ Stats │
│ e  │   (center)         │ Panel │
│ m  │                    │       │
│ e  │                    │       │
│ n  │                    │       │
│ t  │                    │       │
│    │                    │       │
│ D  │                    │       │
│ e  │                    │       │
│ n  │                    │       │
│ d  │                    │       │
└────┴────────────────────┴───────┘
```

1. **Top Dendrogram**: Shows how constructs (columns) are related
2. **Left Dendrogram**: Shows how elements (rows) are related
3. **Center Grid**: Your ratings, sorted so similar items are together
4. **Right Panel**: Top matches and statistics

### Reading the Dendrograms

- **Short connections** = very similar items
- **Long connections** = less similar items
- **Height** = how different items are when they join

Example:
```
    │
    ├─┬── E1  ← E1 and E2 are very similar (join low)
    │ └── E2
    │
    └──── E3  ← E3 is different from E1/E2 (joins high)
```

## Adjusting the Parameters

### Minkowski Power (Default: 1.0)
Controls how distance is calculated:
- **1.0** = City block distance (default, recommended)
  - Treats all rating differences equally
  - Better for categorical-style ratings
- **2.0** = Euclidean distance
  - Emphasizes larger differences
  - Better for continuous measurements

**When to change**: Mostly leave at 1.0. Try 2.0 if you want to emphasize extreme differences.

### Match Cutoff % (Default: 80%)
Shows only matches above this similarity level:
- **80-100%**: Only very strong matches
- **60-80%**: Moderate to strong matches
- **0-60%**: All matches (can be overwhelming)

**When to change**: Lower the cutoff if you see "No matches above threshold" and want to see weaker patterns.

### Show Rating Values
Displays the actual numbers in each cell:
- ✓ **Checked** (default): See the exact ratings
- ☐ **Unchecked**: Just see the color pattern

**When to change**: Uncheck for a cleaner view if you have many elements/constructs.

### Show Color Shading
Color-codes the cells:
- ✓ **Checked** (default): Blue = low, White = mid, Red = high
- ☐ **Unchecked**: No colors, just grid lines

**When to change**: Uncheck if printing in black & white.

## Interpreting the Results

### Element Matches (bottom left)
Shows which elements are most similar:
```
Top Element Matches:
  E2 - E4: 87.5%  ← E2 and E4 are 87.5% similar
  E1 - E3: 76.3%
```

**What this means**: Elements with high similarity were rated similarly across most constructs.

### Construct Matches (bottom right)
Shows which constructs are most similar:
```
Top Construct Matches:
  friendly-unfriendly - warm-cold: 92.1%
```

**What this means**: These constructs essentially measure the same thing in your grid. You might be using redundant dimensions.

## Common Use Cases

### 1. Finding Element Groups
**Goal**: Which items naturally cluster together?

**Look at**: Left dendrogram
- Items that join early (low on tree) = very similar group
- Items that join late (high on tree) = distinct categories

**Example**: In a grid about people, you might see family members cluster separately from colleagues.

### 2. Identifying Redundant Constructs
**Goal**: Am I using the same construct twice?

**Look at**: Construct matches (bottom right)
- Matches above 90% = probably redundant
- Consider removing one or refining the distinction

**Example**: "smart-dumb" and "intelligent-stupid" might be 95% matched.

### 3. Discovering Construct Dimensions
**Goal**: What are my main ways of thinking about this topic?

**Look at**: Top dendrogram
- Major branches = major conceptual dimensions
- Sub-branches = related sub-categories

**Example**: In a product grid, one branch might be "aesthetic" constructs, another "functional" constructs.

### 4. Finding Outliers
**Goal**: Which items don't fit the pattern?

**Look at**: Items that join the dendrogram very late (high up)
- These elements are rated very differently from others
- May be truly unique or may contain rating errors

## Tips and Tricks

### ✓ DO:
- Run Focus analysis after completing your grid
- Look for clusters that make sense to you
- Use high matches to identify redundant constructs
- Compare the sorted view with your original understanding

### ✗ DON'T:
- Over-interpret small differences in similarity (75% vs 77%)
- Assume the algorithm found "the truth" - it's showing patterns in YOUR ratings
- Delete constructs just because they have high matches - first ask if the distinction matters to you

## Downloading Your Results

Click **"Download Focus Plot"** to save a high-resolution PNG image (1200×900 pixels) suitable for:
- Including in reports or presentations
- Sharing with colleagues
- Printing

## Troubleshooting

### "Missing ratings detected"
**Problem**: You have incomplete data in your grid.

**Solution**:
- Either complete all ratings
- Or check "Impute missing ratings (use 4)" in the sidebar
- Then click "Analyze Grid" again

### "No matches above cutoff threshold"
**Problem**: Your cutoff is too high, or your data is very diverse.

**Solution**:
- Lower the "Match Cutoff %" slider (try 60% or 50%)
- Click "Run Focus Analysis" again

### Plot looks crowded
**Problem**: Too many elements/constructs to display clearly.

**Solution**:
- Uncheck "Show Rating Values" for a cleaner view
- Keep "Show Color Shading" to see the pattern
- Use the download button to get a larger image you can zoom

### Dendrograms are hard to read
**Problem**: Labels overlap or are too small.

**Solution**:
- Download the plot for a larger view
- Consider using shorter element/construct names
- Focus on the pattern/structure rather than reading every label

## Example Interpretation

Imagine you rated 5 wines on 4 constructs:

**After Focus analysis you see:**
- Wines W1 and W2 cluster together (both red, full-bodied)
- Wines W4 and W5 cluster together (both white, light)
- Wine W3 is separate (rosé, unique)
- Constructs "full-bodied" and "heavy" are 88% matched

**Interpretation:**
- Your main distinction is red vs white wines
- Rosé doesn't fit either category
- "Full-bodied" and "heavy" essentially mean the same thing to you for wines
- Consider: Do you need both constructs, or are they redundant?

## Questions?

See the full documentation in [FOCUS_IMPLEMENTATION.md](FOCUS_IMPLEMENTATION.md) for technical details.

---

**Happy Clustering!** 🎯
