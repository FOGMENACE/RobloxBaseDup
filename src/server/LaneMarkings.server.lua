--------------------------------------------------
-- LANE MARKINGS (server, decor only)
-- Real bowling-lane markings on the oil course floor right behind the
-- StartWall: foul line, spots and arrows pointing down the course.
--
-- Everything is anchored, non-colliding and lives in Workspace.LaneDecor.
-- Gameplay never reads any of it.
--------------------------------------------------

local Workspace = game:GetService("Workspace")

local ballSpawn = Workspace:WaitForChild("BallSpawn", 30)
local startWall = Workspace:WaitForChild("StartWall", 30)
local course = Workspace:WaitForChild("Course", 30)
if not (ballSpawn and startWall and course) then
	return
end
local courseFloor = course:WaitForChild("Floor", 30)
if not courseFloor then
	return
end

local old = Workspace:FindFirstChild("LaneDecor")
if old then
	old:Destroy()
end
local decor = Instance.new("Folder")
decor.Name = "LaneDecor"
decor.Parent = Workspace

local TILE_DARK = Color3.fromRGB(70, 44, 150)

local function part(name, size, cframe, color, material, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = decor
	return p
end

-- A chevron (^) drawn on the top face of an invisible flat part.
-- `pointsPositiveZ` rotates it so the tip points along +Z.
local function chevron(name, center, width, length, color, transparency, pointsPositiveZ)
	local base = part(name, Vector3.new(width, 0.05, length), CFrame.new(center), color, Enum.Material.SmoothPlastic, 1)
	if pointsPositiveZ then
		base.CFrame = CFrame.new(center) * CFrame.Angles(0, math.pi / 2, 0)
	end

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(300, 300 * length / width)
	gui.LightInfluence = 0
	gui.Parent = base

	-- UI rotation pivots on the element's centre, so each arm is placed by its
	-- centre (apex + half an arm along its direction) in pixels.
	local canvas = gui.CanvasSize
	local phi = math.rad(36)
	local armLength = canvas.X * 0.5
	local thickness = math.min(canvas.X, canvas.Y) * 0.17
	local apex = Vector2.new(canvas.X / 2, canvas.Y * 0.2)

	for _, side in ipairs({ -1, 1 }) do
		local direction = Vector2.new(side * math.cos(phi), math.sin(phi))
		local centre = apex + direction * (armLength / 2)

		local arm = Instance.new("Frame")
		arm.AnchorPoint = Vector2.new(0.5, 0.5)
		arm.Position = UDim2.fromOffset(centre.X, centre.Y)
		arm.Size = UDim2.fromOffset(armLength, thickness)
		arm.Rotation = side * math.deg(phi)
		arm.BackgroundColor3 = color
		arm.BackgroundTransparency = transparency
		arm.BorderSizePixel = 0
		arm.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = arm
	end
	return base
end

local wallZ = startWall.Position.Z


--------------------------------------------------
-- 3) LANE MARKINGS ON THE OIL COURSE (behind the StartWall)
--------------------------------------------------

local laneTop = courseFloor.Position.Y + courseFloor.Size.Y / 2
local laneWidth = courseFloor.Size.Z -- floor is rotated: Z is the width
local laneX = courseFloor.Position.X
local MARK = Color3.fromRGB(58, 36, 24)
local FOUL = Color3.fromRGB(240, 236, 228)

-- foul line + a darker band behind it
part(
	"FoulLine",
	Vector3.new(laneWidth - 1, 0.04, 0.55),
	CFrame.new(laneX, laneTop + 0.04, wallZ + 1.2),
	FOUL,
	Enum.Material.SmoothPlastic,
	0.1
)

-- spots (7 across)
local spotZ = wallZ + 7
for index = 1, 7 do
	local spot = part(
		"Spot" .. index,
		Vector3.new(0.04, 1.3, 1.3),
		CFrame.new(laneX + (index - 4) * (laneWidth / 9), laneTop + 0.04, spotZ) * CFrame.Angles(0, 0, math.rad(90)),
		MARK,
		Enum.Material.SmoothPlastic,
		0.15
	)
	spot.Shape = Enum.PartType.Cylinder
end

-- arrows (darts) in a V: outer ones further back, centre one furthest ahead
local arrowBaseZ = wallZ + 12
for index = 1, 7 do
	local offset = index - 4
	local z = arrowBaseZ + (4 - math.abs(offset)) * 1.6
	chevron(
		"LaneArrow" .. index,
		Vector3.new(laneX + offset * (laneWidth / 9), laneTop + 0.05, z),
		3.4,
		3.6,
		MARK,
		0.2,
		true
	)
end

--------------------------------------------------
-- 4) LANE MARKINGS BEFORE THE FINISH WALL
--
-- The same bowling spots and arrows (pointing at the wall) so the end of the
-- oil course reads like the pin end of a lane.
--------------------------------------------------

local finishWall = Workspace:WaitForChild("FinishWall", 30)
if finishWall then
	local finishZ = finishWall.Position.Z
	local endSpotZ = finishZ - 40
	local endArrowZ = finishZ - 32

	-- a darker approach band across the lane
	part(
		"FinishBand",
		Vector3.new(laneWidth - 1, 0.04, 2.2),
		CFrame.new(laneX, laneTop + 0.03, finishZ - 4),
		MARK,
		Enum.Material.SmoothPlastic,
		0.55
	)

	for index = 1, 7 do
		local spot = part(
			"FinishSpot" .. index,
			Vector3.new(0.04, 1.3, 1.3),
			CFrame.new(laneX + (index - 4) * (laneWidth / 9), laneTop + 0.04, endSpotZ) * CFrame.Angles(0, 0, math.rad(90)),
			MARK,
			Enum.Material.SmoothPlastic,
			0.15
		)
		spot.Shape = Enum.PartType.Cylinder
	end

	-- arrows in the same V, tips toward the finish wall
	for index = 1, 7 do
		local offset = index - 4
		local z = endArrowZ + (4 - math.abs(offset)) * 1.6
		chevron(
			"FinishArrow" .. index,
			Vector3.new(laneX + offset * (laneWidth / 9), laneTop + 0.05, z),
			3.4,
			3.6,
			MARK,
			0.2,
			true
		)
	end
end

print("[LaneMarkings] READY |", #decor:GetChildren(), "parts")
