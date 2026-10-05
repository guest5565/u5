-- minimal Roblox mocks for offline model dumps
local V = {}; V.__index = V
local function v3(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},V) end
V.__add=function(a,b) return v3(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
V.__sub=function(a,b) return v3(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
V.__mul=function(a,b) if type(a)=="number" then a,b=b,a end if type(b)=="number" then return v3(a.X*b,a.Y*b,a.Z*b) end return v3(a.X*b.X,a.Y*b.Y,a.Z*b.Z) end
V.__unm=function(a) return v3(-a.X,-a.Y,-a.Z) end
Vector3={new=v3,one=v3(1,1,1),zero=v3(0,0,0)}
local C={}; C.__index=C
local function cf(p,R) return setmetatable({p=p,R=R},C) end
local I3={{1,0,0},{0,1,0},{0,0,1}}
local function mm(A,B) local R={} for i=1,3 do R[i]={} for j=1,3 do R[i][j]=A[i][1]*B[1][j]+A[i][2]*B[2][j]+A[i][3]*B[3][j] end end return R end
local function mv(A,v) return v3(A[1][1]*v.X+A[1][2]*v.Y+A[1][3]*v.Z, A[2][1]*v.X+A[2][2]*v.Y+A[2][3]*v.Z, A[3][1]*v.X+A[3][2]*v.Y+A[3][3]*v.Z) end
C.__mul=function(a,b) if getmetatable(b)==C then return cf(a.p+mv(a.R,b.p), mm(a.R,b.R)) end return a.p+mv(a.R,b) end
C.__index=function(t,k) if k=="Position" then return t.p end return C[k] end
C.__add=function(a,b) return cf(a.p+b,a.R) end
C.__sub=function(a,b) return cf(a.p-b,a.R) end
local function rx(a) local c,s=math.cos(a),math.sin(a) return {{1,0,0},{0,c,-s},{0,s,c}} end
local function ry(a) local c,s=math.cos(a),math.sin(a) return {{c,0,s},{0,1,0},{-s,0,c}} end
local function rz(a) local c,s=math.cos(a),math.sin(a) return {{c,-s,0},{s,c,0},{0,0,1}} end
CFrame={identity=cf(v3(),I3), new=function(x,y,z) if type(x)=="table" then return cf(x,I3) end return cf(v3(x,y,z),I3) end,
 Angles=function(a,b,c) return cf(v3(),mm(mm(rx(a),ry(b)),rz(c))) end}
Color3={fromRGB=function(r,g,b) return {r/255,g/255,b/255} end,new=function(r,g,b) return {r,g,b} end}
local E=setmetatable({},{__index=function(t,k) local x=setmetatable({},{__index=function(_,n) return n end}) rawset(t,k,x) return x end})
Enum=E
NumberRange={new=function() return {} end} NumberSequence={new=function() return {} end} NumberSequenceKeypoint={new=function() return {} end}
ColorSequence={new=function() return {} end} Vector2={new=function() return {} end}
ALL={}
Instance={new=function(c) local o={ClassName=c,Children={}} if c=="Part" or c=="WedgePart" then table.insert(ALL,o) end
 return setmetatable(o,{__newindex=function(t,k,v) rawset(t,k,v) end}) end}
workspace={BulkMoveTo=function(_,parts,cfs) for i,p in ipairs(parts) do p.CFrame=cfs[i] end end}

function dump(name)
 io=nil
 local out={}
 for _,p in ipairs(ALL) do if p.CFrame and p.Transparency~=1 and p.Name~="Root" then
  local R=p.CFrame.R local q=p.CFrame.p
  out[#out+1]=string.format('{"c":"%s","s":"%s","sz":[%f,%f,%f],"p":[%f,%f,%f],"R":[[%f,%f,%f],[%f,%f,%f],[%f,%f,%f]],"col":[%f,%f,%f],"tr":%f}',
   p.ClassName, tostring(p.Shape or "Block"), p.Size.X,p.Size.Y,p.Size.Z, q.X,q.Y,q.Z, R[1][1],R[1][2],R[1][3],R[2][1],R[2][2],R[2][3],R[3][1],R[3][2],R[3][3], p.Color[1],p.Color[2],p.Color[3], p.Transparency or 0)
 end end
 print("@@"..name.."@@["..table.concat(out,",").."]")
 ALL={}
end
-- added: lookAt / fromAxisAngle / vector Magnitude & Unit for the v0.4 monsters
CFrame.lookAt = function(at, target)
	local d = v3(target.X-at.X, target.Y-at.Y, target.Z-at.Z)
	local L = math.sqrt(d.X*d.X+d.Y*d.Y+d.Z*d.Z); local z = v3(-d.X/L, -d.Y/L, -d.Z/L) -- back vector
	local up = math.abs(z.Y) < 0.99 and v3(0,1,0) or v3(1,0,0)
	local x = v3(up.Y*z.Z-up.Z*z.Y, up.Z*z.X-up.X*z.Z, up.X*z.Y-up.Y*z.X); local Lx = math.sqrt(x.X*x.X+x.Y*x.Y+x.Z*x.Z); x = v3(x.X/Lx, x.Y/Lx, x.Z/Lx)
	local y = v3(z.Y*x.Z-z.Z*x.Y, z.Z*x.X-z.X*x.Z, z.X*x.Y-z.Y*x.X)
	return cf(at, {{x.X,y.X,z.X},{x.Y,y.Y,z.Y},{x.Z,y.Z,z.Z}})
end
CFrame.fromAxisAngle = function(ax, a)
	local L = math.sqrt(ax.X*ax.X+ax.Y*ax.Y+ax.Z*ax.Z); local x,y,z = ax.X/L, ax.Y/L, ax.Z/L
	local c, s = math.cos(a), math.sin(a); local t = 1-c
	return cf(v3(0,0,0), {{t*x*x+c, t*x*y-s*z, t*x*z+s*y},{t*x*y+s*z, t*y*y+c, t*y*z-s*x},{t*x*z-s*y, t*y*z+s*x, t*z*z+c}})
end
V.__unm = V.__unm or function(a) return v3(-a.X,-a.Y,-a.Z) end
