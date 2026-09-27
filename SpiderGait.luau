-- Engine-independent stepping/IK math shared by the spider animator and tests.
local Gait={}
function Gait.Phase(cycle, leg, side)
 local offset=((leg+(side<0 and 0 or 1))%2)*.5
 local phase=(cycle+offset)%1
 return phase,phase>=.56 and (phase-.56)/.44 or 0
end
function Gait.Triangle(upper, lower, distance)
 local d=math.clamp(distance,math.abs(upper-lower)+.001,upper+lower-.001)
 local along=(upper*upper-lower*lower+d*d)/(2*d)
 return along,math.sqrt(math.max(0,upper*upper-along*along)),d
end
function Gait.Lift(progress, scale)
 return math.sin(math.clamp(progress,0,1)*math.pi)*scale
end
return table.freeze(Gait)
