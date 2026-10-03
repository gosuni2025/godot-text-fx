"""Slice a generated icon sheet into packaged 128x128 white-on-transparent PNGs.

Only crop / scale / white normalization (alpha kept). No drawing.
usage: slice_icons.py SHEET ROWS COLS OUTDIR id1 id2 ... (row-major, '-' to skip)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 128
PAD = 0.12
NOISE = 12  # alpha at or below this is treated as empty


def runs(profile, min_gap):
    """Return [start, end) runs where profile > 0, merging gaps < min_gap."""
    on = profile > 0
    segs = []
    i, n = 0, len(on)
    while i < n:
        if on[i]:
            j = i
            while j < n and on[j]:
                j += 1
            segs.append([i, j])
            i = j
        else:
            i += 1
    merged = []
    for s in segs:
        if merged and s[0] - merged[-1][1] < min_gap:
            merged[-1][1] = s[1]
        else:
            merged.append(s)
    return merged


def main():
    sheet, rows, cols, outdir = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), Path(sys.argv[4])
    ids = sys.argv[5:]
    assert len(ids) == rows * cols, "id count must equal rows*cols"
    im = Image.open(sheet)
    print("sheet", sheet, im.mode, im.size)
    rgba = np.array(im.convert("RGBA")).astype(np.float32)
    alpha = rgba[..., 3]
    if alpha.min() >= 250:
        raise SystemExit("sheet has no real transparency; regenerate")
    alpha[alpha <= NOISE] = 0
    h, w = alpha.shape
    row_runs = runs((alpha > 0).sum(axis=1), int(h * 0.04))
    row_runs = [r for r in row_runs if r[1] - r[0] > h * 0.03]
    print("row bands", row_runs)
    if len(row_runs) != rows:
        raise SystemExit(f"expected {rows} rows, found {len(row_runs)}")
    outdir.mkdir(parents=True, exist_ok=True)
    k = 0
    for r0, r1 in row_runs:
        band = alpha[r0:r1]
        col_runs = runs((band > 0).sum(axis=0), int(w * 0.04))
        col_runs = [c for c in col_runs if c[1] - c[0] > w * 0.02]
        print(" col runs", col_runs)
        if len(col_runs) != cols:
            raise SystemExit(f"expected {cols} cols in band {r0}-{r1}, found {len(col_runs)}")
        for c0, c1 in col_runs:
            icon_id = ids[k]
            k += 1
            if icon_id == "-":
                continue
            cell = band[:, c0:c1]
            ys, xs = np.nonzero(cell)
            crop = cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
            ch, cw = crop.shape
            inner = SIZE * (1 - 2 * PAD)
            scale = inner / max(ch, cw)
            nw, nh = max(1, round(cw * scale)), max(1, round(ch * scale))
            a_img = Image.fromarray(crop.astype(np.uint8), "L").resize((nw, nh), Image.LANCZOS)
            a = np.array(a_img)
            a[a <= 4] = 0
            canvas = np.zeros((SIZE, SIZE, 4), np.uint8)
            canvas[..., :3] = 255  # white normalization; alpha carries the glyph
            ox, oy = (SIZE - nw) // 2, (SIZE - nh) // 2
            canvas[oy:oy + nh, ox:ox + nw, 3] = a
            out = outdir / f"{icon_id}.png"
            Image.fromarray(canvas, "RGBA").save(out, optimize=True)
            print(f"  {icon_id}: src bbox {cw}x{ch} -> {nw}x{nh}")


if __name__ == "__main__":
    main()
