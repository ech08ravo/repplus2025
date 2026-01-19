library(OpenRepGrid)

# Test all rgrid files in dataExamples
files <- list.files("dataExamples", pattern = "\\.rgrid$", full.names = TRUE)

for (file in files) {
  cat("\n========================================\n")
  cat("Testing:", basename(file), "\n")
  cat("========================================\n")

  tryCatch({
    txt <- readLines(file, warn = FALSE, encoding = "UTF-8")
    cat("Lines read:", length(txt), "\n")

    # Parse constructs
    c_lines <- grep("^C\\d+\t", txt, value = TRUE)
    cat("Constructs found:", length(c_lines), "\n")

    if (length(c_lines) > 0) {
      cons_split <- lapply(c_lines, function(l) {
        toks <- strsplit(l, "\t")[[1]]
        toks[nzchar(toks)]
      })
      left <- vapply(cons_split, function(p) if (length(p) >= 2) p[length(p) - 1] else NA_character_, character(1))
      right <- vapply(cons_split, function(p) if (length(p) >= 1) p[length(p)] else NA_character_, character(1))
      cat("Construct poles:\n")
      for (i in seq_along(left)) {
        cat("  ", left[i], " - ", right[i], "\n")
      }
      n_c <- length(left)

      # Parse elements
      e_lines <- grep("^E\\d+\t", txt, value = TRUE)
      cat("\nElements found:", length(e_lines), "\n")

      if (length(e_lines) > 0) {
        n_e <- length(e_lines)
        elements <- character(n_e)
        scores_mat <- matrix(NA_real_, nrow = n_e, ncol = n_c)

        for (i in seq_len(n_e)) {
          toks <- strsplit(e_lines[i], "\t")[[1]]
          toks <- toks[nzchar(toks)]
          if (length(toks) < (n_c + 1)) {
            cat("  Warning: Element", i, "has insufficient tokens\n")
            next
          }
          elements[i] <- toks[length(toks)]
          start <- (length(toks) - 1) - n_c + 1
          end <- length(toks) - 1
          if (start >= 1 && end >= start) {
            sc <- suppressWarnings(as.numeric(toks[start:end]))
            scores_mat[i, ] <- sc
            cat("  Element:", elements[i], "Ratings:", paste(toks[start:end], collapse = ", "), "\n")
          }
        }

        cat("\nScores matrix dimensions:", nrow(scores_mat), "x", ncol(scores_mat), "\n")
        cat("Missing values (NA or ?):", sum(is.na(scores_mat)), "\n")

        # Try to create repgrid object
        scores_vec <- as.vector(t(scores_mat))
        cat("Total scores:", length(scores_vec), "\n")
        cat("NA count in vector:", sum(is.na(scores_vec)), "\n")

        if (any(is.na(scores_vec))) {
          cat("WARNING: Grid contains missing values - imputing with 4\n")
          scores_vec[is.na(scores_vec)] <- 4
        }

        repgrid_obj <- makeRepgrid(list(
          name = elements,
          l.name = left,
          r.name = right,
          scores = scores_vec
        ))
        cat("SUCCESS: Created repgrid object\n")
      }
    }
  }, error = function(e) {
    cat("ERROR:", conditionMessage(e), "\n")
  })
}
