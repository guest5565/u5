--!nonstrict
-- INKWING :: PROMPTS + DIALOGUE (v1.10)
--   * Every ProximityPrompt is drawn as one clean "hold E" chip: a key circle with a filling ring + a word.
--   * Talking to an NPC: the camera eases in on them, the rest of the UI fades away, lines type out at
--     the bottom and you pick from 2-3 choices.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local G = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"))
local Fn = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fn")
local me = Players.LocalPlayer
local rgb = Color3.fromRGB
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local okA, Audio = pcall(require, ReplicatedStorage.Shared:WaitForChild("Audio"))
local function sfx(n, o)
	if okA and Audio then
		pcall(Audio.play, n, o)
	end
end

local DARK, GOLD = rgb(28, 28, 32), rgb(240, 200, 70)
local function new(c, props, parent)
	local o = Instance.new(c)
	for k, v in pairs(props or {}) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function corner(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local pg = me:WaitForChild("PlayerGui")
local promptGui = new("ScreenGui", { Name = "Prompts", ResetOnSpawn = false, DisplayOrder = 8 }, pg)

---------------------------------------------------------------------------
-- CUSTOM PROMPTS
---------------------------------------------------------------------------
local function styleAll(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			d.Style = Enum.ProximityPromptStyle.Custom
		end
	end
end
styleAll(workspace)
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		d.Style = Enum.ProximityPromptStyle.Custom
	end
end)

local chips = {}
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom or _G.InkwingDialogue then
		return
	end
	local bb = new("BillboardGui", { Adornee = prompt.Parent, Size = UDim2.fromOffset(170, 46), StudsOffset = Vector3.new(0, 2.5, 0), AlwaysOnTop = true, LightInfluence = 0, Active = true, ResetOnSpawn = false }, promptGui)
	local btn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "" }, bb)
	local key = new("Frame", { Position = UDim2.fromOffset(2, 3), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = DARK, BackgroundTransparency = 0.15 }, bb)
	corner(key, 999)
	local ringS = new("UIStroke", { Thickness = 2, Color = rgb(120, 120, 130) }, key)
	local kl = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, Text = isMobile and "TAP" or (prompt.KeyboardKeyCode.Name), TextColor3 = Color3.new(1, 1, 1) }, key)
	new("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, kl)
	-- the filling ring: a gold circle that grows behind the key while held
	local fill = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 0), BackgroundColor3 = GOLD, BackgroundTransparency = 0.3, ZIndex = 0 }, key)
	corner(fill, 999)
	local word = (prompt.HoldDuration > 0 and (isMobile and "Hold to " or "Hold to ") or "") .. prompt.ActionText:lower()
	new("TextLabel", { Position = UDim2.fromOffset(50, 8), Size = UDim2.new(1, -52, 0, 30), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = word, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, TextStrokeColor3 = rgb(60, 60, 66) }, bb)
	local holdTw
	local c1 = prompt.PromptButtonHoldBegan:Connect(function()
		ringS.Color = GOLD
		holdTw = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
		holdTw:Play()
	end)
	local c2 = prompt.PromptButtonHoldEnded:Connect(function()
		ringS.Color = rgb(120, 120, 130)
		if holdTw then
			holdTw:Cancel()
		end
		fill.Size = UDim2.fromScale(0, 0)
	end)
	btn.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	btn.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.Touch or io.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)
	chips[prompt] = bb
	prompt.PromptHidden:Once(function()
		c1:Disconnect()
		c2:Disconnect()
		bb:Destroy()
		chips[prompt] = nil
	end)
end)

---------------------------------------------------------------------------
-- DIALOGUE WINDOW
---------------------------------------------------------------------------
local dGui = new("ScreenGui", { Name = "Dialogue", ResetOnSpawn = false, DisplayOrder = 30, Enabled = false, IgnoreGuiInset = true }, pg)
-- cinematic bars
local barT = new("Frame", { Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, dGui)
local barB = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, dGui)
local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(0.9, 0, 0, isMobile and 170 or 190), BackgroundColor3 = DARK, BackgroundTransparency = 0.12 }, dGui)
new("UISizeConstraint", { MaxSize = Vector2.new(760, 240) }, box)
corner(box, 14)
new("UIStroke", { Thickness = 2, Color = GOLD }, box)
local nameL = new("TextLabel", { Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -40, 0, 26), BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Text = "", TextColor3 = GOLD }, box)
local lineL = new("TextLabel", { Position = UDim2.fromOffset(20, 42), Size = UDim2.new(1, -40, 0, isMobile and 58 or 66), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = isMobile and 17 or 20, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "", TextColor3 = Color3.new(1, 1, 1) }, box)
local choiceF = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -12), Size = UDim2.new(1, -40, 0, isMobile and 52 or 56), BackgroundTransparency = 1 }, box)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Left, VerticalAlignment = Enum.VerticalAlignment.Center }, choiceF)

local talking, typingId = nil, 0
local camSaved
local function typeLine(text)
	typingId += 1
	local my = typingId
	lineL.Text = text
	lineL.MaxVisibleGraphemes = 0
	task.spawn(function()
		local n = utf8.len(text) or #text
		for i = 1, n do
			if typingId ~= my then
				return
			end
			lineL.MaxVisibleGraphemes = i
			if i % 3 == 0 then
				sfx("ui_click", { vol = 0.12 })
			end
			task.wait(0.018)
		end
		lineL.MaxVisibleGraphemes = -1
	end)
end
local curChoices = {}
local function setChoices(list)
	curChoices = list
	for _, c in ipairs(choiceF:GetChildren()) do
		if c:IsA("TextButton") then
			c:Destroy()
		end
	end
	for i, ch in ipairs(list) do
		local b = new("TextButton", { Size = UDim2.new(1 / #list, -10, 1, 0), BackgroundColor3 = rgb(48, 48, 54), Font = Enum.Font.GothamBold, TextScaled = true, Text = (isMobile and "" or (i .. "  ")) .. ch[1], TextColor3 = GOLD, AutoButtonColor = true, LayoutOrder = i }, choiceF)
		corner(b, 10)
		new("UIStroke", { Thickness = 1.5, Color = GOLD, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
		b:SetAttribute("Idx", i)
		b.Activated:Connect(function()
			sfx("ui_click", { vol = 0.4 })
			ch[2]()
		end)
	end
end

local function closeDialogue()
	if not talking then
		return
	end
	talking = nil
	typingId += 1
	TweenService:Create(barT, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	TweenService:Create(barB, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) }):Play()
	local cam = workspace.CurrentCamera
	if camSaved then
		local tw = TweenService:Create(cam, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { CFrame = camSaved })
		tw:Play()
		tw.Completed:Wait()
	end
	cam.CameraType = Enum.CameraType.Custom
	dGui.Enabled = false
	_G.InkwingDialogue = false
	if _G.InkwingHideUI then
		_G.InkwingHideUI(false)
	end
end

local function openDialogue(npcName, anchorPos, start)
	if talking then
		return
	end
	local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	talking = npcName
	_G.InkwingDialogue = true
	if _G.InkwingHideUI then
		_G.InkwingHideUI(true, true)
	end
	dGui.Enabled = true
	nameL.Text = npcName
	lineL.Text = ""
	setChoices({})
	TweenService:Create(barT, TweenInfo.new(0.35), { Size = UDim2.new(1, 0, 0.09, 0) }):Play()
	TweenService:Create(barB, TweenInfo.new(0.35), { Size = UDim2.new(1, 0, 0.09, 0) }):Play()
	-- camera: over your shoulder, framing the NPC's face
	local cam = workspace.CurrentCamera
	camSaved = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	local face = anchorPos + Vector3.new(0, 1.2, 0)
	local toMe = (hrp.Position - anchorPos) * Vector3.new(1, 0, 1)
	toMe = toMe.Magnitude > 0.1 and toMe.Unit or Vector3.new(0, 0, 1)
	local side = toMe:Cross(Vector3.yAxis)
	local camPos = face + toMe * 7.5 + side * 2.6 + Vector3.new(0, 0.8, 0)
	TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.lookAt(camPos, face) }):Play()
	-- face the NPC
	hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(anchorPos.X, hrp.Position.Y, anchorPos.Z))
	task.delay(0.35, start)
end
_G.InkwingOpenDialogue = openDialogue
_G.InkwingCloseDialogue = closeDialogue

UserInputService.InputBegan:Connect(function(io, gp)
	if not talking or gp then
		return
	end
	if io.KeyCode == Enum.KeyCode.Escape or io.KeyCode == Enum.KeyCode.Backspace then
		closeDialogue()
		return
	end
	local n = ({ [Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3 })[io.KeyCode]
	if n and curChoices[n] then
		sfx("ui_click", { vol = 0.4 })
		curChoices[n][2]()
	end
end)

---------------------------------------------------------------------------
-- MASTER ORREN
---------------------------------------------------------------------------
local function say(text, choices)
	typeLine(text)
	setChoices(choices)
end
local mentorRoot
local function mentorLesson()
	local ok, res = pcall(Fn.InvokeServer, Fn, "mentor")
	local lines = ok and res and res.lines or {}
	local i = 0
	local function nextLine()
		i += 1
		if lines[i] then
			say(lines[i], { { lines[i + 1] and "..." or "I understand", lines[i + 1] and nextLine or mentorRoot } })
		else
			mentorRoot()
		end
	end
	nextLine()
end
function mentorRoot()
	local ok, st = pcall(Fn.InvokeServer, Fn, "mentorState")
	st = ok and st or {}
	local bye = { "Goodbye", closeDialogue }
	local tips = { "How do I fly?", function()
		say("Hold jump to open your wings. Flapping tires them - watch the thin bar. Dive to rest them, and pull up out of a dive to turn that speed into height.", { { "Thank you", mentorRoot }, bye })
	end }
	if not st.has then
		say("I have taught you everything I know. The sky is yours now. Go - and come back stronger.", { tips, bye })
	elseif st.done then
		say("I can feel it in your mana. You did it.", { { "I'm ready", mentorLesson }, bye })
	elseif st.active then
		local t = (st.text or ""):lower():gsub("^%l", string.upper)
		say("Not yet. " .. t .. ". Come back when it is done.", { tips, bye })
	else
		say("You came back. Good. Are you ready for your next lesson?", { { "Teach me", mentorLesson }, tips, bye })
	end
end

---------------------------------------------------------------------------
-- QUILL (the scribe on the starter isle)
---------------------------------------------------------------------------
local quillRoot
function quillRoot()
	local bye = { "Goodbye", closeDialogue }
	say("Oh! A new face. The isles are big and the sky is bigger. What do you need?", {
		{ "Where should I go?", function()
			local q = G.Quests[me:GetAttribute("Quest") or 1]
			local t = q and q.text:lower():gsub("^%l", string.upper) or "Anywhere you like. You have done everything I know of."
			say(t .. ". The golden trail will lead you if you lose your way.", { { "Thanks", quillRoot }, bye })
		end },
		{ "Any advice?", function()
			say("Hold your senses open with V and the world shows you its mana. The things that look weak are not always weak. And mind your mana - seeing costs it.", { { "Thanks", quillRoot }, bye })
		end },
		bye,
	})
end

-- talk prompts
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local npc = prompt:GetAttribute("Npc")
	local p = prompt.Parent
	local pos = p and p:IsA("BasePart") and p.Position or (p and p:IsA("Model") and p:GetPivot().Position)
	if not pos then
		return
	end
	if npc == "mentor" then
		openDialogue("MASTER ORREN", pos, mentorRoot)
	elseif npc == "quill" then
		openDialogue("QUILL", pos, quillRoot)
	end
end)
-- Quill has no server prompt: give her a local one
task.spawn(function()
	local f = workspace:WaitForChild("NPCFigures", 60)
	local col = f and f:WaitForChild("QuillCollider", 60)
	if not col then
		return
	end
	local pr = new("ProximityPrompt", { ActionText = "Talk", ObjectText = "Quill", HoldDuration = 0.5, MaxActivationDistance = 12, RequiresLineOfSight = false, Style = Enum.ProximityPromptStyle.Custom }, col)
	pr:SetAttribute("Npc", "quill")
end)

-- walk away / die = the conversation ends
RunService.Heartbeat:Connect(function()
	if talking then
		local hum = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			closeDialogue()
		end
	end
end)
