# The .rgrid format, rating scales and midpoints

How WebGrid.Online reads `.rgrid` files, why ratings are shifted on import, and
where the midpoint of the scale matters. The parser lives in
[`R/rgrid_io.R`](R/rgrid_io.R).

There is no published specification for the format. Everything below was
derived from the files in `dataExamples/`, a Rep Plus V2.0 export, and a
screenshot of the Rep Plus desktop app displaying the same grid. Statements are
marked **verified** (cross-checked against the desktop display or against every
sample file) or **inferred** (consistent with the evidence, but not confirmed by
a spec).

---

## 1. File structure

Tab-separated, one record per line, CR line endings on files written by Rep
Plus (R's `readLines()` handles these). A header line, then one `C` line per
construct, one `E` line per element, then `_Key value` metadata.

```
	Grid	9#	3	9	yurungi	A	3	2019-04-02	03:29:06	220.101.100.150	Rep Plus V1.1	RepGrid
C0	R	1	0	1	1	5		Social	goal
E0	1	0	3	0	4	Canvas
_UID	52540087A7DEED4F03702
```

Field 12 of the header is the source application (`Rep Plus V1.1`,
`Rep Plus V2.0`, `Rep IV 2.00`). The parser keeps it, because the rating offset
below depends on it.

### Construct lines

Three layouts are in the wild. They differ only in how each pole is written:

| Source | Construct line |
|---|---|
| Rep IV 2.00 | `C0→R→100→0→1→1→5→young→presbyopic` |
| Rep Plus V1.1 | `C0→R→1→0→1→1→5→→Social→goal` |
| Rep Plus V2.0 | `C0→R→1→0→3→1→5→→1*→2→Social→4*→5→goal` |

(`→` is a tab.) Field map, counting non-empty fields:

| Field | Meaning |
|---|---|
| 1 | `C<n>` record id |
| 2 | `R` — record type |
| 3 | weight (`1` in Rep Plus, `100` in Rep IV) |
| 4 | flags (`128` appears on the last construct of Rep Plus files) |
| 5 | **tokens per pole group** — `1` for Rep IV and V1.1, `3` for V2.0 |
| 6, 7 | rating scale minimum and maximum |
| 8+ | the two pole groups |

**Field 5 is the key to parsing poles** (inferred, but it holds for every file
available and it is the only field that co-varies with the layout). Each pole
group is that many tokens, and the label is the **last** token of the group:

```
V1.1, field 5 = 1:   [Social]            [goal]              → Social, goal
V2.0, field 5 = 3:   [1*, 2, Social]     [4*, 5, goal]       → Social, goal
```

Before v2.3.1 the importer took the last two fields, which is correct for Rep IV
and V1.1 but returns `5` and `goal` for V2.0 — so every construct imported with
a left pole of `"5"`. A fallback now also guards the case where field 5 is
missing or wrong: scan back from the end for the last token that is not a bare
number, since a pole label is never purely numeric.

### Element lines

```
E0	1	0	3	0	4	Canvas
```

The name is last; the ratings are the `n_constructs` fields immediately before
it. Leading fields are bookkeeping and are not read.

---

## 2. Ratings are stored 0-based

**Verified.** Rep Plus stores ratings 0-based while declaring a 1-based scale in
fields 6 and 7. The same grid in the Rep Plus desktop app displays 1–5.

Worked example — `Canvas` from `2026-yurungi.rgrid`, three constructs, declared
scale `1 5`:

```
E0	1	0	3	0	4	Canvas
                ^  ^  ^
                |  |  └── construct 3: stored 4 → displayed 5
                |  └───── construct 2: stored 0 → displayed 1
                └──────── construct 1: stored 3 → displayed 4
```

Every element of that grid was checked against the desktop display; all 27
ratings match after adding 1. The same 0-based range (`0–4`) holds across all
nine Rep Plus sample grids in `dataExamples/`.

The giveaway is that a stored `0` is not a legal rating on a 1–5 scale. It also
makes sense semantically: `Canvas` stores `0` on *LMS – Collaboration*, i.e.
rating 1, the pure "LMS" pole — exactly right for a learning management system.

### Where the ratings start

Systems differ in where their ratings begin, and a file does not say which it
used. Rep Plus writes them **0-based**: the file holds 0-4 for a 1-5 scale, so a
stored `0` is the pure left pole and displays as 1. Other systems write them
**1-based** and need no adjustment.

Which one applies is inferred from the ratings themselves. A grid written on its
declared scale **reaches the top of it** - somewhere an element sits at the
maximum, at one pole or the other, which elicited grids almost always contain. A
0-based grid stops one step short:

| Ratings in the file | Reading | Applied |
|---|---|---|
| reach the declared maximum (a 5 on a 1-5 scale) | already 1-based | nothing |
| stop a step short (top out at 4) | 0-based | add the scale minimum |
| fall below the declared minimum (a 0 on a 1-5 scale) | 0-based | add the scale minimum |

The inference needs at least one element at a pole. Where a grid has none -
nobody used the extreme of any construct - the file's own source string decides,
since Rep Plus files are always 0-based. Worked examples:

| Source | Ratings | Reading | Result |
|---|---|---|---|
| Rep Plus | 0-4 | 0-based | 1-5 |
| Rep Plus | 1-4, no 5 | 0-based (source) | 2-5 |
| other system | 1-5 | 1-based | unchanged |
| other system | 1-4, no 5 | 1-based (no evidence of 0-basing) | unchanged |
| this app's own export | 1-5 | 1-based | unchanged |

That last row is what stops a grid being shifted twice on a round trip.

### When 0 means "does not apply"

Separately from where the ratings start, `0` may not be a rating at all. Bezzi
(1996) printed his grid with ratings 1-5 and `0` marking "this construct does
not apply to this element" - 12 such cells, which the `.rgrid` transcription
writes as `?`.

Nothing in a file distinguishes that from Rep Plus's 0-based storage, where `0`
is the left pole (`bezzi1996_expert.rgrid` holds 56 of those). So it is a
checkbox on import - **0 = N/A** - unticked by default:

| | `0` is | 
|---|---|
| unticked (Rep Plus) | a rating |
| ticked (Bezzi) | not applicable, becomes `NA` |

**The two questions are independent.** Ticking the box only removes the zeros;
where the remaining ratings start is still inferred from them, as above. A grid
that uses `0` for "does not apply" and writes ratings 1-5 is left alone; one
that does both - zeros for N/A on 0-based ratings - has the zeros dropped and
the rest shifted. The import notification reports what was done either way.

### Why it is not merely cosmetic

A constant shift leaves correlations and distances unchanged, so cluster
structure and PrinGrid geometry are the same either way. What breaks is anything
keyed to the scale's *absolute* position. Before v2.3.1 `rv$scale` was read at
`app.R:2640` (`scale = c(1, rv$scale %||% 5)`) but never assigned anywhere, so a
0–4 grid was analysed as though it were 1–5:

- imputation filled the midpoint for a 1–5 scale into data whose real midpoint was 2
- the heatmap's `zlim = c(scale_min, scale_max)` clipped every stored `0`
- construct reversal (`2 × scale_mid − rating`) reflected around the wrong centre

Since v2.3.1 the `.rgrid` import assigns `rv$scale` from the file
(`app.R:3829`). Note that no other path does: a grid built in the wizard or
imported from JSON still leaves it `NULL`, so the `%||% 5` fallback applies and
the app assumes a maximum of 5.

---

## 3. How Rep Plus handles the midpoint

The V2.0 construct line states, for each pole, **which ratings belong to it**:

```
C0	R	1	0	3	1	5		1*	2	Social	4*	5	goal
                                        └──┬──┘         └──┬──┘
                                    ratings 1–2       ratings 4–5
```

On a 1–5 scale that assigns 1–2 to the left pole and 4–5 to the right pole and
leaves **3 belonging to neither** — the midpoint is a neutral position, not a
weak form of either pole. The starred value (`1*`, `4*`) is the pole's anchor,
the rating that represents it purely (inferred — the star is consistent across
all three constructs, always on the outermost rating of each band).

In stored 0-based terms the bands are `0,1` left, `2` midpoint, `3,4` right.

V1.1 and Rep IV files carry no band information; they declare only the scale
range, from which the midpoint follows as `(min + max) / 2` = 3 on a 1–5 scale.

So the midpoint on a 1–5 scale is **3**, both by Rep Plus's own banding and by
arithmetic. WebGrid.Online should use 3 wherever it needs a neutral rating.

### Where the midpoint is used in this app

| Use | Location | Value used | Correct for 1–5? |
|---|---|---|---|
| Construct reversal, focus similarities | `R/focus_analysis.r:46` | `(min + max) / 2` of the **observed** data | Yes when the grid uses its full scale; drifts otherwise |
| Construct reversal, grid matching | `R/multigrid_analysis.r:77` | observed min/max of the compared grid | Same caveat |
| Construct reversal, normalised comparison | `R/multigrid_analysis.r:174` | midpoint of the **target** scale (1–7 → 4) | Yes |
| Wizard biplot placeholder | `app.R:2487` | `3` | Yes |
| Imputation of missing ratings | `app.R:3900` | `4` | **No — see below** |
| Crossplot midpoint gridline | `app.R:4438` | `4` | **No — see below** |

The reversal formula is `reversed = 2 × scale_mid − rating`: on a 1–5 scale a
rating of 1 reverses to 5, 2 to 4, and 3 to itself. Deriving `scale_mid` from
the observed data rather than the declared scale is self-correcting for a grid
that uses its whole scale, but a grid rated only 2–5 yields a midpoint of 3.5
and slightly skewed reversals. Using the declared scale would be more robust.

### Known inconsistency (not yet fixed)

Two places use `4`, the midpoint of a **1–7** scale, in an app whose UI, wizard
and crossplot axes are all 1–5:

- **Imputation** fills missing ratings with `4` (`app.R:3900`), while the help
  text beside the control says "the midpoint value (3 on a 1-5 scale)"
  (`app.R:687`). On a 1–5 scale, 4 is not neutral — it sits inside the right
  pole's band, so imputed cells lean toward the right pole.
- **The crossplot** draws its emphasised midpoint gridline at `4`
  (`app.R:4438`), while the axes run 1–5 with pole labels at 1 and 5 and the
  help text says "The midpoint (3) is marked with dashed lines" (`app.R:919`).
  The dashed cross is drawn three-quarters of the way along each axis rather
  than at the centre.

Both look like leftovers from a 1–7 scale. Changing them alters analysis output
(imputation) and an existing figure (crossplot), so they are documented here
rather than changed silently.
