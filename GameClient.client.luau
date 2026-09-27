-- v0.4 quiet presentation. Input is intent only; the server owns all gameplay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.CombatRules)
local Journey = require(ReplicatedStorage.Shared.JourneyRules)
local Layout = require(ReplicatedStorage.Shared.LayoutRules)
local AnimationManager = require(ReplicatedStorage.Shared.AnimationManager)
local SpiderAnimator = require(ReplicatedStorage.Shared.SpiderAnimator)
local PromptController = require(ReplicatedStorage.Shared.PromptController)
local VFX = require(ReplicatedStorage.Shared.VFXManager)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage.Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("HeavensunderHUD")
local canvas = gui:WaitForChild("Canvas")
local hotbar, stats, questPanel = canvas.Hotbar, canvas.Stats, canvas.Quest
local guide, dialogue, journal = canvas.Guide, canvas.Dialogue, canvas.Journal
local toast, bossPanel, targetPanel = canvas.Toast, canvas.Boss, canvas.Target
local qualityLow, reducedMotion = false, false
local qualityMode, averageDt, qualityStable = 0, 1 / 60, 0
local notifications, currentNotice = {}, nil
local toastId, zoneId, hintId = 0, 0, 0
local currentHumanoid, healthConnection, maxHealthConnection
local lastSent, tweens, enemies = {}, {}, {}
local lockedTarget, queuedAction
local dialogueToken, choices = nil, {}
local journalPage = "Journey"
local mouseHeld = false
local targetHighlight = Instance.new("Highlight")
targetHighlight.Name = "LocalTargetOutline"
targetHighlight.FillTransparency = 1; targetHighlight.OutlineTransparency = 0.12
targetHighlight.OutlineColor = Color3.fromRGB(197, 235, 188)
targetHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
targetHighlight.Enabled = false; targetHighlight.Parent = workspace
local function tween(object, properties, duration)
	if tweens[object] then tweens[object]:Cancel() end
	local t = TweenService:Create(object, TweenInfo.new(duration or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	tweens[object] = t; t:Play()
end
local function compact(value) return tostring(math.floor(value or 0)) end
local function now() return workspace:GetServerTimeNow() end
local function focusButton(button)
	if UserInputService.GamepadEnabled then GuiService.SelectedObject = button end
end
local function modalOpen() return guide.Visible or dialogue.Visible or journal.Visible end
local function updateScale()
	local camera=workspace.CurrentCamera
	if not camera then return end
	local top,bottom=GuiService:GetGuiInset()
	local view=camera.ViewportSize-top-bottom
	canvas.Scale.Scale=1
	for _,panel in {guide,journal,dialogue} do
		local size=panel.Size
		panel.Fit.Scale=Layout.ModalScale(view.X,view.Y,size.X.Offset,size.Y.Offset)
	end
	stats.Position=UDim2.new(0,14,1,Layout.StatsY(view.X))
	canvas.Location.Visible=Layout.ShowLocation(view.X)
	canvas.GuideToggle.Visible=Layout.ShowHelp(view.X)
	hotbar.Fit.Scale=Layout.HotbarScale(view.X)
	canvas.Interact.Position=UDim2.new(.5,-150,1,Layout.PromptY(view.X))
	canvas.RecallProgress.Position=UDim2.new(.5,-140,1,view.X<950 and -220 or -168)
	local toastWidth=math.min(320,view.X-28)
	toast.Size=UDim2.fromOffset(toastWidth,58)
	toast.Position=UDim2.new(.5,-toastWidth/2,1,Layout.ToastY(view.X))
	local bossWidth=math.min(360,view.X-28)
	bossPanel.Size=UDim2.fromOffset(bossWidth,47)
	bossPanel.Position=UDim2.new(.5,-bossWidth/2,0,52)
	hotbar.Visible=not modalOpen()
	canvas.ModalVeil.Visible=modalOpen()
end
local function showToast(title, body)
	body = body or ""
	if currentNotice and currentNotice.Title == title and currentNotice.Body == body then return end
	for _, pending in notifications do if pending.Title == title and pending.Body == body then return end end
	if #notifications >= 8 then table.remove(notifications, 1) end
	table.insert(notifications, {Title = title, Body = body})
end
-- A bounded FIFO preserves rewards/status instead of overwriting each message.
-- Dialogues and the journal pause the current notice; they don't silently consume it.
task.spawn(function()
	while gui.Parent do
		if not currentNotice and #notifications > 0 then
			currentNotice = table.remove(notifications, 1); currentNotice.Left = 3.5
			toast.Title.Text = currentNotice.Title; toast.Body.Text = currentNotice.Body
			updateScale()
		end
		toast.Visible = currentNotice ~= nil and not modalOpen() and not canvas.Interact.Visible
		if currentNotice and not modalOpen() and not canvas.Interact.Visible then currentNotice.Left -= 0.1; if currentNotice.Left <= 0 then currentNotice = nil end end
		task.wait(0.1)
	end
end)
local function refreshHealth()
	local hum = currentHumanoid
	if not hum then return end
	stats.HealthRead.Text = "HP  " .. compact(hum.Health) .. " / " .. compact(hum.MaxHealth)
	tween(stats.HealthBar.Fill, {Size = UDim2.fromScale(math.clamp(hum.Health / math.max(1, hum.MaxHealth), 0, 1), 1)})
end
local function shrineText()
	local lines = {}
	for i, shrine in Config.Shrines do
		table.insert(lines, (Rules.HasShrine(player:GetAttribute("Shrines") or 0, i) and "✓  " or "○  ") .. shrine.Name .. "  ·  " .. (Config.ZoneNames[shrine.Zone] or shrine.Zone))
	end
	return table.concat(lines, "\n")
end
local function refreshJournal()
	if not journal.Visible then return end
	local index = player:GetAttribute("Realm") or 1
	local realm = Config.Realms[index]
	if journalPage == "Journey" then
		local quest = Config.Quests[player:GetAttribute("Quest") or 1]
		journal.Scroll.Body.Text = (quest and ("CURRENT TRIAL — " .. quest.Title .. "\n" .. quest.Text) or "THE ELDER'S THREE TRIALS ARE COMPLETE.\nThe ninth realm still awaits.") .. "\n\nTHE FOUR MERIDIANS\n" .. shrineText() .. "\n\nEach shrine: 30 Qi + 15 spirit. All four: an extra 100 Qi + 60 spirit.\nSpeak to Elder Yun to claim completed trial rewards."
	elseif journalPage == "Techniques" then
		journal.Scroll.Body.Text = "JADE STRIKE · M1 / R2 · No focus cost\nThree strikes form a combo; waiting 1.35 seconds resets it.\n\nHEAVEN PALM · Q / X · 22 focus · 4.5-second cooldown\nAim toward your camera or use T / R3 to lock a visible target.\n\nCLOUD STEP · SHIFT / B · 14 focus · 2.8-second cooldown\nDash with brief invulnerability. Solid walls stop the dash.\n\nLOTUS BLOOM · R / Y · 48 focus · Requires realm III\nMERIDIAN GUARD · G / L2 · 10 focus\nThe first 0.23 seconds parry; the rest blocks at a focus cost.\nAfter a perfect parry, strike within 2.5 seconds to riposte.\n\nK / RECALL BUTTON · Four-second stationary homeward seal.\nEight seconds out of combat; movement or actions cancel it.\n\nDISCIPLINES · Select a southern sanctuary altar.\nTiger: +12% damage. Crane: +25% focus regen.\nTortoise: 25% less damage after a successful block."
	else
		journal.Scroll.Body.Text = "CULTIVATION — " .. realm.Name .. "  [" .. index .. " / 9]\nQi: " .. compact(player:GetAttribute("Qi")) .. " / " .. realm.Need .. "\nFocus recovery: " .. string.format("%.1f", Rules.FocusRegen(index, false) * Journey.Discipline(player:GetAttribute("Discipline")).Focus) .. " per second\n\nSPIRIT POUCH\n" .. compact(player:GetAttribute("Spirit")) .. " spirit   /   " .. compact(player:GetAttribute("Petals")) .. " petals\n\nBATTLE RECORD\nGuardians defeated: " .. compact(player:GetAttribute("Kills")) .. "\nHollow Lotus victories: " .. compact(player:GetAttribute("BossKills")) .. "\nPerfect parries: " .. compact(player:GetAttribute("Parries")) .. "\n\n" .. (player:GetAttribute("SaveStatus") or "CONNECTING…") .. "\nStudio sessions are temporary unless persistence is explicitly enabled."
	end
	if journalPage=="Journey" then
		journal.Scroll.Body.Text ..= string.format("\n\nTHE WORLD BELOW\nTake Dawnreach's southern gold gate to Lanternwake.\nMei Lan's survey: %s\nSilkweavers: %d / 5 · Mountain seal: %s\nThe winding path on the north-west mountain reaches the seal.", ({[0]="Speak to Mei Lan",[1]="In progress",[2]="Complete"})[player:GetAttribute("ValleyQuest") or 0], math.min(player:GetAttribute("SilkKills") or 0,5),player:GetAttribute("MountainSeal")==1 and "Recorded" or "Undiscovered")
	end
	for _, page in {"Journey", "Techniques", "Records"} do journal[page].BackgroundColor3 = page == journalPage and Color3.fromRGB(54, 81, 64) or Color3.fromRGB(28, 47, 50) end
end
local function refreshStats()
	local index = math.clamp(player:GetAttribute("Realm") or 1, 1, #Config.Realms)
	local realm, qi = Config.Realms[index], player:GetAttribute("Qi") or 0
	stats.Discipline.Text = Journey.Discipline(player:GetAttribute("Discipline")).Name:upper() .. (player:GetAttribute("Meditating") and string.format(" · RESONANCE +%d%%", math.floor(((player:GetAttribute("Resonance") or 1) - 1) * 100 + 0.5)) or "")
	stats.RealmName.Text = realm.Name; stats.RealmIndex.Text = string.format("REALM %02d / 09", index)
	stats.QiRead.Text = "QI  " .. compact(qi) .. " / " .. realm.Need
	tween(stats.QiBar.Fill, {Size = UDim2.fromScale(math.clamp(qi / realm.Need, 0, 1), 1), BackgroundColor3 = realm.Color})
	stats.FocusRead.Text = "FOCUS  " .. compact(player:GetAttribute("Focus")) .. " / 100"
	tween(stats.FocusBar.Fill, {Size = UDim2.fromScale(math.clamp((player:GetAttribute("Focus") or 0) / 100, 0, 1), 1)})
	stats.Currency.Text = compact(player:GetAttribute("Spirit")) .. " SPIRIT    /    " .. compact(player:GetAttribute("Petals")) .. " PETALS"
	stats.Save.Text = player:GetAttribute("SaveStatus") or "CONNECTING TO THE HEAVENS…"
	hotbar.Lotus.Title.Text = index < 3 and "SEALED · III" or "LOTUS BLOOM"
	hotbar.Meditate.Title.Text = player:GetAttribute("Meditating") and "STAND" or "CULTIVATE"
	local ready = index < 9 and qi >= realm.Need
	hotbar.Breakthrough.Title.Text = ready and "ASCEND · READY" or "BREAKTHROUGH"
	hotbar.Breakthrough.BackgroundColor3 = ready and Color3.fromRGB(85, 74, 42) or Color3.fromRGB(20, 33, 41)
	refreshHealth(); refreshJournal()
end
local function refreshQuest()
	local zone=player:GetAttribute("Zone")
	if (zone=="Lanternwake" or zone=="Silkwood" or zone=="Lowlands" or zone=="Cloudroot") and (player:GetAttribute("ValleyQuest") or 0)>0 then
		questPanel.Title.Text="The valley commission"
		questPanel.Body.Text="Survey Cloudroot Peak and clear the silkweavers. Return to Mei Lan."
		questPanel.Progress.Text=player:GetAttribute("ValleyQuest")==2 and "SURVEY COMPLETE" or string.format("SILKWEAVERS %d / 5 · SEAL %s", math.min(player:GetAttribute("SilkKills") or 0,5), player:GetAttribute("MountainSeal")==1 and "✓" or "—")
		refreshJournal();return
	end
	local quest = Config.Quests[player:GetAttribute("Quest") or 1]
	if not quest then
		questPanel.Title.Text = "The path is yours"; questPanel.Body.Text = "Restore the four meridians. Reach Ninefold Immortal. Your journal remembers the journey."
		questPanel.Progress.Text = "ALL THREE TRIALS COMPLETE"; refreshJournal(); return
	end
	questPanel.Title.Text = quest.Title; questPanel.Body.Text = quest.Text
	local lines, ready = {}, true
	if quest.Gather > 0 then local n = math.min(player:GetAttribute("QuestGather") or 0, quest.Gather); table.insert(lines, "LOTUSES  " .. n .. " / " .. quest.Gather); ready = ready and n == quest.Gather end
	if quest.Kills > 0 then local n = math.min(player:GetAttribute("QuestKills") or 0, quest.Kills); table.insert(lines, "DEFEATED  " .. n .. " / " .. quest.Kills); ready = ready and n == quest.Kills end
	if quest.Boss then local done = (player:GetAttribute("QuestBoss") or 0) > 0; table.insert(lines, "HOLLOW LOTUS  " .. (done and "✓" or "—")); ready = ready and done end
	questPanel.Progress.Text = ready and "READY · SPEAK TO ELDER YUN" or table.concat(lines, "\n")
	refreshJournal()
end
local function setTarget(model)
	lockedTarget = model
	targetHighlight.Adornee = model; targetHighlight.Enabled = model ~= nil
	targetPanel.Visible = model ~= nil
end
local function chooseTarget()
	if lockedTarget then setTarget(nil); return end
	local char = player.Character; local root = char and char:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then return end
	local best, score = nil, math.huge
	for model in enemies do
		local enemyRoot = model:FindFirstChild("HumanoidRootPart"); local hum = model:FindFirstChildOfClass("Humanoid")
		if not enemyRoot or not hum or hum.Health <= 0 then continue end
		local delta = enemyRoot.Position - root.Position
		local projected, visible = camera:WorldToViewportPoint(enemyRoot.Position)
		if delta.Magnitude > 95 or not visible then continue end
		local ray = RaycastParams.new(); ray.FilterType = Enum.RaycastFilterType.Exclude; ray.FilterDescendantsInstances = {char, model}
		if workspace:Raycast(root.Position, delta, ray) then continue end
		local screenDistance = (Vector2.new(projected.X, projected.Y) - camera.ViewportSize / 2).Magnitude / math.max(1, camera.ViewportSize.Y)
		local value = delta.Magnitude + screenDistance * 45
		if value < score then best, score = model, value end
	end
	setTarget(best)
	if not best then showToast("NO VISIBLE TARGET", "Face a living guardian within 95 studs, then press T.") end
end
local function send(key)
	if UserInputService:GetFocusedTextBox() or modalOpen() then return end
	if key == "Palm" and PromptController.GamepadActive() then return end
	if (lastSent[key] or 0) + 0.10 > os.clock() then return end
	local remaining = (player:GetAttribute("CD" .. key) or 0) - now()
	if remaining > 0 and remaining <= 0.16 then queuedAction = {Key = key, Until = now() + 0.20}; return end
	if remaining > 0 then return end
	lastSent[key] = os.clock()
	local char = player.Character; local root = char and char:FindFirstChild("HumanoidRootPart"); local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return end
	local direction = root.CFrame.LookVector
	local enemyRoot = lockedTarget and lockedTarget:FindFirstChild("HumanoidRootPart")
	if enemyRoot then direction = enemyRoot.Position - root.Position
	elseif workspace.CurrentCamera then direction = workspace.CurrentCamera.CFrame.LookVector end
	if key == "Dash" and hum.MoveDirection.Magnitude > 0.1 then direction = hum.MoveDirection end
	remotes.Action:FireServer(key, direction)
end
local function closeGuide()
	guide.Visible = false; GuiService.SelectedObject = nil
	if player:GetAttribute("ProfileLoaded") then remotes.Action:FireServer("IntroSeen") end
end
local function toggleJournal()
	journal.Visible = not journal.Visible
	if journal.Visible then guide.Visible = false; dialogue.Visible = false; toast.Visible = false; mouseHeld = false; refreshJournal(); focusButton(journal.Close) end
end
local function applyQuality()
	VFX.SetQuality(qualityLow); AnimationManager.SetQuality(qualityLow)
	local mode = qualityMode == 0 and (qualityLow and "AUTO · LOW" or "AUTO · FULL") or qualityMode == 1 and "FULL" or "LOW"
	canvas.QualityToggle.Text = "VFX · " .. mode; journal.Quality.Text = "EFFECTS · " .. mode
end
local function setQuality()
	qualityMode = (qualityMode + 1) % 3; qualityStable = 0
	if qualityMode ~= 0 then qualityLow = qualityMode == 2 end
	applyQuality()
end
for key, inputs in {
	Strike = {Enum.KeyCode.ButtonR2}, Palm = {Enum.KeyCode.Q, Enum.KeyCode.ButtonX},
	Dash = {Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB}, Lotus = {Enum.KeyCode.R, Enum.KeyCode.ButtonY},
	Meditate = {Enum.KeyCode.F, Enum.KeyCode.DPadDown}, Breakthrough = {Enum.KeyCode.B, Enum.KeyCode.DPadUp},
	Guard = {Enum.KeyCode.G, Enum.KeyCode.ButtonL2},
} do
	ContextActionService:BindAction("Heavensunder_" .. key, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then send(key) end
		return Enum.ContextActionResult.Pass
	end, false, table.unpack(inputs))
	hotbar[key].Activated:Connect(function() send(key) end)
end
ContextActionService:BindAction("Heavensunder_Target", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and not modalOpen() and not UserInputService:GetFocusedTextBox() then chooseTarget() end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.T, Enum.KeyCode.ButtonR3)
guide.Close.Activated:Connect(closeGuide)
dialogue.Close.Activated:Connect(function() dialogue.Visible = false; dialogueToken = nil; GuiService.SelectedObject = nil end)
canvas.GuideToggle.Activated:Connect(function() guide.Visible = not guide.Visible; journal.Visible = false; dialogue.Visible = false; if guide.Visible then focusButton(guide.Close) end end)
canvas.JournalToggle.Activated:Connect(toggleJournal)
canvas.QuestToggle.Activated:Connect(function() questPanel.Visible = not questPanel.Visible end)
canvas.TargetToggle.Activated:Connect(function() if not modalOpen() then chooseTarget() end end)
canvas.RecallToggle.Activated:Connect(function() send("Recall") end)
canvas.QualityToggle.Activated:Connect(setQuality); journal.Quality.Activated:Connect(setQuality)
journal.Close.Activated:Connect(function() journal.Visible = false; GuiService.SelectedObject = nil end)
journal.Motion.Activated:Connect(function()
	reducedMotion = not reducedMotion; VFX.SetReducedMotion(reducedMotion)
	journal.Motion.Text = reducedMotion and "CAMERA MOTION · OFF" or "CAMERA MOTION · ON"
end)
for _, page in {"Journey", "Techniques", "Records"} do journal[page].Activated:Connect(function() journalPage = page; journal.Scroll.CanvasPosition = Vector2.zero; refreshJournal() end) end
for index = 1, 3 do
	dialogue["Choice" .. index].Activated:Connect(function()
		if not dialogueToken or not choices[index] then return end
		local token, choice = dialogueToken, choices[index].Id
		dialogueToken = nil
		dialogue.Choice1.Visible = false; dialogue.Choice2.Visible = false; dialogue.Choice3.Visible = false
		remotes.NpcChoice:FireServer(token, choice)
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not modalOpen() then mouseHeld = true; send("Strike") end
	if input.KeyCode == Enum.KeyCode.H then guide.Visible = not guide.Visible; journal.Visible = false; dialogue.Visible = false; if guide.Visible then focusButton(guide.Close) end end
	if input.KeyCode == Enum.KeyCode.J then toggleJournal() end
	if input.KeyCode == Enum.KeyCode.K then send("Recall") end
	if input.KeyCode == Enum.KeyCode.Return then closeGuide(); dialogue.Visible = false; journal.Visible = false end
	local movement = input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Space
	if movement and player:GetAttribute("Meditating") then remotes.Action:FireServer("CancelMeditation") end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then mouseHeld = false end end)
UserInputService.WindowFocusReleased:Connect(function() mouseHeld = false; queuedAction = nil end)
remotes.Notice.OnClientEvent:Connect(function(kind, data)
	if kind == "Dialogue" then
		journal.Visible = false; guide.Visible = false; toast.Visible = false; mouseHeld = false
		dialogue.Title.Text = data.Title; dialogue.Body.Text = data.Text; dialogue.Visible = true
		dialogueToken, choices = data.Token, data.Options or {}
		for i = 1, 3 do local button = dialogue["Choice" .. i]; button.Visible = choices[i] ~= nil; if choices[i] then button.Text = choices[i].Label end end
		focusButton(choices[1] and dialogue.Choice1 or dialogue.Close)
		if data.Token then
			local token = data.Token
			task.delay(25, function()
				if dialogueToken == token then dialogueToken = nil; dialogue.Choice1.Visible = false; dialogue.Choice2.Visible = false; dialogue.Choice3.Visible = false; dialogue.Body.Text = "This conversation has paused. Speak to the NPC again to continue." end
			end)
		end
	elseif kind == "HitConfirm" then
		hintId += 1; local id = hintId
		canvas.WorldHint.Text = data.Riposte and "RIPOSTE LANDED" or ("HIT CONFIRMED · COMBO " .. data.Combo .. " / 3")
		task.delay(1.1, function() if id == hintId then canvas.WorldHint.Text = "G · GUARD   /   T · TARGET LOCK   /   J · JOURNAL" end end)
	else showToast(data.Title, data.Text) end
end)
remotes.Effect.OnClientEvent:Connect(function(kind, data) VFX.Handle(kind, data) end)
local function attachCharacter(char, isLocal)
	local hum = char:WaitForChild("Humanoid", 10); local root = char:WaitForChild("HumanoidRootPart", 10)
	if not hum or not root then return end
	local animate = char:FindFirstChild("Animate"); if animate and animate:IsA("LocalScript") then animate.Disabled = true end
	if not SpiderAnimator.Attach(char) then AnimationManager.Attach(char) end
	if isLocal then
		if healthConnection then healthConnection:Disconnect() end
		if maxHealthConnection then maxHealthConnection:Disconnect() end
		setTarget(nil); queuedAction = nil; mouseHeld = false; currentHumanoid = hum
		hum.CameraOffset = Vector3.new(0, 0.8, 0); player.CameraMinZoomDistance = 8; player.CameraMaxZoomDistance = 70
		healthConnection = hum.HealthChanged:Connect(refreshHealth)
		maxHealthConnection = hum:GetPropertyChangedSignal("MaxHealth"):Connect(refreshHealth)
		hum:GetPropertyChangedSignal("MoveDirection"):Connect(function()
			if hum.MoveDirection.Magnitude > 0.1 and player:GetAttribute("Meditating") and (lastSent.Cancel or 0) + 0.3 < os.clock() then lastSent.Cancel = os.clock(); remotes.Action:FireServer("CancelMeditation") end
		end)
		refreshHealth()
	end
end
local function watchPlayer(other)
	other.CharacterAdded:Connect(function(char) task.spawn(attachCharacter, char, other == player) end)
	if other.Character then task.spawn(attachCharacter, other.Character, other == player) end
end
Players.PlayerAdded:Connect(watchPlayer); for _, other in Players:GetPlayers() do watchPlayer(other) end
for _, folder in {workspace.Actors.Enemies, workspace.Actors.NPCs} do
	local isEnemy = folder == workspace.Actors.Enemies
	folder.ChildAdded:Connect(function(model) if isEnemy then enemies[model] = true end; task.spawn(attachCharacter, model, false) end)
	folder.ChildRemoved:Connect(function(model) enemies[model] = nil; AnimationManager.Detach(model); SpiderAnimator.Detach(model); if model == lockedTarget then setTarget(nil) end end)
	for _, model in folder:GetChildren() do if isEnemy then enemies[model] = true end; task.spawn(attachCharacter, model, false) end
end
AnimationManager.RegisterFoliage(workspace.World.Foliage); AnimationManager.Start(); SpiderAnimator.Start(); VFX.Start(); applyQuality()
PromptController.Start(canvas.Interact, function() return modalOpen() or canvas.RecallProgress.Visible end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)
for _, key in {"Realm", "Qi", "Focus", "Spirit", "Petals", "SaveStatus", "Meditating", "Shrines", "Parries", "Kills", "BossKills", "Discipline", "Resonance"} do player:GetAttributeChangedSignal(key):Connect(refreshStats) end
for _, key in {"Quest", "QuestKills", "QuestGather", "QuestBoss", "ValleyQuest", "SilkKills", "MountainSeal"} do player:GetAttributeChangedSignal(key):Connect(refreshQuest) end
player:GetAttributeChangedSignal("IntroSeen"):Connect(function() if player:GetAttribute("IntroSeen") == 1 then guide.Visible = false end end)
local function refreshLocation(announce)
	local zone = player:GetAttribute("Zone") or "Sanctuary"
	local name = Config.ZoneNames[zone] or "THE UNWRITTEN SKY"
	canvas.Location.Zone.Text = name
	local weather = workspace:GetAttribute("Weather") or "Clear"
	canvas.Location.Weather.Text = zone == "Frost" and "SNOWFALL · FROSTVEIL" or ({Clear = "GOLDEN HOUR · CLEAR", Gathering = "CLOUDS GATHERING", Rain = "SPIRIT RAIN", Clearing = "THE SKY IS CLEARING"})[weather] or weather
	if announce then
		zoneId += 1; local id = zoneId
		canvas.ZoneToast.Text = name; canvas.ZoneToast.Visible = true
		task.delay(3, function() if zoneId == id then canvas.ZoneToast.Visible = false end end)
	end
end
local function refreshWeather()
	refreshLocation(false)
	local atmosphere = Lighting:FindFirstChild("SkyVeil"); local grade = Lighting:FindFirstChild("WeatherGrade")
	local intensity = workspace:GetAttribute("WeatherIntensity") or 0
	local frost = player:GetAttribute("Zone") == "Frost"
	if atmosphere then tween(atmosphere, {Density = 0.27 + intensity * 0.07 + (frost and 0.015 or 0), Haze = 1.4 + intensity * 0.7}, 2.2) end
	if grade then
		local tint = Color3.new(1, 1, 1):Lerp(frost and Color3.fromRGB(210, 233, 255) or Color3.fromRGB(211, 227, 247), math.max(intensity * 0.60, frost and 0.35 or 0))
		tween(grade, {TintColor = tint, Saturation = -intensity * 0.06, Brightness = -intensity * 0.018}, 2.2)
	end
end
player:GetAttributeChangedSignal("Zone"):Connect(function() refreshLocation(false); refreshWeather(); refreshQuest() end)
workspace:GetAttributeChangedSignal("Weather"):Connect(refreshWeather)
workspace:GetAttributeChangedSignal("WeatherIntensity"):Connect(refreshWeather)
local uiClock = 0
RunService.RenderStepped:Connect(function(dt)
	averageDt += (math.min(dt, 0.15) - averageDt) * math.min(1, dt * 1.5)
	if qualityMode == 0 then
		local stressed = not qualityLow and averageDt > 1 / 42
		local recovered = qualityLow and averageDt < 1 / 56
		qualityStable = (stressed or recovered) and qualityStable + dt or 0
		local nextLow = Journey.Quality(averageDt, qualityLow, qualityStable)
		if nextLow ~= qualityLow then qualityLow = nextLow; qualityStable = 0; applyQuality() end
	end
	uiClock += dt; if uiClock < 0.1 then return end; uiClock = 0
	updateScale(); local t = now()
	local recall = (player:GetAttribute("RecallUntil") or 0) - t
	canvas.RecallProgress.Visible = recall > 0
	canvas.RecallProgress.Bar.Fill.Size = UDim2.fromScale(math.clamp(1 - recall / 4, 0, 1), 1)
	canvas.RecallToggle.Text = recall > 0 and "×" or ((player:GetAttribute("CDRecall") or 0) > t and tostring(math.ceil(player:GetAttribute("CDRecall") - t)) or "K")
	local practice = (player:GetAttribute("TrainingUntil") or 0) - t
	canvas.Practice.Visible = practice > 0 and not modalOpen()
	if practice > 0 then
		canvas.Practice.Title.Text = string.format("PRACTICE · %ds · %d PARRIES", math.ceil(practice), player:GetAttribute("TrainingParries") or 0)
		canvas.Practice.Read.Text = string.format("%d hits · %.1f DPS\n%s", player:GetAttribute("TrainingHits") or 0, player:GetAttribute("TrainingDPS") or 0, player:GetAttribute("TrainingHint") or "")
	end
	if queuedAction then
		local queued = queuedAction
		if t > queued.Until then queuedAction = nil
		elseif (player:GetAttribute("CD" .. queued.Key) or 0) <= t then queuedAction = nil; send(queued.Key) end
	end
	if mouseHeld and not modalOpen() and (lastSent.Strike or 0) + 0.45 <= os.clock() then send("Strike") end
	for _, key in {"Strike", "Palm", "Dash", "Lotus", "Guard"} do
		local remaining = (player:GetAttribute("CD" .. key) or 0) - t
		hotbar[key].Cooldown.Text = remaining > 0 and string.format("%.1f", remaining) or ""; hotbar[key].Cooldown.Visible = remaining > 0
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")

	if lockedTarget then
		local hum = lockedTarget:FindFirstChildOfClass("Humanoid"); local enemyRoot = lockedTarget:FindFirstChild("HumanoidRootPart")
		if not root or not enemyRoot or not hum or hum.Health <= 0 or (enemyRoot.Position - root.Position).Magnitude > 115 then setTarget(nil)
		else targetPanel.Title.Text = lockedTarget:GetAttribute("DisplayName") or lockedTarget.Name; targetPanel.Hint.Text = string.upper(lockedTarget:GetAttribute("AIState") or "IDLE") .. " · T / R3 RELEASE"; targetPanel.Bar.Fill.Size = UDim2.fromScale(hum.Health / hum.MaxHealth, 1) end
	end
	local boss
	if root then for model in enemies do
		local er, hum = model:FindFirstChild("HumanoidRootPart"), model:FindFirstChildOfClass("Humanoid")
		if model:GetAttribute("Boss") and er and hum and hum.Health > 0 and (root.Position - er.Position).Magnitude < 130 then boss = model; break end
	end end
	bossPanel.Visible = boss ~= nil
	targetPanel.Position = UDim2.new(.5,-120,0,boss and 109 or 51)
	if boss then
		local hum = boss:FindFirstChildOfClass("Humanoid")
		bossPanel.Title.Text = string.upper(boss:GetAttribute("DisplayName") or boss.Name) .. (boss:GetAttribute("Enraged") and " · ENRAGED" or "")
		bossPanel.Bar.Fill.Size = UDim2.fromScale(hum.Health / hum.MaxHealth, 1); bossPanel.Read.Text = compact(hum.Health) .. " / " .. compact(hum.MaxHealth)
	end
end)
guide.Visible = false
if player:GetAttribute("IntroSeen") ~= 1 then showToast("WELCOME, PILGRIM", "H opens the guide. J opens your journal. Hold E to interact.") end
refreshStats(); refreshQuest(); refreshLocation(false); refreshWeather(); updateScale(); gui.Enabled = true
