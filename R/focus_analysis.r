# Focus clustering analysis functions
# Based on Shaw (1980) FOCUS algorithm from RepGrid manual

#' Compute element-element similarity matrix (vectorised)
compute_element_similarities <- function(scores_matrix, power = 1.0) {
  n_elements <- nrow(scores_matrix)
  sim_matrix <- matrix(0, nrow = n_elements, ncol = n_elements)

  # Diagonal = 100 (perfect match with self)
  diag(sim_matrix) <- 100

  # Vectorised computation of pairwise Minkowski distances
  # For each element i, compute distance to all other elements j
  scale_range <- max(scores_matrix, na.rm = TRUE) - min(scores_matrix, na.rm = TRUE)
  n_constructs <- ncol(scores_matrix)
  max_distance <- n_constructs * scale_range

  # Pairwise comparison using sweep so the broadcast is well-defined when
  # n_elements != n_constructs (matrix - matrix with mismatched row counts
  # would error "non-conformable arrays"; sweep applies the row-i vector
  # along the column margin of the full matrix).
  for (i in 1:n_elements) {
    diff_mat <- abs(sweep(scores_matrix, 2, scores_matrix[i, ], "-"))
    # Remove NAs for distance calculation
    diff_mat[is.na(diff_mat)] <- 0
    # Per-element Minkowski distance: sum across constructs (the column
    # axis), one distance per element row.
    distances <- rowSums(diff_mat^power)^(1/power)
    # Convert to similarity (0-100)
    sim_matrix[i, -i] <- pmax(0, 100 * (1 - distances[-i] / max_distance))
  }

  sim_matrix
}

#' Compute construct-construct similarity matrix (vectorised)
compute_construct_similarities <- function(scores_matrix, power = 1.0) {
  n_constructs <- ncol(scores_matrix)
  sim_matrix <- matrix(0, nrow = n_constructs, ncol = n_constructs)

  # Diagonal = 100 (perfect match with self)
  diag(sim_matrix) <- 100

  # Vectorised computation: construct i vs all other constructs j
  scale_range <- max(scores_matrix, na.rm = TRUE) - min(scores_matrix, na.rm = TRUE)
  scale_mid <- (max(scores_matrix, na.rm = TRUE) + min(scores_matrix, na.rm = TRUE)) / 2
  n_elements <- nrow(scores_matrix)
  max_distance <- n_elements * scale_range

  for (i in 1:n_constructs) {
    construct_i <- scores_matrix[, i]
    # Normal orientation: direct differences
    diff_normal <- abs(construct_i - scores_matrix)
    diff_normal[is.na(diff_normal)] <- 0
    dist_normal <- colSums(diff_normal^power)^(1/power)

    # Reversed orientation: flip construct around midpoint
    construct_i_rev <- 2 * scale_mid - construct_i
    diff_reversed <- abs(construct_i_rev - scores_matrix)
    diff_reversed[is.na(diff_reversed)] <- 0
    dist_reversed <- colSums(diff_reversed^power)^(1/power)

    # Use the better match (lower distance) for each pair
    distances <- pmin(dist_normal, dist_reversed)
    # Convert to similarity (0-100), preserving diagonal
    sim_matrix[i, -i] <- pmax(0, 100 * (1 - distances[-i] / max_distance))
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


# ---------------------------------------------------------------------------
# Grid display rendering (WebGrid "Display" layout)
#
# Constructs are rows (poles flanking the ratings box), elements are columns
# with staircased labels below joined to their column by a leader line.
# Dendrograms, when supplied, sit above the element columns and to the right
# of the construct rows. Everything is drawn in a single plot region so the
# ratings box stays compact regardless of label lengths.
# ---------------------------------------------------------------------------

#' Split "left - right" construct labels back into pole pairs
split_pole_labels <- function(labels) {
  pos <- regexpr(" - ", labels, fixed = TRUE)
  left <- ifelse(pos > 0, substr(labels, 1, pos - 1), labels)
  right <- ifelse(pos > 0, substr(labels, pos + 3, nchar(labels)), "")
  list(left = left, right = right)
}

#' Dendrogram segments for arbitrary (possibly non-uniform) leaf positions
#'
#' Returns a matrix of segments with columns pos0, height0, pos1, height1.
#' `leaf_pos` is indexed by display position; it is mapped back onto the
#' original observation indices via hc$order.
dendro_segments <- function(hc, leaf_pos) {
  n <- length(hc$order)
  if (n < 2) return(matrix(numeric(0), ncol = 4))

  pos_by_obs <- numeric(n)
  pos_by_obs[hc$order] <- leaf_pos

  node_pos <- numeric(n - 1)
  segs <- matrix(NA_real_, nrow = 3 * (n - 1), ncol = 4)
  row <- 1

  for (k in seq_len(n - 1)) {
    merge_k <- hc$merge[k, ]
    child_pos <- numeric(2)
    child_h <- numeric(2)
    for (s in 1:2) {
      if (merge_k[s] < 0) {
        child_pos[s] <- pos_by_obs[-merge_k[s]]
        child_h[s] <- 0
      } else {
        child_pos[s] <- node_pos[merge_k[s]]
        child_h[s] <- hc$height[merge_k[s]]
      }
    }
    node_pos[k] <- mean(child_pos)
    h <- hc$height[k]

    segs[row, ] <- c(child_pos[1], child_h[1], child_pos[1], h); row <- row + 1
    segs[row, ] <- c(child_pos[2], child_h[2], child_pos[2], h); row <- row + 1
    segs[row, ] <- c(child_pos[1], h, child_pos[2], h); row <- row + 1
  }
  segs
}

#' Pick a readable text colour for a given cell background
contrast_text_col <- function(bg) {
  rgb_vals <- col2rgb(bg) / 255
  luminance <- 0.2126 * rgb_vals[1, ] + 0.7152 * rgb_vals[2, ] + 0.0722 * rgb_vals[3, ]
  ifelse(luminance < 0.45, "white", "black")
}

#' Render a repertory grid in the compact WebGrid display layout
#'
#' @param scores Matrix of ratings, constructs in rows, elements in columns,
#'   already in the order they should be drawn.
#' @param row_pos,col_pos Optional positions (in cell units) for constructs and
#'   elements. Non-uniform positions give the SPACED variant.
#' @param element_hclust,construct_hclust Optional hclust objects; when given,
#'   dendrograms are drawn above the columns and right of the rows.
render_grid_display <- function(scores, left_poles, right_poles, element_labels,
                                title = NULL, subtitle = NULL,
                                row_pos = NULL, col_pos = NULL,
                                element_hclust = NULL, construct_hclust = NULL,
                                show_values = TRUE, show_shading = TRUE,
                                use_color = FALSE, text_size = 1.0, cell_size = 1.0,
                                heat_low = "#0072B2", heat_high = "#D55E00",
                                element_col = "#C0392B", construct_col = "#1F5FA9") {

  n_const <- nrow(scores)
  n_elem <- ncol(scores)
  if (is.null(row_pos)) row_pos <- seq_len(n_const)
  if (is.null(col_pos)) col_pos <- seq_len(n_elem)
  if (!use_color) {
    element_col <- "#333333"
    construct_col <- "#333333"
  }

  op <- par(no.readonly = TRUE)
  on.exit(par(op), add = TRUE)
  par(mar = c(0, 0, 0, 0), xpd = NA)

  label_cex <- 0.95 * text_size
  value_cex <- 0.95 * cell_size * text_size
  title_cex <- 1.25 * text_size

  din <- par("din")
  pad <- 0.08

  # --- text metrics (inches) -------------------------------------------------
  digit_w <- strwidth("0", units = "inches", cex = value_cex)
  digit_h <- strheight("0", units = "inches", cex = value_cex)
  line_h <- strheight("Ag", units = "inches", cex = label_cex) * 1.75
  left_lab_w <- if (n_const > 0) max(strwidth(left_poles, units = "inches", cex = label_cex)) else 0
  right_lab_w <- if (n_const > 0) max(strwidth(right_poles, units = "inches", cex = label_cex)) else 0
  elem_lab_w <- strwidth(element_labels, units = "inches", cex = label_cex)

  # Cells stay tight around the rating digits - this is what keeps the grid
  # compact instead of stretching to fill the device.
  max_cell_w <- digit_w * 2.6 * cell_size
  max_cell_h <- digit_h * 2.4 * cell_size

  # --- fixed margin components ----------------------------------------------
  dendro_top_h <- if (!is.null(element_hclust) && n_elem > 1)
    min(1.3, max(0.45, din[2] * 0.16)) else 0
  dendro_right_w <- if (!is.null(construct_hclust) && n_const > 1)
    min(1.3, max(0.45, din[1] * 0.13)) else 0

  title_h <- if (!is.null(title)) strheight("Ag", units = "inches", cex = title_cex) * 2.2 else 0
  if (!is.null(subtitle)) title_h <- title_h + line_h

  mar_top <- pad + title_h + dendro_top_h
  mar_left <- pad + left_lab_w + pad
  # Staircase: one line per element below the box, plus clearance for the
  # descenders of the deepest label.
  mar_bottom <- pad + (n_elem + 0.6) * line_h

  x_units <- diff(range(col_pos)) + 1
  y_units <- diff(range(row_pos)) + 1

  # Right margin has to hold the right poles, the construct dendrogram and any
  # staircase label that runs past the last column. The last depends on the
  # cell width, which depends on the margin - so settle it in a few passes.
  mar_right <- pad + right_lab_w + pad + dendro_right_w
  cell_w <- max_cell_w
  for (pass in 1:3) {
    avail_w <- din[1] - mar_left - mar_right
    cell_w <- min(max_cell_w, max(digit_w * 1.2, avail_w / x_units))
    grid_w <- cell_w * x_units
    # Distance from each column's centre to the right edge of the box
    to_right_edge <- (max(col_pos) + 0.5 - col_pos) * cell_w
    overflow <- max(elem_lab_w + pad * 2 - to_right_edge, 0)
    mar_right <- max(pad + right_lab_w + pad + dendro_right_w, overflow + pad)
  }

  avail_h <- din[2] - mar_top - mar_bottom
  cell_h <- min(max_cell_h, max(digit_h * 1.1, avail_h / y_units))
  grid_w <- cell_w * x_units
  grid_h <- cell_h * y_units

  # Leftover space: keep the box near the top, nudged right of the poles
  slack_x <- max(0, din[1] - mar_left - mar_right - grid_w)
  slack_y <- max(0, din[2] - mar_top - mar_bottom - grid_h)
  mai_left <- mar_left + slack_x / 2
  mai_right <- max(0.02, din[1] - mai_left - grid_w)
  mai_top <- mar_top
  mai_bottom <- max(0.02, din[2] - mai_top - grid_h)
  if (slack_y > 0) {
    # Breathe under the title, but never at the cost of the staircase labels.
    mai_top <- mar_top + min(slack_y * 0.25, 0.4)
    mai_top <- min(mai_top, max(mar_top, din[2] - grid_h - mar_bottom))
    mai_bottom <- max(0.02, din[2] - mai_top - grid_h)
  }

  par(mai = c(mai_bottom, mai_left, mai_top, mai_right))

  x_lim <- c(min(col_pos) - 0.5, max(col_pos) + 0.5)
  y_lim <- c(max(row_pos) + 0.5, min(row_pos) - 0.5)  # first construct on top
  plot(NA, xlim = x_lim, ylim = y_lim, xaxs = "i", yaxs = "i",
       axes = FALSE, xlab = "", ylab = "")

  # inches -> user-unit helpers (y axis is reversed, so down is +user)
  dx <- function(inches) inches * diff(x_lim) / par("pin")[1]
  dy <- function(inches) inches * abs(diff(y_lim)) / par("pin")[2]

  cell_hw <- if (n_elem > 1) min(diff(sort(col_pos)), 1) / 2 * 0.96 else 0.48
  cell_hh <- if (n_const > 1) min(diff(sort(row_pos)), 1) / 2 * 0.96 else 0.48

  # --- ratings ---------------------------------------------------------------
  if (show_shading) {
    color_ramp <- if (use_color) {
      colorRampPalette(c(heat_low, "#FFFFFF", heat_high))(100)
    } else {
      gray.colors(100, start = 0.97, end = 0.35)
    }
    val_range <- range(scores, na.rm = TRUE)
    if (!is.finite(diff(val_range)) || diff(val_range) == 0) {
      val_range <- c(val_range[1] - 0.5, val_range[1] + 0.5)
    }
  }

  for (i in seq_len(n_const)) {
    for (j in seq_len(n_elem)) {
      val <- scores[i, j]
      x <- col_pos[j]
      y <- row_pos[i]
      cell_col <- "white"
      if (show_shading && !is.na(val)) {
        idx <- max(1, min(100, round((val - val_range[1]) / diff(val_range) * 99) + 1))
        cell_col <- color_ramp[idx]
        rect(x - cell_hw, y - cell_hh, x + cell_hw, y + cell_hh,
             col = cell_col, border = NA)
      }
      if (show_values && !is.na(val)) {
        text(x, y, sprintf("%.0f", val), cex = value_cex,
             col = if (show_shading) contrast_text_col(cell_col) else "black")
      }
    }
  }
  rect(x_lim[1], y_lim[1], x_lim[2], y_lim[2], border = "#555555", lwd = 1)

  # --- construct poles -------------------------------------------------------
  gap_u <- dx(pad)
  text(x_lim[1] - gap_u, row_pos, left_poles, adj = c(1, 0.5),
       cex = label_cex, col = construct_col)
  text(x_lim[2] + gap_u, row_pos, right_poles, adj = c(0, 0.5),
       cex = label_cex, col = construct_col)

  # --- staircased element labels --------------------------------------------
  y_bottom <- y_lim[1]
  for (j in seq_len(n_elem)) {
    depth <- (n_elem - j + 1) * line_h
    y_lab <- y_bottom + dy(depth)
    segments(col_pos[j], y_bottom, col_pos[j], y_lab, col = "#999999", lwd = 0.8)
    text(col_pos[j] + dx(pad * 0.6), y_lab, element_labels[j], adj = c(0, 0.5),
         cex = label_cex, col = element_col)
  }

  # --- dendrograms -----------------------------------------------------------
  if (dendro_top_h > 0) {
    segs <- dendro_segments(element_hclust, col_pos)
    if (nrow(segs) > 0) {
      max_h <- max(element_hclust$height)
      if (max_h <= 0) max_h <- 1
      to_y <- function(h) y_lim[2] - dy(pad + (h / max_h) * (dendro_top_h - pad))
      segments(segs[, 1], to_y(segs[, 2]), segs[, 3], to_y(segs[, 4]),
               col = "#555555", lwd = 1)
    }
  }

  if (dendro_right_w > 0) {
    segs <- dendro_segments(construct_hclust, row_pos)
    if (nrow(segs) > 0) {
      max_h <- max(construct_hclust$height)
      if (max_h <= 0) max_h <- 1
      base_in <- right_lab_w + pad * 2
      to_x <- function(h) x_lim[2] + dx(base_in + (h / max_h) * (dendro_right_w - pad))
      segments(to_x(segs[, 2]), segs[, 1], to_x(segs[, 4]), segs[, 3],
               col = "#555555", lwd = 1)
    }
  }

  # --- title -----------------------------------------------------------------
  if (!is.null(title)) {
    text(grconvertX(0.5, "ndc", "user"), grconvertY(0.985, "ndc", "user"),
         title, adj = c(0.5, 1), font = 2, cex = title_cex)
  }
  if (!is.null(subtitle)) {
    y_sub <- grconvertY(0.985, "ndc", "user") +
      dy(strheight("Ag", units = "inches", cex = title_cex) * 1.6)
    text(grconvertX(0.5, "ndc", "user"), y_sub, subtitle, adj = c(0.5, 1),
         cex = 0.75 * text_size, col = "#666666")
  }

  invisible(NULL)
}

#' Build the "top match" caption line shown under the title
focus_match_subtitle <- function(focus_result) {
  parts <- character(0)

  elem_sim <- focus_result$element_similarities[focus_result$element_order,
                                                focus_result$element_order, drop = FALSE]
  if (nrow(elem_sim) > 1) {
    diag(elem_sim) <- 0
    top <- which(elem_sim == max(elem_sim, na.rm = TRUE), arr.ind = TRUE)[1, ]
    parts <- c(parts, sprintf("Closest elements: %s / %s (%.0f%%)",
                              focus_result$sorted_elements[top[1]],
                              focus_result$sorted_elements[top[2]],
                              elem_sim[top[1], top[2]]))
  }

  const_sim <- focus_result$construct_similarities[focus_result$construct_order,
                                                   focus_result$construct_order, drop = FALSE]
  if (nrow(const_sim) > 1) {
    diag(const_sim) <- 0
    top <- which(const_sim == max(const_sim, na.rm = TRUE), arr.ind = TRUE)[1, ]
    parts <- c(parts, sprintf("closest constructs: %.0f%%", const_sim[top[1], top[2]]))
  }

  if (length(parts) == 0) return(NULL)
  paste(parts, collapse = "   |   ")
}

#' Resolve construct pole labels for a focus result
focus_poles <- function(focus_result, construct_left = NULL, construct_right = NULL) {
  n_const <- length(focus_result$sorted_constructs)
  # Only trust supplied poles if they still match the analysed constructs -
  # the user may have edited the grid since Focus was run.
  if (!is.null(construct_left) && !is.null(construct_right) &&
      length(construct_left) == n_const && length(construct_right) == n_const) {
    ord <- focus_result$construct_order
    return(list(left = construct_left[ord], right = construct_right[ord]))
  }
  split_pole_labels(focus_result$sorted_constructs)
}

#' Plot a repertory grid in the WebGrid display layout (no clustering)
plot_display_grid <- function(scores_matrix, element_names,
                              construct_left, construct_right,
                              title = "Display Grid", subtitle = NULL,
                              show_values = TRUE, show_shading = TRUE,
                              use_color = FALSE, text_size = 1.0, cell_size = 1.0,
                              heat_low = "#0072B2", heat_high = "#D55E00") {
  render_grid_display(
    scores = t(scores_matrix),
    left_poles = construct_left,
    right_poles = construct_right,
    element_labels = element_names,
    title = title, subtitle = subtitle,
    show_values = show_values, show_shading = show_shading, use_color = use_color,
    text_size = text_size, cell_size = cell_size,
    heat_low = heat_low, heat_high = heat_high
  )
}

#' Plot Focus cluster analysis with dendrograms, in the display layout
plot_focus_cluster <- function(focus_result, title = "Focus Cluster Analysis",
                               show_values = TRUE, show_shading = TRUE, use_color = FALSE,
                               text_size = 1.0, cell_size = 1.0,
                               heat_low = "#0072B2", heat_high = "#D55E00",
                               construct_left = NULL, construct_right = NULL) {
  poles <- focus_poles(focus_result, construct_left, construct_right)

  render_grid_display(
    scores = t(focus_result$sorted_matrix),
    left_poles = poles$left,
    right_poles = poles$right,
    element_labels = focus_result$sorted_elements,
    title = title,
    subtitle = focus_match_subtitle(focus_result),
    element_hclust = focus_result$element_hclust,
    construct_hclust = focus_result$construct_hclust,
    show_values = show_values, show_shading = show_shading, use_color = use_color,
    text_size = text_size, cell_size = cell_size,
    heat_low = heat_low, heat_high = heat_high
  )
}

#' Spacing positions from cophenetic distances between adjacent sorted items
spaced_positions <- function(hc, item_order) {
  n <- length(item_order)
  pos <- numeric(n)
  pos[1] <- 1
  if (n < 2) return(pos)

  coph <- as.matrix(cophenetic(hc))
  max_coph <- max(coph)
  if (!is.finite(max_coph) || max_coph == 0) max_coph <- 1

  for (i in 2:n) {
    d <- coph[item_order[i - 1], item_order[i]]
    pos[i] <- pos[i - 1] + 1 + (d / max_coph) * 1.2
  }
  pos
}

#' Plot Focus cluster with SPACED proportional spacing, in the display layout
plot_focus_spaced <- function(focus_result, title = "SPACED: Focus Cluster Analysis",
                              show_values = TRUE, show_shading = TRUE, use_color = FALSE,
                              text_size = 1.0, cell_size = 1.0,
                              heat_low = "#0072B2", heat_high = "#D55E00",
                              construct_left = NULL, construct_right = NULL) {
  poles <- focus_poles(focus_result, construct_left, construct_right)

  subtitle <- focus_match_subtitle(focus_result)
  spacing_note <- "spacing shows similarity distance"
  subtitle <- if (is.null(subtitle)) spacing_note else paste0(subtitle, "   |   ", spacing_note)

  render_grid_display(
    scores = t(focus_result$sorted_matrix),
    left_poles = poles$left,
    right_poles = poles$right,
    element_labels = focus_result$sorted_elements,
    title = title,
    subtitle = subtitle,
    row_pos = spaced_positions(focus_result$construct_hclust, focus_result$construct_order),
    col_pos = spaced_positions(focus_result$element_hclust, focus_result$element_order),
    element_hclust = focus_result$element_hclust,
    construct_hclust = focus_result$construct_hclust,
    show_values = show_values, show_shading = show_shading, use_color = use_color,
    text_size = text_size, cell_size = cell_size,
    heat_low = heat_low, heat_high = heat_high
  )
}
