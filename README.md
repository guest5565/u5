# python/checks: offline visual checks (optional)

These let you check visual fixes without opening Studio.

- `rigsim.py`: loads a rig from `.rbxmx` with `load_from_rbxmx`, runs forward kinematics like AnimationManager with `solve(rig, pose)`, and renders it with `views(...)` or `render(...)`.
- `pose_design.py`: the numerical solver that produced the v0.4.1 meditation pose. It needs scipy, and it still loads rigs from the old report dump (`load_from_dump`). Switch it to `load_from_rbxmx` before reusing it.
- `holes.py` / `holes2.py`: cast rays from inside houses and report where they escape. `holes2.py` handles WedgeParts exactly.

Export something to check with `lune run lune/inspect.luau export <Path> file.rbxmx`.
