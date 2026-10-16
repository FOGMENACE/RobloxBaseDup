--------------------------------------------------
-- XP GENERATOR CONTROLLER
--
-- LOCATION:
-- ServerScriptService
--
-- PURPOSE:
-- Creates clean floating generator labels in code.
-- Does not award XP or process purchases.
--------------------------------------------------

local Workspace = game:GetService("Workspace")

--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local generatorsFolder = Workspace:WaitForChild("XPGenerators")

assert(
	generatorsFolder:IsA("Model"),
	"[XPGeneratorController] XPGenerators must be a Model."
)

--------------------------------------------------
-- UI SETTINGS
--------------------------------------------------

local GUI_NAME = "GeneratorFloatingUI"

local GUI_WIDTH = 230
local GUI_HEIGHT = 72

local MAX_DISTANCE = 120

--------------------------------------------------
-- GENERATOR CONFIGURATION
--------------------------------------------------

local generatorInfo = {
	GenX1 = {
		Top = "NO REBIRTH",
		Bottom = "X1",
		Color = Color3.fromRGB(90, 255, 155),
	},

	GenX2 = {
		Top = "REBIRTH 2 REQUIRED",
		Bottom = "X2",
		Color = Color3.fromRGB(90, 210, 255),
	},

	GenX4 = {
		Top = "REBIRTH 4 REQUIRED",
		Bottom = "X4",
		Color = Color3.fromRGB(155, 115, 255),
	},

	GenX6 = {
		Top = "LIMITED-TIME GIFT",
		Bottom = "X6",
		Color = Color3.fromRGB(255, 205, 75),
	},

	GenX8 = {
		Top = "REBIRTH 8 REQUIRED",
		Bottom = "X8",
		Color = Color3.fromRGB(255, 125, 190),
	},

	GenX10 = {
		Top = "REBIRTH 10 REQUIRED",
		Bottom = "X10",
		Color = Color3.fromRGB(255, 100, 100),
	},

	["GenX100 Admin XP"] = {
		Top = "ADMIN XP • ROBUX",
		Bottom = "100X XP",
		Color = Color3.fromRGB(255, 190, 65),
	},

	["GenX1000 Admin XP"] = {
		Top = "ADMIN XP • ROBUX",
		Bottom = "1000X XP",
		Color = Color3.fromRGB(255, 90, 90),
	},
}

--------------------------------------------------
-- CREATE FLOATING UI
--------------------------------------------------

local function createGeneratorUI(part)
	if not part:IsA("BasePart") then
		return
	end

	local info = generatorInfo[part.Name]

	if not info then
		warn(
			"[XPGeneratorController] No configuration for:",
			part:GetFullName()
		)
		return
	end

	-- Avoid duplicate interfaces.
	local existing = part:FindFirstChild(GUI_NAME)

	if existing then
		existing:Destroy()
	end

	--------------------------------------------------
	-- BILLBOARD
	--------------------------------------------------

	local billboard = Instance.new("BillboardGui")
	billboard.Name = GUI_NAME
	billboard.Adornee = part
	billboard.Size = UDim2.fromOffset(
		GUI_WIDTH,
		GUI_HEIGHT
	)

	-- Position above the actual MeshPart.
	billboard.StudsOffsetWorldSpace = Vector3.new(
		0,
		part.Size.Y / 2 + 2.3,
		0
	)

	billboard.AlwaysOnTop = false
	billboard.MaxDistance = MAX_DISTANCE
	billboard.LightInfluence = 0
	billboard.Enabled = true
	billboard.Parent = part

	--------------------------------------------------
	-- BACKGROUND
	--------------------------------------------------

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
	background.BackgroundTransparency = 0.12
	background.BorderSizePixel = 0
	background.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = background

	local outline = Instance.new("UIStroke")
	outline.Color = info.Color
	outline.Thickness = 1.5
	outline.Transparency = 0.12
	outline.Parent = background

	--------------------------------------------------
	-- TOP LABEL
	--------------------------------------------------

	local requirement = Instance.new("TextLabel")
	requirement.Name = "Requirement"
	requirement.BackgroundTransparency = 1
	requirement.Position = UDim2.new(0, 7, 0, 5)
	requirement.Size = UDim2.new(1, -14, 0, 21)

	requirement.Font = Enum.Font.GothamBold
	requirement.Text = info.Top
	requirement.TextColor3 = Color3.fromRGB(245, 245, 255)
	requirement.TextScaled = true
	requirement.TextWrapped = false
	requirement.TextXAlignment = Enum.TextXAlignment.Center
	requirement.TextYAlignment = Enum.TextYAlignment.Center

	requirement.Parent = background

	local requirementLimit = Instance.new("UITextSizeConstraint")
	requirementLimit.MinTextSize = 10
	requirementLimit.MaxTextSize = 15
	requirementLimit.Parent = requirement

	--------------------------------------------------
	-- MULTIPLIER LABEL
	--------------------------------------------------

	local multiplier = Instance.new("TextLabel")
	multiplier.Name = "Multiplier"
	multiplier.BackgroundTransparency = 1
	multiplier.Position = UDim2.new(0, 6, 0, 25)
	multiplier.Size = UDim2.new(1, -12, 0, 39)

	multiplier.Font = Enum.Font.GothamBlack
	multiplier.Text = info.Bottom
	multiplier.TextColor3 = info.Color
	multiplier.TextScaled = true
	multiplier.TextXAlignment = Enum.TextXAlignment.Center
	multiplier.TextYAlignment = Enum.TextYAlignment.Center

	multiplier.Parent = background

	local multiplierLimit = Instance.new("UITextSizeConstraint")
	multiplierLimit.MinTextSize = 20
	multiplierLimit.MaxTextSize = 32
	multiplierLimit.Parent = multiplier

	local textOutline = Instance.new("UIStroke")
	textOutline.Color = Color3.fromRGB(0, 0, 0)
	textOutline.Thickness = 1
	textOutline.Transparency = 0.4
	textOutline.Parent = multiplier

	print(
		"[XPGeneratorController] UI created:",
		part.Name
	)
end

--------------------------------------------------
-- INITIAL GENERATORS
--------------------------------------------------

for _, instance in ipairs(generatorsFolder:GetDescendants()) do
	createGeneratorUI(instance)
end

--------------------------------------------------
-- GENERATORS ADDED LATER
--------------------------------------------------

generatorsFolder.DescendantAdded:Connect(function(instance)
	task.defer(function()
		if instance:IsDescendantOf(generatorsFolder) then
			createGeneratorUI(instance)
		end
	end)
end)

--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("[XPGeneratorController] Floating generator UI ready.")