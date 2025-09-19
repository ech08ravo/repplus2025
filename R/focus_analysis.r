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
                              show_values = TRUE, show_shading = TRUE) {
  
  # Set up plotting layout: dendrograms + main plot
  layout_matrix <- matrix(c(0, 1, 0,
                           2, 3, 4), 
                         nrow = 2, byrow = TRUE)
  
  layout(layout_matrix, 
         widths = c(0.2, 0.6, 0.2), 
         heights = c(0.2, 0.8))
  
  # Top dendrogram (constructs)
  par(mar = c(0, 4, 2, 1))
  plot(as.dendrogram(focus_result$construct_hclust), 
       horiz = FALSE, leaflab = "none", 
       main = title, axes = FALSE)
  
  # Left dendrogram (elements) 
  par(mar = c(4, 0, 0, 0))
  plot(as.dendrogram(focus_result$element_hclust), 
       horiz = TRUE, leaflab = "none", axes = FALSE)
  
  # Main grid plot
  par(mar = c(4, 4, 0, 1))
  sorted_matrix <- focus_result$sorted_matrix
  n_elem <- nrow(sorted_matrix)
  n_const <- ncol(sorted_matrix)
  
  # Create image plot
  if (show_shading) {
    # Use color coding for values
    colors <- colorRampPalette(c("#2166AC", "#FFFFFF", "#B2182B"))(100)
    image(1:n_const, 1:n_elem, t(sorted_matrix[n_elem:1, , drop = FALSE]),
          col = colors, axes = FALSE, xlab = "Constructs", ylab = "Elements")
  } else {
    # Just boxes
    plot(1, type = "n", xlim = c(0.5, n_const + 0.5), ylim = c(0.5, n_elem + 0.5),
         xlab = "Constructs", ylab = "Elements", axes = FALSE)
    
    for (i in 1:n_elem) {
      for (j in 1:n_const) {
        rect(j - 0.4, (n_elem - i + 1) - 0.4, j + 0.4, (n_elem - i + 1) + 0.4)
      }
    }
  }
  
  # Add values if requested
  if (show_values) {
    for (i in 1:n_elem) {
      for (j in 1:n_const) {
        val <- sorted_matrix[i, j]
        if (!is.na(val)) {
          text(j, n_elem - i + 1, val, cex = 0.8)
        }
      }
    }
  }
  
  # Add axis labels
  axis(1, at = 1:n_const, labels = focus_result$sorted_constructs, las = 2, cex.axis = 0.7)
  axis(2, at = 1:n_elem, labels = rev(focus_result$sorted_elements), las = 2, cex.axis = 0.7)
  box()
  
  # Right panel - similarity matrices or stats
  par(mar = c(4, 1, 0, 2))
  
  # Plot element similarities as text
  elem_sim <- focus_result$element_similarities[focus_result$element_order, focus_result$element_order]
  plot(1, type = "n", xlim = c(0, 1), ylim = c(0, 1), axes = FALSE, xlab = "", ylab = "")
  
  # Show top matches
  text(0.5, 0.9, "Element Matches", font = 2, cex = 0.8)
  
  # Find and display top similarities (excluding diagonal)
  elem_sim_no_diag <- elem_sim
  diag(elem_sim_no_diag) <- 0
  
  if (n_elem > 1) {
    top_matches <- which(elem_sim_no_diag == max(elem_sim_no_diag, na.rm = TRUE), arr.ind = TRUE)[1, ]
    match_val <- elem_sim_no_diag[top_matches[1], top_matches[2]]
    match_text <- paste0(focus_result$sorted_elements[top_matches[1]], " - ", 
                        focus_result$sorted_elements[top_matches[2]], "\n",
                        round(match_val, 1), "%")
    text(0.5, 0.7, match_text, cex = 0.6)
  }
  
  # Reset layout
  layout(1)
}