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

-- Polished gold look: a deep navy base with gold trim, a shiny gold step, a cream
-- marble column with gold bands, and on top the game's own trophy - a giant golden
-- bowling pin with a white stripe, glowing and giving off soft gold sparkles.
local GOLD = Color3.fromRGB(255, 196, 58)
local GOLD_LIGHT = Color3.fromRGB(255, 226, 120)
local NAVY = Color3.fromRGB(34, 28, 74)
local MARBLE = Color3.fromRGB(246, 240, 228)

local function shiny(p, reflectance)
	p.Reflectance = reflectance or 0.18
	return p
end

-- Two-step round base
local base = part("Base", CYL, Vector3.new(1.2, 9, 9), CFrame.new(CENTER + Vector3.new(0, 0.6, 0)) * upright, NAVY, Enum.Material.SmoothPlastic)
base.CanCollide = true
shiny(part("BaseTrim", CYL, Vector3.new(0.22, 9.25, 9.25), CFrame.new(CENTER + Vector3.new(0, 1.2, 0)) * upright, GOLD, Enum.Material.Foil))
local step = shiny(part("Step", CYL, Vector3.new(1.2, 6.4, 6.4), CFrame.new(CENTER + Vector3.new(0, 1.8, 0)) * upright, GOLD, Enum.Material.Foil), 0.22)
step.CanCollide = true
part("StepTop", CYL, Vector3.new(0.12, 5.6, 5.6), CFrame.new(CENTER + Vector3.new(0, 2.45, 0)) * upright, MARBLE, Enum.Material.Marble)

-- Marble column with gold bands
part("Column", CYL, Vector3.new(4.2, 2.6, 2.6), CFrame.new(CENTER + Vector3.new(0, 4.6, 0)) * upright, MARBLE, Enum.Material.Marble)
shiny(part("ColumnBandLow", CYL, Vector3.new(0.35, 3.0, 3.0), CFrame.new(CENTER + Vector3.new(0, 2.7, 0)) * upright, GOLD, Enum.Material.Foil))
shiny(part("ColumnBandHigh", CYL, Vector3.new(0.35, 3.2, 3.2), CFrame.new(CENTER + Vector3.new(0, 6.6, 0)) * upright, GOLD, Enum.Material.Foil))

-- The golden pin trophy
local pinBase = Vector3.new(0, 6.8, 0)
shiny(part("PinBody", BALL, Vector3.new(2.3, 2.3, 2.3), CFrame.new(CENTER + pinBase + Vector3.new(0, 1.35, 0)), GOLD, Enum.Material.Foil), 0.25)
shiny(part("PinWaist", CYL, Vector3.new(1.6, 1.25, 1.25), CFrame.new(CENTER + pinBase + Vector3.new(0, 2.7, 0)) * upright, GOLD, Enum.Material.Foil), 0.25)
part("PinStripe", CYL, Vector3.new(0.32, 1.38, 1.38), CFrame.new(CENTER + pinBase + Vector3.new(0, 2.95, 0)) * upright, MARBLE, Enum.Material.SmoothPlastic)
local pinHead = shiny(part("PinHead", BALL, Vector3.new(1.5, 1.5, 1.5), CFrame.new(CENTER + pinBase + Vector3.new(0, 3.85, 0)), GOLD, Enum.Material.Foil), 0.25)

local pinGlow = Instance.new("PointLight")
pinGlow.Color = GOLD_LIGHT
pinGlow.Brightness = 1.8
pinGlow.Range = 14
pinGlow.Parent = pinHead

-- soft gold sparkles drifting up around the pin (the "shine")
local sparkleHolder = part("SparkleHolder", BLOCK, Vector3.new(2.4, 0.2, 2.4), CFrame.new(CENTER + pinBase + Vector3.new(0, 1, 0)), GOLD)
sparkleHolder.Transparency = 1
local sparkles = Instance.new("ParticleEmitter")
sparkles.Color = ColorSequence.new(GOLD_LIGHT, Color3.fromRGB(255, 250, 220))
sparkles.LightEmission = 1
sparkles.LightInfluence = 0
sparkles.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.2, 0.28),
	NumberSequenceKeypoint.new(1, 0),
})
sparkles.Transparency = NumberSequence.new(0.15)
sparkles.Lifetime = NumberRange.new(1.4, 2.2)
sparkles.Rate = 9
sparkles.Speed = NumberRange.new(1.2, 2.4)
sparkles.SpreadAngle = Vector2.new(25, 25)
sparkles.EmissionDirection = Enum.NormalId.Top
sparkles.Rotation = NumberRange.new(0, 360)
sparkles.RotSpeed = NumberRange.new(-60, 60)
sparkles.Parent = sparkleHolder

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
-- gold with one bright shine band (the client slides it across the text); the name
-- "Rainbow" is kept because CommunityUI looks it up
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 40)),
	ColorSequenceKeypoint.new(0.42, Color3.fromRGB(255, 214, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 252, 225)),
	ColorSequenceKeypoint.new(0.58, Color3.fromRGB(255, 214, 80)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 40)),
})
gradient.Rotation = 20
gradient.Parent = text

-- The colored circle in front of the podium (toward the room, -Z)
local circle = part(
	"CommunityCircle",
	CYL,
	Vector3.new(0.3, 4.6, 4.6),
	CFrame.new(CENTER + TO_MIDDLE * 8 + Vector3.new(0, 0.35, 0)) * upright, -- sits on the ring (0.2 thick), ring sits on the floor
	Color3.fromRGB(255, 205, 80)
)

-- clean cream rim under the gold disc
part(
	"CommunityRing",
	CYL,
	Vector3.new(0.2, 5.6, 5.6),
	CFrame.new(CENTER + TO_MIDDLE * 8 + Vector3.new(0, 0.1, 0)) * upright,
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

-- A thin glowing ring on the floor all the way around the podium: built from
-- short flat segments (a cylinder cannot be hollow), a gold neon ring with a
-- fainter cream ring just outside it.
do
	local SEGMENTS = 96
	-- centred between the podium and the gold prompt circle so the ring
	-- encloses BOTH (the circle stays inside it)
	local RING_CENTER = CENTER + TO_MIDDLE * 3.3
	local function ring(name, radius, width, color, material, transparency)
		local length = (2 * math.pi * radius / SEGMENTS) * 1.12 -- slight overlap, no gaps
		for index = 1, SEGMENTS do
			local angle = (index / SEGMENTS) * math.pi * 2
			local position = RING_CENTER + Vector3.new(math.cos(angle) * radius, 0.04, math.sin(angle) * radius)
			local segment = part(
				name,
				BLOCK,
				Vector3.new(length, 0.08, width),
				CFrame.new(position) * CFrame.Angles(0, -angle + math.pi / 2, 0),
				color,
				material
			)
			segment.Transparency = transparency or 0
		end
	end

	ring("PodiumRingGlow", 8.8, 0.9, Color3.fromRGB(255, 220, 120), Enum.Material.Neon, 0.82)
	ring("PodiumRing", 8.4, 0.32, Color3.fromRGB(255, 205, 80), Enum.Material.Neon, 0)
end

-- A little smaller overall (podium, mic and circle), standing on the floor.
-- The lowest point is measured per part in WORLD space: Model:GetBoundingBox()
-- is oriented to the first part, and the cylinders here are rotated 90 degrees,
-- so it measured the wrong axis and left the whole podium floating ~1.5 studs.
do
	model:ScaleTo(0.75)

	local lowest = math.huge
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local cf, size = descendant.CFrame, descendant.Size
			local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
			local halfHeight = (math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(look.Y) * size.Z) / 2
			lowest = math.min(lowest, cf.Position.Y - halfHeight)
		end
	end

	-- the real floor under the podium (falls back to FLOOR_Y)
	local floorY = FLOOR_Y
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local hit = Workspace:Raycast(CENTER + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	if hit then
		floorY = hit.Position.Y
	end

	model:PivotTo(model:GetPivot() + Vector3.new(0, floorY - lowest, 0))
	prompt.MaxActivationDistance = 8
end
print("[PodiumService] READY")
