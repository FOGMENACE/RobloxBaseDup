--!strict
-- BRAINROT PROGRESSION UI
-- Client-only visual interface
-- Location: StarterPlayer > StarterPlayerScripts
-- Reads authoritative attributes from PlayerDataService.
-- Does not modify progression, currency, or save data.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--------------------------------------------------
-- CONFIG
--------------------------------------------------

local GUI_NAME = "ProgressionUI"

local COLORS = {
	Background = Color3.fromRGB(25, 20, 39),
	Pink = Color3.fromRGB(255, 64, 180),
	Cyan = Color3.fromRGB(48, 240, 255),
	Yellow = Color3.fromRGB(255, 225, 67),
	Green = Color3.fromRGB(83, 255, 130),
	White = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(180, 172, 200),
}

local FONT = Enum.Font.FredokaOne

local PANEL_WIDTH = 285
local PANEL_HEIGHT = 184
local EDGE_PADDING = 16

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function formatNumber(value: number): string
	value = math.max(0, math.floor(value))

	if value >= 1e12 then
		return string.format("%.2fT", value / 1e12)
	elseif value >= 1e9 then
		return string.format("%.2fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.2fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end

	return tostring(value)
end

local function create(
	className: string,
	properties: {[string]: any},
	parent: Instance
): Instance
	local instance = Instance.new(className)

	for property, value in pairs(properties) do
		(instance :: any)[property] = value
	end

	instance.Parent = parent
	return instance
end

local function addCorner(instance: Instance, radius: number)
	create("UICorner", {
		CornerRadius = UDim.new(0, radius),
	}, instance)
end

local function addStroke(
	instance: Instance,
	color: Color3,
	thickness: number
)
	create("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Transparency = 0.12,
	}, instance)
end

local function makeLabel(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2,
	color: Color3,
	textSize: number
): TextLabel
	return create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		Text = text,
		TextColor3 = color,
		TextSize = textSize,
		Font = FONT,
		TextScaled = false,
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent) :: TextLabel
end

local function getNumberAttribute(
	name: string,
	defaultValue: number
): number
	local value = player:GetAttribute(name)

	if typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge then
		return value
	end

	return defaultValue
end

--------------------------------------------------
-- CLEAN UP PREVIOUS VERSION
--------------------------------------------------

local oldGui = playerGui:FindFirstChild(GUI_NAME)

if oldGui then
	oldGui:Destroy()
end

--------------------------------------------------
-- SCREEN GUI
--------------------------------------------------

local screenGui = create("ScreenGui", {
	Name = GUI_NAME,
	ResetOnSpawn = false,
	IgnoreGuiInset = false,
	DisplayOrder = 10,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui

--------------------------------------------------
-- MAIN PANEL: BOTTOM RIGHT
--------------------------------------------------

local main = create("Frame", {
	Name = "ProgressionPanel",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(
		1, -EDGE_PADDING,
		1, -EDGE_PADDING
	),
	Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
	BackgroundColor3 = COLORS.Background,
	BackgroundTransparency = 0.06,
	BorderSizePixel = 0,
}, screenGui)

addCorner(main, 15)
addStroke(main, COLORS.Pink, 2)

create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(
			0,
			Color3.fromRGB(53, 31, 77)
		),
		ColorSequenceKeypoint.new(
			1,
			Color3.fromRGB(23, 22, 39)
		),
	}),
	Rotation = 35,
}, main)

--------------------------------------------------
-- HEADER
--------------------------------------------------

local header = makeLabel(
	main,
	"Header",
	"VIEW YOUR PROGRESS",
	UDim2.new(1, -20, 0, 25),
	UDim2.fromOffset(10, 5),
	COLORS.Yellow,
	17
)

header.TextXAlignment = Enum.TextXAlignment.Center

--------------------------------------------------
-- LEVEL / GLOBAL LEVEL
--------------------------------------------------

local levelLabel = makeLabel(
	main,
	"LevelLabel",
	"LEVEL 1",
	UDim2.new(0.5, -10, 0, 26),
	UDim2.fromOffset(10, 31),
	COLORS.White,
	17
)

local globalLabel = makeLabel(
	main,
	"GlobalLevelLabel",
	"GLOBAL 1",
	UDim2.new(0.5, -10, 0, 26),
	UDim2.new(0.5, 0, 0, 31),
	COLORS.Cyan,
	15
)

--------------------------------------------------
-- XP BAR
--------------------------------------------------

local xpBackground = create("Frame", {
	Name = "XPBackground",
	Position = UDim2.fromOffset(12, 61),
	Size = UDim2.new(1, -24, 0, 24),
	BackgroundColor3 = Color3.fromRGB(14, 12, 23),
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, main)

addCorner(xpBackground, 8)
addStroke(xpBackground, COLORS.Cyan, 1)

local xpFill = create("Frame", {
	Name = "XPFill",
	Size = UDim2.new(0, 0, 1, 0),
	BackgroundColor3 = COLORS.Green,
	BorderSizePixel = 0,
}, xpBackground)

addCorner(xpFill, 8)

create("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.Cyan),
		ColorSequenceKeypoint.new(1, COLORS.Pink),
	}),
}, xpFill)

local xpText = makeLabel(
	xpBackground,
	"XPText",
	"0 / 100 XP",
	UDim2.fromScale(1, 1),
	UDim2.fromScale(0, 0),
	COLORS.White,
	12
)

xpText.TextXAlignment = Enum.TextXAlignment.Center
xpText.ZIndex = 3

--------------------------------------------------
-- STATUS
--------------------------------------------------

local statusLabel = makeLabel(
	main,
	"StatusLabel",
	"TOTAL XP: 0",
	UDim2.new(1, -20, 0, 20),
	UDim2.fromOffset(10, 88),
	COLORS.Green,
	12
)

statusLabel.TextXAlignment = Enum.TextXAlignment.Center

--------------------------------------------------
-- REBIRTHS / TARGET
--------------------------------------------------

local rebirthLabel = makeLabel(
	main,
	"RebirthLabel",
	"REBIRTHS: 0",
	UDim2.new(0.55, -10, 0, 23),
	UDim2.fromOffset(10, 112),
	COLORS.Pink,
	13
)

local targetLabel = makeLabel(
	main,
	"TargetLabel",
	"TARGET: 65",
	UDim2.new(0.45, -10, 0, 23),
	UDim2.new(0.55, 0, 0, 112),
	COLORS.Yellow,
	12
)

--------------------------------------------------
-- FOOTER
--------------------------------------------------

local footer = makeLabel(
	main,
	"Footer",
	"KEEP GRINDING",
	UDim2.new(1, -20, 0, 18),
	UDim2.fromOffset(10, 151),
	COLORS.Muted,
	10
)

footer.TextXAlignment = Enum.TextXAlignment.Center

--------------------------------------------------
-- XP ANIMATION
--------------------------------------------------

local currentTween: Tween? = nil

local function updateUI()
	local level = getNumberAttribute("Level", 1)
	local globalLevel = getNumberAttribute("GlobalLevel", 1)
	local rebirths = getNumberAttribute("Rebirths", 0)

	local xp = getNumberAttribute("XP", 0)
	local intoLevel = getNumberAttribute("XPIntoLevel", 0)
	local needed = getNumberAttribute("XPNeededForLevel", 100)

	local requirement = getNumberAttribute(
		"RebirthLevelRequirement",
		65
	)

	local maxReached =
		player:GetAttribute("RebirthMaxReached") == true

	levelLabel.Text = "LEVEL " .. formatNumber(level)
	globalLabel.Text = "GLOBAL " .. formatNumber(globalLevel)

	rebirthLabel.Text =
		"REBIRTHS: " .. formatNumber(rebirths)

	targetLabel.Text =
		"TARGET: " .. formatNumber(requirement)

	if maxReached then
		xpText.Text = "MAX LEVEL REACHED"
		statusLabel.Text = "READY TO REBIRTH!"
		statusLabel.TextColor3 = COLORS.Yellow
		footer.Text = "YOUR NEXT JOURNEY AWAITS"
		footer.TextColor3 = COLORS.Pink
	else
		xpText.Text =
			formatNumber(intoLevel)
			.. " / "
			.. formatNumber(needed)
			.. " XP"

		statusLabel.Text = "TOTAL XP: " .. formatNumber(xp)
		statusLabel.TextColor3 = COLORS.Green
		footer.Text = "KEEP GRINDING"
		footer.TextColor3 = COLORS.Muted
	end

	local progress = 0

	if maxReached then
		progress = 1
	elseif needed > 0 then
		progress = math.clamp(intoLevel / needed, 0, 1)
	end

	if currentTween then
		currentTween:Cancel()
	end

	currentTween = TweenService:Create(
		xpFill,
		TweenInfo.new(
			0.25,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{
			Size = UDim2.new(progress, 0, 1, 0),
		}
	)

	currentTween:Play()
end

--------------------------------------------------
-- LIVE ATTRIBUTE UPDATES
--------------------------------------------------

local watchedAttributes = {
	"Level",
	"GlobalLevel",
	"Rebirths",
	"XP",
	"XPIntoLevel",
	"XPNeededForLevel",
	"RebirthLevelRequirement",
	"RebirthMaxReached",
}

for _, attributeName in ipairs(watchedAttributes) do
	player:GetAttributeChangedSignal(attributeName):Connect(updateUI)
end

updateUI()

print("[ProgressionUI] Compact bottom-right UI loaded.")