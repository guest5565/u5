--!nonstrict
-- INKWING :: WINGS on every player (local render). Paper feathers with an ink outline, fanned out from the shoulders.
-- Higher tiers: more + longer feathers; tier 5+ sparkles; tier 10 glows. Flaps hard while flying, gently when standing.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local me = Players.LocalPlayer
local Auras = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Auras"))
-- Inkbound auras unlock with wing tier
local AURA_TOP = { Coral = "drip", Star = "galaxy", Halo = "gold", Ember = "storm", Void = "void" }
local function auraFor(wing, tier)
	if AURA_TOP[wing] and tier >= 3 then
		return tier >= 8 and AURA_TOP[wing] or (tier >= 6 and "lightning" or "sparkle")
	end
	if tier >= 10 then
		return wing == "Ink" and "galaxy" or "gold"
	elseif tier >= 8 then
		return "lightning"
	elseif tier >= 6 then
		return wing == "Ink" and "void" or "storm"
	elseif tier >= 3 then
		return wing == "Ink" and "drip" or "sparkle"
	end
	return nil
end
local AURA_COL = { Ember = { color = Color3.fromRGB(255, 120, 40), c2 = Color3.fromRGB(255, 220, 90) }, Void = { color = Color3.fromRGB(150, 90, 255), c2 = Color3.fromRGB(255, 70, 140) }, Coral = { color = Color3.fromRGB(255, 130, 140), c2 = Color3.fromRGB(90, 220, 255) }, Star = { color = Color3.fromRGB(150, 110, 255), c2 = Color3.fromRGB(255, 230, 120) }, Halo = { color = Color3.fromRGB(255, 225, 130), c2 = Color3.fromRGB(255, 255, 240) }, Paper = { color = Color3.fromRGB(255, 244, 200), c2 = Color3.fromRGB(255, 255, 255) }, Ink = { color = Color3.fromRGB(90, 120, 255), c2 = Color3.fromRGB(170, 90, 255) } }

local STYLE = {
	Ember = { face = Color3.fromRGB(60, 24, 18), edge = Color3.fromRGB(255, 120, 40), tip = Color3.fromRGB(255, 200, 70), mat = Enum.Material.SmoothPlastic, glow = Color3.fromRGB(255, 130, 40), edgeNeon = true },
	Void = { face = Color3.fromRGB(14, 8, 24), edge = Color3.fromRGB(170, 110, 255), tip = Color3.fromRGB(255, 70, 140), mat = Enum.Material.SmoothPlastic, glow = Color3.fromRGB(170, 110, 255), edgeNeon = true },
	Coral = { face = Color3.fromRGB(255, 130, 135), edge = Color3.fromRGB(70, 220, 255), mat = Enum.Material.SmoothPlastic, glow = Color3.fromRGB(90, 220, 255), edgeNeon = true },
	Star = { face = Color3.fromRGB(70, 50, 170), edge = Color3.fromRGB(255, 230, 120), mat = Enum.Material.SmoothPlastic, glow = Color3.fromRGB(255, 230, 120), edgeNeon = true },
	Halo = { face = Color3.fromRGB(255, 250, 236), edge = Color3.fromRGB(255, 205, 80), mat = Enum.Material.SmoothPlastic, glow = Color3.fromRGB(255, 220, 120), edgeNeon = true },
	Paper = { face = Color3.fromRGB(252, 249, 236), edge = Color3.fromRGB(34, 32, 58), mat = Enum.Material.SmoothPlastic, glow = Color3.fromRGB(255, 240, 190) },
	Ink = { face = Color3.fromRGB(46, 62, 170), edge = Color3.fromRGB(120, 170, 255), mat = Enum.Material.SmoothPlastic, glow = Color3.fromRGB(90, 140, 255), edgeNeon = true },
}
local folder = Instance.new("Folder")
folder.Name = "WingVisuals"
folder.Parent = workspace
local rigs = {} -- player -> rig

local function newPart(color, mat, size)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Color = color
	p.Material = mat
	p.Size = size
	p.Parent = folder
	return p
end
local function build(player, wing, tier)
	local st = STYLE[wing] or STYLE.Paper
	local n = 4 + math.floor(tier / 2) -- 4..9 feathers per side
	local rig = { wing = wing, tier = tier, parts = {}, feathers = {}, k = 1 + (tier - 1) * 0.06 }
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, n do
			local u = (i - 1) / math.max(1, n - 1) -- 0 = lowest, 1 = top feather
			local L = (2.2 + math.sin(u * math.pi) * 1.8 + u * 0.6) * rig.k
			local W = (0.75 - u * 0.15) * rig.k
			local face = newPart(st.face, st.mat, Vector3.new(L, W, 0.12))
			local edge = newPart(st.edge, st.edgeNeon and Enum.Material.Neon or Enum.Material.SmoothPlastic, Vector3.new(L + 0.25, W + 0.25, 0.1))
			table.insert(rig.parts, face)
			table.insert(rig.parts, edge)
			-- detail: a quill shaft down the middle, a coloured tip, and a short overlapping covert feather
			local tipC = st.tip or st.edge
			local coverC = st.cover or st.face:Lerp(st.edge, 0.18)
			local shaft = newPart(st.edge:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.SmoothPlastic, Vector3.new(L * 0.92, 0.07, 0.05))
			local tip = newPart(tipC, st.edgeNeon and Enum.Material.Neon or Enum.Material.SmoothPlastic, Vector3.new(L * 0.2, W * 0.92, 0.13))
			local cov = newPart(coverC, st.mat, Vector3.new(L * 0.46, W * 1.15, 0.1))
			local covE = newPart(st.edge, Enum.Material.SmoothPlastic, Vector3.new(L * 0.46 + 0.18, W * 1.15 + 0.18, 0.08))
			for _, q in ipairs({ shaft, tip, cov, covE }) do
				table.insert(rig.parts, q)
			end
			table.insert(rig.feathers, { side = side, ang = -0.35 + u * 1.45, L = L, face = face, edge = edge, u = u,
				extra = { CFrame.new(side * L * 0.02, 0, 0.09), CFrame.new(side * L * 0.4, 0, 0.005), CFrame.new(-side * L * 0.26, 0.05, 0.15), CFrame.new(-side * L * 0.26, 0.05, 0.1) } })
		end
	end
	-- shoulder joints
	rig.shoulders = {}
	for _, side in ipairs({ -1, 1 }) do
		local sj = newPart(st.edge, st.edgeNeon and Enum.Material.Neon or Enum.Material.SmoothPlastic, Vector3.one * 0.55 * rig.k)
		sj.Shape = Enum.PartType.Ball
		table.insert(rig.parts, sj)
		rig.shoulders[side] = true
	end
	if tier >= 5 then
		local em = newPart(Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, Vector3.one * 0.2)
		em.Transparency = 1
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(st.glow)
		pe.LightEmission = 1
		pe.Rate = 4 + tier
		pe.Lifetime = NumberRange.new(0.6, 1.1)
		pe.Speed = NumberRange.new(0.5, 2)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Size = NumberSequence.new(0.3, 0)
		pe.Parent = em
		if tier >= 10 then
			local l = Instance.new("PointLight")
			l.Color = st.glow
			l.Range = 14
			l.Brightness = 1.5
			l.Parent = em
		end
		rig.emitter = em
		table.insert(rig.parts, em)
	end
	-- wing-tip trails (shown while boosting): on the longest feather of each side
	rig.trails = {}
	for _, f in ipairs(rig.feathers) do
		if f.u > 0.45 and f.u < 0.75 and not rig.trails[f.side] then
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position = Vector3.new(f.side * f.L / 2, 0.3, 0)
			a1.Position = Vector3.new(f.side * f.L / 2, -0.3, 0)
			a0.Parent, a1.Parent = f.face, f.face
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Lifetime = 0.35
			tr.Color = ColorSequence.new(st.glow, Color3.new(1, 1, 1))
			tr.Transparency = NumberSequence.new(0.2, 1)
			tr.LightEmission = 0.6
			tr.FaceCamera = true
			tr.WidthScale = NumberSequence.new(1, 0)
			tr.Enabled = false
			tr.Parent = f.face
			rig.trails[f.side] = tr
		end
	end
	rig.stretch = 0
	local style = auraFor(wing, tier)
	if style and Auras.has(style) then
		local ok, a = pcall(Auras.new, style, AURA_COL[wing] or AURA_COL.Paper, { folder = folder, scale = 1, lod = player == me and 1 or 0.6 })
		if ok then
			rig.aura = a
		end
	end
	rig.cfs = table.create(#rig.parts)
	return rig
end
local function clear(player)
	local rig = rigs[player]
	if rig then
		for _, p in ipairs(rig.parts) do
			p:Destroy()
		end
		if rig.aura then
			pcall(rig.aura.destroy, rig.aura)
		end
		rigs[player] = nil
	end
end
Players.PlayerRemoving:Connect(clear)

game:GetService("UserInputService").InputBegan:Connect(function(io, gp)
	if not gp and io.KeyCode == Enum.KeyCode.G then
		me:SetAttribute("WingsOpen", not me:GetAttribute("WingsOpen"))
	end
end)
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local cam = workspace.CurrentCamera.CFrame.Position
	for _, player in ipairs(Players:GetPlayers()) do
		local c = player.Character
		local torso = c and (c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"))
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		local wing = player:GetAttribute("Wing") or "Paper"
		local tier = player:GetAttribute("WingTier") or 1
		if player:GetAttribute("HasWings") == false then
			torso = nil -- no wings yet
		end
		if not torso or not hum or hum.Health <= 0 or (torso.Position - cam).Magnitude > 300 then
			clear(player)
			continue
		end
		local rig = rigs[player]
		if not rig or rig.wing ~= wing or rig.tier ~= tier then
			clear(player)
			rig = build(player, wing, tier)
			rigs[player] = rig
		end
		local flying = hum.PlatformStand or (hum.FloorMaterial == Enum.Material.Air)
		local boosting
		if player == me then
			boosting = me:GetAttribute("Boost") == true
		else
			boosting = flying and torso.AssemblyLinearVelocity.Magnitude > 85
		end
		rig.stretch += ((boosting and 1 or 0) - rig.stretch) * math.min(1, dt * 8)
		local st = rig.stretch
		-- v1.7 FOLD: wings tuck along your back on the ground (G keeps them spread)
		rig.airT = (hum.FloorMaterial == Enum.Material.Air) and ((rig.airT or 0) + dt) or 0
		local reallyFlying
		if player == me then
			reallyFlying = me:GetAttribute("Flying") == true
		else
			reallyFlying = hum.PlatformStand or rig.airT > 0.6
		end
		flying = reallyFlying
		local wantOpen = reallyFlying or boosting or (player == me and me:GetAttribute("WingsOpen") == true)
		rig.fold = (rig.fold or 1) + (((wantOpen and 0) or 1) - (rig.fold or 1)) * math.min(1, dt * 6)
		local fo = rig.fold
		for _, tr in pairs(rig.trails) do
			tr.Enabled = st > 0.5
		end
		local amp, rate = flying and 0.55 or 0.12, flying and 7 or 2
		-- v1.1: boosting = strong, deep, fast power-strokes (the wing never freezes)
		amp = amp * (1 - st) + 0.42 * st
		rate = rate * (1 - st) + 9.5 * st
		local beat = math.sin(t * rate + player.UserId % 7)
		beat = beat * (1 - st) + (beat > 0 and beat ^ 0.6 or -((-beat) ^ 1.6)) * st -- snappy down-stroke
		local back = torso.CFrame * CFrame.new(0, 0.5, 0.65)
		local i = 0
		for _, f in ipairs(rig.feathers) do
			local s = f.side
			-- shoulder pivot: sweep back/forward (Y) + lift (Z), then fan the feather out
			-- boost: the wing opens flat and sweeps back toward the legs (= behind you while you dash)
			local sweep = (0.35 + beat * amp * 0.6) * (1 - st) + 0.05 * st
			local root = back * CFrame.new(s * 0.35, 0, 0) * CFrame.Angles(0, s * (sweep + st * beat * amp * 0.35), s * beat * amp * (0.5 + st * 0.6))
			local ang = f.ang * (1 - st) + (-0.55 + f.u * 0.75) * st
			local reach = 1 + st * 0.15
			if fo > 0.01 then
				sweep = sweep * (1 - fo) + 1.25 * fo
				root = back * CFrame.new(s * 0.35 * (1 - fo * 0.5), 0.2 * fo, 0.1 * fo) * CFrame.Angles(0, s * (sweep + st * beat * amp * 0.35 * (1 - fo)), s * beat * amp * (0.5 + st * 0.6) * (1 - fo))
				ang = ang * (1 - fo) + (-1.2 + f.u * 0.45) * fo
				reach = reach * (1 - fo * 0.85) -- v1.10: wings melt back into your shoulders on the ground
			end
			local fcf = root * CFrame.Angles(0, 0, s * ang) * CFrame.new(s * f.L / 2 * reach, 0, 0)
			i += 1
			rig.cfs[i] = fcf
			i += 1
			rig.cfs[i] = fcf * CFrame.new(0, 0, -0.1) -- outline sits between body and paper
			for _, off in ipairs(f.extra) do
				i += 1
				rig.cfs[i] = fcf * off
			end
		end
		for _, side in ipairs({ -1, 1 }) do
			i += 1
			rig.cfs[i] = back * CFrame.new(side * 0.35, 0, 0.05)
		end
		if rig.emitter then
			i += 1
			rig.cfs[i] = back * CFrame.new(0, 1, 0.6)
		end
		workspace:BulkMoveTo(rig.parts, rig.cfs, Enum.BulkMoveMode.FireCFrameChanged)
		local hide = fo > 0.9
		if rig.hidden ~= hide then
			rig.hidden = hide
			for _, pp in ipairs(rig.parts) do
				if pp:IsA("BasePart") then
					pp.LocalTransparencyModifier = hide and 1 or 0
				end
				for _, d in ipairs(pp:GetDescendants()) do
					if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Light") then
						d.Enabled = not hide
					end
				end
			end
			if rig.aura then
				pcall(rig.aura.setHidden, rig.aura, hide)
				rig.auraHid = hide
			end
		end
		if rig.aura then
			local hrp = c:FindFirstChild("HumanoidRootPart")
			local med = player:GetAttribute("Meditating") == true -- v1.8e: no wing aura while meditating
			med = med or rig.hidden
			if rig.auraHid ~= med then
				rig.auraHid = med
				pcall(rig.aura.setHidden, rig.aura, med)
			end
			if hrp and not med then
				rig.aura:update(hrp.CFrame, t, dt)
			end
		end
	end
end)
