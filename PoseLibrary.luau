-- Pure numeric poses for the authored -Z-forward joint frames.
local pi = math.pi
local sin, cos = math.sin, math.cos
local function ease(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end
local function put(pose, key, x, y, z, px, py, pz)
	-- These rigs face -Z. Positive X raises a downward arm toward -Z.
	if string.find(key, "Shoulder") or string.find(key, "Elbow") or string.find(key, "Hip") or string.find(key, "Knee") or string.find(key, "Ankle") then x = -(x or 0) end
	pose[key] = {x or 0, y or 0, z or 0, px or 0, py or 0, pz or 0}
end
local function neutral(p, t, breath, style)
	local b = sin(t * 1.7 + style) * breath
	put(p, "Waist", b * 0.5, sin(t * 0.43) * 0.035, 0, 0, b * 0.15, 0)
	put(p, "Neck", -b * 0.6, sin(t * 0.39 + style) * 0.10, sin(t * 0.6) * 0.02)
	put(p, "LeftShoulder", b, 0, -0.10 - b)
	put(p, "RightShoulder", -b, 0, 0.10 + b)
	put(p, "LeftElbow", -0.10, 0, 0)
	put(p, "RightElbow", -0.10, 0, 0)
	put(p, "CoreJoint", 0, t * 0.6, sin(t) * 0.1, 0, sin(t * 1.9) * 0.10, 0)
end
local function locomotion(p, t, speed, isBoss)
	local amplitude = math.clamp(speed / 16, 0, 1.3)
	local cycle = t -- distance-integrated gait; stopping no longer changes foot phase
	local stride = sin(cycle) * 0.67 * amplitude
	local lift = math.abs(cos(cycle)) * 0.065 * amplitude
	put(p, "Root", -0.055 * amplitude, 0, sin(cycle) * 0.022, 0, lift, 0)
	put(p, "Waist", 0.035, sin(cycle) * 0.07 * amplitude, 0)
	put(p, "Neck", -0.025, -sin(cycle) * 0.05, 0)
	put(p, "LeftHip", stride, 0, -0.025)
	put(p, "RightHip", -stride, 0, 0.025)
	put(p, "LeftKnee", math.max(0, -sin(cycle)) * 0.85 * amplitude, 0, 0)
	put(p, "RightKnee", math.max(0, sin(cycle)) * 0.85 * amplitude, 0, 0)
	put(p, "LeftAnkle", -stride * 0.32, 0, 0)
	put(p, "RightAnkle", stride * 0.32, 0, 0)
	put(p, "LeftShoulder", -stride * 0.78, 0, -0.11)
	put(p, "RightShoulder", stride * 0.78, 0, 0.11)
	put(p, "LeftElbow", -0.25 - math.max(0, stride) * 0.4, 0, 0)
	put(p, "RightElbow", -0.25 - math.max(0, -stride) * 0.4, 0, 0)
end
-- Seated cross-legged (tailor) pose, hands resting in the lap.
-- Solved offline against the shipped rig proportions (hip 2.34, knee 1.34, ankle 0.46,
-- shoulder 4.13, elbow 3.08, wrist 2.21 rig units): the pelvis is lowered so the hips sit
-- 0.64 above the floor, thighs splay out/forward, shins fold in so the feet meet under the
-- hands. Every leg bone stays above the floor (lowest point ~0.06 below at the shin edge).
-- scale = HumanoidRootPart.Size.Y / 2 (all humanoid rigs are 2*scale tall at the root),
-- needed because the Root drop is a translation in studs.
local MEDITATE_DROP = 1.70
local function meditation(p, t, scale)
	scale = scale or 1
	local breath = sin(t * 1.5)
	put(p, "Root", 0, 0, 0, 0, -MEDITATE_DROP * scale, 0)
	put(p, "Waist", -0.06 - breath * 0.025, 0, 0, 0, breath * 0.03 * scale, 0)
	put(p, "Neck", -0.16 + breath * 0.02, 0, 0)
	put(p, "LeftHip", -1.406, 0.151, -0.843)
	put(p, "RightHip", -1.406, -0.151, 0.843)
	put(p, "LeftKnee", -0.091, -0.297, 2.511)
	put(p, "RightKnee", 0.044, 0.192, -2.389)
	put(p, "LeftAnkle", 1.406, 0.227, 1.226)
	put(p, "RightAnkle", 1.575, -0.138, -1.231)
	put(p, "LeftShoulder", -1.451 - breath * 0.02, 1.275, -0.566)
	put(p, "RightShoulder", -1.451 - breath * 0.02, -1.275, 0.566)
	put(p, "LeftElbow", 1.277, 0, 0)
	put(p, "RightElbow", 1.277, 0, 0)
	put(p, "LeftWrist", -0.607, 0.697, 0)
	put(p, "RightWrist", -0.607, -0.697, 0)
	put(p, "CoreJoint", 0, t, 0, 0, 0.30 + sin(t * 2) * 0.16, -0.3)
end
local function attack(p, elapsed, combo)
	local a = ease(elapsed / 0.13)
	local b = ease((elapsed - 0.14) / 0.20)
	local strike = a * (1 - b)
	local side = combo % 2 == 0 and "Left" or "Right"
	local sign = side == "Left" and -1 or 1
	put(p, "Waist", -0.06, sign * strike * 0.28, sign * strike * 0.10)
	put(p, side .. "Shoulder", -1.6 * strike, sign * 0.24, sign * 0.15)
	put(p, side .. "Elbow", -0.18 * strike - 0.15 * (1 - strike), 0, 0)
	put(p, side .. "Wrist", 0, 0, -sign * 0.3)
	put(p, "Root", -strike * 0.10, sign * strike * 0.15, 0, 0, 0, -strike * 0.25)
end
local function windup(p, t, kind)
	local tremor = sin(t * 26) * 0.013
	if kind == "Ring" then
		put(p, "LeftShoulder", -2.4, -0.3, -0.35)
		put(p, "RightShoulder", -2.4, 0.3, 0.35)
		put(p, "LeftElbow", -0.5, 0, 0)
		put(p, "RightElbow", -0.5, 0, 0)
		put(p, "Waist", -0.25 + tremor, 0, 0)
	else
		put(p, "Waist", 0.13 + tremor, -0.55, 0.12)
		put(p, "RightShoulder", -1.8, 0.2, 0.75)
		put(p, "RightElbow", -1.3, 0, 0)
		put(p, "LeftShoulder", -0.65, -0.3, -0.6)
		put(p, "LeftElbow", -0.8, 0, 0)
		put(p, "RightHip", -0.18, 0, 0.12)
		put(p, "LeftKnee", 0.23, 0, 0)
	end
end
local function slam(p, elapsed)
	local a = math.sin(math.clamp(elapsed / 0.5, 0, 1) * pi)
	put(p, "Waist", a * 0.50, 0, 0)
	put(p, "RightShoulder", -1.5 + a, 0, 0.20)
	put(p, "LeftShoulder", -1.5 + a, 0, -0.20)
	put(p, "RightElbow", -0.2, 0, 0)
	put(p, "LeftElbow", -0.2, 0, 0)
	put(p, "Root", a * 0.12, 0, 0, 0, -a * 0.3, 0)
end
local function palm(p, elapsed)
	local a = math.sin(math.clamp(elapsed / 0.6, 0, 1) * pi)
	put(p, "Waist", 0, a * 0.24, 0)
	put(p, "RightShoulder", -a * 1.7, a * 0.16, a * 0.12)
	put(p, "RightElbow", -a * 0.18, 0, 0)
	put(p, "RightWrist", -a * 0.95, 0, 0)
	put(p, "LeftShoulder", -a * 0.35, 0, -a * 0.45)
	put(p, "LeftElbow", -a * 1.1, 0, 0)
end
local function lotus(p, elapsed)
	local a = math.sin(math.clamp(elapsed / 1.0, 0, 1) * pi)
	put(p, "Root", 0, elapsed * 5 * a, 0, 0, a * 0.8, 0)
	put(p, "LeftShoulder", -0.3, 0, -a * 1.4)
	put(p, "RightShoulder", -0.3, 0, a * 1.4)
	put(p, "Neck", -a * 0.24, 0, 0)
	put(p, "LeftHip", -a * 0.25, 0, -0.15)
	put(p, "RightHip", -a * 0.25, 0, 0.15)
end
local function jump(p, falling)
	put(p, "LeftShoulder", -0.25, 0, falling and -0.9 or -0.4)
	put(p, "RightShoulder", -0.25, 0, falling and 0.9 or 0.4)
	put(p, "LeftHip", -0.38, 0, -0.08)
	put(p, "RightHip", 0.20, 0, 0.08)
	put(p, "LeftKnee", 0.8, 0, 0)
	put(p, "RightKnee", 0.35, 0, 0)
end
local function talking(p, t)
	put(p, "Neck", sin(t * 2) * 0.09, sin(t * 0.8) * 0.20, 0)
	put(p, "RightShoulder", -0.4 - sin(t * 2) * 0.1, 0.1, 0.6)
	put(p, "RightElbow", -0.8 + sin(t * 1.2) * 0.2, 0, 0)
	put(p, "RightWrist", sin(t * 2.1) * 0.2, 0, sin(t) * 0.2)
end
local function alchemy(p, t)
	put(p, "Waist", -0.12, sin(t * 0.7) * 0.08, 0)
	put(p, "Neck", -0.25, 0, 0)
	put(p, "RightShoulder", -0.9 + sin(t * 1.7) * 0.15, 0, 0.25)
	put(p, "RightElbow", -0.6, sin(t * 1.7) * 0.25, 0)
	put(p, "LeftShoulder", -0.6, 0, -0.25)
	put(p, "LeftElbow", -0.9, 0, 0)
end
local function guard(p, elapsed, parry)
	local release = parry and math.max(0, 1 - elapsed / 0.5) or 1
	put(p, "Root", 0.05, -0.12 * release, 0, 0, -0.08, 0)
	put(p, "Waist", 0.13, 0.16, 0)
	put(p, "Neck", -0.08, -0.12, 0)
	put(p, "LeftShoulder", -0.95, -0.32, 0.25)
	put(p, "RightShoulder", -0.98, 0.25, -0.25)
	put(p, "LeftElbow", -1.48, 0, 0.15)
	put(p, "RightElbow", -1.45, 0, -0.15)
	put(p, "LeftWrist", -0.55, 0, 0)
	put(p, "RightWrist", -0.55, 0, 0)
	put(p, "LeftKnee", 0.20, 0, 0)
	put(p, "RightKnee", 0.12, 0, 0)
end
local function attune(p, elapsed)
	local a = math.sin(math.clamp(elapsed / 1.5, 0, 1) * pi)
	put(p, "Waist", -0.18 * a, 0, 0)
	put(p, "Neck", -0.2 * a, 0, 0)
	put(p, "LeftShoulder", -1.1 * a, -0.15, -0.25)
	put(p, "RightShoulder", -1.1 * a, 0.15, 0.25)
	put(p, "LeftElbow", -0.7 * a, 0, 0)
	put(p, "RightElbow", -0.7 * a, 0, 0)
	put(p, "CoreJoint", 0, elapsed * 2, 0, 0, a * 0.2, -a * 0.15)
end

return table.freeze({put=put, neutral=neutral, locomotion=locomotion, meditation=meditation, attack=attack, windup=windup, slam=slam, palm=palm, lotus=lotus, jump=jump, talking=talking, alchemy=alchemy, guard=guard, attune=attune})
