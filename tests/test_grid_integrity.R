# Regression tests for the path from a .rgrid file to the objects the app
# analyses. These guard two bugs that were silent - neither raised an error,
# both produced plausible-looking wrong numbers:
#
#   1. makeRepgrid() fills matrix(scores, ncol = n_elements, byrow = TRUE), so
#      it needs ratings construct-major. The app passed as.vector(t(scores_mat)),
#      which is element-major, scrambling every value in the Statistics tab.
#   2. Rep Plus stores ratings 0-based while declaring a 1-based scale, and the
#      V2.0 construct layout puts pole anchors before the labels.
#
# Run from the project root:  Rscript tests/test_grid_integrity.R

suppressMessages(library(OpenRepGrid))
source("R/rgrid_io.R")

failures <- 0
check <- function(label, ok, detail = "") {
  if (!isTRUE(ok)) failures <<- failures + 1
  cat(sprintf("%-52s %s%s\n", label, if (isTRUE(ok)) "PASS" else "FAIL",
              if (!isTRUE(ok) && nzchar(detail)) paste0(" - ", detail) else ""))
}

g <- parse_rgrid("dataExamples/yurungi.rgrid")

# --- the parser ------------------------------------------------------------
check("9 elements, 3 constructs",
      length(g$elements) == 9 && length(g$left) == 3)
check("poles are labels, not rating numbers",
      !any(grepl("^[0-9]+$", c(g$left, g$right))), paste(g$left, collapse = "/"))
check("ratings shifted onto the declared scale",
      min(g$scores_mat) >= g$scale[1] && max(g$scores_mat) <= g$scale[2],
      paste(range(g$scores_mat), collapse = "-"))
check("Canvas reads 4 1 5 as the Rep Plus desktop shows it",
      identical(unname(g$scores_mat["Canvas", ]), c(4, 1, 5)))

# --- the grid handed to OpenRepGrid ----------------------------------------
# This is what app.R does; if the ordering ever flips back, every statistic in
# the Statistics tab silently scrambles.
rg <- makeRepgrid(list(name = g$elements, l.name = g$left, r.name = g$right,
                       scores = as.vector(g$scores_mat)))
layer <- getRatingLayer(rg)   # constructs x elements

check("repgrid matches the file cell for cell",
      isTRUE(all.equal(unname(t(layer)), unname(g$scores_mat))))
check("element means match the file",
      isTRUE(all.equal(unname(colMeans(layer)), unname(rowMeans(g$scores_mat)))))
check("construct means match the file",
      isTRUE(all.equal(unname(rowMeans(layer)), unname(colMeans(g$scores_mat)))))

# The scrambling is only visible cell by cell - the overall spread is identical
# either way, which is why it went unnoticed.
wrong <- makeRepgrid(list(name = g$elements, l.name = g$left, r.name = g$right,
                          scores = as.vector(t(g$scores_mat))))
check("element-major ordering really does differ",
      !isTRUE(all.equal(unname(getRatingLayer(wrong)), unname(layer))))

# --- every sample grid survives the round trip -----------------------------
for (f in Sys.glob("dataExamples/*.rgrid")) {
  gg <- try(parse_rgrid(f), silent = TRUE)
  if (inherits(gg, "try-error")) { check(basename(f), FALSE, "parse error"); next }
  r <- makeRepgrid(list(name = gg$elements, l.name = gg$left, r.name = gg$right,
                        scores = as.vector(gg$scores_mat)))
  check(paste("round trip:", basename(f)),
        isTRUE(all.equal(unname(t(getRatingLayer(r))), unname(gg$scores_mat))))
}

cat(sprintf("\n%s\n", if (failures == 0) "All checks passed."
                      else paste(failures, "CHECK(S) FAILED")))
if (failures > 0) quit(status = 1)
