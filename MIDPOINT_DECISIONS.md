# The midpoint of the rating scale: decisions so far

Draft, 14 September 2026. Working notes for WebGrid.Online, covering the
decisions taken while reimplementing Rep Plus's grid handling, those
deliberately deferred, and the question that remains open pending a reading of
the literature.

---

## Abstract

Rating-scale repertory grids require a decision that is rarely made explicit:
what the midpoint of the scale means, and what should happen when a rating is
missing. In reimplementing Shaw and Gaines's WebGrid as an open web application
(WebGrid.Online), we found this decision embedded in three places at once — the
file format, the analysis code, and the interface — and answered inconsistently
in each. Rep Plus's own format resolves it declaratively: every construct
records the band of ratings belonging to each pole (1–2 and 4–5 on a five-point
scale), leaving the midpoint assigned to neither. Our implementation had
inherited a different answer: missing ratings were imputed at 4, the midpoint of
a *seven*-point scale, in an application whose scales, axes, wizard and help
text are all five-point. Across ten elicited grids in our corpus participants
used the midpoint in 12.5% of ratings while placing 61% at the extreme anchors,
so imputing a midpoint fills in a value participants themselves rarely chose. We
describe the decisions made, those deferred, and why the question is not merely
computational: it turns on whether a midpoint is read as "neither pole applies",
"both apply equally", or "not known".

---

## The format already contains an answer

Rep Plus V2.0 writes each construct with the ratings that belong to each pole
rather than the pole names alone. On a five-point scale a construct is stored as
`1* 2 Social | 4* 5 goal`: ratings 1–2 belong to the left pole, 4–5 to the
right, the starred value being the pole's pure anchor. Nothing is said about 3.
The midpoint is not a weak form of either pole; it is outside both bands. This
matters because it is a *design* statement by the instrument's authors, not an
inference from the data, and it is stronger than the arithmetic answer — which
would also give 3, but only as the mean of the endpoints. A second discovery in
the same format reinforced the point: Rep Plus stores ratings zero-based (0–4)
while declaring a one-based scale (1–5), so a rating recorded as `0` is the pure
left pole, not a missing value. We had been importing those values unshifted,
which left the analysis treating 0–4 data as though it were 1–5 and putting
every midpoint-dependent calculation — imputation, heatmap bounds, construct
reversal around the scale's centre — off by one. Ratings are now shifted onto
the scale the file itself declares, and the scale is carried through import
rather than assumed.

## Where the midpoint turned out to live in the software

Auditing the code for midpoint use produced six sites and three different
answers. Construct reversal, which flips a construct around the centre of the
scale to test whether it matches another better in reversed orientation, derives
its midpoint from the observed data — self-correcting for a grid that spans its
full scale, but drifting for one that does not. The wizard's placeholder biplot
uses 3. Multi-grid comparison normalises to a 1–7 target and correctly uses 4.
But imputation of missing ratings fills 4, and the crossplot draws its
emphasised midpoint gridline at 4, both being the midpoint of a seven-point
scale in an application that is otherwise five-point throughout — the crossplot
therefore draws its "centre" three-quarters of the way along each axis, and the
help text beside both controls says 3, contradicting the code. These look like
residue from an earlier seven-point implementation. We have documented them
rather than changed them, because altering imputation changes analysis output
and altering the crossplot changes a figure already in use; both are decisions
about the instrument, not bugs to be quietly corrected.

## Why the answer is not merely computational

Imputation is where the interpretation bites. Four of our eleven sample grids
contain missing ratings, one of them in a third of its cells, so the choice is
not hypothetical. Filling with the midpoint is defensible if the midpoint means
"neither pole applies to this element" — the value is then a substantive, if
neutral, judgement. It is much harder to defend if the midpoint means "I do not
know", because the imputed cell then asserts a judgement the participant never
made, and does so at a value they demonstrably avoid: in our corpus the midpoint
accounts for 12.5% of ratings against 61% at the extreme anchors, a
distribution that suggests participants treat the scale as substantially
bipolar. A constant fill also shrinks the variance of the affected construct and
pulls it toward the centre of any subsequent principal-components or cluster
solution, so the imputation choice propagates into exactly the structures the
analysis is meant to reveal. The alternatives — dropping incomplete elements,
carrying missingness through the distance computation, or model-based imputation
from the rest of the grid — each carry their own commitments. Two of these commitments have since been narrowed rather than chosen: unrated
cells are now excluded from every match rather than counted as agreement, and
the scale a grid declares is carried through instead of being re-derived from
the values present. What remains to impute is only the genuinely unknown. The
next step is to establish how the grid literature has handled this, particularly whether
there is a settled convention for the meaning of the midpoint in elicited grids
and for imputation in small grids, and then to make the choice explicit and
configurable in the application rather than fixed in the code, reporting
alongside any analysis which convention produced it.

---

## The decision taken

The midpoint is a rating a participant gives: on a five-point scale it says both
poles apply equally. That is a judgement, and it is not available as a way of
recording that no judgement was made. Nor was the value the app had been using -
4 is neither the midpoint nor a "don't know"; on Rep Plus's own banding it sits
inside the right pole's band, so every filled cell leaned right.

So unrated cells are left blank, and each study keeps its original scale and
intent. Analyses work from the ratings present: a construct counts towards a
comparison when both items are rated on it. The single exception is the PCA
biplot, which cannot decompose an incomplete matrix - elements with unrated
cells are left out of that plot and named beneath it, rather than being given
invented ratings to make the arithmetic work. A grid whose source marked "does
not apply" with 0, as Bezzi printed it, carries those cells as blanks too.

## Status

| Decision | Status |
|---|---|
| Shift Rep Plus ratings onto the scale declared in the file | Done (v2.3.1) |
| Carry the declared scale through import instead of assuming 1–5 | Done (v2.3.1) |
| Document Rep Plus's pole banding and midpoint treatment | Done — see [RGRID_FORMAT.md](RGRID_FORMAT.md) §3 |
| Imputation of unrated cells | **Decided** — none. Blanks stay blank (v2.6.0) |
| Crossplot midpoint gridline (currently `4` on a 1–5 axis) | **Deferred** — pending literature |
| Construct reversal to use the declared rather than observed midpoint | Done (v2.5.0) |
| Exclude unrated cells from matches instead of scoring them as agreement | Done (v2.5.0) |
| Rating scale as a property of the grid, carried through import and export | Done (v2.5.0) |
| `0 = N/A` on import, for sources using Bezzi's convention | Done (v2.5.0) |
| Distinct "does not apply" cell state during elicitation | Proposed |
| Scale length (4- or 5-point) chosen per grid at elicitation | Proposed |
| Make the imputation convention explicit and configurable | Proposed |

Evidence for the figures quoted above: `dataExamples/*.rgrid`, ten elicited
five-point grids (n = 359 ratings; 1: 29.5%, 2: 8.1%, 3: 12.5%, 4: 18.1%,
5: 31.8%), plus `contact_lens.rgrid`, which is synthetic and excluded.
