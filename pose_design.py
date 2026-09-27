"""Design a proper cross-legged (sukhasana) meditation pose for the Heavensunder 15-joint rig.
Works in the rig's authored frame: faces -Z, left = -X, joint C0/C1 rotations are identity.
Outputs PoseLibrary.put() arguments (limb x-angles pre-negated exactly like put() expects)."""
import math, numpy as np, json, sys
from scipy.optimize import minimize
from rigsim import *

def nrm(v): v=np.asarray(v,float); return v/np.linalg.norm(v)
def frame(bone_dir, front_hint):
    """part rotation whose local -Y runs along bone_dir and local -Z faces front_hint"""
    Y=-nrm(bone_dir); f=np.asarray(front_hint,float); f=f-(f@Y)*Y; Z=-nrm(f); X=np.cross(Y,Z)
    return np.column_stack((X,Y,Z))
def frame_xz(x_axis, z_axis):
    X=nrm(x_axis); Z=np.asarray(z_axis,float); Z=nrm(Z-(Z@X)*X); Y=np.cross(Z,X); return np.column_stack((X,Y,Z))
def euler_xyz(R):
    b=math.asin(max(-1,min(1,R[0,2]))); a=math.atan2(-R[1,2],R[2,2]); c=math.atan2(-R[0,1],R[0,0]); return a,b,c
LIMB=('Shoulder','Elbow','Hip','Knee','Ankle')
def to_put(name,R,pos=(0,0,0)):
    a,b,c=euler_xyz(R)          # actual joint rotation (what AnimationManager ends up applying)
    return (a,b,c)+tuple(pos)

HIP_H=0.64           # hip joint height above floor, in rig units (x scale)
BIND_HIP=2.34
DROP=BIND_HIP-HIP_H  # Root translation (x scale)

def leg_targets(side):
    """side=-1 left, +1 right. world-aligned target rotations for thigh, shin, foot"""
    sx=side
    thigh=nrm((0.74*sx,-0.22,-0.64))
    # shins cross in front of the pelvis; right shin rides slightly higher & further forward
    if side<0: shin=nrm((1.0,-0.08,0.12))
    else:      shin=nrm((-1.0,0.05,-0.02))
    Rt=frame(thigh,(0.25*sx,1,-0.25))         # kneecap faces up / slightly out
    Rs=frame(shin,(0,1,-0.35))                 # shin front faces up
    toes=nrm((-sx*1.0,0.0,-0.15))              # toes continue past the opposite knee
    # outer edge of the foot rests on the floor: left foot's -X (outer) points down
    X= (0,1,0) if side<0 else (0,-1,0)
    Rf=frame_xz(X,-toes)
    return Rt,Rs,Rf

def solve_pose(rig, scale, t=0.0, breath=True):
    p={}
    put(p,'Root',0,0,0,0,-DROP*scale,0)
    lean=-0.06
    put(p,'Waist',lean,0,0)
    put(p,'Neck',-0.16,0,0)
    Rw=Rx(lean)
    for side,L in ((-1,'Left'),(1,'Right')):
        Rt,Rs,Rf=leg_targets(side)
        p[L+'Hip']=to_put(L+'Hip',Rt)
        p[L+'Knee']=to_put(L+'Knee',Rt.T@Rs)
        p[L+'Ankle']=to_put(L+'Ankle',Rs.T@Rf)
    # arms: optimise shoulder/elbow/wrist so the palm rests on top of the knee
    byname={q['name']:k for k,q in rig.parts.items()}
    def arm_cost(v,L,side,target):
        q=dict(p)
        q[L+'Shoulder']=(v[0],v[1],v[2],0,0,0); q[L+'Elbow']=(v[3],0,0,0,0,0); q[L+'Wrist']=(v[4],v[5],0,0,0,0)
        w=solve(rig,q)
        hand=w[byname[L+'Hand']]; elbow=w[byname[L+'LowerArm']]; upper=w[byname[L+'UpperArm']]
        hc=hand[:3,3]
        cost=np.sum((hc-target)**2)*20
        # palm down: hand local -Y should point forward/down-ish, hand's -Z face forward-out
        cost+= (hand[:3,1]@np.array([0,1,0])-0.0)**2*0.6 + (hand[:3,2]@np.array([0,0,1])-0.0)**2*0.2
        # keep elbows out and a bit back (relaxed), not inside the torso
        cost+= max(0,(1.05*scale)-abs(elbow[0,3]-root_x))**2*4 + max(0,elbow[2,3]-root[2,3]-0.15*scale)**2*3
        cost+= 0.02*np.sum(np.array(v)**2)
        return cost
    root=rig.parts[byname['HumanoidRootPart']]['cf']; root_x=root[0,3]
    w0=solve(rig,p)
    out={}
    for side,L in ((-1,'Left'),):
        knee=w0[byname[L+'LowerLeg']]  # knee pivot ~ top of lower leg
        thigh=w0[byname[L+'UpperLeg']]
        kpos=thigh[:3,3]+thigh[:3,:3]@np.array([0,-0.5*scale,0])  # distal end of thigh
        # hands rest in the lap (dhyana): just in front of the pelvis, on top of the crossed shins
        target=root[:3,3]+np.array([side*0.30*scale,(-3+HIP_H+0.52)*scale,-0.80*scale])
        best=None
        for x0 in ([0.9,0,0.2*side*-1,-0.9,0.4,0],[1.3,0.3*side,0,-0.6,0.3,0],[0.6,-0.2*side,-0.3*side,-1.2,0.5,0]):
            r=minimize(arm_cost,x0,args=(L,side,target),method='Nelder-Mead',options=dict(maxiter=4000,xatol=1e-4,fatol=1e-7))
            if best is None or r.fun<best.fun: best=r
        v=best.x
        p[L+'Shoulder']=(v[0],v[1],v[2],0,0,0); p[L+'Elbow']=(v[3],0,0,0,0,0); p[L+'Wrist']=(v[4],v[5],0,0,0,0)
        out[L]=(best.fun,np.linalg.norm(solve(rig,p)[byname[L+'Hand']][:3,3]-target))
    for j in ('Shoulder','Elbow','Wrist'):
        x,y,z,a,b,c=p['Left'+j]; p['Right'+j]=(x,-y,-z,-a,b,c)   # mirror across the body's YZ plane
    return p,out

def as_put_args(p, scale):
    """convert solved pose back into put(...) literal arguments"""
    args={}
    for k,v in p.items():
        x,y,z,px,py,pz=v
        if any(s in k for s in LIMB): x=-x
        args[k]=[round(x,3),round(y,3),round(z,3),round(px/scale,3),round(py/scale,3),round(pz/scale,3)]
    return args

if __name__=='__main__':
    name=sys.argv[1] if len(sys.argv)>1 else 'Mei_Lan'
    rig=load_from_dump(name)
    hrp=[q for q in rig.parts.values() if q['name']=='HumanoidRootPart'][0]
    s=hrp['size'][1]/2
    p,info=solve_pose(rig,s)
    print('arm fit',info)
    print(json.dumps(as_put_args(p,s)))
