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
#' @param grid_lines Draw cell boundaries. Worth turning on when the cells
#'   carry no shading, so the grid still reads as a grid
#' @param note Optional line of text under the element labels
#' @param legend_title If not NULL, draw a colour bar to the right with
#'   ticks at legend_at labelled legend_labels
draw_grid_heatmap <- function(mat, elements, left_poles, right_poles,
                              colors, zlim, title = NULL, text_size = 1,
                              show_values = TRUE, value_cex = 0.8 * text_size,
                              value_fmt = function(v) sprintf("%.0f", v),
                              value_col = function(v) "black",
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

  if (!is.null(legend_title)) layout(matrix(c(1, 2), nrow = 1), widths = c(6, 1))

  bottom_mar <- label_margin_lines(elements, elem_cex) + if (is.null(note)) 0.5 else 2
  left_mar <- label_margin_lines(left_lab, pole_cex)
  right_mar <- label_margin_lines(right_lab, pole_cex)
  top_mar <- if (is.null(title)) 1.5 else 3.5
  par(mar = c(bottom_mar, left_mar, top_mar, right_mar), family = "sans")

  # image() puts z[i, k] at (x = i, y = k); reverse the construct columns
  # so construct 1 lands on the top row
  image(1:n_e, 1:n_c, mat[, n_c:1, drop = FALSE],
        col = colors, zlim = zlim, axes = FALSE, xlab = "", ylab = "",
        main = title, cex.main = text_size * 1.1)

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

  axis(1, at = 1:n_e, labels = elements, las = 2, cex.axis = elem_cex)
  axis(2, at = n_c:1, labels = left_lab, las = 1, cex.axis = pole_cex)
  axis(4, at = n_c:1, labels = right_lab, las = 1, cex.axis = pole_cex)
  box()

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
