--------------------------------------------------
-- SETTINGS UI (CLIENT)
--
-- Gear button at the top-left (beside Roblox's own menu / chat buttons)
-- opening four toggles: Music (on), SFX (on), Low graphics (off),
-- Pop ups (on). The server owns and saves the values (SettingsService);
-- this script only asks to flip one and reacts to the replicated player
-- attributes SettingMusic / SettingSfx / SettingLowGfx / SettingPopups.
-- Music and pop-up behaviour is applied in MusicController, PopupsUI and
-- PromptManager; SFX muting and low graphics are applied here.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local setRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SettingSet")

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local GOLD = Color3.fromRGB(255, 214, 70)
local GREEN = Color3.fromRGB(60, 200, 110)
local FONT = Enum.Font.FredokaOne

local ROWS = {
	{ Key = "SettingMusic", Text = "Music", Default = true },
	{ Key = "SettingSfx", Text = "SFX", Default = true },
	{ Key = "SettingLowGfx", Text = "Low graphics", Default = false },
	{ Key = "SettingPopups", Text = "Pop ups", Default = true },
}

local function value(key)
	local v = player:GetAttribute(key)
	if typeof(v) == "boolean" then
		return v
	end
	for _, row in ipairs(ROWS) do
		if row.Key == key then
			return row.Default
		end
	end
	return false
end

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local old = playerGui:FindFirstChild("SettingsUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "SettingsUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 20,
}, playerGui)

-- sits right of Roblox's menu + chat buttons in the top bar
local gear = create("TextButton", {
	Position = UDim2.fromOffset(112, 7),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = Color3.fromRGB(48, 38, 120),
	Text = "⚙",
	Font = Enum.Font.GothamBold,
	TextSize = 26,
	TextColor3 = CREAM,
	AutoButtonColor = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, gear)
create("UIStroke", { Color = GOLD, Thickness = 2.5 }, gear)
local gearScale = create("UIScale", {}, gear)

-- TUTORIAL: replays the guide from the player's own progress (TutorialService validates
-- everything on the server; this only asks). Pressing it again stops the replay.
local tutorialButton = create("TextButton", {
	Name = "TutorialButton",
	Size = UDim2.fromOffset(104, 44),
	BackgroundColor3 = Color3.fromRGB(48, 38, 120),
	Text = "TUTORIAL",
	Font = FONT,
	TextSize = 16,
	TextColor3 = CREAM,
	AutoButtonColor = false,
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(1, 0) }, tutorialButton)
create("UIStroke", { Color = GOLD, Thickness = 2.5 }, tutorialButton)

-- hidden on every course (oil course, countdown, win course): on phones it sat over the oil bar
local function onCourse()
	local state = player:GetAttribute("RunState")
	return state == "Starting" or state == "Running" or state == "Finishing"
		or typeof(player:GetAttribute("WinTravelBudget")) == "number"
end

local function refreshTutorialButton()
	local finished = (player:GetAttribute("TutorialStep") or 0) >= 12
	tutorialButton.Visible = finished and not onCourse()
	tutorialButton.Text = player:GetAttribute("TutorialReplayStep") ~= nil and "STOP GUIDE" or "TUTORIAL"
end
player:GetAttributeChangedSignal("TutorialStep"):Connect(refreshTutorialButton)
player:GetAttributeChangedSignal("TutorialReplayStep"):Connect(refreshTutorialButton)
player:GetAttributeChangedSignal("RunState"):Connect(refreshTutorialButton)
player:GetAttributeChangedSignal("WinTravelBudget"):Connect(refreshTutorialButton)
refreshTutorialButton()

local lastTutorialPress = 0
tutorialButton.Activated:Connect(function()
	if os.clock() - lastTutorialPress < 1.5 then
		return
	end
	lastTutorialPress = os.clock()
	local remote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("TutorialReplay")
	if remote then
		remote:FireServer()
	end
end)

local panel = create("Frame", {
	Position = UDim2.fromOffset(112, 60),
	Size = UDim2.fromOffset(250, 56 + #ROWS * 46),
	BackgroundColor3 = Color3.fromRGB(30, 22, 80),
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 16) }, panel)
create("UIStroke", { Color = GOLD, Thickness = 3 }, panel)
create("UIGradient", {
	Color = ColorSequence.new(Color3.fromRGB(70, 52, 170), Color3.fromRGB(28, 20, 78)),
	Rotation = 90,
}, panel)
local panelScale = create("UIScale", {}, panel)

local title = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 6),
	Size = UDim2.new(1, 0, 0, 36),
	Font = FONT,
	Text = "SETTINGS",
	TextColor3 = GOLD,
	TextSize = 24,
}, panel)
create("UIStroke", { Color = INK, Thickness = 2 }, title)

local switches = {}

local function paint(key, animate)
	local sw = switches[key]
	if not sw then
		return
	end
	local on = value(key)
	local info = TweenInfo.new(animate and 0.15 or 0)
	TweenService:Create(sw.Track, info, { BackgroundColor3 = on and GREEN or Color3.fromRGB(95, 90, 120) }):Play()
	TweenService:Create(sw.Knob, info, { Position = on and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }):Play()
	sw.State.Text = on and "ON" or "OFF"
end

for i, row in ipairs(ROWS) do
	local holder = create("TextButton", {
		Position = UDim2.fromOffset(12, 46 + (i - 1) * 46),
		Size = UDim2.new(1, -24, 0, 40),
		BackgroundColor3 = Color3.fromRGB(20, 14, 58),
		BackgroundTransparency = 0.25,
		Text = "",
		AutoButtonColor = false,
	}, panel)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, holder)
	local name = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		Font = FONT,
		Text = row.Text,
		TextColor3 = CREAM,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, holder)
	create("UIStroke", { Color = INK, Thickness = 1.5 }, name)
	local state = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0, 36, 1, 0),
		Font = FONT,
		Text = "",
		TextColor3 = Color3.fromRGB(200, 195, 230),
		TextSize = 14,
	}, holder)
	local track = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(52, 26),
		BackgroundColor3 = GREEN,
	}, holder)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = CREAM,
	}, track)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
	switches[row.Key] = { Track = track, Knob = knob, State = state }

	holder.Activated:Connect(function()
		-- the server flips it; the attribute change repaints the switch
		setRemote:FireServer(row.Key, not value(row.Key))
	end)
	player:GetAttributeChangedSignal(row.Key):Connect(function()
		paint(row.Key, true)
	end)
	paint(row.Key, false)
end

-- Roblox's own top-bar buttons (menu, chat, microphone ...) occupy the
-- top-left. GuiService.TopbarInset reports the rectangle the Roblox top bar
-- uses, and its Min.X is where those left-hand buttons end - so the gear sits
-- right after them, vertically centered on the bar, and follows when they
-- appear/disappear (microphone is absent on phones/tablets, chat can be off).
-- Fallback if the property is unavailable: a conservative fixed offset.
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

local function fit()
	local h = gui.AbsoluteSize.Y
	local s = math.clamp(h / 500, 0.6, 1)
	local x, barHeight = nil, 58
	local ok, inset = pcall(function()
		return GuiService.TopbarInset
	end)
	if ok and typeof(inset) == "Rect" and inset.Min.X > 0 then
		x = inset.Min.X + 8
		barHeight = inset.Height
	else
		x = 64 + 56 + 56 + 28
	end
	local size = math.clamp(barHeight - 14, 30, 44)
	gear.AnchorPoint = Vector2.new(0, 0.5)
	gear.Size = UDim2.fromOffset(size, size)
	-- Roblox's top-bar buttons are 44 px with a 12 px top margin, i.e. centered
	-- 34 px down in a 58 px bar - not at the bar's middle
	local cy = math.max(barHeight / 2, barHeight - 24)
	gear.Position = UDim2.fromOffset(x, cy)
	tutorialButton.AnchorPoint = Vector2.new(0, 0.5)
	tutorialButton.Size = UDim2.fromOffset(math.floor(size * 2.4), size)
	tutorialButton.TextSize = math.clamp(math.floor(size * 0.38), 11, 17)
	tutorialButton.Position = UDim2.fromOffset(x + size + 8, cy)
	panelScale.Scale = s
	panel.Position = UDim2.fromOffset(x, cy + size / 2 + 6)
end

pcall(function()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit)
end)
pcall(function()
	StarterGui.CoreGuiChangedSignal:Connect(function()
		task.defer(fit)
	end)
end)gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local open = false
gear.Activated:Connect(function()
	open = not open
	panel.Visible = open
end)

--------------------------------------------------
-- SFX: every non-music sound is silenced while SFX is off
--------------------------------------------------

local sfxBase = setmetatable({}, { __mode = "k" }) -- [sound] = volume before muting
local sfxConns = setmetatable({}, { __mode = "k" })

local function isMusic(sound)
	local group = sound.SoundGroup
	return (group and group.Name == "Music") or sound:FindFirstAncestor("Music") ~= nil
end

local function muteSound(sound)
	if isMusic(sound) then
		return
	end
	if not sfxConns[sound] then
		sfxConns[sound] = sound.Played:Connect(function()
			if not value("SettingSfx") then
				sound:Stop()
			end
		end)
	end
	if not value("SettingSfx") then
		if sfxBase[sound] == nil then
			sfxBase[sound] = sound.Volume
		end
		sound.Volume = 0
		if sound.Playing then
			sound:Stop()
		end
	elseif sfxBase[sound] ~= nil then
		sound.Volume = sfxBase[sound]
		sfxBase[sound] = nil
	end
end

local function watchSounds(root)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Sound") then
			muteSound(d)
		end
	end
	root.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") then
			task.defer(muteSound, d)
		end
	end)
end
watchSounds(workspace)
watchSounds(playerGui)
watchSounds(SoundService)
watchSounds(player:WaitForChild("Backpack"))

player:GetAttributeChangedSignal("SettingSfx"):Connect(function()
	for _, root in ipairs({ workspace, playerGui, SoundService }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Sound") then
				muteSound(d)
			end
		end
	end
end)

--------------------------------------------------
-- LOW GRAPHICS: no post effects / shadows / particles / trails
--------------------------------------------------

local gfxBase = setmetatable({}, { __mode = "k" }) -- [instance] = original Enabled
local shadowsBase = Lighting.GlobalShadows
local EFFECT_CLASSES = {
	BloomEffect = true, BlurEffect = true, DepthOfFieldEffect = true, SunRaysEffect = true,
	ColorCorrectionEffect = false, ParticleEmitter = true, Trail = true, Beam = true,
	Smoke = true, Fire = true, Sparkles = true,
}

local function applyGfx(inst)
	if not EFFECT_CLASSES[inst.ClassName] then
		return
	end
	if value("SettingLowGfx") then
		if gfxBase[inst] == nil then
			gfxBase[inst] = inst.Enabled
		end
		inst.Enabled = false
	elseif gfxBase[inst] ~= nil then
		inst.Enabled = gfxBase[inst]
		gfxBase[inst] = nil
	end
end

local function applyAllGfx()
	local low = value("SettingLowGfx")
	if low then
		shadowsBase = Lighting.GlobalShadows
		Lighting.GlobalShadows = false
	else
		Lighting.GlobalShadows = shadowsBase
	end
	for _, root in ipairs({ workspace, Lighting, workspace.CurrentCamera }) do
		if root then
			for _, d in ipairs(root:GetDescendants()) do
				applyGfx(d)
			end
		end
	end
	if workspace.CurrentCamera then
		for _, d in ipairs(workspace.CurrentCamera:GetChildren()) do
			applyGfx(d)
		end
	end
end

local function watchGfx(root)
	root.DescendantAdded:Connect(function(d)
		if value("SettingLowGfx") then
			task.defer(applyGfx, d)
		end
	end)
end
watchGfx(workspace)
watchGfx(Lighting)

player:GetAttributeChangedSignal("SettingLowGfx"):Connect(applyAllGfx)
if value("SettingLowGfx") then
	applyAllGfx()
end