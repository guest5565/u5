"""Tiny offline Roblox rig simulator + software renderer.
- loads a Model from the place dump (analysis/embedded.bin -> /tmp/n.pkl) or from a builder .rbxmx
- forward kinematics through Motor6D (C0*Pose*C1^-1) and WeldConstraints (rigid offsets)
- ports PoseLibrary.put so poses can be tested exactly as AnimationManager applies them
- z-buffer rasterizer (orthographic) with Block / Ball / Cylinder / Wedge shapes
"""
import math, re, pickle, collections
import numpy as np
from PIL import Image

# ---------------------------------------------------------------- math
def Rx(a): c,s=math.cos(a),math.sin(a); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def Ry(a): c,s=math.cos(a),math.sin(a); return np.array([[c,0,s],[0,1,0],[-s,0,c]])
def Rz(a): c,s=math.cos(a),math.sin(a); return np.array([[c,-s,0],[s,c,0],[0,0,1]])
def cf(pos=(0,0,0),rot=None):
    m=np.eye(4); m[:3,3]=pos
    if rot is not None: m[:3,:3]=rot
    return m
def angles(x,y,z): return cf(rot=Rx(x)@Ry(y)@Rz(z))
def inv(m):
    r=m[:3,:3].T; o=np.eye(4); o[:3,:3]=r; o[:3,3]=-r@m[:3,3]; return o

# ---------------------------------------------------------------- loading
_fl=lambda s:[float(x) for x in re.findall(r'-?\d+(?:\.\d+)?(?:e-?\d+)?',s)]
def _cf_text(t):
    v=_fl(t); return cf(v[:3],np.array(v[3:12]).reshape(3,3))

class Rig:
    def __init__(self): self.parts={}; self.motors=[]; self.welds=[]; self.name=''

def load_from_dump(model_name, pkl='/tmp/n.pkl'):
    roots,N=pickle.load(open(pkl,'rb'))
    mid=[i for i,n in N.items() if n['name']==model_name][0]
    rig=Rig(); rig.name=model_name
    def desc(i):
        for c in N[i]['children']:
            yield c; yield from desc(c)
    for i in desc(mid):
        n=N[i]; P={p['name']:p for p in n['props']}
        if n['class'] in ('Part','WedgePart'):
            shape={'0':'Ball','1':'Block','2':'Cylinder'}.get(P.get('shape',{}).get('text','1'),'Block')
            if n['class']=='WedgePart': shape='Wedge'
            rig.parts[i]=dict(name=n['name'],cf=_cf_text(P['CFrame']['text']),size=np.array(_fl(P['size']['text'])),
                              col=np.array(_fl(P['Color3uint8']['text'])),alpha=float(P['Transparency']['text']),shape=shape,
                              mat=P['Material']['text'])
        elif n['class']=='Motor6D':
            rig.motors.append(dict(name=n['name'],p0=P['Part0'].get('target'),p1=P['Part1'].get('target'),
                                   c0=_cf_text(P['C0']['text']),c1=_cf_text(P['C1']['text'])))
        elif n['class']=='WeldConstraint':
            rig.welds.append((P['Part0Internal'].get('target'),P['Part1Internal'].get('target')))
    return rig

def load_from_rbxmx(path):
    import xml.etree.ElementTree as ET
    R=ET.parse(path).getroot(); rig=Rig()
    def g(it,tag,name): return it.find(f'Properties/{tag}[@name="{name}"]')
    def cfx(e): return cf([float(e.find(k).text) for k in 'XYZ'],np.array([float(e.find(f'R{i}{j}').text) for i in range(3) for j in range(3)]).reshape(3,3))
    for it in R.iter('Item'):
        cls=it.get('class'); ref=it.get('referent'); name=g(it,'string','Name').text
        if cls in('Part','WedgePart'):
            sh=g(it,'token','shape'); shape={'0':'Ball','1':'Block','2':'Cylinder'}[sh.text] if sh is not None else 'Block'
            if cls=='WedgePart': shape='Wedge'
            c=g(it,'Color3','Color'); tr=g(it,'*','Transparency'); c8=g(it,'Color3uint8','Color3uint8')
            rig.parts[ref]=dict(name=name,cf=cfx(g(it,'CoordinateFrame','CFrame')),size=np.array([float(g(it,'Vector3','size').find(k).text) for k in 'XYZ']),
                                col=(np.array([float(c.find(k).text)*255 for k in 'RGB']) if c is not None else np.array([(int(c8.text)>>16)&255,(int(c8.text)>>8)&255,int(c8.text)&255])),alpha=float(tr.text) if tr is not None else 0.0,shape=shape,mat=g(it,'token','Material').text)
        elif cls=='Motor6D':
            rig.motors.append(dict(name=name,p0=g(it,'Ref','Part0').text,p1=g(it,'Ref','Part1').text,c0=cfx(g(it,'CoordinateFrame','C0')),c1=cfx(g(it,'CoordinateFrame','C1'))))
        elif cls=='WeldConstraint':
            a=g(it,'Ref','Part0') if g(it,'Ref','Part0') is not None else g(it,'Ref','Part0Internal'); b=g(it,'Ref','Part1') if g(it,'Ref','Part1') is not None else g(it,'Ref','Part1Internal')
            rig.welds.append((a.text,b.text))
    return rig

# ---------------------------------------------------------------- kinematics
def solve(rig, pose=None, root_cf=None):
    """pose: {motorName: (x,y,z,px,py,pz)} already passed through put(). Returns {partId: world cf}"""
    pose=pose or {}
    byname={p['name']:k for k,p in rig.parts.items()}
    root=byname['HumanoidRootPart']
    world={root: rig.parts[root]['cf'] if root_cf is None else root_cf}
    adj=collections.defaultdict(list)
    for m in rig.motors: adj[m['p0']].append(('m',m))
    for a,b in rig.welds:
        adj[a].append(('w',b)); adj[b].append(('w',a))
    q=[root]
    while q:
        a=q.pop()
        for kind,x in adj[a]:
            if kind=='m':
                b=x['p1']
                if b in world: continue
                v=pose.get(x['name'])
                P=cf((v[3],v[4],v[5]))@angles(v[0],v[1],v[2]) if v else np.eye(4)
                world[b]=world[a]@x['c0']@P@inv(x['c1'])
            else:
                b=x
                if b in world: continue
                world[b]=world[a]@inv(rig.parts[a]['cf'])@rig.parts[b]['cf']
            q.append(b)
    return world

def put(pose,key,x=0,y=0,z=0,px=0,py=0,pz=0):
    if any(k in key for k in ('Shoulder','Elbow','Hip','Knee','Ankle')): x=-x
    pose[key]=(x,y,z,px,py,pz)

# ---------------------------------------------------------------- geometry
def _box():
    v=np.array([[x,y,z] for x in(-.5,.5) for y in(-.5,.5) for z in(-.5,.5)])
    f=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    return v,[t for q in f for t in ((q[0],q[1],q[2]),(q[0],q[2],q[3]))]
def _wedge():
    v=np.array([[-.5,-.5,-.5],[.5,-.5,-.5],[-.5,-.5,.5],[.5,-.5,.5],[-.5,.5,.5],[.5,.5,.5]])
    t=[(0,2,3),(0,3,1),(2,4,5),(2,5,3),(0,4,2),(1,3,5),(0,1,5),(0,5,4)]
    return v,t
def _sphere(n=10):
    v=[];t=[]
    for i in range(n+1):
        th=math.pi*i/n
        for j in range(2*n):
            ph=2*math.pi*j/(2*n); v.append([.5*math.sin(th)*math.cos(ph),.5*math.cos(th),.5*math.sin(th)*math.sin(ph)])
    for i in range(n):
        for j in range(2*n):
            a=i*2*n+j; b=i*2*n+(j+1)%(2*n); c=a+2*n; d=b+2*n; t+= [(a,c,d),(a,d,b)]
    return np.array(v),t
def _cyl(n=14):
    v=[];t=[]
    for s in(-.5,.5):
        for j in range(n): a=2*math.pi*j/n; v.append([s,.5*math.cos(a),.5*math.sin(a)])
    v+= [[-.5,0,0],[.5,0,0]]
    for j in range(n):
        k=(j+1)%n; t+=[(j,k,n+k),(j,n+k,n+j),(2*n,k,j),(2*n+1,n+j,n+k)]
    return np.array(v),t
MESH={'Block':_box(),'Wedge':_wedge(),'Ball':_sphere(),'Cylinder':_cyl()}

def triangles(rig, world, skip_alpha=0.95):
    tris=[];cols=[]
    for k,p in rig.parts.items():
        if p['alpha']>skip_alpha or k not in world: continue
        v,t=MESH[p['shape']]
        vw=(world[k][:3,:3]@(v*p['size']).T).T+world[k][:3,3]
        for a,b,c in t: tris.append(vw[[a,b,c]]); cols.append(p['col'])
    return np.array(tris),np.array(cols)

def render(tris, cols, eye_dir=(0.6,0.45,-1.0), up=(0,1,0), size=520, center=None, extent=None, light=(0.4,0.8,-0.5), bg=(24,30,40), ground=None):
    """orthographic render looking along -eye_dir (eye_dir points from target toward camera)"""
    f=-np.array(eye_dir,float); f/=np.linalg.norm(f)
    r=np.cross(f,up); r/=np.linalg.norm(r); u=np.cross(r,f)
    pts=tris.reshape(-1,3)
    if center is None: center=(pts.min(0)+pts.max(0))/2
    rel=tris-center
    X=rel@r; Y=rel@u; Z=rel@f      # Z = depth (bigger = farther)
    if extent is None: extent=max(np.abs(X).max(),np.abs(Y).max())*1.08
    sc=size/(2*extent)
    px=(X*sc+size/2); py=(size/2-Y*sc)
    img=np.zeros((size,size,3)); img[:]=bg; zb=np.full((size,size),np.inf)
    n=np.cross(tris[:,1]-tris[:,0],tris[:,2]-tris[:,0]); nn=np.linalg.norm(n,axis=1); nn[nn==0]=1; n=n/nn[:,None]
    L=np.array(light,float); L/=np.linalg.norm(L)
    shade=0.45+0.55*np.abs(n@L)
    for i in range(len(tris)):
        xs,ys,zs=px[i],py[i],Z[i]
        x0,x1=int(max(0,math.floor(xs.min()))),int(min(size-1,math.ceil(xs.max())))
        y0,y1=int(max(0,math.floor(ys.min()))),int(min(size-1,math.ceil(ys.max())))
        if x0>x1 or y0>y1: continue
        gx,gy=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
        d=(ys[1]-ys[2])*(xs[0]-xs[2])+(xs[2]-xs[1])*(ys[0]-ys[2])
        if abs(d)<1e-9: continue
        w0=((ys[1]-ys[2])*(gx-xs[2])+(xs[2]-xs[1])*(gy-ys[2]))/d
        w1=((ys[2]-ys[0])*(gx-xs[2])+(xs[0]-xs[2])*(gy-ys[2]))/d
        w2=1-w0-w1
        m=(w0>=-1e-6)&(w1>=-1e-6)&(w2>=-1e-6)
        if not m.any(): continue
        z=w0*zs[0]+w1*zs[1]+w2*zs[2]
        sub=zb[y0:y1+1,x0:x1+1]; m&=z<sub
        sub[m]=z[m]
        img[y0:y1+1,x0:x1+1][m]=np.clip(cols[i]*shade[i],0,255)
    if ground is not None:   # draw ground line (y=ground) as thin gray
        pass
    return Image.fromarray(img.astype(np.uint8))

def views(rig, world, labels=('front','side','three-quarter'), size=380, extra_tris=None):
    tris,cols=triangles(rig,world)
    if extra_tris is not None:
        tris=np.concatenate([tris,extra_tris[0]]); cols=np.concatenate([cols,extra_tris[1]])
    pts=tris.reshape(-1,3); center=(pts.min(0)+pts.max(0))/2
    ext=max(pts.max(0)-pts.min(0))*0.62
    dirs={'front':(0,0.12,-1),'side':(1,0.12,0),'three-quarter':(0.7,0.5,-1),'top':(0.0,1,0.35),'back':(0,0.15,1)}
    ims=[render(tris,cols,eye_dir=dirs[l],center=center,extent=ext,size=size) for l in labels]
    W=Image.new('RGB',(size*len(ims),size))
    for i,im in enumerate(ims): W.paste(im,(i*size,0))
    return W

def ground_quad(y, cx, cz, half=4, col=(70,90,70)):
    a=np.array([[cx-half,y,cz-half],[cx+half,y,cz-half],[cx+half,y,cz+half]]); b=np.array([[cx-half,y,cz-half],[cx+half,y,cz+half],[cx-half,y,cz+half]])
    return np.array([a,b]),np.array([col,col])
