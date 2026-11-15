"""Small pixel-art toolkit used by the Lunar Life painters.

Everything here draws whole pixels with a limited palette: no anti-aliasing and no
smooth gradients, so the result stays crisp when the game scales it by 3 or 4.
"""
from __future__ import annotations

import numpy as np
from PIL import Image


def C(hex_color: str) -> tuple[int, int, int]:
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t: float):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def shade(c, factor: float):
    """factor < 1 darkens, > 1 lightens (towards white)."""
    if factor <= 1.0:
        return tuple(int(round(v * factor)) for v in c)
    return mix(c, (255, 255, 255), min(1.0, factor - 1.0))


class Canvas:
    """An RGBA picture with clipped integer drawing calls."""

    def __init__(self, w: int, h: int, fill=None):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), dtype=np.uint8)
        if fill is not None:
            self.a[:, :, :3] = fill
            self.a[:, :, 3] = 255

    # --- basic shapes -------------------------------------------------------
    def _clip(self, x, y, w, h):
        x0, y0 = max(0, int(x)), max(0, int(y))
        x1, y1 = min(self.w, int(x + w)), min(self.h, int(y + h))
        return x0, y0, x1, y1

    def rect(self, x, y, w, h, c, alpha: float = 1.0):
        x0, y0, x1, y1 = self._clip(x, y, w, h)
        if x1 <= x0 or y1 <= y0:
            return
        if alpha >= 1.0:
            self.a[y0:y1, x0:x1, :3] = c
            self.a[y0:y1, x0:x1, 3] = 255
        else:
            region = self.a[y0:y1, x0:x1, :3].astype(np.float32)
            region = region * (1 - alpha) + np.array(c, dtype=np.float32) * alpha
            self.a[y0:y1, x0:x1, :3] = np.clip(region + 0.5, 0, 255).astype(np.uint8)
            self.a[y0:y1, x0:x1, 3] = np.maximum(self.a[y0:y1, x0:x1, 3], int(255 * alpha))

    def px(self, x, y, c, alpha: float = 1.0):
        self.rect(x, y, 1, 1, c, alpha)

    def hline(self, x, y, w, c, alpha: float = 1.0):
        self.rect(x, y, w, 1, c, alpha)

    def vline(self, x, y, h, c, alpha: float = 1.0):
        self.rect(x, y, 1, h, c, alpha)

    def frame(self, x, y, w, h, c, alpha: float = 1.0):
        self.hline(x, y, w, c, alpha)
        self.hline(x, y + h - 1, w, c, alpha)
        self.vline(x, y + 1, h - 2, c, alpha)
        self.vline(x + w - 1, y + 1, h - 2, c, alpha)

    def line(self, x0, y0, x1, y1, c, alpha: float = 1.0):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.px(x0, y0, c, alpha)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    # --- masks --------------------------------------------------------------
    def grid(self):
        ys, xs = np.mgrid[0:self.h, 0:self.w]
        return xs, ys

    def ellipse_mask(self, cx, cy, rx, ry):
        xs, ys = self.grid()
        return ((xs + 0.5 - cx) / max(rx, 0.01)) ** 2 + ((ys + 0.5 - cy) / max(ry, 0.01)) ** 2 <= 1.0

    def rect_mask(self, x, y, w, h):
        m = np.zeros((self.h, self.w), dtype=bool)
        x0, y0, x1, y1 = self._clip(x, y, w, h)
        m[y0:y1, x0:x1] = True
        return m

    def fill(self, mask, c, alpha: float = 1.0):
        if alpha >= 1.0:
            self.a[mask, :3] = c
            self.a[mask, 3] = 255
        else:
            region = self.a[mask, :3].astype(np.float32)
            region = region * (1 - alpha) + np.array(c, dtype=np.float32) * alpha
            self.a[mask, :3] = np.clip(region + 0.5, 0, 255).astype(np.uint8)
            self.a[mask, 3] = np.maximum(self.a[mask, 3], int(255 * alpha))

    def scale_rgb(self, mask, factor: float):
        """Darken (factor < 1) or lighten the pixels under a mask."""
        region = self.a[mask, :3].astype(np.float32)
        if factor <= 1.0:
            region *= factor
        else:
            region += (255.0 - region) * min(1.0, factor - 1.0)
        self.a[mask, :3] = np.clip(region + 0.5, 0, 255).astype(np.uint8)

    def ellipse(self, cx, cy, rx, ry, c, alpha: float = 1.0):
        self.fill(self.ellipse_mask(cx, cy, rx, ry), c, alpha)

    # --- compositing --------------------------------------------------------
    def blit(self, other: "Canvas", x: int, y: int):
        """Alpha-composite another canvas at (x, y)."""
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.w, x + other.w), min(self.h, y + other.h)
        if x1 <= x0 or y1 <= y0:
            return
        src = other.a[y0 - y:y1 - y, x0 - x:x1 - x].astype(np.float32)
        dst = self.a[y0:y1, x0:x1].astype(np.float32)
        alpha = src[:, :, 3:4] / 255.0
        dst[:, :, :3] = dst[:, :, :3] * (1 - alpha) + src[:, :, :3] * alpha
        dst[:, :, 3:4] = np.maximum(dst[:, :, 3:4], src[:, :, 3:4])
        self.a[y0:y1, x0:x1] = np.clip(dst + 0.5, 0, 255).astype(np.uint8)

    def flipped(self) -> "Canvas":
        out = Canvas(self.w, self.h)
        out.a = self.a[:, ::-1].copy()
        return out

    def save(self, path, scale: int = 1):
        img = Image.fromarray(self.a, "RGBA")
        if scale != 1:
            img = img.resize((self.w * scale, self.h * scale), Image.NEAREST)
        img.save(path)

    def image(self) -> Image.Image:
        return Image.fromarray(self.a, "RGBA")


# --- noise ----------------------------------------------------------------------

def value_noise(w: int, h: int, cell: int, rng: np.random.Generator) -> np.ndarray:
    """Smooth 0..1 noise with features about `cell` pixels wide."""
    gw, gh = w // cell + 3, h // cell + 3
    g = rng.random((gh, gw)).astype(np.float32)
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    fx, fy = xs / cell, ys / cell
    x0, y0 = fx.astype(int), fy.astype(int)
    tx, ty = fx - x0, fy - y0
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = g[y0, x0] * (1 - tx) + g[y0, x0 + 1] * tx
    b = g[y0 + 1, x0] * (1 - tx) + g[y0 + 1, x0 + 1] * tx
    return a * (1 - ty) + b * ty


def shift(mask: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """Move a boolean mask by (dx, dy) pixels, filling with False."""
    out = np.zeros_like(mask)
    h, w = mask.shape
    xs0, xs1 = max(0, dx), min(w, w + dx)
    ys0, ys1 = max(0, dy), min(h, h + dy)
    if xs1 > xs0 and ys1 > ys0:
        out[ys0:ys1, xs0:xs1] = mask[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


def grow(mask: np.ndarray, left: int, right: int, top: int, bottom: int) -> np.ndarray:
    """Rectangular dilation by a different amount on each side."""
    out = mask.copy()
    row = mask.copy()
    for d in range(1, left + 1):
        row |= shift(mask, -d, 0)
    for d in range(1, right + 1):
        row |= shift(mask, d, 0)
    out = row.copy()
    for d in range(1, top + 1):
        out |= shift(row, 0, -d)
    for d in range(1, bottom + 1):
        out |= shift(row, 0, d)
    return out


def edge(mask: np.ndarray, outside: np.ndarray | None = None) -> np.ndarray:
    """Pixels of `mask` that touch a pixel that is not in it (4-neighbour)."""
    not_mask = ~mask if outside is None else outside
    return mask & (shift(not_mask, 1, 0) | shift(not_mask, -1, 0) | shift(not_mask, 0, 1) | shift(not_mask, 0, -1))
