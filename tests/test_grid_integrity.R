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

# --- published-source check ------------------------------------------------
# Bezzi (1996) Figure 1 as printed. The paper marks "construct does not apply"
# with 0 and rates 1-5; the .rgrid transcription uses "?" for those cells and
# stores ratings 0-based. Reproducing the printed figure exactly exercises pole
# parsing, the rating offset and N/A handling together.
pub <- matrix(c(
  5,1,1,1,5,5,1,1,5,      NA,5,5,NA,4,5,3,1,1,
  5,1,1,5,1,1,1,NA,NA,    1,5,5,1,1,5,5,NA,NA,
  5,1,1,1,5,5,1,1,5,      NA,1,1,NA,1,1,3,4,5,
  NA,1,1,NA,NA,1,1,4,5,   5,1,2,5,5,3,3,3,1,
  1,5,5,5,1,1,5,5,1,      1,2,2,1,2,2,3,5,5,
  5,4,5,NA,3,3,3,1,1,     5,1,1,5,4,1,2,3,3,
  4,1,2,2,2,3,5,3,1,      1,5,5,5,1,3,5,5,5,
  5,1,1,5,5,3,1,1,1,      1,1,1,1,1,1,3,2,5), nrow = 16, byrow = TRUE)

bz <- parse_rgrid("dataExamples/bezzi1996_expert.rgrid")
check("Bezzi: N/A cells match the published figure",
      identical(is.na(pub), unname(is.na(t(bz$scores_mat)))))
check("Bezzi: all 144 cells match the published figure",
      isTRUE(all.equal(pub, unname(t(bz$scores_mat)))))
check("Bezzi: 12 cells marked not-applicable", sum(is.na(bz$scores_mat)) == 12)

# --- similarity semantics --------------------------------------------------
source("R/focus_analysis.r")
sim2 <- function(m) compute_element_similarities(m, scale = c(1, 5))[1, 2]

check("identical elements match 100%",
      sim2(matrix(c(1,5,3, 1,5,3), 2, byrow = TRUE)) == 100)
check("an unrated cell is excluded, not scored as agreement",
      round(sim2(matrix(c(1,5,3, 5,NA,3), 2, byrow = TRUE))) == 50)
check("elements sharing no rated construct match 0%",
      sim2(matrix(c(1,NA, NA,5), 2, byrow = TRUE)) == 0)
check("matches use the declared scale, not the observed range",
      round(sim2(matrix(c(2,4,2, 4,2,4), 2, byrow = TRUE))) == 50)
check("a grid with N/A cells still clusters",
      !inherits(try(focus_cluster(bz$scores_mat, bz$elements,
                                  paste(bz$left, "-", bz$right),
                                  method = "focus", scale = bz$scale),
                    silent = TRUE), "try-error"))

# --- where ratings start, and what 0 means (independent questions) ----------
mk_tmp <- function(rows, source = "Rep Plus V1.1", scale = c(1, 5)) {
  f <- tempfile(fileext = ".rgrid"); con <- file(f, open = "w", encoding = "UTF-8")
  writeLines(paste("", "Grid", length(rows), length(rows[[1]]), 0, "t", "", "1",
                   "01-Jan-2026", "00:00", "x", source, "RepGrid", sep = "\t"), con)
  for (i in seq_along(rows[[1]]))
    writeLines(sprintf("C%d\tR\t1\t0\t1\t%s\t%s\t\tL%d\tR%d\t", i - 1,
                       scale[1], scale[2], i, i), con)
  for (i in seq_along(rows))
    writeLines(paste0("E", i - 1, "\t1\t0\t", paste(rows[[i]], collapse = "\t"),
                      "\tel", i), con)
  close(con); f
}

check("0-based file reaching 4 is read as 1-5",
      parse_rgrid(mk_tmp(list(c(0,4,2), c(4,0,3))))$offset_applied == 1)
check("1-based file reaching 5 is left alone",
      parse_rgrid(mk_tmp(list(c(1,5,3), c(5,1,4)), source = "Other 1.0"))$offset_applied == 0)
check("no element at a pole: source decides (non-Rep Plus)",
      parse_rgrid(mk_tmp(list(c(1,4,3), c(4,1,2)), source = "Other 1.0"))$offset_applied == 0)
check("no element at a pole: source decides (Rep Plus)",
      parse_rgrid(mk_tmp(list(c(1,4,3), c(4,1,2))))$offset_applied == 1)
check("0 = N/A leaves 1-based ratings untouched", {
  r <- parse_rgrid(mk_tmp(list(c(0,5,3), c(1,0,4)), source = "Other 1.0"), zero_is_na = TRUE)
  sum(is.na(r$scores_mat)) == 2 && r$offset_applied == 0 })
check("0 = N/A and 0-based are handled independently", {
  r <- parse_rgrid(mk_tmp(list(c(0,4,2), c(4,0,3))), zero_is_na = TRUE)
  sum(is.na(r$scores_mat)) == 2 && r$offset_applied == 1 })

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
