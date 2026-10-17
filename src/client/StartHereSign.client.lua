--------------------------------------------------
-- START HERE SIGN
--
-- CLIENT ONLY, visual. Makes the StartWall invisible (locally; the wall
-- itself and its Touched logic are untouched) and hangs an animated
-- "START HERE" sign with a bobbing down arrow in the lane opening.
--------------------------------------------------

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local LANE = Color3.fromRGB(240, 178, 82)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local FONT = Enum.Font.FredokaOne

local startWall = workspace:WaitForChild("StartWall")

-- Fully transparent for this player only.
startWall.LocalTransparencyModifier = 1
startWall:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
	if startWall.LocalTransparencyModifier ~= 1 then
		startWall.LocalTransparencyModifier = 1
	end
end)

local old = startWall:FindFirstChild("StartHereSign")
if old then
	old:Destroy()
end

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local sign = create("BillboardGui", {
	Name = "StartHereSign",
	Adornee = startWall,
	Size = UDim2.fromOffset(320, 190),
	StudsOffsetWorldSpace = Vector3.new(0, -7, 0),
	AlwaysOnTop = false,
	LightInfluence = 0,
	MaxDistance = 220,
}, startWall)

local pill = create("Frame", {
	Size = UDim2.fromOffset(320, 72),
	BackgroundColor3 = PIN_RED,
}, sign)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, pill)
create("UIStroke", { Color = INK, Thickness = 5 }, pill)

local text = create("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = FONT,
	Text = "START HERE",
	TextColor3 = CREAM,
	TextSize = 44,
}, pill)
create("UIStroke", { Color = INK, Thickness = 3 }, text)

local arrow = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 74),
	Size = UDim2.fromOffset(100, 100),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "v",
	TextColor3 = LANE,
	TextSize = 110,
}, sign)
create("UIStroke", { Color = INK, Thickness = 5 }, arrow)

-- Idle animation: the sign breathes, the arrow bobs.
local pillScale = create("UIScale", { Scale = 1 }, pill)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	arrow.Position = UDim2.new(0.5, 0, 0, 74 + math.sin(t * 4) * 10)
	pillScale.Scale = 1 + math.sin(t * 2.5) * 0.03
end)

-- Hide while a run is in progress (the player is already past it).
local player = game:GetService("Players").LocalPlayer
local function refresh()
	local state = player:GetAttribute("RunState")
	sign.Enabled = (state == nil or state == "" or state == "Waiting")
end
player:GetAttributeChangedSignal("RunState"):Connect(refresh)
refresh()
