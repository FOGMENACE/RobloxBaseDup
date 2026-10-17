--!strict
-- RebirthUIClient
-- Location: StarterPlayer > StarterPlayerScripts
-- Client-side UI. Server remains authoritative for rebirths.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RebirthBonuses = require(ReplicatedStorage:WaitForChild("RebirthBonuses"))
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------
-- CONFIGURATION
--------------------------------------------------

local COLORS = {
	Background = Color3.fromRGB(28, 20, 48),
	Panel = Color3.fromRGB(47, 33, 76),
	Pink = Color3.fromRGB(255, 65, 173),
	Purple = Color3.fromRGB(151, 79, 255),
	Cyan = Color3.fromRGB(53, 235, 255),
	Yellow = Color3.fromRGB(255, 220, 65),
	Green = Color3.fromRGB(75, 255, 135),
	White = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(190, 180, 215),
	Red = Color3.fromRGB(255, 85, 100),
}

local FONT = Enum.Font.GothamBlack

--------------------------------------------------
-- REMOTE EVENT
--------------------------------------------------

local rebirthSystem = ReplicatedStorage:WaitForChild("RebirthSystem")
local rebirthRemote = rebirthSystem:WaitForChild("RebirthRemote", 15)

if not rebirthRemote or not rebirthRemote:IsA("RemoteEvent") then
	error("[RebirthUIClient] RebirthRemote is missing or is not a RemoteEvent.")
end

--------------------------------------------------
-- CLEAN UP OLD UI
--------------------------------------------------

local oldUI = playerGui:FindFirstChild("RebirthUI")

if oldUI then
	oldUI:Destroy()
end

--------------------------------------------------
-- UI HELPERS
--------------------------------------------------

local function make(className, properties, parent)
	local object = Instance.new(className)

	for property, value in pairs(properties) do
		object[property] = value
	end

	object.Parent = parent
	return object
end

local function corner(parent, radius)
	make("UICorner", {
		CornerRadius = UDim.new(0, radius),
	}, parent)
end

local function stroke(parent, color, thickness)
	return make("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function label(parent, name, text, size, position)
	return make("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Text = text,
		TextColor3 = COLORS.White,
		TextScaled = true,
		Font = FONT,
	}, parent)
end

--------------------------------------------------
-- SCREEN GUI
--------------------------------------------------

local screen = make("ScreenGui", {
	Name = "RebirthUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

--------------------------------------------------
-- OPEN BUTTON
--------------------------------------------------

local openButton = make("TextButton", {
	Name = "OpenRebirth",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 18, 0.5, 0),
	Size = UDim2.fromOffset(150, 54),
	BackgroundColor3 = COLORS.Pink,
	Text = "♻ REBIRTH",
	TextColor3 = COLORS.White,
	TextScaled = true,
	Font = FONT,
	AutoButtonColor = false,
}, screen)

corner(openButton, 16)
stroke(openButton, COLORS.Yellow, 3)

--------------------------------------------------
-- MAIN PANEL
--------------------------------------------------

local panel = make("Frame", {
	Name = "MainPanel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.42, 0.56),
	BackgroundColor3 = COLORS.Background,
	Visible = false,
}, screen)

panel.Size = UDim2.new(
	0.42, 0,
	0, 420
)

make("UISizeConstraint", {
	MinSize = Vector2.new(310, 390),
	MaxSize = Vector2.new(560, 500),
}, panel)

corner(panel, 24)
stroke(panel, COLORS.Purple, 4)

--------------------------------------------------
-- HEADER
--------------------------------------------------

local header = make("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 74),
	BackgroundColor3 = COLORS.Purple,
}, panel)

corner(header, 20)

label(
	header,
	"Title",
	"REBIRTH?! 💀",
	UDim2.new(1, -70, 0, 38),
	UDim2.fromOffset(12, 7)
)

label(
	header,
	"Subtitle",
	"RESET THE GRIND. GET STRONGER.",
	UDim2.new(1, -20, 0, 19),
	UDim2.new(0, 10, 0, 47)
)

local closeButton = make("TextButton", {
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 8),
	Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = COLORS.Red,
	Text = "X",
	TextColor3 = COLORS.White,
	TextScaled = true,
	Font = FONT,
}, header)

corner(closeButton, 10)

--------------------------------------------------
-- LEVEL INFORMATION
--------------------------------------------------

label(
	panel,
	"RebirthLevelTitle",
	"YOUR REBIRTH LEVEL",
	UDim2.new(1, -32, 0, 24),
	UDim2.fromOffset(16, 88)
)

local levelLabel = label(
	panel,
	"Level",
	"LEVEL 1",
	UDim2.new(1, -32, 0, 44),
	UDim2.fromOffset(16, 116)
)

levelLabel.TextColor3 = COLORS.Cyan

local requirementLabel = label(
	panel,
	"Requirement",
	"REACH LEVEL 65",
	UDim2.new(1, -32, 0, 28),
	UDim2.fromOffset(16, 162)
)

requirementLabel.TextColor3 = COLORS.Yellow

--------------------------------------------------
-- PROGRESS BAR
--------------------------------------------------

local barBackground = make("Frame", {
	Name = "ProgressBackground",
	Position = UDim2.fromOffset(22, 202),
	Size = UDim2.new(1, -44, 0, 26),
	BackgroundColor3 = Color3.fromRGB(67, 56, 88),
	ClipsDescendants = true,
}, panel)

corner(barBackground, 12)

local barFill = make("Frame", {
	Name = "ProgressFill",
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = COLORS.Green,
}, barBackground)

corner(barFill, 12)

local progressLabel = label(
	barBackground,
	"ProgressText",
	"0%",
	UDim2.fromScale(1, 1),
	UDim2.fromScale(0, 0)
)

progressLabel.ZIndex = 3

--------------------------------------------------
-- GLOBAL LEVEL AND REBIRTH COUNT
--------------------------------------------------

local statsLabel = label(
	panel,
	"Stats",
	"GLOBAL LEVEL 1  |  REBIRTHS 0",
	UDim2.new(1, -30, 0, 28),
	UDim2.fromOffset(15, 241)
)

statsLabel.TextColor3 = COLORS.White

local rewardLabel = label(
	panel,
	"Reward",
	"NEXT GOAL: +15 LEVELS",
	UDim2.new(1, -30, 0, 25),
	UDim2.fromOffset(15, 273)
)

rewardLabel.TextColor3 = COLORS.Pink

--------------------------------------------------
-- REBIRTH BUTTON
--------------------------------------------------

local rebirthButton = make("TextButton", {
	Name = "RebirthButton",
	Position = UDim2.new(0, 22, 0, 313),
	Size = UDim2.new(1, -44, 0, 62),
	BackgroundColor3 = COLORS.Green,
	Text = "REBIRTH NOW 🔥",
	TextColor3 = COLORS.Background,
	TextScaled = true,
	Font = FONT,
	AutoButtonColor = false,
}, panel)

corner(rebirthButton, 18)
stroke(rebirthButton, COLORS.White, 2)

local statusLabel = label(
	panel,
	"Status",
	"KEEP GRINDING 💪",
	UDim2.new(1, -30, 0, 24),
	UDim2.fromOffset(15, 378)
)

statusLabel.TextColor3 = COLORS.Muted

--------------------------------------------------
-- UI OPEN / CLOSE
--------------------------------------------------

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

-- The hub (HubUI) now owns the entry button. It fires this client-only
-- BindableEvent to toggle the panel; the old floating button is hidden.
openButton.Visible = false

local oldToggle = playerGui:FindFirstChild("ToggleRebirthPanel")
if oldToggle then
	oldToggle:Destroy()
end

local toggleEvent = Instance.new("BindableEvent")
toggleEvent.Name = "ToggleRebirthPanel"
toggleEvent.Parent = playerGui

toggleEvent.Event:Connect(function()
	panel.Visible = not panel.Visible
end)

closeButton.Activated:Connect(function()
	panel.Visible = false
end)

--------------------------------------------------
-- READ SERVER-AUTHORITATIVE ATTRIBUTES
--------------------------------------------------

local busy = false

local function refreshUI()
	local level = player:GetAttribute("Level") or 1
	local globalLevel = player:GetAttribute("GlobalLevel") or 1
	local rebirths = player:GetAttribute("Rebirths") or 0

	local requirement =
		player:GetAttribute("RebirthLevelRequirement") or 65

	local progress =
		player:GetAttribute("LevelProgress") or 0

	local canRebirth =
		player:GetAttribute("RebirthMaxReached") == true

	levelLabel.Text = "LEVEL " .. tostring(level)

	requirementLabel.Text =
		"REACH LEVEL " .. tostring(requirement) .. "  -  " .. tostring(math.floor(math.clamp(progress, 0, 1) * 100)) .. "% DONE"

	statsLabel.Text =
		"GLOBAL LEVEL " .. tostring(globalLevel)
		.. "  |  REBIRTHS " .. tostring(rebirths)

	rewardLabel.Text =
		"NEXT REBIRTH: OIL x" .. tostring(RebirthBonuses.OilMultiplier(rebirths + 1)) .. "  WINS x" .. tostring(RebirthBonuses.WinsMultiplier(rebirths + 1)) .. "  XP x" .. tostring(RebirthBonuses.XPMultiplier(rebirths + 1))

	progress = math.clamp(progress, 0, 1)

	progressLabel.Text =
		tostring(math.floor(progress * 100)) .. "%"

	TweenService:Create(
		barFill,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad),
		{
			Size = UDim2.fromScale(progress, 1),
		}
	):Play()

	if busy then
		rebirthButton.Text = "REBIRTHING..."
		rebirthButton.BackgroundColor3 = COLORS.Muted
		rebirthButton.Active = false
	elseif canRebirth then
		rebirthButton.Text = "REBIRTH NOW 🔥"
		rebirthButton.BackgroundColor3 = COLORS.Green
		rebirthButton.Active = true
		statusLabel.Text = "YOU'RE READY! 🤑"
		statusLabel.TextColor3 = COLORS.Green
	else
		rebirthButton.Text = "NOT READY YET 💀"
		rebirthButton.BackgroundColor3 = COLORS.Muted
		rebirthButton.Active = false
		statusLabel.Text = "KEEP GRINDING 💪"
		statusLabel.TextColor3 = COLORS.Muted
	end
end

--------------------------------------------------
-- LIVE ATTRIBUTE UPDATES
--------------------------------------------------

local attributes = {
	"Level",
	"GlobalLevel",
	"Rebirths",
	"RebirthLevelRequirement",
	"LevelProgress",
	"RebirthMaxReached",
}

for _, attribute in ipairs(attributes) do
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
		statusLabel.Text = "NOT READY YET 💀"
		statusLabel.TextColor3 = COLORS.Red
		return
	end

	busy = true
	refreshUI()

	statusLabel.Text = "PROCESSING REBIRTH..."
	statusLabel.TextColor3 = COLORS.Yellow

	-- Match the existing server's expected action.
	local success, err = pcall(function()
		rebirthRemote:FireServer("Rebirth")
	end)

	if not success then
		busy = false
		refreshUI()

		statusLabel.Text = "REQUEST FAILED! TRY AGAIN"
		statusLabel.TextColor3 = COLORS.Red

		warn("[RebirthUIClient] FireServer failed:", err)
	end
end)

--------------------------------------------------
-- SERVER RESULT
--------------------------------------------------

rebirthRemote.OnClientEvent:Connect(function(message, success, reason)
	if message ~= "RebirthResult" then
		return
	end

	busy = false
	refreshUI()

	if success then
		statusLabel.Text = "REBIRTH COMPLETE! 🔥"
		statusLabel.TextColor3 = COLORS.Green

		print("[RebirthUIClient] Rebirth successful:", reason)
	else
		statusLabel.Text = "REBIRTH FAILED: " .. tostring(reason)
		statusLabel.TextColor3 = COLORS.Red

		warn("[RebirthUIClient] Rebirth rejected:", reason)
	end
end)

--------------------------------------------------
-- BUTTON ANIMATION
--------------------------------------------------

local pulseTween = TweenService:Create(
	openButton,
	TweenInfo.new(
		0.8,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true
	),
	{
		Size = UDim2.fromOffset(158, 58),
	}
)

pulseTween:Play()

--------------------------------------------------
-- INITIALIZE
--------------------------------------------------

refreshUI()

print("[RebirthUIClient] Rebirth UI loaded.")