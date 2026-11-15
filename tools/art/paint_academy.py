"""Paints the Astronaut Academy hall (assets/art/world/academy_bg.png).

Run through paint_world.py. The floor plan comes from scripts/academy/academy_layout.gd.
Live parts (the hologram, the hatch lamp, blinking racks, screen traces) are drawn by the
game on top, using the rectangles written to academy_art.json.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from pixelkit import C, Canvas, mix, shade, shift
import paint_world as pw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "art" / "world"

WALL = C("2b2850")
WALL_HI = C("3d3a6b")
WALL_LO = C("1f1c3f")
WAINSCOT = C("242146")
CAP = C("403d70")
CAP_HI = C("5b5890")
EDGE = C("12112a")
FLOOR = C("4b4d76")
FLOOR_LINE = C("414369")
FLOOR_HI = C("575a84")
PATH = C("a97c58")
PATH_HI = C("c4946a")
PATH_LO = C("86603f")
CORAL = C("c8584a")
CORAL_HI = C("e37a62")
CORAL_LO = C("963d3a")
WOOD = C("7a5a44")
WOOD_HI = C("9c7758")
VIOLET = C("b79dff")
VIOLET_LO = C("6a55a8")
FACE_H = 74
CAP_T = 10


def potted_plant(cv: Canvas, x, y, w=18, d=12):
    """A leafy plant in a pot standing against the wall; the leaves rise above the footprint."""
    cx = x + w // 2
    cv.rect(x + 2, y + d, w - 2, 2, EDGE, 0.3)
    for dx, dy, r in [(-5, -14, 5), (4, -17, 6), (0, -24, 5), (-6, -6, 4), (6, -7, 4), (1, -11, 6)]:
        cv.ellipse(cx + dx, y + dy, r, r * 0.8, pw.GREEN_DK)
    for dx, dy, r in [(-4, -15, 3.2), (4, -18, 4), (0, -24, 3), (2, -11, 4), (-6, -7, 2.4), (6, -8, 2.4)]:
        cv.ellipse(cx + dx, y + dy, r, r * 0.75, pw.GREEN_LO)
    for dx, dy in [(-4, -16), (5, -19), (0, -25), (2, -12)]:
        cv.rect(cx + dx, y + dy, 2, 1, pw.GREEN)
    cv.rect(x + 3, y - 2, w - 6, d, EDGE)
    cv.rect(x + 4, y - 1, w - 8, d - 2, C("b06a45"))
    cv.rect(x + 4, y - 1, w - 8, 2, C("d28c5f"))
    cv.rect(x + 4, y + d - 5, w - 8, 2, C("8a4f35"))


def monitor(cv: Canvas, x, y, w, h, tint):
    cv.rect(x - 2, y - 2, w + 4, h + 4, EDGE)
    cv.rect(x - 1, y - 1, w + 2, h + 2, pw.STEEL_LO)
    cv.rect(x, y, w, h, C("0e1a30"))
    cv.hline(x, y, w, shade(tint, 0.55))
    for yy in range(y + 3, y + h, 3):
        cv.hline(x + 1, yy, w - 2, C("13233c"))


def sconce(cv: Canvas, x, y, tint=pw.AMBER):
    cv.rect(x - 3, y, 7, 3, EDGE)
    cv.rect(x - 2, y + 1, 5, 1, tint)
    cv.rect(x - 1, y + 3, 3, 4, pw.STEEL_LO)
    pw.glow(cv, x, y + 10, 22, tint, 0.28)


def paint_academy(preview: bool):
    L = pw.scaled(pw.read_layout(ROOT / "scripts" / "academy" / "academy_layout.gd"))
    W, H = L["MAP"]
    fx, fy, fw, fh = L["FLOOR"]
    rng = np.random.default_rng(1969)
    cv = Canvas(W, H, EDGE)
    art: dict = {}
    xs, ys = cv.grid()

    # --- shell -----------------------------------------------------------------
    cv.rect(0, 0, W, H, CAP)
    cv.rect(0, 0, W, 1, CAP_HI)
    cv.rect(0, 0, 1, H, CAP_HI)
    for x in range(0, W, 32):
        cv.vline(x + 15, 1, CAP_T - 1, shade(CAP, 0.8))
        cv.vline(x + 15, fy + fh + 1, H - fy - fh - 1, shade(CAP, 0.8))
    for y in range(0, H, 32):
        cv.hline(1, y + 15, fx - 1, shade(CAP, 0.8))
        cv.hline(fx + fw, y + 15, W - fx - fw - 1, shade(CAP, 0.8))
    cv.frame(0, 0, W, H, EDGE)

    # Back wall: upper panels, a rail, then darker wainscot down to the skirting.
    top = fy - FACE_H
    cv.rect(fx, top, fw, FACE_H, WALL)
    cv.rect(fx, top, fw, 2, WALL_HI)
    cv.rect(fx, fy - 22, fw, 22, WAINSCOT)
    cv.hline(fx, fy - 23, fw, WALL_HI)
    cv.hline(fx, fy - 22, fw, WALL_LO)
    cv.rect(fx, fy - 3, fw, 3, EDGE)
    for x in range(fx + 30, fx + fw, 62):
        cv.vline(x, top + 2, FACE_H - 25, WALL_LO)
        cv.vline(x + 1, top + 2, FACE_H - 25, shade(WALL, 1.1))
    for x in range(fx + 14, fx + fw, 31):
        cv.vline(x, fy - 20, 16, WALL_LO)
    cv.vline(fx - 1, top, FACE_H, EDGE)
    cv.vline(fx + fw, top, FACE_H, EDGE)

    # --- floor -------------------------------------------------------------------
    cv.rect(fx, fy, fw, fh, FLOOR)
    for ty in range(fy, fy + fh, 24):
        for tx in range(fx, fx + fw, 24):
            r = rng.random()
            if r < 0.12:
                cv.rect(tx, ty, min(24, fx + fw - tx), min(24, fy + fh - ty), mix(FLOOR, FLOOR_HI, 0.5))
            elif r > 0.9:
                cv.rect(tx, ty, min(24, fx + fw - tx), min(24, fy + fh - ty), mix(FLOOR, FLOOR_LINE, 0.6))
    # Each wing gets a faint colour of its own.
    cv.rect(fx, fy, 238, 156, VIOLET_LO, 0.1)
    cv.rect(450, fy, fx + fw - 450, 156, pw.TEAL_LO, 0.1)
    cv.rect(fx, 292, 238, fy + fh - 292, pw.GREEN_LO, 0.1)
    for tx in range(fx, fx + fw, 24):
        cv.vline(tx, fy, fh, FLOOR_LINE)
        cv.vline(tx + 1, fy, fh, FLOOR_HI, 0.3)
    for ty in range(fy, fy + fh, 24):
        cv.hline(fx, ty, fw, FLOOR_LINE)
        cv.hline(fx, ty + 1, fw, FLOOR_HI, 0.3)

    # Warm walkways: one across the hall, one up to the window, and a plaza round the holo table.
    hx, hy, hw, hh = L["HOLO_TABLE"]
    plaza = (hx + hw / 2, hy + hh / 2 + 2)
    walk = cv.rect_mask(fx, 240, fw, 48) | cv.rect_mask(356, fy, 56, 156) | cv.rect_mask(356, 288, 56, 56)
    walk |= cv.ellipse_mask(plaza[0], plaza[1], 70, 44)
    walk &= cv.rect_mask(fx, fy, fw, fh)
    cv.fill(walk, PATH)
    grain = rng.random((H, W))
    cv.fill(walk & (grain < 0.06), PATH_HI)
    cv.fill(walk & (grain > 0.95), PATH_LO)
    cv.fill(walk & ((xs + ys * 2) % 48 == 0), PATH_LO)
    rim = walk & (shift(~walk, 1, 0) | shift(~walk, -1, 0) | shift(~walk, 0, 1) | shift(~walk, 0, -1))
    cv.fill(rim, PATH_LO)
    inner = walk & ~rim & (shift(rim, 1, 0) | shift(rim, -1, 0) | shift(rim, 0, 1) | shift(rim, 0, -1))
    cv.fill(inner, pw.AMBER_LO)
    cv.fill(inner & ((xs + ys) % 12 < 2), pw.AMBER)
    ring = cv.ellipse_mask(plaza[0], plaza[1], 52, 31) & ~cv.ellipse_mask(plaza[0], plaza[1], 50, 29.5)
    cv.fill(ring, PATH_LO)

    # Shadow of the back wall on the floor, and soft edges along the sides.
    for k, f in [(0, 0.62), (1, 0.72), (2, 0.82), (3, 0.9), (4, 0.95)]:
        cv.scale_rgb(cv.rect_mask(fx, fy + k, fw, 1), f)
    cv.scale_rgb(cv.rect_mask(fx, fy, 2, fh), 0.8)
    cv.scale_rgb(cv.rect_mask(fx + fw - 2, fy, 2, fh), 0.86)
    cv.scale_rgb(cv.rect_mask(fx, fy + fh - 2, fw, 2), 0.86)

    # --- west wing: space-weather desk ---------------------------------------------
    dx, dy, dw, dd = L["WEATHER_DESK"]
    art["monitors"] = []
    for i in range(3):
        mx = dx + 6 + i * 40
        monitor(cv, mx, top + 22, 32, 24, VIOLET)
        art["monitors"].append([mx, top + 22, 32, 24])
    cv.rect(dx - 1, dy - 8, dw + 2, dd + 9, EDGE)
    cv.rect(dx, dy - 7, dw, 7, C("6a5f8f"))                               # desk top (seen from above)
    cv.hline(dx, dy - 7, dw, C("8a7fb4"))
    cv.rect(dx, dy, dw, dd - 4, C("4a4270"))
    cv.rect(dx, dy + dd - 4, dw, 3, C("342e55"))
    for i in range(3):                                                    # keyboards and a mug
        cv.rect(dx + 10 + i * 40, dy - 5, 20, 3, EDGE)
        cv.rect(dx + 11 + i * 40, dy - 4, 18, 1, VIOLET_LO)
    cv.rect(dx + dw - 12, dy - 6, 5, 4, C("e9eef7"))
    for i in range(4):
        cv.rect(dx + 8 + i * 30, dy + 4, 22, 8, C("3d3661"))
        cv.px(dx + 26 + i * 30, dy + 8, VIOLET)
    art["desk_sign"] = [dx + 6, top + 8]
    # Pennant with a crescent moon.
    cv.rect(22, top + 6, 20, 44, EDGE)
    cv.rect(23, top + 7, 18, 42, C("31407a"))
    for k in range(8):                                                    # swallow-tail cut at the bottom
        cv.hline(32 - k, top + 49 - k, 2 * k, WALL)
    cv.rect(23, top + 7, 18, 3, pw.AMBER)
    cv.ellipse(32, top + 24, 6, 6, pw.AMBER)
    cv.ellipse(34.5, top + 22.5, 5, 5, C("31407a"))
    for k in range(3):
        cv.px(27 + k * 4, top + 36, pw.AMBER)
    # Server rack with a row of status lights (the game blinks them).
    sx, sy, sw, sd = L["SERVER_RACK"]
    cv.rect(sx - 1, sy - 36, sw + 2, sd + 37, EDGE)
    cv.rect(sx, sy - 35, sw, 4, pw.STEEL_HI)
    cv.rect(sx, sy - 31, sw, sd + 28, C("3b3f63"))
    art["rack_leds"] = []
    for row in range(5):
        cv.rect(sx + 3, sy - 27 + row * 8, sw - 6, 5, EDGE)
        for col in range(4):
            art["rack_leds"].append([sx + 6 + col * 7, sy - 25 + row * 8])
    cv.rect(sx, sy + sd - 3, sw, 3, C("2a2d4a"))

    # --- centre: mission board, window, plants -----------------------------------
    bx, by, bw, bh = L["BOARD"]
    cv.rect(bx - 3, by - 3, bw + 6, bh + 6, EDGE)
    cv.rect(bx - 2, by - 2, bw + 4, bh + 4, pw.AMBER_LO)
    cv.rect(bx - 2, by - 2, bw + 4, 1, pw.AMBER)
    cv.rect(bx, by, bw, bh, C("252a52"))
    cv.ellipse(bx + 28, by + 26, 21, 21, C("8a8aa4"))                     # the Moon map
    cv.ellipse(bx + 28, by + 26, 20, 20, C("9e9eb6"))
    for mx, my, r in [(-8, -7, 4), (6, 3, 5), (-3, 9, 3), (9, -9, 2.5), (-12, 4, 2)]:
        cv.ellipse(bx + 28 + mx, by + 26 + my, r, r, C("7c7c96"))
    for px_, py_ in [(22, 40), (30, 43), (36, 39)]:                       # pins near the south pole
        cv.rect(bx + px_, by + py_, 2, 2, pw.RED)
    cv.line(bx + 23, by + 41, bx + 37, by + 40, pw.AMBER)
    for i, (px_, py_) in enumerate([(54, 6), (54, 28)]):                  # two photographs
        cv.rect(bx + px_, by + py_, 16, 18, C("e9eef7"))
        cv.rect(bx + px_ + 2, by + py_ + 2, 12, 10, C("31407a") if i == 0 else C("3f9a4d"))
        cv.rect(bx + px_ + 4, by + py_ + 7, 8, 5, C("9e9eb6") if i == 0 else C("7ddc6f"))
        cv.px(bx + px_ + 8, by + py_, pw.RED)
    art["board"] = [bx, by, bw, bh]
    # Big round window.
    wx, wy = L["WINDOW_CENTER"]
    cv.ellipse(wx, wy, 34, 31, EDGE)
    cv.ellipse(wx, wy, 33, 30, pw.STEEL)
    cv.ellipse(wx, wy - 1, 32, 29, pw.STEEL_HI)
    cv.ellipse(wx, wy, 31, 28, pw.STEEL_LO)
    cv.ellipse(wx, wy, 28, 25, EDGE)
    glass = cv.ellipse_mask(wx, wy, 27, 24)
    cv.fill(glass, C("060a1a"))
    for _ in range(26):
        sxp, syp = int(wx - 27 + rng.integers(0, 54)), int(wy - 24 + rng.integers(0, 34))
        if glass[syp, sxp]:
            cv.px(sxp, syp, mix(C("5a6690"), C("ffffff"), float(rng.random())))
    cv.fill(glass & cv.ellipse_mask(wx + 12, wy - 9, 6, 6), C("2f74c0"))   # Earth
    cv.fill(glass & cv.ellipse_mask(wx + 10, wy - 10, 2.5, 2), C("4cab7a"))
    cv.fill(glass & cv.ellipse_mask(wx + 14, wy - 7, 3, 1), C("e6f2fb"))
    cv.fill(glass & cv.ellipse_mask(wx - 6, wy + 44, 60, 34), C("8a8aa4"))  # the Moon's limb below
    cv.fill(glass & cv.ellipse_mask(wx - 6, wy + 46, 60, 34), C("77778f"))
    for mx, my, r in [(-12, 16, 5), (8, 19, 3), (-2, 22, 2)]:
        cv.fill(glass & cv.ellipse_mask(wx + mx, wy + my, r, r * 0.5), C("5c5c76"))
    art["window"] = [wx, wy, 27, 24]
    for k in range(8):                                                    # frame bolts
        ang = k * np.pi / 4 + 0.39
        cv.px(int(wx + np.cos(ang) * 30.5), int(wy + np.sin(ang) * 27.5), pw.STEEL_HI)
    for name in ("PLANTER_WEST", "PLANTER_EAST"):
        potted_plant(cv, *L[name])
    sconce(cv, 252, top + 10)
    sconce(cv, 438, top + 10)

    # --- east wing: power lab and the lander dock -------------------------------------
    rx, ry, rw, rd = L["BATTERY_RACK"]
    cv.rect(rx - 1, ry - 40, rw + 2, rd + 41, EDGE)
    cv.rect(rx, ry - 39, rw, 4, pw.STEEL_HI)
    cv.rect(rx, ry - 35, rw, rd + 32, pw.STEEL_LO)
    art["academy_cells"] = []
    for row in range(2):
        for col in range(3):
            cx0, cy0 = rx + 4 + col * 17, ry - 31 + row * 21
            cv.rect(cx0, cy0, 14, 17, EDGE)
            cv.rect(cx0 + 1, cy0 + 1, 12, 15, pw.TEAL_LO)
            cv.rect(cx0 + 1, cy0 + 1, 12, 4, pw.TEAL)
            cv.vline(cx0 + 2, cy0 + 6, 9, C("9af3e8"))
            cv.rect(cx0 + 5, cy0 - 2, 4, 2, pw.STEEL)
            art["academy_cells"].append([cx0 + 1, cy0 + 1, 12, 15])
    cv.rect(rx, ry + rd - 3, rw, 3, C("3a3f62"))
    pw.bolt_icon(cv, rx + rw + 12, top + 24, pw.AMBER)
    cx, cy, cw, cd = L["TRAINING_CONSOLE"]
    monitor(cv, cx + 6, top + 12, cw - 12, 34, pw.TEAL)
    art["training_screen"] = [cx + 6, top + 12, cw - 12, 34]
    cv.rect(cx - 1, cy - 8, cw + 2, cd + 9, EDGE)
    cv.rect(cx, cy - 7, cw, 7, pw.STEEL_HI)
    cv.rect(cx, cy, cw, cd - 4, pw.STEEL)
    cv.rect(cx, cy + cd - 4, cw, 3, pw.STEEL_LO)
    for i in range(8):
        cv.rect(cx + 6 + i * 9, cy - 5, 5, 3, pw.AMBER if i % 3 else pw.TEAL)
    cv.rect(cx + 5, cy + 3, cw - 10, 8, EDGE)
    for i in range(12):
        cv.rect(cx + 7 + i * 6, cy + 5, 4, 4, pw.TEAL_LO if i % 2 else pw.AMBER_LO)
    art["training_console"] = [cx, cy, cw, cd]
    sconce(cv, 654, top + 10, pw.TEAL)
    # Lander dock: a heavy door with a porthole. The lamp above it is drawn by the game.
    hx_, hy_, hw_, hh_ = L["HATCH_DOOR"]
    cv.rect(hx_ - 6, hy_ - 6, hw_ + 12, hh_ + 6, EDGE)
    cv.rect(hx_ - 5, hy_ - 5, hw_ + 10, hh_ + 5, pw.STEEL_LO)
    pw.hazard(cv, hx_ - 5, hy_ - 5, hw_ + 10, 5, pw.AMBER, EDGE, 4)
    pw.hazard(cv, hx_ - 5, hy_, 5, hh_, pw.AMBER, EDGE, 4)
    pw.hazard(cv, hx_ + hw_, hy_, 5, hh_, pw.AMBER, EDGE, 4)
    cv.rect(hx_, hy_, hw_, hh_, EDGE)
    cv.rect(hx_ + 1, hy_ + 1, hw_ - 2, hh_ - 1, C("59608a"))
    cv.rect(hx_ + 1, hy_ + 1, hw_ - 2, 2, C("8a92bd"))
    cv.vline(hx_ + hw_ // 2 - 1, hy_ + 1, hh_ - 1, EDGE)
    cv.vline(hx_ + hw_ // 2, hy_ + 1, hh_ - 1, C("3d4268"))
    for side in (0, 1):
        ox = hx_ + 6 + side * (hw_ // 2)
        cv.rect(ox, hy_ + 8, hw_ // 2 - 12, 18, EDGE)
        cv.rect(ox + 1, hy_ + 9, hw_ // 2 - 14, 16, C("0b1226"))
        cv.px(ox + 3, hy_ + 12, C("ffffff"))
        cv.px(ox + 9, hy_ + 18, C("9fd8ff"))
        cv.rect(ox, hy_ + 34, hw_ // 2 - 12, 20, C("4a5078"))
        cv.frame(ox, hy_ + 34, hw_ // 2 - 12, 20, C("3d4268"))
    art["hatch_lamp"] = [hx_ + hw_ // 2 - 5, hy_ - 12, 10, 4]
    cv.rect(hx_ + hw_ // 2 - 7, hy_ - 14, 14, 8, EDGE)
    pw.hazard(cv, hx_ - 8, fy, hw_ + 16, 4, pw.AMBER, EDGE, 4)
    cv.frame(hx_ - 8, fy + 4, hw_ + 16, 26, pw.AMBER_LO)

    # --- holo table ------------------------------------------------------------------
    tcx, tcy = hx + hw / 2, hy + hh / 2
    cv.ellipse(tcx + 2, tcy + 4, 33, 18, EDGE, 0.35)
    cv.ellipse(tcx, tcy + 3, 32, 17, EDGE)
    cv.ellipse(tcx, tcy + 2, 31, 16, pw.STEEL_LO)
    cv.ellipse(tcx, tcy, 31, 16, EDGE)
    cv.ellipse(tcx, tcy, 30, 15, pw.STEEL)
    cv.ellipse(tcx, tcy - 1, 29, 14, pw.STEEL_HI)
    cv.ellipse(tcx, tcy, 25, 11.5, EDGE)
    cv.ellipse(tcx, tcy, 24, 10.5, C("123a4a"))
    cv.ellipse(tcx, tcy, 18, 7.5, C("1a5a66"))
    for k in range(12):
        ang = k * np.pi / 6
        cv.px(int(tcx + np.cos(ang) * 27), int(tcy + np.sin(ang) * 13), pw.AMBER)
    art["holo"] = [int(tcx), int(tcy)]

    # --- plant lab ------------------------------------------------------------------
    px_, py_, pw_, pd_ = L["PLANT_BENCH"]
    cv.rect(px_ + 2, py_ + pd_, pw_, 2, EDGE, 0.3)
    cv.rect(px_, py_, pw_, pd_, EDGE)
    cv.rect(px_ + 1, py_ + 1, pw_ - 2, pd_ - 2, pw.STEEL_LO)
    cv.rect(px_ + 1, py_ + 1, pw_ - 2, 2, pw.STEEL)
    cv.rect(px_ + 3, py_ + 4, pw_ - 6, pd_ - 12, pw.SOIL)
    for i in range(9):
        pw.plant(cv, px_ + 4 + i * 12, py_ + 3, i % 4, rng)
    cv.rect(px_ + 1, py_ + pd_ - 8, pw_ - 2, 7, pw.STEEL)
    cv.hline(px_ + 1, py_ + pd_ - 8, pw_ - 2, pw.STEEL_HI)
    cv.rect(px_ + 6, py_ + pd_ - 5, pw_ - 12, 2, EDGE)
    art["plant_bench"] = [px_, py_, pw_, pd_]
    art["plant_lamp"] = [px_ + 3, py_ + 2, pw_ - 6, 1]
    # Seed cabinet and watering cans beside the west wall.
    pw.crate(cv, fx + 4, 380, 22, 20, C("5f668e"), pw.GREEN)
    pw.crate(cv, fx + 22, 388, 16, 12, pw.STEEL_LO, pw.GREEN)

    # --- crew lounge -----------------------------------------------------------------
    rug = (286, 338, 196, 70)
    cv.rect(*rug, CORAL_LO)
    cv.rect(rug[0] + 2, rug[1] + 2, rug[2] - 4, rug[3] - 4, C("7f3a44"))
    cv.frame(rug[0] + 5, rug[1] + 5, rug[2] - 10, rug[3] - 10, pw.AMBER_LO)
    for k in range(rug[0] + 12, rug[0] + rug[2] - 12, 12):
        cv.px(k, rug[1] + 8, pw.AMBER_LO)
        cv.px(k, rug[1] + rug[3] - 9, pw.AMBER_LO)
    for name, facing in (("SOFA_WEST", 1), ("SOFA_EAST", -1)):
        sx_, sy_, sw_, sd_ = L[name]
        cv.rect(sx_ + 2, sy_ + sd_, sw_, 2, EDGE, 0.3)
        cv.rect(sx_, sy_, sw_, sd_, EDGE)
        cv.rect(sx_ + 1, sy_ + 1, sw_ - 2, sd_ - 2, CORAL)
        back_x = sx_ + 1 if facing == 1 else sx_ + sw_ - 9
        cv.rect(back_x, sy_ + 1, 8, sd_ - 2, CORAL_LO)                    # back rest
        cv.vline(back_x + (7 if facing == 1 else 0), sy_ + 1, sd_ - 2, shade(CORAL_LO, 0.8))
        for k in range(1, 3):
            cv.hline(sx_ + 1, sy_ + k * sd_ // 3, sw_ - 2, CORAL_LO)
        cv.rect(sx_ + 1, sy_ + 1, sw_ - 2, 3, CORAL_HI)
        cv.rect(sx_ + 1, sy_ + sd_ - 6, sw_ - 2, 5, CORAL_LO)
        seat_x = sx_ + 11 if facing == 1 else sx_ + 4
        cv.rect(seat_x, sy_ + 8, 9, 9, C("e9c46a"))                       # cushion
        cv.frame(seat_x, sy_ + 8, 9, 9, C("b8923f"))
    tx, ty, tw, td = L["LOUNGE_TABLE"]
    cv.rect(tx + 2, ty + td, tw, 2, EDGE, 0.3)
    cv.rect(tx, ty, tw, td, EDGE)
    cv.rect(tx + 1, ty + 1, tw - 2, td - 2, WOOD)
    cv.rect(tx + 1, ty + 1, tw - 2, 2, WOOD_HI)
    cv.rect(tx + 1, ty + td - 5, tw - 2, 4, C("5d4434"))
    cv.rect(tx + 6, ty + 5, 5, 5, C("e9eef7"))
    cv.rect(tx + 7, ty + 6, 3, 3, C("6b4a3a"))
    cv.rect(tx + 18, ty + 5, 12, 8, EDGE)
    cv.rect(tx + 19, ty + 6, 10, 6, pw.TEAL_LO)
    cv.rect(tx + 34, ty + 8, 5, 5, C("e9eef7"))
    # Entrance mat at the south wall.
    cv.rect(352, fy + fh - 12, 64, 12, C("3a3d62"))
    pw.hazard(cv, 352, fy + fh - 3, 64, 3, pw.AMBER_LO, EDGE, 4)
    cv.rect(350, fy + fh, 68, H - fy - fh - 1, EDGE)
    cv.rect(352, fy + fh + 1, 31, H - fy - fh - 3, C("59608a"))
    cv.rect(385, fy + fh + 1, 31, H - fy - fh - 3, C("59608a"))
    cv.hline(352, fy + fh + 1, 64, C("8a92bd"))

    # --- suit lockers -----------------------------------------------------------------
    lx, ly, lw, ld = L["LOCKERS"]
    cv.rect(lx + 2, ly + ld, lw, 2, EDGE, 0.3)
    cv.rect(lx - 1, ly - 20, lw + 2, ld + 21, EDGE)
    cv.rect(lx, ly - 19, lw, 5, pw.STEEL_HI)
    cv.rect(lx, ly - 14, lw, ld + 11, pw.STEEL)
    for i in range(4):
        ox = lx + 2 + i * 24
        cv.rect(ox, ly - 12, 20, ld + 6, EDGE)
        cv.rect(ox + 1, ly - 11, 18, ld + 4, C("2a3050"))
        cv.ellipse(ox + 10, ly - 4, 6, 5.5, C("e9eef7"))                  # helmet
        cv.ellipse(ox + 10, ly - 3, 4, 3, C("2f5f8a"))
        cv.rect(ox + 4, ly + 3, 12, ld - 12, [C("e37a40"), C("5f8fe0"), C("e9c46a"), C("6fc77a")][i])   # folded suit
        cv.rect(ox + 4, ly + 3, 12, 2, C("e9eef7"))
    cv.rect(lx, ly + ld - 3, lw, 3, pw.STEEL_LO)

    # --- pools of light ------------------------------------------------------------------
    floor_mask = cv.rect_mask(fx, fy, fw, fh)
    for lx_, tint in ((252, pw.AMBER), (438, pw.AMBER), (654, pw.TEAL), (118, VIOLET)):
        cv.fill(floor_mask & cv.ellipse_mask(lx_, fy + 10, 44, 26), tint, 0.05)
        cv.fill(floor_mask & cv.ellipse_mask(lx_, fy + 6, 26, 14), tint, 0.06)
    cv.fill(floor_mask & cv.ellipse_mask(384, 372, 96, 44), pw.AMBER, 0.04)

    cv.save(OUT / "academy_bg.png")
    (OUT / "academy_art.json").write_text(json.dumps(art, indent="\t", sort_keys=True) + "\n")
    if preview:
        cv.save("/tmp/academy_bg_2x.png", 2)
    return cv
