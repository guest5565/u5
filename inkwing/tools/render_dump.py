import json,sys,math,numpy as np,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon
txt=open(sys.argv[1]).read()
models={}
for chunk in txt.split('@@')[1:]:
    pass
parts=txt.split('@@')
for i in range(1,len(parts),2):
    models[parts[i]]=json.loads(parts[i+1].strip())
az=math.radians(float(sys.argv[2]) if len(sys.argv)>2 else 25); el=math.radians(15)
# camera looking toward -Z world from +Z (front), rotated by az around Y, el pitch
fwd=np.array([-math.sin(az)*math.cos(el), -math.sin(el), -math.cos(az)*math.cos(el)])
right=np.cross(fwd,[0,1,0]); right/=np.linalg.norm(right); up=np.cross(right,fwd)
L=np.array([0.4,0.8,0.5]); L/=np.linalg.norm(L)
def faces(p):
    sx,sy,sz=[v/2 for v in p['sz']]; R=np.array(p['R']); c=np.array(p['p'])
    if p['s']=='Ball':
        return [('ball',c,sx)]
    if p['c']=='WedgePart':
        V=[(-sx,-sy,-sz),(sx,-sy,-sz),(sx,-sy,sz),(-sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz)]
        Fs=[[0,1,2,3],[3,2,4,5],[0,1,4,5],[0,3,5],[1,2,4]]
    elif p['s']=='Cylinder':
        n=14;ang=np.linspace(0,2*np.pi,n+1)[:-1];r=min(sy,sz)
        V=[(x,r*math.cos(a),r*math.sin(a)) for x in(-sx,sx) for a in ang]
        Fs=[list(range(n))[::-1],list(range(n,2*n))]+[[i,(i+1)%n,n+(i+1)%n,n+i] for i in range(n)]
    else:
        V=[(x,y,z) for x in(-sx,sx) for y in(-sy,sy) for z in(-sz,sz)]
        Fs=[[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]
    W=[R@np.array(v)+c for v in V]
    return [('poly',[W[i] for i in f]) for f in Fs]
names=list(models)
fig,axs=plt.subplots(1,len(names),figsize=(5*len(names),5),squeeze=False); axs=axs[0]
fig.patch.set_facecolor((0.75,0.85,1))
for ax,nm in zip(axs,names):
    items=[]
    for p in models[nm]:
        col=np.array(p['col']); a=1-p['tr']
        for f in faces(p):
            if f[0]=='ball':
                c=f[1];d=c@fwd
                items.append((d,'ball',c,f[2],col,a))
            else:
                W=np.array(f[1]); cen=W.mean(0)
                nrm=np.cross(W[1]-W[0],W[2]-W[0]);
                if np.linalg.norm(nrm)<1e-9: continue
                nrm/=np.linalg.norm(nrm)
                if nrm@(cen-np.array(p['p']))<0: nrm=-nrm
                if nrm@fwd>0.05: continue
                sh=0.45+0.55*max(0,nrm@L)
                items.append((cen@fwd,'poly',W,None,col*sh,a))
    items.sort(key=lambda t:-t[0])
    pts=[]
    for d,k,g,r,col,a in items:
        if k=='ball':
            c2=(g@right,g@up)
            ax.add_patch(plt.Circle(c2,r,color=np.clip(col*0.95,0,1),alpha=a,ec=(0,0,0,0.25),lw=0.5))
            ax.add_patch(plt.Circle((c2[0]-r*0.3,c2[1]+r*0.3),r*0.35,color=np.clip(col*1.25+0.05,0,1),alpha=a*0.6,lw=0))
            pts+= [(c2[0]-r,c2[1]-r),(c2[0]+r,c2[1]+r)]
        else:
            P2=[(w@right,w@up) for w in g]
            ax.add_patch(Polygon(P2,closed=True,fc=np.clip(col,0,1),alpha=a,ec=(0,0,0,0.3),lw=0.4)); pts+=P2
    pts=np.array(pts); c=pts.mean(0); r=(pts.max(0)-pts.min(0)).max()/2*1.1
    ax.set_xlim(c[0]-r,c[0]+r); ax.set_ylim(c[1]-r,c[1]+r); ax.set_aspect('equal'); ax.axis('off'); ax.set_title(nm)
plt.savefig(sys.argv[3] if len(sys.argv)>3 else 'previews/enemies.png',dpi=70,bbox_inches='tight',facecolor=fig.get_facecolor())
