# OP Scanner — Perceptual Hash Spec (v1)

The recognizer matches a scanned card against precomputed per-variant hashes.
The hash MUST be computed **identically** by `/ingest` (TypeScript, over the
upstream art) and by the client (Dart, over the camera-rectified card), or
matching fails. This document is the single source of truth; both sides implement
exactly these steps as pure functions over raw RGB pixels.

> Key idea: relying on a library's `resize()` would diverge between sharp (TS)
> and Dart. So we only use libraries to **decode** images to raw RGB, and do the
> crop / downscale / DCT / hashing with our own exactly-specified arithmetic.

## Inputs

- A decoded RGB image: `rgb` (row-major, 3 bytes/pixel, no alpha), `width`,
  `height`.
  - ingest: the upstream full-art PNG decoded at native resolution.
  - client: the card rectified by OpenCV to a fixed **aspect ratio of 600:838**
    (any size with that aspect is fine — the downscale normalizes resolution).

## Step 1 — Crop the art region (resolution-independent fractions)

Crop to the rectangle (fractions of width/height), to emphasize artwork and drop
the outer border and bottom text box (this is what separates alt-arts):

```
CROP = { left: 0.05, top: 0.06, right: 0.95, bottom: 0.78 }
x0 = round(left  * width),  x1 = round(right  * width)
y0 = round(top   * height), y1 = round(bottom * height)
cropW = x1 - x0,  cropH = y1 - y0
```

## Step 2 — Block-average downscale to 32×32 (per channel)

Deterministic area-average (box) downscale. For output pixel `(ox, oy)`,
`ox, oy ∈ [0, 32)`, average the source block (integer boundaries):

```
sx0 = x0 + floor(ox     * cropW / 32),  sx1 = x0 + floor((ox+1) * cropW / 32)
sy0 = y0 + floor(oy     * cropH / 32),  sy1 = y0 + floor((oy+1) * cropH / 32)
if sx1 == sx0: sx1 = sx0 + 1
if sy1 == sy0: sy1 = sy0 + 1
out[oy][ox][c] = mean over (sx0..sx1-1, sy0..sy1-1) of rgb[y][x][c]   (float)
```

Produces three 32×32 float channels (R, G, B), values 0–255.

## Step 3 — 2D DCT-II per channel; take the 8×8 low-frequency block

For each channel's 32×32 matrix `g`, compute the DCT-II coefficients for
`u, v ∈ [0, 8)` only (we only need the low-frequency block):

```
DCT(u,v) = a(u) * a(v) * sum_{x=0..31} sum_{y=0..31}
             g[y][x] * cos(((2x+1) u π)/64) * cos(((2y+1) v π)/64)
a(0) = sqrt(1/32),  a(k>0) = sqrt(2/32)
```

(Constant scale factors are irrelevant to the > median comparison, but are
specified for determinism.)

## Step 4 — Hash bits (per channel → 64 bits)

```
block = the 64 coefficients DCT(u,v), row-major index k = v*8 + u  (u=col, v=row)
median = median of the 63 values EXCLUDING k=0 (the DC term)
bit k  = 1 if block[k] > median else 0
hash64 = sum over k of bit_k << (63 - k)        # position k=0 is the MSB
```

Emit `hash64` as 16 lowercase hex chars (zero-padded, big-endian).

## Step 5 — Combine channels

```
phash = hex(R) + hex(G) + hex(B)     # 48 lowercase hex chars, 192 bits total
```

Stored in `card_variant.phash`. (`phash_variants` may later hold rotated/mirrored
hashes; v1 stores the single upright hash.)

## Matching

Parse the 48-hex into three 64-bit integers. Distance between two hashes:

```
dist = popcount(R xor R') + popcount(G xor G') + popcount(B xor B')   # 0..192
```

Rank candidates by ascending `dist`. With OCR prefilter ON, candidates are
restricted to the variants of the read card code; otherwise the full set.

Accept top-1 automatically iff:

```
dist(top1) <= ACCEPT_THRESHOLD   (default 40)
AND dist(top2) - dist(top1) >= ACCEPT_MARGIN   (default 12)
```

Otherwise present the top-3 for the user to confirm. Thresholds are tunable via
the eval harness (`/ingest` bench or the client eval test); record changes here.

### Query-side orientation normalization (client)

`card_variant.phash` stores a single **upright** hash; we do NOT precompute
rotated/mirrored variants. Instead the live scanner makes the *query* rotation-
invariant: OpenCV warps the detected card quad so its **short edge becomes the
top** (always portrait, folding in any 90°/270° in-frame rotation), then hashes
both that warp **and its 180° rotation**. `matchHashMulti` scores every query
orientation against each stored hash and keeps the smaller distance. The wrong
orientation lands its crop on the card's text box (not the art) and scores far,
so the correct upright orientation wins. This keeps the stored hash domain
unchanged — adding orientation handling needs no recompute. (Mirroring can't
occur: corners are ordered clockwise to match the destination winding.)

## Versioning

Bump this version and recompute all hashes if any of: CROP, downscale, DCT block
size, or bit ordering changes. Mismatched hash domains silently break matching.
