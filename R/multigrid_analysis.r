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

  # Normalize all grids to same scale
  target_scale <- c(1, 7)
  normalized_grids <- lapply(grids, function(g) {
    idx <- match(common_elements, g$elements)
    mat <- g$scores_mat[idx, , drop = FALSE]
    if (!is.null(g$scale)) {
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
plot_socionets <- function(socionet_data, title = "Socionets: Grid Relationships",
                          node_color = "#0072B2", edge_color = "#666666",
                          show_weights = TRUE) {
  if (!requireNamespace("igraph", quietly = TRUE)) {
    stop("igraph package required for Socionets visualization")
  }

  nodes <- socionet_data$nodes
  edges <- socionet_data$edges
  symmetric <- socionet_data$symmetric

  if (nrow(edges) == 0) {
    # No edges above cutoff - just plot nodes
    plot(1, type = "n", xlim = c(0, 1), ylim = c(0, 1),
         xlab = "", ylab = "", axes = FALSE, main = title)
    n <- nrow(nodes)
    if (n > 0) {
      # Arrange nodes in a circle
      angles <- seq(0, 2 * pi, length.out = n + 1)[1:n]
      x <- 0.5 + 0.3 * cos(angles)
      y <- 0.5 + 0.3 * sin(angles)
      points(x, y, pch = 21, bg = node_color, cex = 3)
      text(x, y, labels = nodes$name, pos = 3, cex = 0.8)
    }
    text(0.5, 0.1, "No connections above cutoff", col = "gray50")
    return(invisible(NULL))
  }

  # Create igraph object
  g <- igraph::graph_from_data_frame(edges, directed = !symmetric, vertices = nodes)

  # Layout
  layout <- igraph::layout_with_fr(g)

  # Scale edge widths
  edge_widths <- igraph::E(g)$weight / 30  # 90% -> 3, 60% -> 2
  edge_widths <- pmax(edge_widths, 0.5)

  # Plot
  plot(g,
       layout = layout,
       vertex.size = 25,
       vertex.color = node_color,
       vertex.frame.color = "white",
       vertex.label = igraph::V(g)$name,
       vertex.label.color = "black",
       vertex.label.cex = 0.8,
       edge.width = edge_widths,
       edge.color = edge_color,
       edge.arrow.size = if (symmetric) 0 else 0.4,
       edge.label = if (show_weights) paste0(igraph::E(g)$weight, "%") else NA,
       edge.label.cex = 0.7,
       edge.label.color = "gray30",
       main = title)

  invisible(g)
}
