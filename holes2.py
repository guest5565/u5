# holes.py + exact WedgePart intersection, loading houses from an .rbxlx
import sys, numpy as np, xml.etree.ElementTree as ET, collections
import holes
def ray_hits(o,d,boxes,tmax=60):
    best=tmax;name=None
    for c,r,h,n,wedge in boxes:
        lo=r.T@(o-c); ld=r.T@d
        with np.errstate(divide='ignore',invalid='ignore'):
            t1=(-h-lo)/ld; t2=(h-lo)/ld
        tn=np.nanmax(np.minimum(t1,t2)); tf=np.nanmin(np.maximum(t1,t2))
        if wedge:   # keep the half-space  z*hy - y*hz >= 0  (slope faces -Z/+Y)
            nrm=np.array([0,-h[2],h[1]]); a=nrm@lo; b=nrm@ld
            if abs(b)<1e-12:
                if a<0: continue
            elif b>0: tn=max(tn,-a/b)
            else: tf=min(tf,-a/b)
        if tf>=max(tn,0) and tn<best: best=max(tn,0);name=n
    return best,name
holes.ray_hits=lambda o,d,boxes,tmax=60: ray_hits(o,d,boxes,tmax)
def houses(path):
    R=ET.parse(path).getroot(); out=[]
    for it in R.iter('Item'):
        P=it.find('Properties')
        if it.get('class')=='Model' and P.find('string[@name="Name"]').text=='LanternwakeHome':
            parts=[]
            for q in it.iter('Item'):
                if q.get('class') not in ('Part','WedgePart'): continue
                Q=q.find('Properties'); cf=Q.find('CoordinateFrame[@name="CFrame"]')
                v=[float(cf.find(t).text) for t in ['X','Y','Z','R00','R01','R02','R10','R11','R12','R20','R21','R22']]
                sz=Q.find('Vector3[@name="size"]'); s=np.array([float(sz.find(t).text) for t in 'XYZ'])
                tr=Q.find('float[@name="Transparency"]'); a=float(tr.text) if tr is not None else 0
                parts.append(dict(name=Q.find('string[@name="Name"]').text,cf=np.vstack([np.c_[np.array(v[3:]).reshape(3,3),v[:3]],[0,0,0,1]]),size=s,alpha=a,wedge=q.get('class')=='WedgePart'))
            out.append(parts)
    return out
if __name__=='__main__':
    path=sys.argv[1]; which=[int(x) for x in sys.argv[2].split(',')]; nd=int(sys.argv[3]) if len(sys.argv)>3 else 300
    H=houses(path)
    for i in which:
        parts=H[i]; f=[p for p in parts if p['name']=='RaisedStoneFoundation'][0]
        R=f['cf'][:3,:3]; base=f['cf'][:3,3]-R@np.array([0,.35,0])
        bx=[b+(p['wedge'],) for b,p in zip(holes.obbs([p for p in parts if not(p['alpha']>0.5 or p['name'] in ('LanternBody','EaveCap','Frame','SilkTassel'))],base,R),[p for p in parts if not(p['alpha']>0.5 or p['name'] in ('LanternBody','EaveCap','Frame','SilkTassel'))])]
        holes.scan(bx,f'{path.split("/")[-1]} house {i} (yaw {round(np.degrees(np.arctan2(R[0,2],R[0,0])))})',nd)
