"""Design a cross-legged (sukhasana) meditation pose for a Heavensunder 15-joint rig.

Works in the rig's authored frame: faces -Z, left = -X, joint C0/C1 rotations
are identity. Outputs PoseLibrary.put() arguments (limb x-angles pre-negated
exactly like put() expects).

This is the generalised version of the script that produced the v0.4.1
meditation pose. It now loads the rig from a .rbxmx (exported with
`lune run lune/inspect.luau export <Path> rig.rbxmx`) instead of the old
report dump, and takes hip height / scale as arguments.

Usage (run from python/checks/):
    pip install -r ../requirements.txt
    lune run ../../lune/inspect.luau export Workspace.Actors.NPCs.Mei_Lan mei.rbxmx   # from repo root
    python pose_design.py mei.rbxmx                      # prints JSON of put() args
    python pose_design.py mei.rbxmx --luau               # prints Luau put() lines for PoseLibrary
    python pose_design.py mei.rbxmx --hip-height 0.70 --out pose.json
    python pose_design.py --from-dump Mei_Lan --pkl /tmp/n.pkl   # legacy v0.4.1 path
"""

import argparse
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rigsim import Rx, load_from_dump, load_from_rbxmx, put, solve  # noqa: E402

try:
    from scipy.optimize import minimize
except ImportError:
    minimize = None

# ---------------------------------------------------------------- frames
def nrm(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def frame(bone_dir, front_hint):
    """part rotation whose local -Y runs along bone_dir and local -Z faces front_hint"""
    Y = -nrm(bone_dir)
    f = np.asarray(front_hint, float)
    f = f - (f @ Y) * Y
    Z = -nrm(f)
    X = np.cross(Y, Z)
    return np.column_stack((X, Y, Z))


def frame_xz(x_axis, z_axis):
    X = nrm(x_axis)
    Z = np.asarray(z_axis, float)
    Z = nrm(Z - (Z @ X) * X)
    Y = np.cross(Z, X)
    return np.column_stack((X, Y, Z))


def euler_xyz(R):
    b = math.asin(max(-1, min(1, R[0, 2])))
    a = math.atan2(-R[1, 2], R[2, 2])
    c = math.atan2(-R[0, 1], R[0, 0])
    return a, b, c


LIMB = ('Shoulder', 'Elbow', 'Hip', 'Knee', 'Ankle')


def to_put(name, R, pos=(0, 0, 0)):
    a, b, c = euler_xyz(R)  # actual joint rotation (what AnimationManager ends up applying)
    return (a, b, c) + tuple(pos)


BIND_HIP = 2.34  # hip joint height in bind pose, rig units
HIP_H_DEFAULT = 0.64  # hip joint height above floor when seated, rig units


def leg_targets(side):
    """side=-1 left, +1 right. world-aligned target rotations for thigh, shin, foot"""
    sx = side
    thigh = nrm((0.74 * sx, -0.22, -0.64))
    # shins cross in front of the pelvis; right shin rides slightly higher & further forward
    if side < 0:
        shin = nrm((1.0, -0.08, 0.12))
    else:
        shin = nrm((-1.0, 0.05, -0.02))
    Rt = frame(thigh, (0.25 * sx, 1, -0.25))  # kneecap faces up / slightly out
    Rs = frame(shin, (0, 1, -0.35))  # shin front faces up
    toes = nrm((-sx * 1.0, 0.0, -0.15))  # toes continue past the opposite knee
    # outer edge of the foot rests on the floor: left foot's -X (outer) points down
    X = (0, 1, 0) if side < 0 else (0, -1, 0)
    Rf = frame_xz(X, -toes)
    return Rt, Rs, Rf


def solve_pose(rig, scale, hip_h=HIP_H_DEFAULT):
    drop = BIND_HIP - hip_h  # Root translation (x scale)
    p = {}
    put(p, 'Root', 0, 0, 0, 0, -drop * scale, 0)
    lean = -0.06
    put(p, 'Waist', lean, 0, 0)
    put(p, 'Neck', -0.16, 0, 0)
    for side, L in ((-1, 'Left'), (1, 'Right')):
        Rt, Rs, Rf = leg_targets(side)
        p[L + 'Hip'] = to_put(L + 'Hip', Rt)
        p[L + 'Knee'] = to_put(L + 'Knee', Rt.T @ Rs)
        p[L + 'Ankle'] = to_put(L + 'Ankle', Rs.T @ Rf)
    # arms: optimise shoulder/elbow/wrist so the palm rests on top of the knee
    if minimize is None:
        raise SystemExit("scipy is required for the arm fit: pip install -r ../requirements.txt")
    byname = {q['name']: k for k, q in rig.parts.items()}

    def arm_cost(v, L, side, target):
        q = dict(p)
        q[L + 'Shoulder'] = (v[0], v[1], v[2], 0, 0, 0)
        q[L + 'Elbow'] = (v[3], 0, 0, 0, 0, 0)
        q[L + 'Wrist'] = (v[4], v[5], 0, 0, 0, 0)
        w = solve(rig, q)
        hand = w[byname[L + 'Hand']]
        elbow = w[byname[L + 'LowerArm']]
        hc = hand[:3, 3]
        cost = np.sum((hc - target) ** 2) * 20
        # palm down: hand local -Y should point forward/down-ish, hand's -Z face forward-out
        cost += (hand[:3, 1] @ np.array([0, 1, 0]) - 0.0) ** 2 * 0.6 + (hand[:3, 2] @ np.array([0, 0, 1]) - 0.0) ** 2 * 0.2
        # keep elbows out and a bit back (relaxed), not inside the torso
        cost += max(0, (1.05 * scale) - abs(elbow[0, 3] - root_x)) ** 2 * 4 + max(0, elbow[2, 3] - root[2, 3] - 0.15 * scale) ** 2 * 3
        cost += 0.02 * np.sum(np.array(v) ** 2)
        return cost

    root = rig.parts[byname['HumanoidRootPart']]['cf']
    root_x = root[0, 3]
    out = {}
    for side, L in ((-1, 'Left'),):
        # hands rest in the lap (dhyana): just in front of the pelvis, on top of the crossed shins
        target = root[:3, 3] + np.array([side * 0.30 * scale, (-3 + hip_h + 0.52) * scale, -0.80 * scale])
        best = None
        for x0 in ([0.9, 0, 0.2 * side * -1, -0.9, 0.4, 0], [1.3, 0.3 * side, 0, -0.6, 0.3, 0], [0.6, -0.2 * side, -0.3 * side, -1.2, 0.5, 0]):
            r = minimize(arm_cost, x0, args=(L, side, target), method='Nelder-Mead',
                         options=dict(maxiter=4000, xatol=1e-4, fatol=1e-7))
            if best is None or r.fun < best.fun:
                best = r
        v = best.x
        p[L + 'Shoulder'] = (v[0], v[1], v[2], 0, 0, 0)
        p[L + 'Elbow'] = (v[3], 0, 0, 0, 0, 0)
        p[L + 'Wrist'] = (v[4], v[5], 0, 0, 0, 0)
        out[L] = (best.fun, np.linalg.norm(solve(rig, p)[byname[L + 'Hand']][:3, 3] - target))
    for j in ('Shoulder', 'Elbow', 'Wrist'):
        x, y, z, a, b, c = p['Left' + j]
        p['Right' + j] = (x, -y, -z, -a, b, c)  # mirror across the body's YZ plane
    return p, out


def as_put_args(p, scale):
    """convert solved pose back into put(...) literal arguments"""
    args = {}
    for k, v in p.items():
        x, y, z, px, py, pz = v
        if any(s in k for s in LIMB):
            x = -x
        args[k] = [round(x, 3), round(y, 3), round(z, 3),
                   round(px / scale, 3), round(py / scale, 3), round(pz / scale, 3)]
    return args


def as_luau(args, drop):
    """render put() args as Luau lines ready to paste into PoseLibrary.meditation"""
    lines = [f"local MEDITATE_DROP = {drop:.2f}"]
    order = ['Root', 'Waist', 'Neck', 'LeftHip', 'RightHip', 'LeftKnee', 'RightKnee',
             'LeftAnkle', 'RightAnkle', 'LeftShoulder', 'RightShoulder',
             'LeftElbow', 'RightElbow', 'LeftWrist', 'RightWrist']
    for k in order:
        if k not in args:
            continue
        x, y, z, px, py, pz = args[k]
        if k == 'Root':
            lines.append(f'\tput(p, "Root", 0, 0, 0, 0, -MEDITATE_DROP * scale, 0)')
        elif px == 0 and py == 0 and pz == 0:
            lines.append(f'\tput(p, "{k}", {x}, {y}, {z})')
        else:
            lines.append(f'\tput(p, "{k}", {x}, {y}, {z}, 0, {py} * scale, 0)')
    return "\n".join(lines)


def rig_scale(rig):
    hrp = [q for q in rig.parts.values() if q['name'] == 'HumanoidRootPart'][0]
    return hrp['size'][1] / 2


def main(argv=None):
    ap = argparse.ArgumentParser(description="Solve a cross-legged meditation pose for a Heavensunder rig.")
    ap.add_argument('rbxmx', nargs='?', help='.rbxmx rig file (from inspect.luau export)')
    ap.add_argument('--hip-height', type=float, default=HIP_H_DEFAULT,
                    help=f'hip joint height above floor in rig units (default {HIP_H_DEFAULT})')
    ap.add_argument('--scale', type=float, default=None,
                    help='rig scale override (default: HumanoidRootPart.Size.Y / 2)')
    ap.add_argument('--out', default=None, help='write JSON put() args to this file')
    ap.add_argument('--luau', action='store_true', help='print Luau put() lines instead of JSON')
    ap.add_argument('--from-dump', default=None, metavar='MODEL',
                    help='legacy v0.4.1 path: load MODEL from a report-dump pickle')
    ap.add_argument('--pkl', default='/tmp/n.pkl', help='pickle path for --from-dump')
    a = ap.parse_args(argv)
    if a.from_dump:
        rig = load_from_dump(a.from_dump, a.pkl)
    elif a.rbxmx:
        rig = load_from_rbxmx(a.rbxmx)
    else:
        ap.error("give a .rbxmx file (or --from-dump MODEL for the legacy path)")
    s = a.scale or rig_scale(rig)
    p, info = solve_pose(rig, s, hip_h=a.hip_height)
    print(f"# arm fit dydx: {info}  scale={s:.4g}  hip_h={a.hip_height}", file=sys.stderr)
    args = as_put_args(p, s)
    if a.luau:
        print(as_luau(args, BIND_HIP - a.hip_height))
    else:
        text = json.dumps(args, indent=1)
        if a.out:
            open(a.out, 'w').write(text + "\n")
            print(f"# wrote {a.out}", file=sys.stderr)
        else:
            print(text)


if __name__ == '__main__':
    main()
