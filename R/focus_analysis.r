# Focus clustering analysis functions
# Based on Shaw (1980) FOCUS algorithm from RepGrid manual

#' Compute element-element similarity matrix
compute_element_similarities <- function(scores_matrix, power = 1.0) {
  n_elements <- nrow(scores_matrix)
  sim_matrix <- matrix(0, nrow = n_elements, ncol = n_elements)
  
  for (i in 1:n_elements) {
    for (j in 1:n_elements) {
      if (i == j) {
        sim_matrix[i, j] <- 100
      } else {
        # Minkowski distance with specified power
        diff_vec <- abs(scores_matrix[i, ] - scores_matrix[j, ])
        diff_vec <- diff_vec[!is.na(diff_vec)]
        if (length(diff_vec) > 0) {
          distance <- sum(diff_vec^power)^(1/power)
          max_distance <- length(diff_vec) * (max(scores_matrix, na.rm = TRUE) - min(scores_matrix, na.rm = TRUE))
          similarity <- max(0, 100 * (1 - distance / max_distance))
          sim_matrix[i, j] <- similarity
        }
      }
    }
  }
  sim_matrix
}

#' Compute construct-construct similarity matrix  
compute_construct_similarities <- function(scores_matrix, power = 1.0) {
  n_constructs <- ncol(scores_matrix)
  sim_matrix <- matrix(0, nrow = n_constructs, ncol = n_constructs)
  
  for (i in 1:n_constructs) {
    for (j in 1:n_constructs) {
      if (i == j) {
        sim_matrix[i, j] <- 100
      } else {
        # Try both normal and reversed construct
        diff_normal <- abs(scores_matrix[, i] - scores_matrix[, j])
        diff_reversed <- abs(scores_matrix[, i] - (max(scores_matrix, na.rm = TRUE) + min(scores_matrix, na.rm = TRUE) - scores_matrix[, j]))
        
        diff_normal <- diff_normal[!is.na(diff_normal)]
        diff_reversed <- diff_reversed[!is.na(diff_reversed)]
        
        if (length(diff_normal) > 0) {
          dist_normal <- sum(diff_normal^power)^(1/power)
          dist_reversed <- sum(diff_reversed^power)^(1/power)
          
          # Use the better match (normal or reversed)
          distance <- min(dist_normal, dist_reversed)
          max_distance <- length(diff_normal) * (max(scores_matrix, na.rm = TRUE) - min(scores_matrix, na.rm = TRUE))
          similarity <- max(0, 100 * (1 - distance / max_distance))
          sim_matrix[i, j] <- similarity
        }
      }
    }
  }
  sim_matrix
}

#' Perform Focus clustering and sorting
focus_cluster <- function(scores_matrix, element_names, construct_names, power = 1.0) {
  # Compute similarities
  elem_sim <- compute_element_similarities(scores_matrix, power)
  const_sim <- compute_construct_similarities(scores_matrix, power)
  
  # Hierarchical clustering
  elem_dist <- as.dist(100 - elem_sim)
  const_dist <- as.dist(100 - const_sim)
  
  elem_hclust <- hclust(elem_dist, method = "complete")
  const_hclust <- hclust(const_dist, method = "complete")
  
  # Sort according to clustering
  elem_order <- elem_hclust$order
  const_order <- const_hclust$order
  
  # Reorder matrix and names
  sorted_matrix <- scores_matrix[elem_order, const_order, drop = FALSE]
  sorted_elements <- element_names[elem_order]
  sorted_constructs <- construct_names[const_order]
  
  list(
    sorted_matrix = sorted_matrix,
    sorted_elements = sorted_elements,
    sorted_constructs = sorted_constructs,
    element_hclust = elem_hclust,
    construct_hclust = const_hclust,
    element_similarities = elem_sim,
    construct_similarities = const_sim,
    element_order = elem_order,
    construct_order = const_order
  )
}

#' Plot Focus cluster analysis with dendrograms
plot_focus_cluster <- function(focus_result, title = "Focus Cluster Analysis",
                              show_values = TRUE, show_shading = TRUE, use_color = FALSE,
                              text_size = 1.0, cell_size = 1.0,
                              heat_low = "#0072B2", heat_high = "#D55E00") {

  # Get dimensions for adaptive layout
  n_elem <- nrow(focus_result$sorted_matrix)
  n_const <- ncol(focus_result$sorted_matrix)
  sorted_matrix <- focus_result$sorted_matrix

  # Calculate adaptive margins FIRST so dendrograms can use them
  max_elem_chars <- max(nchar(focus_result$sorted_elements))
  max_const_chars <- max(nchar(focus_result$sorted_constructs))
  left_mar <- min(12 * text_size, max(4, max_elem_chars * 0.4 * text_size))
  bottom_mar <- min(10 * text_size, max(4, max_const_chars * 0.25 * text_size))

  # Set up plotting layout: dendrograms + main plot
  layout_matrix <- matrix(c(0, 1, 0,
                           2, 3, 4),
                         nrow = 2, byrow = TRUE)

  # Make dendrogram heights proportional but not too small
  dendro_height <- max(0.15, min(0.22, 0.18))
  main_height <- 1 - dendro_height

  # Side panels proportional to content
  side_width <- max(0.14, min(0.20, 0.17))
  main_width <- 1 - 2 * side_width

  layout(layout_matrix,
         widths = c(side_width, main_width, side_width),
         heights = c(dendro_height, main_height))

  # Top dendrogram (constructs) - left margin matches main grid
  par(mar = c(0, left_mar, 2, 0.5), cex = text_size, cex.main = text_size * 1.2)
  plot(as.dendrogram(focus_result$construct_hclust),
       horiz = FALSE, leaflab = "none",
       main = title, axes = FALSE)

  # Left dendrogram (elements) - bottom margin matches main grid
  par(mar = c(bottom_mar, 0, 0.5, 0), cex = text_size)
  plot(as.dendrogram(focus_result$element_hclust),
       horiz = TRUE, leaflab = "none", axes = FALSE)

  # Main grid plot
  par(mar = c(bottom_mar, left_mar, 0.5, 0.5), cex = text_size)

  # Create image plot - NO asp=1 to allow proper sizing
  if (show_shading) {
    # Use greyscale by default, color if requested with palette colors
    if (use_color) {
      colors <- colorRampPalette(c(heat_low, "#FFFFFF", heat_high))(100)
    } else {
      colors <- gray.colors(100, start = 0.95, end = 0.2)
    }
    image(1:n_const, 1:n_elem, t(sorted_matrix[n_elem:1, , drop = FALSE]),
          col = colors, axes = FALSE, xlab = "", ylab = "")
  } else {
    # Just boxes without aspect constraint
    plot(1, type = "n", xlim = c(0.5, n_const + 0.5), ylim = c(0.5, n_elem + 0.5),
         xlab = "", ylab = "", axes = FALSE)

    for (i in 1:n_elem) {
      for (j in 1:n_const) {
        rect(j - 0.4, (n_elem - i + 1) - 0.4, j + 0.4, (n_elem - i + 1) + 0.4)
      }
    }
  }

  # Add values if requested
  if (show_values) {
    # Scale text size - minimum 1.0 cex (~12pt) for readability
    base_cex <- max(1.0, min(1.4, 18 / max(n_elem, n_const)))
    value_cex <- base_cex * cell_size * text_size

    for (i in 1:n_elem) {
      for (j in 1:n_const) {
        val <- sorted_matrix[i, j]
        if (!is.na(val)) {
          text(j, n_elem - i + 1, sprintf("%.0f", val), cex = value_cex)
        }
      }
    }
  }

  # Add axis labels with adaptive sizing - scale with text_size
  # Calculate label size based on number of items - larger minimum
  const_cex <- min(0.9, max(0.55, 12 / n_const)) * text_size
  elem_cex <- min(0.9, max(0.55, 12 / n_elem)) * text_size

  axis(1, at = 1:n_const, labels = focus_result$sorted_constructs,
       las = 2, cex.axis = const_cex, tck = -0.02)
  axis(2, at = 1:n_elem, labels = rev(focus_result$sorted_elements),
       las = 2, cex.axis = elem_cex, tck = -0.02)
  box()

  # Right panel - similarity matrices or stats
  par(mar = c(4, 1, 0, 2))

  # Plot element similarities as text
  elem_sim <- focus_result$element_similarities[focus_result$element_order, focus_result$element_order]
  plot(1, type = "n", xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, xlab = "", ylab = "")

  # Show top matches - scale with text_size
  text(0.5, 0.9, "Element Matches", font = 2, cex = 0.8 * text_size)

  # Find and display top similarities (excluding diagonal)
  elem_sim_no_diag <- elem_sim
  diag(elem_sim_no_diag) <- 0

  if (n_elem > 1) {
    top_matches <- which(elem_sim_no_diag == max(elem_sim_no_diag, na.rm = TRUE), arr.ind = TRUE)[1, ]
    match_val <- elem_sim_no_diag[top_matches[1], top_matches[2]]
    match_text <- paste0(focus_result$sorted_elements[top_matches[1]], " - ",
                        focus_result$sorted_elements[top_matches[2]], "\n",
                        round(match_val, 1), "%")
    text(0.5, 0.7, match_text, cex = 0.6 * text_size)
  }

  # Reset layout
  layout(1)
}

#' Plot Focus cluster with SPACED proportional spacing
#' Spaces rows/columns proportionally to their similarity distances
plot_focus_spaced <- function(focus_result, title = "SPACED: Focus Cluster Analysis",
                              show_values = TRUE, show_shading = TRUE, use_color = FALSE,
                              text_size = 1.0, cell_size = 1.0,
                              heat_low = "#0072B2", heat_high = "#D55E00") {
  n_elem <- nrow(focus_result$sorted_matrix)
  n_const <- ncol(focus_result$sorted_matrix)
  sorted_matrix <- focus_result$sorted_matrix

  # Compute spacing from cophenetic distances
  elem_coph <- as.matrix(cophenetic(focus_result$element_hclust))
  const_coph <- as.matrix(cophenetic(focus_result$construct_hclust))

  # Get ordered cophenetic distances between adjacent items
  elem_order <- focus_result$element_order
  const_order <- focus_result$construct_order

  # Element positions: cumulative distances between adjacent sorted items
  elem_pos <- numeric(n_elem)
  elem_pos[1] <- 1
  if (n_elem > 1) {
    for (i in 2:n_elem) {
      dist <- elem_coph[elem_order[i-1], elem_order[i]]
      # Scale: small distance = close together, large = far apart
      # Normalize to reasonable spacing (min 0.5, max 2.0 units)
      spacing <- 0.5 + (dist / max(elem_coph)) * 1.5
      elem_pos[i] <- elem_pos[i-1] + spacing
    }
  }

  # Construct positions: same approach
  const_pos <- numeric(n_const)
  const_pos[1] <- 1
  if (n_const > 1) {
    for (j in 2:n_const) {
      dist <- const_coph[const_order[j-1], const_order[j]]
      spacing <- 0.5 + (dist / max(const_coph)) * 1.5
      const_pos[j] <- const_pos[j-1] + spacing
    }
  }

  # Calculate adaptive margins
  max_elem_chars <- max(nchar(focus_result$sorted_elements))
  max_const_chars <- max(nchar(focus_result$sorted_constructs))
  left_mar <- min(12 * text_size, max(4, max_elem_chars * 0.4 * text_size))
  bottom_mar <- min(10 * text_size, max(4, max_const_chars * 0.25 * text_size))

  # Set up layout: dendrograms + main plot
  layout_matrix <- matrix(c(0, 1, 0,
                           2, 3, 4),
                         nrow = 2, byrow = TRUE)

  dendro_height <- max(0.15, min(0.22, 0.18))
  main_height <- 1 - dendro_height
  side_width <- max(0.14, min(0.20, 0.17))
  main_width <- 1 - 2 * side_width

  layout(layout_matrix,
         widths = c(side_width, main_width, side_width),
         heights = c(dendro_height, main_height))

  # Top dendrogram (constructs)
  par(mar = c(0, left_mar, 2, 0.5), cex = text_size, cex.main = text_size * 1.2)
  plot(as.dendrogram(focus_result$construct_hclust),
       horiz = FALSE, leaflab = "none",
       main = title, axes = FALSE)

  # Left dendrogram (elements)
  par(mar = c(bottom_mar, 0, 0.5, 0), cex = text_size)
  plot(as.dendrogram(focus_result$element_hclust),
       horiz = TRUE, leaflab = "none", axes = FALSE)

  # Main grid plot with proportional spacing
  par(mar = c(bottom_mar, left_mar, 0.5, 0.5), cex = text_size)

  # Cell half-widths for rect drawing
  elem_hw <- min(diff(elem_pos), 0.5) / 2 * 0.9
  const_hw <- min(diff(const_pos), 0.5) / 2 * 0.9
  if (n_elem == 1) elem_hw <- 0.4
  if (n_const == 1) const_hw <- 0.4

  # Set up colors
  if (show_shading) {
    if (use_color) {
      color_ramp <- colorRampPalette(c(heat_low, "#FFFFFF", heat_high))(100)
    } else {
      color_ramp <- gray.colors(100, start = 0.95, end = 0.2)
    }
    val_range <- range(sorted_matrix, na.rm = TRUE)
    if (diff(val_range) == 0) val_range <- c(val_range[1] - 0.5, val_range[2] + 0.5)
  }

  # Plot area
  plot(1, type = "n",
       xlim = c(const_pos[1] - const_hw * 1.5, const_pos[n_const] + const_hw * 1.5),
       ylim = c(elem_pos[1] - elem_hw * 1.5, elem_pos[n_elem] + elem_hw * 1.5),
       xlab = "", ylab = "", axes = FALSE)

  # Draw cells as rectangles at non-uniform positions
  for (i in 1:n_elem) {
    for (j in 1:n_const) {
      val <- sorted_matrix[i, j]
      y <- elem_pos[n_elem - i + 1]  # Flip for top-first display
      x <- const_pos[j]

      if (show_shading && !is.na(val)) {
        color_idx <- max(1, min(100, round((val - val_range[1]) / diff(val_range) * 99) + 1))
        bg_col <- color_ramp[color_idx]
      } else {
        bg_col <- "white"
      }

      rect(x - const_hw, y - elem_hw, x + const_hw, y + elem_hw,
           col = bg_col, border = "gray80")

      if (show_values && !is.na(val)) {
        base_cex <- max(1.0, min(1.4, 18 / max(n_elem, n_const)))
        value_cex <- base_cex * cell_size * text_size
        text(x, y, sprintf("%.0f", val), cex = value_cex)
      }
    }
  }

  # Axis labels at non-uniform positions
  const_cex <- min(0.9, max(0.55, 12 / n_const)) * text_size
  elem_cex <- min(0.9, max(0.55, 12 / n_elem)) * text_size

  axis(1, at = const_pos, labels = focus_result$sorted_constructs,
       las = 2, cex.axis = const_cex, tck = -0.02)
  axis(2, at = rev(elem_pos), labels = rev(focus_result$sorted_elements),
       las = 2, cex.axis = elem_cex, tck = -0.02)

  # Right panel - similarity info
  par(mar = c(4, 1, 0, 2))
  elem_sim <- focus_result$element_similarities[focus_result$element_order, focus_result$element_order]
  plot(1, type = "n", xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, xlab = "", ylab = "")

  text(0.5, 0.9, "Element Matches", font = 2, cex = 0.8 * text_size)

  if (n_elem > 1) {
    elem_sim_no_diag <- elem_sim
    diag(elem_sim_no_diag) <- 0
    top_matches <- which(elem_sim_no_diag == max(elem_sim_no_diag, na.rm = TRUE), arr.ind = TRUE)[1, ]
    match_val <- elem_sim_no_diag[top_matches[1], top_matches[2]]
    match_text <- paste0(focus_result$sorted_elements[top_matches[1]], " - ",
                        focus_result$sorted_elements[top_matches[2]], "\n",
                        round(match_val, 1), "%")
    text(0.5, 0.7, match_text, cex = 0.6 * text_size)
  }

  text(0.5, 0.4, "Spacing shows\nsimilarity distance", cex = 0.5 * text_size, col = "gray50")

  layout(1)
}