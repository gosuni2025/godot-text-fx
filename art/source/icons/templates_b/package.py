"""Slice a 3x3 transparent icon sheet and package 128x128 white RGBA icons.

Only crop / scale / white-normalize (alpha kept). No drawing.
Content is fit into the central 76% (12% padding); glyphs whose stroke would exceed
MAX_STROKE px are scaled down further so stroke weight matches across sheets.
usage: python3 package.py <sheet.png> <out_dir> id1 id2 ... id9   (row-major)
       an id of "-" skips that cell.
"""
import sys
from PIL import Image
import numpy as np

SIZE = 128
PAD = 0.12
ALPHA_FLOOR = 8  # alpha below this is treated as background noise -> 0
MAX_STROKE = 7.0  # px at 128; thick-stroke glyphs are scaled smaller so line weight stays even across the set


def stroke_width(mask):
    """Approximate stroke width of a thin-line glyph: 2 * area / perimeter."""
    area = mask.sum()
    perim = (mask[1:, :] != mask[:-1, :]).sum() + (mask[:, 1:] != mask[:, :-1]).sum()
    return 2.0 * area / max(perim, 1)


def bands(profile, n):
    """Split a 1-D occupancy profile into n bands at the widest empty gaps."""
    occ = profile > 0
    L = len(occ)
    # candidate gap centers: longest empty runs
    runs, start = [], None
    for i, v in enumerate(occ):
        if not v and start is None:
            start = i
        if v and start is not None:
            runs.append((start, i)); start = None
    if start is not None:
        runs.append((start, L))
    inner = [r for r in runs if r[0] > 0 and r[1] < L]
    inner.sort(key=lambda r: r[1] - r[0], reverse=True)
    cuts = sorted((a + b) // 2 for a, b in inner[: n - 1])
    if len(cuts) < n - 1:  # fallback: equal split
        cuts = [L * k // n for k in range(1, n)]
    edges = [0] + cuts + [L]
    return list(zip(edges[:-1], edges[1:]))


def main():
    sheet, out_dir, ids = sys.argv[1], sys.argv[2], sys.argv[3:]
    im = Image.open(sheet).convert("RGBA")
    a = np.array(im)
    alpha = a[:, :, 3].astype(np.int32)
    alpha[alpha < ALPHA_FLOOR] = 0
    rows = bands(alpha.sum(axis=1), 3)
    k = 0
    for (y0, y1) in rows:
        cols = bands(alpha[y0:y1].sum(axis=0), 3)
        for (x0, x1) in cols:
            icon_id = ids[k]; k += 1
            if icon_id == "-":
                continue
            cell = alpha[y0:y1, x0:x1]
            ys, xs = np.nonzero(cell)
            cy0, cy1, cx0, cx1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
            crop_a = cell[cy0:cy1, cx0:cx1].astype(np.uint8)
            h, w = crop_a.shape
            rgba = np.zeros((h, w, 4), np.uint8)
            rgba[:, :, :3] = 255
            rgba[:, :, 3] = crop_a
            glyph = Image.fromarray(rgba, "RGBA")
            # premultiplied-safe resize: white RGB everywhere so only alpha resamples
            box = int(round(SIZE * (1 - 2 * PAD)))
            s = min(box / max(w, h), MAX_STROKE / stroke_width(crop_a > 128))
            nw, nh = max(1, round(w * s)), max(1, round(h * s))
            glyph = glyph.resize((nw, nh), Image.LANCZOS)
            g = np.array(glyph)
            g[:, :, :3] = 255
            g[g[:, :, 3] < ALPHA_FLOOR, 3] = 0
            canvas = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
            canvas.paste(Image.fromarray(g, "RGBA"), ((SIZE - nw) // 2, (SIZE - nh) // 2))
            out = f"{out_dir}/{icon_id}.png"
            canvas.save(out, optimize=True)
            print(out, f"cell=({x0},{y0})-({x1},{y1}) bbox={w}x{h} -> {nw}x{nh} stroke~{stroke_width(crop_a > 128) * s:.1f}px")


if __name__ == "__main__":
    main()
