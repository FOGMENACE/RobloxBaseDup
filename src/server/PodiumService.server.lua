--------------------------------------------------
-- PODIUM (SERVER, decoration only)
--
-- A podium beside the StartWall with a golden microphone, a floating
-- "FREE WINS!" billboard (animated by client/PodiumFX) and a glowing
-- colored circle in front. Stepping up to the circle and using its
-- prompt opens the COMMUNITY REWARDS panel (client/CommunityUI); the
-- reward itself is granted by RewardService.
--------------------------------------------------

local Workspace = game:GetService("Workspace")

local FLOOR_Y = 63.5
-- Moved to the west side (where the ball shop used to be), turned toward
-- the middle of the room.
local CENTER = Vector3.new(-84, FLOOR_Y, -208)
local TO_MIDDLE = (Vector3.new(-65, 0, -237) - Vector3.new(CENTER.X, 0, CENTER.Z)).Unit
local YAW = math.atan2(-TO_MIDDLE.X, -TO_MIDDLE.Z) -- local -Z front -> toward the middle

local old = Workspace:FindFirstChild("Podium")
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = "Podium"
model.Parent = Workspace

local function part(name, shape, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local CYL = Enum.PartType.Cylinder
local BLOCK = Enum.PartType.Block
local BALL = Enum.PartType.Ball
local upright = CFrame.Angles(0, 0, math.pi / 2) -- cylinders stand along Y

-- Two-step round base
local base = part("Base", CYL, Vector3.new(1.2, 9, 9), CFrame.new(CENTER + Vector3.new(0, 0.6, 0)) * upright, Color3.fromRGB(70, 60, 120))
base.CanCollide = true
local step = part("Step", CYL, Vector3.new(1.2, 6.4, 6.4), CFrame.new(CENTER + Vector3.new(0, 1.8, 0)) * upright, Color3.fromRGB(240, 178, 82))
step.CanCollide = true

-- Speaker's stand
part("Stand", BLOCK, Vector3.new(3.2, 4.2, 2.2), CFrame.new(CENTER + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, YAW, 0), Color3.fromRGB(150, 70, 60), Enum.Material.WoodPlanks)
part("StandTop", BLOCK, Vector3.new(3.8, 0.4, 2.8), CFrame.new(CENTER + Vector3.new(0, 6.8, 0)) * CFrame.Angles(0, YAW, 0), Color3.fromRGB(255, 247, 232))

-- Golden microphone
local gold = Color3.fromRGB(255, 200, 50)
part("MicNeck", CYL, Vector3.new(2.4, 0.5, 0.5), CFrame.new(CENTER + Vector3.new(0, 8.2, 0)) * upright, gold, Enum.Material.Metal)
part("MicHead", BALL, Vector3.new(2, 2, 2), CFrame.new(CENTER + Vector3.new(0, 10.1, 0)), gold, Enum.Material.Metal)
local micGlow = Instance.new("PointLight")
micGlow.Color = Color3.fromRGB(255, 220, 120)
micGlow.Brightness = 1.5
micGlow.Range = 12
micGlow.Parent = model.MicHead

-- Billboard anchor (client animates the contents)
local anchor = part("TitleAnchor", BLOCK, Vector3.new(1, 1, 1), CFrame.new(CENTER + Vector3.new(0, 14, 0)), Color3.new(1, 1, 1))
anchor.Transparency = 1

local billboard = Instance.new("BillboardGui")
billboard.Name = "FreeWinsBillboard"
-- sized in STUDS (scale), so it shrinks with distance: small from afar,
-- readable when you walk up to the podium
billboard.Size = UDim2.fromScale(5.2, 1.35)
billboard.AlwaysOnTop = false
billboard.LightInfluence = 0
billboard.MaxDistance = 80
billboard.Parent = anchor

local text = Instance.new("TextLabel")
text.Name = "Text"
text.AnchorPoint = Vector2.new(0.5, 0.5)
text.Position = UDim2.fromScale(0.5, 0.5)
text.Size = UDim2.fromScale(1, 1)
text.BackgroundTransparency = 1
text.Font = Enum.Font.FredokaOne
text.Text = "FREE WINS!"
text.TextColor3 = Color3.new(1, 1, 1)
text.TextScaled = true
text.Parent = billboard

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.new(0, 0, 0)
stroke.Thickness = 5
stroke.Parent = text

local gradient = Instance.new("UIGradient")
gradient.Name = "Rainbow"
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 230, 90)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(160, 90, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 60)),
})
gradient.Parent = text

-- The colored circle in front of the podium (toward the room, -Z)
local circle = part(
	"CommunityCircle",
	CYL,
	Vector3.new(0.3, 4.6, 4.6),
	CFrame.new(CENTER + TO_MIDDLE * 8 + Vector3.new(0, 0.5, 0)) * upright,
	Color3.fromRGB(255, 205, 80)
)

-- clean cream rim under the gold disc
part(
	"CommunityRing",
	CYL,
	Vector3.new(0.2, 5.6, 5.6),
	CFrame.new(CENTER + TO_MIDDLE * 8 + Vector3.new(0, 0.38, 0)) * upright,
	Color3.fromRGB(255, 247, 232)
)

local promptHolder = part("PromptHolder", BLOCK, Vector3.new(1, 1, 1), CFrame.new(CENTER + TO_MIDDLE * 8 + Vector3.new(0, 1.2, 0)), Color3.new(1, 1, 1))
promptHolder.Transparency = 1

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "CommunityPrompt"
prompt.ActionText = "Community Rewards"
prompt.ObjectText = "FREE WINS"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 8
prompt.RequiresLineOfSight = false
prompt.Parent = promptHolder

-- A little smaller overall (podium, mic and circle), standing on the floor.
do
	model:ScaleTo(0.75)
	local cf, size = model:GetBoundingBox()
	local bottom = cf.Position.Y - size.Y / 2
	model:PivotTo(model:GetPivot() + Vector3.new(0, FLOOR_Y - bottom, 0))
	prompt.MaxActivationDistance = 8
end

print("[PodiumService] READY")
