--!nonstrict
-- INKWING :: code-driven FLIGHT ANIMATION for every R15 character (no uploaded animations needed).
--   HOVER : upright, legs dangling and swaying, arms slightly out, gentle bob
--   FLY   : leaning forward into the flight, legs trailing behind, arms swept back
--   BOOST : superman dash - body flat, one fist forward, legs straight back (wings stretch in WingsRender)
-- Poses go into Motor6D.C0 (the Animator cannot overwrite C0); default tracks are muted while flying.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local me = Players.LocalPlayer
local A = CFrame.Angles

local POSE = {
	hover = {
		Root = { -0.08, 0, 0 }, Waist = { 0.04, 0, 0 }, Neck = { 0.06, 0, 0 },
		LeftShoulder = { 0.1, 0, -0.35 }, RightShoulder = { 0.1, 0, 0.35 }, LeftElbow = { 0.35, 0, 0 }, RightElbow = { 0.35, 0, 0 },
		LeftHip = { 0.25, 0, -0.05 }, RightHip = { 0.05, 0, 0.05 }, LeftKnee = { -0.55, 0, 0 }, RightKnee = { -0.35, 0, 0 },
		LeftAnkle = { -0.3, 0, 0 }, RightAnkle = { -0.3, 0, 0 },
	},
	fly = {
		Root = { -0.55, 0, 0 }, Waist = { -0.1, 0, 0 }, Neck = { 0.5, 0, 0 },
		LeftShoulder = { -0.45, 0, -0.2 }, RightShoulder = { -0.45, 0, 0.2 }, LeftElbow = { 0.25, 0, 0 }, RightElbow = { 0.25, 0, 0 },
		LeftHip = { -0.15, 0, -0.04 }, RightHip = { -0.1, 0, 0.04 }, LeftKnee = { -0.45, 0, 0 }, RightKnee = { -0.3, 0, 0 },
		LeftAnkle = { -0.5, 0, 0 }, RightAnkle = { -0.5, 0, 0 },
	},
	meditate = {
		Root = { 0, 0, 0 }, Waist = { 0.06, 0, 0 }, Neck = { -0.18, 0, 0 },
		LeftShoulder = { 0.45, 0, -0.2 }, RightShoulder = { 0.45, 0, 0.2 }, LeftElbow = { 0.9, 0, 0 }, RightElbow = { 0.9, 0, 0 },
		LeftHip = { 1.45, 0.25, -0.75 }, RightHip = { 1.45, -0.25, 0.75 }, LeftKnee = { -2.25, 0, 0 }, RightKnee = { -2.25, 0, 0 },
		LeftAnkle = { 0.2, 0, 0 }, RightAnkle = { 0.2, 0, 0 },
	},
	boost = {
		Root = { -1.2, 0, 0 }, Waist = { -0.05, 0, 0 }, Neck = { 0.95, 0, 0 },
		LeftShoulder = { -0.25, 0, -0.08 }, RightShoulder = { 2.95, 0, 0.05 }, LeftElbow = { 0.1, 0, 0 }, RightElbow = { 0.05, 0, 0 },
		LeftHip = { -0.08, 0, -0.03 }, RightHip = { -0.08, 0, 0.03 }, LeftKnee = { -0.08, 0, 0 }, RightKnee = { -0.15, 0, 0 },
		LeftAnkle = { -0.7, 0, 0 }, RightAnkle = { -0.7, 0, 0 },
	},
}
local JOINTS = {}
for name in pairs(POSE.hover) do
	table.insert(JOINTS, name)
end

local rigs = {} -- character -> rig
local rayP = RaycastParams.new()
rayP.FilterType = Enum.RaycastFilterType.Exclude

-- We pose through Motor6D.C0 (base C0 * pose). The Animator only writes Transform, so it can never
-- overwrite this - the old Transform approach got stomped by the default Animate script.
-- Joints can be classic Motor6Ds or (Avatar Joint Upgrade) AnimationConstraints.
-- Motor6D: pose C0. AnimationConstraint: pose its Attachment0 (the parent-side frame, same role as C0).
local function jointTarget(m)
	if m:IsA("Motor6D") then
		return m, "C0"
	end
	local a = m.Attachment0
	if a then
		return a, "CFrame"
	end
	return nil
end
local function baseC0(m)
	local obj, prop = jointTarget(m)
	if not obj then
		return CFrame.identity
	end
	local b = obj:GetAttribute("BaseC0")
	if typeof(b) ~= "CFrame" then
		b = obj[prop]
		obj:SetAttribute("BaseC0", b)
	end
	return b
end
local function setPose(m, cf)
	local obj, prop = jointTarget(m)
	if obj then
		obj[prop] = cf
	end
end
local function isJoint(d)
	return d:IsA("Motor6D") or d:IsA("AnimationConstraint")
end
local function scan(r, c)
	r.motors = {}
	for _, d in ipairs(c:GetDescendants()) do
		local key = d.Name
		if d:IsA("AnimationConstraint") and not POSE.hover[key] and d.Attachment0 then
			key = (d.Attachment0.Name:gsub("RigAttachment$", ""))
		end
		if isJoint(d) and POSE.hover[key] then
			r.motors[key] = d
			r.kind = d.ClassName
			baseC0(d)
		end
	end
	r.scanned = os.clock()
end
local function getRig(c, plr)
	local r = rigs[c]
	if not r then
		if not c:FindFirstChild("LowerTorso") or false then
			return nil -- R6 / still loading
		end
		r = { motors = {}, w = { ground = 1, hover = 0, fly = 0, boost = 0, med = 0 }, seed = math.random() * 10, posed = false }
		rigs[c] = r
		scan(r, c)
		c.DescendantAdded:Connect(function(d)
			if isJoint(d) then
				r.dirty = true
			end
		end)
		c.AncestryChanged:Connect(function(_, parent)
			if not parent then
				rigs[c] = nil
			end
		end)
	end
	local root = r.motors.Root
	if r.dirty or not root or not root.Parent or (os.clock() - r.scanned > 3) then
		r.dirty = false
		scan(r, c)
	end
	return r
end
local function quiet(c, r, on)
	local hum = c:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	r.quiet = r.quiet or {}
	if on then
		for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
			if not r.quiet[tr] then
				r.quiet[tr] = true
				tr:AdjustWeight(0.001, 0.15)
			end
		end
	else
		for tr in pairs(r.quiet) do
			tr:AdjustWeight(1, 0.2)
		end
		table.clear(r.quiet)
	end
end

local DEBUG = false
local dbg
if DEBUG then
	local g = Instance.new("ScreenGui")
	g.Name = "AnimDebug"
	g.ResetOnSpawn = false
	g.Parent = me:WaitForChild("PlayerGui")
	dbg = Instance.new("TextLabel")
	dbg.AnchorPoint = Vector2.new(0, 1)
	dbg.Position = UDim2.new(0, 8, 1, -8)
	dbg.Size = UDim2.fromOffset(420, 18)
	dbg.BackgroundTransparency = 0.5
	dbg.BackgroundColor3 = Color3.new(0, 0, 0)
	dbg.TextColor3 = Color3.new(1, 1, 1)
	dbg.Font = Enum.Font.Code
	dbg.TextSize = 13
	dbg.TextXAlignment = Enum.TextXAlignment.Left
	dbg.Text = "anim: starting"
	dbg.Parent = g
end
local lastErr

local function stepChar(plr, dt, t, camPos)
	local c = plr.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum and hum.Health > 0) or (hrp.Position - camPos).Magnitude > 300 then
		return "skip"
	end
	local r = getRig(c, plr)
	if not r then
		return "skip"
	end
	local vel = hrp.AssemblyLinearVelocity
	local speed = vel.Magnitude
	local airborne, boosting
	if plr == me then
		airborne = me:GetAttribute("Flying") == true
		boosting = me:GetAttribute("Boost") == true or me:GetAttribute("Rush") == true
	else
		rayP.FilterDescendantsInstances = { c }
		airborne = workspace:Raycast(hrp.Position, Vector3.new(0, -4.5, 0), rayP) == nil
		boosting = airborne and speed > 85
	end
	local goal = { ground = 0, hover = 0, fly = 0, boost = 0, med = 0 }
	if plr:GetAttribute("Meditating") == true then
		goal.med = 1
	elseif not airborne then
		goal.ground = 1
	elseif boosting then
		goal.boost = 1
	else
		local f = math.clamp((Vector3.new(vel.X, 0, vel.Z).Magnitude - 6) / 30, 0, 1)
		goal.fly, goal.hover = f, 1 - f
	end
	local k = math.clamp(dt * 7, 0, 1)
	for key, v in pairs(goal) do
		r.w[key] += (v - r.w[key]) * k
	end
	local wAir = 1 - r.w.ground
	if wAir > 0.5 then
		quiet(c, r, true)
	elseif r.quiet and next(r.quiet) then
		quiet(c, r, false)
	end
	if wAir < 0.02 then
		if r.posed then -- back on the ground: restore the real joints
			r.posed = false
			for _, m in pairs(r.motors) do
				setPose(m, baseC0(m))
			end
		end
		return "skip"
	end
	r.posed = true
	local s = r.seed
	local wh, wf, wb, wm = r.w.hover, r.w.fly, r.w.boost, r.w.med
	local sum = math.max(wh + wf + wb + wm, 0.001)
	for _, name in ipairs(JOINTS) do
		local m = r.motors[name]
		if m and m.Parent then
			local h, f, b, md = POSE.hover[name], POSE.fly[name], POSE.boost[name], POSE.meditate[name]
			local x = (h[1] * wh + f[1] * wf + b[1] * wb + md[1] * wm) / sum
			local y = (h[2] * wh + f[2] * wf + b[2] * wb + md[2] * wm) / sum
			local z = (h[3] * wh + f[3] * wf + b[3] * wb + md[3] * wm) / sum
			if wm > 0.05 and (name == "Waist" or name == "Neck") then -- slow deep breaths
				x += math.sin(t * 0.9 + s) * 0.05 * wm
			end
			if name == "LeftHip" or name == "RightHip" then
				x += math.sin(t * 2.2 + s + (name == "LeftHip" and 0 or math.pi)) * (0.12 * wh + 0.08 * wf + 0.03 * wb)
			elseif name == "LeftKnee" or name == "RightKnee" then
				x -= (math.sin(t * 2.2 + s + (name == "LeftKnee" and 0.6 or 3.7)) * 0.5 + 0.5) * (0.15 * wh + 0.1 * wf)
			elseif name == "LeftShoulder" or name == "RightShoulder" then
				z += (name == "LeftShoulder" and -1 or 1) * math.sin(t * 1.6 + s) * 0.06 * wh
			elseif name == "Root" then
				x += math.sin(t * 1.8 + s) * 0.03 * wh
			end
			local pose = A(x * wAir, y * wAir, z * wAir)
			setPose(m, baseC0(m) * pose)
		end
	end
	return "ok"
end

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	for _, plr in ipairs(Players:GetPlayers()) do
		local ok, res = pcall(stepChar, plr, dt, t, camPos)
		if not ok and res ~= lastErr then
			lastErr = res
			warn("[Inkwing CharAnim] " .. tostring(res))
		end
		if DEBUG and plr == me then
			local r = me.Character and rigs[me.Character]
			local n = 0
			if r then
				for _ in pairs(r.motors) do
					n += 1
				end
			end
			dbg.Text = ("anim: %s | flying=%s | joints=%d %s | air=%.2f | %s"):format(ok and tostring(res) or "ERROR", tostring(me:GetAttribute("Flying")), n, r and r.kind or "?",
				r and (1 - r.w.ground) or -1, lastErr and tostring(lastErr):sub(1, 60) or "")
		end
	end
end)
