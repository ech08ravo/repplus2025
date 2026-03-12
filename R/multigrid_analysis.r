# Multi-grid analysis functions
# Based on Shaw (1980) SOCIOGRIDS methodology for comparing multiple repertory grids

#' Normalize ratings from one scale to another
#' @param ratings Numeric vector or matrix of ratings
#' @param from_scale c(min, max) of original scale
#' @param to_scale c(min, max) of target scale (default 1-7)
#' @return Normalized ratings on target scale
normalize_scale <- function(ratings, from_scale, to_scale = c(1, 7)) {
  if (from_scale[1] == to_scale[1] && from_scale[2] == to_scale[2]) {
    return(ratings)
  }
  # Linear interpolation
  (ratings - from_scale[1]) / (from_scale[2] - from_scale[1]) *
    (to_scale[2] - to_scale[1]) + to_scale[1]
}

#' Compute match percentage between two grids
#' Uses Minkowski distance on common elements, finding best-matching constructs
#' @param grid_a First grid object (list with elements, constructs, scores_mat)
#' @param grid_b Second grid object
#' @param common_elements Character vector of elements in both grids
#' @param power Minkowski power parameter (1.0 = city block, 2.0 = Euclidean)
#' @return List with match_a_to_b, match_b_to_a (asymmetric match percentages)
compute_grid_match <- function(grid_a, grid_b, common_elements, power = 1.0) {
  if (length(common_elements) < 1) {
    return(list(match_a_to_b = NA, match_b_to_a = NA))
  }

  # Get indices of common elements in each grid
  idx_a <- match(common_elements, grid_a$elements)
  idx_b <- match(common_elements, grid_b$elements)

  # Extract submatrices for common elements
  mat_a <- grid_a$scores_mat[idx_a, , drop = FALSE]
  mat_b <- grid_b$scores_mat[idx_b, , drop = FALSE]

  # Normalize scales if different
  if (!is.null(grid_a$scale) && !is.null(grid_b$scale)) {
    target_scale <- c(1, 7)
    mat_a <- normalize_scale(mat_a, grid_a$scale, target_scale)
    mat_b <- normalize_scale(mat_b, grid_b$scale, target_scale)
    scale_range <- target_scale[2] - target_scale[1]
  } else {
    scale_range <- max(mat_a, mat_b, na.rm = TRUE) - min(mat_a, mat_b, na.rm = TRUE)
  }

  n_common <- length(common_elements)
  max_distance <- n_common * scale_range

  # For each construct in A, find best match in B (considering reversal)
  match_a_to_b <- compute_directional_match(mat_a, mat_b, power, max_distance)

  # For each construct in B, find best match in A (considering reversal)
  match_b_to_a <- compute_directional_match(mat_b, mat_a, power, max_distance)

  list(
    match_a_to_b = match_a_to_b,
    match_b_to_a = match_b_to_a,
    symmetric = (match_a_to_b + match_b_to_a) / 2
  )
}

#' Compute directional match from grid A's constructs to grid B
#' @param mat_a Matrix of ratings for grid A (common elements x constructs)
#' @param mat_b Matrix of ratings for grid B (common elements x constructs)
#' @param power Minkowski power
#' @param max_distance Maximum possible distance for normalization
#' @return Average match percentage (0-100)
compute_directional_match <- function(mat_a, mat_b, power, max_distance) {
  n_constructs_a <- ncol(mat_a)
  n_constructs_b <- ncol(mat_b)

  if (n_constructs_a == 0 || n_constructs_b == 0) return(NA)

  # For each construct in A, find the best-matching construct in B
  best_matches <- numeric(n_constructs_a)

  for (i in seq_len(n_constructs_a)) {
    construct_a <- mat_a[, i]
    best_match <- 0

    for (j in seq_len(n_constructs_b)) {
      construct_b <- mat_b[, j]

      # Try normal orientation
      diff_normal <- abs(construct_a - construct_b)
      diff_normal <- diff_normal[!is.na(diff_normal)]

      # Try reversed orientation (flip construct B around midpoint)
      scale_mid <- (max(mat_b, na.rm = TRUE) + min(mat_b, na.rm = TRUE)) / 2
      construct_b_rev <- 2 * scale_mid - construct_b
      diff_reversed <- abs(construct_a - construct_b_rev)
      diff_reversed <- diff_reversed[!is.na(diff_reversed)]

      if (length(diff_normal) > 0) {
        dist_normal <- sum(diff_normal^power)^(1/power)
        dist_reversed <- sum(diff_reversed^power)^(1/power)

        # Use better match
        distance <- min(dist_normal, dist_reversed)
        similarity <- max(0, 100 * (1 - distance / max_distance))
        best_match <- max(best_match, similarity)
      }
    }
    best_matches[i] <- best_match
  }

  # Average of best matches for all constructs in A
  mean(best_matches, na.rm = TRUE)
}

#' Compute full match matrix for a collection of grids
#' @param grids Named list of grid objects
#' @param common_elements Character vector of common elements (or NULL to compute)
#' @param power Minkowski power parameter
#' @return Matrix of match percentages (rows = from, cols = to)
compute_match_matrix <- function(grids, common_elements = NULL, power = 1.0) {
  n <- length(grids)
  grid_names <- names(grids)
  if (is.null(grid_names)) grid_names <- paste0("Grid", seq_len(n))

  # Ensure unique names
  if (anyDuplicated(grid_names)) {
    grid_names <- make.unique(grid_names, sep = "_")
  }

  # Find common elements if not provided
  if (is.null(common_elements)) {
    common_elements <- Reduce(intersect, lapply(grids, function(g) g$elements))
  }

  match_mat <- matrix(NA_real_, nrow = n, ncol = n)
  rownames(match_mat) <- colnames(match_mat) <- grid_names

  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i == j) {
        match_mat[i, j] <- 100
      } else {
        result <- compute_grid_match(grids[[i]], grids[[j]], common_elements, power)
        match_mat[i, j] <- result$match_a_to_b
      }
    }
  }

  match_mat
}

#' Find similar constructs between two grids
#' @param grid_a First grid object
#' @param grid_b Second grid object
#' @param common_elements Elements to compare on
#' @param cutoff Minimum similarity threshold (0-100)
#' @param power Minkowski power
#' @return Data frame of matching construct pairs with similarity scores
find_similar_constructs <- function(grid_a, grid_b, common_elements,
                                    cutoff = 70, power = 1.0) {
  if (length(common_elements) < 1) {
    return(data.frame(
      construct_a = character(),
      construct_b = character(),
      similarity = numeric(),
      reversed = logical(),
      stringsAsFactors = FALSE
    ))
  }

  # Get indices and submatrices
  idx_a <- match(common_elements, grid_a$elements)
  idx_b <- match(common_elements, grid_b$elements)
  mat_a <- grid_a$scores_mat[idx_a, , drop = FALSE]
  mat_b <- grid_b$scores_mat[idx_b, , drop = FALSE]

  # Normalize scales
  target_scale <- c(1, 7)
  if (!is.null(grid_a$scale)) mat_a <- normalize_scale(mat_a, grid_a$scale, target_scale)
  if (!is.null(grid_b$scale)) mat_b <- normalize_scale(mat_b, grid_b$scale, target_scale)

  scale_range <- target_scale[2] - target_scale[1]
  max_distance <- length(common_elements) * scale_range

  # Construct labels
  labels_a <- paste(grid_a$constructs$left, "-", grid_a$constructs$right)
  labels_b <- paste(grid_b$constructs$left, "-", grid_b$constructs$right)

  results <- list()

  for (i in seq_len(ncol(mat_a))) {
    for (j in seq_len(ncol(mat_b))) {
      construct_a <- mat_a[, i]
      construct_b <- mat_b[, j]

      # Normal orientation
      diff_normal <- abs(construct_a - construct_b)
      diff_normal <- diff_normal[!is.na(diff_normal)]

      # Reversed orientation
      scale_mid <- (target_scale[1] + target_scale[2]) / 2
      construct_b_rev <- 2 * scale_mid - construct_b
      diff_reversed <- abs(construct_a - construct_b_rev)
      diff_reversed <- diff_reversed[!is.na(diff_reversed)]

      if (length(diff_normal) > 0) {
        dist_normal <- sum(diff_normal^power)^(1/power)
        dist_reversed <- sum(diff_reversed^power)^(1/power)

        if (dist_normal <= dist_reversed) {
          similarity <- max(0, 100 * (1 - dist_normal / max_distance))
          reversed <- FALSE
        } else {
          similarity <- max(0, 100 * (1 - dist_reversed / max_distance))
          reversed <- TRUE
        }

        if (similarity >= cutoff) {
          results[[length(results) + 1]] <- data.frame(
            construct_a = labels_a[i],
            construct_b = labels_b[j],
            similarity = round(similarity, 1),
            reversed = reversed,
            stringsAsFactors = FALSE
          )
        }
      }
    }
  }

  if (length(results) == 0) {
    return(data.frame(
      construct_a = character(),
      construct_b = character(),
      similarity = numeric(),
      reversed = logical(),
      stringsAsFactors = FALSE
    ))
  }

  result_df <- do.call(rbind, results)
  result_df[order(-result_df$similarity), ]
}

#' Generate Mode (consensus) grid from multiple grids
#' @param grids Named list of grid objects with common elements
#' @param common_elements Elements shared across grids (or NULL to compute)
#' @param method Consensus method: "average" or "median"
#' @param construct_handling "fold" (average identical) or "collect" (gather all)
#' @param similarity_cutoff For grouping similar constructs (when collecting)
#' @return New grid object representing consensus
generate_mode_grid <- function(grids, common_elements = NULL, method = "average",
                               construct_handling = "fold", similarity_cutoff = 80) {
  if (length(grids) < 2) {
    stop("Need at least 2 grids to generate mode grid")
  }

  # Find common elements
  if (is.null(common_elements)) {
    common_elements <- Reduce(intersect, lapply(grids, function(g) g$elements))
  }

  if (length(common_elements) < 2) {
    stop("Need at least 2 common elements to generate mode grid")
  }

  # Check if all grids share the same scale — if so, keep it; otherwise normalize to 1-7
  all_scales <- lapply(grids, function(g) if (!is.null(g$scale)) g$scale else c(1, 7))
  scales_same <- all(sapply(all_scales, function(s) identical(s, all_scales[[1]])))
  target_scale <- if (scales_same) all_scales[[1]] else c(1, 7)

  normalized_grids <- lapply(grids, function(g) {
    idx <- match(common_elements, g$elements)
    mat <- g$scores_mat[idx, , drop = FALSE]
    if (!is.null(g$scale) && !identical(g$scale, target_scale)) {
      mat <- normalize_scale(mat, g$scale, target_scale)
    }
    list(
      mat = mat,
      constructs = g$constructs,
      labels = paste(g$constructs$left, "-", g$constructs$right)
    )
  })

  if (construct_handling == "fold") {
    # Find identical constructs (by label) and average their ratings
    all_labels <- unique(unlist(lapply(normalized_grids, function(g) g$labels)))

    result_mat <- matrix(NA_real_, nrow = length(common_elements), ncol = length(all_labels))
    result_constructs <- data.frame(left = character(), right = character(),
                                    stringsAsFactors = FALSE)

    for (k in seq_along(all_labels)) {
      label <- all_labels[k]
      # Find this construct in each grid
      ratings_list <- list()
      for (g in normalized_grids) {
        idx <- which(g$labels == label)
        if (length(idx) > 0) {
          ratings_list[[length(ratings_list) + 1]] <- g$mat[, idx[1]]
        }
      }

      if (length(ratings_list) > 0) {
        # Average or median across grids
        ratings_matrix <- do.call(cbind, ratings_list)
        if (method == "average") {
          result_mat[, k] <- rowMeans(ratings_matrix, na.rm = TRUE)
        } else {
          result_mat[, k] <- apply(ratings_matrix, 1, median, na.rm = TRUE)
        }

        # Parse label back to poles
        parts <- strsplit(label, " - ")[[1]]
        result_constructs <- rbind(result_constructs, data.frame(
          left = parts[1],
          right = if (length(parts) > 1) parts[2] else "",
          stringsAsFactors = FALSE
        ))
      }
    }

    colnames(result_mat) <- all_labels

  } else {
    # "collect" - gather all constructs from all grids
    all_mats <- list()
    all_constructs <- data.frame(left = character(), right = character(),
                                 source = character(), stringsAsFactors = FALSE)

    grid_names <- names(grids)
    if (is.null(grid_names)) grid_names <- paste0("Grid", seq_along(grids))

    for (i in seq_along(normalized_grids)) {
      g <- normalized_grids[[i]]
      all_mats[[i]] <- g$mat
      source_constructs <- g$constructs
      source_constructs$source <- grid_names[i]
      all_constructs <- rbind(all_constructs, source_constructs)
    }

    result_mat <- do.call(cbind, all_mats)
    result_constructs <- all_constructs
  }

  rownames(result_mat) <- common_elements

  # Convert to ratings data frame
  construct_labels <- paste(result_constructs$left, "-", result_constructs$right)
  ratings_df <- data.frame(
    element = character(),
    construct = character(),
    rating = numeric(),
    stringsAsFactors = FALSE
  )

  for (i in seq_along(common_elements)) {
    for (j in seq_along(construct_labels)) {
      ratings_df <- rbind(ratings_df, data.frame(
        element = common_elements[i],
        construct = construct_labels[j],
        rating = round(result_mat[i, j], 1),
        stringsAsFactors = FALSE
      ))
    }
  }

  list(
    id = paste0("mode_", format(Sys.time(), "%Y%m%d%H%M%S")),
    name = paste("Mode Grid (", method, ")", sep = ""),
    elements = common_elements,
    constructs = result_constructs[, c("left", "right")],
    ratings = ratings_df,
    scores_mat = result_mat,
    scale = target_scale,
    source = "generated",
    source_grids = names(grids)
  )
}

#' Generate Composite grid merging multiple grids
#' @param grids Named list of grid objects
#' @param merge_on "elements" (common elements, all constructs) or
#'                 "constructs" (common constructs, all elements)
#' @param label_source Whether to append source grid name to labels
#' @return New grid object with merged data
generate_composite_grid <- function(grids, merge_on = "elements", label_source = TRUE) {
  if (length(grids) < 2) {
    stop("Need at least 2 grids to generate composite grid")
  }

  grid_names <- names(grids)
  if (is.null(grid_names)) grid_names <- paste0("Grid", seq_along(grids))

  target_scale <- c(1, 7)

  if (merge_on == "elements") {
    # Common elements, all constructs
    common_elements <- Reduce(intersect, lapply(grids, function(g) g$elements))

    if (length(common_elements) < 2) {
      stop("Need at least 2 common elements")
    }

    all_constructs <- data.frame(left = character(), right = character(),
                                 stringsAsFactors = FALSE)
    all_ratings <- list()

    for (i in seq_along(grids)) {
      g <- grids[[i]]
      idx <- match(common_elements, g$elements)
      mat <- g$scores_mat[idx, , drop = FALSE]

      if (!is.null(g$scale)) {
        mat <- normalize_scale(mat, g$scale, target_scale)
      }

      constructs <- g$constructs
      if (label_source) {
        constructs$left <- paste0(constructs$left, " [", grid_names[i], "]")
        constructs$right <- paste0(constructs$right, " [", grid_names[i], "]")
      }

      all_constructs <- rbind(all_constructs, constructs)
      all_ratings[[i]] <- mat
    }

    result_mat <- do.call(cbind, all_ratings)
    rownames(result_mat) <- common_elements
    result_elements <- common_elements
    result_constructs <- all_constructs

  } else {
    # Common constructs, all elements
    all_construct_labels <- lapply(grids, function(g) {
      paste(g$constructs$left, "-", g$constructs$right)
    })
    common_construct_labels <- Reduce(intersect, all_construct_labels)

    if (length(common_construct_labels) < 2) {
      stop("Need at least 2 common constructs")
    }

    all_elements <- character()
    all_ratings <- list()

    for (i in seq_along(grids)) {
      g <- grids[[i]]
      labels <- paste(g$constructs$left, "-", g$constructs$right)
      const_idx <- match(common_construct_labels, labels)
      mat <- g$scores_mat[, const_idx, drop = FALSE]

      if (!is.null(g$scale)) {
        mat <- normalize_scale(mat, g$scale, target_scale)
      }

      elements <- g$elements
      if (label_source) {
        elements <- paste0(elements, " [", grid_names[i], "]")
      }

      all_elements <- c(all_elements, elements)
      all_ratings[[i]] <- mat
    }

    result_mat <- do.call(rbind, all_ratings)
    rownames(result_mat) <- all_elements
    result_elements <- all_elements

    # Parse common construct labels back to poles
    result_constructs <- data.frame(
      left = sapply(strsplit(common_construct_labels, " - "), `[`, 1),
      right = sapply(strsplit(common_construct_labels, " - "), function(x) {
        if (length(x) > 1) x[2] else ""
      }),
      stringsAsFactors = FALSE
    )
  }

  # Convert to ratings data frame
  construct_labels <- paste(result_constructs$left, "-", result_constructs$right)
  ratings_df <- data.frame(
    element = character(),
    construct = character(),
    rating = numeric(),
    stringsAsFactors = FALSE
  )

  for (i in seq_along(result_elements)) {
    for (j in seq_along(construct_labels)) {
      ratings_df <- rbind(ratings_df, data.frame(
        element = result_elements[i],
        construct = construct_labels[j],
        rating = round(result_mat[i, j], 1),
        stringsAsFactors = FALSE
      ))
    }
  }

  list(
    id = paste0("composite_", format(Sys.time(), "%Y%m%d%H%M%S")),
    name = paste("Composite Grid (", merge_on, ")", sep = ""),
    elements = result_elements,
    constructs = result_constructs,
    ratings = ratings_df,
    scores_mat = result_mat,
    scale = target_scale,
    source = "generated",
    source_grids = grid_names
  )
}

#' Prepare network data for Socionets visualization
#' @param match_matrix From compute_match_matrix
#' @param cutoff Minimum match % to show edge
#' @param symmetric Whether to average bidirectional matches
#' @return List with nodes and edges data frames for igraph
prepare_socionet_data <- function(match_matrix, cutoff = 70, symmetric = FALSE) {
  grid_names <- rownames(match_matrix)
  n <- nrow(match_matrix)

  # Ensure unique names by appending suffix if duplicates exist
  if (anyDuplicated(grid_names)) {
    grid_names <- make.unique(grid_names, sep = "_")
    rownames(match_matrix) <- grid_names
    colnames(match_matrix) <- grid_names
  }

  nodes <- data.frame(
    name = grid_names,
    stringsAsFactors = FALSE
  )

  edges <- data.frame(
    from = character(),
    to = character(),
    weight = numeric(),
    stringsAsFactors = FALSE
  )

  if (symmetric) {
    # Average i->j and j->i, only include each pair once
    for (i in 1:(n - 1)) {
      for (j in (i + 1):n) {
        avg_match <- (match_matrix[i, j] + match_matrix[j, i]) / 2
        if (!is.na(avg_match) && avg_match >= cutoff) {
          edges <- rbind(edges, data.frame(
            from = grid_names[i],
            to = grid_names[j],
            weight = round(avg_match, 1),
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  } else {
    # Directed edges
    for (i in seq_len(n)) {
      for (j in seq_len(n)) {
        if (i != j) {
          match_val <- match_matrix[i, j]
          if (!is.na(match_val) && match_val >= cutoff) {
            edges <- rbind(edges, data.frame(
              from = grid_names[i],
              to = grid_names[j],
              weight = round(match_val, 1),
              stringsAsFactors = FALSE
            ))
          }
        }
      }
    }
  }

  list(nodes = nodes, edges = edges, symmetric = symmetric)
}

#' Plot Socionets network using igraph
#' @param socionet_data Output from prepare_socionet_data
#' @param title Plot title
#' @param node_color Color for nodes
#' @param edge_color Color for edges
#' @param show_weights Whether to show edge weight labels
#' @param text_size Text size multiplier
plot_socionets <- function(socionet_data, title = "Socionets: Grid Relationships",
                          node_color = "steelblue", edge_color = "darkgrey",
                          show_weights = TRUE, text_size = 1.2) {
  if (!requireNamespace("igraph", quietly = TRUE)) {
    stop("igraph package required for Socionets visualization")
  }

  nodes <- socionet_data$nodes
  edges <- socionet_data$edges
  symmetric <- socionet_data$symmetric

  if (nrow(edges) == 0) {
    # No edges above cutoff - just plot nodes
    par(cex = text_size, family = "sans")
    plot(1, type = "n", xlim = c(0, 1), ylim = c(0, 1),
         xlab = "", ylab = "", axes = FALSE, main = title)
    n <- nrow(nodes)
    if (n > 0) {
      # Arrange nodes in a circle with more spacing
      angles <- seq(0, 2 * pi, length.out = n + 1)[1:n]
      x <- 0.5 + 0.4 * cos(angles)
      y <- 0.5 + 0.4 * sin(angles)
      points(x, y, pch = 21, bg = node_color, cex = 2 * text_size)
      text(x, y, labels = nodes$name, pos = 3, cex = 0.7 * text_size, family = "sans")
    }
    text(0.5, 0.05, "No connections above cutoff", col = "gray50", cex = text_size, family = "sans")
    return(invisible(NULL))
  }

  # Create igraph object
  g <- igraph::graph_from_data_frame(edges, directed = !symmetric, vertices = nodes)

  # Use circular layout for cleaner spacing with many nodes
  n_nodes <- igraph::vcount(g)
  if (n_nodes <= 3) {
    layout <- igraph::layout_with_fr(g)
  } else {
    # Circular layout provides more predictable spacing
    layout <- igraph::layout_in_circle(g)
  }
  # Normalize and expand layout for more spacing
  layout <- igraph::norm_coords(layout, xmin = -2, xmax = 2, ymin = -2, ymax = 2)

  # Scale edge widths - thinner lines
  edge_widths <- igraph::E(g)$weight / 60  # 90% -> 1.5, 60% -> 1
  edge_widths <- pmax(edge_widths, 0.3)
  edge_widths <- pmin(edge_widths, 2)  # Cap maximum width

  # Calculate edge curvature to avoid overlapping edges between same node pairs
  edge_curved <- rep(0.2, igraph::ecount(g))  # Slight curve on all edges

  # Make edge color semi-transparent
  edge_col_alpha <- adjustcolor(edge_color, alpha.f = 0.6)

  # Plot with text size scaling and sans-serif font
  par(cex = text_size, family = "sans", mar = c(1, 1, 3, 1))
  plot(g,
       layout = layout,
       vertex.size = 12 * text_size,  # Smaller nodes
       vertex.color = adjustcolor(node_color, alpha.f = 0.8),
       vertex.frame.color = adjustcolor(node_color, alpha.f = 0.9),
       vertex.frame.width = 1,
       vertex.label = igraph::V(g)$name,
       vertex.label.color = "gray20",
       vertex.label.cex = 0.65 * text_size,  # Smaller labels
       vertex.label.family = "sans",
       vertex.label.dist = 2,  # Labels further from nodes
       vertex.label.degree = -pi/2,  # Labels above nodes
       edge.width = edge_widths * text_size,
       edge.color = edge_col_alpha,
       edge.curved = edge_curved,
       edge.arrow.size = if (symmetric) 0 else 0.25 * text_size,  # Smaller arrows
       edge.arrow.width = if (symmetric) 0 else 0.8,
       edge.label = if (show_weights) paste0(igraph::E(g)$weight, "%") else NA,
       edge.label.cex = 0.5 * text_size,  # Much smaller edge labels
       edge.label.color = "gray40",
       edge.label.family = "sans",
       main = title,
       margin = c(0, 0, 0, 0))

  invisible(g)
}

# ============================================================================
# MINUS Analysis - Grid Subtraction
# ============================================================================

#' Compute MINUS (difference) grid from two grids
#' @param grid_a First grid object
#' @param grid_b Second grid object
#' @param common_elements Character vector of shared element names
#' @param common_constructs Character vector of shared construct labels ("left - right")
#' @return List with diff_mat, pct_diff_mat, elements, constructs, scale, grid names
compute_minus_grid <- function(grid_a, grid_b, common_elements, common_constructs) {
  if (length(common_elements) < 2) stop("Need at least 2 common elements")
  if (length(common_constructs) < 1) stop("Need at least 1 common construct")

  target_scale <- c(1, 7)
  scale_range <- target_scale[2] - target_scale[1]

  # Get element indices
  idx_a_elem <- match(common_elements, grid_a$elements)
  idx_b_elem <- match(common_elements, grid_b$elements)

  # Get construct indices by label matching
  labels_a <- paste(grid_a$constructs$left, "-", grid_a$constructs$right)
  labels_b <- paste(grid_b$constructs$left, "-", grid_b$constructs$right)
  idx_a_const <- match(common_constructs, labels_a)
  idx_b_const <- match(common_constructs, labels_b)

  # Extract and normalize submatrices
  mat_a <- grid_a$scores_mat[idx_a_elem, idx_a_const, drop = FALSE]
  mat_b <- grid_b$scores_mat[idx_b_elem, idx_b_const, drop = FALSE]

  if (!is.null(grid_a$scale)) mat_a <- normalize_scale(mat_a, grid_a$scale, target_scale)
  if (!is.null(grid_b$scale)) mat_b <- normalize_scale(mat_b, grid_b$scale, target_scale)

  # Compute differences
  diff_mat <- mat_a - mat_b
  pct_diff_mat <- diff_mat / scale_range * 100

  rownames(diff_mat) <- rownames(pct_diff_mat) <- common_elements
  colnames(diff_mat) <- colnames(pct_diff_mat) <- common_constructs

  # Parse construct labels back to poles
  constructs_df <- data.frame(
    left = sapply(strsplit(common_constructs, " - "), `[`, 1),
    right = sapply(strsplit(common_constructs, " - "), function(x) if (length(x) > 1) x[2] else ""),
    stringsAsFactors = FALSE
  )

  list(
    diff_mat = diff_mat,
    pct_diff_mat = pct_diff_mat,
    elements = common_elements,
    constructs = constructs_df,
    construct_labels = common_constructs,
    scale = target_scale,
    grid_a_name = if (!is.null(grid_a$name)) grid_a$name else "Grid A",
    grid_b_name = if (!is.null(grid_b$name)) grid_b$name else "Grid B",
    mean_abs_diff = mean(abs(diff_mat), na.rm = TRUE),
    max_diff = max(abs(diff_mat), na.rm = TRUE)
  )
}

#' Plot MINUS grid as a diverging heatmap
#' @param minus_result Output from compute_minus_grid
#' @param title Plot title
#' @param text_size Text scaling factor
#' @param show_values Whether to show numeric values in cells
#' @param show_pct Whether to show percentage differences instead of raw
plot_minus_grid <- function(minus_result, title = NULL, text_size = 1.2,
                            show_values = TRUE, show_pct = FALSE) {
  mat <- if (show_pct) minus_result$pct_diff_mat else minus_result$diff_mat

  if (is.null(title)) {
    title <- paste0("MINUS: ", minus_result$grid_a_name, " - ", minus_result$grid_b_name)
  }

  n_elem <- nrow(mat)
  n_const <- ncol(mat)

  # Set up layout: main heatmap + color legend
  layout(matrix(c(1, 2), nrow = 1), widths = c(5, 1))

  # Diverging color palette: blue (negative) - white (zero) - orange (positive)
  colors <- colorRampPalette(c("#0072B2", "#FFFFFF", "#D55E00"))(100)

  # Determine symmetric zlim around zero
  max_abs <- max(abs(mat), na.rm = TRUE)
  if (max_abs == 0) max_abs <- 1
  zlim <- c(-max_abs, max_abs)

  # Main heatmap
  par(mar = c(10, 12, 5, 1), family = "sans")

  image(1:n_const, 1:n_elem, t(mat[n_elem:1, , drop = FALSE]),
        col = colors, axes = FALSE, xlab = "", ylab = "",
        main = title, cex.main = text_size * 1.1,
        zlim = zlim)

  # Add values
  if (show_values) {
    for (i in 1:n_elem) {
      for (j in 1:n_const) {
        val <- mat[i, j]
        if (!is.na(val)) {
          fmt <- if (show_pct) sprintf("%.0f%%", val) else sprintf("%.1f", val)
          text(j, n_elem - i + 1, fmt, cex = 0.8 * text_size, family = "sans")
        }
      }
    }
  }

  # Axes
  axis(1, at = 1:n_const, labels = minus_result$construct_labels, las = 2,
       cex.axis = 0.7 * text_size, family = "sans")
  axis(2, at = 1:n_elem, labels = rev(minus_result$elements), las = 2,
       cex.axis = 0.8 * text_size, family = "sans")
  box()

  label_suffix <- if (show_pct) " (percentage)" else " (raw)"
  mtext(paste0("Blue = A < B   White = no difference   Orange = A > B", label_suffix),
        side = 1, line = 8, cex = 0.8 * text_size, family = "sans")

  # Color legend
  par(mar = c(10, 0.5, 5, 3), family = "sans")
  legend_vals <- seq(zlim[1], zlim[2], length.out = 100)
  image(1, legend_vals, t(as.matrix(legend_vals)), col = colors,
        axes = FALSE, xlab = "", ylab = "")
  axis(4, at = c(zlim[1], 0, zlim[2]),
       labels = round(c(zlim[1], 0, zlim[2]), 1),
       las = 2, cex.axis = 0.8 * text_size, family = "sans")
  mtext("Diff", side = 3, line = 0.5, cex = 0.8 * text_size, family = "sans")
  box()

  layout(1)
}

# ============================================================================
# CORE Analysis - Iterative Grid Comparison
# ============================================================================

#' Compute CORE analysis - iterative removal of least similar items
#' @param grid_a First grid object
#' @param grid_b Second grid object
#' @param common_elements Character vector of shared elements
#' @param common_constructs Character vector of shared construct labels
#' @param power Minkowski power parameter
#' @param min_elements Minimum elements to retain
#' @param min_constructs Minimum constructs to retain
#' @return List with steps log, core elements/constructs, core matrices, final similarity
compute_core_analysis <- function(grid_a, grid_b, common_elements, common_constructs,
                                   power = 1.0, min_elements = 2, min_constructs = 1) {
  if (length(common_elements) < 2) stop("Need at least 2 common elements")
  if (length(common_constructs) < 1) stop("Need at least 1 common construct")

  target_scale <- c(1, 7)

  # Get indices and extract submatrices
  labels_a <- paste(grid_a$constructs$left, "-", grid_a$constructs$right)
  labels_b <- paste(grid_b$constructs$left, "-", grid_b$constructs$right)

  current_elements <- common_elements
  current_constructs <- common_constructs

  # Helper to build temporary grid objects for matching
  make_subgrid <- function(grid, elements, construct_labels) {
    all_labels <- paste(grid$constructs$left, "-", grid$constructs$right)
    idx_elem <- match(elements, grid$elements)
    idx_const <- match(construct_labels, all_labels)
    mat <- grid$scores_mat[idx_elem, idx_const, drop = FALSE]
    if (!is.null(grid$scale)) mat <- normalize_scale(mat, grid$scale, target_scale)
    rownames(mat) <- elements
    colnames(mat) <- construct_labels
    list(
      elements = elements,
      constructs = data.frame(
        left = sapply(strsplit(construct_labels, " - "), `[`, 1),
        right = sapply(strsplit(construct_labels, " - "), function(x) if (length(x) > 1) x[2] else ""),
        stringsAsFactors = FALSE
      ),
      scores_mat = mat,
      scale = target_scale
    )
  }

  # Compute initial similarity
  sub_a <- make_subgrid(grid_a, current_elements, current_constructs)
  sub_b <- make_subgrid(grid_b, current_elements, current_constructs)
  initial_match <- compute_grid_match(sub_a, sub_b, current_elements, power)
  current_similarity <- initial_match$symmetric

  steps <- data.frame(
    step = integer(), type = character(), removed = character(),
    similarity_before = numeric(), similarity_after = numeric(),
    stringsAsFactors = FALSE
  )

  step_num <- 0

  while (TRUE) {
    can_remove_elem <- length(current_elements) > min_elements
    can_remove_const <- length(current_constructs) > min_constructs

    if (!can_remove_elem && !can_remove_const) break

    best_improvement <- -Inf
    best_type <- ""
    best_name <- ""
    best_similarity <- current_similarity

    # Try removing each element
    if (can_remove_elem) {
      for (i in seq_along(current_elements)) {
        test_elements <- current_elements[-i]
        test_a <- make_subgrid(grid_a, test_elements, current_constructs)
        test_b <- make_subgrid(grid_b, test_elements, current_constructs)
        test_match <- compute_grid_match(test_a, test_b, test_elements, power)
        improvement <- test_match$symmetric - current_similarity
        if (improvement > best_improvement) {
          best_improvement <- improvement
          best_type <- "Element"
          best_name <- current_elements[i]
          best_similarity <- test_match$symmetric
        }
      }
    }

    # Try removing each construct
    if (can_remove_const) {
      for (j in seq_along(current_constructs)) {
        test_constructs <- current_constructs[-j]
        test_a <- make_subgrid(grid_a, current_elements, test_constructs)
        test_b <- make_subgrid(grid_b, current_elements, test_constructs)
        test_match <- compute_grid_match(test_a, test_b, current_elements, power)
        improvement <- test_match$symmetric - current_similarity
        if (improvement > best_improvement) {
          best_improvement <- improvement
          best_type <- "Construct"
          best_name <- current_constructs[j]
          best_similarity <- test_match$symmetric
        }
      }
    }

    # If no improvement possible, stop
    if (best_improvement <= 0) break

    step_num <- step_num + 1
    steps <- rbind(steps, data.frame(
      step = step_num, type = best_type, removed = best_name,
      similarity_before = round(current_similarity, 1),
      similarity_after = round(best_similarity, 1),
      stringsAsFactors = FALSE
    ))

    # Remove the item
    if (best_type == "Element") {
      current_elements <- setdiff(current_elements, best_name)
    } else {
      current_constructs <- setdiff(current_constructs, best_name)
    }
    current_similarity <- best_similarity
  }

  # Build final core subgrids
  core_a <- make_subgrid(grid_a, current_elements, current_constructs)
  core_b <- make_subgrid(grid_b, current_elements, current_constructs)

  list(
    steps = steps,
    core_elements = current_elements,
    core_constructs = current_constructs,
    core_mat_a = core_a$scores_mat,
    core_mat_b = core_b$scores_mat,
    core_similarity = current_similarity,
    initial_similarity = initial_match$symmetric,
    n_elements_removed = length(common_elements) - length(current_elements),
    n_constructs_removed = length(common_constructs) - length(current_constructs),
    grid_a_name = if (!is.null(grid_a$name)) grid_a$name else "Grid A",
    grid_b_name = if (!is.null(grid_b$name)) grid_b$name else "Grid B"
  )
}

#' Plot CORE analysis results
#' @param core_result Output from compute_core_analysis
#' @param title Plot title
#' @param text_size Text scaling
plot_core_analysis <- function(core_result, title = "CORE Analysis", text_size = 1.2) {
  steps <- core_result$steps

  if (nrow(steps) == 0) {
    # No removals needed - grids already maximally similar
    par(mar = c(4, 4, 3, 2), family = "sans")
    plot(1, type = "n", xlim = c(0, 1), ylim = c(0, 1), axes = FALSE,
         xlab = "", ylab = "", main = title)
    text(0.5, 0.5, paste0("No removals needed\nGrids are already maximally similar\n",
                           "Similarity: ", round(core_result$initial_similarity, 1), "%"),
         cex = text_size, family = "sans")
    return(invisible(NULL))
  }

  # Two-panel layout: line chart (left) + core grid heatmap (right)
  layout(matrix(c(1, 2), nrow = 1), widths = c(3, 2))

  # Panel 1: Similarity progression
  par(mar = c(8, 5, 4, 2), family = "sans")

  all_sims <- c(steps$similarity_before[1], steps$similarity_after)
  all_steps <- 0:nrow(steps)

  plot(all_steps, all_sims, type = "b", pch = 19,
       xlab = "Step", ylab = "Similarity (%)",
       main = paste0(title, "\n", core_result$grid_a_name, " vs ", core_result$grid_b_name),
       cex.main = text_size, cex.lab = text_size, cex.axis = text_size * 0.9,
       col = "#0072B2", lwd = 2, ylim = c(min(all_sims) - 5, 100))

  # Label each removal point
  for (i in seq_len(nrow(steps))) {
    label <- paste0(steps$type[i], ": ", steps$removed[i])
    col <- if (steps$type[i] == "Element") "#D55E00" else "#009E73"
    text(i, steps$similarity_after[i], label,
         pos = if (i %% 2 == 1) 1 else 3, cex = 0.6 * text_size,
         col = col, family = "sans")
  }

  abline(h = core_result$core_similarity, lty = 2, col = "gray50")
  text(0, core_result$core_similarity,
       paste0("Core: ", round(core_result$core_similarity, 1), "%"),
       pos = 4, cex = 0.7 * text_size, col = "gray40", family = "sans")

  # Panel 2: Core grid heatmap (average of A and B)
  par(mar = c(8, 8, 4, 3), family = "sans")
  core_avg <- (core_result$core_mat_a + core_result$core_mat_b) / 2
  n_elem <- nrow(core_avg)
  n_const <- ncol(core_avg)

  colors <- colorRampPalette(c("#0072B2", "#FFFFFF", "#D55E00"))(100)

  image(1:n_const, 1:n_elem, t(core_avg[n_elem:1, , drop = FALSE]),
        col = colors, axes = FALSE, xlab = "", ylab = "",
        main = "Core Grid (average)", cex.main = text_size * 0.9,
        zlim = c(1, 7))

  # Add values
  for (i in 1:n_elem) {
    for (j in 1:n_const) {
      val <- core_avg[i, j]
      if (!is.na(val)) {
        text(j, n_elem - i + 1, sprintf("%.1f", val),
             cex = 0.7 * text_size, family = "sans")
      }
    }
  }

  axis(1, at = 1:n_const, labels = core_result$core_constructs, las = 2,
       cex.axis = 0.6 * text_size, family = "sans")
  axis(2, at = 1:n_elem, labels = rev(core_result$core_elements), las = 2,
       cex.axis = 0.7 * text_size, family = "sans")
  box()

  layout(1)
}

# ============================================================================
# PrinGrid Trajectories - Multi-grid PCA with movement arrows
# ============================================================================

#' Compute PrinGrid Trajectories PCA data for multiple grids
#' @param grids Named list of grid objects
#' @param common_elements Character vector of shared elements
#' @return List with element_positions per grid, construct_loadings, variance_explained
compute_pringrid_trajectories <- function(grids, common_elements) {
  if (length(grids) < 2) stop("Need at least 2 grids")
  if (length(common_elements) < 2) stop("Need at least 2 common elements")

  target_scale <- c(1, 7)
  grid_names <- names(grids)
  if (is.null(grid_names)) grid_names <- paste0("Grid", seq_along(grids))

  # Build stacked matrix: rows = grids*elements, cols = all constructs collected
  all_mats <- list()
  all_construct_labels <- character()
  row_labels <- character()
  row_grid_source <- character()

  for (i in seq_along(grids)) {
    g <- grids[[i]]
    idx_elem <- match(common_elements, g$elements)
    mat <- g$scores_mat[idx_elem, , drop = FALSE]
    if (!is.null(g$scale)) mat <- normalize_scale(mat, g$scale, target_scale)

    labels <- paste(g$constructs$left, "-", g$constructs$right)
    # Append grid name to make construct columns unique
    labeled <- paste0(labels, " [", grid_names[i], "]")

    colnames(mat) <- labeled
    rownames(mat) <- paste0(common_elements, " [", grid_names[i], "]")

    all_mats[[i]] <- mat
    all_construct_labels <- c(all_construct_labels, labeled)
    row_labels <- c(row_labels, rownames(mat))
    row_grid_source <- c(row_grid_source, rep(grid_names[i], length(common_elements)))
  }

  # Build full matrix: rows = all element instances, cols = all constructs
  n_total_rows <- length(common_elements) * length(grids)
  n_total_cols <- length(all_construct_labels)
  stacked <- matrix(NA_real_, nrow = n_total_rows, ncol = n_total_cols)
  rownames(stacked) <- row_labels
  colnames(stacked) <- all_construct_labels

  row_start <- 1
  for (i in seq_along(all_mats)) {
    mat <- all_mats[[i]]
    n_rows <- nrow(mat)
    col_idx <- match(colnames(mat), all_construct_labels)
    stacked[row_start:(row_start + n_rows - 1), col_idx] <- mat
    row_start <- row_start + n_rows
  }

  # Replace NAs with column means for PCA
  for (j in seq_len(ncol(stacked))) {
    col_mean <- mean(stacked[, j], na.rm = TRUE)
    if (is.na(col_mean)) col_mean <- 4  # midpoint fallback
    stacked[is.na(stacked[, j]), j] <- col_mean
  }

  # Remove zero-variance columns
  col_vars <- apply(stacked, 2, var, na.rm = TRUE)
  keep_cols <- col_vars > 1e-10
  if (sum(keep_cols) < 2) stop("Not enough variation for PCA")
  stacked <- stacked[, keep_cols, drop = FALSE]

  # Run PCA
  pc <- prcomp(stacked, scale. = TRUE)

  # Extract element scores (PC1, PC2)
  scores <- pc$x[, 1:min(2, ncol(pc$x))]
  if (ncol(pc$x) < 2) {
    scores <- cbind(scores, 0)
  }

  # Partition scores back to grids
  element_positions <- list()
  row_start <- 1
  for (i in seq_along(grids)) {
    n_rows <- length(common_elements)
    grid_scores <- scores[row_start:(row_start + n_rows - 1), , drop = FALSE]
    element_positions[[grid_names[i]]] <- data.frame(
      element = common_elements,
      PC1 = grid_scores[, 1],
      PC2 = grid_scores[, 2],
      grid = grid_names[i],
      stringsAsFactors = FALSE
    )
    row_start <- row_start + n_rows
  }

  # Construct loadings (correlations with PCs)
  load <- cor(stacked, pc$x[, 1:min(2, ncol(pc$x))])
  if (ncol(pc$x) < 2) load <- cbind(load, 0)

  construct_loadings <- data.frame(
    label = rownames(load),
    PC1 = load[, 1],
    PC2 = load[, 2],
    stringsAsFactors = FALSE
  )

  # Variance explained
  ve <- (pc$sdev^2 / sum(pc$sdev^2)) * 100

  list(
    element_positions = element_positions,
    construct_loadings = construct_loadings,
    variance_explained = ve[1:min(length(ve), 5)],
    grid_names = grid_names,
    common_elements = common_elements
  )
}

#' Plot PrinGrid trajectories
#' @param traj_data Output from compute_pringrid_trajectories
#' @param title Plot title
#' @param show_arrows Whether to draw movement arrows
#' @param show_labels Whether to show element labels
#' @param show_constructs Whether to show construct lines
#' @param text_size Text scaling
plot_pringrid_trajectories <- function(traj_data, title = "PrinGrid Trajectories",
                                       show_arrows = TRUE, show_labels = TRUE,
                                       show_constructs = TRUE, text_size = 1.2) {
  positions <- traj_data$element_positions
  loadings <- traj_data$construct_loadings
  grid_names <- traj_data$grid_names
  ve <- traj_data$variance_explained

  # Assign colors to grids
  grid_colors <- c("#0072B2", "#D55E00", "#009E73", "#CC79A7",
                   "#E69F00", "#56B4E9", "#F0E442", "#000000")
  grid_colors <- grid_colors[seq_along(grid_names)]
  names(grid_colors) <- grid_names

  # Compute axis limits from all positions
  all_pc1 <- unlist(lapply(positions, function(p) p$PC1))
  all_pc2 <- unlist(lapply(positions, function(p) p$PC2))

  if (show_constructs) {
    all_pc1 <- c(all_pc1, loadings$PC1, -loadings$PC1)
    all_pc2 <- c(all_pc2, loadings$PC2, -loadings$PC2)
  }

  x_range <- range(all_pc1, na.rm = TRUE)
  y_range <- range(all_pc2, na.rm = TRUE)
  x_expand <- diff(x_range) * 0.25
  y_expand <- diff(y_range) * 0.25
  xlim <- c(x_range[1] - x_expand, x_range[2] + x_expand)
  ylim <- c(y_range[1] - y_expand, y_range[2] + y_expand)

  par(mar = c(5, 5, 4, 2), family = "sans")

  plot(NULL, type = "n", xlim = xlim, ylim = ylim,
       xlab = sprintf("PC1 (%.1f%%)", ve[1]),
       ylab = sprintf("PC2 (%.1f%%)", ve[2]),
       main = title,
       cex.main = text_size, cex.lab = text_size, cex.axis = text_size * 0.9)

  abline(h = 0, v = 0, lty = 3, col = "gray50")

  # Draw construct lines if requested
  if (show_constructs && nrow(loadings) > 0) {
    for (i in seq_len(nrow(loadings))) {
      lines(c(-loadings$PC1[i], loadings$PC1[i]),
            c(-loadings$PC2[i], loadings$PC2[i]),
            col = adjustcolor("gray70", alpha.f = 0.5), lwd = 1)
    }
  }

  # Draw trajectory arrows between same elements across grids
  if (show_arrows && length(grid_names) > 1) {
    for (elem in traj_data$common_elements) {
      for (k in 1:(length(grid_names) - 1)) {
        g1 <- grid_names[k]
        g2 <- grid_names[k + 1]
        p1 <- positions[[g1]]
        p2 <- positions[[g2]]
        row1 <- which(p1$element == elem)
        row2 <- which(p2$element == elem)
        if (length(row1) == 1 && length(row2) == 1) {
          arrows(p1$PC1[row1], p1$PC2[row1], p2$PC1[row2], p2$PC2[row2],
                 col = adjustcolor("gray40", alpha.f = 0.6),
                 length = 0.1, lwd = 1.5)
        }
      }
    }
  }

  # Plot elements for each grid
  for (gname in grid_names) {
    p <- positions[[gname]]
    col <- grid_colors[gname]
    points(p$PC1, p$PC2, pch = 19, col = col, cex = text_size * 1.3)
    if (show_labels) {
      text(p$PC1, p$PC2, labels = p$element, pos = 3, col = col,
           cex = text_size * 0.8, font = 2, family = "sans")
    }
  }

  # Legend
  legend("topright", legend = grid_names, col = grid_colors, pch = 19,
         cex = text_size * 0.8, bg = "white", box.lty = 0)
}

# ============================================================================
# Exchange Grid Analysis - 6-grid CORE protocol
# ============================================================================

#' Compute Exchange Grid analysis using CORE on 4 grid pairs
#' @param grids List of exactly 6 grid objects in protocol order
#' @param power Minkowski power
#' @return List with agreement and understanding CORE results
compute_exchange_analysis <- function(grids, power = 1.0) {
  if (length(grids) != 6) stop("Exchange analysis requires exactly 6 grids")

  # Grid roles:
  # 1: A's own grid, 2: B's own grid
  # 3: A filled by B (as B wants), 4: B filled by A (as A wants)
  # 5: A filled by B (as B thinks A filled it), 6: B filled by A (as A thinks B filled it)

  run_core_pair <- function(g1, g2, pair_label) {
    common_elem <- intersect(g1$elements, g2$elements)
    labels_1 <- paste(g1$constructs$left, "-", g1$constructs$right)
    labels_2 <- paste(g2$constructs$left, "-", g2$constructs$right)
    common_const <- intersect(labels_1, labels_2)

    if (length(common_elem) < 2 || length(common_const) < 1) {
      return(list(
        pair = pair_label,
        error = "Insufficient common elements or constructs",
        core_similarity = NA,
        initial_similarity = NA
      ))
    }

    tryCatch({
      result <- compute_core_analysis(g1, g2, common_elem, common_const, power)
      result$pair <- pair_label
      result
    }, error = function(e) {
      list(pair = pair_label, error = e$message, core_similarity = NA, initial_similarity = NA)
    })
  }

  # Agreement pairs: (1,3) and (2,4)
  agreement_ab <- run_core_pair(grids[[1]], grids[[3]], "Agreement: A vs B-fills-A")
  agreement_ba <- run_core_pair(grids[[2]], grids[[4]], "Agreement: B vs A-fills-B")

  # Understanding pairs: (1,5) and (2,6)
  understanding_ab <- run_core_pair(grids[[1]], grids[[5]], "Understanding: A vs B-predicts-A")
  understanding_ba <- run_core_pair(grids[[2]], grids[[6]], "Understanding: B vs A-predicts-B")

  # Summary table
  summary_df <- data.frame(
    Pair = c("Agreement (A)", "Agreement (B)", "Understanding (A)", "Understanding (B)"),
    Description = c(
      "Does B agree with A's construing?",
      "Does A agree with B's construing?",
      "Does B understand A's construing?",
      "Does A understand B's construing?"
    ),
    Initial = c(
      agreement_ab$initial_similarity, agreement_ba$initial_similarity,
      understanding_ab$initial_similarity, understanding_ba$initial_similarity
    ),
    Core = c(
      agreement_ab$core_similarity, agreement_ba$core_similarity,
      understanding_ab$core_similarity, understanding_ba$core_similarity
    ),
    stringsAsFactors = FALSE
  )

  list(
    agreement_ab = agreement_ab,
    agreement_ba = agreement_ba,
    understanding_ab = understanding_ab,
    understanding_ba = understanding_ba,
    summary = summary_df
  )
}

# ============================================================================
# Class Metagrid - Grids as elements
# ============================================================================

#' Create a metagrid where grids become elements
#' @param grid_names Character vector of grid names (elements)
#' @param meta_constructs data.frame with left and right poles
#' @param scores_mat Matrix of ratings (grids x meta-constructs)
#' @param scale Scale range
#' @return Standard grid list object
create_metagrid <- function(grid_names, meta_constructs, scores_mat, scale = c(1, 7)) {
  rownames(scores_mat) <- grid_names
  construct_labels <- paste(meta_constructs$left, "-", meta_constructs$right)
  colnames(scores_mat) <- construct_labels

  # Build ratings data frame
  ratings_df <- expand.grid(
    element = grid_names,
    construct = construct_labels,
    stringsAsFactors = FALSE
  )
  ratings_df$rating <- as.vector(scores_mat)

  list(
    id = paste0("metagrid_", format(Sys.time(), "%Y%m%d%H%M%S")),
    name = "Class Metagrid",
    elements = grid_names,
    constructs = meta_constructs[, c("left", "right")],
    ratings = ratings_df,
    scores_mat = scores_mat,
    scale = scale,
    source = "generated",
    source_grids = grid_names
  )
}
