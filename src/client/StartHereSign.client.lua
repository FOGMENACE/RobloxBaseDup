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
	Size = UDim2.fromOffset(520, 170),
	StudsOffsetWorldSpace = Vector3.new(0, -7, 0),
	AlwaysOnTop = false,
	LightInfluence = 0,
	MaxDistance = 220,
}, startWall)

-- No box: just glowing text with arrows that slide in from both sides,
-- fade in and out slowly and glitch every now and then.
local holder = create("Frame", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
}, sign)

local function makeText(text, size, color, position, anchor)
	local label = create("TextLabel", {
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(360, 60),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = text,
		TextColor3 = color,
		TextSize = size,
	}, holder)
	create("UIStroke", { Color = INK, Thickness = 4 }, label)
	return label
end

-- glitch ghosts (red / cyan copies that flash for a few frames)
local ghostR = makeText("START HERE", 44, Color3.fromRGB(255, 70, 90), UDim2.fromScale(0.5, 0.3))
local ghostC = makeText("START HERE", 44, Color3.fromRGB(70, 230, 255), UDim2.fromScale(0.5, 0.3))
ghostR.TextTransparency, ghostC.TextTransparency = 1, 1
ghostR:FindFirstChildOfClass("UIStroke").Enabled = false
ghostC:FindFirstChildOfClass("UIStroke").Enabled = false

local text = makeText("START HERE", 44, CREAM, UDim2.fromScale(0.5, 0.3))
local leftArrows = makeText(">>>", 40, LANE, UDim2.fromScale(0.05, 0.3))
local rightArrows = makeText("<<<", 40, LANE, UDim2.fromScale(0.95, 0.3))

local arrow = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 62),
	Size = UDim2.fromOffset(100, 100),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "v",
	TextColor3 = LANE,
	TextSize = 100,
}, sign)
create("UIStroke", { Color = INK, Thickness = 5 }, arrow)

local rng = Random.new()
local glitchUntil = 0
local nextGlitch = os.clock() + rng:NextNumber(2.5, 6)

RunService.RenderStepped:Connect(function()
	local t = os.clock()

	-- slow fade in / out (never fully gone)
	local fade = 0.5 + 0.5 * math.sin(t * 1.3)
	local alpha = 0.15 + 0.85 * fade

	-- arrows slide toward the middle and restart
	local slide = (t * 0.55) % 1
	leftArrows.Position = UDim2.fromScale(0.01 + slide * 0.1, 0.3)
	rightArrows.Position = UDim2.fromScale(0.99 - slide * 0.1, 0.3)
	local arrowAlpha = math.sin(slide * math.pi)
	leftArrows.TextTransparency = 1 - arrowAlpha * alpha
	rightArrows.TextTransparency = 1 - arrowAlpha * alpha

	arrow.Position = UDim2.new(0.5, 0, 0, 62 + math.sin(t * 4) * 8)
	arrow.TextTransparency = 1 - alpha

	-- occasional glitch: a quick flicker with a horizontal jitter
	if t >= nextGlitch then
		glitchUntil = t + rng:NextNumber(0.12, 0.3)
		nextGlitch = t + rng:NextNumber(2.5, 6)
	end

	if t < glitchUntil then
		local jitter = rng:NextInteger(-9, 9)
		text.Position = UDim2.new(0.5, jitter, 0.3, 0)
		ghostR.Position = UDim2.new(0.5, jitter - 5, 0.3, rng:NextInteger(-3, 3))
		ghostC.Position = UDim2.new(0.5, jitter + 5, 0.3, rng:NextInteger(-3, 3))
		ghostR.TextTransparency, ghostC.TextTransparency = 0.35, 0.35
		text.TextTransparency = rng:NextInteger(0, 1) * 0.6
	else
		text.Position = UDim2.fromScale(0.5, 0.3)
		ghostR.TextTransparency, ghostC.TextTransparency = 1, 1
		text.TextTransparency = 1 - alpha
	end
end)

-- Hide while a run is in progress (the player is already past it).
local player = game:GetService("Players").LocalPlayer
local function refresh()
	local state = player:GetAttribute("RunState")
	sign.Enabled = (state == nil or state == "" or state == "Waiting")
end
player:GetAttributeChangedSignal("RunState"):Connect(refresh)
refresh()
