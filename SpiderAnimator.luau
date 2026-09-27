-- Articulated arachnid animator: alternating four-foot support groups, planted
-- world-space contacts, stepped terrain probes, two-link knees and three bones/leg.
local RunService=game:GetService('RunService')
local Gait=require(script.Parent.SpiderGait)
local Spider={}
local rigs={}
local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Include
local function rodFrame(a,b)
 local delta=b-a
 local axis=delta.Magnitude>.001 and delta.Unit or Vector3.yAxis
 local up=Vector3.zAxis:Cross(axis)
 if up.Magnitude<.01 then up=Vector3.yAxis:Cross(axis) end
 up=up.Unit
 return CFrame.fromMatrix((a+b)/2,axis,up,axis:Cross(up))
end
function Spider.Attach(model)
 if rigs[model] or not model:FindFirstChild('RigKind') or model.RigKind.Value~='Spider' then return false end
 local root=model:FindFirstChild('HumanoidRootPart');if not root then return false end
 local joints={};for _,v in model:GetDescendants() do if v:IsA('Motor6D') then joints[v.Name]=v end end
 local r={Root=root,Joints=joints,Legs={},Clock=0,Cycle=0,Last=root.Position,Scale=root.Size.Y/2,Phase=math.random()*5}
 for _,side in {-1,1} do for index=1,4 do
  local key=(side<0 and 'L' or 'R')..index
  local m1,m2,m3=joints['Leg_'..key..'_1'],joints['Leg_'..key..'_2'],joints['Leg_'..key..'_3']
  local hip=(m1.Part0.CFrame*m1.C0).Position;local knee=(m2.Part0.CFrame*m2.C0).Position;local ankle=(m3.Part0.CFrame*m3.C0).Position
  local toe=m3.Part1.CFrame:PointToWorldSpace(Vector3.new(m3.Part1.Size.X/2,0,0))
  table.insert(r.Legs,{Side=side,Index=index,Motors={m1,m2,m3},Hip=root.CFrame:PointToObjectSpace(hip),Rest=root.CFrame:PointToObjectSpace(toe),Foot=toe,Upper=(hip-knee).Magnitude,Lower=(knee-ankle).Magnitude,Tarsus=(ankle-toe).Magnitude,Swing=false})
 end end
 r.BodyBase={};for _,n in {'SpiderRoot','SpiderNeck','AbdomenJoint','Fang_-1','Fang_1'} do r.BodyBase[n]=joints[n].C0 end
 rigs[model]=r;return true
end
function Spider.Detach(model) rigs[model]=nil end
local function contact(position)
 local hit=workspace:Raycast(position+Vector3.new(0,9,0),Vector3.new(0,-24,0),ray)
 return hit and hit.Position+Vector3.new(0,.1,0) or position
end
function Spider.Start()
 ray.FilterDescendantsInstances={workspace.World.Ground,workspace.World.Islands,workspace.World.Paths,workspace.World.Architecture}
 RunService.PreSimulation:Connect(function(dt)
  local camera=workspace.CurrentCamera;if not camera then return end
  for model,r in rigs do
   if not model.Parent then rigs[model]=nil;continue end
   local distance=(r.Root.Position-camera.CFrame.Position).Magnitude
   if distance>300 then continue end
   r.Clock+=dt
   if r.Clock<(distance<90 and 1/30 or distance<180 and 1/15 or 1/8) then continue end
   local elapsed=math.min(r.Clock,.15);r.Clock=0
   local moved=(r.Root.Position-r.Last).Magnitude;local warped=moved>24
   r.Last=r.Root.Position
   local velocity=r.Root.AssemblyLinearVelocity;local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
   r.Cycle+=(speed>1 and math.min(speed,24)*.11 or .12)*elapsed
   local t=workspace:GetServerTimeNow();local state=model:GetAttribute('AIState') or 'Idle'
   local bodyY=math.sin(t*1.7+r.Phase)*.065*r.Scale
   if state=='Windup' then bodyY-=.35*r.Scale elseif state=='Recover' then bodyY+=.1*r.Scale end
   local age=t-(model:GetAttribute('ActionAt') or t)
   local strike=state=='Recover' and model:GetAttribute('AttackKind')=='Pounce' and math.sin(math.clamp(age/.55,0,1)*math.pi) or 0
   bodyY+=strike*.8*r.Scale
   local dead=state=='Dead'
   local body=r.Root.CFrame*CFrame.new(0,dead and -.85*r.Scale or bodyY,-strike*1.6*r.Scale)*CFrame.Angles(0,0,dead and .7 or math.sin(r.Cycle*math.pi*2)*.025)
   local torso=r.Joints.SpiderRoot
   torso.C0=r.Root.CFrame:ToObjectSpace(body)*torso.C1
   for _,name in {'SpiderNeck','AbdomenJoint','Fang_-1','Fang_1'} do
    local joint=r.Joints[name]
    local pose=name=='AbdomenJoint' and CFrame.Angles(math.sin(t*1.3)*.035,0,0) or name=='SpiderNeck' and CFrame.Angles(state=='Windup' and -.15 or .03,0,0) or CFrame.Angles(state=='Windup' and .55 or .10+math.sin(t*2)*.04,0,0)
    joint.C0=r.BodyBase[name]*pose
   end
   for _,leg in r.Legs do
    local rest=r.Root.CFrame:PointToWorldSpace(leg.Rest)
    local phase,u=Gait.Phase(r.Cycle,leg.Index,leg.Side)
    local swinging=phase>=.56
    if warped then leg.Foot=contact(rest);leg.Swing=false end
    if swinging and not leg.Swing and (speed>1 or (leg.Foot-rest).Magnitude>1.8*r.Scale) then
     leg.From=leg.Foot
     local lead=speed>1 and Vector3.new(velocity.X,0,velocity.Z).Unit*math.min(1.4*r.Scale,speed*.10) or Vector3.zero
     leg.To=contact(rest+lead);leg.Swing=true
    end
    if leg.Swing then
     if swinging then
      local smooth=u*u*(3-2*u)
      leg.Foot=leg.From:Lerp(leg.To,smooth)+Vector3.new(0,Gait.Lift(u,.95*r.Scale),0)
     else leg.Foot=leg.To;leg.Swing=false end
    end
    local hip=body:PointToWorldSpace(leg.Hip)
    local foot=dead and body:PointToWorldSpace(leg.Rest*.55)+Vector3.new(0,r.Scale,0) or leg.Foot
    local ankle=foot+Vector3.new(0,leg.Tarsus*.86,0)
    local delta=ankle-hip;local axis=delta.Magnitude>.001 and delta.Unit or Vector3.xAxis
    local along,height,d=Gait.Triangle(leg.Upper,leg.Lower,math.max(.001,delta.Magnitude))
    ankle=hip+axis*d
    local bend=Vector3.yAxis-axis*axis:Dot(Vector3.yAxis)
    bend=bend.Magnitude>.001 and bend.Unit or Vector3.zAxis
    local knee=hip+axis*along+bend*height
    local points={hip,knee,ankle,foot};local parent=body
    for segment,motor in leg.Motors do
     local cf=rodFrame(points[segment],points[segment+1])
     motor.C0=parent:ToObjectSpace(cf)*motor.C1
     parent=cf
    end
   end
  end
 end)
end
return Spider
