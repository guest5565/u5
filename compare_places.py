#!/usr/bin/env python3
"""Compare two Roblox XML files (.rbxmx / .rbxlx) part-for-part.

    python compare_places.py before.rbxmx after.rbxmx
    python compare_places.py a.rbxlx b.rbxlx --tolerance 0.005 --show-all

Used to prove that a patch (or the asset builder) produces exactly the
geometry you expect: same instances, same positions, sizes, rotations,
colours, materials and transparency. Prints "N/M parts identical" plus a
list of added / removed / changed instances.

How it works: streaming XML parse (iterparse, constant memory even for the
~120 MB full-place XML), one signature per BasePart keyed by its full path
with sibling indices (so 320 CliffFacets don't collide). Floats compare
with --tolerance (default 1e-3); the old pipeline truncated colours while
Rojo rounds them, so use 0.005 to ignore 1/255 noise.

Exit code 0 = identical, 1 = differences found.

Known structural difference (not a bug): in the shipped place, Motor6Ds are
parented under their Part0, while asset_builder parents them under the Model.
A full compare of shipped-vs-built therefore always lists joint moves; use
--parts-only for the geometry verdict (161/161 on the spider).
"""
import argparse
import sys
import xml.etree.ElementTree as ET

PART_CLASSES = {'Part', 'WedgePart', 'MeshPart', 'CornerWedgePart', 'VehicleSeat', 'Seat'}
VALUE_TAGS = {'string', 'bool', 'int', 'int64', 'float', 'double', 'token'}


def _text(elem, tag, name):
    child = elem.find(f"{tag}[@name='{name}']")
    return child.text if child is not None else None


def _cf(elem):
    cf = elem.find("CoordinateFrame[@name='CFrame']")
    if cf is None:
        return None
    return tuple(float(cf.find(k).text) for k in
                 ('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'))


def _vec3(elem, name):
    v = elem.find(f"Vector3[@name='{name}']")
    if v is None:
        v = elem.find(f"Vector3[@name='size']")
        if name != 'size' or v is None:
            return None
    return tuple(float(v.find(k).text) for k in 'XYZ')


def _color(elem):
    c = elem.find("Color3[@name='Color']")
    if c is not None:
        return tuple(float(c.find(k).text) for k in 'RGB')
    u = elem.find("Color3uint8[@name='Color3uint8']")
    if u is not None and u.text:
        n = int(float(u.text))
        return (((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255)
    return None


def _prop_text(props, name):
    for tag in VALUE_TAGS:
        v = props.find(f"{tag}[@name='{name}']")
        if v is not None:
            return f"{tag}:{v.text}"
    return None


def signatures(path):
    """{full/path: signature}. Parts get geometry; ValueBase gets its value; rest presence."""
    records = {}  # id -> {name, class, idx, parent, sig}
    counters = {}  # parent id -> {(class, name): next sibling index}
    stack = []  # open item ids (parents first)
    next_id = 0
    for event, elem in ET.iterparse(path, events=('start', 'end')):
        if elem.tag != 'Item':
            continue
        if event == 'start':
            next_id += 1
            stack.append(next_id)
            records[next_id] = {'class': elem.get('class')}
        else:
            iid = stack.pop()
            props = elem.find('Properties')
            name = _text(props, 'string', 'Name') if props is not None else None
            cls = records[iid]['class']
            parent = stack[-1] if stack else 0
            key = (cls, name or '?')
            idx = counters.setdefault(parent, {}).get(key, 0)
            counters[parent][key] = idx + 1
            if cls in PART_CLASSES and props is not None:
                sig = ('part', _cf(props), _vec3(props, 'size'), _color(props),
                       _prop_text(props, 'Material'), _prop_text(props, 'Transparency'),
                       _prop_text(props, 'shape'))
            elif cls.endswith('Value') and props is not None:
                sig = ('value', _prop_text(props, 'Value'))
            else:
                sig = ('item',)
            records[iid].update(name=name or '?', idx=idx, parent=parent, sig=sig)
            elem.clear()

    def path_of(iid):
        segs = []
        while iid:
            r = records[iid]
            segs.append(f"{r['class']}:{r['name']}[{r['idx']}]")
            iid = r['parent']
        return '/'.join(reversed(segs))

    return {path_of(iid): r['sig'] for iid, r in records.items()}


def _close(a, b, tol):
    if a == b:
        return True
    if a is None or b is None:
        return False
    if isinstance(a, tuple) and isinstance(b, tuple) and len(a) == len(b):
        for x, y in zip(a, b):
            if isinstance(x, str) or isinstance(y, str):
                if x != y:
                    return False
            elif abs(float(x) - float(y)) > tol:
                return False
        return True
    return False


def same(sig_a, sig_b, tol):
    if sig_a[0] != sig_b[0]:
        return False
    if sig_a[0] == 'part':
        return all((
            _close(sig_a[1], sig_b[1], tol),  # CFrame
            _close(sig_a[2], sig_b[2], tol),  # size
            _close(sig_a[3], sig_b[3], max(tol, 0.006)),  # color (0.006 covers 1/255 rounding)
            sig_a[4] == sig_b[4],  # material
            _close((float(sig_a[5].split(':')[1]),), (float(sig_b[5].split(':')[1]),), tol)
            if sig_a[5] and sig_b[5] else sig_a[5] == sig_b[5],
            sig_a[6] == sig_b[6],  # shape
        ))
    return sig_a == sig_b


def main(argv=None):
    ap = argparse.ArgumentParser(description='Compare two Roblox XML files part-for-part.')
    ap.add_argument('a', help='first .rbxmx / .rbxlx')
    ap.add_argument('b', help='second .rbxmx / .rbxlx')
    ap.add_argument('--tolerance', type=float, default=1e-3, help='float tolerance (default 1e-3)')
    ap.add_argument('--show-all', action='store_true', help='list every difference (default: first 40)')
    ap.add_argument('--parts-only', action='store_true', help='only compare BaseParts')
    args = ap.parse_args(argv)
    sa, sb = signatures(args.a), signatures(args.b)
    if args.parts_only:
        sa = {k: v for k, v in sa.items() if v[0] == 'part'}
        sb = {k: v for k, v in sb.items() if v[0] == 'part'}
    only_a = sorted(set(sa) - set(sb))
    only_b = sorted(set(sb) - set(sa))
    changed = sorted(k for k in set(sa) & set(sb) if not same(sa[k], sb[k], args.tolerance))
    parts_a = sum(1 for v in sa.values() if v[0] == 'part')
    parts_b = sum(1 for v in sb.values() if v[0] == 'part')
    same_parts = sum(1 for k in set(sa) & set(sb)
                     if sa[k][0] == 'part' and same(sa[k], sb[k], args.tolerance))
    print(f"{args.a}: {len(sa)} instances ({parts_a} parts)")
    print(f"{args.b}: {len(sb)} instances ({parts_b} parts)")
    print(f"identical parts: {same_parts} / {max(parts_a, parts_b)}")
    diffs = ([f'- {k}' for k in only_a] + [f'+ {k}' for k in only_b] + [f'~ {k}' for k in changed])
    if diffs:
        limit = len(diffs) if args.show_all else 40
        print(f"differences ({len(diffs)}):")
        for d in diffs[:limit]:
            print(f"  {d}")
        if len(diffs) > limit:
            print(f"  ... and {len(diffs) - limit} more (--show-all to list)")
        return 1
    print("0 models differ.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
