# .rgrid file reading
#
# Three construct-line layouts are in the wild. They differ in how many tokens
# each pole group carries, and field 5 of the line is that count:
#
#   Rep IV      C0 R 100 0 1 1 5           young        presbyopic
#   Rep Plus V1.1  C0 R 1   0 1 1 5        Social       goal
#   Rep Plus V2.0  C0 R 1   0 3 1 5   1* 2 Social  4* 5 goal
#
# V2.0 annotates each pole with the ratings it covers ("1* 2 Social" = the left
# pole spans ratings 1-2, anchored at 1). Taking the last two fields - which is
# what the importer used to do - therefore yields "5" and "goal" for V2.0 files,
# so every construct imported with a left pole of "5".
#
# Fields 6 and 7 are the rating scale (min, max).

#' Is this token a bare rating number rather than a pole label?
is_rating_token <- function(x) {
  !is.na(x) & grepl("^[0-9]+\\*?$", x)
}

#' Extract the two pole labels from one construct line's tokens
extract_poles <- function(toks) {
  n <- length(toks)
  if (n < 2) return(c(NA_character_, NA_character_))

  # Field 5 is the number of tokens per pole group: 1 for Rep IV and V1.1,
  # 3 for V2.0. The label is the last token of each group.
  k <- suppressWarnings(as.integer(toks[5]))
  if (is.na(k) || k < 1 || (n - k) < 6) k <- 1

  left <- toks[n - k]
  right <- toks[n]

  # Safety net for a layout we have not seen: a pole label is never a bare
  # number, so if the group size was wrong, walk back for the last token that
  # does not look like a rating. (A construct genuinely labelled "5" would be
  # misread here, but that is far rarer than an unknown layout.)
  if (is_rating_token(left)) {
    non_numeric <- which(!is_rating_token(toks[seq_len(n - 1)]))
    non_numeric <- non_numeric[non_numeric > 7]
    left <- if (length(non_numeric)) toks[max(non_numeric)] else NA_character_
  }

  c(left, right)
}

#' Rating scale declared on a construct line (fields 6 and 7)
extract_scale <- function(toks) {
  scale <- suppressWarnings(as.numeric(toks[6:7]))
  if (any(is.na(scale)) || scale[2] <= scale[1]) return(c(1, 5))
  scale
}

#' How much to add to stored ratings to put them on the declared scale
#'
#' Rep Plus stores ratings 0-based - a file reading "3 0 4" is displayed as
#' "4 1 5" by the Rep Plus desktop app - while declaring a 1-based scale. The
#' offset is only applied when the data actually fits after shifting, so a file
#' that is already 1-based is never shifted twice.
rgrid_rating_offset <- function(scores, scale, source_tag = "") {
  vals <- scores[!is.na(scores)]
  if (!length(vals)) return(0)
  if (max(vals) + scale[1] > scale[2]) return(0)          # already on the scale
  if (min(vals) < scale[1]) return(scale[1])              # 0 is not a valid rating
  if (grepl("Rep Plus", source_tag, fixed = TRUE)) return(scale[1])
  0
}

#' Read a .rgrid file
#'
#' Returns elements, construct poles, the ratings matrix (elements x
#' constructs, shifted onto the declared scale), the scale itself, and the
#' source application string from the header.
#'
#' @param zero_is_na What a stored `0` means. FALSE (default) reads it as a
#'   rating: Rep Plus stores ratings 0-based, so `0` is the pure left pole and
#'   the grid is shifted onto its declared scale. TRUE reads `0` as "does not
#'   apply" - the convention Bezzi (1996) used in print - in which case the
#'   remaining values are already 1-based and no shift is applied. The two
#'   conventions collide (a Rep Plus grid can hold dozens of legitimate zeros),
#'   so this is the caller's decision, not a guess.
parse_rgrid <- function(file_path, zero_is_na = FALSE) {
  txt <- readLines(file_path, warn = FALSE)

  header <- if (length(txt)) strsplit(txt[1], "\t")[[1]] else character(0)
  source_tag <- if (length(header) >= 12) header[12] else ""

  c_lines <- grep("^C\\d+\\t", txt, value = TRUE)
  if (length(c_lines) == 0) stop("Invalid .rgrid file: no constructs found")

  cons_split <- lapply(c_lines, function(l) {
    toks <- strsplit(l, "\t")[[1]]
    toks[nzchar(toks)]
  })

  poles <- vapply(cons_split, extract_poles, character(2))
  left <- poles[1, ]
  right <- poles[2, ]
  n_c <- length(left)

  scale <- extract_scale(cons_split[[1]])

  e_lines <- grep("^E\\d+\\t", txt, value = TRUE)
  if (length(e_lines) == 0) stop("Invalid .rgrid file: no elements found")

  n_e <- length(e_lines)
  elements <- character(n_e)
  scores_mat <- matrix(NA_real_, nrow = n_e, ncol = n_c)

  for (i in seq_len(n_e)) {
    toks <- strsplit(e_lines[i], "\t")[[1]]
    toks <- toks[nzchar(toks)]
    if (length(toks) < (n_c + 1)) next
    elements[i] <- toks[length(toks)]
    start <- (length(toks) - 1) - n_c + 1
    end <- length(toks) - 1
    if (start >= 1 && end >= start) {
      scores_mat[i, ] <- suppressWarnings(as.numeric(toks[start:end]))
    }
  }

  if (zero_is_na) {
    zeros <- sum(scores_mat == 0, na.rm = TRUE)
    scores_mat[!is.na(scores_mat) & scores_mat == 0] <- NA
    offset <- 0
  } else {
    zeros <- 0
    offset <- rgrid_rating_offset(scores_mat, scale, source_tag)
    if (offset != 0) scores_mat <- scores_mat + offset
  }

  rownames(scores_mat) <- elements
  colnames(scores_mat) <- paste(left, "-", right)

  list(
    elements = elements,
    left = left,
    right = right,
    scores_mat = scores_mat,
    scale = scale,
    source = source_tag,
    offset_applied = offset,
    zero_is_na = zero_is_na,
    n_zero_as_na = zeros,
    n_not_rated = sum(is.na(scores_mat))
  )
}
