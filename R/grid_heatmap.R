# Grid-shaped heatmaps, drawn the RepPlus way: elements across the bottom
# in grid order, one row per construct (first construct at the top), the
# left pole labelled on the left axis and the right pole on the right axis.
# Every grid-shaped plot (single-grid heatmap, Mode, MINUS, CORE) goes
# through here so they all read the same way.

# Wrap a long pole label onto several lines so the side margins stay sane
wrap_pole <- function(x, width = 28) {
  vapply(x, function(s) paste(strwrap(s, width = width), collapse = "\n"),
         character(1), USE.NAMES = FALSE)
}

# Margin (in text lines) needed to fit the widest of `labels` at `cex`
label_margin_lines <- function(labels, cex) {
  if (length(labels) == 0) return(1)
  w <- max(strwidth(labels, units = "inches", cex = cex), na.rm = TRUE)
  w / par("csi") + 1.5
}

# Which palette entry a value lands on - the same mapping image() applies
# across zlim. Used to pick a label colour that contrasts with its own cell.
palette_index <- function(v, zlim, n) {
  if (!is.finite(v)) return(1L)
  span <- diff(zlim)
  frac <- if (!is.finite(span) || span == 0) 0.5 else (v - zlim[1]) / span
  idx <- as.integer(round(frac * (n - 1))) + 1L
  max(1L, min(as.integer(n), idx))
}

#' Draw a grid heatmap
#' @param mat Matrix, elements (rows) x constructs (cols), as scores_mat
#' @param elements,left_poles,right_poles Labels, in the same order as mat
#' @param colors Palette vector for image()
#' @param zlim Value range mapped onto the palette
#' @param value_cex Text size of the cell values
#' @param value_fmt Function turning a cell value into its label
#' @param value_col Function giving the label colour for a cell value
#' @param subtitle Smaller line under the title - the grid's elicitation
#'   context, where the file carries one
#' @param elem_col,pole_col Colours for the element labels along the bottom
#'   and the construct pole labels down each side. pole_col may be one colour
#'   per construct, to show which grid each one came from.
#' @param element_hclust,construct_hclust Optional hclust objects. When given,
#'   a dendrogram is drawn above the elements and to the right of the
#'   constructs. The matrix must already be in the order those trees imply -
#'   leaf k across is element k, leaf k down is construct k - which is what
#'   reordering by hc$order gives you. A colour bar cannot be shown at the same
#'   time: it splits the device, and the construct tree needs that same strip.
#' @param show_match_pct Label each dendrogram join with the percentage at
#'   which those two clusters merged. FOCUS stores a join's height as
#'   100 - match, so the figure is the one the sort used, not a recomputation.
#' @param grid_lines Draw cell boundaries. Worth turning on when the cells
#'   carry no shading, so the grid still reads as a grid
#' @param note Optional line of text under the element labels
#' @param legend_title If not NULL, draw a colour bar to the right with
#'   ticks at legend_at labelled legend_labels
draw_grid_heatmap <- function(mat, elements, left_poles, right_poles,
                              colors, zlim, title = NULL, subtitle = NULL,
                              text_size = 1,
                              show_values = TRUE, value_cex = 0.8 * text_size,
                              value_fmt = function(v) sprintf("%.0f", v),
                              value_col = function(v) "black",
                              elem_col = "black", pole_col = "black",
                              element_hclust = NULL, construct_hclust = NULL,
                              show_match_pct = FALSE,
                              grid_lines = FALSE,
                              note = NULL, legend_title = NULL,
                              legend_at = NULL, legend_labels = legend_at) {
  n_e <- nrow(mat)
  n_c <- ncol(mat)
  if (!is.finite(diff(zlim)) || diff(zlim) == 0) zlim <- zlim[1] + c(-0.5, 0.5)

  pole_cex <- 0.75 * text_size
  elem_cex <- 0.8 * text_size
  left_lab <- wrap_pole(left_poles)
  right_lab <- wrap_pole(right_poles)

  # A colour bar splits the device in two, and the construct dendrogram wants
  # the strip the bar would occupy. Asking for both is a mistake worth naming
  # rather than drawing something overlapping.
  show_dendro_e <- !is.null(element_hclust) && n_e > 1
  show_dendro_c <- !is.null(construct_hclust) && n_c > 1
  if (!is.null(legend_title) && (show_dendro_e || show_dendro_c)) {
    stop("draw_grid_heatmap(): a legend and dendrograms cannot share the plot; ",
         "drop legend_title to show the trees.")
  }

  if (!is.null(legend_title)) layout(matrix(c(1, 2), nrow = 1), widths = c(6, 1))

  din <- par("din")
  csi <- par("csi")                      # height of one margin line, in inches
  # Tree depth, in inches. Capped so a tall window does not hand most of the
  # plot to the dendrograms, and floored so a short one still shows them.
  dend_top_in <- if (show_dendro_e) min(1.1, max(0.4, din[2] * 0.14)) else 0
  dend_right_in <- if (show_dendro_c) min(1.1, max(0.4, din[1] * 0.11)) else 0

  right_lab_in <- if (length(right_lab)) {
    max(strwidth(right_lab, units = "inches", cex = pole_cex), na.rm = TRUE)
  } else 0

  # The construct tree's join labels are left-aligned and run outwards past it,
  # so the margin has to hold them or the outermost one falls off the device.
  pct_cex <- 0.62 * text_size
  pct_w <- if (show_match_pct && show_dendro_c) {
    strwidth("100%", units = "inches", cex = pct_cex) * 1.3
  } else 0

  bottom_mar <- label_margin_lines(elements, elem_cex) + if (is.null(note)) 0.5 else 2
  left_mar <- label_margin_lines(left_lab, pole_cex)
  right_mar <- label_margin_lines(right_lab, pole_cex) + dend_right_in / csi +
    pct_w / csi
  top_mar <- if (is.null(title)) 1.5 else 3.5
  if (!is.null(subtitle)) top_mar <- top_mar + 1.4
  top_mar <- top_mar + dend_top_in / csi
  # a little headroom so the topmost join's label is not clipped
  if (show_match_pct && show_dendro_e) top_mar <- top_mar + 0.9
  par(mar = c(bottom_mar, left_mar, top_mar, right_mar), family = "sans")

  # image() puts z[i, k] at (x = i, y = k); reverse the construct columns
  # so construct 1 lands on the top row
  # With a dendrogram above, the top margin is no longer just the title's -
  # image() would place main() relative to the plot edge, underneath the tree.
  # In that case the title and subtitle are placed by hand, above it.
  has_dendro <- show_dendro_e || show_dendro_c

  image(1:n_e, 1:n_c, mat[, n_c:1, drop = FALSE],
        col = colors, zlim = zlim, axes = FALSE, xlab = "", ylab = "",
        main = if (has_dendro) NULL else title, cex.main = text_size * 1.1)

  if (has_dendro && !is.null(title)) {
    title_line <- top_mar - 1.6
    mtext(title, side = 3, line = title_line, cex = text_size * 1.1, font = 2)
    if (!is.null(subtitle)) {
      mtext(subtitle, side = 3, line = title_line - 1.2,
            cex = 0.72 * text_size, col = "#555555")
    }
  } else if (!is.null(subtitle)) {
    mtext(subtitle, side = 3, line = 0.6, cex = 0.72 * text_size, col = "#555555")
  }

  if (grid_lines) {
    abline(v = seq(0.5, n_e + 0.5, by = 1), col = "#CCCCCC", lwd = 0.5)
    abline(h = seq(0.5, n_c + 0.5, by = 1), col = "#CCCCCC", lwd = 0.5)
  }

  if (show_values) {
    for (i in seq_len(n_e)) {
      for (j in seq_len(n_c)) {
        v <- mat[i, j]
        if (!is.na(v)) {
          text(i, n_c - j + 1, value_fmt(v), col = value_col(v),
               cex = value_cex, font = 2)
        }
      }
    }
  }

  axis(1, at = 1:n_e, labels = elements, las = 2, cex.axis = elem_cex,
       col.axis = elem_col)

  if (length(pole_col) <= 1) {
    axis(2, at = n_c:1, labels = left_lab, las = 1, cex.axis = pole_cex,
         col.axis = pole_col)
    axis(4, at = n_c:1, labels = right_lab, las = 1, cex.axis = pole_cex,
         col.axis = pole_col)
  } else {
    # col.axis is one graphical parameter for the whole axis - axis() will not
    # take a colour per label - so the ticks are drawn bare and each label is
    # placed by hand. text() rather than mtext() because a wrapped pole label
    # carries newlines, which mtext does not lay out.
    pc <- rep_len(pole_col, n_c)
    axis(2, at = n_c:1, labels = FALSE, cex.axis = pole_cex)
    axis(4, at = n_c:1, labels = FALSE, cex.axis = pole_cex)
    old_xpd <- par("xpd"); par(xpd = NA)
    gap <- strwidth("m", cex = pole_cex)
    for (j in seq_len(n_c)) {
      y <- n_c - j + 1
      text(0.5 - gap, y, left_lab[j], adj = c(1, 0.5),
           cex = pole_cex, col = pc[j])
      text(n_e + 0.5 + gap, y, right_lab[j], adj = c(0, 0.5),
           cex = pole_cex, col = pc[j])
    }
    par(xpd = old_xpd)
  }
  box()

  # --- dendrograms ---------------------------------------------------------
  # image() uses xaxs/yaxs = "i", so the user window is exactly the cell
  # extent: x spans 0.5 .. n_e + 0.5 and y 0.5 .. n_c + 0.5. That makes the
  # conversion from inches to user units a straight ratio against par("pin").
  if (show_dendro_e || show_dendro_c) {
    ux <- n_e / par("pin")[1]            # user units per inch, across
    uy <- n_c / par("pin")[2]            # user units per inch, down
    old_xpd <- par("xpd"); par(xpd = NA)

    if (show_dendro_e) {
      lay <- dendro_layout(element_hclust, seq_len(n_e))
      if (nrow(lay$segs) > 0) {
        max_h <- max(element_hclust$height)
        if (!is.finite(max_h) || max_h <= 0) max_h <- 1
        base_y <- n_c + 0.5 + 0.10 * uy          # small gap above the box
        span <- max(0, dend_top_in - 0.14) * uy
        to_y <- function(h) base_y + (h / max_h) * span
        segments(lay$segs[, 1], to_y(lay$segs[, 2]),
                 lay$segs[, 3], to_y(lay$segs[, 4]), col = "#555555", lwd = 1)
        if (show_match_pct && nrow(lay$nodes) > 0) {
          text(lay$nodes[, 1], to_y(lay$nodes[, 2]) + span * 0.07,
               sprintf("%.0f%%", 100 - lay$nodes[, 2]),
               cex = pct_cex, col = "#333333")
        }
      }
    }

    if (show_dendro_c) {
      # Construct j is drawn at y = n_c - j + 1, so leaf k down the display is
      # at n_c - k + 1; dendro_layout wants those positions in display order.
      lay <- dendro_layout(construct_hclust, n_c:1)
      if (nrow(lay$segs) > 0) {
        max_h <- max(construct_hclust$height)
        if (!is.finite(max_h) || max_h <= 0) max_h <- 1
        # Start clear of the right pole labels, which sit in the same margin.
        base_x <- n_e + 0.5 + (right_lab_in + 0.12) * ux
        span <- max(0, dend_right_in - 0.14) * ux
        to_x <- function(h) base_x + (h / max_h) * span
        segments(to_x(lay$segs[, 2]), lay$segs[, 1],
                 to_x(lay$segs[, 4]), lay$segs[, 3], col = "#555555", lwd = 1)
        if (show_match_pct && nrow(lay$nodes) > 0) {
          # Left-aligned, so the label starts clear of its own join line.
          text(to_x(lay$nodes[, 2]) + span * 0.07, lay$nodes[, 1],
               sprintf("%.0f%%", 100 - lay$nodes[, 2]),
               cex = pct_cex, col = "#333333", adj = c(0, 0.5))
        }
      }
    }
    par(xpd = old_xpd)
  }

  if (!is.null(note)) {
    mtext(note, side = 1, line = bottom_mar - 1.2, cex = 0.7 * text_size)
  }

  if (!is.null(legend_title)) {
    par(mar = c(bottom_mar, 0.5, top_mar, 3), family = "sans")
    vals <- seq(zlim[1], zlim[2], length.out = 100)
    image(1, vals, t(as.matrix(vals)), col = colors,
          axes = FALSE, xlab = "", ylab = "")
    if (is.null(legend_at)) legend_at <- c(zlim[1], mean(zlim), zlim[2])
    if (is.null(legend_labels)) legend_labels <- round(legend_at, 1)
    axis(4, at = legend_at, labels = legend_labels, las = 2, cex.axis = 0.8 * text_size)
    mtext(legend_title, side = 3, line = 0.5, cex = 0.8 * text_size)
    box()
    layout(1)
  }
  invisible(NULL)
}

# Split "left - right" construct labels back into poles (MINUS and CORE
# carry the combined label)
split_construct_labels <- function(labels) {
  parts <- strsplit(labels, " - ", fixed = TRUE)
  list(left = vapply(parts, `[`, character(1), 1),
       right = vapply(parts, function(p) if (length(p) > 1) paste(p[-1], collapse = " - ") else "",
                      character(1)))
}
