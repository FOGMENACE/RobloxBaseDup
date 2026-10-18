-- RebirthUIClient
-- Client-side UI only. The server stays authoritative: it checks the level
-- requirement, resets XP / level and applies the new multipliers.
--
-- Layout (top to bottom): title, progress card (level x / y with a percent
-- bar), rewards card (multipliers NOW -> AFTER rebirth), the REBIRTH button
-- and a status line. The hub's REBIRTH button toggles the panel through
-- the client-only BindableEvent "ToggleRebirthPanel".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RebirthBonuses = require(ReplicatedStorage:WaitForChild("RebirthBonuses"))
local PanelManager = require(ReplicatedStorage:WaitForChild("PanelManager"))
local Shine = require(ReplicatedStorage:WaitForChild("Shine"))
local UiAssets = require(ReplicatedStorage:WaitForChild("UiAssets"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local GREEN = Color3.fromRGB(88, 196, 110)
local GREY = Color3.fromRGB(110, 110, 130)
local RED = Color3.fromRGB(235, 70, 70)
local GOLD = Color3.fromRGB(255, 226, 90)
local FONT = Enum.Font.FredokaOne

--------------------------------------------------
-- REMOTE
--------------------------------------------------

local rebirthSystem = ReplicatedStorage:WaitForChild("RebirthSystem")
local rebirthRemote = rebirthSystem:WaitForChild("RebirthRemote", 15)

if not rebirthRemote or not rebirthRemote:IsA("RemoteEvent") then
	error("[RebirthUIClient] RebirthRemote is missing or is not a RemoteEvent.")
end

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function round(inst, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end

local function stroke(inst, thickness, color)
	create("UIStroke", { Color = color or INK, Thickness = thickness }, inst)
end

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.Font = FONT
	local strokeThickness = props.StrokeThickness or 2.5
	props.StrokeThickness = nil
	local textLabel = create("TextLabel", props, parent)
	if strokeThickness > 0 then
		stroke(textLabel, strokeThickness)
	end
	return textLabel
end

local function formatNumber(value)
	local text = tostring(math.floor(value))
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

--------------------------------------------------
-- ROOT
--------------------------------------------------

local old = playerGui:FindFirstChild("RebirthUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "RebirthUI",
	ResetOnSpawn = false,
	DisplayOrder = 20,
}, playerGui)

local panel = create("Frame", {
	Name = "MainPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(470, 590),
	BackgroundColor3 = Color3.fromRGB(46, 36, 96),
	Visible = false,
}, gui)
round(panel, 22)
stroke(panel, 5)

local panelScale = create("UIScale", { Scale = 1 }, panel)

local function fit()
	local viewport = gui.AbsoluteSize
	panelScale.Scale = math.clamp(math.min(viewport.X / 520, viewport.Y / 660), 0.5, 1.1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

--------------------------------------------------
-- TITLE
--------------------------------------------------

label({
	Position = UDim2.fromOffset(18, 10),
	Size = UDim2.new(1, -80, 0, 40),
	Text = "REBIRTH",
	TextColor3 = GOLD,
	TextSize = 32,
	TextXAlignment = Enum.TextXAlignment.Left,
}, panel)

label({
	Position = UDim2.fromOffset(18, 48),
	Size = UDim2.new(1, -36, 0, 20),
	Text = "Reset your level for permanent bonuses.",
	TextColor3 = CREAM,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
	StrokeThickness = 2,
}, panel)

local closeButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = RED,
	Font = FONT,
	Text = "X",
	TextColor3 = CREAM,
	TextSize = 18,
}, panel)
round(closeButton, 10)
stroke(closeButton, 3)

--------------------------------------------------
-- PROGRESS CARD
--------------------------------------------------

local progressCard = create("Frame", {
	Position = UDim2.fromOffset(18, 82),
	Size = UDim2.new(1, -36, 0, 128),
	BackgroundColor3 = Color3.fromRGB(30, 24, 66),
}, panel)
round(progressCard, 16)

local levelLabel = label({
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -32, 0, 40),
	Text = "LEVEL 1 / 65",
	TextColor3 = CREAM,
	TextSize = 30,
	TextXAlignment = Enum.TextXAlignment.Left,
}, progressCard)

local barTrack = create("Frame", {
	Position = UDim2.fromOffset(16, 56),
	Size = UDim2.new(1, -32, 0, 30),
	BackgroundColor3 = Color3.fromRGB(70, 66, 100),
}, progressCard)
round(barTrack, 15)
stroke(barTrack, 3)

local barFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = GREEN,
}, barTrack)
round(barFill, 15)

local percentLabel = label({
	Size = UDim2.fromScale(1, 1),
	Text = "0%",
	TextColor3 = CREAM,
	TextSize = 18,
	ZIndex = 3,
}, barTrack)

local hintLabel = label({
	Position = UDim2.fromOffset(16, 94),
	Size = UDim2.new(1, -32, 0, 24),
	Text = "",
	TextColor3 = Color3.fromRGB(200, 190, 235),
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	StrokeThickness = 2,
}, progressCard)

--------------------------------------------------
-- REWARDS CARD (NOW -> AFTER)
--------------------------------------------------

local rewardCard = create("Frame", {
	Position = UDim2.fromOffset(18, 222),
	Size = UDim2.new(1, -36, 0, 168),
	BackgroundColor3 = Color3.fromRGB(30, 24, 66),
}, panel)
round(rewardCard, 16)

local function column(x, title, tint)
	local holder = create("Frame", {
		Position = UDim2.fromOffset(x, 10),
		Size = UDim2.fromOffset(160, 148),
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.82,
	}, rewardCard)
	round(holder, 14)

	-- header pill
	local header = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(136, 26),
		BackgroundColor3 = tint,
		BackgroundTransparency = 0.25,
	}, holder)
	round(header, 13)
	label({
		Size = UDim2.fromScale(1, 1),
		Text = title,
		TextColor3 = CREAM,
		TextSize = 15,
		StrokeThickness = 2.5,
	}, header)

	-- row 1: OIL BARREL icon, then its multiplier on the right
	local oilIcon = label({
		Position = UDim2.fromOffset(8, 42),
		Size = UDim2.fromOffset(56, 48),
		Text = "🛢️",
		TextColor3 = INK,
		TextSize = 42,
		StrokeThickness = 0,
	}, holder)
	local oilText = label({
		Position = UDim2.fromOffset(66, 42),
		Size = UDim2.fromOffset(88, 48),
		Text = "x1",
		TextColor3 = Color3.fromRGB(205, 175, 255),
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
	}, holder)

	-- row 2 (under it): TROPHY icon, then the wins multiplier on the right
	local winsIcon = create("ImageLabel", {
		Position = UDim2.fromOffset(12, 94),
		Size = UDim2.fromOffset(46, 46),
		BackgroundTransparency = 1,
		Image = UiAssets.TrophyImage,
		ScaleType = Enum.ScaleType.Fit,
	}, holder)
	local winsText = label({
		Position = UDim2.fromOffset(66, 94),
		Size = UDim2.fromOffset(88, 46),
		Text = "x1",
		TextColor3 = Color3.fromRGB(255, 226, 120),
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = 3,
	}, holder)

	return winsText, oilText, winsIcon, oilIcon
end
local nowWins, nowOil, nowWinsIcon, nowOilIcon = column(14, "NOW", Color3.fromRGB(200, 200, 230))
local nextWins, nextOil, nextWinsIcon, nextOilIcon = column(260, "AFTER REBIRTH", GREEN)

label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 6),
	Size = UDim2.fromOffset(60, 60),
	Text = ">>",
	TextColor3 = GOLD,
	TextSize = 34,
}, rewardCard)

--------------------------------------------------
-- REBIRTH BUTTON + STATUS
--------------------------------------------------

local rebirthButton = create("TextButton", {
	Name = "RebirthNowButton",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 404),
	Size = UDim2.fromOffset(300, 62),
	BackgroundColor3 = GREY,
	Font = FONT,
	Text = "NOT READY YET",
	TextColor3 = CREAM,
	TextSize = 26,
	AutoButtonColor = false,
}, panel)
round(rebirthButton, 16)
stroke(rebirthButton, 4)
Shine.Attach(rebirthButton, { Offset = 0.5 })

-- During the tutorial the first rebirth is FREE: a gold tag hangs over the
-- button (TutorialStep 4, TutorialService).
local freeTag = create("TextLabel", {
	Name = "FreeTag",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, 398),
	Size = UDim2.fromOffset(170, 50),
	BackgroundColor3 = Color3.fromRGB(255, 205, 60),
	Font = FONT,
	Text = "FREE!",
	TextColor3 = Color3.fromRGB(30, 20, 60),
	TextSize = 36,
	Visible = false,
	ZIndex = 30,
}, panel)
round(freeTag, 14)

local freeTagScale = create("UIScale", { Scale = 1 }, freeTag)

local function refreshFreeTag()
	freeTag.Visible = player:GetAttribute("TutorialStep") == 4
end
player:GetAttributeChangedSignal("TutorialStep"):Connect(refreshFreeTag)
refreshFreeTag()
task.spawn(function()
	while true do
		task.wait()
		if freeTag.Visible then
			freeTagScale.Scale = 1 + math.sin(os.clock() * 6) * 0.07
		end
	end
end)

local statusLabel = label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 476),
	Size = UDim2.new(1, -30, 0, 28),
	Text = "",
	TextColor3 = CREAM,
	TextSize = 15,
	StrokeThickness = 2,
}, panel)


--------------------------------------------------
-- AUTO REBIRTH (free toggle) + SKIP REBIRTH (R$ 46)
--------------------------------------------------

local autoButton = create("TextButton", {
	Position = UDim2.fromOffset(18, 516),
	Size = UDim2.fromOffset(204, 50),
	BackgroundColor3 = RED,
	Font = FONT,
	Text = "AUTO REBIRTH: OFF",
	TextColor3 = CREAM,
	TextSize = 16,
	AutoButtonColor = false,
}, panel)
round(autoButton, 14)
stroke(autoButton, 3)

local skipButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 516),
	Size = UDim2.fromOffset(222, 50),
	BackgroundColor3 = Color3.fromRGB(235, 140, 60),
	Font = FONT,
	Text = "SKIP REBIRTH   46",
	TextColor3 = CREAM,
	TextSize = 16,
	AutoButtonColor = false,
}, panel)
round(skipButton, 14)
stroke(skipButton, 3)
Shine.Attach(skipButton, { Offset = 1.2 })

local function refreshAuto()
	local on = player:GetAttribute("AutoRebirth") == true
	autoButton.Text = on and "AUTO REBIRTH: ON" or "AUTO REBIRTH: OFF"
	autoButton.BackgroundColor3 = on and GREEN or RED
end

autoButton.Activated:Connect(function()
	local on = player:GetAttribute("AutoRebirth") == true
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AutoRebirthToggle"):FireServer(not on)
end)

skipButton.Activated:Connect(function()
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StorePrompt"):FireServer("RebirthSkip")
	statusLabel.Text = "Opening the skip purchase..."
	statusLabel.TextColor3 = GOLD
end)

player:GetAttributeChangedSignal("AutoRebirth"):Connect(refreshAuto)
--------------------------------------------------
-- OPEN / CLOSE
--------------------------------------------------

PanelManager.Register("Rebirth", panel, fit)

closeButton.Activated:Connect(function()
	PanelManager.Close("Rebirth")
end)

-- The hub (HubUI) owns the entry button and fires this event.
local oldToggle = playerGui:FindFirstChild("ToggleRebirthPanel")
if oldToggle then
	oldToggle:Destroy()
end

local toggleEvent = Instance.new("BindableEvent")
toggleEvent.Name = "ToggleRebirthPanel"
toggleEvent.Parent = playerGui

toggleEvent.Event:Connect(function()
	PanelManager.Toggle("Rebirth")
end)

--------------------------------------------------
-- READ SERVER ATTRIBUTES
--------------------------------------------------

local busy = false

local function refreshUI()
	local level = math.floor(player:GetAttribute("Level") or 1)
	local rebirths = player:GetAttribute("Rebirths") or 0
	local requirement = math.max(player:GetAttribute("RebirthLevelRequirement") or 2, 2)
	local levelProgress = player:GetAttribute("LevelProgress") or 0
	local canRebirth = player:GetAttribute("RebirthMaxReached") == true
	skipButton.Visible = not canRebirth

	-- Level 1 is the start (0%); the requirement level is 100%. Inside the
	-- current level the XP bar adds the fractional part.
	local fraction = (level - 1 + (level >= requirement and 0 or math.clamp(levelProgress, 0, 1))) / (requirement - 1)
	fraction = math.clamp(fraction, 0, 1)
	local percent = canRebirth and 100 or math.min(99, math.floor(fraction * 100))

	levelLabel.Text = "LEVEL " .. level .. " / " .. requirement
	percentLabel.Text = percent .. "%"
	hintLabel.Text = canRebirth and "You are ready to rebirth!"
		or ("Reach level " .. requirement .. " to rebirth.")

	TweenService:Create(
		barFill,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad),
		{ Size = UDim2.fromScale(canRebirth and 1 or fraction, 1) }
	):Play()

	-- multipliers now vs after the next rebirth (XP bonus is shown on the HUD pill)
	nowWins.Text = "x" .. formatNumber(RebirthBonuses.WinsMultiplier(rebirths))
	nowOil.Text = "x" .. formatNumber(RebirthBonuses.OilMultiplier(rebirths))
	nextWins.Text = "x" .. formatNumber(RebirthBonuses.WinsMultiplier(rebirths + 1))
	nextOil.Text = "x" .. formatNumber(RebirthBonuses.OilMultiplier(rebirths + 1))

	-- The wins multiplier is a surprise: it stays hidden until a rebirth that
	-- actually grants it (rebirth 2), then the rows appear.
	local showWins = RebirthBonuses.WinsMultiplier(rebirths + 1) > 1 or RebirthBonuses.WinsMultiplier(rebirths) > 1
	for _, object in ipairs({ nowWins, nextWins, nowWinsIcon, nextWinsIcon }) do
		object.Visible = showWins
	end

	if busy then
		rebirthButton.Text = "REBIRTHING..."
		rebirthButton.BackgroundColor3 = GREY
	elseif canRebirth then
		rebirthButton.Text = "REBIRTH NOW!"
		rebirthButton.BackgroundColor3 = GREEN
		if statusLabel.Text == "" or statusLabel.Text:find("grind") then
			statusLabel.Text = "Resets level and XP. You keep wins, balls and oil."
			statusLabel.TextColor3 = CREAM
		end
	else
		rebirthButton.Text = "NOT READY YET"
		rebirthButton.BackgroundColor3 = GREY
		statusLabel.Text = "Keep rolling - every level counts!"
		statusLabel.TextColor3 = Color3.fromRGB(200, 190, 235)
	end
end

for _, attribute in ipairs({ "Level", "Rebirths", "RebirthLevelRequirement", "LevelProgress", "RebirthMaxReached" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refreshUI)
end

--------------------------------------------------
-- REQUEST REBIRTH
--------------------------------------------------

rebirthButton.Activated:Connect(function()
	if busy then
		return
	end

	if player:GetAttribute("RebirthMaxReached") ~= true then
		statusLabel.Text = "Not ready yet - reach the level first."
		statusLabel.TextColor3 = RED
		return
	end

	busy = true
	refreshUI()
	statusLabel.Text = "Processing rebirth..."
	statusLabel.TextColor3 = GOLD

	-- never stay stuck: if no answer arrives, unlock the button after a few
	-- seconds (the rebirth count tells us whether it went through)
	local rebirthsBefore = player:GetAttribute("Rebirths") or 0
	task.delay(6, function()
		if busy then
			busy = false
			refreshUI()
			if (player:GetAttribute("Rebirths") or 0) > rebirthsBefore then
				statusLabel.Text = "REBIRTH COMPLETE!"
				statusLabel.TextColor3 = GREEN
			else
				statusLabel.Text = "No answer - try again."
				statusLabel.TextColor3 = RED
			end
		end
	end)

	local success, err = pcall(function()
		rebirthRemote:FireServer("Rebirth")
	end)

	if not success then
		busy = false
		refreshUI()
		statusLabel.Text = "Request failed - try again."
		statusLabel.TextColor3 = RED
		warn("[RebirthUIClient] FireServer failed:", err)
	end
end)

-- The server's answer is the only thing that says it worked.
rebirthRemote.OnClientEvent:Connect(function(message, success, reason)
	if message ~= "RebirthResult" then
		return
	end

	busy = false
	refreshUI()

	if success then
		statusLabel.Text = "REBIRTH COMPLETE!"
		statusLabel.TextColor3 = GREEN
	else
		statusLabel.Text = "Rebirth failed: " .. tostring(reason)
		statusLabel.TextColor3 = RED
		warn("[RebirthUIClient] Rebirth rejected:", reason)
	end
end)

refreshUI()
refreshAuto()
print("[RebirthUIClient] Rebirth UI loaded.")
