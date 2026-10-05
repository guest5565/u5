"""INKWING world -> src/Workspace/World.model.json
Mostly sky: small floating paper islands (cardboard layers underneath), clouds, a cloud sea, and the
dark Ink Depths below with the Blot King's throne. Keep coordinates in sync with Shared/Game.lua."""
import json, math, random, sys, os
sys.path.insert(0, os.path.expanduser("~/Inkbound/tools"))
sys.path.insert(0, os.path.expanduser("~/DoodlePets/tools"))
import gen_map as g
import mapkit as mk
from gen_map import part, model, folder, rot_y, rot_z, mul, I3
rot_x = g.rot_x
CYL_UP = mk.CYL_UP
rnd = random.Random(7)
random.seed(7)

def F(c): return [float(v) for v in c]
def P(name, size, pos, col, **kw): return part(name, size, pos, F(col), **kw)
def D(name, size, pos, col, **kw):
    kw.setdefault("collide", False)
    return P(name, size, pos, col, **kw)
def label(text, col=(1, 1, 1), size=(18, 4), dist=160):
    return {"name": "Label", "className": "BillboardGui", "properties": {"Size": {"UDim2": [[0, int(size[0] * 14)], [0, int(size[1] * 14)]]}, "MaxDistance": float(dist), "LightInfluence": 0.0},
            "children": [{"name": "T", "className": "TextLabel", "properties": {"Text": text, "TextScaled": True, "Font": "FredokaOne", "BackgroundTransparency": 1.0,
                          "TextColor3": F(col), "TextStrokeTransparency": 0.0, "Size": {"UDim2": [[1, 0], [1, 0]]}}}]}
def light(color, rng=16, b=1.2):
    return {"name": "Light", "className": "PointLight", "properties": {"Color": F(color), "Range": float(rng), "Brightness": float(b)}}

INK = (0.16, 0.17, 0.3)
PAPER = (0.98, 0.96, 0.9)
CARD = [(0.86, 0.72, 0.52), (0.78, 0.63, 0.44), (0.7, 0.55, 0.38)]
DARK_TOP = (0.2, 0.2, 0.32)
DARK_CARD = [(0.14, 0.13, 0.22), (0.11, 0.1, 0.18), (0.09, 0.08, 0.15)]

def island(name, x, top, z, r, dark=False, rules=True, props=0):
    """a round paper island: paper top + ink outline + tapering cardboard layers + drips"""
    ch = []
    ch.append(P("Top", [1.2, r * 2, r * 2], [x, top - 0.6, z], DARK_TOP if dark else PAPER, rot=CYL_UP, shape="Cylinder"))
    ch.append(P("Rim", [0.9, r * 2 + 1.4, r * 2 + 1.4], [x, top - 1.55, z], INK if not dark else (0.45, 0.2, 0.6), rot=CYL_UP, shape="Cylinder",
                mat="Neon" if dark else "SmoothPlastic"))
    layers = 4 if r > 10 else 3
    y = top - 2.0
    for k in range(layers):
        h = 2.2 + k * 0.6
        rr = r * (0.94 - 0.2 * k)
        ch.append(P("Layer", [h, rr * 2, rr * 2], [x + rnd.uniform(-0.6, 0.6), y - h / 2, z + rnd.uniform(-0.6, 0.6)],
                    (DARK_CARD if dark else CARD)[k % 3], rot=mul(rot_y(rnd.uniform(0, 3)), CYL_UP), shape="Cylinder"))
        y -= h
    ch.append(P("Tip", [r * 0.5, r * 0.5, r * 0.5], [x, y - r * 0.1, z], (DARK_CARD if dark else CARD)[2], shape="Ball"))
    for k in range(int(r // 3)):  # ink drips hanging off the rim
        a = rnd.uniform(0, math.tau)
        L = rnd.uniform(1.5, 4.5)
        ch.append(D("Drip", [0.6, L, 0.6], [x + math.cos(a) * (r + 0.3), top - 2 - L / 2, z + math.sin(a) * (r + 0.3)], INK if not dark else (0.5, 0.25, 0.7)))
    if rules and not dark:
        for k in range(-int(r // 4), int(r // 4) + 1):
            zz = z + k * 4
            half = math.sqrt(max(0, (r - 2) ** 2 - (k * 4) ** 2))
            if half > 2:
                ch.append(D("Rule", [half * 2, 0.04, 0.22], [x, top + 0.02, zz], (0.62, 0.74, 0.92)))
    for _ in range(props):
        a, d = rnd.uniform(0, math.tau), rnd.uniform(r * 0.3, r * 0.8)
        px, pz = x + math.cos(a) * d, z + math.sin(a) * d
        kind = rnd.choice(["crane", "books", "pin", "note"])
        if kind == "crane": ch.append(mk.crane("Crane", px, top, pz, rnd))
        elif kind == "books": ch.append(mk.book_stack("Books", px, top, pz, rnd))
        elif kind == "pin": ch.append(mk.pushpin("Pin", px, top, pz, rnd))
        else: ch.append(mk.sticky_note("Note", px, top, pz, rnd))
    return model(name, ch)


# ======== v1.3 NATURE ISLANDS (real floating islands: lobed grass tops, dirt, cliffs, big trees, water) ========
GRASS = [(0.36, 0.62, 0.25), (0.33, 0.58, 0.23), (0.4, 0.66, 0.28)]
SANDP = [(0.93, 0.85, 0.62), (0.9, 0.82, 0.58), (0.95, 0.88, 0.66)]
DIRT = (0.52, 0.34, 0.2)
NROCK = [(0.45, 0.42, 0.4), (0.38, 0.35, 0.34), (0.52, 0.48, 0.45)]
NLEAF = [(0.22, 0.5, 0.2), (0.28, 0.58, 0.22), (0.18, 0.42, 0.17), (0.35, 0.62, 0.25), (0.3, 0.52, 0.16)]
G_CLEAR = [(0, 300, 34), (0, 380, 18), (14, 350, 14), (8, 364, 10)]  # genesis: shrine, spawn, mentor, sign
OAKS = []
def g_oak(ch, x, y, z, s):
    h = 10 * s
    OAKS.append((x, y, z, s))
    ch.append(P("Trunk", [h * 0.6, 2.6 * s, 2.6 * s], [x, y + h * 0.3, z], (0.4, 0.27, 0.16), rot=CYL_UP, shape="Cylinder", mat="Wood"))
    ch.append(P("Trunk", [h * 0.55, 1.8 * s, 1.8 * s], [x, y + h * 0.75, z], (0.42, 0.28, 0.17), rot=CYL_UP, shape="Cylinder", mat="Wood"))
    for k in range(4):  # roots
        a_ = k / 4 * math.tau + 0.4
        ch.append(P("Root", [3.4 * s, 0.9 * s, 0.9 * s], [x + math.cos(a_) * 1.6 * s, y + 0.3 * s, z + math.sin(a_) * 1.6 * s], (0.38, 0.25, 0.15), rot=mul(rot_y(-a_), rot_z(-0.35)), mat="Wood"))
    for k in range(3):  # branches
        a_ = k / 3 * math.tau + rnd.uniform(0, 1)
        L = 5 * s
        ch.append(P("Branch", [L, 0.9 * s, 0.9 * s], [x + math.cos(a_) * L * 0.4, y + h * 0.85 + L * 0.25, z + math.sin(a_) * L * 0.4], (0.4, 0.27, 0.16), rot=mul(rot_y(-a_), rot_z(0.55)), mat="Wood"))
    n = 9
    for i in range(n):  # canopy: a dome of clustered leaf balls
        a_ = i / n * math.tau + rnd.uniform(-0.3, 0.3)
        ring = 0 if i == 0 else (3.6 * s if i < 6 else 2 * s)
        yy = y + h + (2.6 * s if i == 0 else (rnd.uniform(-0.5, 1) * s if i < 6 else 3.2 * s))
        bs = rnd.uniform(6, 8.5) * s
        ch.append(P("Leaves", [bs, bs, bs], [x + math.cos(a_) * ring, yy, z + math.sin(a_) * ring], NLEAF[rnd.randrange(5)], shape="Ball", mat="Grass"))
def g_pine(ch, x, y, z, s):
    h = 18 * s
    ch.append(P("Trunk", [h, 1.4 * s, 1.4 * s], [x, y + h / 2, z], (0.34, 0.23, 0.14), rot=CYL_UP, shape="Cylinder", mat="Wood"))
    tiers = 6
    for i in range(tiers):  # tiered cones from stacked, shrinking discs
        w = (9 - i * 1.3) * s
        ch.append(P("Needles", [2.6 * s, w, w], [x, y + 4 * s + i * 2.4 * s, z], (0.13, 0.34 + (i % 2) * 0.04, 0.2), rot=mul(rot_y(i * 0.5), CYL_UP), shape="Cylinder", mat="Grass"))
        ch.append(P("Needles", [1.4 * s, w * 0.75, w * 0.75], [x, y + 5.6 * s + i * 2.4 * s, z], (0.11, 0.3, 0.18), rot=CYL_UP, shape="Cylinder", mat="Grass"))
    ch.append(P("PineTip", [2 * s, 2 * s, 2 * s], [x, y + 4 * s + tiers * 2.4 * s, z], (0.12, 0.32, 0.19), shape="Ball", mat="Grass"))
def g_palm(ch, x, y, z, s):
    h = 14 * s
    for i in range(5):  # a curved trunk in segments
        ch.append(P("PalmTrunk", [h / 5 + 0.3, 1.3 * s, 1.3 * s], [x + i * 0.5 * s, y + h / 10 + i * h / 5, z], (0.62, 0.48, 0.3), rot=mul(rot_z(math.pi / 2 - 0.08 * i), I3), shape="Cylinder", mat="Wood"))
    tx, ty = x + 2.5 * s, y + h
    for k in range(7):
        a_ = k / 7 * math.tau
        ch.append(P("Frond", [8 * s, 0.4, 2.2 * s], [tx + math.cos(a_) * 3.6 * s, ty - 0.8 * s, z + math.sin(a_) * 3.6 * s], (0.25, 0.55, 0.2), rot=mul(rot_y(-a_), rot_z(-0.35)), mat="Grass"))
def g_ancient(ch, x, y, z, s=5):
    """a giant world-tree landmark"""
    g_oak(ch, x, y, z, s)
    for k in range(6):
        a_ = k / 6 * math.tau
        ch.append(P("Leaves", [7 * s, 7 * s, 7 * s], [x + math.cos(a_) * 5 * s, y + 10 * s + rnd.uniform(-1, 1) * s, z + math.sin(a_) * 5 * s], NLEAF[k % 5], shape="Ball", mat="Grass"))
# ======== v1.8 helpers: segments between points, yaw-local placement ========
def rot_from_x(d):
    L = math.sqrt(d[0] ** 2 + d[1] ** 2 + d[2] ** 2) or 1
    x = [d[0] / L, d[1] / L, d[2] / L]
    up = [0, 1, 0] if abs(x[1]) < 0.95 else [1, 0, 0]
    z = [x[1] * up[2] - x[2] * up[1], x[2] * up[0] - x[0] * up[2], x[0] * up[1] - x[1] * up[0]]
    zl = math.sqrt(sum(c * c for c in z)) or 1
    z = [c / zl for c in z]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
    return [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]]
def seg(name, a, b, d, col, mat="Slate", shape="Cylinder", collide=True, **kw):
    v = [b[0] - a[0], b[1] - a[1], b[2] - a[2]]
    L = math.sqrt(sum(c * c for c in v))
    mid = [(a[k] + b[k]) / 2 for k in range(3)]
    if shape == "Block":
        return P(name, [L, d, d], mid, col, rot=rot_from_x(v), mat=mat, collide=collide, **kw)
    return P(name, [L, d, d], mid, col, rot=rot_from_x(v), shape="Cylinder", mat=mat, collide=collide, **kw)
def yawpt(cx, cy, cz, yaw):
    c_, s_ = math.cos(yaw), math.sin(yaw)
    return lambda lx, ly, lz: [cx + lx * c_ + lz * s_, cy + ly, cz - lx * s_ + lz * c_]
def g_island(name, x, top, z, r, trees=6, sand=False, lobes=4, avoid=None, water=False, ancient=False, lite=False):
    ch = []
    top_c = SANDP if sand else GRASS
    blobs = [(x, z, r)]
    for i in range(lobes):  # irregular outline: overlapping lobes around the rim
        a_ = i / lobes * math.tau + rnd.uniform(-0.4, 0.4)
        if avoid is not None and abs((a_ - avoid + math.pi) % math.tau - math.pi) < 0.8:
            continue
        lr = r * rnd.uniform(0.38, 0.55)
        d_ = r * rnd.uniform(0.62, 0.8)
        blobs.append((x + math.cos(a_) * d_, z + math.sin(a_) * d_, lr))
    for bi, (bx, bz, br) in enumerate(blobs):
        tt = top + (0 if bi == 0 else -0.08 * bi)  # tiny steps so tops never z-fight
        ch.append(P("Grass", [2, br * 2, br * 2], [bx, tt - 1, bz], top_c[bi % 3], rot=CYL_UP, shape="Cylinder", mat="Sand" if sand else "Grass"))
        ch.append(P("Dirt", [6, br * 2 - 1, br * 2 - 1], [bx, tt - 5, bz], (0.86, 0.75, 0.5) if sand else DIRT, rot=CYL_UP, shape="Cylinder", mat="Sandstone" if sand else "Ground"))
        y, rr, k = tt - 8, br * 0.96, 0
        # v1.8c: varied undersides - spike / roots / crystal / chunky boulders
        if bi == 0:
            style = rnd.choice(["spike", "roots", "crystal", "chunky", "spike", "roots"]) if not sand else "spike"
        shrink = {"spike": 0.7, "roots": 0.62, "crystal": 0.66, "chunky": 0.55}[style]
        while rr > 3:  # rocky underside tapering down
            hh = max(4, br * (0.22 if style != "chunky" else 0.3))
            ch.append(P("Rock", [hh, rr * 2, rr * 2], [bx + rnd.uniform(-1.5, 1.5), y - hh / 2, bz + rnd.uniform(-1.5, 1.5)], NROCK[k % 3], rot=mul(rot_y(rnd.uniform(0, 3)), CYL_UP), shape="Cylinder", mat="Slate"))
            y -= hh * 0.85
            rr *= shrink
            k += 1
        if bi == 0:
            nU = max(4, min(14, int(br / 6)))
            for i in range(nU):
                a_ = i / nU * math.tau + rnd.uniform(-0.2, 0.2)
                d_ = br * rnd.uniform(0.35, 0.8)
                ux, uz = bx + math.cos(a_) * d_, bz + math.sin(a_) * d_
                if style == "roots":  # gnarled roots hanging out of the dirt
                    L = br * rnd.uniform(0.5, 1.1)
                    ux2, uz2 = bx + math.cos(a_) * d_ * 1.15, bz + math.sin(a_) * d_ * 1.15
                    ch.append(seg("HangRoot", [ux, tt - 7, uz], [ux2, tt - 7 - L * 0.55, uz2], max(0.8, br * 0.05), (0.33, 0.23, 0.15), mat="Wood", collide=False))
                    ch.append(seg("HangRoot", [ux2, tt - 7 - L * 0.55, uz2], [ux2 + rnd.uniform(-3, 3), tt - 7 - L, uz2 + rnd.uniform(-3, 3)], max(0.5, br * 0.03), (0.38, 0.27, 0.17), mat="Wood", collide=False))
                    if i % 2 == 0:
                        ch.append(D("RootMoss", [max(1, br * 0.07)] * 3, [ux2, tt - 7 - L * 0.55, uz2], NLEAF[i % 5], shape="Ball", mat="Grass"))
                elif style == "crystal":  # glowing crystals growing out of the rock
                    cs = br * rnd.uniform(0.08, 0.16)
                    cy = tt - 10 - br * rnd.uniform(0.1, 0.5) * (1 - d_ / br)
                    col = [(0.55, 0.85, 1), (0.75, 0.6, 1), (0.6, 1, 0.85)][(i + int(x)) % 3]
                    ch.append(D("UnderCrystal", [cs * 0.6, cs * 2.4, cs * 0.6], [ux, cy - cs, uz], col, rot=mul(rot_y(a_), rot_z(rnd.uniform(-0.5, 0.5))), mat="Neon", transparency=0.15))
                elif style == "chunky":  # big boulders clustered under the rim
                    bs = br * rnd.uniform(0.18, 0.32)
                    ch.append(P("UnderBoulder", [bs, bs * 0.8, bs], [ux, tt - 9 - bs * 0.4 - (1 - d_ / br) * br * 0.3, uz], NROCK[i % 3], shape="Ball", mat="Slate", collide=False))
                elif i % 2 == 0:  # spike: a few long hanging vines
                    L = br * rnd.uniform(0.2, 0.5)
                    ch.append(D("Vine", [0.6, L, 0.6], [bx + math.cos(a_) * (br - 0.4), tt - 3 - L / 2, bz + math.sin(a_) * (br - 0.4)], NLEAF[i % 5], mat="Grass"))
        for i in range(3 if lite else max(3, int(br / 5))):  # cliffs + stalactites under the rim
            a_ = rnd.uniform(0, math.tau)
            d_ = rnd.uniform(0.6, 0.92) * br
            sz = rnd.uniform(4, 10) * max(1, br / 50)
            ch.append(P("Crag", [sz, sz * 2.2, sz], [bx + math.cos(a_) * d_, tt - 9 - sz, bz + math.sin(a_) * d_], NROCK[i % 3], rot=mul(rot_y(a_), rot_z(rnd.uniform(-0.25, 0.25))), mat="Slate"))
        for i in range(0 if lite else int(br / 8)):  # hanging moss / roots off the dirt edge
            a_ = rnd.uniform(0, math.tau)
            L = rnd.uniform(3, 9)
            ch.append(D("Vine", [0.5, L, 0.5], [bx + math.cos(a_) * (br - 0.3), tt - 3 - L / 2, bz + math.sin(a_) * (br - 0.3)], NLEAF[i % 5], mat="Grass"))
    def free(px, pz):
        return any(math.hypot(px - bx, pz - bz) < br * 0.85 for bx, bz, br in blobs) and not any(math.hypot(px - cx_, pz - cz_) < cr_ for cx_, cz_, cr_ in G_CLEAR)
    placed = 0
    tries = 0
    while placed < trees and tries < trees * 6:
        tries += 1
        bx, bz, br = blobs[rnd.randrange(len(blobs))]
        a_ = rnd.uniform(0, math.tau)
        px, pz = bx + math.cos(a_) * rnd.uniform(0.15, 0.8) * br, bz + math.sin(a_) * rnd.uniform(0.15, 0.8) * br
        if not free(px, pz):
            continue
        placed += 1
        ts = min(1.0, max(0.45, r / 40))  # small rocks get small trees
        if sand:
            g_palm(ch, px, top, pz, rnd.uniform(0.9, 1.3) * ts)
        elif rnd.random() < 0.55:
            g_oak(ch, px, top, pz, rnd.uniform(1.3, 2.4) * ts)
        else:
            g_pine(ch, px, top, pz, rnd.uniform(1.1, 2.0) * ts)
    for i in range(0 if lite else int(r * 0.6)):  # bushes, mossy stones, flowers, grass tufts
        bx, bz, br = blobs[rnd.randrange(len(blobs))]
        a_ = rnd.uniform(0, math.tau)
        px, pz = bx + math.cos(a_) * rnd.uniform(0, 0.9) * br, bz + math.sin(a_) * rnd.uniform(0, 0.9) * br
        if not free(px, pz):
            continue
        t_ = i % 4
        if t_ == 0 and not sand:
            bs = rnd.uniform(3, 6)
            ch.append(P("Bush", [bs, bs * 0.8, bs], [px, top + bs * 0.3, pz], NLEAF[i % 5], shape="Ball", mat="Grass"))
        elif t_ == 1:
            rs = rnd.uniform(2, 6)
            ch.append(P("Stone", [rs, rs * 0.6, rs * 0.8], [px, top + rs * 0.2, pz], NROCK[i % 3], rot=rot_y(a_), mat="Slate"))
            ch.append(D("Moss", [rs * 0.8, 0.3, rs * 0.6], [px, top + rs * 0.5 + 0.05, pz], NLEAF[i % 5], rot=rot_y(a_), mat="Grass"))
        elif t_ == 2 and not sand:
            for f in range(6):
                fx_, fz_ = px + rnd.uniform(-2.5, 2.5), pz + rnd.uniform(-2.5, 2.5)
                ch.append(D("Stem", [0.15, 1.1, 0.15], [fx_, top + 0.55, fz_], (0.25, 0.5, 0.2)))
                ch.append(D("Flower", [0.8, 0.8, 0.8], [fx_, top + 1.2, fz_], [(1, 0.85, 0.3), (0.95, 0.45, 0.55), (0.75, 0.6, 1), (1, 1, 1)][f % 4], shape="Ball"))
        else:
            for f in range(4):
                ch.append(D("Tuft", [0.4, 1.4, 1.2], [px + rnd.uniform(-1.5, 1.5), top + 0.6, pz + rnd.uniform(-1.5, 1.5)], NLEAF[f % 5], rot=rot_y(rnd.uniform(0, 3)), mat="Grass", cls="WedgePart"))
    # v1.8c: break up the flat tops - grassy mounds, mossy boulders and bush clusters (cheap, also on lite isles)
    nT = int(r * (0.12 if lite else 0.08)) + 2
    for i in range(nT):
        bx, bz, br = blobs[rnd.randrange(len(blobs))]
        a_ = rnd.uniform(0, math.tau)
        px, pz = bx + math.cos(a_) * rnd.uniform(0.1, 0.75) * br, bz + math.sin(a_) * rnd.uniform(0.1, 0.75) * br
        if not free(px, pz):
            continue
        t_ = i % 3
        if t_ == 0 and not sand:
            ms = min(r * 0.4, rnd.uniform(10, 26))
            ch.append(P("Mound", [ms, ms * 0.35, ms * 0.9], [px, top - ms * 0.06, pz], top_c[i % 3], rot=rot_y(a_), shape="Ball", mat="Grass"))
        elif t_ == 1:
            rs = min(r * 0.2, rnd.uniform(4, 9))
            ch.append(P("Boulder", [rs, rs * 0.75, rs * 0.9], [px, top + rs * 0.2, pz], NROCK[i % 3], rot=rot_y(a_), shape="Ball", mat="Slate"))
            ch.append(D("BoulderMoss", [rs * 0.7, rs * 0.25, rs * 0.6], [px, top + rs * 0.55, pz], NLEAF[i % 5], rot=rot_y(a_), shape="Ball", mat="Grass"))
        elif not sand:
            for b in range(3):
                bs = rnd.uniform(3, 6)
                ch.append(D("Bush", [bs, bs * 0.8, bs], [px + rnd.uniform(-4, 4), top + bs * 0.3, pz + rnd.uniform(-4, 4)], NLEAF[(i + b) % 5], shape="Ball", mat="Grass"))
            for f in range(3):
                ch.append(D("Flower", [1, 1, 1], [px + rnd.uniform(-5, 5), top + 0.7, pz + rnd.uniform(-5, 5)], [(1, 0.85, 0.3), (0.95, 0.45, 0.55), (0.75, 0.6, 1)][f], shape="Ball"))
    if water:  # a pond, a stream to the edge and a waterfall pouring off into the sky
        wx, wz = x - r * 0.45, z + r * 0.15
        WATER = (0.35, 0.6, 0.85)
        ch.append(D("Pond", [0.4, r * 0.36, r * 0.36], [wx, top + 0.05, wz], WATER, rot=CYL_UP, shape="Cylinder", mat="Glass", transparency=0.25))
        ch.append(P("PondRim", [0.8, r * 0.4, r * 0.4], [wx, top - 0.2, wz], NROCK[0], rot=CYL_UP, shape="Cylinder", mat="Slate"))
        L = r * 0.6
        ch.append(D("Stream", [L, 0.3, 4], [wx - L / 2, top + 0.06, wz], WATER, mat="Glass", transparency=0.25))
        ex = x - r - 1.5
        ch.append(D("Waterfall", [1.2, 60, 6], [ex, top - 30, wz], (0.75, 0.88, 1), mat="Glass", transparency=0.35))
        ch.append(D("FallMist", [8, 8, 8], [ex, top - 62, wz], (1, 1, 1), shape="Ball", transparency=0.7))
        for i in range(8):
            a_ = i / 8 * math.tau
            ch.append(P("PondStone", [2.2, 1.4, 2], [wx + math.cos(a_) * r * 0.2, top + 0.3, wz + math.sin(a_) * r * 0.2], NROCK[i % 3], rot=rot_y(a_), mat="Slate"))
    if ancient:
        g_ancient(ch, x + r * 0.35, top, z - r * 0.35, 4.5)
    return model(name, ch)
def nat_isle(name, x, top, z, r, **kw):
    """overworld isle at 1.6x the old paper radius"""
    R = r * 1.6
    return g_island(name, x, top, z, R, trees=kw.pop("trees", max(2, int(R / 6))), lobes=kw.pop("lobes", 3), **kw)

def pencil(name, x, y, z, length, rot, col=(0.98, 0.8, 0.25), r=0.9):
    ax = [rot[0][0], rot[1][0], rot[2][0]]
    at = lambda d: [x + ax[0] * d, y + ax[1] * d, z + ax[2] * d]
    return [P(name + "Body", [length, r * 2, r * 2], [x, y, z], col, rot=rot, shape="Cylinder", collide=False),
            P(name + "Eraser", [r * 1.6, r * 2, r * 2], at(length / 2 + r * 0.8), (1, 0.6, 0.65), rot=rot, shape="Cylinder", collide=False),
            P(name + "Band", [r * 0.5, r * 2.1, r * 2.1], at(length / 2), (0.75, 0.75, 0.8), rot=rot, shape="Cylinder", mat="Metal", collide=False),
            P(name + "Wood", [r * 1.6, r * 1.5, r * 1.5], at(-length / 2 - r * 0.6), (0.95, 0.82, 0.62), rot=rot, shape="Cylinder", collide=False),
            P(name + "Lead", [r * 0.9, r * 0.6, r * 0.6], at(-length / 2 - r * 1.7), INK, rot=rot, shape="Cylinder", collide=False)]

islands, deco, clouds, depths = [], [], [], []

# ---- QUILL'S REST (hub, spawn)
islands.append(nat_isle("Hub", 0, 100, 0, 26, water=False))
# Quill, the old paper-folder NPC
qx, qz = -10, 4
# v1.8: Quill himself is built + animated by NPCs.client (NPCModel "quill"), standing on the ground at the anchor
deco.append(model("QuillNPC", [D("QuillAnchor", [0.2, 0.2, 0.2], [qx, 102.5, qz], (1, 1, 1), transparency=1, children=[label("QUILL", (1, 0.9, 0.5), (8, 2), 80)])]))
# JUMP sign at the edge facing the blob isle
deco.append(model("JumpSign", [P("Post", [0.5, 6, 0.5], [6, 103, -22], (0.55, 0.38, 0.24), mat="Wood"),
                               P("Board", [8, 3, 0.4], [6, 105.5, -22], (1, 0.85, 0.35), mat="Wood",
                                 children=[label("JUMP OFF TO FLY!", (1, 1, 1), (14, 3), 120)])]))
spawn = {"name": "Spawn", "className": "SpawnLocation", "properties": {"Anchored": True, "Size": [8.0, 1.0, 8.0], "Color": [1.0, 0.85, 0.45], "Duration": 0,
         "Neutral": True, "TopSurface": "Smooth", "CFrame": {"CFrame": {"position": [0.0, 100.5, 8.0], "orientation": [[1, 0, 0], [0, 1, 0], [0, 0, 1]]}}, "Transparency": 0.0}}

# ---- SKY ISLES
islands.append(nat_isle("BlobIsle", -10, 82, -90, 16))
islands.append(nat_isle("BlobIsle2", 70, 92, -40, 11))
islands.append(nat_isle("BatPeak", -110, 140, -60, 13))
islands.append(nat_isle("WaspNestIsle", 120, 170, -150, 15))
islands.append(nat_isle("Lookout", 0, 230, -210, 8))
for (x, y, z, r) in [(-60, 120, 40, 6), (60, 130, 60, 5), (-170, 110, -150, 7), (180, 140, -40, 6), (40, 200, -100, 5), (-60, 190, -170, 6), (150, 110, 60, 5)]:
    islands.append(nat_isle("Rock", x, y, z, r, trees=2, lobes=2))
# the wasp nest: a paper lantern hive
wx, wy, wz = 120, 170, -150
nest = [P("Hive", [9, 9, 9], [wx, wy + 6, wz], (0.92, 0.8, 0.45), shape="Ball")]
for k in range(5):
    nest.append(D("HiveBand", [0.5, 9.6 - abs(k - 2) * 1.6, 9.6 - abs(k - 2) * 1.6], [wx, wy + 3 + k * 1.5, wz], (0.55, 0.4, 0.2), rot=CYL_UP, shape="Cylinder"))
nest.append(D("HiveHole", [1, 2.6, 2.6], [wx, wy + 5, wz + 4.4], INK, rot=rot_y(math.pi / 2), shape="Cylinder"))
deco.append(model("WaspNest", nest))
# giant floating pencils + paper planes (sky landmarks)
# (v1.8: the floating sky pencils were removed - they read as random sticks in the sky)
for k in range(6):
    x, y, z = rnd.uniform(-180, 180), rnd.uniform(120, 240), rnd.uniform(-220, 80)
    a = rnd.uniform(0, math.tau)
    deco.append(model("PaperPlane", [P("WingL", [0.2, 3, 6], [x - 1.4, y, z], (1, 1, 1), cls="WedgePart", rot=mul(rot_y(a), rot_z(0.25)), collide=False),
                                     P("WingR", [0.2, 3, 6], [x + 1.4, y, z], (1, 1, 1), cls="WedgePart", rot=mul(rot_y(a), rot_z(-0.25)), collide=False)]))
# ---- CLOUDS (soft, few). A handful of puffy white clouds near the isles, a layered translucent cloud
# sea far below and a grey cloud deck above (the doorway to the storm). Layers = big thin discs.
def puff_cloud(name, x, y, z, sc, col=(1, 1, 1), tr=0.05, dark=0):
    """an invisible anchor; CloudFX.client fills it with soft particle cloud (no ball clouds)"""
    p = D(name, [sc * 26, sc * 7, sc * 12], [x, y, z], col, transparency=1.0)
    p.setdefault("properties", {})["CanQuery"] = False
    p["attributes"] = {"Cloud": float(sc), "Dark": float(dark)}
    return p
for _ in range(16):
    while True:
        x, y, z = rnd.uniform(-240, 240), rnd.uniform(40, 240), rnd.uniform(-300, 140)
        if (x ** 2 + z ** 2) > 60 ** 2: break
    clouds.append(puff_cloud("Cloud", x, y, z, rnd.uniform(0.8, 1.6)))
def layer(name, y, d, col, tr):
    return D(name, [2.0, d, d], [0, y, -60], col, rot=CYL_UP, shape="Cylinder", transparency=tr, mat="SmoothPlastic")
# v1.8b: the flat CloudSea / CloudDeck plates are gone - storm + sea are hidden client-side (Storm.client)

# ---- THE STORM (y 620-850): dark slate islands among the tornados
def storm_isle(name, x, top, z, r):
    m = island(name, x, top, z, r, props=0, rules=False)
    for c in m["children"]:
        pr = c.get("properties", {})
        if c.get("name") == "Top": pr["Color"] = [0.55, 0.57, 0.66]
        if c.get("name") == "Layer": pr["Color"] = [v * 0.55 for v in pr["Color"]]
    # a lightning rod (giant pencil) on every storm isle
    m["children"] += pencil("Rod", x + r * 0.3, top + 9, z, 18, rot_z(math.pi / 2), col=(0.55, 0.6, 0.75), r=0.6)
    return m
for (x, y, z, r) in [(-90, 2290, -120, 14), (130, 2360, -220, 15), (20, 2240, -60, 10), (-160, 2400, -260, 9), (200, 2300, 40, 9), (-20, 2460, -330, 12)]:
    islands.append(storm_isle("StormIsle", x, y, z, r))
for _ in range(20):
    x, y, z = rnd.uniform(-300, 300), rnd.uniform(2200, 2600), rnd.uniform(-420, 200)
    clouds.append(puff_cloud("StormCloud", x, y, z, rnd.uniform(1.4, 2.6), (0.32, 0.33, 0.42), 0.1, dark=1))


# ---- THE INK DEPTHS (dark floating ink rocks, glowing crystals)
for k in range(24):
    x, y, z = rnd.uniform(-200, 200), rnd.uniform(-3320, -2830), rnd.uniform(-300, 160)
    if (x - 0) ** 2 + (z + 100) ** 2 < 80 ** 2 and y < -3220: continue
    depths.append(island("InkRock", x, y, z, rnd.uniform(5, 12), dark=True))
    for c in range(3):
        cx, cz = x + rnd.uniform(-4, 4), z + rnd.uniform(-4, 4)
        h = rnd.uniform(2, 5)
        depths.append(P("Crystal", [1.2, h, 1.2], [cx, y + h / 2 - 0.3, cz], (0.6, 0.3, 1), mat="Neon", rot=mul(rot_y(rnd.uniform(0, 3)), rot_z(rnd.uniform(-0.3, 0.3))),
                        collide=False, children=[light((0.6, 0.35, 1), 14, 1)] if c == 0 else None))
# the Blot King's throne
bx, by, bz = 0, -1501, -100  # the throne sits on the sea floor of the Ink Sea now
throne = [island("ThroneIsle", bx, by, bz, 36, dark=True)]
tch = []
for k in range(12):
    a = k * math.tau / 12
    tch.append(P("Spike", [2.5, 9, 2.5], [bx + math.cos(a) * 33, by + 4, bz + math.sin(a) * 33], (0.1, 0.08, 0.16), rot=mul(rot_y(-a), rot_z(0.25)), cls="WedgePart"))
for k in range(24):
    a = k * math.tau / 24
    tch.append(D("Rune", [0.2, 3.6, 1.2], [bx + math.cos(a) * 26, by + 0.1, bz + math.sin(a) * 26], (0.9, 0.15, 0.3), mat="Neon", rot=mul(rot_y(-a), rot_z(math.pi / 2))))
for k in range(5):
    a = k * math.tau / 5 + 0.3
    h = rnd.uniform(8, 18)
    tch.append(P("Pillar", [3.5, h, 3.5], [bx + math.cos(a) * 20, by + h / 2, bz + math.sin(a) * 20], (0.18, 0.16, 0.26)))
tch.append(D("ThroneGlow", [1, 1, 1], [bx, by + 6, bz], (0.9, 0.2, 0.35), mat="Neon", shape="Ball", transparency=0.6, children=[light((1, 0.25, 0.4), 60, 2)]))
throne.append(model("ThroneDeco", tch))
sea_throne = throne

storm = [c for c in islands if c.get("name") == "StormIsle"] + [c for c in clouds if c.get("name") in ("StormCloud", "StormTop")]
islands = [c for c in islands if c.get("name") != "StormIsle"]
clouds = [c for c in clouds if c.get("name") not in ("StormCloud", "StormTop")]
# THE INK SEA: an ink ocean far below the isles (surface y -700). Streamed in when you dive.
SEA = -700
ocean = [D("SeaSurface", [1.5, 2040, 2040], [0, SEA, -60], (0.1, 0.17, 0.42), rot=CYL_UP, shape="Cylinder", transparency=0.15),
         D("SeaShine", [0.3, 2040, 2040], [0, SEA + 1.2, -60], (0.35, 0.5, 0.9), rot=CYL_UP, shape="Cylinder", transparency=0.7, mat="Glass")]
ocean += sea_throne
# sunken / drifting things in the sea (story bits): paper boats, a giant pencil, books sinking
for (x, y, z, kind) in [(-120, -900, -60, "boat"), (90, -1300, -200, "pencil"), (-40, -1700, 80, "boat"), (160, -2000, 20, "books"), (-200, -2200, -250, "pencil")]:
    if kind == "boat":
        ocean.append(model("SunkenBoat", [D("Hull", [3, 8, 22], [x, y, z], (0.95, 0.94, 0.88), cls="WedgePart", rot=rot_z(math.pi)),
                                          D("Sail", [0.4, 12, 9], [x, y + 8, z], (0.95, 0.94, 0.88), cls="WedgePart"),
                                          D("Mast", [0.6, 10, 0.6], [x, y + 5, z], (0.55, 0.38, 0.24))]))
    elif kind == "pencil":
        ocean.append(model("SunkenPencil", pencil("P", x, y, z, 60, mul(rot_y(1.1), rot_z(0.7)), r=3)))
    else:
        ocean.append(model("SinkingBooks", [D("Book", [8, 2, 11], [x + k * 2, y + k * 6, z - k], [(0.8, 0.25, 0.3), (0.25, 0.45, 0.8), (0.3, 0.65, 0.4)][k % 3],
                                              rot=mul(rot_y(k * 0.7), rot_z(0.3 * k))) for k in range(4)]))

def look_rot(d):
    """rotation matrix whose local Z axis points along d"""
    L = math.sqrt(sum(v * v for v in d)); z = [v / L for v in d]
    up = [0, 1, 0] if abs(z[1]) < 0.95 else [1, 0, 0]
    x = [up[1] * z[2] - up[2] * z[1], up[2] * z[0] - up[0] * z[2], up[0] * z[1] - up[1] * z[0]]
    Lx = math.sqrt(sum(v * v for v in x)); x = [v / Lx for v in x]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
    return [[x[0], y[0], z[0]], [x[1], y[1], z[1]], [x[2], y[2], z[2]]]
def beam(name, a, b, w, col, mat="Neon", tr=0.0):
    d = [b[i] - a[i] for i in range(3)]
    L = math.sqrt(sum(v * v for v in d))
    return D(name, [w, w, L], [(a[i] + b[i]) / 2 for i in range(3)], col, rot=look_rot(d), mat=mat, transparency=tr)
def recolor(m, top=None, layer=None, rim=None, tip=None):
    for c in m["children"]:
        pr = c.setdefault("properties", {})
        n = c.get("name")
        if n == "Top" and top: pr["Color"] = F(top)
        if n == "Layer" and layer: pr["Color"] = F(layer)
        if n == "Rim" and rim: pr["Color"] = F(rim); pr["Material"] = "Neon"
        if n == "Tip" and (tip or layer): pr["Color"] = F(tip or layer)
        if n == "Drip" and rim: pr["Color"] = F(rim)
    return m

# ---- THE DRIFTWOOD ISLES: paper islands floating on the ink sea surface
SAND = (0.97, 0.9, 0.72)
def sea_isle(name, x, z, r):
    m = g_island(name, x, SEA + 5, z, r, trees=max(2, int(r / 6)), sand=True, lobes=3)
    for k in range(int(r * 0.8)):  # white foam blobs around the shore
        a = k / int(r * 0.8) * math.tau
        m["children"].append(D("Foam", [rnd.uniform(3, 6), 0.3, rnd.uniform(2, 3)], [x + math.cos(a) * (r + 1.5), SEA + 1.0, z + math.sin(a) * (r + 1.5)], (1, 1, 1), rot=rot_y(-a)))
    return m
seaisles = []
lx, lz = -260, -200
m = sea_isle("LighthouseIsle", lx, lz, 30)
for k in range(7):  # a striped paper lighthouse
    m["children"].append(P("Tower", [7, 9 - k * 0.4, 9 - k * 0.4], [lx, SEA + 5 + 3.5 + k * 7, lz], (0.92, 0.25, 0.3) if k % 2 == 0 else (0.98, 0.96, 0.9), rot=CYL_UP, shape="Cylinder"))
m["children"].append(D("Lamp", [6, 6, 6], [lx, SEA + 5 + 53, lz], (1, 0.9, 0.5), mat="Neon", shape="Ball", transparency=0.1, children=[light((1, 0.85, 0.5), 60, 3), label("THE LAST LIGHTHOUSE", (1, 0.9, 0.6), dist=500)]))
m["children"].append(P("Cap", [4, 8, 8], [lx, SEA + 5 + 58, lz], INK, cls="WedgePart"))
seaisles.append(m)
wx, wz = 220, 120
m = sea_isle("WreckIsle", wx, wz, 24)
m["children"] += [P("Hull", [8, 14, 46], [wx + 4, SEA + 9, wz], (0.55, 0.38, 0.24), cls="WedgePart", rot=mul(rot_y(0.5), rot_z(math.pi + 0.35))),
                  P("Mast", [1.6, 34, 1.6], [wx + 2, SEA + 22, wz - 4], (0.45, 0.3, 0.2), rot=rot_z(0.5)),
                  D("TornSail", [0.4, 16, 12], [wx - 4, SEA + 26, wz - 4], (0.95, 0.94, 0.88), cls="WedgePart", rot=rot_z(0.5))]
seaisles.append(m)
ix, iz = 40, -420
m = sea_isle("InkwellIsle", ix, iz, 20)
m["children"] += [P("Inkwell", [16, 18, 18], [ix, SEA + 13, iz], (0.12, 0.13, 0.25), rot=CYL_UP, shape="Cylinder"),
                  P("Neck", [5, 9, 9], [ix, SEA + 23.5, iz], (0.12, 0.13, 0.25), rot=CYL_UP, shape="Cylinder"),
                  D("InkPool", [0.3, 7.6, 7.6], [ix, SEA + 26.2, iz], (0.2, 0.4, 1), mat="Neon", rot=CYL_UP, shape="Cylinder"),
                  P("Quill", [1.2, 40, 1.2], [ix + 3, SEA + 40, iz], (0.98, 0.96, 0.9), rot=rot_z(0.35))]
seaisles.append(m)
dx_, dz_ = -80, 300
m = sea_isle("DriftwoodIsle", dx_, dz_, 16)
for k in range(6):
    m["children"].append(P("Plank", [12, 1, 2.4], [dx_ + rnd.uniform(-8, 8), SEA + 5.6 + k * 0.05, dz_ + rnd.uniform(-8, 8)], (0.6, 0.45, 0.3), rot=rot_y(rnd.uniform(0, 3))))
m["children"].append(P("Bottle", [2.4, 6, 2.4], [dx_ + 3, SEA + 7, dz_ - 2], (0.5, 0.9, 0.7), rot=rot_z(math.pi / 2 - 0.3), shape="Cylinder", mat="Glass", transparency=0.3))
seaisles.append(m)
seaisles.append(sea_isle("KrakenRock", 300, -350, 10))
ocean += seaisles

# ---- THE COSMOS (4300-5100): moon isles, paper planets, constellations
cosmos = []
MOON, MOON2 = (0.84, 0.85, 0.92), (0.45, 0.45, 0.58)
for (x, y, z, r) in [(0, 4450, 60, 16), (-90, 4540, -120, 22), (130, 4680, -40, 20), (-200, 4750, -300, 12), (210, 4880, -250, 14), (-60, 4980, 140, 10)]:
    m = recolor(island("MoonIsle", x, y, z, r, rules=False), top=MOON, layer=MOON2, rim=(0.6, 0.5, 1))
    for k in range(int(r // 4)):
        a, dd = rnd.uniform(0, math.tau), rnd.uniform(0, r * 0.6)
        cr = rnd.uniform(2, 4.5)
        m["children"].append(D("Crater", [0.12, cr * 2, cr * 2], [x + math.cos(a) * dd, y + 0.06, z + math.sin(a) * dd], (0.68, 0.69, 0.78), rot=CYL_UP, shape="Cylinder"))
    cosmos.append(m)
# the Comet Eater's orbit: a ring of floating rocks
for k in range(16):
    a = k / 16 * math.tau
    s_ = rnd.uniform(4, 9)
    cosmos.append(P("OrbitRock", [s_, s_ * 0.8, s_], [math.cos(a) * 85, 4880 + rnd.uniform(-10, 10), -260 + math.sin(a) * 85], MOON2, rot=mul(rot_y(a), rot_z(rnd.uniform(0, 1)))))
for (x, y, z, d, col, ringed) in [(-650, 4900, -750, 240, (0.55, 0.35, 0.9), True), (720, 4500, -300, 170, (1, 0.6, 0.35), False), (300, 5250, 800, 130, (0.3, 0.8, 0.8), True), (-450, 4250, 520, 90, (0.9, 0.9, 0.95), False)]:
    ch = [D("Planet", [d, d, d], [x, y, z], col, shape="Ball", collide=False),
          D("Band", [d * 0.12, d * 1.01, d * 1.01], [x, y + d * 0.1, z], [c * 0.75 for c in col], rot=CYL_UP, shape="Cylinder")]
    if ringed:
        ch.append(D("Ring", [0.8, d * 1.9, d * 1.9], [x, y, z], (0.95, 0.9, 0.7), rot=mul(rot_z(0.3), CYL_UP), shape="Cylinder", transparency=0.35))
    cosmos.append(model("PaperPlanet", ch))
# constellations: a bird, a quill, a crown (neon stars joined by lines)
def constellation(name, center, pts, edges, scale):
    ch = []
    P3 = [[center[0] + p[0] * scale, center[1] + p[1] * scale, center[2]] for p in pts]
    for q in P3: ch.append(D("Star", [4, 4, 4], q, (1, 0.95, 0.7), mat="Neon", shape="Ball"))
    for (i, j) in edges: ch.append(beam("Line", P3[i], P3[j], 0.6, (0.75, 0.75, 1), tr=0.35))
    return model(name, ch)
cosmos.append(constellation("Bird", [-250, 4800, -650], [(0, 0), (-3, 1), (-6, 3), (3, 1), (6, 3), (0, -2), (-1, -4), (1, -4)], [(0, 1), (1, 2), (0, 3), (3, 4), (0, 5), (5, 6), (5, 7)], 18))
cosmos.append(constellation("Quill", [350, 4700, -600], [(0, -5), (0, 0), (1, 3), (2, 6), (-1, 3), (-0.5, 6)], [(0, 1), (1, 2), (2, 3), (1, 4), (4, 5), (3, 5)], 20))
cosmos.append(constellation("Crown", [0, 5000, -700], [(-4, 0), (4, 0), (-4, 3), (-2, 1.5), (0, 4), (2, 1.5), (4, 3)], [(0, 1), (0, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 1)], 16))
for k in range(70):  # big paper stars all around
    a, b = rnd.uniform(0, math.tau), rnd.uniform(-0.5, 0.9)
    R = rnd.uniform(350, 800)
    d = rnd.uniform(1.5, 4)
    cosmos.append(D("FarStar", [d, d, d], [math.cos(a) * math.cos(b) * R, 4700 + math.sin(b) * R, -60 + math.sin(a) * math.cos(b) * R], (1, 0.96, 0.8), mat="Neon", shape="Ball"))

# ---- HEAVEN (6600-7300): white and gold cloud isles, a golden gate, the Halo Warden's arena
heaven = []
WHITE, IVORY, GOLD = (1, 1, 1), (0.96, 0.93, 0.85), (1, 0.82, 0.35)
for (x, y, z, r) in [(0, 6700, 40, 24), (-100, 6740, -100, 22), (120, 6800, -40, 20), (-220, 6860, 120, 12), (200, 6920, 160, 12)]:
    m = recolor(island("CloudIsle", x, y, z, r, rules=False), top=WHITE, layer=IVORY, rim=GOLD)
    heaven.append(m)
    for k in range(3):
        heaven.append(puff_cloud("HeavenCloud", x + rnd.uniform(-r, r), y - 10 - k * 6, z + rnd.uniform(-r, r), r / 10))
gx, gy, gz = 0, 6700, 40
gate = []
for sd in (-1, 1):
    gate.append(P("GatePillar", [30, 5, 5], [gx + sd * 12, gy + 15, gz - 10], IVORY, rot=CYL_UP, shape="Cylinder"))
    gate.append(P("PillarCap", [2, 7, 7], [gx + sd * 12, gy + 31, gz - 10], GOLD, rot=CYL_UP, shape="Cylinder", mat="Neon"))
gate.append(P("Arch", [30, 3, 4], [gx, gy + 33.5, gz - 10], GOLD, children=[label("HEAVEN'S GATE", (1, 0.85, 0.4), dist=500)]))
for k in range(9):
    a = math.pi * k / 8
    gate.append(D("ArchHalo", [1, 1, 4], [gx + math.cos(a) * 10, gy + 36 + math.sin(a) * 6, gz - 10], GOLD, mat="Neon"))
heaven.append(model("GoldenGate", gate))
# the arena
ax, ay, az = 0, 6990, -280
m = recolor(island("WardenArena", ax, ay, az, 44, rules=False), top=IVORY, layer=WHITE, rim=GOLD)
for k in range(10):
    a = k / 10 * math.tau
    h = rnd.uniform(14, 28) if k % 3 else 6  # some columns broken
    m["children"].append(P("Column", [h, 4.5, 4.5], [ax + math.cos(a) * 38, ay + h / 2, az + math.sin(a) * 38], IVORY, rot=CYL_UP, shape="Cylinder"))
    m["children"].append(D("InkCrack", [0.2, 1.4, rnd.uniform(6, 14)], [ax + math.cos(a) * 20, ay + 0.1, az + math.sin(a) * 20], (0.12, 0.1, 0.2), rot=rot_y(-a)))
heaven.append(m)
for (x, y, z, R) in [(-300, 7100, -500, 40), (350, 6900, -450, 30), (0, 7250, 300, 50)]:
    for k in range(24):  # giant floating halos
        a = k / 24 * math.tau
        heaven.append(D("SkyHalo", [3, 3, R * math.tau / 24 * 1.05], [x + math.cos(a) * R, y, z + math.sin(a) * R], GOLD, mat="Neon", rot=rot_y(-a), transparency=0.2))
for k in range(30):
    heaven.append(puff_cloud("HeavenCloud", rnd.uniform(-400, 400), rnd.uniform(6550, 7200), rnd.uniform(-500, 400), rnd.uniform(1.6, 3.2)))
# ======================= v0.4 =======================
# ---- HEAVEN, fleshed out (refs: a cloud city with domes, towers, gates, angel statues, a rainbow, waterfalls)
PINK, PEACH, MARBLE = (1, 0.82, 0.86), (1, 0.88, 0.75), (0.97, 0.95, 0.92)
def dome_building(x, y, z, w, h, col=MARBLE):
    ch = [P("Hall", [w, h, w], [x, y + h / 2, z], col),
          P("Drum", [h * 0.3, w * 0.8, w * 0.8], [x, y + h + h * 0.15, z], col, rot=CYL_UP, shape="Cylinder"),
          P("Dome", [w * 0.8, w * 0.8, w * 0.8], [x, y + h + h * 0.3, z], (1, 0.86, 0.5), shape="Ball"),
          P("Spire", [1, w * 0.5, 1], [x, y + h + h * 0.3 + w * 0.55, z], (1, 0.82, 0.35), mat="Neon")]
    for k in range(4):
        a = k * math.pi / 2
        ch.append(D("Window", [0.2, h * 0.5, w * 0.18], [x + math.cos(a) * (w / 2 + 0.1), y + h * 0.55, z + math.sin(a) * (w / 2 + 0.1)], (0.55, 0.75, 1), mat="Neon", rot=rot_y(-a)))
    return model("DomeHall", ch)
def tower(x, y, z, w, h):
    return model("Tower", [P("Shaft", [h, w, w], [x, y + h / 2, z], MARBLE, rot=CYL_UP, shape="Cylinder"),
                           P("Ring", [1, w * 1.25, w * 1.25], [x, y + h, z], (1, 0.82, 0.35), rot=CYL_UP, shape="Cylinder", mat="Neon"),
                           P("Roof", [w, w * 1.6, w], [x, y + h + w * 0.8, z], (0.95, 0.6, 0.7), cls="WedgePart"),
                           P("Roof2", [w, w * 1.6, w], [x, y + h + w * 0.8, z], (0.95, 0.6, 0.7), cls="WedgePart", rot=rot_y(math.pi))])
def angel_statue(x, y, z, face):
    r = rot_y(face)
    def at(dx, dy, dz):
        c, s_ = math.cos(face), math.sin(face)
        return [x + dx * c + dz * s_, y + dy, z - dx * s_ + dz * c]
    ch = [P("Plinth", [5, 3, 5], at(0, 1.5, 0), MARBLE, rot=r),
          P("Robe", [3.4, 7, 3.4], at(0, 6.5, 0), MARBLE, cls="WedgePart", rot=r),
          P("Head", [2, 2, 2], at(0, 11, 0), MARBLE, shape="Ball"),
          D("Halo", [0.3, 2.6, 2.6], at(0, 12.6, 0.3), (1, 0.85, 0.4), mat="Neon", rot=CYL_UP, shape="Cylinder"),
          P("Trumpet", [5, 0.8, 0.8], at(0, 10.6, -2.4), (1, 0.8, 0.3), rot=mul(r, mul(rot_y(math.pi / 2), rot_z(0.35))), shape="Cylinder"),
          P("Bell", [0.6, 2, 2], at(0, 11.6, -4.8), (1, 0.8, 0.3), rot=mul(r, rot_y(math.pi / 2)), shape="Cylinder")]
    for sd in (-1, 1):
        ch.append(P("Wing", [0.5, 8, 5], at(sd * 2.2, 9, 1.4), (1, 1, 1), cls="WedgePart", rot=mul(r, rot_z(-sd * 0.5))))
    return model("AngelStatue", ch)
# the City of Light on a big main isle (walkable)
cx, cy, cz = 0, 6760, 260
city = recolor(island("CityIsle", cx, cy, cz, 70, rules=False), top=MARBLE, layer=PEACH, rim=GOLD)
heaven.append(city)
heaven.append(dome_building(cx, cy, cz - 10, 26, 22))
for (dx, dz, w, h) in [(-38, 10, 14, 12), (36, 6, 16, 14), (-20, 42, 12, 10), (24, 40, 12, 11)]:
    heaven.append(dome_building(cx + dx, cy, cz + dz, w, h, PEACH if dx > 0 else MARBLE))
for (dx, dz, h) in [(-55, -20, 40), (55, -26, 46), (-50, 40, 30), (50, 44, 34), (0, 58, 38)]:
    heaven.append(tower(cx + dx, cy, cz + dz, 6, h))
for k in range(14):  # golden road from the gate to the hall
    heaven.append(D("GoldRoad", [6, 0.15, 5], [cx, cy + 0.08, cz - 66 + k * 4], (1, 0.86, 0.45)))
# the pearly gate with bars at the city edge
gate2 = []
for k in range(-6, 7):
    if abs(k) < 2: continue
    gate2.append(P("Bar", [0.6, 16 + (6 - abs(k)) * 1.2, 0.6], [cx + k * 2, cy + 8 + (6 - abs(k)) * 0.6, cz - 68], (1, 0.82, 0.35), mat="Neon"))
for sd in (-1, 1):
    gate2.append(P("GatePost", [3.4, 26, 3.4], [cx + sd * 14, cy + 13, cz - 68], MARBLE))
    gate2.append(D("PostOrb", [3.4, 3.4, 3.4], [cx + sd * 14, cy + 28, cz - 68], (1, 0.9, 0.55), mat="Neon", shape="Ball"))
heaven.append(model("PearlyGate", gate2))
for (dx, dz, f) in [(-18, -60, 0.3), (18, -60, -0.3), (-62, 0, 1.4), (62, 0, -1.4)]:
    heaven.append(angel_statue(cx + dx, cy, cz + dz, f))
# waterfalls pouring off the city and the cloud isles into the clouds
for (x, y, z, w) in [(cx - 40, cy, cz + 62, 10), (cx + 66, cy, cz + 20, 8), (-100, 6740, -122, 6)]:
    heaven.append(D("Waterfall", [w, 120, 1.5], [x, y - 60, z], (0.65, 0.85, 1), mat="Neon", transparency=0.45))
heaven.append(D("River", [8, 0.2, 60], [cx - 40, cy + 0.12, cz + 32], (0.55, 0.8, 1), mat="Neon", transparency=0.2))
# the floating rotunda (temple) above the city
tx, ty, tz = 0, 6900, 250
rot_ = recolor(island("TempleIsle", tx, ty, tz, 18, rules=False), top=MARBLE, layer=PINK, rim=GOLD)
for k in range(10):
    a = k / 10 * math.tau
    rot_["children"].append(P("Column", [14, 1.6, 1.6], [tx + math.cos(a) * 12, ty + 7, tz + math.sin(a) * 12], MARBLE, rot=CYL_UP, shape="Cylinder"))
rot_["children"].append(P("RoofDisc", [1.4, 28, 28], [tx, ty + 14.7, tz], MARBLE, rot=CYL_UP, shape="Cylinder"))
rot_["children"].append(P("TempleDome", [22, 22, 22], [tx, ty + 15.4, tz], (1, 0.86, 0.5), shape="Ball"))
rot_["children"].append(D("Flame", [3, 3, 3], [tx, ty + 3, tz], (1, 0.95, 0.7), mat="Neon", shape="Ball", children=[light((1, 0.9, 0.6), 40, 3)]))
heaven.append(rot_)
# a rainbow arching over the city
for i, col in enumerate([(1, 0.3, 0.3), (1, 0.6, 0.2), (1, 0.95, 0.3), (0.4, 0.9, 0.4), (0.3, 0.6, 1), (0.5, 0.35, 0.9)]):
    R = 200 - i * 4
    prev = None
    for k in range(0, 31):
        a = math.pi * k / 30
        pt = [cx + math.cos(a) * R, cy - 30 + math.sin(a) * R * 0.7, cz + 120]
        if prev: heaven.append(beam("Rainbow", prev, pt, 4, col, tr=0.3))
        prev = pt
for k in range(26):  # pink and peach sunset clouds
    heaven.append(puff_cloud("PinkCloud", rnd.uniform(-450, 450), rnd.uniform(6600, 7150), rnd.uniform(-450, 500), rnd.uniform(2, 3.6), dark=2))

# ---- HELL (-4200..-5000): a lava sea, volcanoes, WALKABLE rock isles joined by bridges, the Cinder King's caldera
hell = []
LAVA, LAVA2, ROCK, ROCK2 = (1, 0.42, 0.1), (1, 0.7, 0.2), (0.16, 0.1, 0.1), (0.25, 0.14, 0.12)
hell.append(D("LavaSea", [2, 2040, 2040], [0, -4900, -60], LAVA, mat="Neon", rot=CYL_UP, shape="Cylinder"))
hell.append(D("LavaCrust", [0.6, 2040, 2040], [0, -4898.4, -60], (0.25, 0.08, 0.05), rot=CYL_UP, shape="Cylinder", transparency=0.55))
def volcano(name, x, base, z, r, h):
    ch = []
    n = 8
    for k in range(n):
        u = k / n
        rr = r * (1 - u * 0.8)
        ch.append(P("Cone", [h / n + 0.4, rr * 2, rr * 2], [x, base + h * u + h / n / 2, z], ROCK if k % 2 else ROCK2, rot=mul(rot_y(k), CYL_UP), shape="Cylinder"))
    ch.append(D("Crater", [1, r * 0.4, r * 0.4], [x, base + h + 0.3, z], LAVA2, mat="Neon", rot=CYL_UP, shape="Cylinder", children=[light(LAVA, 80, 3)]))
    for k in range(5):  # lava streaks down the side
        a = rnd.uniform(0, math.tau)
        hell.append(beam("LavaFlow", [x + math.cos(a) * r * 0.2, base + h, z + math.sin(a) * r * 0.2], [x + math.cos(a) * r * 0.95, base + 2, z + math.sin(a) * r * 0.95], rnd.uniform(1.5, 3), LAVA))
    return model(name, ch)
for (x, z, r, h) in [(-420, -500, 120, 320), (380, -620, 90, 260), (520, 260, 70, 180), (-520, 340, 80, 220), (60, -760, 140, 380)]:
    hell.append(volcano("Volcano", x, -4900, z, r, h))
def hell_isle(name, x, top, z, r):
    m = recolor(island(name, x, top, z, r, rules=False), top=(0.22, 0.14, 0.13), layer=ROCK, rim=LAVA)
    for k in range(int(r // 3)):  # glowing cracks in the ground
        a, d_ = rnd.uniform(0, math.tau), rnd.uniform(0, r * 0.75)
        m["children"].append(D("Crack", [rnd.uniform(4, 10), 0.12, 0.6], [x + math.cos(a) * d_, top + 0.07, z + math.sin(a) * d_], LAVA2, mat="Neon", rot=rot_y(rnd.uniform(0, 3))))
    for k in range(int(r // 6)):  # jagged rock spikes
        a, d_ = rnd.uniform(0, math.tau), rnd.uniform(r * 0.55, r * 0.9)
        hgt = rnd.uniform(6, 16)
        m["children"].append(P("Spike", [3, hgt, 3], [x + math.cos(a) * d_, top + hgt / 2, z + math.sin(a) * d_], ROCK2, cls="WedgePart", rot=rot_y(rnd.uniform(0, 6))))
    m["children"].append(D("Lavafall", [6, 300, 1.5], [x + r * 0.9, top - 150, z], LAVA, mat="Neon", transparency=0.1))
    return m
H_ISLES = [(-140, -4500, -80, 34), (150, -4560, 60, 30), (0, -4640, -320, 52), (-40, -4470, 120, 18), (240, -4520, -180, 16)]
for (x, y, z, r) in H_ISLES:
    hell.append(hell_isle("HellIsle" if r != 52 else "Caldera", x, y, z, r))
def bridge(a, b):
    """a walkable rope bridge of dark planks between two isle edges"""
    ch = []
    L = math.dist([a[0], a[2]], [b[0], b[2]])
    n = int(L / 3)
    yaw = math.atan2(b[0] - a[0], b[2] - a[2])
    for k in range(n + 1):
        u = k / n
        sag = math.sin(u * math.pi) * L * 0.04
        ch.append(P("Plank", [6, 0.6, 2.4], [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u - sag, a[2] + (b[2] - a[2]) * u], (0.3, 0.18, 0.12), rot=rot_y(yaw)))
    for sd in (-1, 1):
        off = [math.cos(yaw) * 3.2 * sd, 0, -math.sin(yaw) * 3.2 * sd]
        ch.append(beam("Rope", [a[0] + off[0], a[1] + 2.5, a[2] + off[2]], [b[0] + off[0], b[1] + 2.5, b[2] + off[2]], 0.4, (0.15, 0.1, 0.08), mat="SmoothPlastic"))
    return model("Bridge", ch)
def edge(i, j):
    (x1, y1, z1, r1), (x2, y2, z2, r2) = H_ISLES[i], H_ISLES[j]
    d = math.dist([x1, z1], [x2, z2]); ux, uz = (x2 - x1) / d, (z2 - z1) / d
    return [x1 + ux * (r1 - 2), y1, z1 + uz * (r1 - 2)], [x2 - ux * (r2 - 2), y2, z2 - uz * (r2 - 2)]
for (i, j) in [(0, 1), (0, 2), (1, 2), (0, 3), (1, 4)]:
    hell.append(bridge(*edge(i, j)))
# ink hands reaching out of the lava (the lost, drawn in ink)
for k in range(22):
    x, z = rnd.uniform(-300, 300), rnd.uniform(-450, 300)
    hy = -4899
    ch = [P("Arm", [1.6, 9, 1.6], [x, hy + 4, z], (0.08, 0.05, 0.08), rot=rot_z(rnd.uniform(-0.3, 0.3))),
          P("Palm", [3, 2.4, 1], [x, hy + 9, z], (0.08, 0.05, 0.08))]
    for f in range(4):
        ch.append(P("Finger", [0.5, 2.2, 0.5], [x - 1.1 + f * 0.75, hy + 11, z], (0.08, 0.05, 0.08), rot=rot_z((f - 1.5) * 0.15)))
    hell.append(model("InkHand", ch))
# the caldera throne
kx, ky, kz = 0, -4640, -320
for k in range(8):
    a = k / 8 * math.tau
    hell.append(P("ThronePillar", [5, 30, 5], [kx + math.cos(a) * 46, ky + 15, kz + math.sin(a) * 46], ROCK2, cls="WedgePart", rot=rot_y(-a)))
    hell.append(D("Brazier", [3, 3, 3], [kx + math.cos(a) * 46, ky + 31.5, kz + math.sin(a) * 46], LAVA2, mat="Neon", shape="Ball", children=[light(LAVA, 30, 2)] if k % 2 == 0 else None))
for k in range(16):
    hell.append(puff_cloud("AshCloud", rnd.uniform(-500, 500), rnd.uniform(-4350, -4150), rnd.uniform(-600, 400), rnd.uniform(2.5, 4), dark=1))

# ---- THE ABYSS (-5800..-6600): black and almost empty. Giant bones, monoliths, faint lights
abyss = []
BONE = (0.8, 0.78, 0.72)
for (x, y, z, L, yaw) in [(-120, -6150, -200, 160, 0.4), (180, -6350, 120, 120, -1.1)]:
    ch = []
    for k in range(12):  # the ribcage of something enormous
        u = k / 11
        px, pz = x + math.sin(yaw) * (u - 0.5) * L, z + math.cos(yaw) * (u - 0.5) * L
        rr = 30 * math.sin(0.15 + u * 2.8)
        for sd in (-1, 1):
            ch.append(beam("Rib", [px, y, pz], [px + math.cos(yaw) * rr * sd, y - rr * 0.9, pz - math.sin(yaw) * rr * sd], 2.4, BONE, mat="SmoothPlastic"))
    ch.append(beam("Spine", [x - math.sin(yaw) * L / 2, y, z - math.cos(yaw) * L / 2], [x + math.sin(yaw) * L / 2, y, z + math.cos(yaw) * L / 2], 4, BONE, mat="SmoothPlastic"))
    ch.append(P("Skull", [26, 20, 30], [x + math.sin(yaw) * (L / 2 + 14), y - 4, z + math.cos(yaw) * (L / 2 + 14)], BONE, rot=rot_y(yaw)))
    abyss.append(model("Leviathan Bones", ch))
for k in range(9):
    x, y, z = rnd.uniform(-300, 300), rnd.uniform(-6550, -5850), rnd.uniform(-400, 250)
    h = rnd.uniform(30, 70)
    abyss.append(model("Monolith", [P("Stone", [8, h, 4], [x, y, z], (0.05, 0.05, 0.08), rot=mul(rot_y(rnd.uniform(0, 3)), rot_z(rnd.uniform(-0.2, 0.2)))),
                                     D("Rune", [0.3, h * 0.6, 1], [x, y, z - 2.1], (0.55, 0.3, 0.9), mat="Neon", transparency=0.4)]))
for k in range(40):
    abyss.append(D("Glimmer", [0.8, 0.8, 0.8], [rnd.uniform(-400, 400), rnd.uniform(-6600, -5800), rnd.uniform(-500, 350)], (0.6, 0.9, 1), mat="Neon", shape="Ball"))
abyss.append(island("LastLedge", 0, -6060, -60, 14, dark=True))

# ---- THE UNKNOWN (-7400..-8400): pieces of the world that fell this far, drifting in the dark.
# (the colossal beings + ink clouds + eyes are client effects: Unknown.client)
unknown = []
for (x, y, z, r) in [(0, -7700, -60, 16), (-180, -7900, 120, 10), (160, -7820, -240, 12), (-60, -8100, -380, 8)]:
    unknown.append(recolor(island("FallenIsle", x, y, z, r), top=(0.85, 0.83, 0.8), layer=(0.3, 0.28, 0.35), rim=(0.6, 0.3, 1)))
# a lighthouse that fell from the sea, upside down; a heaven column; a storm lightning rod
unknown.append(model("FallenLighthouse", [P("Tower", [40, 8, 8], [220, -7650, 60], (0.92, 0.25, 0.3), rot=mul(rot_z(2.6), CYL_UP), shape="Cylinder"),
                                           D("DeadLamp", [6, 6, 6], [232, -7668, 60], (0.3, 0.3, 0.35), shape="Ball")]))
unknown.append(P("FallenColumn", [30, 4.5, 4.5], [-240, -7760, -120], MARBLE, rot=mul(rot_z(1.2), CYL_UP), shape="Cylinder"))
unknown.append(model("FallenPencil", pencil("P", -120, -8000, 200, 70, mul(rot_y(0.6), rot_z(2.2)), r=3)))

# ======================= HEAVEN v2 (v0.5) =======================
# A dense cloud city like the reference paintings: districts on big cloud isles packed close together,
# joined by arched marble bridges, everything sitting on thick pink/peach cloud banks.
heaven = []
MARBLE, IVORY2, PINK2, PEACH2, ROSE = (0.98, 0.96, 0.93), (0.95, 0.9, 0.82), (1, 0.8, 0.86), (1, 0.87, 0.74), (0.93, 0.62, 0.7)
GOLD2, GOLDD, SKYW = (1, 0.82, 0.35), (0.85, 0.62, 0.2), (0.6, 0.8, 1)
HY = 6720  # ground level of the city
def cloud_bank(x, y, z, r, n=None):
    """thick cloud mass under an isle (soft particle anchors, pink + white)"""
    for k in range(n or max(4, int(r / 9))):
        a, d_ = rnd.uniform(0, math.tau), rnd.uniform(0, r * 0.9)
        heaven.append(puff_cloud("CloudBank", x + math.cos(a) * d_, y - rnd.uniform(8, 40), z + math.sin(a) * d_, rnd.uniform(2.6, 4.2), dark=2 if k % 2 else 0))
def h_isle(name, x, top, z, r):
    m = recolor(island(name, x, top, z, r, rules=False), top=MARBLE, layer=PEACH2, rim=GOLD2, tip=PINK2)
    heaven.append(m)
    cloud_bank(x, top, z, r)
    return m
def box(name, size, pos, col, **kw): heaven.append(P(name, size, pos, col, **kw))
def hdeco(name, size, pos, col, **kw): heaven.append(D(name, size, pos, col, **kw))
def arch_window(x, y, z, w, h, yaw, col=SKYW):
    """a tall arched window: glowing pane + round top"""
    r = rot_y(yaw)
    hdeco("Window", [w, h, 0.3], [x, y, z], col, mat="Neon", rot=r)
    hdeco("WindowTop", [0.3, w, w], [x, y + h / 2, z], col, mat="Neon", rot=mul(r, rot_y(math.pi / 2)), shape="Cylinder")
def spire(x, y, z, w, h, col=GOLD2):
    box("SpireBase", [w, w * 0.6, w], [x, y + w * 0.3, z], MARBLE)
    for k in range(4):
        u = k / 4
        box("Spire", [w * (1 - u * 0.85), h / 4 + 0.2, w * (1 - u * 0.85)], [x, y + w * 0.6 + h * u + h / 8, z], col if k == 3 else ROSE, rot=rot_y(k * 0.4))
    hdeco("SpireTip", [0.6, 4, 0.6], [x, y + w * 0.6 + h + 2, z], GOLD2, mat="Neon")
def dome(x, y, z, d, col=GOLD2):
    box("Drum", [d * 0.35, d * 0.9, d * 0.9], [x, y + d * 0.17, z], MARBLE, rot=CYL_UP, shape="Cylinder")
    box("Dome", [d, d, d], [x, y + d * 0.35, z], col, shape="Ball")
    box("Lantern", [d * 0.2, d * 0.15, d * 0.15], [x, y + d * 0.85 + d * 0.1, z], MARBLE, rot=CYL_UP, shape="Cylinder")
    hdeco("Cross", [0.6, d * 0.3, 0.6], [x, y + d + d * 0.15, z], GOLD2, mat="Neon")
def colonnade(x, y, z, length, yaw, n, h, col=MARBLE):
    c, s_ = math.cos(yaw), math.sin(yaw)
    for k in range(n):
        u = (k / (n - 1) - 0.5) * length
        box("Column", [h, 1.6, 1.6], [x + c * u, y + h / 2, z - s_ * u], col, rot=CYL_UP, shape="Cylinder")
    box("Entablature", [length + 3, 2, 4], [x, y + h + 1, z], col, rot=rot_y(yaw))
    box("Pediment", [length + 3, 4, 4], [x, y + h + 4, z], ROSE, cls="WedgePart", rot=rot_y(yaw))
def big_angel(x, y, z, face, S):
    """a giant trumpeting angel statue (refs: corner angels)"""
    c, s_ = math.cos(face), math.sin(face)
    def at(dx, dy, dz): return [x + (dx * c + dz * s_) * S, y + dy * S, z + (-dx * s_ + dz * c) * S]
    r = rot_y(face)
    box("Plinth", [6 * S, 4 * S, 6 * S], at(0, 2, 0), MARBLE, rot=r)
    hdeco("PlinthGold", [6.4 * S, 0.6 * S, 6.4 * S], at(0, 4.1, 0), GOLD2, rot=r, mat="Neon")
    box("Robe", [4 * S, 9 * S, 4 * S], at(0, 8.6, 0), PEACH2, cls="WedgePart", rot=r)
    box("Chest", [3 * S, 3 * S, 2.4 * S], at(0, 13.6, 0), PEACH2, rot=r)
    box("Head", [2.4 * S] * 3, at(0, 16.4, 0), IVORY2, shape="Ball")
    hdeco("Halo", [0.4 * S, 3.4 * S, 3.4 * S], at(0, 18.4, 0.4), GOLD2, mat="Neon", rot=mul(r, mul(rot_x(0.3), CYL_UP)), shape="Cylinder")
    box("Trumpet", [7 * S, 0.8 * S, 0.8 * S], at(0, 16.5, -4), GOLD2, rot=mul(r, mul(rot_y(math.pi / 2), rot_z(0.45))), shape="Cylinder")
    box("Bell", [0.8 * S, 2.6 * S, 2.6 * S], at(0, 18.4, -7.2), GOLD2, rot=mul(r, mul(rot_y(math.pi / 2), rot_z(0.45))), shape="Cylinder")
    for sd in (-1, 1):
        box("Wing", [0.8 * S, 14 * S, 7 * S], at(sd * 2.6, 15, 2.2), (1, 1, 1), cls="WedgePart", rot=mul(r, mul(rot_z(-sd * 0.45), rot_x(-0.25))))
        box("WingTip", [0.7 * S, 8 * S, 5 * S], at(sd * 5.6, 21, 3.4), (0.98, 0.96, 1), cls="WedgePart", rot=mul(r, mul(rot_z(-sd * 0.8), rot_x(-0.4))))
def arch_bridge(a, b, w=7):
    """an arched marble bridge with gold rails between two points"""
    L = math.dist(a, b); n = max(6, int(L / 4))
    yaw = math.atan2(b[0] - a[0], b[2] - a[2])
    for k in range(n):
        u0, u1 = k / n, (k + 1) / n
        p0 = [a[i] + (b[i] - a[i]) * u0 for i in range(3)]; p0[1] += math.sin(u0 * math.pi) * L * 0.12
        p1 = [a[i] + (b[i] - a[i]) * u1 for i in range(3)]; p1[1] += math.sin(u1 * math.pi) * L * 0.12
        heaven.append(beam("BridgeDeck", p0, p1, 1, MARBLE, mat="SmoothPlastic"))
        heaven[-1]["properties"]["Size"][0] = float(w)
        heaven[-1]["properties"]["Collide"] = True if "Collide" in heaven[-1]["properties"] else None
        heaven[-1]["properties"].pop("Collide", None)
        for sd in (-1, 1):
            off = [math.cos(yaw) * w / 2 * sd, 1.6, -math.sin(yaw) * w / 2 * sd]
            heaven.append(beam("BridgeRail", [p0[i] + off[i] for i in range(3)], [p1[i] + off[i] for i in range(3)], 0.5, GOLD2))
            if k % 3 == 0:
                hdeco("RailPost", [0.8, 3, 0.8], [p0[0] + off[0], p0[1] + 1, p0[2] + off[2]], MARBLE)
    # arch underneath
    for k in range(n):
        u = (k + 0.5) / n
        p = [a[i] + (b[i] - a[i]) * u for i in range(3)]
        p[1] += math.sin(u * math.pi) * L * 0.12 - 3
        hdeco("BridgeArch", [2, 4, 4], p, IVORY2, rot=rot_y(yaw))

# --- A. GATE PLAZA (where you arrive from below): the ornate pearly gates, giant trumpeting angels
GX, GZ = 0, 230
h_isle("GatePlaza", GX, HY - 20, GZ, 62)
gate = []
for k in range(-9, 10):  # bars, taller toward the middle, ending in gold spear tips
    if k == 0: continue
    hgt = 26 + (9 - abs(k)) * 1.6
    gate.append(P("Bar", [0.7, hgt, 0.7], [GX + k * 1.8, HY - 20 + hgt / 2, GZ - 50], GOLD2, mat="Neon"))
    gate.append(P("Tip", [1.2, 1.6, 1.2], [GX + k * 1.8, HY - 20 + hgt + 0.8, GZ - 50], GOLD2, cls="WedgePart"))
for ring_y in (8, 20):  # gold scroll rings across the bars
    for k in range(-8, 9, 2):
        gate.append(D("Scroll", [0.4, 3, 3], [GX + k * 1.8, HY - 20 + ring_y, GZ - 50], GOLD2, mat="Neon", rot=rot_y(math.pi / 2), shape="Cylinder"))
gate.append(P("GateArch", [38, 2.4, 2], [GX, HY - 20 + 44, GZ - 50], GOLD2, mat="Neon", children=[label("THE PEARLY GATES", (1, 0.85, 0.45), dist=600)]))
for sd in (-1, 1):
    gate.append(P("Gatehouse", [9, 48, 9], [GX + sd * 21, HY - 20 + 24, GZ - 50], MARBLE))
    gate.append(P("GatehouseCap", [11, 3, 11], [GX + sd * 21, HY - 20 + 49.5, GZ - 50], GOLD2))
    gate.append(D("Lantern", [4, 4, 4], [GX + sd * 21, HY - 20 + 53, GZ - 50], (1, 0.95, 0.7), mat="Neon", shape="Ball", children=[light((1, 0.9, 0.6), 50, 2)]))
heaven.append(model("PearlyGates", gate))
for k in range(16):  # golden cobble road through the gate into the city
    hdeco("GoldRoad", [8, 0.15, 6], [GX, HY - 20 + 0.08, GZ + 40 - k * 6], (1, 0.86, 0.45) if k % 2 else (0.98, 0.8, 0.4))
box("Lectern", [3, 4, 2], [GX + 9, HY - 20 + 2, GZ - 40], (0.6, 0.42, 0.28))
hdeco("Book", [3.2, 0.5, 2.2], [GX + 9, HY - 20 + 4.3, GZ - 40], (1, 0.97, 0.88), rot=rot_x(0.3))
big_angel(GX - 40, HY - 20, GZ - 30, 0.5, 1.8)
big_angel(GX + 40, HY - 20, GZ - 30, -0.5, 1.8)

# --- B. CATHEDRAL ISLE: a gothic cathedral with twin spired towers and a glowing rose window
CX, CZ = -190, -10
h_isle("CathedralIsle", CX, HY, CZ, 78)
box("Nave", [26, 30, 64], [CX, HY + 15, CZ], MARBLE)
box("RoofL", [13, 12, 64], [CX - 6.5, HY + 36, CZ], ROSE, cls="WedgePart", rot=rot_y(math.pi / 2) if False else mul(rot_y(0), rot_z(0)))
for sd in (-1, 1):
    heaven.append(P("Roof", [64, 12, 14], [CX + sd * 6.5, HY + 36, CZ], ROSE, cls="WedgePart", rot=rot_y(math.pi / 2 if sd > 0 else -math.pi / 2)))
heaven.pop(-3) if False else None
for sd in (-1, 1):  # twin towers at the front with spires
    box("Tower", [12, 52, 12], [CX + sd * 16, HY + 26, CZ - 34], MARBLE)
    spire(CX + sd * 16, HY + 52, CZ - 34, 12, 34)
    for k in range(3):
        arch_window(CX + sd * 16, HY + 14 + k * 14, CZ - 40.2, 3, 8, 0)
    for k in range(5):  # flying buttresses along the nave
        bz = CZ - 24 + k * 12
        heaven.append(beam("Buttress", [CX + sd * 13, HY + 26, bz], [CX + sd * 22, HY + 4, bz], 2, IVORY2, mat="SmoothPlastic"))
        box("ButtressPier", [3, 8, 3], [CX + sd * 22, HY + 4, bz], IVORY2)
        arch_window(CX + sd * 13.2, HY + 16, bz, 3, 12, math.pi / 2, (0.75, 0.6, 1) if k % 2 else SKYW)
# rose window: a glowing wheel of colour between the towers
RW = [CX, HY + 34, CZ - 32.4]
hdeco("RoseRing", [0.6, 14, 14], RW, GOLD2, mat="Neon", rot=rot_y(math.pi / 2), shape="Cylinder")
hdeco("RoseGlass", [0.7, 12, 12], RW, (0.85, 0.45, 0.8), mat="Neon", rot=rot_y(math.pi / 2), shape="Cylinder")
for k in range(8):
    a = k / 8 * math.pi
    hdeco("RoseSpoke", [0.6, 12, 0.6], [RW[0], RW[1], RW[2] - 0.5], GOLD2, rot=rot_z(a))
box("Portal", [8, 14, 1], [CX, HY + 7, CZ - 32.6], GOLDD)
dome(CX, HY + 30, CZ + 30, 22)  # the apse dome behind
colonnade(CX + 40, HY, CZ + 40, 30, 0.4, 7, 14)

# --- C. DOME CITY: a great basilica, a clock tower and streets of little domed houses
DX, DZ = 190, -20
h_isle("DomeCity", DX, HY + 10, DZ, 80)
box("Basilica", [44, 24, 44], [DX, HY + 10 + 12, DZ], MARBLE)
for sd in (-1, 1):
    for k in range(3):
        arch_window(DX + sd * 22.2, HY + 10 + 12, DZ - 12 + k * 12, 3, 10, math.pi / 2)
        arch_window(DX - 12 + k * 12, HY + 10 + 12, DZ + sd * 22.2, 3, 10, 0)
dome(DX, HY + 10 + 24, DZ, 36)
for (ox, oz) in [(-22, -22), (22, -22), (-22, 22), (22, 22)]:
    dome(DX + ox, HY + 10 + 24, DZ + oz, 12, (1, 0.9, 0.6))
colonnade(DX, HY + 10, DZ - 30, 40, 0, 9, 16)
# clock tower
box("ClockTower", [12, 70, 12], [DX + 52, HY + 10 + 35, DZ + 30], IVORY2)
hdeco("ClockFace", [0.4, 8, 8], [DX + 52, HY + 10 + 58, DZ + 23.8], (1, 0.97, 0.86), rot=rot_y(math.pi / 2), shape="Cylinder")
hdeco("ClockRing", [0.3, 9, 9], [DX + 52, HY + 10 + 58, DZ + 23.9], GOLD2, mat="Neon", rot=rot_y(math.pi / 2), shape="Cylinder")
spire(DX + 52, HY + 10 + 70, DZ + 30, 12, 26)
for k in range(16):  # houses
    a = k / 16 * math.tau + 0.2
    rr = rnd.uniform(48, 68)
    hx, hz = DX + math.cos(a) * rr, DZ + math.sin(a) * rr
    if abs(hx - (DX + 52)) < 10 and abs(hz - (DZ + 30)) < 10: continue
    w_, h_ = rnd.uniform(8, 12), rnd.uniform(8, 16)
    box("House", [w_, h_, w_], [hx, HY + 10 + h_ / 2, hz], MARBLE if k % 3 else PEACH2, rot=rot_y(-a))
    if k % 2:
        dome(hx, HY + 10 + h_, hz, w_ * 0.8, ROSE if k % 4 == 1 else GOLD2)
    else:
        box("HouseRoof", [w_, w_ * 0.6, w_], [hx, HY + 10 + h_ + w_ * 0.3, hz], ROSE, cls="WedgePart", rot=rot_y(-a))
    arch_window(hx - math.cos(a) * (w_ / 2 + 0.2), HY + 10 + h_ * 0.5, hz - math.sin(a) * (w_ / 2 + 0.2), 1.6, 3.6, -a + math.pi / 2, (1, 0.9, 0.6))

# --- D. THE LAKE OF STILL WATER in the middle: a lake, a little island with a gazebo, rose gardens, waterfalls
LX, LZ = 0, -10
h_isle("LakeIsle", LX, HY - 10, LZ, 70)
hdeco("Lake", [0.4, 96, 96], [LX, HY - 10 + 0.2, LZ], (0.45, 0.75, 0.95), mat="Glass", rot=CYL_UP, shape="Cylinder", transparency=0.15)
hdeco("LakeGlow", [0.2, 90, 90], [LX, HY - 10 + 0.45, LZ], (0.6, 0.85, 1), mat="Neon", rot=CYL_UP, shape="Cylinder", transparency=0.7)
box("Islet", [2, 22, 22], [LX, HY - 10 + 1, LZ], (0.6, 0.85, 0.55), rot=CYL_UP, shape="Cylinder")
for k in range(8):
    a = k / 8 * math.tau
    box("GazeboColumn", [10, 1, 1], [LX + math.cos(a) * 6, HY - 10 + 7, LZ + math.sin(a) * 6], MARBLE, rot=CYL_UP, shape="Cylinder")
dome(LX, HY - 10 + 12, LZ, 14, (1, 1, 1))
for k in range(28):  # rose bushes round the shore
    a = k / 28 * math.tau
    rr = rnd.uniform(52, 64)
    d_ = rnd.uniform(3, 5)
    box("RoseBush", [d_, d_, d_], [LX + math.cos(a) * rr, HY - 10 + d_ * 0.35, LZ + math.sin(a) * rr], (0.45, 0.72, 0.42), shape="Ball")
    for f in range(2):
        hdeco("Rose", [1, 1, 1], [LX + math.cos(a) * rr + rnd.uniform(-1, 1), HY - 10 + d_ * 0.7, LZ + math.sin(a) * rr + rnd.uniform(-1, 1)], (1, 0.5, 0.65) if (k + f) % 2 else (1, 1, 1), shape="Ball")
for (x, z) in [(LX - 66, LZ + 20), (LX + 30, LZ + 62), (LX + 64, LZ - 30)]:
    hdeco("Waterfall", [12, 160, 1.5], [x, HY - 10 - 80, z], (0.65, 0.85, 1), mat="Neon", transparency=0.4)
# rainbow over the lake
for i, col in enumerate([(1, 0.35, 0.35), (1, 0.62, 0.25), (1, 0.95, 0.35), (0.45, 0.9, 0.45), (0.35, 0.6, 1), (0.6, 0.4, 0.95)]):
    R = 150 - i * 4.5; prev = None
    for k in range(0, 31):
        a = math.pi * k / 30
        pt = [LX + math.cos(a) * R, HY - 40 + math.sin(a) * R * 0.75, LZ - 90]
        if prev: heaven.append(beam("Rainbow", prev, pt, 4.5, col, tr=0.3))
        prev = pt

# bridges: gate -> lake -> cathedral / dome city
arch_bridge([GX, HY - 20, GZ - 62], [LX, HY - 10, LZ + 70])
arch_bridge([LX - 70, HY - 10, LZ], [CX + 78, HY, CZ])
arch_bridge([LX + 70, HY - 10, LZ], [DX - 80, HY + 10, DZ])

# --- E. THE HALO WARDEN'S SANCTUM (boss): a raised ring of columns above the lake
ax, ay, az = 0, 6990, -280
m = recolor(island("WardenArena", ax, ay, az, 46, rules=False), top=IVORY2, layer=PINK2, rim=GOLD2)
for k in range(14):
    a = k / 14 * math.tau
    hgt = rnd.uniform(18, 30) if k % 4 else 7
    m["children"].append(P("Column", [hgt, 4.5, 4.5], [ax + math.cos(a) * 40, ay + hgt / 2, az + math.sin(a) * 40], MARBLE, rot=CYL_UP, shape="Cylinder"))
    m["children"].append(D("InkCrack", [0.2, 1.4, rnd.uniform(8, 16)], [ax + math.cos(a) * 22, ay + 0.1, az + math.sin(a) * 22], (0.12, 0.1, 0.2), rot=rot_y(-a)))
heaven.append(m)
cloud_bank(ax, ay, az, 46)

# --- F. THE SKY PALACE, floating highest: three tiers of terraces, towers and golden domes
PX, PY, PZ = -40, 7080, 220
for t_, (r, hh) in enumerate([(44, 0), (32, 16), (20, 32)]):
    box("Terrace", [3, r * 2, r * 2], [PX, PY + hh, PZ], MARBLE if t_ % 2 == 0 else PEACH2, rot=CYL_UP, shape="Cylinder")
    hdeco("TerraceRim", [0.6, r * 2 + 1.2, r * 2 + 1.2], [PX, PY + hh + 1.6, PZ], GOLD2, mat="Neon", rot=CYL_UP, shape="Cylinder")
    for k in range(6 + t_ * -1):
        a = k / (6 - t_) * math.tau + t_
        box("PalaceTower", [5, 14, 5], [PX + math.cos(a) * (r - 4), PY + hh + 8.5, PZ + math.sin(a) * (r - 4)], IVORY2)
        dome(PX + math.cos(a) * (r - 4), PY + hh + 15.5, PZ + math.sin(a) * (r - 4), 6, ROSE if k % 2 else GOLD2)
dome(PX, PY + 33, PZ, 26)
cloud_bank(PX, PY, PZ, 44)

# --- G. distant floating castles (background, like the far spires in the paintings)
for (x, y, z, S) in [(-480, 7020, -420, 1.4), (480, 6960, -380, 1.2), (440, 7120, 420, 1.6), (-460, 7160, 380, 1.1)]:
    box("FarCastleBase", [6 * S, 50 * S, 50 * S], [x, y, z], MARBLE, rot=CYL_UP, shape="Cylinder")
    box("FarKeep", [20 * S, 30 * S, 20 * S], [x, y + 18 * S, z], IVORY2)
    for k in range(4):
        a = k / 4 * math.tau + 0.4
        box("FarTower", [6 * S, 40 * S, 6 * S], [x + math.cos(a) * 18 * S, y + 22 * S, z + math.sin(a) * 18 * S], MARBLE)
        box("FarRoof", [6 * S, 10 * S, 6 * S], [x + math.cos(a) * 18 * S, y + 47 * S, z + math.sin(a) * 18 * S], ROSE, cls="WedgePart")
    dome(x, y + 33 * S, z, 14 * S)
    for k in range(4):
        heaven.append(puff_cloud("FarCloud", x + rnd.uniform(-30, 30) * S, y - 10 * S, z + rnd.uniform(-30, 30) * S, 4 * S, dark=2))
# sky-wide pink + white cloud sea under the whole city
for k in range(60):
    heaven.append(puff_cloud("CloudSea", rnd.uniform(-520, 520), rnd.uniform(6580, 6660), rnd.uniform(-520, 520), rnd.uniform(3.5, 5), dark=2 if k % 3 else 0))
for k in range(18):
    heaven.append(puff_cloud("HighCloud", rnd.uniform(-500, 500), rnd.uniform(7000, 7300), rnd.uniform(-500, 500), rnd.uniform(2.5, 4), dark=2))


# ======================= WIDE ZONES (v0.6) =======================
import copy
wr = random.Random(606)
def _walk(n, f):
    f(n)
    for c in n.get("children", []): _walk(c, f)
def _center(m):
    a = []
    _walk(m, lambda n: a.append(n["properties"]["CFrame"]["CFrame"]["position"]) if "CFrame" in n.get("properties", {}) else None)
    if not a: return None
    return [sum(v[i] for v in a) / len(a) for i in range(3)]
def _sz(n):
    v = n.get("properties", {}).get("Size")
    return v if isinstance(v, list) and all(isinstance(q, (int, float)) for q in v) else None
def _bigpart(m):
    big = [False]
    _walk(m, lambda n: big.__setitem__(0, True) if max(_sz(n) or [0]) > 1200 else None)
    return big[0]
def clone_to(m, to, yaw, dy=0):
    """deep-copy a model and move it so its centre lands at `to`, rotated by yaw around Y"""
    m = copy.deepcopy(m); c0 = _center(m)
    c, s_ = math.cos(yaw), math.sin(yaw)
    R = [[c, 0, s_], [0, 1, 0], [-s_, 0, c]]
    def mv(n):
        pr = n.get("properties", {})
        if "CFrame" not in pr: return
        cf = pr["CFrame"]["CFrame"]; p_ = cf["position"]
        dx, dyy, dz = p_[0] - c0[0], p_[1] - c0[1], p_[2] - c0[2]
        cf["position"] = [to[0] + c * dx + s_ * dz, to[1] + dyy + dy, to[2] - s_ * dx + c * dz]
        o = cf["orientation"]
        cf["orientation"] = [[sum(R[i][k] * o[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    _walk(m, mv)
    return m
def widen_sizes(lst, f=2.0):
    """make huge surfaces (sea, lava sea, cloud decks) wider"""
    def g(n):
        pr = n.get("properties", {}); sz = _sz(n)
        if sz and max(sz) > 1200:
            pr["Size"] = [float(v * f) if v > 1200 else float(v) for v in sz]
    for m in lst: _walk(m, g)
def ring_fill(lst, names, count, rmin, rmax, ymin=None, ymax=None, keep_y=True):
    pool = [m for m in lst if m.get("name") in names and not _bigpart(m) and _center(m)]
    if not pool: return
    placed = []
    for k in range(count):
        for tries in range(30):
            a = (k / count) * math.tau + wr.uniform(-0.25, 0.25)
            d = wr.uniform(rmin, rmax)
            x, z = math.cos(a) * d, math.sin(a) * d
            if all(math.dist([x, z], q) > 120 for q in placed): break
        placed.append([x, z])
        src = wr.choice(pool); c0 = _center(src)
        y = c0[1] if keep_y else wr.uniform(ymin, ymax)
        if ymin is not None and keep_y: y = c0[1] + wr.uniform(ymin, ymax)
        lst.append(clone_to(src, [x, y, z], wr.uniform(0, math.tau)))
W = 1300  # new zone radius
for L in (clouds, ocean, hell): widen_sizes(L, 2.2)
# sky isles: more blob isles, peaks, rocks, planes, pencils around the hub
ring_fill(islands, {"BlobIsle", "BlobIsle2", "BatPeak", "WaspNestIsle", "Lookout"}, 10, 420, W, -120, 200)
ring_fill(islands, {"Rock"}, 10, 300, W, -160, 240)  # v1.8c: fewer, more spread in height
ring_fill(deco, {"PaperPlane", "SkyPencil", "Quill"}, 30, 300, W, -40, 120)
ring_fill(clouds, {"Cloud"}, 40, 250, W, -40, 120)
ring_fill(storm, {"StormIsle"}, 14, 450, W, -80, 120)
ring_fill(storm, {"StormCloud"}, 50, 350, W, -100, 200)
ring_fill(ocean, {"LighthouseIsle", "WreckIsle", "InkwellIsle", "DriftwoodIsle", "KrakenRock"}, 16, 450, W)
ring_fill(ocean, {"SunkenBoat", "SunkenPencil", "SinkingBooks"}, 18, 350, W)
ring_fill(depths, {"Crystal"}, 160, 250, W, -60, 60)
ring_fill(depths, {"InkRock"}, 50, 250, W, -60, 60)
ring_fill(cosmos, {"MoonIsle"}, 10, 850, W + 200, -200, 300)
ring_fill(cosmos, {"OrbitRock"}, 30, 800, W + 200, -200, 300)
ring_fill(cosmos, {"FarStar"}, 80, 800, W + 400, -300, 500)
ring_fill(abyss, {"Monolith"}, 20, 400, W, -40, 40)
ring_fill(abyss, {"Leviathan Bones"}, 6, 450, W)
ring_fill(abyss, {"Glimmer"}, 80, 300, W, -200, 200)
ring_fill(unknown, {"FallenIsle", "FallenLighthouse", "FallenColumn", "FallenPencil"}, 14, 350, W, -200, 200)
# hell: an outer ring of walkable volcano isles linked by rope bridges, plus big volcanoes
OUT = []
for k in range(9):
    a = k / 9 * math.tau + wr.uniform(-0.15, 0.15); d = wr.uniform(700, 1100)
    x, z, r = math.cos(a) * d, math.sin(a) * d - 200, wr.uniform(22, 42)
    y = wr.uniform(-4620, -4460)
    hell.append(hell_isle("HellIsle", x, y, z, r)); OUT.append((x, y, z, r))
for k in range(9):
    (x1, y1, z1, r1), (x2, y2, z2, r2) = OUT[k], OUT[(k + 1) % 9]
    d = math.dist([x1, z1], [x2, z2])
    if d < 420:
        ux, uz = (x2 - x1) / d, (z2 - z1) / d
        hell.append(bridge([x1 + ux * (r1 - 2), y1, z1 + uz * (r1 - 2)], [x2 - ux * (r2 - 2), y2, z2 - uz * (r2 - 2)]))
for k in range(7):
    a = k / 7 * math.tau + 0.3; d = wr.uniform(850, 1250)
    hell.append(volcano("Volcano", math.cos(a) * d, -4900, math.sin(a) * d - 200, wr.uniform(90, 160), wr.uniform(250, 420)))
ring_fill(hell, {"InkHand"}, 40, 600, W, -10, 10)
ring_fill(hell, {"AshCloud"}, 30, 500, W, -50, 150)
# heaven: outer districts in a ring (marble towns, chapels, angels, gardens, linked by bridges)
def heaven_ring(N, rmin, rmax, a0, rr=(55, 80)):
  HD = []
  for k in range(N):
    a = k / N * math.tau + a0; d = wr.uniform(rmin, rmax)
    x, z, r = math.cos(a) * d, math.sin(a) * d, wr.uniform(*rr)
    top = 6720 + wr.uniform(-40, 60)
    h_isle("OuterIsle", x, top, z, r); HD.append((x, top, z, r))
    kind = k % 4
    if kind == 0:   # domed temple town
        heaven.append(dome_building(x, top, z, 26, 22))
        for j in range(6):
            b = j / 6 * math.tau
            box("House", [10, 9, 10], [x + math.cos(b) * r * 0.62, top + 4.5, z + math.sin(b) * r * 0.62], IVORY2)
            box("HouseRoof", [10, 5, 10], [x + math.cos(b) * r * 0.62, top + 11.5, z + math.sin(b) * r * 0.62], ROSE, cls="WedgePart", rot=rot_y(b))
    elif kind == 1:  # chapel with spires + angels
        box("Chapel", [24, 26, 40], [x, top + 13, z], MARBLE)
        box("ChapelRoof", [24, 12, 40], [x, top + 32, z], ROSE, cls="WedgePart")
        for sd in (-1, 1):
            heaven.append(tower(x + sd * 14, top, z - 20, 8, 34))
            big_angel(x + sd * r * 0.6, top, z + r * 0.4, math.pi, 0.9)
    elif kind == 2:  # garden: colonnade ring, roses, fountain
        colonnade(x, top, z - r * 0.5, r * 0.9, 0, 7, 14)
        colonnade(x, top, z + r * 0.5, r * 0.9, math.pi, 7, 14)
        hdeco("Fountain", [3, 18, 18], [x, top + 1.5, z], SKYW, mat="Neon", rot=CYL_UP, shape="Cylinder")
        for j in range(14):
            b, dd = wr.uniform(0, math.tau), wr.uniform(14, r * 0.8)
            box("RoseBush", [4, 4, 4], [x + math.cos(b) * dd, top + 2, z + math.sin(b) * dd], ROSE, shape="Ball")
    else:            # bell tower keep
        heaven.append(tower(x, top, z, 18, 60))
        for j in range(4):
            b = j / 4 * math.tau + 0.4
            heaven.append(tower(x + math.cos(b) * r * 0.6, top, z + math.sin(b) * r * 0.6, 9, 30))
    hdeco("Waterfall", [10, 260, 2], [x + r * 0.9, top - 130, z], SKYW, mat="Neon", transparency=0.35)
  for k in range(N):
    (x1, y1, z1, r1), (x2, y2, z2, r2) = HD[k], HD[(k + 1) % N]
    d = math.dist([x1, z1], [x2, z2])
    if d < 650:
        ux, uz = (x2 - x1) / d, (z2 - z1) / d
        arch_bridge([x1 + ux * (r1 - 3), y1, z1 + uz * (r1 - 3)], [x2 - ux * (r2 - 3), y2, z2 - uz * (r2 - 3)])
  return HD
heaven_ring(8, 560, 900, 0.2)
heaven_ring(14, 1500, 2500, 0.05, (60, 95))
for k in range(24):
    a = k / 24 * math.tau + wr.uniform(-0.2, 0.2); d = wr.uniform(950, 2900)
    cloud_bank(math.cos(a) * d, 6700 + wr.uniform(-60, 80), math.sin(a) * d, 90)

# ======================= v0.9 UNDERWORLD at full size (it has its own place now) =======================
widen_sizes(hell, 1.35)
OUT2 = []
for k in range(14):
    a = k / 14 * math.tau + wr.uniform(-0.1, 0.1); d = wr.uniform(1500, 2500)
    x, z, r = math.cos(a) * d, math.sin(a) * d - 200, wr.uniform(26, 50)
    y = wr.uniform(-4640, -4440)
    hell.append(hell_isle("HellIsle", x, y, z, r)); OUT2.append((x, y, z, r))
for k in range(10):
    a = k / 10 * math.tau + 0.15; d = wr.uniform(1600, 2900)
    hell.append(volcano("Volcano", math.cos(a) * d, -4900, math.sin(a) * d - 200, wr.uniform(120, 220), wr.uniform(320, 560)))
ring_fill(hell, {"InkHand"}, 50, 1300, 2800, -10, 10)
ring_fill(hell, {"AshCloud"}, 50, 1200, 2800, -50, 200)
ring_fill(abyss, {"Monolith"}, 40, 1200, 2800, -60, 60)
ring_fill(abyss, {"Leviathan Bones"}, 12, 1200, 2800)
ring_fill(abyss, {"Glimmer"}, 120, 1000, 2800, -250, 250)
ring_fill(unknown, {"FallenIsle", "FallenLighthouse", "FallenColumn", "FallenPencil"}, 24, 1200, 2800, -250, 250)

# ======================= v0.9c: THE UNKNOWN IS EMPTY; HELL GETS ITS CITY =======================
unknown.clear()  # nothing down there. only dark. (and what lives in it)
def fire(size=20, heat=20, col=(1, 0.45, 0.1), col2=(1, 0.15, 0.05)):
    return {"name": "Fire", "className": "Fire", "properties": {"Size": float(size), "Heat": float(heat), "Color": F(col), "SecondaryColor": F(col2)}}
STONE, STONE2, GLOWW, FLAME = (0.42, 0.24, 0.17), (0.26, 0.13, 0.1), (1, 0.55, 0.18), (1, 0.5, 0.12)
def pandemonium(X, T, Z, yaw=0.0):
    """the palace of Pandemonium: a vast colonnaded facade, a keep, towers, a thousand torches"""
    c_, s_ = math.cos(yaw), math.sin(yaw)
    def at(dx, dy, dz): return [X + dx * c_ + dz * s_, T + dy, Z - dx * s_ + dz * c_]
    R = rot_y(yaw)
    ch = []
    ch.append(P("Terrace", [620, 30, 200], at(0, 15, 0), STONE2, rot=R))
    ch.append(P("Terrace2", [560, 14, 170], at(0, 37, -5), STONE, rot=R))
    for k in range(26):  # arcade under the terrace, glowing from inside
        x = -300 + k * 24
        ch.append(D("ArchGlow", [12, 18, 1], at(x, 12, -100.6), GLOWW, mat="Neon", rot=R))
    for tier, (y0, h, n, w) in enumerate([(44, 70, 30, 7), (124, 46, 26, 5)]):
        L = 540 - tier * 80
        for k in range(n):
            x = -L / 2 + k * L / (n - 1)
            ch.append(P("Column", [h, w, w], at(x, y0 + h / 2, -70 + tier * 20), STONE, rot=mul(R, CYL_UP), shape="Cylinder"))
            if k < n - 1:
                ch.append(D("Window", [L / (n - 1) * 0.55, h * 0.6, 1], at(x + L / (n - 1) / 2, y0 + h * 0.45, -55.6 + tier * 20), GLOWW, mat="Neon", rot=R))
        ch.append(P("Hall", [L, h, 60], at(0, y0 + h / 2, -25 + tier * 20), STONE2, rot=R))
        ch.append(P("Entablature", [L + 16, 8, 80], at(0, y0 + h + 4, -40 + tier * 20), STONE, rot=R))
    ch.append(P("Keep", [150, 120, 90], at(0, 238, 30), STONE2, rot=R))
    for k in range(7):
        ch.append(D("KeepWindow", [8, 30, 1], at(-60 + k * 20, 250, -15.6), GLOWW, mat="Neon", rot=R))
    ch.append(P("Dome", [90, 90, 90], at(0, 300, 30), STONE, shape="Ball"))
    for sd in (-1, 1):
        for (tx, th) in [(250, 260), (140, 330)]:
            ch.append(P("Tower", [44, th, 44], at(sd * tx, th / 2 + 30, 40), STONE2, rot=R))
            for j in range(4):  # crenellations
                ch.append(P("Merlon", [10, 12, 10], at(sd * tx + (j % 2 - 0.5) * 30, th + 36, 40 + (j // 2 - 0.5) * 30), STONE, rot=R))
            ch.append(D("TowerFlame", [14, 14, 14], at(sd * tx, th + 50, 40), FLAME, mat="Neon", shape="Ball", children=[fire(30, 25), light(FLAME, 60, 3)]))
            for j in range(5):
                ch.append(D("Slit", [4, 16, 1], at(sd * tx, 80 + j * th / 6, 17.6), GLOWW, mat="Neon", rot=R))
    for k in range(32):  # torches along the terrace edge
        x = -300 + k * 600 / 31
        ch.append(P("TorchPost", [2, 10, 2], at(x, 49, -82), STONE2, rot=R))
        kids = ([fire(8, 12)] if k % 2 == 0 else []) + ([light(FLAME, 40, 2)] if k % 4 == 0 else [])
        ch.append(D("Torch", [2.6, 2.6, 2.6], at(x, 55, -82), FLAME, mat="Neon", shape="Ball", children=kids))
    for sd in (-1, 1):  # serpent-headed gate statues
        ch.append(P("Statue", [20, 60, 20], at(sd * 40, 74, -95), STONE2, rot=R))
        ch.append(D("StatueEyes", [10, 2, 1], at(sd * 40, 98, -105.6), (1, 0.2, 0.1), mat="Neon", rot=R))
    return model("Pandemonium", ch)
PX, PY, PZ = -200, -4700, -1300
hell.append(recolor(island("PandemoniumRock", PX, PY, PZ, 340, rules=False), top=(0.2, 0.12, 0.1), layer=ROCK, rim=LAVA))
hell.append(pandemonium(PX, PY, PZ + 40, 0.0))
def eye_tower(X, B, Z, H):
    """the tower with the eye (image: a spiralling spire, an open eye at its tip)"""
    ch = []
    n = 14
    for k in range(n):
        u = k / n
        r = 60 * (1 - u * 0.8)
        ch.append(P("Tier", [H / n, r * 2, r * 2], [X, B + H * u + H / n / 2, Z], STONE if k % 2 else STONE2, rot=CYL_UP, shape="Cylinder"))
        for j in range(6):
            a = j / 6 * math.tau + k * 0.5
            ch.append(D("TierWindow", [3, H / n * 0.5, 1], [X + math.cos(a) * (r + 0.4), B + H * u + H / n / 2, Z + math.sin(a) * (r + 0.4)], GLOWW, mat="Neon", rot=rot_y(-a + math.pi / 2)))
    top = B + H
    ch.append(D("EyeWhite", [40, 40, 40], [X, top + 20, Z], (0.95, 0.9, 0.82), shape="Ball"))
    ch.append(D("Iris", [22, 22, 22], [X, top + 20, Z - 11], (1, 0.25, 0.05), mat="Neon", shape="Ball", children=[light((1, 0.3, 0.1), 60, 4)]))
    ch.append(D("Pupil", [10, 10, 10], [X, top + 20, Z - 18], (0, 0, 0), shape="Ball"))
    ch.append(D("Crown", [6, 54, 54], [X, top + 2, Z], STONE2, rot=CYL_UP, shape="Cylinder", children=[fire(30, 25)]))
    return model("TowerOfTheEye", ch)
hell.append(eye_tower(900, -4900, -900, 640))
hell.append(eye_tower(-1500, -4900, 900, 520))
def flame_pillar(X, Z, H):
    """an eternal flame roaring out of the lava sea"""
    ch = [D("FlameCore", [H, 30, 30], [X, -4900 + H / 2, Z], FLAME, mat="Neon", rot=CYL_UP, shape="Cylinder", transparency=0.25),
          D("FlameOuter", [H * 0.8, 54, 54], [X, -4900 + H * 0.4, Z], (1, 0.25, 0.05), mat="Neon", rot=CYL_UP, shape="Cylinder", transparency=0.65)]
    for k in range(2):
        ch.append(D("FlameFire", [4, 4, 4], [X, -4900 + 10 + k * H / 4, Z], FLAME, transparency=1, children=[fire(30, 25)] + ([light(FLAME, 60, 3)] if k == 1 else [])))
    return model("EternalFlame", ch)
for k in range(10):
    a = k / 10 * math.tau + 0.3
    d = 700 + (k % 3) * 600
    hell.append(flame_pillar(math.cos(a) * d, math.sin(a) * d, 260 + (k % 4) * 90))
for (x, y, z, r) in (OUT + OUT2)[:40]:  # braziers burning on every isle
    for j in range(2):
        a = j * math.pi + 0.7
        bx, bz = x + math.cos(a) * r * 0.5, z + math.sin(a) * r * 0.5
        hell.append(P("Brazier", [5, 7, 5], [bx, y + 3.5, bz], STONE2))
        hell.append(D("BrazierFlame", [4, 4, 4], [bx, y + 8.5, bz], FLAME, mat="Neon", shape="Ball", children=([fire(14, 18), light(FLAME, 40, 2.5)] if j == 0 else [])))

# v1.0 the Cosmos widens to r~3300 and gets taller: more planets, moons, rocks and stars out where the giants roam
ring_fill(cosmos, {"PaperPlanet"}, 6, 1600, 3200, -300, 500)
ring_fill(cosmos, {"MoonIsle"}, 14, 1400, 3300, -250, 450)
ring_fill(cosmos, {"OrbitRock"}, 40, 1400, 3300, -300, 500)
ring_fill(cosmos, {"FarStar"}, 120, 1400, 3500, -400, 700)

# ======================= v0.9 REALMS: one World per place =======================
import copy as _cp
def spawn_at(x, y, z):
    sp = _cp.deepcopy(spawn)
    sp["properties"]["CFrame"]["CFrame"]["position"] = [float(x), float(y), float(z)]
    return sp
# Celestial gate isle: a dark star-paper island ringed in gold (arrival + respawn)
cel_gate = []
gi = recolor(island("CelestialGate", 0, 3955, 0, 34, rules=False), top=(0.12, 0.12, 0.25), layer=(0.2, 0.18, 0.4), rim=(1, 0.82, 0.35), tip=(0.6, 0.5, 1))
cel_gate.append(gi)
for k in range(8):
    an = k / 8 * math.tau
    cel_gate.append(P("GatePillar", [3, 18, 3], [math.cos(an) * 28, 3955 + 9, math.sin(an) * 28], (0.95, 0.92, 0.85)))
    cel_gate.append(D("PillarStar", [2.4, 2.4, 2.4], [math.cos(an) * 28, 3955 + 19.5, math.sin(an) * 28], (1, 0.85, 0.4), mat="Neon", shape="Ball"))
cel_gate.append(D("GateLabel", [1, 1, 1], [0, 3955 + 26, 0], (1, 1, 1), transparency=1, children=[label("THE CELESTIAL REALM", (1, 0.85, 0.45), (30, 6), 400)]))
# Underworld gate isle: a scorched rock with a ring of braziers
und_gate = []
und_gate.append(hell_isle("UnderworldGate", 0, -4045, 0, 34))
for k in range(6):
    an = k / 6 * math.tau
    und_gate.append(P("Brazier", [4, 6, 4], [math.cos(an) * 26, -4045 + 3, math.sin(an) * 26], (0.2, 0.12, 0.1)))
    und_gate.append(D("Flame", [3, 3, 3], [math.cos(an) * 26, -4045 + 7.5, math.sin(an) * 26], (1, 0.5, 0.15), mat="Neon", shape="Ball", children=[light((1, 0.45, 0.15), 30, 2)]))
und_gate.append(D("GateLabel", [1, 1, 1], [0, -4045 + 22, 0], (1, 1, 1), transparency=1, children=[label("THE UNDERWORLD", (1, 0.4, 0.3), (30, 6), 400)]))
# v1.2 GENESIS ISLES: a cluster of real floating islands (grass, dirt, rock, trees) chained together
genesis = []
GX, GY, GZ = 0, 40, 300
def g_chain(a, b, sag=18, link=3.2):
    """an iron chain between two anchor points, sagging in the middle"""
    ch = []
    ax, ay, az = a; bx, by, bz = b
    L = math.dist(a, b)
    n = max(4, int(L / (link * 0.8)))
    yaw = math.atan2(-(bx - ax), -(bz - az))
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((ax + (bx - ax) * t, ay + (by - ay) * t - math.sin(t * math.pi) * sag, az + (bz - az) * t))
    for i in range(n):
        p0, p1 = pts[i], pts[i + 1]
        dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        hz = math.hypot(dx, dz)
        pitch = math.atan2(dy, hz)
        cx, cy, cz = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2
        rot = mul(mul(rot_y(yaw), rot_x(pitch)), rot_z(math.pi / 2 if i % 2 else 0))
        # a link = an open rectangle of 4 bars (local Z = along the chain)
        ch.append(D("Link", [1.4, 0.35, link], [cx, cy, cz], (0.32, 0.32, 0.35), rot=rot, mat="Metal"))
    return model("Chain", ch)
OAKS.clear()
genesis.append(g_island("GenesisIsle", GX, GY, GZ, 210, trees=60, lobes=6, avoid=-math.pi / 2, water=True, ancient=True))
MAIN_OAKS = list(OAKS)
G_CLEAR += [(420, 600, 34), (-420, 140, 22), (0, 860, 22), (430, 180, 22)]  # v1.8: temple + shrine plazas
SAT = [(-420, 60, -160, 90), (430, 20, -120, 80), (420, 90, 300, 95), (-400, 0, 330, 80), (0, 70, 560, 85)]
for i, (dx, dy, dz, r) in enumerate(SAT):
    sx, sy, sz = GX + dx, GY + dy, GZ + dz
    genesis.append(g_island("SkyIsle%d" % i, sx, sy, sz, r, trees=int(r / 5), lobes=4))
    # chain from the main isle rim to the satellite rim, anchored in rock posts
    d = math.hypot(dx, dz)
    ux, uz = dx / d, dz / d
    a = (GX + ux * 200, GY - 3, GZ + uz * 200)
    b = (sx - ux * (r - 6), sy - 3, sz - uz * (r - 6))
    for (px, py, pz) in (a, b):
        genesis.append(P("ChainPost", [3, 6, 3], [px, py + 3, pz], NROCK[1], mat="Slate"))
        genesis.append(P("ChainRing", [0.8, 3.4, 3.4], [px, py + 1, pz], (0.3, 0.3, 0.33), mat="Metal", shape="Cylinder"))
    genesis.append(g_chain(a, b, sag=20 + d * 0.03))
# chains between neighbouring satellites too
for i in range(len(SAT)):
    j = (i + 2) % len(SAT)
    if i < j:
        A, B = SAT[i], SAT[j]
        genesis.append(g_chain((GX + A[0], GY + A[1] - 12, GZ + A[2]), (GX + B[0], GY + B[1] - 12, GZ + B[2]), sag=40))
STONE = (0.82, 0.8, 0.76)
for k in range(8):  # the Wing Shrine: weathered marble pillars around an altar
    an = k / 8 * math.tau
    px, pz = GX + math.cos(an) * 24, GZ + math.sin(an) * 24
    genesis.append(P("ShrinePillar", [26, 4, 4], [px, GY + 13, pz], STONE, rot=CYL_UP, shape="Cylinder", mat="Marble"))
    genesis.append(P("PillarCap", [6, 1.5, 6], [px, GY + 26.7, pz], STONE, mat="Marble"))
    genesis.append(D("Ivy", [4.3, 3, 4.3], [px, GY + 3 + (k % 3) * 2, pz], NLEAF[k % 4], mat="Grass", transparency=0.1, shape="Block"))
genesis.append(P("Altar", [3, 14, 14], [GX, GY + 1.5, GZ], STONE, rot=CYL_UP, shape="Cylinder", mat="Marble"))
genesis.append(P("ShrineFloor", [0.6, 56, 56], [GX, GY + 0.3, GZ], (0.7, 0.68, 0.64), rot=CYL_UP, shape="Cylinder", mat="Cobblestone"))
for sd in (-1, 1):  # a pair of great feathered wings floating over the altar
    for f in range(9):
        a_ = 0.2 + f * 0.14
        L = 9 + f * 0.9
        genesis.append(D("ShrineFeather", [L, 0.4, 1.6], [GX + sd * (math.cos(a_) * L / 2 + 1.5), GY + 16 + math.sin(a_) * L / 2, GZ], (1, 1, 1) if f % 2 else (0.95, 0.93, 0.88),
                         rot=rot_z(sd * a_)))
genesis.append(D("ShrineGlow", [3, 3, 3], [GX, GY + 16, GZ], (1, 0.9, 0.6), mat="Neon", shape="Ball", children=[light((1, 0.9, 0.6), 40, 2)]))
# v1.8f: no Wing Shrine label (less text)
# the MENTOR: an old winged master who trains your skills (server adds the prompt)
MX, MZ = GX + 14, GZ + 50
SKIN = (0.92, 0.76, 0.62); ROBE = (0.85, 0.82, 0.74)
genesis.append(model("Mentor", [  # v1.7: the detailed animated figure is built by NPCs.client (NPCModel "mentor")
    P("MentorDais", [0.8, 7, 7], [MX, GY + 0.4, MZ], (0.78, 0.76, 0.72), rot=CYL_UP, shape="Cylinder", mat="Marble"),
    D("MentorDaisRune", [0.85, 5, 5], [MX, GY + 0.42, MZ], (0.55, 0.85, 1), rot=CYL_UP, shape="Cylinder", mat="Neon", transparency=0.6),
    D("MentorAnchor", [1, 1, 1], [MX, GY + 3, MZ], (1, 1, 1), transparency=1, children=[label("MASTER ORREN - TRAINER", (1, 0.95, 0.7), (16, 3), 120)]),
]))
spawn["properties"]["CFrame"]["CFrame"]["position"] = [float(GX), float(GY + 0.5), float(GZ + 80)]
# ======== v1.4 WORLD LIFE: chests, apples, landmarks, the hidden isle, a far horizon ========
def attr(pt, **a):
    pt["attributes"] = {k: (float(v) if isinstance(v, (int, float)) else v) for k, v in a.items()}
    return pt
GOLD_T = (0.95, 0.75, 0.25)

def chest(cid, x, y, z, yaw=0.0, tier=1):
    # v1.8: a proper treasure chest - plank body, metal corners, rounded lid with bands, lock plate, handles,
    # and gold inside (hidden under the lid until it opens). Lid parts are named ChestLid* (they swing open).
    W = yawpt(x, y, z, yaw)
    r_ = rot_y(yaw)
    if tier == 1:
        wood, wood2, trim, gem = (0.5, 0.31, 0.16), (0.38, 0.23, 0.12), GOLD_T, (1, 0.85, 0.3)
    else:
        wood, wood2, trim, gem = (0.3, 0.27, 0.38), (0.22, 0.2, 0.3), (0.75, 0.6, 1), (0.7, 0.5, 1)
    ch = [attr(P("ChestBase", [4, 2.4, 2.8], W(0, 1.2, 0), wood, rot=r_, mat="WoodPlanks" if tier == 1 else "Slate"), ChestId=cid, Tier=tier)]
    for hy in (0.75, 1.6):
        ch.append(D("ChestPlank", [4.04, 0.1, 2.84], W(0, hy, 0), wood2, rot=r_, mat="Wood"))
    ch.append(P("ChestFoot", [4.2, 0.3, 3.0], W(0, 0.15, 0), trim, rot=r_, mat="Metal"))
    for sx in (-1, 1):
        for sz in (-1, 1):
            ch.append(D("ChestCorner", [0.32, 2.5, 0.32], W(sx * 1.94, 1.25, sz * 1.34), trim, rot=r_, mat="Metal"))
        ch.append(D("ChestHandle", [0.14, 0.45, 1.1], W(sx * 2.06, 1.7, 0), (0.3, 0.3, 0.32), rot=r_, mat="Metal"))
    ch.append(D("ChestLock", [0.95, 1.0, 0.14], W(0, 1.95, -1.47), trim, rot=r_, mat="Metal"))
    ch.append(D("ChestKeyhole", [0.18, 0.42, 0.06], W(0, 1.9, -1.55), INK, rot=r_))
    # treasure inside (sits under the dome)
    for k in range(9):
        a_ = k * 2.1
        ch.append(D("ChestGoldCoin", [0.14, 0.55, 0.55], W(math.cos(a_) * 1.1 * (k % 3) / 2, 2.48 + (k % 2) * 0.1, math.sin(a_) * 0.6 * (k % 3) / 2), (1, 0.82, 0.25), rot=mul(r_, rot_z(math.pi / 2 + 0.2 * (k % 3))), shape="Cylinder", mat="Metal"))
    ch.append(D("ChestGoldGem", [0.6, 0.6, 0.6], W(0.4, 2.7, 0.2), gem, shape="Ball", mat="Neon"))
    # rounded lid + bands + latch
    ch.append(P("ChestLid", [3.96, 2.8, 2.8], W(0, 2.4, 0), wood, rot=r_, shape="Cylinder", mat="WoodPlanks" if tier == 1 else "Slate"))
    for bx in (-1.3, 1.3):
        ch.append(D("ChestLidBand", [0.3, 2.92, 2.92], W(bx, 2.4, 0), trim, rot=r_, shape="Cylinder", mat="Metal"))
    ch.append(D("ChestLidEnd", [4.06, 2.86, 2.86], W(0, 2.4, 0), wood2, rot=r_, shape="Cylinder", mat="Wood", transparency=1))
    ch.append(D("ChestLidLatch", [0.55, 0.7, 0.16], W(0, 2.55, -1.47), trim, rot=r_, mat="Metal"))
    if tier >= 2:
        for k in range(3):
            ch.append(D("ChestRune", [0.12, 0.6, 0.06], W(-1.2 + k * 1.2, 1.2, -1.43), (0.7, 0.5, 1), rot=r_, mat="Neon"))
    ch.append(D("ChestGlow", [0.5, 0.5, 0.5], W(0, 3.6, 0), trim, mat="Neon", shape="Ball", transparency=0.4, children=[light(trim, 14, 1.2)]))
    return model("Chest", ch)
life = []
# glowing apples hanging under the canopies of main-isle oaks (eat = heal + a little XP)
for i, (ox, oy, oz, os_) in enumerate(MAIN_OAKS[::3][:16]):
    a_ = i * 2.1
    life.append(attr(D("Apple", [1.3, 1.3, 1.3], [ox + math.cos(a_) * 2.6 * os_, oy + 10 * os_ - 2.2 * os_, oz + math.sin(a_) * 2.6 * os_], (0.95, 0.2, 0.18), shape="Ball", mat="Neon", transparency=0.05), Apple=1))
# treasure chests: one hidden on every satellite, a few on the main isle, the rest in odd places
CH = []
for i, (dx, dy, dz, r) in enumerate(SAT):
    a_ = 0.7 + i
    CH.append((GX + dx + math.cos(a_) * r * 0.5, GY + dy, GZ + dz + math.sin(a_) * r * 0.5, 1))
CH += [(GX - 150, GY, GZ + 60, 1), (GX + 120, GY, GZ - 120, 1)]
# the FORGOTTEN TEMPLE on SkyIsle2 (v1.8): a stepped marble sanctuary - 3 terraces, a ring of fluted columns
# with bases + capitals (some broken), a carved entablature on the intact ones, a front gate, stairs, a winged
# statue, braziers, a reflecting pool, fallen drums, ivy everywhere, and the ancient chest on the altar.
tx_, ty_, tz_ = GX + SAT[2][0], GY + SAT[2][1], GZ + SAT[2][2]
MARB, MARB2, MARB3 = (0.86, 0.84, 0.79), (0.78, 0.76, 0.71), (0.7, 0.68, 0.64)
for k, (rr, hh) in enumerate([(25, 1.2), (19.5, 1.2), (13.5, 1.2)]):
    life.append(P("TempleTier", [hh, rr * 2, rr * 2], [tx_, ty_ + 0.6 + k * 1.2, tz_], [MARB2, MARB, MARB2][k], rot=CYL_UP, shape="Cylinder", mat="Marble"))
    life.append(D("TempleTierEdge", [0.3, rr * 2 + 0.6, rr * 2 + 0.6], [tx_, ty_ + 0.15 + k * 1.2, tz_], MARB3, rot=CYL_UP, shape="Cylinder", mat="Marble"))
TT = ty_ + 3.6  # top of the third terrace
# mosaic rings on the sanctum floor
for rr, col in [(11, (0.75, 0.62, 0.35)), (7, (0.35, 0.45, 0.7)), (3.5, (0.75, 0.62, 0.35))]:
    life.append(D("TempleMosaic", [0.1, rr * 2, rr * 2], [tx_, TT + 0.04 + rr * 0.001, tz_], col, rot=CYL_UP, shape="Cylinder", mat="Marble"))
# stairs up the terraces (front = -z)
for k in range(6):
    life.append(P("TempleStair", [8, 0.6, 1.4], [tx_, ty_ + 0.3 + k * 0.6, tz_ - 26 + k * 1.3], MARB, mat="Marble"))
# column ring on the first terrace
HGT = [24, 24, 9, 24, 24, 5, 24, 24, 14, 24, 7, 24]
for k in range(12):
    an = k / 12 * math.tau + math.pi / 12
    px, pz = tx_ + math.cos(an) * 22, tz_ + math.sin(an) * 22
    h = HGT[k]
    by = ty_ + 1.2
    life.append(P("PillarBase", [3.2, 1.0, 3.2], [px, by + 0.5, pz], MARB2, mat="Marble"))
    life.append(P("RuinColumn", [h, 2.6, 2.6], [px, by + 1 + h / 2, pz], MARB, rot=CYL_UP, shape="Cylinder", mat="Marble"))
    for f in range(6):  # flutes
        fa = f / 6 * math.tau
        life.append(D("Flute", [h * 0.9, 0.35, 0.35], [px + math.cos(fa) * 1.25, by + 1 + h / 2, pz + math.sin(fa) * 1.25], MARB3, rot=CYL_UP, shape="Cylinder", mat="Marble"))
    if h >= 20:
        life.append(P("PillarCap", [3.4, 1.2, 3.4], [px, by + 1 + h + 0.6, pz], MARB2, mat="Marble"))
    else:
        life.append(P("RuinPiece", [7, 2.5, 2.5], [px + math.cos(an) * 6, by + 0.4, pz + math.sin(an) * 6], MARB2, rot=rot_y(-an + 0.6), shape="Cylinder", mat="Marble"))
        life.append(P("RuinPiece", [4, 2.5, 2.5], [px + math.cos(an + 0.3) * 10, by + 0.2, pz + math.sin(an + 0.3) * 10], MARB3, rot=rot_y(-an - 0.4), shape="Cylinder", mat="Marble"))
    life.append(D("RuinIvy", [2.9, min(h, 10) * 0.8, 2.9], [px, by + 1 + min(h, 10) * 0.4, pz], NLEAF[k % 5], mat="Grass", transparency=0.1))
    # entablature beams between neighbouring intact columns
    k2 = (k + 1) % 12
    if HGT[k] >= 20 and HGT[k2] >= 20:
        an2 = k2 / 12 * math.tau + math.pi / 12
        a_ = [px, by + 1 + h + 1.8, pz]
        b_ = [tx_ + math.cos(an2) * 22, by + 1 + h + 1.8, tz_ + math.sin(an2) * 22]
        life.append(seg("Entablature", a_, b_, 2.2, MARB2, mat="Marble", shape="Block"))
        life.append(seg("Frieze", [a_[0], a_[1] + 1.4, a_[2]], [b_[0], b_[1] + 1.4, b_[2]], 0.8, (0.75, 0.62, 0.35), mat="Marble", shape="Block"))
# the front gate: two tall columns + a lintel + a pediment
for sx in (-1, 1):
    life.append(P("GatePillar", [30, 3.2, 3.2], [tx_ + sx * 6, ty_ + 15, tz_ - 28], MARB, rot=CYL_UP, shape="Cylinder", mat="Marble"))
life.append(P("GateLintel", [16, 2.6, 3.6], [tx_, ty_ + 31, tz_ - 28], MARB2, mat="Marble"))
life.append(P("GatePediment", [3.6, 5, 9], [tx_ - 4.5, ty_ + 34.8, tz_ - 28], MARB, rot=rot_y(math.pi / 2), mat="Marble", cls="WedgePart"))
life.append(P("GatePediment", [3.6, 5, 9], [tx_ + 4.5, ty_ + 34.8, tz_ - 28], MARB, rot=rot_y(-math.pi / 2), mat="Marble", cls="WedgePart"))
life.append(D("GateIvy", [17, 1.5, 3.8], [tx_ - 1, ty_ + 32.6, tz_ - 28], NLEAF[1], mat="Grass", transparency=0.1))
# altar + winged statue behind it
life.append(P("Altar", [7, 2.2, 4.4], [tx_, TT + 1.1, tz_], MARB2, mat="Marble"))
life.append(D("AltarCloth", [7.2, 0.15, 2.0], [tx_, TT + 2.25, tz_], (0.55, 0.15, 0.2), mat="Fabric"))
SX, SZ = tx_, tz_ + 8
life.append(P("StatuePlinth", [5, 3, 5], [SX, TT + 1.5, SZ], MARB3, mat="Marble"))
life.append(P("StatueRobe", [6, 3.4, 3.4], [SX, TT + 6, SZ], MARB, rot=CYL_UP, shape="Cylinder", mat="Marble"))
life.append(P("StatueChest", [3, 2.6, 2], [SX, TT + 10, SZ], MARB, mat="Marble"))
life.append(P("StatueHead", [1.9, 1.9, 1.9], [SX, TT + 12.3, SZ], MARB, shape="Ball", mat="Marble"))
for sd in (-1, 1):
    for f in range(6):
        L = 4 + f * 1.2
        life.append(P("StatueWing", [0.4, L, 1.6], [SX + sd * (2 + f * 0.9), TT + 11 - L / 2 + f * 0.6, SZ + 0.6], MARB2, rot=rot_z(sd * (0.35 + f * 0.1)), mat="Marble"))
    life.append(seg("StatueArm", [SX + sd * 1.6, TT + 10.6, SZ], [SX + sd * 2.6, TT + 13.5, SZ - 1.4], 0.8, MARB, mat="Marble"))
# braziers + reflecting pool
for sx in (-1, 1):
    bx_, bz_ = tx_ + sx * 9, tz_ - 4
    life.append(P("TempleBrazierStand", [1.2, 3, 1.2], [bx_, TT + 1.5, bz_], (0.3, 0.27, 0.25), mat="Metal"))
    life.append(P("TempleBrazier", [0.8, 2.6, 2.6], [bx_, TT + 3.2, bz_], (0.35, 0.3, 0.26), rot=CYL_UP, shape="Cylinder", mat="Metal"))
    life.append(D("TempleFlame", [1.6, 1.6, 1.6], [bx_, TT + 4, bz_], (1, 0.6, 0.2), shape="Ball", mat="Neon", transparency=0.15, children=[light((1, 0.6, 0.25), 26, 2)]))
life.append(P("PoolRim", [1.2, 10, 10], [tx_, TT + 0.4, tz_ - 9], MARB2, rot=CYL_UP, shape="Cylinder", mat="Marble"))
life.append(D("PoolWater", [0.2, 8.6, 8.6], [tx_, TT + 0.95, tz_ - 9], (0.35, 0.6, 0.85), rot=CYL_UP, shape="Cylinder", mat="Glass", transparency=0.2))
CH.append((tx_, TT + 2.3, tz_, 2))
life.append(D("TempleLabel", [1, 1, 1], [tx_, ty_ + 42, tz_], (1, 1, 1), transparency=1, children=[label("THE FORGOTTEN TEMPLE", (0.95, 0.9, 0.7), (22, 4), 220)]))
# a BROKEN STONE BRIDGE reaching from the main isle toward SkyIsle1 - it ends mid-air
bx0, bz0 = GX + 200, GZ - 60
for k in range(14):
    if k in (9, 11):
        continue  # gaps: the bridge has collapsed here
    life.append(P("BridgeSlab", [6.2, 1.4, 10], [bx0 + k * 6, GY - 1 - (k > 8) * (k - 8) * 1.5, bz0 - k * 1.4], (0.6, 0.58, 0.55), rot=rot_z(-(k > 8) * 0.12), mat="Cobblestone"))
    if k % 2 == 0:
        for sd in (-1, 1):
            life.append(P("BridgeRail", [1, 3, 1], [bx0 + k * 6, GY + 1.2 - (k > 8) * (k - 8) * 1.5, bz0 - k * 1.4 + sd * 4.6], (0.55, 0.53, 0.5), mat="Cobblestone"))
# the HIDDEN ISLE: far above the main isle, only reachable with wings. A golden chest waits.
HX, HY, HZ = GX + 60, GY + 260, GZ - 40
life.append(g_island("HiddenIsle", HX, HY, HZ, 34, trees=3, lobes=2))
life.append(D("HiddenGlow", [2, 2, 2], [HX, HY + 6, HZ], (1, 0.9, 0.5), mat="Neon", shape="Ball", transparency=0.2, children=[light((1, 0.9, 0.5), 40, 2)]))
CH.append((HX, HY, HZ, 2))
# ======== v1.6 UNDERCAVES + SKY SHRINES ========
def cave(name, cx, cy, cz, yaw, crystal, chest_t=2):
    # a hollow floating rock with a wide mouth facing local +x; glowing crystals inside, a chest at the back
    def W(lx, ly, lz):
        c_, s_ = math.cos(yaw), math.sin(yaw)
        return [cx + lx * c_ + lz * s_, cy + ly, cz - lx * s_ + lz * c_]
    R_ = rot_y(yaw)
    rk = lambda i: NROCK[i % len(NROCK)]
    out = []
    out.append(P("CaveFloor", [46, 4, 40], W(0, -2, 0), rk(0), rot=R_, mat="Slate"))
    out.append(P("CaveRoof", [46, 5, 40], W(0, 18.5, 0), rk(1), rot=R_, mat="Slate"))
    out.append(P("CaveBack", [4, 17, 40], W(-21, 8, 0), rk(2), rot=R_, mat="Slate"))
    for sd in (-1, 1):
        out.append(P("CaveSide", [46, 17, 4], W(0, 8, sd * 18), rk(3), rot=R_, mat="Slate"))
        out.append(P("CaveLip", [5, 17, 9], W(21, 8, sd * 13.5), rk(4), rot=R_, mat="Slate"))
    # rough outer shell: boulders hugging the box (all outside the hollow)
    for k, (lx, ly, lz, sx, sy, sz, a) in enumerate([(-6, 25, -6, 30, 12, 26, 0.3), (8, 24, 8, 26, 10, 22, -0.4), (-18, 12, -16, 16, 22, 16, 0.6), (-18, 10, 16, 18, 20, 14, -0.5),
                                                     (-4, -10, 0, 36, 12, 30, 0.2), (2, -20, 4, 20, 12, 18, -0.6), (-2, -28, -2, 10, 10, 10, 0.8), (12, 6, -22, 22, 18, 8, 0.1), (10, 6, 22, 22, 18, 8, -0.2)]):
        out.append(P("CaveRock", [sx, sy, sz], W(lx, ly, lz), rk(k), rot=mul(R_, rot_y(a)), mat="Slate"))
    out.append(D("CaveMoss", [42, 1.2, 4], W(0, 21.6, 16), NLEAF[0], rot=R_, mat="Grass"))
    out.append(D("CaveMoss", [30, 1.2, 6], W(-4, 31.6, -6), NLEAF[2], rot=R_, mat="Grass"))
    # crystals growing out of floor, walls and roof
    for k in range(16):
        ang = k * 2.4
        lx, lz = -16 + (k * 7.3) % 30, -14 + (k * 5.1) % 28
        h = 3 + (k * 1.7) % 6
        roof = k % 4 == 0
        ly = 15.5 - h / 2 if roof else h / 2
        tilt = mul(R_, mul(rot_y(ang), rot_z(0.35 if k % 2 else -0.3)))
        out.append(P("Crystal", [1.6, h, 1.6], W(lx, ly, lz), crystal, rot=tilt, mat="Neon", transparency=0.15, collide=False))
    for k in range(4):
        out.append(D("CrystalGlow", [1, 1, 1], W(-14 + k * 9, 4, (-1) ** k * 8), crystal, transparency=1, children=[light(crystal, 26, 1.4)]))
    # glow mushrooms + a little pool
    for k in range(6):
        lx, lz = 6 - k * 4, 14 - (k % 2) * 28 + (1 if k % 2 else -1) * 2
        out.append(P("MushStem", [0.6, 2, 0.6], W(lx, 1, lz), (0.9, 0.88, 0.8), rot=R_, mat="SmoothPlastic", collide=False))
        out.append(P("MushCap", [2.4, 0.8, 2.4], W(lx, 2.3, lz), (0.4, 0.9, 1) if crystal[2] > 0.8 else (1, 0.6, 0.9), rot=R_, mat="Neon", transparency=0.1, collide=False))
    out.append(D("CavePool", [0.6, 12, 12], W(-4, 0.05, -6), (0.25, 0.55, 0.75), rot=mul(R_, rot_z(math.pi / 2)), shape="Cylinder", mat="Glass", transparency=0.3))
    out.append(D("CaveLabel", [1, 1, 1], W(0, 26, 0), (1, 1, 1), transparency=1, children=[label(name, (0.85, 0.95, 1), (18, 3.5), 140)]))
    return model(name.title().replace(" ", ""), out), W(-14, 0.05, 0)
# WATERFALL GROTTO: a hollow rock floating beside the Genesis waterfall, mouth facing the falls
gro, gch = cave("WATERFALL GROTTO", GX - 262, GY - 30, GZ + 31, 0.0, (0.45, 0.9, 1.0))
life.append(gro); CH.append((gch[0], gch[1], gch[2], 2))
# CRYSTAL HOLLOW: hanging under the far west sky isle, mouth facing the main isle
cxx, cyy, czz = GX + SAT[3][0] - 95, GY + SAT[3][1] - 70, GZ + SAT[3][2] - 50
hol, hch = cave("CRYSTAL HOLLOW", cxx, cyy, czz, 0.5, (0.8, 0.5, 1.0))
life.append(hol); CH.append((hch[0], hch[1], hch[2], 2))
# three SKY SHRINES (v1.8): a stepped octagonal stone dais, four carved pillars carrying the braziers,
# low arches between them, a glowing rune circle, stone lanterns and a floating shrine crystal.
SHR = [("s1", SAT[0], (1, 0.55, 0.25)), ("s2", SAT[4], (1, 0.55, 0.85)), ("s3", SAT[1], (0.55, 1, 0.85))]
STONE, STONE2, STONE3 = (0.62, 0.6, 0.58), (0.52, 0.5, 0.49), (0.72, 0.7, 0.66)
for sid, (dx, dy, dz, r), glow in SHR:
    sx_, sy_, sz_ = GX + dx, GY + dy, GZ + dz
    for k, (rr, hh) in enumerate([(17, 1.0), (14, 0.8)]):
        for o in range(2):  # octagon from two rotated squares
            life.append(P("ShrineDais", [rr * 1.5, hh, rr * 1.5], [sx_, sy_ + hh / 2 + k * 1.0 + o * 0.01, sz_], [STONE2, STONE][k], rot=rot_y(o * math.pi / 4), mat="Slate"))
    DT = sy_ + 1.8
    life.append(D("ShrineRune", [0.06, 13, 13], [sx_, DT + 0.03, sz_], glow, rot=CYL_UP, shape="Cylinder", mat="Neon", transparency=0.55))
    life.append(D("ShrineRuneIn", [0.07, 11.6, 11.6], [sx_, DT + 0.04, sz_], STONE3, rot=CYL_UP, shape="Cylinder", mat="Slate"))
    life.append(D("ShrineRune2", [0.08, 7, 7], [sx_, DT + 0.05, sz_], glow, rot=CYL_UP, shape="Cylinder", mat="Neon", transparency=0.45))
    life.append(D("ShrineRuneIn2", [0.09, 6, 6], [sx_, DT + 0.06, sz_], STONE3, rot=CYL_UP, shape="Cylinder", mat="Slate"))
    for k in range(8):  # rune glyph strokes between the rings
        a_ = k / 8 * math.tau
        life.append(D("ShrineGlyph", [0.1, 0.3, 1.6], [sx_ + math.cos(a_) * 4.6, DT + 0.07, sz_ + math.sin(a_) * 4.6], glow, rot=rot_y(-a_), mat="Neon", transparency=0.3))
    # the floating crystal
    life.append(D("ShrineCrystal", [1.6, 4.2, 1.6], [sx_, DT + 6, sz_], glow, rot=rot_y(0.785), mat="Neon", transparency=0.1, children=[light(glow, 30, 1.6)]))
    life.append(D("ShrineCrystalTip", [1.2, 1.2, 1.2], [sx_, DT + 8.5, sz_], glow, shape="Ball", mat="Neon", transparency=0.3))
    pil = []
    for k in range(4):
        an = k / 4 * math.tau + 0.785
        bx_, bz_ = sx_ + math.cos(an) * 11, sz_ + math.sin(an) * 11
        pil.append((bx_, bz_))
        life.append(P("ShrinePillarBase", [3.6, 1, 3.6], [bx_, DT + 0.5, bz_], STONE2, rot=rot_y(an), mat="Slate"))
        life.append(P("ShrinePillar", [2.6, 7, 2.6], [bx_, DT + 4.5, bz_], STONE, rot=rot_y(an), mat="Slate"))
        for c in range(3):  # carved bands
            life.append(D("ShrineBand", [2.8, 0.3, 2.8], [bx_, DT + 2 + c * 2.2, bz_], STONE3, rot=rot_y(an), mat="Slate"))
        life.append(D("ShrinePillarGlyph", [0.1, 4, 0.6], [bx_ - math.cos(an) * 1.32, DT + 4.5, bz_ - math.sin(an) * 1.32], glow, rot=rot_y(-an), mat="Neon", transparency=0.35))
        life.append(attr(P("Brazier", [4.2, 1.4, 4.2], [bx_, DT + 8.7, bz_], (0.3, 0.26, 0.24), mat="Metal"), ShrineId=sid, Idx=k + 1))
        life.append(D("BrazierCoal", [3.2, 0.3, 3.2], [bx_, DT + 9.55, bz_], (0.15, 0.1, 0.08), mat="Slate"))
        for f in range(4):  # little brazier feet
            fa = f / 4 * math.tau + 0.785
            life.append(D("BrazierFoot", [0.5, 0.8, 0.5], [bx_ + math.cos(fa) * 1.7, DT + 7.8, bz_ + math.sin(fa) * 1.7], (0.25, 0.22, 0.2), mat="Metal"))
        # stone lantern outside each pillar
        lx_, lz_ = sx_ + math.cos(an) * 16, sz_ + math.sin(an) * 16
        life.append(P("Lantern", [1, 3, 1], [lx_, sy_ + 1.5, lz_], STONE2, mat="Slate"))
        life.append(P("LanternBox", [1.8, 1.4, 1.8], [lx_, sy_ + 3.7, lz_], STONE, mat="Slate"))
        life.append(D("LanternGlow", [1.0, 0.9, 1.0], [lx_, sy_ + 3.7, lz_], glow, mat="Neon", transparency=0.2, children=[light(glow, 12, 1)]))
        life.append(P("LanternRoof", [2.6, 0.5, 2.6], [lx_, sy_ + 4.65, lz_], STONE2, rot=rot_y(0.785), mat="Slate"))
    # low arches between neighbouring pillars (2 segments each, peaked)
    for k in range(4):
        (ax_, az_), (bx_, bz_) = pil[k], pil[(k + 1) % 4]
        mx_, mz_ = (ax_ + bx_) / 2, (az_ + bz_) / 2
        life.append(seg("ShrineArch", [ax_, DT + 7.6, az_], [mx_, DT + 10.4, mz_], 1.1, STONE, mat="Slate", shape="Block"))
        life.append(seg("ShrineArch", [mx_, DT + 10.4, mz_], [bx_, DT + 7.6, bz_], 1.1, STONE, mat="Slate", shape="Block"))
    nm_ = {"s1": "SHRINE OF EMBERS", "s2": "SHRINE OF ECHOES", "s3": "SHRINE OF GALES"}[sid]
    life.append(D("ShrineLabel", [1, 1, 1], [sx_, sy_ + 17, sz_], (1, 1, 1), transparency=1, children=[label(nm_, (1, 0.85, 0.55), (16, 3), 140)]))

# ======== v1.8 GIANT STONE HANDS cradling Quill's Rest from below ========
HUBY = 100
for sd in (-1, 1):
    # forearm rising out of the clouds, wrist, palm under the island, fingers curling up around the rim
    wrist = [sd * 34, HUBY - 52, 6]
    life.append(seg("HandArm", [sd * 52, HUBY - 150, 14], wrist, 17, NROCK[1], mat="Slate"))
    life.append(P("HandWrist", [17, 17, 17], wrist, NROCK[0], shape="Ball", mat="Slate"))
    palm = [sd * 31, HUBY - 40, 0]
    life.append(P("HandPalm", [10, 30, 26], palm, NROCK[0], rot=rot_z(sd * 0.55), mat="Slate"))
    life.append(P("HandPalmPad", [9, 22, 22], [palm[0] + sd * 2, palm[1] - 2, 0], NROCK[2], shape="Ball", mat="Slate"))
    for f in range(4):
        fz = -11 + f * 7.3
        k0 = [sd * 43, HUBY - 33 + abs(f - 1.5) * 1.2, fz]
        k1 = [sd * 51, HUBY - 18, fz * 1.05]
        k2 = [sd * 51, HUBY - 4 - abs(f - 1.5) * 1.5, fz * 1.08]
        k3 = [sd * 45.5, HUBY + 3 - abs(f - 1.5) * 2, fz * 1.08]
        dd = 7.4 - abs(f - 1.5) * 0.7
        for a_, b_, dk in ((k0, k1, dd), (k1, k2, dd * 0.92), (k2, k3, dd * 0.82)):
            life.append(seg("HandFinger", a_, b_, dk, NROCK[(f + 1) % 3], mat="Slate"))
        for kn, dk in ((k1, dd), (k2, dd * 0.92)):
            life.append(P("HandKnuckle", [dk * 1.1, dk * 1.1, dk * 1.1], kn, NROCK[f % 3], shape="Ball", mat="Slate"))
        life.append(P("HandNail", [0.8, dd * 0.6, dd * 0.6], [k3[0] - sd * 0.6, k3[1] + 1, k3[2]], NROCK[2], rot=rot_z(sd * 0.6), mat="Slate"))
        life.append(D("HandMoss", [dd * 0.7, 0.6, dd * 0.9], [k2[0] - sd * 1, k2[1] + dd * 0.45, k2[2]], NLEAF[f % 5], mat="Grass"))
    # thumb wrapping round the front
    t0 = [sd * 38, HUBY - 42, -14]
    t1 = [sd * 40, HUBY - 26, -34]
    t2 = [sd * 30, HUBY - 6, -44]
    life.append(seg("HandThumb", t0, t1, 9, NROCK[1], mat="Slate"))
    life.append(seg("HandThumb", t1, t2, 8, NROCK[0], mat="Slate"))
    life.append(P("HandKnuckle", [9, 9, 9], t1, NROCK[2], shape="Ball", mat="Slate"))
    for v in range(4):
        life.append(D("HandVine", [0.6, 10 + v * 3, 0.6], [sd * (48 - v), HUBY - 30 - v * 4, -8 + v * 6], NLEAF[v % 5], mat="Grass"))

# ======== v1.8 NEW SKY ISLES (inspired by the refs): castle isles with waterfalls, a stone arch, a sky galleon,
# rock spires, and a colossal WORLD TREE far away on the horizon ========
def waterfalls(lst, x, top, z, r, n, length=140):
    for k in range(n):
        a_ = rnd.uniform(0, math.tau)
        ex, ez = x + math.cos(a_) * (r + 0.8), z + math.sin(a_) * (r + 0.8)
        w = rnd.uniform(4, 9)
        L = length * rnd.uniform(0.6, 1.2)
        lst.append(D("Waterfall", [w, L, 1.4], [ex, top - L / 2 - 1, ez], (0.78, 0.9, 1), rot=rot_y(-a_ + math.pi / 2), mat="Glass", transparency=0.3))
        lst.append(D("WaterfallCore", [w * 0.5, L, 1.0], [ex + math.cos(a_) * 0.3, top - L / 2 - 1, ez + math.sin(a_) * 0.3], (0.95, 0.98, 1), rot=rot_y(-a_ + math.pi / 2), mat="Neon", transparency=0.55))
        lst.append(D("FallMist", [w * 2.2, w * 2.2, w * 2.2], [ex, top - L - 2, ez], (1, 1, 1), shape="Ball", transparency=0.75))
        lst.append(D("FallLip", [w + 2, 1.2, 3], [ex - math.cos(a_) * 1.2, top + 0.1, ez - math.sin(a_) * 1.2], (0.5, 0.72, 0.95), rot=rot_y(-a_ + math.pi / 2), mat="Glass", transparency=0.25))
def tower(lst, x, base, z, r, h, roof=(0.55, 0.25, 0.2)):
    WALL, WALL2 = (0.78, 0.72, 0.62), (0.68, 0.62, 0.53)
    lst.append(P("TowerBody", [h, r * 2, r * 2], [x, base + h / 2, z], WALL, rot=CYL_UP, shape="Cylinder", mat="Cobblestone"))
    for b in range(int(h // 10)):
        lst.append(D("TowerBand", [0.6, r * 2 + 0.4, r * 2 + 0.4], [x, base + 6 + b * 10, z], WALL2, rot=CYL_UP, shape="Cylinder", mat="Cobblestone"))
    lst.append(P("TowerRing", [2, r * 2 + 2, r * 2 + 2], [x, base + h + 1, z], WALL2, rot=CYL_UP, shape="Cylinder", mat="Cobblestone"))
    for c in range(10):
        a_ = c / 10 * math.tau
        lst.append(P("Merlon", [1.8, 2.2, 1.2], [x + math.cos(a_) * (r + 0.4), base + h + 3, z + math.sin(a_) * (r + 0.4)], WALL, rot=rot_y(-a_), mat="Cobblestone"))
    # conical roof from stacked shrinking cylinders + spire
    for k in range(7):
        rr = (r + 1.2) * (1 - k / 7)
        lst.append(P("Roof", [2.2, rr * 2, rr * 2], [x, base + h + 3.5 + k * 2.1, z], roof if k % 2 == 0 else tuple(c * 0.88 for c in roof), rot=CYL_UP, shape="Cylinder", mat="Slate"))
    lst.append(P("Spire", [6, 0.5, 0.5], [x, base + h + 20, z], (0.85, 0.7, 0.3), rot=CYL_UP, shape="Cylinder", mat="Metal"))
    for w in range(4):  # glowing windows
        a_ = w / 4 * math.tau + 0.4
        for lv in (0.45, 0.75):
            lst.append(D("Window", [1.4, 2.6, 0.4], [x + math.cos(a_) * (r + 0.05), base + h * lv, z + math.sin(a_) * (r + 0.05)], (1, 0.82, 0.45), rot=rot_y(-a_ + math.pi / 2), mat="Neon", transparency=0.1))
def castle_isle(name, x, top, z, r, towers, falls):
    lst = [g_island(name, x, top, z, r, trees=int(r / 9), lobes=4, lite=True)]
    WALL = (0.75, 0.69, 0.6)
    # keep: a big central tower + smaller towers around, curtain walls between
    tower(lst, x, top, z, r * 0.16, r * 0.9, roof=(0.25, 0.32, 0.55))
    pts = []
    for k in range(towers):
        a_ = k / towers * math.tau + 0.3
        tx2, tz2 = x + math.cos(a_) * r * 0.42, z + math.sin(a_) * r * 0.42
        pts.append((tx2, tz2))
        tower(lst, tx2, top, tz2, r * 0.08, r * rnd.uniform(0.4, 0.6), roof=(0.25, 0.32, 0.55))
    for k in range(towers):
        (ax_, az_), (bx_, bz_) = pts[k], pts[(k + 1) % towers]
        lst.append(seg("CurtainWall", [ax_, top + r * 0.12, az_], [bx_, top + r * 0.12, bz_], r * 0.24, WALL, mat="Cobblestone", shape="Block"))
    waterfalls(lst, x, top, z, r, falls, length=r * 3)
    return model(name, lst)
NEW = []
NEW.append(castle_isle("CastleIsle", -880, 150, 980, 95, 5, 6))
NEW.append(castle_isle("CastleIsle2", -1120, 230, 760, 60, 3, 4))
for (x, y, z, r) in [(-760, 90, 1180, 28), (-1010, 300, 1060, 22), (-1220, 140, 960, 30), (-700, 260, 820, 18)]:
    NEW.append(g_island("CastleRock", x, y, z, r, trees=3, lobes=3, lite=True))
    wf = []
    waterfalls(wf, x, y, z, r, 2, length=r * 3)
    NEW.append(model("CastleRockFalls", wf))
# a giant natural STONE ARCH springing between two isles
A1, A2 = (760, 70, 980), (1060, 110, 1180)
NEW.append(g_island("ArchIsleA", A1[0], A1[1], A1[2], 55, trees=6, lobes=4, lite=True))
NEW.append(g_island("ArchIsleB", A2[0], A2[1], A2[2], 48, trees=5, lobes=4, lite=True))
arc = []
N_ = 14
prev = None
for k in range(N_ + 1):
    u = k / N_
    px = A1[0] + (A2[0] - A1[0]) * u
    pz = A1[2] + (A2[2] - A1[2]) * u
    py = A1[1] + (A2[1] - A1[1]) * u + math.sin(u * math.pi) * 170
    cur = [px, py, pz]
    if prev:
        arc.append(seg("Arch", prev, cur, 26 - math.sin(u * math.pi) * 8, NROCK[k % 3], mat="Slate"))
        arc.append(D("ArchMoss", [10, 2, 14], [cur[0], cur[1] + 11, cur[2]], NLEAF[k % 5], mat="Grass"))
        if k % 3 == 0:
            arc.append(D("ArchVine", [1, 30, 1], [cur[0], cur[1] - 26, cur[2]], NLEAF[k % 5], mat="Grass"))
    prev = cur
NEW.append(model("StoneArch", arc))
# a SKY GALLEON moored to a small isle by chains
GX_, GY_, GZ_ = 1100, 260, 420
gal = []
HULL, HULL2, SAIL = (0.42, 0.27, 0.15), (0.32, 0.2, 0.11), (0.92, 0.9, 0.82)
for k in range(9):
    zz = -32 + k * 8
    w = 16 * math.sin((k + 1) / 10 * math.pi) + 6
    gal.append(P("HullRib", [w, 12, 8.2], [GX_, GY_, GZ_ + zz], HULL if k % 2 else HULL2, mat="WoodPlanks"))
    gal.append(P("HullKeel", [w * 0.6, 6, 8.2], [GX_, GY_ - 8, GZ_ + zz], HULL2, mat="WoodPlanks"))
gal.append(P("Deck", [18, 1, 66], [GX_, GY_ + 6, GZ_], (0.6, 0.45, 0.28), mat="WoodPlanks"))
gal.append(P("Stern", [16, 8, 12], [GX_, GY_ + 10, GZ_ + 30], HULL, mat="WoodPlanks"))
gal.append(P("Bowsprit", [26, 1.4, 1.4], [GX_, GY_ + 10, GZ_ - 44], HULL2, rot=mul(rot_y(math.pi / 2), rot_z(0.25)), shape="Cylinder", mat="Wood"))
for k, (mz, mh) in enumerate([(-16, 50), (6, 60), (24, 40)]):
    gal.append(P("Mast", [mh, 1.6, 1.6], [GX_, GY_ + 6 + mh / 2, GZ_ + mz], HULL2, rot=CYL_UP, shape="Cylinder", mat="Wood"))
    for sl in range(2):
        sy2 = GY_ + 18 + sl * mh * 0.35
        sw = 26 - sl * 6
        gal.append(P("Yard", [sw + 4, 0.8, 0.8], [GX_, sy2 + mh * 0.16, GZ_ + mz], HULL2, shape="Cylinder", mat="Wood"))
        gal.append(D("Sail", [sw, mh * 0.3, 0.4], [GX_, sy2, GZ_ + mz + 0.8], SAIL if (k + sl) % 2 == 0 else (0.35, 0.6, 0.55), mat="Fabric"))
    gal.append(P("CrowNest", [2.5, 4, 4], [GX_, GY_ + 6 + mh - 3, GZ_ + mz], HULL, rot=CYL_UP, shape="Cylinder", mat="WoodPlanks"))
for k in range(6):
    gal.append(D("Lamp", [1.2, 1.2, 1.2], [GX_ + (9.5 if k % 2 else -9.5), GY_ + 8, GZ_ - 25 + k * 10], (1, 0.8, 0.4), shape="Ball", mat="Neon", children=[light((1, 0.75, 0.4), 18, 1.3)]))
NEW.append(model("SkyGalleon", gal))
NEW.append(g_island("GalleonDock", GX_ - 70, GY_ - 20, GZ_ + 10, 32, trees=3, lobes=3, lite=True))
NEW.append(g_chain((GX_ - 44, GY_ - 22, GZ_ + 10), (GX_ - 9, GY_ - 2, GZ_ + 4), sag=10))
NEW.append(g_chain((GX_ - 44, GY_ - 22, GZ_ - 2), (GX_ - 9, GY_ - 2, GZ_ - 26), sag=12))
# ROCK SPIRES: tall thin pillars with a little tree crown, like the refs
for k in range(9):
    an = k / 9 * math.tau + 0.4
    d_ = rnd.uniform(980, 1250)
    x, z = math.cos(an) * d_, 300 + math.sin(an) * d_
    if math.hypot(x - GX_, z - GZ_) < 200 or math.hypot(x + 880, z - 980) < 220 or math.hypot(x - 900, z - 1080) < 260:
        continue
    top = rnd.uniform(60, 260)
    h = rnd.uniform(160, 320)
    sp = []
    rr = rnd.uniform(14, 24)
    y = top
    while y > top - h:
        hh = rnd.uniform(16, 30)
        sp.append(P("Spire", [hh, rr * 2, rr * 2], [x + rnd.uniform(-2, 2), y - hh / 2, z + rnd.uniform(-2, 2)], NROCK[int(y) % 3], rot=mul(rot_y(rnd.uniform(0, 3)), CYL_UP), shape="Cylinder", mat="Slate"))
        y -= hh * 0.9
        rr *= rnd.uniform(0.8, 0.95)
    NEW.append(model("RockSpire", sp))
    NEW.append(g_island("SpireTop", x, top + 1, z, max(14, rr * 1.2 + 6), trees=2, lobes=2, lite=True))
# the WORLD TREE (v1.8b): a colossal tree growing out of its own floating island. Roots grip the island and
# drape off its edges, boughs fork into branches, a layered canopy with moss curtains, glowing fruit, little
# satellite isles caught in its roots - and FAIRIES (animated client-side around the "FairyZone" anchors).
WT = (1500, 60, 2900)
WTH = 900
NEW.append(g_island("WorldTreeIsle", WT[0], WT[1], WT[2], 240, trees=10, lobes=6, lite=True, water=True))
wt = []
BARK, BARK2, BARK3 = (0.36, 0.25, 0.17), (0.3, 0.2, 0.13), (0.42, 0.3, 0.2)
for k in range(10):  # trunk, gently twisting and tapering, flared at the base
    y0 = WT[1] + k * WTH / 10
    rr = (78 - k * 4.6) * (1.35 if k == 0 else 1)
    wt.append(P("WTTrunk", [WTH / 10 + 6, rr * 2, rr * 2], [WT[0] + math.sin(k * 0.5) * 10, y0 + WTH / 20, WT[2] + math.cos(k * 0.4) * 6], BARK if k % 2 else BARK2, rot=mul(rot_y(k * 0.7), CYL_UP), shape="Cylinder", mat="Wood"))
for k in range(14):  # bark ridges spiralling up
    a_ = k / 14 * math.tau
    wt.append(seg("WTRidge", [WT[0] + math.cos(a_) * 84, WT[1], WT[2] + math.sin(a_) * 84], [WT[0] + math.cos(a_ + 1.1) * 40, WT[1] + WTH * 0.85, WT[2] + math.sin(a_ + 1.1) * 40], 18 + (k % 3) * 4, BARK3 if k % 2 else BARK2, mat="Wood"))
for k in range(5):  # hollows / knots
    a_ = k * 1.3
    hy = WT[1] + 120 + k * 140
    rr = 78 - (hy - WT[1]) / WTH * 46
    wt.append(D("WTKnot", [22, 22, 22], [WT[0] + math.cos(a_) * rr, hy, WT[2] + math.sin(a_) * rr], BARK2, shape="Ball", mat="Wood"))
for k in range(12):  # great roots: over the grass, down over the rim, trailing into the sky
    a_ = k / 12 * math.tau + 0.1
    r0 = [WT[0] + math.cos(a_) * 70, WT[1] + 20, WT[2] + math.sin(a_) * 70]
    r1 = [WT[0] + math.cos(a_) * 150, WT[1] + 4, WT[2] + math.sin(a_) * 150]
    r2 = [WT[0] + math.cos(a_ + 0.08) * 235, WT[1] - 10, WT[2] + math.sin(a_ + 0.08) * 235]
    r3 = [WT[0] + math.cos(a_ + 0.15) * 265, WT[1] - 140 - (k % 3) * 50, WT[2] + math.sin(a_ + 0.15) * 265]
    r4 = [WT[0] + math.cos(a_ + 0.2) * 250, WT[1] - 330 - (k % 4) * 60, WT[2] + math.sin(a_ + 0.2) * 250]
    for (u, v, d_) in ((r0, r1, 34), (r1, r2, 24), (r2, r3, 18), (r3, r4, 10)):
        wt.append(seg("WTRoot", u, v, d_, BARK2 if k % 2 else BARK, mat="Wood"))
    wt.append(D("WTRootMoss", [18, 3, 26], [r1[0], r1[1] + 11, r1[2]], NLEAF[k % 5], rot=rot_y(-a_), mat="Grass"))
LEAFW = [(0.2, 0.42, 0.22), (0.25, 0.5, 0.24), (0.17, 0.36, 0.2), (0.3, 0.55, 0.3), (0.35, 0.6, 0.32)]
tips = []
for k in range(9):  # main boughs, each forking into two branches ending in leaf clusters
    a_ = k / 9 * math.tau + rnd.uniform(-0.15, 0.15)
    by = WT[1] + WTH * (0.62 + (k % 3) * 0.09)
    b0 = [WT[0] + math.cos(a_) * 20, by, WT[2] + math.sin(a_) * 20]
    L = rnd.uniform(240, 330)
    b1 = [WT[0] + math.cos(a_) * L, by + rnd.uniform(110, 190), WT[2] + math.sin(a_) * L]
    wt.append(seg("WTBough", b0, b1, 34, BARK, mat="Wood"))
    wt.append(P("WTElbow", [36, 36, 36], b1, BARK2, shape="Ball", mat="Wood"))
    for f in (-0.45, 0.45):
        b2 = [b1[0] + math.cos(a_ + f) * 160, b1[1] + rnd.uniform(40, 120), b1[2] + math.sin(a_ + f) * 160]
        wt.append(seg("WTBranch", b1, b2, 18, BARK3, mat="Wood"))
        tips.append(b2)
        for t in range(2):  # twigs
            b3 = [b2[0] + rnd.uniform(-70, 70), b2[1] + rnd.uniform(20, 60), b2[2] + rnd.uniform(-70, 70)]
            wt.append(seg("WTTwig", b2, b3, 7, BARK3, mat="Wood"))
            tips.append(b3)
for k, (x, y, z) in enumerate(tips):  # leaf clusters on every branch tip (canopy built from many clumps)
    for c in range(2):
        sz = rnd.uniform(110, 170) * (1.2 if c == 0 else 0.8)
        wt.append(P("WTLeaves", [sz, sz * 0.62, sz], [x + rnd.uniform(-40, 40), y + 20 + c * 40, z + rnd.uniform(-40, 40)], LEAFW[(k + c) % 5], shape="Ball", mat="Grass", collide=False))
for k in range(10):  # crown over the trunk
    a_ = k / 10 * math.tau
    sz = rnd.uniform(200, 280)
    wt.append(P("WTCrown", [sz, sz * 0.6, sz], [WT[0] + math.cos(a_) * 120, WT[1] + WTH + 60 + (k % 3) * 40, WT[2] + math.sin(a_) * 120], LEAFW[k % 5], shape="Ball", mat="Grass", collide=False))
wt.append(P("WTCrown", [300, 200, 300], [WT[0], WT[1] + WTH + 150, WT[2]], LEAFW[1], shape="Ball", mat="Grass", collide=False))
for k in range(26):  # moss curtains hanging under the canopy
    x, y, z = tips[k * 3 % len(tips)]
    L = rnd.uniform(40, 110)
    wt.append(D("WTMossCurtain", [3, L, 3], [x + rnd.uniform(-30, 30), y - L / 2 - 10, z + rnd.uniform(-30, 30)], NLEAF[k % 5], mat="Grass", transparency=0.1))
for k in range(28):  # glowing fruit
    x, y, z = tips[rnd.randrange(len(tips))]
    wt.append(D("WTFruit", [7, 7, 7], [x + rnd.uniform(-50, 50), y - rnd.uniform(5, 30), z + rnd.uniform(-50, 50)], (1, 0.85, 0.45) if k % 3 else (0.7, 1, 0.8), shape="Ball", mat="Neon", transparency=0.1))
# fairy anchors: the client spawns little fairies around each of these
for k in range(6):
    a_ = k / 6 * math.tau
    wt.append(attr(D("FairyZone", [1, 1, 1], [WT[0] + math.cos(a_) * 200, WT[1] + 120 + (k % 3) * 260, WT[2] + math.sin(a_) * 200], (1, 1, 1), transparency=1), R=170, N=7))
wt.append(attr(D("FairyZone", [1, 1, 1], [WT[0], WT[1] + 30, WT[2]], (1, 1, 1), transparency=1), R=150, N=10))
NEW.append(model("WorldTree", wt))
for k in range(4):  # little isles caught in the hanging roots
    a_ = k / 4 * math.tau + 0.4
    NEW.append(g_island("RootIsle", WT[0] + math.cos(a_) * 330, WT[1] - 160 - k * 40, WT[2] + math.sin(a_) * 330, rnd.uniform(26, 40), trees=3, lobes=3, lite=True))
life.append(folder("V18Isles", NEW))
# ======== v1.8c SHIPS: rideable sky skiffs, little sailboats + balloon ships, and a colossal sky ark ========
def skiff(x, y, z, yaw, col=(0.55, 0.36, 0.2), sail=(0.95, 0.92, 0.84)):
    W = yawpt(x, y, z, yaw)
    r_ = rot_y(yaw)
    dark = tuple(c * 0.75 for c in col)
    ch = [P("SkiffHull", [9, 1, 22], W(0, 0, 0), (0.62, 0.46, 0.3), rot=r_, mat="WoodPlanks")]
    for k in range(5):  # rounded hull sides from stacked planks
        zz = -9 + k * 4.5
        w = 9 * math.sin((k + 1) / 6 * math.pi) + 1.5
        ch.append(P("SkiffSide", [w, 3.2, 4.6], W(0, -1.8, zz), col if k % 2 else dark, rot=r_, mat="WoodPlanks"))
        ch.append(P("SkiffKeel", [w * 0.5, 2, 4.6], W(0, -4, zz), dark, rot=r_, mat="WoodPlanks"))
    for sd in (-1, 1):
        ch.append(P("SkiffRail", [0.6, 1.4, 20], W(sd * 4.3, 1.2, 0), dark, rot=r_, mat="Wood"))
        # little gliding wings / fins on the sides
        ch.append(P("SkiffFin", [10, 0.5, 6], W(sd * 9, -1, 2), sail, rot=mul(r_, rot_z(sd * -0.2)), mat="Fabric"))
        ch.append(P("SkiffFinBone", [10.5, 0.7, 0.7], W(sd * 9, -0.6, -0.8), dark, rot=mul(r_, rot_z(sd * -0.2)), mat="Wood"))
    ch.append(P("SkiffBow", [3, 3, 4], W(0, -0.6, -12.5), dark, rot=mul(r_, rot_y(math.pi)), mat="WoodPlanks", cls="WedgePart"))
    ch.append(P("SkiffMast", [14, 0.8, 0.8], W(0, 7.5, -3), dark, rot=mul(r_, CYL_UP), shape="Cylinder", mat="Wood"))
    ch.append(P("SkiffSail", [8, 9, 0.3], W(0, 8.5, -2.4), sail, rot=r_, mat="Fabric"))
    ch.append(P("SkiffYard", [9.5, 0.5, 0.5], W(0, 13.2, -2.6), dark, rot=r_, shape="Cylinder", mat="Wood"))
    ch.append(P("SkiffFlag", [2.4, 1.4, 0.1], W(1.2, 15, -3), (0.85, 0.25, 0.25), rot=r_, mat="Fabric"))
    ch.append(P("SkiffWheel", [0.4, 3, 3], W(0, 2.6, 6), dark, rot=mul(r_, rot_y(math.pi / 2)), shape="Cylinder", mat="Wood"))
    ch.append(P("SkiffProp", [0.4, 5, 1], W(0, -1, 11.6), (0.6, 0.6, 0.65), rot=r_, mat="Metal"))
    ch.append(P("SkiffLamp", [1, 1, 1], W(0, 2, -10), (1, 0.8, 0.4), rot=r_, shape="Ball", mat="Neon", children=[light((1, 0.8, 0.45), 16, 1.2)]))
    ch.append(attr(P("SkiffHelm", [1, 1, 1], W(0, 1.1, 8.2), (1, 1, 1), rot=r_, transparency=1, collide=False), Yaw=yaw))
    return model("Skiff", ch)
SHIPS = []
for (x, y, z, yaw, col) in [(GX + 252, GY - 3, GZ - 20, 0.0, (0.55, 0.36, 0.2)), (GX - 252, GY - 3, GZ + 40, 0.0, (0.3, 0.42, 0.6)),
                            (GX + 20, GY - 3, GZ - 232, math.pi / 2, (0.6, 0.25, 0.25)), (GX + SAT[2][0] + 115, GY + SAT[2][1] - 3, GZ + SAT[2][2], 0.0, (0.35, 0.5, 0.3))]:
    SHIPS.append(skiff(x, y, z, yaw, col))
def sailboat(x, y, z, yaw, s_=1.0):
    W = yawpt(x, y, z, yaw)
    r_ = rot_y(yaw)
    ch = []
    for k in range(4):
        zz = (-6 + k * 4) * s_
        w = (7 * math.sin((k + 1) / 5 * math.pi) + 1) * s_
        ch.append(P("BoatHull", [w, 3 * s_, 4.2 * s_], W(0, 0, zz), (0.5, 0.33, 0.2) if k % 2 else (0.42, 0.27, 0.16), rot=r_, mat="WoodPlanks"))
    ch.append(P("BoatMast", [12 * s_, 0.6 * s_, 0.6 * s_], W(0, 7 * s_, 0), (0.35, 0.23, 0.14), rot=mul(r_, CYL_UP), shape="Cylinder", mat="Wood"))
    ch.append(D("BoatSail", [0.3 * s_, 9 * s_, 7 * s_], W(0, 7.5 * s_, 1 * s_), (0.95, 0.93, 0.86), rot=mul(r_, rot_y(math.pi / 2)), mat="Fabric"))
    ch.append(D("BoatLamp", [0.9 * s_] * 3, W(0, 2 * s_, -7.5 * s_), (1, 0.8, 0.4), shape="Ball", mat="Neon"))
    return model("SkyBoat", ch)
def balloon_ship(x, y, z, yaw, s_=1.0, col=(0.85, 0.35, 0.3)):
    W = yawpt(x, y, z, yaw)
    r_ = rot_y(yaw)
    ch = [P("Envelope", [18 * s_, 12 * s_, 30 * s_], W(0, 16 * s_, 0), col, rot=r_, shape="Ball" if False else "Block", mat="Fabric")]
    ch[0] = P("Envelope", [16 * s_, 16 * s_, 16 * s_], W(0, 16 * s_, 0), col, shape="Ball", mat="Fabric")
    ch.append(P("EnvelopeFront", [12 * s_, 12 * s_, 12 * s_], W(0, 16 * s_, -9 * s_), col, shape="Ball", mat="Fabric"))
    ch.append(P("EnvelopeBack", [12 * s_, 12 * s_, 12 * s_], W(0, 16 * s_, 9 * s_), col, shape="Ball", mat="Fabric"))
    ch.append(D("EnvelopeBand", [0.6 * s_, 16.4 * s_, 16.4 * s_], W(0, 16 * s_, 0), (0.95, 0.85, 0.5), rot=mul(r_, rot_y(math.pi / 2)), shape="Cylinder", mat="Fabric"))
    ch.append(P("Gondola", [6 * s_, 3 * s_, 14 * s_], W(0, 0, 0), (0.45, 0.3, 0.18), rot=r_, mat="WoodPlanks"))
    for sx in (-1, 1):
        for sz in (-1, 1):
            ch.append(seg("Rope", W(sx * 2.6 * s_, 1.5 * s_, sz * 6 * s_), W(sx * 5 * s_, 10 * s_, sz * 8 * s_), 0.2 * s_, (0.3, 0.25, 0.2), mat="Fabric", collide=False))
    ch.append(P("Fin", [0.4 * s_, 6 * s_, 6 * s_], W(0, 16 * s_, 17 * s_), (0.95, 0.85, 0.5), rot=r_, mat="Fabric"))
    ch.append(D("GondolaLamp", [1 * s_] * 3, W(0, 0, -7.5 * s_), (1, 0.8, 0.4), shape="Ball", mat="Neon"))
    return model("BalloonShip", ch)
for k in range(7):
    an = k / 7 * math.tau + 0.3
    d_ = rnd.uniform(500, 1200)
    SHIPS.append(sailboat(math.cos(an) * d_, rnd.uniform(60, 320), 300 + math.sin(an) * d_, rnd.uniform(0, math.tau), rnd.uniform(0.9, 1.6)))
for k in range(5):
    an = k / 5 * math.tau + 1.0
    d_ = rnd.uniform(600, 1300)
    SHIPS.append(balloon_ship(math.cos(an) * d_, rnd.uniform(160, 460), 300 + math.sin(an) * d_, rnd.uniform(0, math.tau), rnd.uniform(1.2, 2.4), [(0.85, 0.35, 0.3), (0.3, 0.5, 0.85), (0.95, 0.8, 0.3), (0.5, 0.75, 0.45), (0.75, 0.45, 0.8)][k]))
# THE SKY ARK: a colossal flying ship (~520 studs) that slowly circles the far sky (moved client-side)
def sky_ark():
    ch = []
    HU, HU2, GLD = (0.36, 0.24, 0.15), (0.28, 0.18, 0.11), (0.85, 0.7, 0.3)
    L = 520
    for k in range(14):
        zz = -L / 2 + (k + 0.5) * L / 14
        w = 110 * math.sin((k + 0.6) / 14.6 * math.pi) + 20
        ch.append(P("ArkHull", [w, 60, L / 14 + 2], [0, 0, zz], HU if k % 2 else HU2, mat="WoodPlanks"))
        ch.append(D("ArkKeel", [w * 0.55, 40, L / 14 + 2], [0, -45, zz], HU2, mat="WoodPlanks"))
        ch.append(D("ArkKeel2", [w * 0.2, 30, L / 14 + 2], [0, -75, zz], HU, mat="WoodPlanks"))
        ch.append(P("ArkTrim", [w + 2, 4, L / 14 + 2.5], [0, 26, zz], GLD, mat="Metal"))
        for sd in (-1, 1):
            if k % 2 == 0 and 1 < k < 13:
                ch.append(D("ArkPort", [1, 6, 8], [sd * (w / 2 + 0.3), 6, zz], (1, 0.8, 0.45), mat="Neon"))
    ch.append(P("ArkDeck", [100, 3, L - 40], [0, 31, 0], (0.6, 0.45, 0.28), mat="WoodPlanks"))
    ch.append(P("ArkCastle", [90, 50, 70], [0, 56, L / 2 - 60], HU, mat="WoodPlanks"))
    ch.append(P("ArkCastleRoof", [96, 6, 76], [0, 84, L / 2 - 60], GLD, mat="Metal"))
    ch.append(P("ArkBow", [60, 50, 70], [0, 0, -L / 2 - 30], HU2, rot=rot_y(math.pi), mat="WoodPlanks", cls="WedgePart"))
    ch.append(seg("ArkBowsprit", [0, 30, -L / 2 - 20], [0, 90, -L / 2 - 160], 8, HU2, mat="Wood", collide=False))
    for k, (mz, mh) in enumerate([(-170, 300), (-40, 360), (90, 300)]):
        ch.append(D("ArkMast", [mh, 9, 9], [0, 31 + mh / 2, mz], HU2, rot=CYL_UP, shape="Cylinder", mat="Wood"))
        for sl in range(3):
            sy = 31 + mh * (0.3 + sl * 0.25)
            sw = 180 - sl * 40
            ch.append(D("ArkYard", [sw + 20, 4, 4], [0, sy + mh * 0.12, mz], HU2, shape="Cylinder", mat="Wood"))
            ch.append(D("ArkSail", [sw, mh * 0.22, 2], [0, sy, mz + 4], (0.95, 0.92, 0.84) if (k + sl) % 2 == 0 else (0.75, 0.25, 0.25), mat="Fabric"))
        ch.append(D("ArkFlag", [40, 18, 1], [20, 31 + mh + 10, mz], (0.85, 0.7, 0.3), mat="Fabric"))
    for sd in (-1, 1):  # great feathered wings on the sides
        for f in range(7):
            ch.append(D("ArkWing", [180 - f * 16, 6, 34], [sd * (60 + (180 - f * 16) / 2), -10 - f * 4, -60 + f * 26], (0.95, 0.94, 0.9) if f % 2 == 0 else (0.85, 0.83, 0.78), rot=rot_z(sd * (0.12 + f * 0.04)), mat="Fabric"))
    for k in range(6):
        ch.append(D("ArkLantern", [10, 10, 10], [(k % 2 * 2 - 1) * 45, 40, -200 + k * 80], (1, 0.8, 0.4), shape="Ball", mat="Neon", children=[light((1, 0.75, 0.4), 60, 2)]))
    return model("SkyArk", ch)
def _shift(m, off):
    for c in m.get("children", []):
        pr = c.get("properties", {})
        cf = pr.get("CFrame")
        if cf:
            pp = cf["CFrame"]["position"]
            cf["CFrame"]["position"] = [pp[0] + off[0], pp[1] + off[1], pp[2] + off[2]]
        _shift(c, off)
ark = sky_ark()
_shift(ark, (2600, 520, 300))
ark["children"].append(attr(D("ArkPath", [1, 1, 1], [0, 520, 300], (1, 1, 1), transparency=1), R=2600, Speed=0.004))
SHIPS.append(ark)
life.append(folder("Ships", SHIPS))

for i, (x, y, z, t) in enumerate(CH):
    life.append(chest(i + 1, x, y, z, yaw=i * 1.3, tier=t))
N_CHESTS = len(CH)
# the FAR HORIZON: a wide ring of distant islands so the sky never ends (low detail, no trees on most)
for i in range(11):  # v1.8c: fewer but bigger, at very different heights
    an = i / 11 * math.tau + rnd.uniform(-0.1, 0.1)
    d_ = rnd.uniform(1600, 2400)
    fx, fz = math.cos(an) * d_, -60 + math.sin(an) * d_
    if math.hypot(fx - 1500, fz - 2900) < 700:
        continue
    life.append(g_island("FarIsle", fx, rnd.uniform(-150, 600), fz, rnd.uniform(110, 210), trees=rnd.randrange(2, 7), lobes=4, lite=True))
genesis.append(folder("Life", life))
print("chests:", N_CHESTS)

E_ = []
def realm_world(keep, extra, sp):
    allf = {"Islands": islands, "Deco": deco, "Clouds": clouds, "Storm": storm, "Ocean": ocean, "Depths": depths, "Cosmos": cosmos, "Heaven": heaven, "Hell": hell, "Abyss": abyss, "Unknown": unknown}
    ch = [folder(n, (lst if n in keep else E_)) for n, lst in allf.items()]
    ch.append(folder("Gate", extra))
    ch.append(sp)
    return {"className": "Model", "children": ch}
import check_zfight as _zf
os.makedirs("src/Workspace", exist_ok=True)
os.makedirs("src/Realms", exist_ok=True)
worlds = {
    "src/Workspace/World.model.json": realm_world({"Islands", "Deco", "Clouds", "Storm", "Ocean", "Depths"}, genesis, spawn),
    "src/Realms/Celestial.model.json": realm_world({"Cosmos", "Heaven"}, cel_gate, spawn_at(0, 3955.5, 0)),
    "src/Realms/Underworld.model.json": realm_world({"Hell", "Abyss", "Unknown"}, und_gate, spawn_at(0, -4044.5, 0)),
}
def cnt(n): return 1 + sum(cnt(c) for c in n.get("children", []))
for path, w in worlds.items():
    print(path, "z-fight fixes:", _zf.fix(w), "instances:", cnt(w))
    json.dump(w, open(path, "w"))
