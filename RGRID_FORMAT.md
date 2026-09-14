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

### The offset rule

`rgrid_rating_offset()` decides whether to shift, and by how much:

```r
offset = 0                            if max(ratings) + scale_min > scale_max
       = scale_min                    if min(ratings) < scale_min
       = scale_min                    if the header says "Rep Plus"
       = 0                            otherwise
```

| Case | Stored | Scale | Offset | Why |
|---|---|---|---|---|
| Rep Plus grid | 0–4 | 1–5 | **+1** | 4+1 ≤ 5, and 0 is not a legal rating |
| Rep Plus grid not using the bottom rating | 1–3 | 1–5 | **+1** | fits after shifting; source says Rep Plus |
| This app's own export | 1–5 | 1–5 | **0** | 5+1 > 5, so it cannot be 0-based |
| `contact_lens.rgrid` | 1–7 | 1–5 | **0** | 7+1 > 5 |

The first test is what prevents a double shift: a grid already occupying the top
of its scale cannot be 0-based, so re-importing a file this app exported leaves
it untouched. There is one ambiguity the rule cannot resolve from the data
alone — stored `1–3` could be 1-based or 0-based — which is why the source
string is consulted.

### When 0 means "does not apply"

The two conventions collide. Rep Plus *stores* ratings 0-based, so `0` is the
pure left pole - `bezzi1996_expert.rgrid` contains 56 of them. But Bezzi (1996)
*printed* that same grid with `0` marking "construct does not apply", and its 12
such cells are written `?` in the file. A transcription that kept the printed
convention would therefore hold ratings 1-5 alongside `0` for not-applicable,
and reading it 0-based would be wrong.

No rule can settle this from the data alone, so it is the importer's choice:
**Treat 0 as "does not apply"** on the File Operations panel, unticked by
default.

| Checkbox | `0` is read as | Shift applied |
|---|---|---|
| unticked (default) | a rating - the pure left pole | yes, for Rep Plus files |
| ticked | not applicable (`NA`) | none - values are already 1-based |

Ticking it for a genuine Rep Plus file is destructive: Bezzi would go from 12
not-applicable cells to 68, discarding 56 real ratings. The import notification
reports what was actually done - the shift applied, how many cells were read as
not applicable, and how many are unrated - so the reading is visible rather than
assumed.

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
