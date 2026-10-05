"""render one World folder from src/Workspace/World.model.json to a PNG.
usage: python3 tools/render_zone.py <Folder> <out.png> [elev] [azim] [ymin] [ymax]"""
import json, sys, numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import os
w = json.load(open(os.environ.get("WORLD", "src/Workspace/World.model.json")))
folder = next(c for c in w["children"] if c.get("name") == sys.argv[1])
out, elev, azim = sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 25, float(sys.argv[4]) if len(sys.argv) > 4 else -60
ymin = float(sys.argv[5]) if len(sys.argv) > 5 else -1e9
ymax = float(sys.argv[6]) if len(sys.argv) > 6 else 1e9
def solids(n, o):
    pr = n.get("properties", {})
    if "CFrame" in pr and "Size" in pr and pr.get("Transparency", 0) < 0.95: o.append((n.get("className"), pr))
    for c in n.get("children", []): solids(c, o)
def verts(cls, pr):
    sx, sy, sz = [v / 2 for v in pr["Size"]]
    R = np.array(pr["CFrame"]["CFrame"]["orientation"]); p = np.array(pr["CFrame"]["CFrame"]["position"])
    shape = pr.get("Shape")
    if cls == "WedgePart":
        L = [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, -sy, sz), (-sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)]
        F = [[0, 1, 2, 3], [3, 2, 4, 5], [0, 1, 4, 5], [0, 3, 5], [1, 2, 4]]
    elif shape == "Cylinder":
        r = min(sy, sz); ang = np.linspace(0, 2 * np.pi, 13)[:-1]
        L = [(x, r * np.cos(a), r * np.sin(a)) for x in (-sx, sx) for a in ang]
        n = 12; F = [list(range(n)), list(range(n, 2 * n))] + [[i, (i + 1) % n, n + (i + 1) % n, n + i] for i in range(n)]
    else:
        if shape == "Ball":
            s = min(sx, sy, sz); ang = np.linspace(0, 2 * np.pi, 9)[:-1]; lat = [-0.7, 0, 0.7]
            L = [(s * np.cos(b) * np.cos(a), s * np.sin(b), s * np.cos(b) * np.sin(a)) for b in lat for a in ang]
            F = [[j * 8 + i, j * 8 + (i + 1) % 8, (j + 1) * 8 + (i + 1) % 8, (j + 1) * 8 + i] for j in range(2) for i in range(8)]
        else:
            L = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
            F = [[0, 1, 3, 2], [4, 5, 7, 6], [0, 1, 5, 4], [2, 3, 7, 6], [0, 2, 6, 4], [1, 3, 7, 5]]
    V = [R @ np.array(v) + p for v in L]
    return [[V[i] for i in f] for f in F]
s = []; solids(folder, s)
polys, cols = [], []
for cls, pr in s:
    pp = pr["CFrame"]["CFrame"]["position"]
    if not (ymin <= pp[1] <= ymax): continue
    import os
    if os.environ.get("R") and (pp[0] ** 2 + pp[2] ** 2) ** 0.5 > float(os.environ["R"]): continue
    c = pr.get("Color", [0.7, 0.7, 0.7]); tr = pr.get("Transparency", 0)
    for f in verts(cls, pr):
        polys.append([(v[0], v[2], v[1]) for v in f]); cols.append((*c, 1 - tr * 0.8))
fig = plt.figure(figsize=(14, 10), dpi=90); ax = fig.add_subplot(111, projection="3d")
ax.add_collection3d(Poly3DCollection(polys, facecolors=cols, edgecolors=(0, 0, 0, 0.15), linewidths=0.2))
P = np.array([v for p in polys for v in p]); mn, mx = P.min(0), P.max(0); c = (mn + mx) / 2; r = (mx - mn).max() / 2
ax.set_xlim(c[0] - r, c[0] + r); ax.set_ylim(c[1] - r, c[1] + r); ax.set_zlim(c[2] - r * 0.5, c[2] + r * 0.5)
ax.view_init(elev, azim); ax.set_box_aspect((1, 1, 0.5)); ax.set_facecolor((0.75, 0.85, 1)); fig.patch.set_facecolor((0.75, 0.85, 1))
plt.axis("off"); plt.tight_layout(); plt.savefig(out); print("rendered", len(polys), "polys")
