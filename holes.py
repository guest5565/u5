import numpy as np, pickle
def obbs(parts, base, R, skip=('LanternBody','EaveCap','Frame','SilkTassel')):
    out=[]
    for p in parts:
        if p['alpha']>0.5 or p['name'] in skip: continue
        c=R.T@(p['cf'][:3,3]-base); r=R.T@p['cf'][:3,:3]
        out.append((c,r,p['size']/2,p['name']))
    return out
def ray_hits(o,d,boxes,tmax=60):
    best=tmax;name=None
    for c,r,h,n in boxes:
        lo=r.T@(o-c); ld=r.T@d
        with np.errstate(divide='ignore',invalid='ignore'):
            t1=(-h-lo)/ld; t2=(h-lo)/ld
        tn=np.nanmax(np.minimum(t1,t2)); tf=np.nanmin(np.maximum(t1,t2))
        if tf>=max(tn,0) and tn<best: best=max(tn,0);name=n
    return best,name
def scan(boxes, label, n_dirs=900, seed=1):
    rng=np.random.default_rng(seed)
    origins=[np.array([x,y,z]) for x in (-5,0,5) for y in (3,6,9.5) for z in (-4,0,4)]
    v=rng.normal(size=(n_dirs,3)); v/=np.linalg.norm(v,axis=1)[:,None]
    escapes=[]
    for o in origins:
        for d in v:
            t,n=ray_hits(o,d,boxes)
            if n is None:
                # where does it cross the house shell (|x|<=9.4,|z|<=8.4, y<=12.5)?
                ts=[]
                for ax,lim in ((0,9.4),(2,8.4),(1,12.6)):
                    if abs(d[ax])>1e-9:
                        for s in (-lim,lim):
                            tt=(s-o[ax])/d[ax]
                            if tt>0: ts.append(tt)
                p=o+d*min(ts); escapes.append(p)
    escapes=np.array(escapes)
    def cls(p):
        x,y,z=p
        if z<-8 and abs(x)<2.45 and y<7.4: return 'door (expected)'
        if abs(x)>9 : return 'side gable/wall x=%+d'%np.sign(x)
        if abs(z)>8 : return ('front' if z<0 else 'rear')+' wall-roof gap'
        return 'roof'
    import collections
    c=collections.Counter(cls(p) for p in escapes)
    print(f'{label}: {len(escapes)} of {len(origins)*n_dirs} interior rays escape ->',dict(c))
    return escapes
