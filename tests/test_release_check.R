# Release check: does the arithmetic still come out right?
#
# Run from the project root, before every release:
#
#     Rscript tests/test_release_check.R
#
# Exits non-zero if anything fails, so it can gate a deploy.
#
# The point of this file is to check the numbers are RIGHT, not merely that
# they have not changed. A snapshot of whatever the app currently prints would
# have happily frozen two real bugs found in October 2026 - matches that were
# excluded from the "top" list, and missing cells counted as agreement - since
# both produced stable, plausible-looking wrong output for months.
#
# So the expected values here come from somewhere other than the code under
# test, in three ways:
#
#   1. tests/fixtures/*.rgrid are built so the answer follows by construction.
#      Two identical elements must match 100%; two that sit at opposite ends of
#      every construct must match 0%. These are written below as literals.
#   2. match_pct_naive() below reimplements the documented formula in the most
#      obvious way possible - a loop, no vectorisation - and the whole matrix is
#      compared against it. The production code is a sweep()-based version of
#      the same thing, so agreement is real evidence; a bug would have to occur
#      twice, differently, to slip through.
#   3. Invariants that must hold for ANY grid are checked over every sample
#      grid in dataExamples/, not just the fixtures.

source("R/rgrid_io.R")
source("R/focus_analysis.r")

failures <- 0
# detail is whatever the failing value was, so it has to survive being NULL,
# NA or a vector - a check that crashes while reporting a failure is worse
# than no check, because the run stops before the rest of the file is reached.
check <- function(label, ok, detail = NULL) {
  ok <- isTRUE(ok)
  if (!ok) failures <<- failures + 1
  d <- ""
  if (!ok) {
    d <- if (length(detail) == 0) "<empty>" else paste(utils::head(detail, 3), collapse = ", ")
    d <- paste0(" - ", d)
  }
  cat(sprintf("%-58s %s%s\n", label, if (ok) "PASS" else "FAIL", d))
}
near <- function(a, b, tol = 0.05) isTRUE(all(abs(a - b) < tol))

section <- function(x) cat(sprintf("\n-- %s %s\n", x, strrep("-", max(0, 56 - nchar(x)))))

# ---------------------------------------------------------------------------
# An independent reimplementation of the match formula, written straight from
# the description: the percentage of the maximum possible difference that two
# items do NOT differ by, over the cells where both are rated.
# ---------------------------------------------------------------------------
match_pct_naive <- function(a, b, scale_range) {
  shared <- !is.na(a) & !is.na(b)
  if (!any(shared)) return(0)
  total_diff <- sum(abs(a[shared] - b[shared]))
  max_diff <- sum(shared) * scale_range
  max(0, 100 * (1 - total_diff / max_diff))
}

# Constructs are compared in whichever orientation fits better, so a construct
# and its mirror image count as the same distinction.
construct_pct_naive <- function(a, b, scale_range, scale_mid) {
  direct <- match_pct_naive(a, b, scale_range)
  flipped <- match_pct_naive(2 * scale_mid - a, b, scale_range)
  max(direct, flipped)
}

# ===========================================================================
section("Fixtures load as written")
# ===========================================================================
ge <- parse_rgrid("tests/fixtures/calibration_elements.rgrid")
gc <- parse_rgrid("tests/fixtures/calibration_constructs.rgrid")

check("element fixture: 8 elements, 6 constructs",
      length(ge$elements) == 8 && length(ge$left) == 6)
check("element fixture: scale read as 1-5", identical(as.numeric(ge$scale), c(1, 5)))
check("element fixture: no rating shift applied", ge$offset_applied == 0,
      paste("offset", ge$offset_applied))
check("element fixture: 6 cells left unrated", sum(is.na(ge$scores_mat)) == 6)
check("element fixture: name survives the round trip",
      identical(ge$grid_name, "calibration-elements"), ge$grid_name)
check("construct fixture: 6 elements, 6 constructs",
      length(gc$elements) == 6 && length(gc$left) == 6)
check("construct fixture: 3 cells left unrated", sum(is.na(gc$scores_mat)) == 3)

E <- ge$scores_mat
rownames(E) <- ge$elements

# ===========================================================================
section("Element matches, against values true by construction")
# ===========================================================================
esim <- compute_element_similarities(E, scale = ge$scale)
rownames(esim) <- colnames(esim) <- ge$elements
p <- function(a, b) esim[a, b]

# Every cell identical -> nothing differs.
check("identical elements match 100%", near(p("All ones", "All ones twin"), 100),
      p("All ones", "All ones twin"))
# Every cell 4 apart on a scale whose range is 4 -> the maximum possible.
check("opposite elements match 0%", near(p("All ones", "All fives"), 0),
      p("All ones", "All fives"))
# 2 apart out of a possible 4, on every construct.
check("1s against 3s match 50%", near(p("All ones", "All threes"), 50),
      p("All ones", "All threes"))
# 1 apart out of 4.
check("1s against 2s match 75%", near(p("All ones", "All twos"), 75),
      p("All ones", "All twos"))
# 3 apart out of 4.
check("5s against 2s match 25%", near(p("All fives", "All twos"), 25),
      p("All fives", "All twos"))
# Half the cells agree exactly, half differ by the full range.
check("alternating against 1s matches 50%", near(p("All ones", "Alternating"), 50),
      p("All ones", "Alternating"))

# The discriminating missing-data case. "Half rated high" is rated on three
# constructs and is the opposite of "All ones" on every one of them, so the
# answer is 0%. Counting an unrated cell as agreement - which the app used to
# do - would give 50% instead, because the three absent cells would each score
# a perfect match against a denominator that still counted them.
check("unrated cells excluded, not counted as agreement",
      near(p("All ones", "Half rated high"), 0),
      paste0(round(p("All ones", "Half rated high"), 1), "% (50% means the old bug is back)"))
check("partial element agreeing where rated matches 100%",
      near(p("All ones", "Half rated low"), 100), p("All ones", "Half rated low"))
check("two partial elements, opposite where rated, match 0%",
      near(p("Half rated low", "Half rated high"), 0),
      p("Half rated low", "Half rated high"))

# ===========================================================================
section("Element matches, against an independent implementation")
# ===========================================================================
agree <- TRUE; worst <- 0
for (i in seq_len(nrow(E))) for (j in seq_len(nrow(E))) {
  if (i == j) next
  expected <- match_pct_naive(E[i, ], E[j, ], diff(ge$scale))
  worst <- max(worst, abs(esim[i, j] - expected))
  if (!near(esim[i, j], expected)) agree <- FALSE
}
check("whole element matrix matches the naive formula", agree,
      sprintf("largest disagreement %.3f", worst))
check("element matrix is symmetric", near(esim, t(esim)))
check("element self-match is 100%", near(diag(esim), 100))
check("element matches stay within 0-100", all(esim >= 0 & esim <= 100))

# ===========================================================================
section("Construct matches, including reversal")
# ===========================================================================
C <- gc$scores_mat
csim <- compute_construct_similarities(C, scale = gc$scale)
labs <- gc$left
rownames(csim) <- colnames(csim) <- labs
q <- function(a, b) csim[a, b]

check("identical constructs match 100%", near(q("base", "copy of base"), 100),
      q("base", "copy of base"))
# "reverse of base" is base mirrored about the scale centre. Compared directly
# it differs by the full range in every cell, so a 0% here means reversal is no
# longer being detected and mirrored constructs look unrelated.
check("a reversed construct still matches 100%",
      near(q("base", "reverse of base"), 100),
      paste0(round(q("base", "reverse of base"), 1), "% (0% means reversal is not detected)"))
check("construct agreeing on 4 of 6 elements matches 66.7%",
      near(q("base", "agrees on four"), 100 * (1 - 8 / 24)), q("base", "agrees on four"))
check("flat construct against base matches 50%", near(q("base", "flat"), 50),
      q("base", "flat"))
check("partial construct agreeing where rated matches 100%",
      near(q("base", "half rated"), 100), q("base", "half rated"))

scale_mid <- sum(gc$scale) / 2
agree <- TRUE; worst <- 0
for (i in seq_len(ncol(C))) for (j in seq_len(ncol(C))) {
  if (i == j) next
  expected <- construct_pct_naive(C[, i], C[, j], diff(gc$scale), scale_mid)
  worst <- max(worst, abs(csim[i, j] - expected))
  if (!near(csim[i, j], expected)) agree <- FALSE
}
check("whole construct matrix matches the naive formula", agree,
      sprintf("largest disagreement %.3f", worst))
check("construct matrix is symmetric", near(csim, t(csim)))

# ===========================================================================
section("The scale is the grid's, not the range that happens to be used")
# ===========================================================================
# Ratings 2 and 4 on a declared 1-5 scale differ by 2 of a possible 4 -> 50%.
# Reading the scale off the data instead would make 2 and 4 the extremes, and
# the same pair would come out at 0%.
narrow <- rbind(c(2, 2, 2, 2), c(4, 4, 4, 4))
ns <- compute_element_similarities(narrow, scale = c(1, 5))
check("declared scale used rather than the observed range",
      near(ns[1, 2], 50),
      paste0(round(ns[1, 2], 1), "% (0% means the observed range was used)"))

# ===========================================================================
section("FOCUS sort and its dendrograms")
# ===========================================================================
fr <- focus_cluster(E, ge$elements, paste(ge$left, "-", ge$right))

check("FOCUS returns every element once",
      setequal(fr$sorted_elements, ge$elements) &&
        length(fr$sorted_elements) == length(ge$elements))
check("FOCUS returns every construct once",
      length(fr$construct_order) == ncol(E) &&
        !any(duplicated(fr$construct_order)))

# Two elements that match 100% have nothing between them to separate them.
pos <- match(c("All ones", "All ones twin"), fr$sorted_elements)
check("identical elements end up next to each other", abs(diff(pos)) == 1,
      paste("positions", paste(pos, collapse = " and ")))

# FOCUS stores each join as 100 - match, which is what the dendrogram labels
# and the match percentages on screen both rely on.
h <- fr$element_hclust$height
check("join heights are 100 - match, so in range", all(h >= 0 & h <= 100))
check("join heights never decrease up the tree", !is.unsorted(h))
check("closest pair joins at 100%", near(min(h), 0),
      paste("lowest join at", round(100 - min(h), 1), "%"))

lay <- dendro_layout(fr$element_hclust, seq_along(fr$element_order))
check("dendrogram exposes one node per join",
      nrow(lay$nodes) == length(h) && near(lay$nodes[, 2], h))
check("dendro_segments still returns just the segments",
      identical(dendro_segments(fr$element_hclust, seq_along(fr$element_order)),
                lay$segs))

# ===========================================================================
section("Match listing and export")
# ===========================================================================
# Reimplemented here rather than reaching into app.R, so this is a second
# opinion on what the Focus tab lists and what its Matches CSV should contain.
expected_pairs <- function(sim, labels, cutoff) {
  out <- data.frame(a = character(0), b = character(0), m = numeric(0))
  for (i in seq_len(nrow(sim))) for (j in seq_len(nrow(sim))) {
    if (i < j && !is.na(sim[i, j]) && sim[i, j] >= cutoff) {
      out <- rbind(out, data.frame(a = labels[i], b = labels[j], m = sim[i, j]))
    }
  }
  out[order(-out$m, out$a, out$b), ]
}
ep <- expected_pairs(esim, ge$elements, 70)
check("every qualifying pair is found once",
      nrow(ep) == sum(esim[upper.tri(esim)] >= 70))
check("the strongest pair really is the 100% one", near(max(ep$m), 100))
check("no pair is listed against itself", !any(ep$a == ep$b))
check("no pair appears twice",
      !any(duplicated(paste(pmin(ep$a, ep$b), pmax(ep$a, ep$b)))))

# ===========================================================================
section("Invariants over every sample grid")
# ===========================================================================
for (f in sort(Sys.glob("dataExamples/*.rgrid"))) {
  g <- try(parse_rgrid(f), silent = TRUE)
  nm <- basename(f)
  if (inherits(g, "try-error")) { check(nm, FALSE, "parse error"); next }
  s <- compute_element_similarities(g$scores_mat, scale = g$scale)
  cs <- compute_construct_similarities(g$scores_mat, scale = g$scale)

  naive_ok <- TRUE
  for (i in seq_len(nrow(s))) for (j in seq_len(nrow(s))) {
    if (i != j && !near(s[i, j], match_pct_naive(g$scores_mat[i, ],
                                                 g$scores_mat[j, ],
                                                 diff(g$scale)))) naive_ok <- FALSE
  }
  ok <- naive_ok &&
    near(s, t(s)) && near(diag(s), 100) && all(s >= 0 & s <= 100) &&
    near(cs, t(cs)) && near(diag(cs), 100) && all(cs >= 0 & cs <= 100) &&
    !any(is.na(s)) && !any(is.na(cs))
  check(paste("matches sane and match the formula:", nm), ok)
}

# ===========================================================================
section("A grid survives export and reimport")
# ===========================================================================
# Guards the bug where an exported grid came back named after a count in the
# header, because the name was read from the wrong field.
tmp <- tempfile(fileext = ".rgrid")
con <- file(tmp, open = "wb")
wl <- function(x) writeChar(paste0(x, "\n"), con, eos = NULL)
wl(paste("", "Grid", 3, 2, 6, "Exported Grid", "", "1",
         "23-Oct-2026", "10:00", "local", "Rep IV 2.00", "RepGrid", sep = "\t"))
wl("C0\tR\t100\t0\t1\t1\t5\tcold\thot\t")
wl("C1\tR\t100\t0\t1\t1\t5\tslow\tfast\t")
wl("E0\t100\t0\t1\t1\t4\t1\t5\tAlpha")
wl("E1\t100\t0\t1\t1\t4\t5\t1\tBeta")
wl("E2\t100\t0\t1\t1\t4\t3\t3\tGamma")
wl("_Date\t23-Oct-2026")
close(con)
rt <- parse_rgrid(tmp)
check("reimported grid keeps its name, not a row count",
      identical(rt$grid_name, "Exported Grid"), rt$grid_name)
check("reimported grid keeps its ratings",
      near(rt$scores_mat, rbind(c(1, 5), c(5, 1), c(3, 3))))
unlink(tmp)

# ===========================================================================
section("Version and changelog agree")
# ===========================================================================
# APP_VERSION is what the title bar shows and what deploy.sh compares the live
# site against, so if it is not bumped the version check stops meaning
# anything - it sat at 2.6.0 across eleven commits once, for exactly that
# reason. ./bump_version.sh moves both of these together.
app_version <- sub('.*"(.*)".*', "\\1",
                   grep("^APP_VERSION <-", readLines("app.R"), value = TRUE)[1])
changelog_version <- sub("^## \\[([0-9.]+)\\].*", "\\1",
                         grep("^## \\[[0-9]", readLines("CHANGELOG.md"), value = TRUE)[1])

check("APP_VERSION looks like a version",
      grepl("^[0-9]+\\.[0-9]+\\.[0-9]+$", app_version), app_version)
check("APP_VERSION matches the newest CHANGELOG entry",
      identical(app_version, changelog_version),
      paste0("app.R ", app_version, " vs CHANGELOG ", changelog_version))
check("the CHANGELOG entry has been written",
      !any(grepl("TODO: describe this release",
                 utils::head(readLines("CHANGELOG.md"), 12))))

cat(sprintf("\n%s\n", if (failures == 0) "All release checks passed."
                      else paste(failures, "RELEASE CHECK(S) FAILED")))
if (failures > 0) quit(status = 1)
