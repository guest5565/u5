--!nonstrict
-- INKWING :: FLIGHT (local). Walk off any edge and your wings catch you - you never fall.
--   steer with the stick / WASD, the camera pitch climbs or dives, hold UP / DOWN (Space, Q or Ctrl), BOOST (Shift).
--   Gates: thin air above the ceiling, pressure below the depth line until your wings are strong enough.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local me = Players.LocalPlayer
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"))
local Fx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx")
local CombatRE = ReplicatedStorage.Remotes:WaitForChild("Combat")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local InkFX = require(ReplicatedStorage.Shared:WaitForChild("InkFX"))
local okA, Audio = pcall(require, ReplicatedStorage.Shared:WaitForChild("Audio"))
local function sfx(n, o)
	if okA and Audio then
		pcall(Audio.play, n, o)
	end
end
local HOLD_T = 1.6 -- v1.10: hold jump this long to unfurl your wings
local state = { stam = 100, holdT = nil, lastJump = 0, diveE = 0, flying = false, up = false, down = false, boostUntil = 0, boostReady = 0, airT = 0, flyT = 0, vel = Vector3.zero, dashUntil = 0, dashVel = Vector3.zero, warnT = 0 }
local char, hum, hrp, lv, ao, att

local FONT = Enum.Font.FredokaOne
local INK = Color3.fromRGB(30, 28, 50)
local gui = Instance.new("ScreenGui")
gui.Name = "FlightUI"
gui.ResetOnSpawn = false
gui.Parent = me:WaitForChild("PlayerGui")
local function btn(text, color, pos, size)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = pos
	b.Size = size
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b
	local ts = Instance.new("UIStroke")
	ts.Thickness = 1.5
	ts.Color = INK
	ts.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8), UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = b
	b.Parent = gui
	return b
end
-- mobile: UP / DOWN on the right edge above the jump button; BOOST for everyone
local upB = btn("UP", Color3.fromRGB(90, 190, 255), UDim2.new(1, -18, 1, -250), UDim2.fromOffset(70, 70))
local downB = btn("DOWN", Color3.fromRGB(120, 110, 200), UDim2.new(1, -18, 1, -172), UDim2.fromOffset(70, 70))
local boostB = btn("BOOST", Color3.fromRGB(255, 170, 50), UDim2.new(1, -96, 1, -250), UDim2.fromOffset(70, 70))
upB.Visible, downB.Visible = false, false
if not isMobile then
	boostB.Position = UDim2.new(1, -18, 1, -18)
	boostB.Size = UDim2.fromOffset(80, 80)
	boostB.Text = "BOOST / DODGE (SHIFT)"
	boostB.Visible = false -- v1.10 PC: Shift only
end
-- v1.10 wing stamina bar + unfurl charge (small, under the character, only when needed)
local stamBg = Instance.new("Frame")
stamBg.AnchorPoint = Vector2.new(0.5, 0)
stamBg.Position = UDim2.new(0.5, 0, 0.62, 0)
stamBg.Size = UDim2.fromOffset(120, 6)
stamBg.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
stamBg.BackgroundTransparency = 0.4
stamBg.BorderSizePixel = 0
stamBg.Visible = false
stamBg.Parent = gui
Instance.new("UICorner", stamBg).CornerRadius = UDim.new(1, 0)
local stamFill = Instance.new("Frame")
stamFill.Size = UDim2.fromScale(1, 1)
stamFill.BorderSizePixel = 0
stamFill.Parent = stamBg
Instance.new("UICorner", stamFill).CornerRadius = UDim.new(1, 0)
local chargeF = stamBg:Clone()
chargeF.Position = UDim2.new(0.5, 0, 0.62, 10)
chargeF.Parent = gui
local chargeFill = chargeF:FindFirstChildOfClass("Frame")
chargeFill.BackgroundColor3 = Color3.fromRGB(150, 210, 255)
local function hold(b, key)
	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			state[key] = true
		end
	end)
	b.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			state[key] = false
		end
	end)
end
hold(upB, "up")
hold(downB, "down")
-- gate message
local warnL = Instance.new("TextLabel")
warnL.AnchorPoint = Vector2.new(0.5, 0.5)
warnL.Position = UDim2.fromScale(0.5, 0.62)
warnL.Size = UDim2.fromOffset(640, 40)
warnL.BackgroundTransparency = 1
warnL.Font = FONT
warnL.TextScaled = true
warnL.TextColor3 = Color3.fromRGB(255, 120, 120)
warnL.TextStrokeTransparency = 0
warnL.TextStrokeColor3 = INK
warnL.Text = ""
warnL.Parent = gui

local function boost()
	if me:GetAttribute("HasWings") == false then
		return
	end
	local now = os.clock()
	if now < state.boostReady then
		return
	end
	CombatRE:FireServer("boost") -- v1.6 Gale Plume
	-- v0.7 DODGE: in combat, BOOST is a quick dash in your move direction (dodge telegraphs)
	if me:GetAttribute("CombatCam") and hum and hrp then
		local mv = hum.MoveDirection
		if mv.Magnitude < 0.1 then
			mv = -workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)
		end
		if mv.Magnitude > 0.01 then
			state.flying = state.flying or hum:GetState() == Enum.HumanoidStateType.Freefall
			state.flyT = now
			state.dashUntil = now + 0.22
			state.dashVel = mv.Unit * 130
			state.boostReady = now + 1.6
			if not state.flying then
				hrp.AssemblyLinearVelocity = mv.Unit * 110 + Vector3.new(0, 18, 0)
			end
			Fx:FireServer("Dodge")
			return
		end
	end
	local wing = me:GetAttribute("Wing") or "Paper"
	state.boostUntil = now + (wing == "Paper" and 6 or 7) -- v0.9c: long boosts
	state.boostReady = now + 2 -- can chain
	if not state.flying then
		return -- v1.10: boost only works with your wings open
	end
	if state.stam < 15 then
		return
	end
	TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.25), { FieldOfView = 86 }):Play()
	task.delay(state.boostUntil - now, function()
		TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5), { FieldOfView = 70 }):Play()
	end)
end
boostB.Activated:Connect(boost)
UserInputService.InputBegan:Connect(function(i, gp)
	if gp then
		return
	end
	if i.KeyCode == Enum.KeyCode.Space then
		state.up = true
		if not state.flying then
			state.holdT = os.clock()
		end
	elseif i.KeyCode == Enum.KeyCode.Q or i.KeyCode == Enum.KeyCode.LeftControl then
		state.down = true
	elseif i.KeyCode == Enum.KeyCode.LeftShift then
		boost()
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.KeyCode == Enum.KeyCode.Space then
		state.up = false
	elseif i.KeyCode == Enum.KeyCode.Q or i.KeyCode == Enum.KeyCode.LeftControl then
		state.down = false
	end
end)
-- mobile jump while in the air = start flying
UserInputService.JumpRequest:Connect(function() -- mobile: holding the jump button repeats this
	local now = os.clock()
	if now - state.lastJump > 0.35 then
		state.holdT = now
	end
	state.lastJump = now
end)

local function setup(c)
	char = c
	hum = c:WaitForChild("Humanoid")
	hrp = c:WaitForChild("HumanoidRootPart")
	att = Instance.new("Attachment")
	att.Name = "FlyAtt"
	att.Parent = hrp
	lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = 1e7
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Enabled = false
	lv.Parent = hrp
	ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = 1e7
	ao.Responsiveness = 18
	ao.Enabled = false
	ao.Parent = hrp
	state.flying = false
	state.vel = Vector3.zero
end
if me.Character then
	task.spawn(setup, me.Character)
end
me.CharacterAdded:Connect(setup)

Fx.OnClientEvent:Connect(function(kind, info)
	if kind == "Dash" and hrp then
		local dir = info.to - hrp.Position
		if dir.Magnitude > 1 then
			state.flying = true
			state.flyT = os.clock()
			state.dashUntil = os.clock() + 0.25
			state.dashVel = dir.Unit * math.min(dir.Magnitude / 0.25, 220)
		end
	end
end)

local rayP = RaycastParams.new()
rayP.FilterType = Enum.RaycastFilterType.Exclude
local bank = 0
RunService.RenderStepped:Connect(function(dt)
	if not (hum and hrp and lv and hum.Health > 0) then
		return
	end
	local now = os.clock()
	local st = hum:GetState()
	-- auto-catch: in the air for a moment -> wings open (you never fall)
	if not state.flying then
		if st == Enum.HumanoidStateType.Freefall then
			state.airT += dt
			if hrp.AssemblyLinearVelocity.Y < -95 then -- v1.10: only a long fall forces the wings open
				state.flying = true
				state.flyT = now
				state.vel = hrp.AssemblyLinearVelocity * Vector3.new(1, 0.2, 1)
			end
		else
			state.airT = 0
		end
	end
	-- tornado wind can sweep you off an island
	local wind = me:GetAttribute("Wind") or Vector3.zero
	if not state.flying and wind.Magnitude > 30 then
		state.flying = true
		state.flyT = now
	end
	if hum.SeatPart then
		state.flying = false -- v1.8c: piloting a skiff
	end
	if me:GetAttribute("HasWings") == false then
		state.flying = false -- v1.1: the story starts on foot; wings come after the first hunt
	end
	-- v1.10 HOLD JUMP TO UNFURL
	local held = state.up or (now - state.lastJump < 0.35)
	if not held then
		state.holdT = nil
	end
	local canWing = me:GetAttribute("HasWings") ~= false and not hum.SeatPart
	if not state.flying and held and state.holdT and canWing then
		local k = (now - state.holdT) / HOLD_T
		chargeF.Visible = k > 0.15
		chargeFill.Size = UDim2.fromScale(math.clamp(k, 0, 1), 1)
		if k >= 1 and state.stam > 10 then
			state.holdT = nil
			state.flying = true
			state.flyT = now
			state.vel = Vector3.new(0, 45, 0)
			pcall(InkFX.ring, hrp.Position - Vector3.new(0, 2, 0), Color3.fromRGB(255, 245, 220), 1, 14, 0.5, 1)
			pcall(InkFX.puffs, hrp.Position, Color3.fromRGB(240, 240, 250), 8, 4, 0.8)
			sfx("jump_pad", { vol = 0.7 })
			TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.2), { FieldOfView = 80 }):Play()
			task.delay(0.35, function()
				TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.6), { FieldOfView = 70 }):Play()
			end)
		end
	else
		chargeF.Visible = false
	end
	-- stamina: refills on the ground (and while gliding with Mana Rotation)
	local maxS = 100 + ((me:GetAttribute("WingRank") or 1) - 1) * 30
	if not state.flying then
		state.stam = math.min(maxS, state.stam + dt * 30)
	end
	stamBg.Visible = state.stam < maxS - 0.5
	stamFill.Size = UDim2.fromScale(math.clamp(state.stam / maxS, 0, 1), 1)
	stamFill.BackgroundColor3 = state.stam < maxS * 0.25 and Color3.fromRGB(255, 110, 90) or Color3.fromRGB(255, 235, 170)
	-- wading: water slows you on foot too
	local wetFoot = hrp.Position.Y < G.SEA + 2
	if not state.flying then
		hum.WalkSpeed = wetFoot and 7 or 16
	end
	upB.Visible = isMobile and state.flying
	downB.Visible = isMobile and state.flying
	me:SetAttribute("Flying", state.flying)
	if not state.flying then
		me:SetAttribute("Boost", false)
		lv.Enabled, ao.Enabled = false, false
		if hum.PlatformStand then
			hum.PlatformStand = false
		end
		return
	end
	rayP.FilterDescendantsInstances = { char, workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("EnemyVisuals") }
	-- landing: close to the ground and not climbing
	local vNow = hrp.AssemblyLinearVelocity
	local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -(3.6 + math.max(0, -vNow.Y) * dt * 1.5), 0), rayP)
	if hit and not state.up and now - state.flyT > 0.6 and now > state.dashUntil then
		-- v1.8 GROUND SLAM: crash into the ground at high speed = shockwave
		if vNow.Magnitude > 105 and vNow.Y < -35 and now > (state.slamReady or 0) then
			state.slamReady = now + 2.5
			hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0)) * hrp.CFrame.Rotation
			CombatRE:FireServer("slam", hit.Position, vNow.Magnitude)
			if _G.InkwingShake then
				_G.InkwingShake(math.clamp(vNow.Magnitude / 200, 0.4, 0.9), 0.7)
			end
		end
		state.flying = false
		lv.Enabled, ao.Enabled = false, false
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.Landed)
		return
	end
	hum.PlatformStand = true
	lv.Enabled, ao.Enabled = true, true

	local wing = me:GetAttribute("Wing") or "Paper"
	local tier = me:GetAttribute("WingTier") or 1
	local w = G.Wings[wing] or G.Wings.Paper
	local speed = w.speed + tier * 2
	-- v1.0: wing rank + skills + Tempest aspect
	do
		local sk = me:GetAttribute("Skills") or ""
		speed *= 1 + ((me:GetAttribute("WingRank") or 1) - 1) * 0.05
		speed *= (me:GetAttribute("Aspect") == "Storm" and 1.1 or 1)
		if workspace:GetServerTimeNow() < (me:GetAttribute("BuffWind") or 0) then
			speed *= 1.3 -- Tailwind Tonic
		end
		local _ = sk
	end
	speed *= 0.6 -- v1.10: wings are much slower; distance matters
	local maxS = 100 + ((me:GetAttribute("WingRank") or 1) - 1) * 30
	local boosting = now < state.boostUntil
	if boosting and state.stam <= 0 then
		state.boostUntil = 0
		boosting = false
	end
	if boosting then
		speed *= 1.8
	end
	local tired = state.stam <= 0
	me:SetAttribute("Boost", boosting)
	local cam = workspace.CurrentCamera
	local look = cam.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.new(0, 0, -1)
	local move = hum.MoveDirection
	local target = move * speed
	if move.Magnitude > 0.1 then
		local fwd = math.max(0, move.Unit:Dot(flatLook))
		target += Vector3.new(0, look.Y * speed * fwd * 1.1, 0) -- fly where the camera looks
	end
	if state.up then
		target += Vector3.new(0, speed * 0.75, 0)
	end
	if state.down then
		target -= Vector3.new(0, speed * 1.3, 0)
	end
	-- MOMENTUM: keep climbing or diving and the wings build up speed (zones are far apart)
	local vdir = (target.Y > speed * 0.45 and 1) or (target.Y < -speed * 0.45 and -1) or 0
	if vdir ~= 0 and vdir == state.vdir then
		state.vHold = (state.vHold or 0) + dt
	else
		state.vHold = 0
	end
	state.vdir = vdir
	if vdir ~= 0 then
		local m = 1 + math.clamp((state.vHold - 0.6) / 2.5, 0, 1) * (vdir > 0 and 1 or 3)
		target = Vector3.new(target.X, target.Y * m, target.Z)
		me:SetAttribute("Rush", m > 1.5)
	else
		me:SetAttribute("Rush", false)
	end
	if move.Magnitude < 0.1 and not state.up and not state.down then
		target += Vector3.new(0, math.sin(now * 2) * 1.2, 0) -- idle hover
	end
	-- v1.10 WING STAMINA: flapping, climbing and boosting tire you; diving rests the wings.
	do
		local climbing = target.Y > 2
		local diving = state.vel.Y < -25
		local drain = boosting and 14 or climbing and 7 or (move.Magnitude > 0.1 and 3.5 or 2.5)
		if diving then
			drain = -6
		end
		if (me:GetAttribute("Skills") or ""):find("rotation") then
			drain -= 1.5
		end
		state.stam = math.clamp(state.stam - drain * dt, 0, maxS)
		if tired then -- exhausted: you can only glide down
			target = Vector3.new(target.X * 0.7, math.min(target.Y, -14), target.Z * 0.7)
			warnL.Text = "YOUR WINGS ARE EXHAUSTED - LAND TO REST"
			state.warnT = now
		end
		-- DIVE -> PULL UP: speed built in a dive turns into height and a burst
		if state.vel.Y < -45 then
			state.diveE = math.max(state.diveE * 0.995, -state.vel.Y)
		elseif state.diveE > 70 and look.Y > 0.12 and not state.down then
			local e = state.diveE
			state.diveE = 0
			state.vel = state.vel + Vector3.new(0, e * 0.85, 0) + flatLook * e * 0.35
			state.boostUntil = math.max(state.boostUntil, now + 1.2)
			sfx("jump_pad", { vol = 0.8 })
			pcall(InkFX.ring, hrp.Position, Color3.fromRGB(230, 240, 255), 2, 18, 0.4, 0.6)
			TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.15), { FieldOfView = 88 }):Play()
			task.delay(0.5, function()
				TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.8), { FieldOfView = 70 }):Play()
			end)
			if _G.InkwingShake then
				_G.InkwingShake(0.25, 0.3)
			end
		elseif state.vel.Y > -10 then
			state.diveE = math.max(0, state.diveE - dt * 120)
		end
	end
	-- WATER: hitting the ink sea brakes you hard, and you swim slower than you fly (Coral Wings swim fast)
	local y = hrp.Position.Y
	local wet = y < G.SEA
	if wet then
		target *= (wing == "Coral" and 0.6 or 0.28)
		target += Vector3.new(0, 3, 0) -- a little buoyancy
	end
	if wet ~= (state.wet or false) then
		state.wet = wet
		state.vel *= 0.3
		me:SetAttribute("Underwater", wet)
	end
	-- GATES
	local msg
	if y > G.CEILING then
		target = Vector3.new(target.X, math.min(target.Y, -30), target.Z)
		msg = "THE SKY ENDS HERE... FOR NOW"
	elseif y < G.FLOOR then
		target = Vector3.new(target.X, math.max(target.Y, 30), target.Z)
		msg = "NOTHING BELOW... YET"
	end
	if msg then
		warnL.Text = msg
		state.warnT = now
	elseif now - state.warnT > 2 then
		warnL.Text = ""
	end
	-- v0.7: hard speed cap by your best wings (Ink boost + momentum used to stack to ~800 studs/s)
	local rank = me:GetAttribute("BestRank") or 1
	local cap = (G.FLY_CAP[rank] or 150) * 0.6
	local exp = me:GetAttribute("Exposure") or 0
	if exp > 0 then
		cap *= math.max(0.35, 1 - exp * 0.2) -- too-weak wings struggle in hostile zones
	end
	if target.Magnitude > cap then
		target = target.Unit * cap
	end
	if now < state.dashUntil then
		target = state.dashVel
	end
	state.vel = state.vel:Lerp(target, math.clamp(dt * 5, 0, 1))
	if _G.InkwingImpulse then -- v1.6: knockbacks / pulls from elites and bosses
		state.vel += _G.InkwingImpulse
		_G.InkwingImpulse = nil
	end
	lv.VectorVelocity = state.vel + wind + (_G.InkwingExtVel or Vector3.zero) -- v1.6: wind currents / updrafts
	-- face where you fly, lean into turns and dives
	local hv = Vector3.new(state.vel.X, 0, state.vel.Z)
	local face = hv.Magnitude > 3 and hv.Unit or flatLook
	if me:GetAttribute("CombatCam") then
		face = flatLook -- combat camera: always face the crosshair
	end
	local turn = face:Cross(flatLook).Y
	bank += ((math.clamp(turn * 1.5, -0.6, 0.6)) - bank) * math.clamp(dt * 4, 0, 1)
	local pitch = math.clamp(state.vel.Y / math.max(speed, 1), -0.6, 0.6) * 0.6 - math.clamp(hv.Magnitude / math.max(speed, 1), 0, 1) * 0.35
	ao.CFrame = CFrame.lookAt(Vector3.zero, face) * CFrame.Angles(pitch, 0, bank)
end)
