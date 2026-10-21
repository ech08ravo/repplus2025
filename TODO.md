# To do

## Fix the "4 = neutral" label on the rating slider
`app.R` (pole labels above the rating slider, `output$pole_labels_ui`) still
says "4 = neutral", left over from the 1-7 scale. The slider is 1-5 and the
help text above it says "3 = neutral". Change the label to "3 = neutral".
Display text only; no analysis output changes. Separate from the two deferred
midpoint questions in `MIDPOINT_DECISIONS.md` (imputation fill, crossplot
gridline), though it shares their 1-7 history.

## Collapse similar constructs after a FOCUS cluster
After eliciting constructs and running FOCUS, let the user merge constructs
that FOCUS shows as near-duplicates into one construct. There is currently no
single-grid merge: "Fold Identical" (Mode Grid) only merges across grids, and
only by identical labels.

Decided:
- The app suggests candidate pairs (from the FOCUS match scores); the user
  confirms or rejects each one manually. Nothing merges automatically.
- Every merge is logged in a note attached to the grid (what was merged,
  orientation, how ratings were combined, new labels, when), so the change
  travels with the grid file and can be reported or undone.

Still open:
- Reversed matches: flip one construct's poles (`2 * scale_mid - x`) before
  merging.
- Merged ratings: keep one construct's ratings, average them, or ask the
  user to re-rate the new construct?
- Labels: user writes new pole labels, or picks one pair.
- Keep the original constructs and a record of the merge, so it can be undone
  and reported.
