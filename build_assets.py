#!/usr/bin/env python3
"""Build a catalog of Heavensunder assets as individual .rbxmx files.

    cd python && pip install -r requirements.txt
    python build_assets.py                  # -> assets/*.rbxmx
    python build_assets.py --out my_assets  # somewhere else

Each file holds ONE model at the baked position shown below. Merge it into a
copy of the place without touching anything else:

    lune run lune/merge_into_place.luau Heavensunder.rbxl test.rbxl \\
        Workspace/Actors/Enemies=python/assets/JadeSilkweaver_99.rbxmx

Notes:
- Positions are baked into the files. EnemyService uses the model's pivot as
  its home/spawn, so move the model in Studio after merging if you want it
  elsewhere (or re-export with --position via asset_builder.py export).
- Seeds are fixed so the catalog is reproducible. Random-driven parts (trees,
  islands) will NOT match the shipped instances exactly; see docs/REVIEW.
- For true 1:1 copies of shipped complex assets (costumed rigs, waterfalls,
  bridges), extract them from the place instead:
    lune run lune/inspect.luau export Workspace.Actors.Enemies.JadeWarden_00 warden.rbxmx
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from asset_builder import export_rbxmx

# (kind, name, position, options, subfolder)
CATALOG = [
    # houses (v0.4.1 geometry: door beams split, gables/eaves filled)
    ('house', 'LanternwakeHome_new', (0, 0, 0), {'accent': 'redwood', 'yaw': 0}, '.'),
    ('house', 'LanternwakeHome_new_180', (30, 0, 0), {'accent': 'redwood', 'yaw': 3.14159265}, '.'),
    ('stall', 'TeaAndSilkMarket_new', (0, 0, 20), {}, '.'),
    ('reeds', 'RiverReeds_new', (10, 0, 20), {'scale': 1.0}, '.'),
    # spiders (exact recipes)
    ('spider', 'JadeSilkweaver_99', (20, 0, 20), {'scale': 0.85}, '.'),
    ('spider', 'SilkMatriarch_99', (-20, 0, 20), {'scale': 1.6, 'matriarch': True}, '.'),
    # humanoid rigs (body + armour + halo + neck; no costume layers)
    ('enemy', 'JadeWarden_99', (-20, 0, -20), {'style': 'JadeWarden', 'scale': 1.30}, '.'),
    ('enemy', 'StormDisciple_99', (0, 0, -20), {'style': 'StormDisciple', 'scale': 1.30}, '.'),
    ('enemy', 'HollowLotus_99', (20, 0, -20), {'style': 'LotusSovereign', 'scale': 1.60}, '.'),
    ('npc', 'Villager_99', (0, 0, 40), {'style': 'player', 'scale': 1.0,
                                        'role': 'Villager', 'subtitle': 'LANTERNWAKE VILLAGER'}, '.'),
    # scenery (recipes match; random parts differ from shipped instances)
    ('tree', 'LowlandBough_99', (50, 0, 0), {'scale': 1.0, 'style': 'jade'}, '.'),
    ('tree', 'SnowPine_99', (70, 0, 0), {'scale': 1.0, 'style': 'snow'}, '.'),
    ('island', 'Isle_99', (0, 130, 200), {'radius': 90, 'biome': 'grass'}, '.'),
    ('mountain', 'Peak_99', (200, 0, 200), {'radius': 90, 'height': 100}, '.'),
]

SEED = 71624


def main(argv=None):
    ap = argparse.ArgumentParser(description='Build the Heavensunder .rbxmx asset catalog.')
    ap.add_argument('--out', default='assets', help='output folder (default assets/)')
    ap.add_argument('--seed', type=int, default=SEED, help=f'rng seed (default {SEED})')
    ap.add_argument('--only', default=None, help='comma-separated names to build (default: all)')
    a = ap.parse_args(argv)
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    only = set(a.only.split(',')) if a.only else None
    n = 0
    for kind, name, pos, opts, _ in CATALOG:
        if only and name not in only:
            continue
        export_rbxmx(kind, name, str(out / f'{name}.rbxmx'), position=pos, seed=a.seed, **opts)
        print(f'  {name}.rbxmx  ({kind} at {pos} {opts})')
        n += 1
    print(f'wrote {n} files to {out}/')


if __name__ == '__main__':
    main()
