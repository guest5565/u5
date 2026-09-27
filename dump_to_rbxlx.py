"""Rebuild a real place file from the property dump embedded in the Heavensunder report HTML.

    python3 dump_to_rbxlx.py "Heavensunder-v0.4 (1).html" Heavensunder-v0.4.rbxlx
    lune run xml_to_binary.luau Heavensunder-v0.4.rbxlx Heavensunder-v0.4.rbxl

The HTML's <script id="rbxl-data"> block holds gzip+base64 JSON: every instance of the original
.rbxl, with every *saved* property written under its serialized name and with its type
(Float32/Enum/CFrame/...). Those map 1:1 onto rbx-dom's XML format, so the place can be
reconstructed. What the dump does NOT contain (it only stores a hash for these):
  - Lighting.AttributesSerialize (89 bytes) and Workspace.AttributesSerialize (28 bytes).
    Workspace attributes are Weather/WeatherIntensity, which GameServer sets at startup anyway.
  - Terrain SmoothGrid/PhysicsGrid/MaterialColors (the terrain is empty: 2-byte grid),
    Workspace.CollisionGroupData (16 bytes = just the Default group).
  - Model LOD caches (ModelMeshData/SlimHash) - Studio regenerates them.
"""
import sys, re, json, gzip, base64, html
from xml.sax.saxutils import escape as _esc, quoteattr as _qa

def load_dump(path):
    if path.endswith('.bin') or path.endswith('.json'):
        return json.loads(open(path, 'rb').read())
    text = open(path, encoding='utf-8').read()
    m = re.search(r'<script id="rbxl-data"[^>]*>(.*?)</script>', text, re.S)
    blob = html.unescape(m.group(1).strip())
    try:
        blob = json.loads(blob) if blob.startswith('"') else blob
    except Exception:
        pass
    return json.loads(gzip.decompress(base64.b64decode(blob)))

NUM = r'[-+]?(?:\d+\.?\d*(?:[eE][-+]?\d+)?|inf|nan)'
def nums(s): return re.findall(NUM, s)
def fnum(s):
    s = s.lower()
    return {'inf': 'INF', '-inf': '-INF', '+inf': 'INF', 'nan': 'NAN'}.get(s, s)

class El:
    """minimal element: collects children, serialised immediately by the caller"""
    __slots__ = ('tag', 'attrs', 'text', 'kids')
    def __init__(self, tag): self.tag, self.attrs, self.text, self.kids = tag, {}, None, []
    def set(self, k, v): self.attrs[k] = v
    def dump(self, w, ind):
        a = ''.join(f' {k}={_qa(v)}' for k, v in self.attrs.items())
        if self.kids:
            w(f'{ind}<{self.tag}{a}>\n')
            for k in self.kids: k.dump(w, ind + '\t')
            w(f'{ind}</{self.tag}>\n')
        else:
            w(f'{ind}<{self.tag}{a}>{_esc(self.text or "")}</{self.tag}>\n')

def sub(parent, tag, text=None):
    e = El(tag)
    if text is not None: e.text = text
    parent.kids.append(e)
    return e

def cframe_into(e, text):
    v = [fnum(x) for x in nums(text)]
    assert len(v) == 12, text
    for k, x in zip(['X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'], v): sub(e, k, x)

SKIP_NAMES = {'HistoryId'}
# String-typed in the dump but ContentId in the Roblox API (XML needs <Content><url>)
CONTENT = {'Texture', 'TopImage', 'MidImage', 'BottomImage', 'Image', 'LinkedSource', 'MoonTextureId', 'SunTextureId',
           'SkyboxBk', 'SkyboxDn', 'SkyboxFt', 'SkyboxLf', 'SkyboxRt', 'SkyboxUp', 'MeshId', 'TextureID', 'SoundId'}          # all zero in the file
stats = {'props': 0, 'skipped': {}}

def write_prop(P, p, node, referent):
    t, name, text = p['type'], p['name'], p.get('text', '')
    def skip(why): stats['skipped'][f'{t}:{name}:{why}'] = stats['skipped'].get(f'{t}:{name}:{why}', 0) + 1
    if p.get('origin') != 'saved' or name in SKIP_NAMES: return
    if 'byteLength' in p: return skip('binary-not-in-dump')
    if t == 'SharedString':
        if text: skip('sharedstring')
        return
    if name == 'AttributesSerialize':
        if text: skip('attributes')
        return
    stats['props'] += 1
    if t == 'String':
        if name == 'Source' and node.get('script'):
            sub(P, 'ProtectedString', node.get('source') or '').set('name', 'Source'); return
        if name in CONTENT:
            e = sub(P, 'Content'); e.set('name', name); sub(e, 'url' if text else 'null', text or None); return
        sub(P, 'string', text).set('name', name); return
    tag = {'Bool': 'bool', 'Float32': 'float', 'Float64': 'double', 'Int32': 'int', 'Int64': 'int64',
           'Enum': 'token', 'BrickColor': 'int', 'SecurityCapabilities': 'SecurityCapabilities'}.get(t)
    if tag:
        v = text
        if t in ('Float32', 'Float64'): v = fnum(v)
        if t in ('Enum', 'BrickColor', 'Int32', 'Int64', 'SecurityCapabilities'): v = nums(v)[0]
        sub(P, tag, v).set('name', name); return
    if t == 'UniqueId':
        sub(P, 'UniqueId', text.split()[0]).set('name', name); return
    if t == 'Vector3':
        e = sub(P, 'Vector3'); e.set('name', name)
        for k, x in zip('XYZ', nums(text)): sub(e, k, fnum(x))
        return
    if t == 'Vector2':
        e = sub(P, 'Vector2'); e.set('name', name)
        for k, x in zip('XY', nums(text)): sub(e, k, fnum(x))
        return
    if t == 'CFrame':
        e = sub(P, 'CoordinateFrame'); e.set('name', name); cframe_into(e, text); return
    if t == 'OptionalCFrame':
        e = sub(P, 'OptionalCoordinateFrame'); e.set('name', name)
        if nums(text): cframe_into(sub(e, 'CFrame'), text)
        return
    if t == 'Color3':
        e = sub(P, 'Color3'); e.set('name', name)
        for k, x in zip('RGB', nums(text)): sub(e, k, fnum(x))
        return
    if t == 'Color3uint8':
        r, g, b = (int(x) for x in nums(text))
        sub(P, 'Color3uint8', str((r << 16) | (g << 8) | b)).set('name', name); return
    if t == 'UDim2':
        xs, xo, ys, yo = nums(text)
        e = sub(P, 'UDim2'); e.set('name', name)
        sub(e, 'XS', fnum(xs)); sub(e, 'XO', str(int(float(xo)))); sub(e, 'YS', fnum(ys)); sub(e, 'YO', str(int(float(yo)))); return
    if t == 'UDim':
        s, o = nums(text)
        e = sub(P, 'UDim'); e.set('name', name); sub(e, 'S', fnum(s)); sub(e, 'O', str(int(float(o)))); return
    if t == 'NumberRange':
        a, b = nums(text); sub(P, 'NumberRange', f'{fnum(a)} {fnum(b)} ').set('name', name); return
    if t == 'NumberSequence':
        v = nums(text); assert len(v) % 3 == 0, text
        sub(P, 'NumberSequence', ' '.join(fnum(x) for x in v) + ' ').set('name', name); return
    if t == 'ColorSequence':
        v = nums(text); assert len(v) % 5 == 0, text
        sub(P, 'ColorSequence', ' '.join(fnum(x) for x in v) + ' ').set('name', name); return
    if t == 'PhysicalProperties':
        e = sub(P, 'PhysicalProperties'); e.set('name', name)
        if text.startswith('default'):
            sub(e, 'CustomPhysics', 'false')
        else:
            v = nums(text); sub(e, 'CustomPhysics', 'true')
            for k, x in zip(['Density', 'Friction', 'Elasticity', 'FrictionWeight', 'ElasticityWeight'], v): sub(e, k, fnum(x))
        return
    if t == 'Font':
        m = re.match(r'family: (.*?), weight: (\d+), style: (\d+)(?:, cached face: (.*))?$', text)
        e = sub(P, 'Font'); e.set('name', name)
        sub(sub(e, 'Family'), 'url', m.group(1)); sub(e, 'Weight', m.group(2))
        sub(e, 'Style', 'Italic' if m.group(3) == '1' else 'Normal')
        if m.group(4): sub(sub(e, 'CachedFaceId'), 'url', m.group(4))
        return
    if t == 'Reference':
        tgt = p.get('target')
        sub(P, 'Ref', referent(tgt) if tgt is not None else 'null').set('name', name); return
    stats['props'] -= 1
    skip('unhandled-type')

def main(src, out):
    if src.endswith('.pkl'):
        import pickle
        roots, N = pickle.load(open(src, 'rb'))
    else:
        d = load_dump(src)
        N = {int(k): v for k, v in d['nodes'].items()}; del d['nodes']
        roots = d['roots']
    referent = lambda i: f'RBX{int(i):06d}'
    f = open(out, 'w', encoding='utf-8', newline='\n'); w = f.write
    w('<roblox version="4">\n\t<Meta name="ExplicitAutoJoints">true</Meta>\n')
    count = 0
    def emit(i, ind):
        nonlocal count
        n = N[i]
        if n['class'] == 'Instance':   # Studio-internal FilteredSelection objects
            return
        count += 1
        w(f'{ind}<Item class={_qa(n["class"])} referent="{referent(i)}">\n')
        P = El('Properties')
        for p in n['props']: write_prop(P, p, n, referent)
        P.dump(w, ind + '\t')
        for c in n['children']: emit(c, ind + '\t')
        w(f'{ind}</Item>\n')
    for r in roots: emit(r, '\t')
    w('</roblox>\n'); f.close()
    print(f'wrote {out}: {count} instances, {stats["props"]} properties')
    for k, v in sorted(stats['skipped'].items()): print(f'  skipped {v:6d} x {k}')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
