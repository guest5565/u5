#!/usr/bin/env python3
"""
Heavensunder AssetBuilder — FIXED
=================================
Geometry recipes are unchanged from the original (verified part-for-part against
Heavensunder-v0.4.rbxl for spider, matriarch, house, stall, reeds, rig bodies).

Serialization fixes (see REVIEW.md):
  1. Property types follow the Roblox reflection types (Float32 'float', Float64 'double',
     Int32 'int'). The original wrote e.g. <int name="Transparency">, which makes
     `rojo build -o place.rbxl` abort with "Property type mismatch".
  2. Attachments write their serialized CFrame (not the non-serialized 'Position').
  3. Humanoid Health is written as Health_XML (the serialized name). The shipped place
     has Health_XML=100 for every humanoid, i.e. the original 'Health' writes were lost.
  4. Enemy/NPC rigs get the 30 R15 *RigAttachment instances and DisplayDistanceType=None,
     exactly like the shipped rigs. NPCs get the 'Interact' ProximityPrompt (NPCService needs
     it for dialogue) and the role Subtitle line on their nameplate.
  5. Nameplates get Bar styling + the Bar.Fill frame EnemyService updates.
  6. Referents never collide with Items already present in `root`.
  7. export_rbxmx() writes a single model as a Rojo-ready .rbxmx file.

Still NOT reproduced (need the original scripts or extraction from the place file):
  costume layers on rigs (RobePanel, HairLock, horns, wings ...), island ExposedMineral,
  house Frame/SilkTassel/LanternLight, the shipped waterfall (CascadeSheet...), the shipped
  bridge (ropes, rails, lanterns), and per-instance RNG state for trees/islands/mountains/reeds.
"""

from pathlib import Path
import math, random, json
import xml.etree.ElementTree as ET
import numpy as np

COL = {
 'rock': (44,64,75), 'rock2':(64,83,88), 'rock3':(83,100,95), 'grass':(80,125,91),
 'moss':(105,151,108), 'jade':(111,225,194), 'gold':(222,183,110), 'bark':(78,59,52),
 'wood':(78,65,60), 'redwood':(122,67,62), 'slate':(49,66,80), 'paper':(245,214,165),
 'pink':(231,151,183), 'snow':(219,232,242), 'ice':(125,185,208), 'water':(103,209,218),
 'dark':(24,38,50), 'stone':(158,165,152), 'pale':(221,221,196), 'leaf':(76,144,113),
}
MAT = {'Plastic':256,'SmoothPlastic':272,'Neon':288,'Wood':512,'WoodPlanks':528,'Marble':784,'Basalt':788,'Slate':800,'Concrete':816,'Limestone':820,'Granite':832,'Pavement':836,'Brick':848,'Pebble':864,'Cobblestone':880,'Rock':896,'Sandstone':912,'Metal':1088,'Grass':1280,'LeafyGrass':1284,'Sand':1296,'Fabric':1312,'Snow':1328,'Ground':1360,'Ice':1536,'Glacier':1552,'Glass':1568,'ForceField':1584}
pi = math.pi

# Serialized XML type of numeric properties we write (Roblox reflection types).
FLOAT32 = {'Transparency','Reflectance','HipHeight','WalkSpeed','Health_XML','MaxHealth','JumpPower',
           'JumpHeight','MaxDistance','BackgroundTransparency','TextSize','TextStrokeTransparency',
           'Width0','Width1','CurveSize0','CurveSize1','LightEmission','LightInfluence','TextureSpeed',
           'Brightness','Range','Density','Offset','Glare','Haze','HoldDuration','MaxActivationDistance'}
INT32 = {'BorderSizePixel','Segments','RootPriority','ZIndex','LayoutOrder'}
DOUBLE = {('NumberValue','Value')}

class AssetBuilder:
    def __init__(self, root=None, seed=71624, scene=None, schema_path=None):
        self.R = root if root is not None else ET.Element('roblox', {'xmlns:xmime':'http://www.w3.org/2005/05/xmlmime','xmlns:xsi':'http://www.w3.org/2001/XMLSchema-instance','version':'4'})
        if len(self.R) == 0 and self.R.find('External') is None:
            ET.SubElement(self.R,'External').text='null'
            ET.SubElement(self.R,'External').text='nil'
        self.rng = random.Random(seed)
        self.scene = [] if scene is None else scene
        self.frames = {}
        self.sizes = {}
        self._serial = 0
        self._taken = {e.get('referent') for e in self.R.iter('Item')}
        self.SCHEMA = None
        if schema_path:
            try: self.SCHEMA = json.loads(Path(schema_path).read_text())['classes']
            except: self.SCHEMA=None
        self.catalog = {
            'house': self.house,
            'stall': self.stall, 'market_stall': self.stall,
            'mountain': self.mountain,
            'reeds': self.reeds, 'reed_cluster': self.reeds,
            'spider': self.spider,
            'tree': self.tree,
            'island': self.island,
            'waterfall': self.waterfall,
            'bridge': self.bridge,
            'enemy': self.enemy,
            'npc': self.npc,
        }

    def _prop(self, obj, tag, name, value=None):
        prev = obj.find(f'Properties/*[@name="{name}"]')
        if prev is not None: obj.find('Properties').remove(prev)
        e = ET.SubElement(obj.find('Properties'), tag, {'name':name})
        if value is not None: e.text = str(value)
        return e
    def _text(self, obj, name, val): return self._prop(obj,'string',name,val)
    def _num(self, obj, name, val):
        if self.SCHEMA:
            kind = self.SCHEMA[obj.get('class')][name]['type']
            if kind in ('int','int64'): return self._prop(obj,kind,name,str(int(val)))
            return self._prop(obj,kind,name, format(float(val),'.17g' if kind=='double' else '.9g'))
        if (obj.get('class'),name) in DOUBLE: return self._prop(obj,'double',name,format(float(val),'.17g'))
        if name in FLOAT32: return self._prop(obj,'float',name,format(float(val),'.9g'))
        if name in INT32: return self._prop(obj,'int',name,str(int(val)))
        return self._prop(obj,'double' if isinstance(val,float) else 'int', name, str(val))
    def _integer(self,obj,name,val): return self._prop(obj,'int',name,val)
    def _token(self,obj,name,val): return self._prop(obj,'token',name,val)
    def _boolean(self,obj,name,val): return self._prop(obj,'bool',name,str(bool(val)).lower())
    def _ref(self,obj,name,val): return self._prop(obj,'Ref',name, val.attrib['referent'] if val is not None else 'null')
    def _color(self,obj,name,rgb):
        e=self._prop(obj,'Color3',name)
        for k,v in zip('RGB',rgb): ET.SubElement(e,k).text=f'{v/255:.7g}'
    def _vec(self,obj,name,v,dim=3):
        e=self._prop(obj,'Vector'+str(dim),name)
        for k,x in zip('XYZ',v): ET.SubElement(e,k).text=f'{float(x):.7g}'
    def _udim(self,obj,name,v):
        e=self._prop(obj,'UDim2',name)
        for k,x in zip(['XS','XO','YS','YO'],v): ET.SubElement(e,k).text=str(x)
    def _cf(self,obj,name,position=(0,0,0),rotation=None):
        rotation=np.eye(3) if rotation is None else np.asarray(rotation)
        e=self._prop(obj,'CoordinateFrame',name)
        for k,x in zip('XYZ',position): ET.SubElement(e,k).text=f'{float(x):.7g}'
        for i in range(3):
            for j in range(3): ET.SubElement(e,f'R{i}{j}').text=f'{rotation[i,j]:.8g}'
    def _rot(self,x=0,y=0,z=0):
        cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
        return np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]]) @ np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]]) @ np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]])
    def _lookat(self,pos,target):
        back=np.array(pos,dtype=float)-np.array(target,dtype=float)
        if np.linalg.norm(back)>1e-6: back/=np.linalg.norm(back)
        right=np.cross(np.array([0.,1,0]),back)
        if np.linalg.norm(right)<.0001: right=np.array([1.,0,0])
        right/=np.linalg.norm(right); up=np.cross(back,right)
        return np.column_stack((right,up,back))
    def _tint(self,c,delta): return tuple(max(0,min(255,v+delta)) for v in c)
    def inst(self, cls, name, parent=None):
        self._serial+=1
        while f'RBX{self._serial:07d}' in self._taken: self._serial+=1
        ref=f'RBX{self._serial:07d}'; self._taken.add(ref)
        obj=ET.SubElement(parent if parent is not None else self.R,'Item',{'class':cls,'referent':ref})
        ET.SubElement(obj,'Properties'); self._text(obj,'Name',name)
        if cls=='Model': self._ref(obj,'PrimaryPart',None)
        return obj
    def model(self,name,parent): return self.inst('Model',name,parent)
    def folder(self,name,parent): return self.inst('Folder',name,parent)
    def _value(self,cls,name,v,parent):
        obj=self.inst(cls,name,parent)
        if cls=='StringValue': self._text(obj,'Value',v)
        elif cls=='Vector3Value': self._vec(obj,'Value',v)
        elif cls=='NumberValue': self._num(obj,'Value',v)
        elif cls=='BoolValue': self._boolean(obj,'Value',v)
        return obj
    def _weld(self,parent,a,b,name='DetailWeld'):
        w=self.inst('WeldConstraint',name,parent); self._ref(w,'Part0',a); self._ref(w,'Part1',b); return w
    def _joint(self,parent,name,a,b,pivot):
        obj=self.inst('Motor6D',name,parent); self._ref(obj,'Part0',a); self._ref(obj,'Part1',b)
        pa,ra=self.frames[a.attrib['referent']]; pb,rb=self.frames[b.attrib['referent']]; p=np.array(pivot)
        self._cf(obj,'C0', ra.T@(p-pa), ra.T); self._cf(obj,'C1', rb.T@(p-pb), rb.T)
        return obj
    def part(self,name,parent,pos,size,c='stone',material='Slate',shape='Block',rotation=None,collide=True,alpha=0,anchored=True,record=True):
        c=COL.get(c,c) if isinstance(c,str) else c
        cls='WedgePart' if shape=='Wedge' else 'Part'
        obj=self.inst(cls,name,parent)
        r=np.eye(3) if rotation is None else rotation
        self._cf(obj,'CFrame',pos,r); self._vec(obj,'size',size)
        self._color(obj,'Color',c); self._token(obj,'Material',MAT[material])
        self._boolean(obj,'Anchored',anchored); self._boolean(obj,'CanCollide',collide); self._boolean(obj,'CanTouch',False)
        self._boolean(obj,'CanQuery',collide); self._boolean(obj,'CastShadow',alpha<.5 and material!='Neon')
        self._num(obj,'Transparency',alpha); self._num(obj,'Reflectance',0)
        self._token(obj,'TopSurface',0); self._token(obj,'BottomSurface',0)
        if cls=='Part': self._token(obj,'shape',{'Block':1,'Ball':0,'Cylinder':2}[shape])
        self.frames[obj.attrib['referent']]=(np.array(pos,dtype=float),np.array(r))
        self.sizes[obj.attrib['referent']]=size
        if not anchored: self._boolean(obj,'Massless',not collide)
        if record and alpha<.96:
            self.scene.append({'n':name,'p':[round(float(v),3) for v in pos],'s':[round(float(v),3) for v in size],'r':[round(float(v),5) for v in np.asarray(r).flat],'c':c,'m':material,'k':shape,'a':alpha})
        return obj
    def ball(self,name,parent,pos,size,c,mat='SmoothPlastic',alpha=0): return self.part(name,parent,pos,size,c,mat,'Ball',collide=False,alpha=alpha)
    def cylinder(self,name,parent,pos,height,radius,c,mat='Slate',collide=True,alpha=0): return self.part(name,parent,pos,(height,radius*2,radius*2),c,mat,'Cylinder',self._rot(z=pi/2),collide,alpha)
    def rod(self,name,parent,a,b,width,c,mat='Wood',collide=False,shape='Cylinder'):
        a=np.array(a);b=np.array(b);delta=b-a; length=np.linalg.norm(delta)
        x=delta/length; y=np.cross(np.array([0.,0,1]),x)
        if np.linalg.norm(y)<.01: y=np.cross(np.array([0.,1,0]),x)
        y/=np.linalg.norm(y); z=np.cross(x,y); r=np.column_stack((x,y,z))
        return self.part(name,parent,(a+b)/2,(length,width,width),c,mat,shape,r,collide)
    def triangle(self,name,parent,a,b,c,color_,mat='Rock'):
        pts=[np.asarray(x,dtype=float) for x in (a,b,c)]
        edges=[(0,1,2),(1,2,0),(2,0,1)]
        i,j,k=max(edges,key=lambda t: np.linalg.norm(pts[t[0]]-pts[t[1]]))
        a,b,c=pts[i],pts[j],pts[k]
        along=(b-a)/np.linalg.norm(b-a); foot=a+along*np.dot(c-a,along)
        h=np.linalg.norm(c-foot)
        if h<.01: return
        y=(c-foot)/h
        for point in (a,b):
            d=np.linalg.norm(point-foot)
            if d<.01: continue
            z=(foot-point)/d; x=np.cross(y,z); p=(point+c)/2
            self.part(name,parent,p,(.25,h,d),color_,mat,'Wedge',np.column_stack((x,y,z)),False)
    def ring(self,name,parent,center,radius,width,c,mat='Neon',segments=48,vertical=False):
        cx,cy,cz=center
        for i in range(segments):
            a=i/segments*2*pi; b=(i+1)/segments*2*pi
            if vertical: p=(cx+math.cos(a)*radius,cy+math.sin(a)*radius,cz); q=(cx+math.cos(b)*radius,cy+math.sin(b)*radius,cz)
            else: p=(cx+math.cos(a)*radius,cy,cz+math.sin(a)*radius); q=(cx+math.cos(b)*radius,cy,cz+math.sin(b)*radius)
            self.rod(name,parent,p,q,width,c,mat)

    def billboard(self,parent,title,subtitle='',width=230,offset=3,c=(229,224,199),health=False):
        gui=self.inst('BillboardGui','Nameplate',parent); self._udim(gui,'Size',(0,width,0,66))
        self._vec(gui,'StudsOffset',(0,offset,0)); self._boolean(gui,'AlwaysOnTop',False); self._num(gui,'MaxDistance',95)
        self._num(gui,'LightInfluence',0)
        def _label(name,parent,msg,pos,size):
            o=self.inst('TextLabel',name,parent); self._text(o,'Text',msg); self._udim(o,'Position',pos); self._udim(o,'Size',size)
            self._num(o,'BackgroundTransparency',1); self._num(o,'BorderSizePixel',0); self._token(o,'Font',19); self._num(o,'TextSize',17)
            self._color(o,'TextColor3',c); self._num(o,'TextStrokeTransparency',.5)
            return o
        t=_label('Title',gui,title,(0,0,0,0),(1,0,0,25)); self._token(t,'TextXAlignment',2)
        if subtitle:   # shipped NPC nameplates: "LANTERNWAKE CARTOGRAPHER" under the name
            st=_label('Subtitle',gui,subtitle,(0,0,0,28),(1,0,0,22)); self._num(st,'TextSize',12); self._color(st,'TextColor3',(170,205,195))
        if health:
            bar=self.inst('Frame','Bar',gui); self._udim(bar,'Position',(0.1,0,0,34)); self._udim(bar,'Size',(.8,0,0,5))
            self._color(bar,'BackgroundColor3',(28,38,48)); self._num(bar,'BackgroundTransparency',.1); self._num(bar,'BorderSizePixel',0)
            fill=self.inst('Frame','Fill',bar); self._udim(fill,'Size',(1,0,1,0)); self._color(fill,'BackgroundColor3',c)
            self._num(fill,'BorderSizePixel',0)   # EnemyService.updateHealthBillboard resizes Bar.Fill
        return gui

    def create(self, kind, name, parent, position, **opts):
        if kind not in self.catalog: raise ValueError(f'Unknown kind {kind!r}. Known: {list(self.catalog)}')
        return self.catalog[kind](name, parent, position, **opts)

    def house(self, name, parent, position, accent='redwood', yaw=0):
        m=self.model(name,parent); base=np.array(position); r=self._rot(y=yaw)
        def p(n,xyz,size,col='wood',mat='WoodPlanks',collide=False,rotation=None,shape='Block'):
            return self.part(n,m,base+r@np.array(xyz),size,col,mat,shape,rotation=r@(np.eye(3) if rotation is None else rotation),collide=collide)
        p('RaisedStoneFoundation',(0,.35,0),(21,.7,19),'stone','Slate',True)
        p('TimberFloor',(0,.85,0),(18,.3,16),'wood','WoodPlanks',True)
        for x in [-9,9]: p('SideWall',(x,4.7,0),(.7,7.6,16),'paper','Plaster' if 'Plaster' in MAT else 'Sandstone',True)
        p('RearWall',(0,4.7,8),(18,7.6,.7),'paper','Sandstone',True)
        for x in [-5.7,5.7]: p('DoorSideWall',(x,4.7,-8),(6.5,7.6,.7),'paper','Sandstone',True)
        p('DoorLintel',(0,8,-8),(5.2,1.3,.85),accent,'Wood',True)
        for x in [-9,-2.4,2.4,9]:
            p('FacadePost',(x,4.7,-8.5),(.42,8.3,.5),accent,'Wood')
            p('PostFoot',(x,1.2,-8.5),(.8,1,.85),'stone','Slate')
        for z in [-8,0,8]:
            for x in [-9.5,9.5]: p('WallTimber',(x,4.7,z),(.5,8.2,.5),accent,'Wood')
        # v0.4.1: the 1.5 / 4.5 beams used to run straight across the doorway (x -2.19..2.19).
        # They now stop at the door posts (x = +-2.4, hidden inside the post) on each side.
        for y in [1.5,4.5]:
            for sx in [-1,1]: p('CrossBeam',(sx*6.025,y,-8.5),(7.25,.35,.4),accent,'Wood')
        p('CrossBeam',(0,8.4,-8.5),(19.3,.35,.4),accent,'Wood')
        for x in [-5.7,5.7]:
            p('WarmPaperWindow',(x,5.3,-8.43),(3.4,3.6,.08),(207,186,124),'SmoothPlastic')
            for dx in [-1.65,-.8,0,.8,1.65]: p('WindowLattice',(x+dx,5.3,-8.52),(.10,3.7,.12),'dark','Wood')
            for y in [3.6,4.7,5.8,7]: p('WindowLattice',(x,y,-8.54),(3.5,.10,.12),'dark','Wood')
        for side in [-1,1]:
            for course in range(8):
                z=side*(course*1.4+.4); y=12-course*.48+(max(0,course-5)**2)*.12
                p('RoofCourse',(0,y,z),(22,.45,1.6),accent,'Slate',False,self._rot(x=side*.31))
                for x in range(-10,11,2): p('RoofRib',(x,y+.26,z),(.10,.13,1.64),'gold','Metal',False,self._rot(x=side*.31))
        p('RoofRidge',(0,12.45,0),(23,.32,.4),'gold','Metal')
        # v0.4.1: the walls stop at y 8.5 but the roof underside is ~9.2 at the eaves and ~11.9 at the ridge,
        # which left open triangles above both side walls and a slot above the front/rear walls.
        wall_mat='Plaster' if 'Plaster' in MAT else 'Sandstone'
        for x in [-9,9]:
            p('GableInfill',(x,8.89,0),(.7,.78,16.7),'paper',wall_mat,True)
            for zs in [-1,1]:   # wedge: vertical face at the ridge (z=0), slope down to the eave line
                p('GableInfill',(x,10.70,zs*4.175),(.7,2.84,8.35),'paper',wall_mat,True,None if zs<0 else self._rot(y=pi),shape='Wedge')
        for z in [-8,8]: p('EaveInfill',(0,8.95,z),(18.7,.9,.7),'paper','Sandstone',True)
        # SweptEave trim sat 1.3 studs above the eave edge; move it onto the lowest roof course's outer edge
        for z in [-10.98,10.98]: p('SweptEave',(0,8.88,z),(23,.22,.28),'gold','Metal')
        for x in [-8,8]:
            lx,ly,lz = base+r@np.array([x,6.6,-10])
            lm=self.model('SpiritLantern',m)
            self.part('LanternBody',lm,(lx,ly,lz),(1.04,1.3,1.04),'paper','Neon',collide=False)
            for dy in [-0.7475,0.7475]: self.part('EaveCap',lm,(lx,ly+dy,lz),(1.365,.195,1.365),'dark','Metal',collide=False)
        p('ServingTable',(-5,2.7,3),(5,.35,3),'wood','Wood',True)
        for x in [-7,-3]: p('TableLeg',(x,1.8,3),(.3,1.7,.3),'wood','Wood',True)
        p('SleepingMat',(4,1.2,4),(4,.25,6),'redwood','Fabric')
        for i in range(4): p('FoldedBedding',(4,1.4+i*.12,6),(3.4,.12,1.1),'paper','Fabric')
        for obj in m.iter('Item'):
            n=obj.find('Properties/string[@name="Name"]')
            if n is not None and n.text=='RoofCourse': self._boolean(obj,'CanQuery',True)
        return m

    def stall(self, name, parent, position, accent='jade'):
        m=self.model(name,parent); x,y,z=position
        self.part('Counter',m,(x,y+2.5,z),(9,.45,4),'wood','WoodPlanks',collide=True)
        for dx in [-4,4]:
            for dz in [-1.7,1.7]: self.rod('AwningPost',m,(x+dx,y,z+dz),(x+dx,y+7,z+dz),.22,'redwood')
        for i in range(9):
            self.part('CanvasStripe',m,(x-4+i,y+6.5,z),(1.03,.16,5.4),accent if i%2 else 'paper','Fabric',rotation=self._rot(x=.1),collide=False)
            self.part('ScallopedValance',m,(x-4+i,y+6.05,z-2.7),(1,.8,.12),accent if i%2 else 'paper','Fabric','Wedge',collide=False)
        for dx in [-2.8,0,2.8]:
            self.part('ProduceTray',m,(x+dx,y+2.9,z),(2.1,.22,2.6),'gold','Wood',collide=False)
            for i in range(6): self.ball('MarketFruit',m,(x+dx+(i%2-.5)*.6,y+3.2,z+(i//2-1)*.7),(.65,.6,.65),'pink' if dx<0 else 'jade')
        return m

    def mountain(self, name, parent, position, radius=90, height=100):
        a=self; m=self.model(name,parent); x,y,z=position; segments=12; layers=[]
        for layer in range(5):
            fraction=layer/4; rad=radius*(1-fraction*.88)
            points=[]
            for i in range(segments):
                angle=i/segments*math.tau
                points.append((x+math.cos(angle)*rad*self.rng.uniform(.88,1.08),y+height*fraction+self.rng.uniform(-3,3),z+math.sin(angle)*rad*self.rng.uniform(.88,1.08)))
            layers.append(points)
            self.cylinder('MountainTerrace',m,(x,y+height*fraction-2,z),4,rad*.80,'rock2','Rock',True)
        for j in range(4):
            for i in range(segments):
                n=(i+1)%segments; col='snow' if j==3 else ('rock2' if i%2 else 'rock3')
                self.triangle('MountainFace',m,layers[j][i],layers[j+1][i],layers[j][n], COL[col],'Rock')
                self.triangle('MountainFace',m,layers[j][n],layers[j+1][i],layers[j+1][n], COL[col],'Rock')
        for step in range(int(height/2)+1):
            fraction=step/max(1,int(height/2)); angle=fraction*math.pi*2.1; rr=radius*(1-fraction*.87)*.80
            self.part('MountainTrail',m,(x+math.cos(angle)*rr,y+height*fraction+.2,z+math.sin(angle)*rr),(8,.6,8),'stone','Rock',collide=True)
        return m

    def reeds(self, name, parent, position, scale=1):
        m=self.model(name,parent); x,y,z=position
        for j in range(9):
            dx=self.rng.uniform(-2,2)*scale; dz=self.rng.uniform(-2,2)*scale; h=self.rng.uniform(2,5)*scale
            self.rod('ReedStalk',m,(x+dx,y,z+dz),(x+dx+.25,y+h,z+dz),.07*scale,'leaf')
            self.ball('Cattail',m,(x+dx+.25,y+h,z+dz),(.22*scale,.75*scale,.22*scale),'bark')
        return m

    def spider(self, name, parent, position, scale=1, matriarch=False):
        base=np.array(position,float); s=scale; m=self.model(name,parent); _s0=len(self.scene)
        palette=(44,65,73) if not matriarch else (68,47,77); glow=(121,207,178) if not matriarch else (222,148,204)
        def part_(n,offset,size,c=palette,shape='Ball',r=None,solid=False,visible=True):
            return self.part(n,m,base+np.array(offset)*s,np.array(size)*s,c,'SmoothPlastic',shape,r,solid,alpha=0 if visible else 1,anchored=False,record=visible)
        def deco(n,bone,offset,size,c=palette,shape='Ball',r=None):
            p=part_(n,offset,size,c,shape,r); self._weld(p,bone,p); return p
        root=part_('HumanoidRootPart',(0,3,0),(3,2,4),solid=True,visible=False)
        self._boolean(root,'Massless',False); self._integer(root,'RootPriority',127); self._ref(m,'PrimaryPart',root)
        thorax=part_('Thorax',(0,3,0),(3.4,2.1,4.2)); self._joint(m,'SpiderRoot',root,thorax,base+np.array([0,3,0])*s)
        abdomen=part_('Abdomen',(0,3.35,3.2),(4.7,3.35,5.2)); self._joint(m,'AbdomenJoint',thorax,abdomen,base+np.array([0,3.15,1.9])*s)
        head=part_('Head',(0,3,-2.1),(2.9,1.65,2.0)); self._joint(m,'SpiderNeck',thorax,head,base+np.array([0,3,-1.3])*s)
        for i in range(6):
            z=1.4+i*.63
            deco('AbdominalScute',abdomen,(0,4.6-i*.035,z),(3.9-abs(i-2.5)*.32,.20,.43),(70+i*3,89,91),'Block')
            for side in [-1,1]: deco('SilkRune',abdomen,(side*(1.6-abs(i-2.5)*.15),4.0,z),(.18,.30,.30),glow)
        for side in [-1,1]:
            for index in range(4):
                z=-1.8+index*1.18; out=5.3+(.5 if index in [1,2] else 0)
                hip=np.array([side*1.35,3,z]); knee=np.array([side*3.5,4.6,z+(-1.8+index*1.1)])
                ankle=np.array([side*out,1.15,z+(-2.8+index*1.8)]); toe=np.array([side*(out+.35),.15,ankle[2]-.4])
                prior=thorax
                for segment,(begin,end,width) in enumerate([(hip,knee,.52),(knee,ankle,.34),(ankle,toe,.19)],1):
                    d=end-begin; length=np.linalg.norm(d); axis=d/length; up=np.cross([0,0,1],axis)
                    if np.linalg.norm(up)<.01: up=np.cross([0,1,0],axis)
                    up/=np.linalg.norm(up); back=np.cross(axis,up)
                    bone=part_(f'Leg{side}_{index}_{segment}',(begin+end)/2,(length,width,width),palette,'Cylinder',np.column_stack((axis,up,back)))
                    side_char='L' if side<0 else 'R'
                    self._joint(m,f'Leg_{side_char}{index+1}_{segment}',prior,bone,base+begin*s)
                    deco('JointSocket',bone,begin,(width*1.7,)*3,(87,105,100))
                    for hair in range(3):
                        t=(hair+1)/4; pos=begin+d*t
                        deco('SensoryBristle',bone,pos+[0,.18,.12],(.10,.42,.08),(24,35,39),'Wedge',self._rot(z=-side*.35))
                    prior=bone
            for i in range(4):
                x=side*(.26+(i%2)*.58); yy=3.05+(i//2)*.43; zz=-3.04+(i%2)*.07
                deco('EyeSocket',head,(x,yy,zz),(.40,.36,.18),(12,22,27))
                eye=deco('SpiderEye',head,(x,yy,zz-.09),(.22,.22,.13),glow)
                self._token(eye,'Material',MAT['Neon'])
            fang=part_('Fang'+str(side),(side*.72,2.15,-3.0),(.48,1.25,.5),'stone','Wedge',self._rot(x=.35,z=-side*.2))
            self._joint(m,'Fang_'+str(side),head,fang,base+np.array([side*.72,2.65,-2.65])*s)
        core=deco('QiCore',abdomen,(0,4.8,3.1),(.45,.25,.6),glow); self._token(core,'Material',MAT['Neon'])
        if matriarch:
            for i in range(5): deco('MatriarchCrest',abdomen,((i-2)*.6,5.0,3.1),(.24,1.2-abs(i-2)*.2,.4),'gold','Wedge')
        hum=self.inst('Humanoid','Humanoid',m)
        for key,v in [('HipHeight',2*s),('WalkSpeed',12),('Health_XML',160 if not matriarch else 900),('MaxHealth',160 if not matriarch else 900),('JumpPower',0)]: self._num(hum,key,v)
        self._text(hum,'DisplayName',name.replace('_',' '))
        self._token(hum,'RigType',1); self._token(hum,'DisplayDistanceType',2); self._boolean(hum,'RequiresNeck',False); self._boolean(hum,'BreakJointsOnDeath',False); self._boolean(hum,'UseJumpPower',True)
        self._value('StringValue','Archetype','SilkMatriarch' if matriarch else 'SilkSpider',m)
        self._value('StringValue','RigKind','Spider',m)
        self.billboard(head,'The Silk Matriarch' if matriarch else 'Jade Silkweaver',width=240,offset=2.5*s,c=glow,health=True)
        for entry in self.scene[_s0:]: entry['asset']=name
        return m

    def tree(self, name, parent, position, scale=1, style='jade'):
        x,y,z=position; m=self.model(name,parent); _s0=len(self.scene)
        self._value('NumberValue','WindWeight',.55 if scale>2 else 1,m)
        canopy=self.model('WindCanopy',m)
        bark=(72,63,67) if style=='snow' else COL['bark']
        leaf=(143,191,193) if style=='snow' else COL['pink'] if style=='pink' else COL['leaf']
        height=(19 if style!='snow' else 27)*scale
        main=[]
        for i in range(6):
            main.append(np.array([x+math.sin(i*.7)*scale*.7,y+i*height/5,z+math.cos(i*.9)*scale*.5]))
        for i in range(5):
            self.rod('TrunkSegment',m,main[i],main[i+1],(3.7-i*.40)*scale,bark,collide=True)
            for k in range(3):
                a=k*2*pi/3+i*.3
                p=main[i]+np.array([math.cos(a)*1.8*scale,.1,math.sin(a)*1.8*scale])
                q=p+np.array([.15,height/5*.8,.15])
                self.rod('BarkRidge',m,p,q,.17*scale,self._tint(bark,-14))
        for i in range(9):
            a=i/9*2*pi
            p=(x+math.cos(a)*2*scale,y+2*scale,z+math.sin(a)*2*scale)
            q=(x+math.cos(a)*6*scale,y+.3,z+math.sin(a)*6*scale)
            self.rod('ButtressRoot',m,p,q,1.1*scale,bark)
            self.rod('RootTip',m,q,(q[0]+math.cos(a)*2*scale,y+.1,q[2]+math.sin(a)*2*scale),.42*scale,bark)
        if style=='snow':
            for layer in range(6):
                yy=y+height*(.34+layer*.105); radius=(8-layer*.95)*scale
                for i in range(7):
                    a=i/7*2*pi+layer*.52
                    tip=np.array([x+math.cos(a)*radius,yy-1.5*scale,z+math.sin(a)*radius])
                    self.rod('PineBough',canopy,(x,yy,z),tip,.45*scale,bark)
                    self.ball('NeedleSpray',canopy,tip,(4.2*scale,1.65*scale,3.8*scale),self._tint((53,95,100),self.rng.randint(-10,10)),'Grass')
                    self.ball('FreshSnow',canopy,tip+np.array([0,.75*scale,0]),(4.1*scale,.8*scale,3.6*scale),self._tint(COL['snow'],self.rng.randint(-5,8)),'Snow')
            self.ball('PineCrown',canopy,(x,y+height+1.2*scale,z),(3*scale,5*scale,3*scale),'snow','Snow')
        else:
            for i in range(11):
                a=i/11*2*pi+self.rng.uniform(-.2,.2)
                b0=main[self.rng.choice([2,3,4])]
                reach=self.rng.uniform(6.5,11)*scale
                mid=np.array([x+math.cos(a)*reach*.60,y+height*.88+self.rng.uniform(-2,3)*scale,z+math.sin(a)*reach*.60])
                tip=np.array([x+math.cos(a)*reach,y+height+self.rng.uniform(-3,3)*scale,z+math.sin(a)*reach])
                self.rod('PrimaryBough',canopy,b0,mid,1.2*scale,bark)
                self.rod('SecondaryBough',canopy,mid,tip,.6*scale,bark)
                for k in range(3):
                    offset=np.array([self.rng.uniform(-2.2,2.2),self.rng.uniform(-.7,2.4),self.rng.uniform(-2.2,2.2)])*scale
                    point=tip+offset
                    self.rod('LeafTwig',canopy,tip,point,.18*scale,bark)
                    self.ball('FoliageCluster',canopy,point,(self.rng.uniform(4.2,6.4)*scale,self.rng.uniform(2.8,4.1)*scale,self.rng.uniform(4.5,6.5)*scale),self._tint(leaf,self.rng.randint(-19,22)),'Grass')
                    for q in range(2):
                        leafpoint=point+np.array([self.rng.uniform(-2.3,2.3),self.rng.uniform(.7,2),self.rng.uniform(-2.3,2.3)])*scale
                        self.part('IndividualLeaf',canopy,leafpoint,(1.5*scale,.12*scale,.65*scale),self._tint(leaf,self.rng.randint(-6,28)),'SmoothPlastic','Wedge',self._rot(.15,self.rng.uniform(0,pi),.25),False)
            self.ball('HighCrown',canopy,(x,y+height+2*scale,z),(9*scale,5*scale,9*scale),self._tint(leaf,9),'Grass')
        pivot=self.part('WindPivot',canopy,(x,y+height*.58,z),(1,1,1),'bark',alpha=1,collide=False,record=False)
        self._ref(canopy,'PrimaryPart',pivot)
        for i in range(5):
            av=i*1.25; p=(x+math.cos(av)*3*scale,y+.3,z+math.sin(av)*3*scale)
            self.ball('RootMoss',m,p,(2.3*scale,.5*scale,1.7*scale),'moss','Grass')
        for entry in self.scene[_s0:]: entry['asset']=name
        return m

    def island(self, name, parent, position, radius=90, biome='grass'):
        cx,h,cz=position; m=self.model(name,parent)
        grass=COL['snow'] if biome=='snow' else COL['grass'] if biome=='grass' else (78,83,102)
        mat='Snow' if biome=='snow' else 'Grass' if biome=='grass' else 'Slate'
        self.cylinder('WalkableCrown',m,(cx,h-2,cz),4,radius*.95,grass,mat)
        self.cylinder('UpperStratum',m,(cx,h-5.0,cz),4,radius*.96,'rock3','Rock')
        segments=20
        ring_points=[]; phases=[self.rng.uniform(.91,1.07) for _ in range(segments)]
        for level,(scale,depth) in enumerate([(1,3),(.92,15),(.67,33),(.39,53),(.08,72)]):
            ring_points.append([np.array([cx+math.cos(i/segments*2*pi)*radius*scale*phases[i],h-depth*radius/90-self.rng.uniform(0,4),cz+math.sin(i/segments*2*pi)*radius*scale*phases[i]]) for i in range(segments)])
        for level in range(len(ring_points)-1):
            for i in range(segments):
                j=(i+1)%segments; c=self._tint(COL['rock' if level>1 else 'rock2'],self.rng.randint(-12,12))
                self.triangle('CliffFacet',m,ring_points[level][i],ring_points[level+1][i],ring_points[level][j],c)
                self.triangle('CliffFacet',m,ring_points[level][j],ring_points[level+1][i],ring_points[level+1][j],self._tint(c,-5))
        for i in range(segments):
            a=i/segments*2*pi; rr=radius*self.rng.uniform(.86,.95); x,z=cx+math.cos(a)*rr,cz+math.sin(a)*rr
            self.ball('WeatheredRim',m,(x,h-1.8,z),(self.rng.uniform(10,18),self.rng.uniform(4,7),self.rng.uniform(10,18)),self._tint(grass,self.rng.randint(-8,12)),mat)
            if i%2==0:
                tip=(x+self.rng.uniform(-5,5),h-self.rng.uniform(27,52),z+self.rng.uniform(-5,5))
                self.rod('HangingRoot',m,(x,h-5,z),tip,1.2,'bark')
                self.rod('RootFork',m,tuple(np.array((x,h-5,z))*.4+np.array(tip)*.6),(tip[0]+self.rng.uniform(-6,6),tip[1]-8,tip[2]+self.rng.uniform(-6,6)),.55,'bark')
        return m

    def waterfall(self, name, parent, position, width=9, drop=80):
        x,y,z=position; m=self.model(name,parent)
        for i in range(5):
            xx=x+(i-2)*width/5
            p=self.part('FlowAnchor',m,(xx,y-.3,z),(1,1,1),'water',alpha=1,collide=False,record=False)
            a=self.inst('Attachment','Lip',p); self._cf(a,'CFrame',(0,0,0))
            b=self.inst('Attachment','Fall',p); self._cf(b,'CFrame',(self.rng.uniform(-1.5,1.5),-drop,self.rng.uniform(-1,1)))
            beam=self.inst('Beam','FallingWater',p); self._ref(beam,'Attachment0',a); self._ref(beam,'Attachment1',b)
            self._num(beam,'Width0',width/4); self._num(beam,'Width1',width/3); self._boolean(beam,'FaceCamera',True)
            self._num(beam,'LightEmission',.35); self._num(beam,'LightInfluence',.2); self._num(beam,'TextureSpeed',1.6)
            self._prop(beam,'ColorSequence','Color','0 0.57 0.91 0.95 0 1 0.86 0.94 1 0')
            self._prop(beam,'NumberSequence','Transparency','0 0.34 0 0.78 0.55 0 1 1 0')
            self._num(beam,'CurveSize0',3); self._num(beam,'CurveSize1',5); self._integer(beam,'Segments',12)
            self.part('WaterRibbon',m,(xx,y-drop*.43,z),(width/5,drop*.86,.12),'water','Glass',alpha=.77,collide=False)
        for i in range(7): self.ball('FallMist',m,(x+self.rng.uniform(-width,width),y-drop+self.rng.uniform(-3,4),z+self.rng.uniform(-3,3)),(12,7,10),(191,227,232),'SmoothPlastic',.85)
        self.cylinder('SpringPool',m,(x,y+.04,z-6),.13,width*.7,'water','Glass',False,.24)
        return m

    def bridge(self, name, parent, a, b):
        m=self.model(name,parent); a=np.array(a,dtype=float); b=np.array(b,dtype=float)
        d=b-a; length=np.linalg.norm(d); count=int(length/3.4)+1
        tangent=np.array([d[0],0,d[2]]); tangent/=np.linalg.norm(tangent) if np.linalg.norm(tangent)>1e-6 else 1; right=np.cross(tangent,[0,1,0])
        if np.linalg.norm(right)>1e-6: right/=np.linalg.norm(right)
        for i in range(count+1):
            t=i/count; p=a+d*t+np.array([0,math.sin(t*pi)*3,0])
            self.part('BridgePlank',m,p,(10,.6,length/count+0.2),'wood','WoodPlanks','Block',self._rot(y=math.atan2(d[0],d[2])) if np.linalg.norm(d)>1e-6 else None,True)
        return m

    def enemy(self, name, parent, position, style='JadeWarden', scale=1.3):
        return self._rig(name, parent, position, style=style, scale=scale, enemy=True)
    def npc(self, name, parent, position, style='player', scale=1.0, role='Cartographer', subtitle=None):
        return self._rig(name, parent, position, style=style, scale=scale, enemy=False, role=role, subtitle=subtitle)

    def _rig(self,name,parent,position,style='player',scale=1,enemy=False,role=None,subtitle=None):
        x,y,z=position; m=self.model(name,parent); s=scale; _s0=len(self.scene)
        palette={'player':((41,68,77),(129,236,201),(217,183,113)),'elder':((214,212,191),(134,223,202),(212,181,109)),'alchemist':((84,62,100),(225,164,226),(204,167,102)),'ferryman':((59,84,102),(136,197,231),(178,157,101)),'JadeWarden':((41,80,75),(109,235,181),(173,177,113)),'StormDisciple':((46,56,91),(141,195,255),(177,191,220)),'LotusSovereign':((63,45,83),(255,155,211),(220,185,116))}
        cloth,accent,metal=palette.get(style, palette['player']); skin=(219,180,148) if not enemy else (76,90,100)
        root=self.part('HumanoidRootPart',m,(x,y+3*s,z),(2*s,2*s,1*s),cloth,anchored=False,collide=False,alpha=1,record=False)
        self._ref(m,'PrimaryPart',root); self._boolean(root,'Massless',False); self._integer(root,'RootPriority',127)
        specs={'LowerTorso':((0,2.65,0),(1.6,.75,.86),cloth),'UpperTorso':((0,3.65,0),(1.85,1.35,.92),cloth),'Head':((0,5.03,0),(1.12,1.15,1.05),skin),'LeftUpperArm':((-1.26,3.65,0),(.62,1.20,.68),cloth),'LeftLowerArm':((-1.26,2.64,0),(.55,.87,.60),skin),'LeftHand':((-1.26,2.01,-.02),(.55,.45,.62),skin),'RightUpperArm':((1.26,3.65,0),(.62,1.20,.68),cloth),'RightLowerArm':((1.26,2.64,0),(.55,.87,.60),skin),'RightHand':((1.26,2.01,-.02),(.55,.45,.62),skin),'LeftUpperLeg':((-.46,1.85,0),(.69,1.00,.72),cloth),'LeftLowerLeg':((-.46,.88,0),(.63,.85,.66),cloth),'LeftFoot':((-.46,.26,-.16),(.69,.44,1.0),cloth),'RightUpperLeg':((.46,1.85,0),(.69,1.00,.72),cloth),'RightLowerLeg':((.46,.88,0),(.63,.85,.66),cloth),'RightFoot':((.46,.26,-.16),(.69,.44,1.0),cloth)}
        body={'HumanoidRootPart':root}
        for n,(off,sz,col) in specs.items():
            body[n]=self.part(n,m,np.array((x,y,z))+np.array(off)*s,np.array(sz)*s,col,'SmoothPlastic','Ball' if n=='Head' else 'Block',anchored=False,collide=n in ['UpperTorso','LowerTorso'],record=False)
        body['QiCore']=self.part('QiCore',m,(x,y+3.72*s,z-.74*s),(.33*s,.48*s,.24*s),accent,'Neon','Ball',anchored=False,collide=False,record=False)
        conns=[('Root','HumanoidRootPart','LowerTorso',(0,3,0)),('Waist','LowerTorso','UpperTorso',(0,3.02,0)),('Neck','UpperTorso','Head',(0,4.41,0)),('LeftShoulder','UpperTorso','LeftUpperArm',(-1.06,4.13,0)),('LeftElbow','LeftUpperArm','LeftLowerArm',(-1.26,3.08,0)),('LeftWrist','LeftLowerArm','LeftHand',(-1.26,2.21,0)),('RightShoulder','UpperTorso','RightUpperArm',(1.06,4.13,0)),('RightElbow','RightUpperArm','RightLowerArm',(1.26,3.08,0)),('RightWrist','RightLowerArm','RightHand',(1.26,2.21,0)),('LeftHip','LowerTorso','LeftUpperLeg',(-.46,2.34,0)),('LeftKnee','LeftUpperLeg','LeftLowerLeg',(-.46,1.34,0)),('LeftAnkle','LeftLowerLeg','LeftFoot',(-.46,.46,0)),('RightHip','LowerTorso','RightUpperLeg',(.46,2.34,0)),('RightKnee','RightUpperLeg','RightLowerLeg',(.46,1.34,0)),('RightAnkle','RightLowerLeg','RightFoot',(.46,.46,0)),('CoreJoint','UpperTorso','QiCore',(0,3.72,-.74))]
        for n,a_,b_,piv in conns:
            joint=self._joint(m,n,body[a_],body[b_],np.array((x,y,z))+np.array(piv)*s)
            if n!='CoreJoint':   # shipped rigs: 15 R15 joints x 2 RigAttachments at C0 / C1
                for part_,cfname in ((body[a_],'C0'),(body[b_],'C1')):
                    pa,ra=self.frames[part_.attrib['referent']]; world=np.array((x,y,z))+np.array(piv)*s
                    att=self.inst('Attachment',n+'RigAttachment',part_); self._cf(att,'CFrame',ra.T@(world-pa))
        hum=self.inst('Humanoid','Humanoid',m); self._token(hum,'RigType',1); self._num(hum,'HipHeight',2*s); self._num(hum,'WalkSpeed',18)
        self._num(hum,'MaxHealth',120); self._num(hum,'Health_XML',120); self._token(hum,'DisplayDistanceType',2); self._boolean(hum,'BreakJointsOnDeath',False); self._text(hum,'DisplayName',name.replace('_',' '))
        def _detail(n,att,off,sz,c,mat='SmoothPlastic',shape='Block',rotation=None):
            p=self.part(n,m,np.array((x,y,z))+np.array(off)*s,np.array(sz)*s,c,mat,shape,rotation,False,alpha=1 if n=='ClosedEye' else 0,anchored=False,record=False)
            self._weld(p,body[att],p); return p
        for side in [-1,1]:
            arm='Left' if side<0 else 'Right'
            _detail('ShoulderArmor',arm+'UpperArm',(side*1.23,4.04,0),(1.0,.47,1.14),metal,'Metal','Ball')
            for j in range(4): _detail('PauldronLamella',arm+'UpperArm',(side*(1.24+j*.05),3.94-j*.19,.20),(.80,.19,.97),self._tint(cloth,j*6),'Metal')
            _detail('Bracer',arm+'LowerArm',(side*1.26,2.65,-.06),(.66,.63,.71),cloth,'Metal')
            _detail('BracerRune',arm+'LowerArm',(side*1.26,2.68,-.45),(.13,.34,.07),accent,'Neon')
            _detail('KneeGuard',arm+'LowerLeg',(side*.46,1.13,-.37),(.72,.48,.16),metal,'Metal','Ball')
        for j in range(5): _detail('ChestLamella','UpperTorso',(0,3.90-j*.20,-.49),(1.50-j*.06,.16,.13),self._tint(cloth,12),'Metal')
        # v0.4.1: Head (Ball, bottom at 4.455) never touched UpperTorso (top at 4.325) -> 'floating head'.
        # Skin-coloured neck column centred on the Neck pivot (4.41) and welded to the Head, so it follows
        # head turns/nods with almost no visible displacement; its lower end sits inside the UpperTorso.
        _detail('NeckColumn','Head',(0,4.46,0),(.48,.52,.52),skin,'SmoothPlastic','Cylinder',self._rot(z=pi/2))
        if enemy:
            self._value('StringValue','Archetype',style,m)
            for i in range(32):
                a=i/32*2*pi; _detail('HaloSegment','UpperTorso',(math.cos(a)*1.62,4.6+math.sin(a)*1.62,.92),(.32,.11,.11),accent,'Neon',rotation=self._rot(z=a+pi/2))
            self.billboard(body['Head'],{'JadeWarden':'Jade Warden','StormDisciple':'Exiled Storm Disciple','LotusSovereign':'The Hollow Lotus'}[style],width=260,offset=2.4*s,c=accent,health=True)
        elif role:
            self._value('StringValue','Role',role,m)
            self.billboard(body['Head'],name.replace('_',' '),subtitle if subtitle is not None else role.upper(),width=230,offset=2.2,c=accent)
            # NPCService connects to the first ProximityPrompt under the model; without it the NPC can't be talked to
            pr=self.inst('ProximityPrompt','Interact',root)
            self._text(pr,'ActionText','Speak'); self._text(pr,'ObjectText',name.replace('_',' '))
            self._num(pr,'HoldDuration',.35); self._num(pr,'MaxActivationDistance',12); self._token(pr,'KeyboardKeyCode',101)
            self._boolean(pr,'RequiresLineOfSight',False); self._token(pr,'Style',1); self._token(pr,'Exclusivity',1)
        for e in self.scene[_s0:]: e['asset']=name
        return m

WorldBuilder = AssetBuilder

def export_rbxmx(kind, name, path, position=(0,0,0), seed=71624, **opts):
    """Build one asset into its own .rbxmx (model file) for a Rojo "$path" entry."""
    R=ET.Element('roblox',{'version':'4'}); b=AssetBuilder(R,seed=seed)
    b.create(kind,name,R,position,**opts)
    ET.indent(R,space='  '); Path(path).parent.mkdir(parents=True,exist_ok=True)
    Path(path).write_text(ET.tostring(R,encoding='unicode')); return path

if __name__ == '__main__':
    import argparse, sys
    ap = argparse.ArgumentParser(description='Heavensunder AssetBuilder: generate .rbxmx / .rbxlx models.')
    sub = ap.add_subparsers(dest='cmd')
    sub.add_parser('demo', help='write demo_full.rbxlx (houses, spider, warden, tree, island)')
    sub.add_parser('list', help='list buildable asset kinds')
    ex = sub.add_parser('export', help='build one asset into its own .rbxmx file')
    ex.add_argument('kind', help='asset kind (see list)')
    ex.add_argument('name', help='model name')
    ex.add_argument('path', help='output .rbxmx path')
    ex.add_argument('--position', default='0,0,0', help='x,y,z (default 0,0,0)')
    ex.add_argument('--seed', type=int, default=71624)
    ex.add_argument('--set', action='append', default=[], metavar='key=value',
                    help='asset option, e.g. --set scale=1.3 --set yaw=3.14159 (repeatable)')
    a = ap.parse_args(sys.argv[1:] or ['demo'])
    if a.cmd == 'list':
        b = AssetBuilder(ET.Element('roblox', {'version': '4'}))
        print('\n'.join(sorted(b.catalog)))
    elif a.cmd == 'export':
        pos = tuple(float(v) for v in a.position.split(','))
        opts = {}
        for kv in a.set:
            k, v = kv.split('=', 1)
            try: v = int(v)
            except ValueError:
                try: v = float(v)
                except ValueError: pass
            opts[k] = v
        export_rbxmx(a.kind, a.name, a.path, position=pos, seed=a.seed, **opts)
        print(f'Wrote {a.path} ({a.kind} {a.name} at {pos} seed={a.seed} {opts})')
    else:
        R = ET.Element('roblox',{'version':'4'})
        b = AssetBuilder(R, seed=71624)
        world = b.folder('World', b.inst('Workspace','Workspace'))
        enemies = b.folder('Enemies', b.folder('Actors', world))
        foliage = b.folder('Foliage', world)
        b.create('house','DemoHouse', world, (0,-40,0), accent='redwood')
        b.create('spider','DemoSpider', enemies, (20,-60,20), scale=0.85)
        b.create('enemy','DemoWarden', enemies, (-20,151,-100), style='JadeWarden', scale=1.30)
        b.create('tree','DemoTree', foliage, (10,-60,10), scale=1.0, style='jade')
        b.create('island','DemoIsland', world, (0,130,0), radius=90, biome='grass')
        ET.indent(R, space='  ')
        Path('demo_full.rbxlx').write_text(ET.tostring(R, encoding='unicode'))
        print('Wrote demo_full.rbxlx', len(list(R.iter('Item'))))
