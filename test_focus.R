# Quick test of Focus analysis functions
library(OpenRepGrid)

# Source the focus analysis functions
source("R/focus_analysis.r")

# Create a simple test grid
test_matrix <- matrix(
  c(1, 5, 3, 6, 2,
    7, 2, 4, 1, 6,
    3, 4, 5, 5, 3,
    6, 1, 2, 7, 1),
  nrow = 4, byrow = TRUE
)

element_names <- c("E1", "E2", "E3", "E4")
construct_names <- c("C1", "C2", "C3", "C4", "C5")

# Test focus cluster
result <- focus_cluster(
  scores_matrix = test_matrix,
  element_names = element_names,
  construct_names = construct_names,
  power = 1.0
)

# Check result structure
cat("Focus cluster result:\n")
cat("Sorted elements:", result$sorted_elements, "\n")
cat("Sorted constructs:", result$sorted_constructs, "\n")
cat("\nElement similarities (first 3x3):\n")
print(round(result$element_similarities[1:3, 1:3], 1))

# Test plot
cat("\nGenerating plot...\n")
png("test_focus_plot.png", width = 1000, height = 800)
plot_focus_cluster(result, show_values = TRUE, show_shading = TRUE)
dev.off()
cat("Plot saved to test_focus_plot.png\n")
