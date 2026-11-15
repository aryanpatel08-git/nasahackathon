#!/usr/bin/env python3
"""Paints Lunar Life's world art as pixel art, straight from the game's floor plans.

    python3 tools/art/paint_world.py            # writes assets/art/world/*.png + *_art.json
    python3 tools/art/paint_world.py --preview  # also writes 2x previews to /tmp

The outpost floor plan is read from scripts/outpost/outpost_layout.gd and the academy's
from scripts/academy/academy_layout.gd, so the pictures always match the walls the game
builds from the same numbers. Parts that change while you play (battery charge, grow
lamps, the shelter hatch, warning lights) are NOT painted here: the game draws them on
top, using the rectangles this script writes to the *_art.json files.

Needs: Python 3, numpy, Pillow.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pixelkit import C, Canvas, edge, grow, mix, shade, shift, value_noise  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "world"

# --- palette --------------------------------------------------------------------
SKY_TOP, SKY_LOW = C("04060f"), C("0b1026")
REG = [C("3f3d5a"), C("55536f"), C("6a6884"), C("807e98"), C("9896ad")]   # dark -> light
HULL_EDGE = C("131429")
HULL_TOP = C("3c3f6e")
HULL_TOP_HI = C("585d94")
HULL_TOP_LO = C("2c2e56")
WALL = C("2f3160")
WALL_HI = C("474b82")
WALL_LO = C("1f2046")
STEEL = C("7d86ad")
STEEL_HI = C("a9b2d4")
STEEL_LO = C("555c84")
DARK = C("12142a")
TEAL = C("5fe3d3")
TEAL_LO = C("2a8f95")
AMBER = C("ffc45e")
AMBER_LO = C("b9722f")
GREEN = C("7ddc6f")
GREEN_LO = C("3f9a4d")
GREEN_DK = C("27663a")
SOIL = C("4a3328")
SOIL_HI = C("654636")
RED = C("ff6b5e")
WATER = C("4aa8d8")
WATER_HI = C("9fe0f2")
ORANGE = C("e2793f")
ORANGE_LO = C("a54f2c")

FLOOR_STYLES = {
    "corridor": (C("666d92"), C("585e84"), C("747ba0")),
    "power": (C("5c6389"), C("4e557a"), C("6a7197")),
    "green": (C("5f6c86"), C("515d78"), C("6d7a94")),
    "shelter": (C("555a80"), C("484c71"), C("63688e")),
}

FACE_H = 21
CAP_X, CAP_T, CAP_B = 9, 8, 7
OUT_H = 9


# --- reading the floor plan -------------------------------------------------------

def read_layout(path: Path) -> dict:
    """Pulls `const NAME := Rect2(...)`, Vector2(...), Vector2i(...) and numbers out of a .gd file."""
    out: dict = {}
    for line in path.read_text().splitlines():
        m = re.match(r"\s*const\s+(\w+)\s*(?::\s*\w+\s*)?:?=\s*(.+)$", line)
        if not m:
            continue
        name, value = m.group(1), m.group(2).strip()
        inner = value[value.find("(") + 1:] if "(" in value else value
        nums = [float(v) for v in re.findall(r"-?\d+(?:\.\d+)?", inner)]
        if value.startswith("Rect2(") and len(nums) == 4:
            out[name] = tuple(nums)
        elif value.startswith(("Vector2(", "Vector2i(")) and len(nums) == 2:
            out[name] = tuple(nums)
        elif re.fullmatch(r"-?\d+(?:\.\d+)?", value):
            out[name] = nums[0]
    return out


def scaled(layout: dict) -> dict:
    s = layout["SCALE"]
    out = {}
    for key, value in layout.items():
        if isinstance(value, tuple):
            out[key] = tuple(int(round(v * s)) for v in value)
        else:
            out[key] = value
    return out


# --- shared painting helpers ------------------------------------------------------

def hazard(cv: Canvas, x, y, w, h, a=AMBER, b=DARK, step=4):
    """Diagonal caution stripes."""
    for yy in range(h):
        for xx in range(w):
            cv.px(x + xx, y + yy, a if ((xx + yy) // step) % 2 == 0 else b)


def bolt_icon(cv: Canvas, x, y, c):
    for dx, dy in [(3, 0), (2, 1), (1, 2), (0, 3), (1, 3), (2, 3), (3, 3), (2, 4), (1, 5), (0, 6), (2, 2), (3, 1), (4, 0), (3, 4)]:
        cv.px(x + dx, y + dy, c)


def leaf_icon(cv: Canvas, x, y, c):
    for dx, dy in [(3, 0), (4, 0), (2, 1), (3, 1), (4, 1), (5, 1), (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (1, 3), (2, 3), (3, 3), (4, 3), (2, 4), (3, 4), (1, 5), (0, 6)]:
        cv.px(x + dx, y + dy, c)


def shield_icon(cv: Canvas, x, y, c):
    for dy, (x0, x1) in enumerate([(0, 6), (0, 6), (0, 6), (0, 6), (1, 5), (2, 4), (3, 3)]):
        cv.hline(x + x0, y + dy, x1 - x0 + 1, c)


def glow(cv: Canvas, cx, cy, radius, c, strength=0.35):
    """Banded light: three flat rings, strongest in the middle (pixel-art friendly)."""
    for k, frac in enumerate([1.0, 0.66, 0.36]):
        cv.fill(cv.ellipse_mask(cx, cy, radius * frac, radius * frac * 0.8), c, strength * (0.35 + 0.3 * k))


def screen(cv: Canvas, x, y, w, h, tint=TEAL):
    """A wall monitor: dark glass, coloured frame line, scan lines."""
    cv.rect(x - 1, y - 1, w + 2, h + 2, STEEL_LO)
    cv.rect(x, y, w, h, C("0d1f33"))
    cv.hline(x, y, w, shade(tint, 0.55))
    for yy in range(y + 2, y + h, 2):
        cv.hline(x + 1, yy, w - 2, C("12293f"))


def crate(cv: Canvas, x, y, w, h, body=STEEL_LO, label=AMBER):
    cv.rect(x, y, w, h, DARK)
    cv.rect(x + 1, y + 1, w - 2, h - 2, body)
    cv.rect(x + 1, y + 1, w - 2, max(2, h // 3), shade(body, 1.25))      # lid seen from above
    cv.hline(x + 1, y + 1 + max(2, h // 3), w - 2, shade(body, 0.7))
    cv.vline(x + w // 2, y + 1, h - 2, shade(body, 0.75))
    cv.rect(x + 3, y + h - 6, 5, 3, label)
    cv.px(x + 1, y + 1, shade(body, 1.5))


# --- the Moon outside -------------------------------------------------------------

def paint_ground(cv: Canvas, horizon: int, rng: np.random.Generator, craters, rocks):
    w, h = cv.w, cv.h
    # Sky: near black with a faint glow at the horizon, stars and Earth.
    for y in range(horizon):
        cv.hline(0, y, w, mix(SKY_TOP, SKY_LOW, (y / max(1, horizon - 1)) ** 2))
    for _ in range(170):
        x, y = int(rng.integers(0, w)), int(rng.integers(0, max(1, horizon - 3)))
        b = float(rng.random())
        c = mix(C("5a6690"), C("ffffff"), b)
        if rng.random() < 0.12:
            c = mix(c, C("9fd8ff") if rng.random() < 0.5 else C("ffe2b0"), 0.6)
        cv.px(x, y, c)
        if b > 0.93:
            cv.px(x + 1, y, shade(c, 0.6))
            cv.px(x, y + 1, shade(c, 0.6))
    ex, ey, er = w - 118, 17, 11
    cv.ellipse(ex, ey, er + 1.2, er + 1.2, C("1d3a66"))
    cv.ellipse(ex, ey, er, er, C("2f74c0"))
    cv.fill(cv.ellipse_mask(ex - 3, ey - 2, 5, 3.4) & cv.ellipse_mask(ex, ey, er, er), C("4cab7a"))
    cv.fill(cv.ellipse_mask(ex + 4, ey + 4, 3.2, 2.2) & cv.ellipse_mask(ex, ey, er, er), C("4cab7a"))
    cv.fill(cv.ellipse_mask(ex - 1, ey + 5, 6, 1.6) & cv.ellipse_mask(ex, ey, er, er), C("e6f2fb"))
    cv.fill(cv.ellipse_mask(ex + 2, ey - 5, 5, 1.4) & cv.ellipse_mask(ex, ey, er, er), C("e6f2fb"))
    night = cv.ellipse_mask(ex, ey, er, er) & ~cv.ellipse_mask(ex - 5, ey - 2, er + 2, er + 2)
    cv.fill(night, C("0a1430"), 0.82)

    # Regolith: four flat tones from two layers of soft noise.
    n = 0.6 * value_noise(w, h, 56, rng) + 0.4 * value_noise(w, h, 17, rng)
    ys = np.mgrid[0:h, 0:w][0]
    ground = ys >= horizon
    for lo, hi, tone in [(0.0, 0.36, REG[1]), (0.36, 0.56, REG[2]), (0.56, 0.74, mix(REG[2], REG[3], 0.5)), (0.74, 1.01, REG[3])]:
        cv.fill(ground & (n >= lo) & (n < hi), tone)
    # Grain.
    grain = rng.random((h, w))
    cv.fill(ground & (grain < 0.035), REG[1])
    cv.fill(ground & (grain > 0.972), REG[4])
    # The ground darkens a little toward the horizon so the base reads as nearer.
    for k in range(18):
        cv.scale_rgb(cv.rect_mask(0, horizon + k, w, 1), 0.72 + 0.28 * (k / 18.0))

    # Far ridge line on the horizon, lit from the left.
    ridge = 3.0 + 9.0 * value_noise(w, 1, 34, rng)[0] + 3.0 * value_noise(w, 1, 9, rng)[0]
    for x in range(w):
        top = int(horizon - ridge[x])
        cv.vline(x, top, horizon - top, REG[1])
        lit = x > 0 and ridge[x] > ridge[x - 1]
        cv.px(x, top, REG[4] if lit else REG[2])
        cv.px(x, top + 1, REG[3] if lit else REG[1])

    for cx, cy, rx in craters:
        ry = rx * 0.62
        cv.fill(cv.ellipse_mask(cx, cy, rx + 2, ry + 2) & ~cv.ellipse_mask(cx + 1.5, cy + 1.5, rx + 1, ry + 1), REG[4])   # sunlit outer rim
        cv.fill(cv.ellipse_mask(cx, cy, rx + 2, ry + 2) & ~cv.ellipse_mask(cx - 1.5, cy - 1.5, rx + 1, ry + 1), REG[1])   # far rim in shade
        cv.ellipse(cx, cy, rx, ry, REG[1])
        cv.fill(cv.ellipse_mask(cx, cy, rx, ry) & ~cv.ellipse_mask(cx + rx * 0.3, cy + ry * 0.38, rx, ry), REG[0])       # inner shadow
        cv.fill(cv.ellipse_mask(cx, cy, rx, ry) & ~cv.ellipse_mask(cx - rx * 0.22, cy - ry * 0.3, rx, ry), REG[2])       # lit inner wall
    for x, y, s in rocks:
        cv.rect(x + 2, y + s - 1, s + 2, 2, REG[0], 0.55)        # cast shadow
        cv.rect(x, y, s, s - 1, REG[1])
        cv.rect(x, y, s - 1, max(1, s - 2), REG[3])
        cv.px(x, y, REG[4])
        cv.px(x + s - 1, y + s - 2, REG[0])


# --- habitat shell ----------------------------------------------------------------

def habitat_masks(cv: Canvas, floors: dict, armored: list[str]):
    """Returns the pixel masks of floor, north wall faces, wall tops, outer faces and cast shadow."""
    floor = np.zeros((cv.h, cv.w), dtype=bool)
    for r in floors.values():
        floor |= cv.rect_mask(*r)
    face = np.zeros_like(floor)
    for k in range(1, FACE_H + 1):
        face |= shift(floor, 0, -k)
    face &= ~floor
    core = floor | face
    shell = grow(core, CAP_X, CAP_X, CAP_T, CAP_B)
    armor = np.zeros_like(floor)
    for name in armored:
        own = cv.rect_mask(*floors[name])
        own_face = np.zeros_like(own)
        for k in range(1, FACE_H + 1):
            own_face |= shift(own, 0, -k)
        armor |= grow(own | own_face, 15, 15, 13, 11)
    armor &= ~core
    shell |= armor
    cap = shell & ~core
    outer = np.zeros_like(floor)
    for k in range(1, OUT_H + 1):
        outer |= shift(shell, 0, k)
    outer &= ~shell
    solid = shell | outer
    shadow = (shift(solid, 7, 5) | shift(solid, 4, 3)) & ~solid
    return floor, face, cap, outer, solid, shadow, armor & cap


def paint_shell(cv: Canvas, floors: dict, armored: list[str], horizon: int):
    floor, face, cap, outer, solid, shadow, armor = habitat_masks(cv, floors, armored)
    xs, ys = cv.grid()
    ground = ys >= horizon
    cv.scale_rgb(shadow & ground & shift(solid, 7, 5), 0.62)
    cv.scale_rgb(shadow & ground & ~shift(solid, 7, 5), 0.8)

    # Outer south faces: dark plating with small teal running lights.
    cv.fill(outer, WALL_LO)
    cv.fill(outer & shift(~solid | cap | face, 0, 1) & shift(cap, 0, 1), WALL)
    cv.fill(outer & (xs % 24 == 0), DARK)
    lights = outer & shift(outer, 0, 3) & shift(outer, 0, -3) & (xs % 36 > 15) & (xs % 36 < 21)
    cv.fill(lights, TEAL)
    cv.fill(shift(lights, 0, 1) & outer & ~lights, TEAL_LO)

    # Wall tops.
    cv.fill(cap, HULL_TOP)
    horizontal = cap & (grow(floor | face, 0, 0, CAP_T + 14, CAP_B + 12))
    vertical = cap & (grow(floor | face, CAP_X + 16, CAP_X + 16, 0, 0))
    cv.fill(horizontal & ~vertical & (xs % 24 == 11), HULL_TOP_LO)
    cv.fill(vertical & ~horizontal & (ys % 24 == 11), HULL_TOP_LO)
    cv.fill(cap & shift(~solid, 0, 1), HULL_TOP_HI)            # lit top edge
    cv.fill(cap & shift(~solid, 1, 0), HULL_TOP_HI)            # lit left edge
    cv.fill(cap & shift(floor, -1, 0), HULL_TOP_LO)            # edge that drops to a floor on its right
    cv.fill(cap & shift(floor, 0, -1), HULL_TOP_LO)            # edge above a floor (south walls)
    cv.fill(cap & shift(floor, 1, 0), HULL_TOP_HI)
    # Armoured shell: a second ring and blue water-wall panels (water is good shielding).
    ring = armor & ~grow(floor | face, CAP_X - 2, CAP_X - 2, CAP_T - 2, CAP_B - 2)
    cv.fill(armor, shade(HULL_TOP, 0.86))
    cv.fill(edge(ring & armor, ~(ring & armor)) & armor, HULL_TOP_LO)
    panel = ring & armor & ~edge(ring & armor, ~(ring & armor))
    panel &= ~shift(~(ring & armor), 2, 0) & ~shift(~(ring & armor), -2, 0) & ~shift(~(ring & armor), 0, 2) & ~shift(~(ring & armor), 0, -2)
    cv.fill(panel & (((xs // 12) + (ys // 12)) % 2 == 0), C("2c5f8f"))
    cv.fill(panel & (((xs // 12) + (ys // 12)) % 2 == 1), C("26507c"))
    cv.fill(panel & ((xs % 12 == 0) | (ys % 12 == 0)), HULL_TOP_LO)
    cv.fill(armor & shift(~solid, 0, 1), HULL_TOP_HI)
    cv.fill(armor & shift(~solid, 1, 0), HULL_TOP_HI)

    # North wall faces: trim line on top, plating, dark skirting where they meet the floor.
    depth = np.zeros((cv.h, cv.w), dtype=np.int32)             # rows above the floor (1 = touching)
    for k in range(FACE_H, 0, -1):
        depth[shift(floor, 0, -k) & face] = k
    cv.fill(face, WALL)
    cv.fill(face & (depth >= FACE_H - 1), WALL_HI)
    cv.fill(face & (depth == FACE_H - 2), WALL_LO)
    cv.fill(face & (depth <= 2), WALL_LO)
    cv.fill(face & (depth == 3), shade(WALL, 0.85))
    cv.fill(face & (xs % 24 == 11) & (depth > 2) & (depth < FACE_H - 2), WALL_LO)
    cv.fill(face & (xs % 24 == 12) & (depth > 2) & (depth < FACE_H - 2), shade(WALL, 1.12))

    # Dark outline around the whole base.
    cv.fill(edge(solid), HULL_EDGE)
    return floor, face, cap, outer, solid, depth


def paint_floor(cv: Canvas, rect, style: str, face: np.ndarray, floor: np.ndarray, rng, tile=24):
    base, line, hi = FLOOR_STYLES[style]
    x, y, w, h = rect
    cv.rect(x, y, w, h, base)
    # A few tiles are a touch lighter or darker, like panels that were replaced.
    for ty in range(y, y + h, tile):
        for tx in range(x, x + w, tile):
            r = rng.random()
            if r < 0.14:
                cv.rect(tx, ty, min(tile, x + w - tx), min(tile, y + h - ty), mix(base, hi, 0.45))
            elif r > 0.88:
                cv.rect(tx, ty, min(tile, x + w - tx), min(tile, y + h - ty), mix(base, line, 0.5))
    for tx in range(x, x + w, tile):
        cv.vline(tx, y, h, line)
        cv.vline(tx + 1, y, h, hi, 0.35)
    for ty in range(y, y + h, tile):
        cv.hline(x, ty, w, line)
        cv.hline(x, ty + 1, w, hi, 0.35)
    own = cv.rect_mask(x, y, w, h)
    # Walls throw a soft shadow onto the floor in front of them and along the left side.
    for k, f in [(1, 0.62), (2, 0.74), (3, 0.84), (4, 0.92)]:
        cv.scale_rgb(own & shift(face, 0, k) & ~shift(face, 0, k - 1) if k > 1 else own & shift(face, 0, 1), f)
    cv.scale_rgb(own & shift(~floor, 1, 0), 0.8)
    cv.scale_rgb(own & shift(~floor, 2, 0) & ~shift(~floor, 1, 0), 0.92)
    cv.scale_rgb(own & shift(~floor, -1, 0), 0.88)
    cv.scale_rgb(own & shift(~floor, 0, -1), 0.86)


# --- outpost ------------------------------------------------------------------------

def paint_outpost(preview: bool):
    L = scaled(read_layout(ROOT / "scripts" / "outpost" / "outpost_layout.gd"))
    W, H = L["MAP"]
    horizon = int(L["HORIZON"] * L["SCALE"])
    rng = np.random.default_rng(20261115)
    cv = Canvas(W, H, SKY_TOP)
    art: dict = {}

    craters = [(84, 96, 22), (598, 92, 15), (690, 150, 9), (30, 190, 8), (228, 440, 9), (516, 436, 13), (702, 400, 7),
               (150, 60, 6), (16, 300, 5), (455, 62, 5), (700, 250, 5)]
    rocks = [(22, 140, 4), (196, 70, 3), (214, 196, 4), (500, 150, 3), (708, 96, 5), (692, 330, 4), (12, 410, 5),
             (274, 438, 3), (438, 444, 4), (588, 422, 3), (30, 250, 3), (640, 60, 3), (540, 70, 4), (120, 150, 3)]
    paint_ground(cv, horizon, rng, craters, rocks)

    floors = {name: L[name] for name in ["CORRIDOR", "POWER_ROOM", "POWER_DOOR", "GREEN_ROOM", "GREEN_DOOR", "SHELTER_ROOM", "SHELTER_DOOR"]}
    paint_exterior_before(cv, L, rng)
    floor, face, cap, outer, solid, depth = paint_shell(cv, floors, ["SHELTER_ROOM"], horizon)
    styles = {"CORRIDOR": "corridor", "POWER_ROOM": "power", "POWER_DOOR": "corridor", "GREEN_ROOM": "green",
              "GREEN_DOOR": "corridor", "SHELTER_ROOM": "shelter", "SHELTER_DOOR": "corridor"}
    for name, rect in floors.items():
        paint_floor(cv, rect, styles[name], face, floor, rng)

    paint_corridor(cv, L, art)
    paint_power_room(cv, L, art)
    paint_greenhouse(cv, L, art, rng)
    paint_shelter(cv, L, art)
    paint_exterior_after(cv, L, art)
    # Banded pools of light on the floor under the wall lamps.
    for name, tint in (("POWER_ROOM", TEAL), ("GREEN_ROOM", C("f6b7ff")), ("SHELTER_ROOM", AMBER)):
        x, y, w, h = L[name]
        own = cv.rect_mask(x, y, w, h)
        for lx in (x + 14, x + w - 14) if name != "SHELTER_ROOM" else (x + 36, x + w - 56):
            cv.fill(own & cv.ellipse_mask(lx, y + 6, 34, 22), tint, 0.05)
            cv.fill(own & cv.ellipse_mask(lx, y + 4, 20, 12), tint, 0.07)
    x, y, w, h = L["CORRIDOR"]
    own = cv.rect_mask(x, y, w, h)
    for ly in range(y + 34, y + h - 20, 48):
        cv.fill(own & cv.ellipse_mask(x + w / 2, ly, 46, 16), C("cfe8ff"), 0.045)

    OUT.mkdir(parents=True, exist_ok=True)
    cv.save(OUT / "outpost_bg.png")
    paint_hatch(art)
    (OUT / "outpost_art.json").write_text(json.dumps(art, indent="\t", sort_keys=True) + "\n")
    if preview:
        cv.save("/tmp/outpost_bg_2x.png", 2)
    return cv


def paint_exterior_before(cv: Canvas, L: dict, rng):
    """Things that sit on the ground behind the base: rover tracks and the cable trench."""
    rx, ry = L["ROVER_SPOT"]
    for off in (-5, 5):
        for x in range(0, rx - 14, 3):
            cv.px(x, ry + off + int(2 * np.sin(x / 23.0)), REG[1])
    # Buried power cable from the solar field to the power room wall.
    px, py, pw, ph = L["POWER_ROOM"]
    for y in range(150, py - FACE_H - CAP_T, 2):
        cv.px(120, y, REG[1])
        cv.px(121, y + 1, REG[0])


def paint_corridor(cv: Canvas, L: dict, art: dict):
    x, y, w, h = L["CORRIDOR"]
    cx = x + w // 2
    door_y = L["POWER_DOOR"][1] + L["POWER_DOOR"][3] // 2
    pad_x, pad_y = L["RETURN_SPOT"]
    # Way-finding lines on the floor: teal to power, green to the greenhouse, amber to the shelter.
    top = y + 20
    cv.rect(cx - 1, top + 8, 2, pad_y - 28 - top, AMBER_LO)
    cv.rect(cx - 7, door_y - 1, 2, pad_y - 19 - door_y, TEAL_LO)
    cv.rect(L["POWER_DOOR"][0] + 6, door_y - 1, cx - 7 - L["POWER_DOOR"][0] - 4, 2, TEAL_LO)
    cv.rect(cx + 5, door_y + 3, 2, pad_y - 23 - door_y, GREEN_LO)
    cv.rect(cx + 5, door_y + 3, L["GREEN_DOOR"][0] + L["GREEN_DOOR"][2] - 6 - cx - 5, 2, GREEN_LO)
    for k in range(3):                                                     # arrow heads
        cv.vline(L["POWER_DOOR"][0] + 6 + k, door_y - 1 - k, 2 + 2 * k, TEAL_LO)
        cv.vline(L["GREEN_DOOR"][0] + L["GREEN_DOOR"][2] - 7 - k, door_y + 3 - k, 2 + 2 * k, GREEN_LO)
        cv.hline(cx - 1 - k, top + 8 + k, 2 + 2 * k, AMBER_LO)
    bolt_icon(cv, L["POWER_DOOR"][0] + L["POWER_DOOR"][2] + 5, door_y - 12, TEAL)
    leaf_icon(cv, L["GREEN_DOOR"][0] - 12, door_y + 9, GREEN)

    # Door thresholds for the two side passages: caution stripes and steel posts.
    for name in ("POWER_DOOR", "GREEN_DOOR"):
        dx, dy, dw, dh = L[name]
        for ex in (dx, dx + dw - 4):
            hazard(cv, ex, dy, 4, dh, AMBER, DARK, 3)
        for ex in (dx - 1, dx + dw - 2):
            cv.rect(ex, dy - FACE_H + 2, 3, FACE_H - 2, STEEL_LO)
            cv.vline(ex, dy - FACE_H + 2, FACE_H - 2, STEEL_HI)
            cv.rect(ex, dy - 6, 3, 2, AMBER)
        cv.rect(dx + 6, dy - FACE_H + 4, dw - 12, 11, DARK)                 # sign plate; the game letters it
        cv.frame(dx + 6, dy - FACE_H + 4, dw - 12, 11, STEEL_LO)
    art["corridor_lights"] = []
    for yy in range(y + 30, y + h - 30, 24):
        for lx in (x + 3, x + w - 6):
            cv.rect(lx, yy, 3, 8, DARK)
            art["corridor_lights"].append([lx, yy, 3, 8])

    # Shelter doorway floor: heavy caution plate. The hatch itself is drawn by the game.
    sx, sy, sw, sh = L["SHELTER_DOOR"]
    cv.rect(sx, sy, sw, sh, C("3a3d62"))
    hazard(cv, sx, sy + sh - 5, sw, 5, AMBER, DARK, 4)
    hazard(cv, sx, sy, sw, 4, AMBER, DARK, 4)
    for k in range(4, sh - 5, 4):
        cv.hline(sx + 3, sy + k, sw - 6, C("2c2e52"))
    art["hatch"] = [sx, sy, sw, sh]

    # Transit pad to the academy at the south end.
    cv.fill(cv.ellipse_mask(pad_x, pad_y - 2, 22, 11), DARK)
    cv.fill(cv.ellipse_mask(pad_x, pad_y - 2, 20, 9.5), C("464b72"))
    ring = cv.ellipse_mask(pad_x, pad_y - 2, 20, 9.5) & ~cv.ellipse_mask(pad_x, pad_y - 2, 16, 7.5)
    xs, ys = cv.grid()
    cv.fill(ring & (((xs + ys) // 4) % 2 == 0), AMBER)
    cv.fill(ring & (((xs + ys) // 4) % 2 == 1), DARK)
    cv.fill(cv.ellipse_mask(pad_x, pad_y - 2, 9, 4), TEAL_LO)
    cv.fill(cv.ellipse_mask(pad_x, pad_y - 2, 6, 2.5), C("464b72"))
    art["transit_pad"] = [pad_x, pad_y - 2]


def paint_power_room(cv: Canvas, L: dict, art: dict):
    rx, ry, rw, rh = L["POWER_ROOM"]
    # Battery bank: a cabinet against the north wall. The eight cell windows are filled by the game.
    bx, by, bw, bd = L["BATTERY_BANK"]
    top = by - 17
    cv.rect(bx - 1, top - 1, bw + 2, 17 + bd + 1, DARK)
    cv.rect(bx, top, bw, 4, STEEL_HI)                                   # top of the cabinet
    cv.rect(bx, top + 4, bw, 13 + bd - 4, STEEL_LO)
    cv.hline(bx, top + 4, bw, STEEL)
    cv.rect(bx, by + bd - 3, bw, 3, C("3a3f62"))                          # plinth
    cells = []
    cell_w = (bw - 8) // 8
    for i in range(8):
        cx0 = bx + 4 + i * cell_w
        cv.rect(cx0, top + 7, cell_w - 2, 16, DARK)
        cv.rect(cx0 + 1, top + 8, cell_w - 4, 14, C("16233a"))
        cv.rect(cx0 + 2, top + 5, cell_w - 6, 2, STEEL)                   # terminal
        cells.append([cx0 + 1, top + 8, cell_w - 4, 14])
    art["battery_cells"] = cells
    hazard(cv, bx, by + bd, bw, 3, AMBER, DARK, 3)                        # keep-clear strip on the floor
    # Conduit from the bank to the console.
    cx, cy, cw, cd = L["POWER_CONSOLE"]
    cv.rect(bx + bw, top + 9, cx - bx - bw, 3, DARK)
    cv.hline(bx + bw, top + 10, cx - bx - bw, TEAL_LO)

    # Console: wall monitor above a sloped desk of switches.
    screen(cv, cx + 6, cy - FACE_H + 3, cw - 12, 12, TEAL)
    art["power_screen"] = [cx + 6, cy - FACE_H + 3, cw - 12, 12]
    cv.rect(cx - 1, cy - 5, cw + 2, cd + 6, DARK)
    cv.rect(cx, cy - 4, cw, 5, STEEL_HI)
    cv.rect(cx, cy + 1, cw, cd - 1, STEEL)
    cv.rect(cx, cy + cd - 3, cw, 3, STEEL_LO)
    for i in range(6):
        cv.rect(cx + 5 + i * 9, cy - 3, 5, 3, AMBER if i % 3 else TEAL)
        cv.px(cx + 5 + i * 9, cy - 3, C("ffffff"))
    cv.rect(cx + 4, cy + 3, cw - 8, 6, DARK)
    for i in range(10):
        cv.rect(cx + 6 + i * 5, cy + 5, 3, 2, TEAL_LO if i % 2 else AMBER_LO)
    art["power_console"] = [cx, cy, cw, cd]

    # Sign and wall lamp.
    bolt_icon(cv, bx + bw + 8, ry - FACE_H + 4, AMBER)
    for lx in (rx + 8, rx + rw - 20):
        cv.rect(lx, ry - FACE_H + 4, 12, 3, DARK)
        cv.rect(lx + 1, ry - FACE_H + 5, 10, 1, TEAL)

    # Crates in the corner, and a tool cart.
    kx, ky, kw, kh = L["CRATES"]
    crate(cv, kx, ky + 8, 22, kh - 8)
    crate(cv, kx + 17, ky + 14, kw - 17, kh - 14, STEEL, TEAL)
    crate(cv, kx + 3, ky, 17, 13, C("5f668e"), AMBER)
    cv.rect(kx + 2, ky + kh, kw, 2, DARK, 0.3)

    # Workbench along the west wall with a charger dock and tools.
    wx, wy, ww, wh = L["WORKBENCH"]
    cv.rect(wx + 2, wy + wh, ww, 2, DARK, 0.3)
    cv.rect(wx, wy, ww, wh, DARK)
    cv.rect(wx + 1, wy + 1, ww - 2, wh - 2, C("6b5a4e"))
    cv.rect(wx + 1, wy + 1, ww - 2, 2, C("8a7565"))
    cv.rect(wx + 1, wy + wh - 5, ww - 2, 4, C("4d4038"))
    cv.rect(wx + 4, wy + 6, 9, 7, DARK)
    cv.rect(wx + 5, wy + 7, 7, 5, TEAL_LO)
    cv.rect(wx + 4, wy + 18, 3, 9, STEEL_HI)
    cv.rect(wx + 9, wy + 17, 5, 3, AMBER)
    cv.rect(wx + 9, wy + 23, 6, 2, STEEL)
    cv.rect(wx + 5, wy + 31, 8, 6, C("3b3f5c"))
    cv.rect(wx + 6, wy + 32, 6, 2, RED)
    # Cable channel in the floor from the battery bank down to the door.
    door = L["POWER_DOOR"]
    channel_y = door[1] + door[3] // 2 + 8
    cv.rect(bx + 20, by + bd + 3, 3, channel_y - by - bd - 3, C("3f4468"))
    cv.rect(bx + 20, channel_y, rx + rw - bx - 20, 3, C("3f4468"))
    for k in range(bx + 24, rx + rw - 2, 8):
        cv.px(k, channel_y + 1, TEAL_LO)
    for k in range(by + bd + 6, channel_y, 8):
        cv.px(bx + 21, k, TEAL_LO)
    # Floor outline that marks the operator's spot (the game adds the pulsing marker).
    sx, sy = L["POWER_SPOT"]
    art["power_spot"] = [sx, sy]
    for k in range(0, 36, 6):
        cv.hline(sx - 18 + k, sy + 10, 3, AMBER_LO)
        cv.hline(sx - 18 + k, sy - 12, 3, AMBER_LO)


def plant(cv: Canvas, x, y, kind: int, rng):
    """One plant seen from above, about 11 x 11 pixels."""
    if kind == 0:      # lettuce rosette
        cv.ellipse(x + 5.5, y + 5.5, 5.4, 5.0, GREEN_DK)
        cv.ellipse(x + 5.5, y + 5.2, 4.4, 4.0, GREEN_LO)
        cv.ellipse(x + 5.2, y + 4.8, 3.0, 2.6, GREEN)
        cv.ellipse(x + 5.0, y + 4.4, 1.5, 1.2, C("c8f5a8"))
        cv.px(x + 2, y + 6, GREEN)
        cv.px(x + 8, y + 7, GREEN)
    elif kind == 1:    # tomato bush
        cv.ellipse(x + 5.5, y + 5.5, 5.4, 5.2, GREEN_DK)
        cv.ellipse(x + 5.0, y + 5.0, 4.0, 3.8, C("2f8a48"))
        cv.ellipse(x + 4.6, y + 4.2, 2.2, 1.8, C("4fb35c"))
        for dx, dy in [(2, 3), (7, 3), (3, 7), (7, 7), (5, 5)]:
            cv.rect(x + dx, y + dy, 2, 2, RED)
            cv.px(x + dx, y + dy, C("ffb7a8"))
    elif kind == 2:    # wheat: rows of stalks with golden heads
        for dx in (1, 4, 7, 10):
            cv.vline(x + dx, y + 2, 8, C("7fae4a"))
            cv.rect(x + dx - 1, y, 2, 3, C("e8d36a"))
            cv.px(x + dx, y, C("fff0a0"))
            cv.px(x + dx - 1, y + 5, C("5d8f3c"))
            cv.px(x + dx + 1, y + 7, C("5d8f3c"))
    else:              # herbs with small flowers
        cv.ellipse(x + 5.5, y + 5.5, 5.0, 4.6, GREEN_DK)
        cv.ellipse(x + 5.2, y + 5.0, 3.8, 3.4, GREEN_LO)
        for dx, dy in [(2, 4), (4, 2), (7, 3), (3, 7), (6, 6), (5, 4), (8, 6)]:
            cv.px(x + dx, y + dy, GREEN)
        for dx, dy in [(4, 5), (7, 5), (5, 8)]:
            cv.px(x + dx, y + dy, C("f6a8c8"))


def paint_greenhouse(cv: Canvas, L: dict, art: dict, rng):
    rx, ry, rw, rh = L["GREEN_ROOM"]
    art["beds"] = []
    art["bed_lamps"] = []
    for i, name in enumerate(["BED_A", "BED_B", "BED_C", "BED_D"]):
        x, y, w, h = L[name]
        cv.rect(x + 2, y + h, w, 2, DARK, 0.3)                           # shadow on the floor
        cv.rect(x, y, w, h, DARK)
        cv.rect(x + 1, y + 1, w - 2, h - 2, STEEL_LO)
        cv.rect(x + 1, y + 1, w - 2, 3, STEEL)                            # lamp rail along the back
        cv.rect(x + 3, y + 4, w - 6, h - 13, SOIL)
        for sy in range(y + 6, y + h - 10, 3):
            cv.hline(x + 4, sy, w - 8, SOIL_HI, 0.6)
        for row in range(2):
            for col in range(5):
                plant(cv, x + 4 + col * 12 - (0 if row == 0 else 0), y + 5 + row * 13, i, rng)
        # Front of the planter: plating, teal status strip.
        cv.rect(x + 1, y + h - 9, w - 2, 8, STEEL)
        cv.hline(x + 1, y + h - 9, w - 2, STEEL_HI)
        cv.rect(x + 1, y + h - 3, w - 2, 2, STEEL_LO)
        cv.rect(x + 5, y + h - 6, w - 10, 2, DARK)
        art["beds"].append([x, y, w, h])
        art["bed_lamps"].append([x + 3, y + 2, w - 6, 1])
        cv.rect(x + 3, y + 2, w - 6, 1, DARK)
        cv.rect(x + w - 9, y + h - 6, 4, 2, DARK)

    # Water tank and irrigation control on the north wall.
    tx, ty, tw, td = L["WATER_TANK"]
    top = ty - FACE_H + 2
    cv.rect(tx + 5, top, tw - 10, FACE_H + 6, DARK)
    cv.rect(tx + 6, top + 1, tw - 12, FACE_H + 4, WATER)
    cv.rect(tx + 6, top + 1, tw - 12, 6, C("1b2c4a"))                     # air gap at the top
    cv.vline(tx + 8, top + 2, FACE_H + 2, WATER_HI)
    cv.vline(tx + tw - 9, top + 8, FACE_H - 5, shade(WATER, 0.75))
    cv.rect(tx + 4, top - 2, tw - 8, 3, STEEL_HI)
    cv.rect(tx + 4, top + FACE_H + 5, tw - 8, 3, STEEL_LO)
    art["water_tank"] = [tx + 6, top + 7, tw - 12, FACE_H - 2]
    # Pipes to both sides.
    for px0, px1 in ((rx + 20, tx + 5), (tx + tw - 5, rx + rw - 20)):
        cv.rect(px0, ty - 7, px1 - px0, 3, STEEL_LO)
        cv.hline(px0, ty - 7, px1 - px0, STEEL_HI)
        for jx in range(px0 + 12, px1 - 4, 28):
            cv.rect(jx, ty - 8, 3, 5, STEEL)
    # Control pedestal in front of the tank.
    cv.rect(tx + 2, ty + 2, tw - 4, td - 2, DARK)
    cv.rect(tx + 3, ty + 3, tw - 6, td - 6, STEEL)
    cv.rect(tx + 3, ty + 3, tw - 6, 3, STEEL_HI)
    cv.rect(tx + 6, ty + 7, 9, 5, C("0d1f33"))
    cv.rect(tx + tw - 13, ty + 8, 5, 3, AMBER)
    art["green_screen"] = [tx + 6, ty + 7, 9, 5]
    # Wall lamps and a leaf sign.
    leaf_icon(cv, rx + rw // 2 + 26, ry - FACE_H + 4, GREEN)
    for lx in (rx + 8, rx + rw - 20):
        cv.rect(lx, ry - FACE_H + 4, 12, 3, DARK)
        cv.rect(lx + 1, ry - FACE_H + 5, 10, 1, C("f6b7ff"))
    sx, sy = L["GREEN_SPOT"]
    art["green_spot"] = [sx, sy]


def paint_shelter(cv: Canvas, L: dict, art: dict):
    rx, ry, rw, rh = L["SHELTER_ROOM"]
    # A warm rug of caution orange down the middle so the room reads as "safe place".
    dx = L["SHELTER_DOOR"][0]
    dw = L["SHELTER_DOOR"][2]
    mid_x = dx + dw // 2
    cv.frame(dx - 10, ry + 28, dw + 20, rh - 28, AMBER_LO)
    cv.frame(dx - 8, ry + 30, dw + 16, rh - 30, C("43476c"))
    # Shield emblem inlaid in the floor.
    for row, half in enumerate([13, 13, 13, 13, 13, 13, 12, 12, 11, 10, 9, 8, 6, 5, 3, 1]):
        cv.hline(mid_x - half, ry + 38 + row, half * 2, C("6a5a52") if row > 0 else AMBER_LO)
    for row, half in enumerate([10, 10, 10, 10, 10, 9, 9, 8, 7, 6, 5, 3, 1]):
        cv.hline(mid_x - half, ry + 40 + row, half * 2, C("4d5178"))
    cv.rect(mid_x - 1, ry + 42, 2, 9, AMBER_LO)
    cv.rect(mid_x - 5, ry + 45, 10, 2, AMBER_LO)
    # Emergency supplies stacked in the corners.
    crate(cv, rx + 4, ry + rh - 24, 20, 18, C("5f668e"), AMBER)
    crate(cv, rx + 20, ry + rh - 18, 16, 12, STEEL_LO, TEAL)
    crate(cv, rx + rw - 26, ry + rh - 24, 20, 18, STEEL_LO, WATER)
    crate(cv, rx + rw - 40, ry + rh - 17, 15, 11, C("5f668e"), AMBER)
    for name in ("BENCH_WEST", "BENCH_EAST"):
        x, y, w, d = L[name]
        cv.rect(x - 1, y - 9, w + 2, d + 10, DARK)
        cv.rect(x, y - 8, w, 8, ORANGE_LO)                                # back rest on the wall
        cv.hline(x, y - 8, w, ORANGE)
        cv.rect(x, y, w, d - 4, ORANGE)                                   # seat
        cv.hline(x, y, w, C("f39a5c"))
        for sx in range(x + w // 3, x + w - 2, w // 3):
            cv.vline(sx, y - 7, d + 3, ORANGE_LO)
        cv.rect(x, y + d - 4, w, 3, STEEL_LO)
        cv.rect(x + 2, y + d - 1, 3, 2, DARK)
        cv.rect(x + w - 5, y + d - 1, 3, 2, DARK)
    # Wall kit between the benches: radiation monitor (drawn live by the game), supplies, first aid.
    mid = rx + rw // 2
    screen(cv, mid - 17, ry - FACE_H + 4, 34, 12, AMBER)
    art["rad_screen"] = [mid - 17, ry - FACE_H + 4, 34, 12]
    cv.rect(rx + 8, ry - FACE_H + 5, 13, 12, DARK)
    cv.rect(rx + 9, ry - FACE_H + 6, 11, 10, C("e9eef7"))
    cv.rect(rx + 13, ry - FACE_H + 8, 3, 6, C("3fae5c"))
    cv.rect(rx + 11, ry - FACE_H + 10, 7, 2, C("3fae5c"))                 # green first-aid cross
    for k in range(3):                                                    # water and ration lockers
        lx = rx + rw - 44 + k * 12
        cv.rect(lx, ry - FACE_H + 5, 11, 13, DARK)
        cv.rect(lx + 1, ry - FACE_H + 6, 9, 11, STEEL_LO)
        cv.rect(lx + 2, ry - FACE_H + 8, 7, 3, WATER if k < 2 else AMBER_LO)
        cv.px(lx + 8, ry - FACE_H + 13, STEEL_HI)
    for lx in (rx + 30, rx + rw - 62):
        cv.rect(lx, ry - FACE_H + 4, 12, 3, DARK)
        cv.rect(lx + 1, ry - FACE_H + 5, 10, 1, AMBER)
    art["shelter_room"] = [rx, ry, rw, rh]
    # Beacon housing above the hatch, on the corridor side. The lamp is animated by the game.
    hx, hy, hw, hh = L["SHELTER_DOOR"]
    art["beacon"] = [hx + hw // 2, hy - 2]


def solar_panel(cv: Canvas, x, y, w=40, h=20):
    cv.rect(x + 6, y + h + 1, w, 5, REG[0], 0.5)                          # long shadow, sun is low
    cv.rect(x + w // 2 - 1, y + h - 2, 3, 7, STEEL_LO)                    # post
    cv.rect(x + w // 2 - 4, y + h + 4, 9, 2, DARK)
    cv.rect(x, y, w, h, DARK)
    cv.rect(x + 1, y + 1, w - 2, h - 2, C("1f3f8a"))
    for gx in range(x + 1, x + w - 1, 6):
        cv.vline(gx, y + 1, h - 2, C("16306e"))
    for gy in range(y + 1, y + h - 1, 6):
        cv.hline(x + 1, gy, w - 2, C("16306e"))
    cv.hline(x + 1, y + 1, w - 2, C("5f8fe0"))
    cv.vline(x + 1, y + 1, h - 2, C("3f6cc4"))
    for k in range(0, w - 8, 9):                                          # glint
        cv.px(x + 4 + k, y + 3, C("b8d4ff"))
    cv.hline(x, y + h, w, STEEL_HI)


def paint_exterior_after(cv: Canvas, L: dict, art: dict):
    # Solar field north-west of the power room.
    art["solar_panels"] = []
    for row, y in enumerate((112, 150)):
        for col in range(3):
            x = 34 + col * 52 + row * 10
            solar_panel(cv, x, y)
            art["solar_panels"].append([x, y, 40, 20])
    # Junction box where the cable enters the hull.
    px, py, pw, ph = L["POWER_ROOM"]
    cv.rect(114, py - FACE_H - CAP_T - 6, 13, 7, DARK)
    cv.rect(115, py - FACE_H - CAP_T - 5, 11, 5, STEEL)
    cv.px(124, py - FACE_H - CAP_T - 4, TEAL)
    art["junction_light"] = [124, py - FACE_H - CAP_T - 4]

    # Comms dish and tanks north-east of the greenhouse.
    gx, gy, gw, gh = L["GREEN_ROOM"]
    dx, dy = gx + gw - 40, gy - FACE_H - CAP_T - 44
    cv.rect(dx + 4, dy + 34, 26, 4, REG[0], 0.5)
    cv.rect(dx + 8, dy + 18, 3, 16, STEEL_LO)
    cv.rect(dx + 2, dy + 32, 15, 3, DARK)
    cv.fill(cv.ellipse_mask(dx + 10, dy + 10, 13, 9), DARK)
    cv.fill(cv.ellipse_mask(dx + 10, dy + 10, 12, 8), STEEL_HI)
    cv.fill(cv.ellipse_mask(dx + 11, dy + 11, 9, 6), STEEL)
    cv.fill(cv.ellipse_mask(dx + 12, dy + 12, 5, 3), STEEL_LO)
    cv.line(dx + 10, dy + 10, dx + 19, dy + 2, DARK)
    cv.rect(dx + 18, dy, 3, 3, AMBER)
    art["dish_light"] = [dx + 19, dy + 1]
    for k, tx in enumerate((gx + 26, gx + 58)):
        ty = gy - FACE_H - CAP_T - 30
        cv.rect(tx + 5, ty + 24, 22, 4, REG[0], 0.5)
        cv.rect(tx, ty, 20, 26, DARK)
        cv.rect(tx + 1, ty + 1, 18, 24, STEEL if k == 0 else C("8f9ac0"))
        cv.rect(tx + 1, ty + 1, 18, 4, STEEL_HI)
        cv.vline(tx + 3, ty + 5, 19, STEEL_HI)
        cv.vline(tx + 16, ty + 5, 19, STEEL_LO)
        cv.rect(tx + 5, ty + 11, 10, 5, WATER if k == 0 else C("d9e4f5"))
        cv.rect(tx + 8, ty + 26, 4, 8, STEEL_LO)                          # pipe down into the hull

    # Rover parked south-west. Its charge cable and lamp are drawn by the game.
    rx, ry = L["ROVER_SPOT"]
    cv.rect(rx - 12, ry + 6, 34, 4, REG[0], 0.55)
    for wx in (-15, -4, 8):
        cv.rect(rx + wx, ry + 2, 7, 6, DARK)
        cv.rect(rx + wx + 1, ry + 3, 5, 4, C("3b3f5c"))
        cv.px(rx + wx + 3, ry + 5, STEEL)
    cv.rect(rx - 15, ry - 5, 30, 8, DARK)
    cv.rect(rx - 14, ry - 4, 28, 6, STEEL)
    cv.hline(rx - 14, ry - 4, 28, STEEL_HI)
    cv.rect(rx - 10, ry - 11, 18, 7, DARK)
    cv.rect(rx - 9, ry - 10, 16, 5, C("1f3f8a"))
    cv.hline(rx - 9, ry - 10, 16, C("5f8fe0"))
    cv.rect(rx + 10, ry - 14, 2, 10, STEEL_LO)
    cv.rect(rx + 8, ry - 17, 6, 4, DARK)
    cv.rect(rx + 9, ry - 16, 3, 2, TEAL)
    art["rover"] = [rx, ry]
    art["rover_port"] = [rx - 15, ry - 1]
    art["rover_lamp"] = [rx + 12, ry - 6]
    # Charge socket on the hull, below the power room.
    px, py, pw, ph = L["POWER_ROOM"]
    sx, sy = rx - 34, py + ph + CAP_B + 2
    cv.rect(sx, sy, 6, 5, DARK)
    cv.rect(sx + 1, sy + 1, 4, 3, AMBER_LO)
    art["hull_port"] = [sx + 3, sy + 4]

    # Landing lights leading away from the transit end of the corridor.
    cx = L["CORRIDOR"][0] + L["CORRIDOR"][2] // 2
    by = L["CORRIDOR"][1] + L["CORRIDOR"][3] + CAP_B + OUT_H + 4
    art["path_lights"] = []
    for k, off in enumerate((-70, -46, 46, 70)):
        lx, ly = cx + off, by + (2 if abs(off) > 50 else 0)
        cv.rect(lx - 1, ly + 3, 6, 2, REG[0], 0.5)
        cv.rect(lx, ly, 3, 5, DARK)
        cv.px(lx + 1, ly + 1, AMBER)
        art["path_lights"].append([lx + 1, ly + 1])


def paint_hatch(art: dict):
    """The shelter's blast hatch: two heavy leaves, drawn closed. The game slides them apart."""
    w, h = art["hatch"][2], art["hatch"][3]
    leaf_w = w // 2
    cv = Canvas(w, h)
    for side in range(2):
        x0 = side * leaf_w
        cv.rect(x0, 0, leaf_w, h, DARK)
        cv.rect(x0 + 1, 1, leaf_w - 2, h - 2, C("59608a"))
        cv.rect(x0 + 1, 1, leaf_w - 2, 2, C("8a92bd"))
        cv.rect(x0 + 1, h - 4, leaf_w - 2, 3, C("3d4268"))
        hazard(cv, x0 + 3, 5, leaf_w - 6, 4, AMBER, DARK, 3)
        hazard(cv, x0 + 3, h - 10, leaf_w - 6, 4, AMBER, DARK, 3)
        cv.rect(x0 + 4, 11, leaf_w - 8, h - 23, C("4a5078"))
        cv.frame(x0 + 4, 11, leaf_w - 8, h - 23, C("3d4268"))
        for bx, by in ((x0 + 2, 3), (x0 + leaf_w - 3, 3), (x0 + 2, h - 5), (x0 + leaf_w - 3, h - 5)):
            cv.px(bx, by, C("b6bee0"))
    # Locking wheel across the seam.
    cv.fill(cv.ellipse_mask(w / 2, h / 2, 5.2, 5.2), DARK)
    cv.fill(cv.ellipse_mask(w / 2, h / 2, 4.2, 4.2), STEEL_HI)
    cv.fill(cv.ellipse_mask(w / 2, h / 2, 2.4, 2.4), C("59608a"))
    cv.rect(w // 2 - 1, h // 2 - 4, 2, 9, STEEL_LO)
    cv.rect(w // 2 - 4, h // 2 - 1, 9, 2, STEEL_LO)
    cv.vline(w // 2 - 1, 0, h, DARK)
    cv.vline(w // 2, 0, h, DARK)
    cv.save(OUT / "hatch_leaves.png")

    # Frame: posts either side and a lintel with a status light slot.
    fw, fh = w + 16, h + 12
    fr = Canvas(fw, fh)
    for x0 in (0, fw - 8):
        fr.rect(x0, 6, 8, fh - 6, DARK)
        fr.rect(x0 + 1, 7, 6, fh - 8, STEEL_LO)
        fr.vline(x0 + 1, 7, fh - 8, STEEL_HI)
        hazard(fr, x0 + 2, fh - 12, 4, 10, AMBER, DARK, 3)
    fr.rect(0, 0, fw, 9, DARK)
    fr.rect(1, 1, fw - 2, 7, STEEL)
    fr.hline(1, 1, fw - 2, STEEL_HI)
    fr.hline(1, 7, fw - 2, STEEL_LO)
    fr.rect(fw // 2 - 14, 3, 28, 3, DARK)
    fr.save(OUT / "hatch_frame.png")
    art["hatch_frame_size"] = [fw, fh]
    art["hatch_status_slot"] = [fw // 2 - 13, 4, 26, 1]


def main():
    preview = "--preview" in sys.argv
    paint_outpost(preview)
    academy = ROOT / "scripts" / "academy" / "academy_layout.gd"
    if academy.exists():
        from paint_academy import paint_academy  # noqa: WPS433
        paint_academy(preview)
    print("painted ->", OUT)


if __name__ == "__main__":
    main()
