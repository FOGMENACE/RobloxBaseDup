--------------------------------------------------
-- WORLD COURSE THEME (CLIENT, visual only)
--
-- The oil course is shared by every world. On this client it is dressed in
-- the theme of the world the player is in: a polished wood-plank bowling
-- lane tinted to the world, glowing side walls, and two metal gutters along
-- the edges. The gutters are local, non-colliding and non-queryable, so the
-- ball rolls straight past them; nothing here touches gameplay or the server.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local course = Workspace:WaitForChild("Course")
local floor = course:WaitForChild("Floor")
local walls = { course:WaitForChild("LeftBoundary"), course:WaitForChild("RightBoundary") }

local original = {} -- [part] = { Color, Material, Reflectance }
local function remember(part)
	if not original[part] then
		original[part] = { Color = part.Color, Material = part.Material, Reflectance = part.Reflectance }
	end
end

-- gutters: built once, recoloured per world
local gutterFolder = Instance.new("Folder")
gutterFolder.Name = "VisualGutters"
local gutterParts = {}

local function visual(part)
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = gutterFolder
	return part
end

do
	local laneTop = floor.Position.Y + floor.Size.Y / 2
	local length = math.max(floor.Size.X, floor.Size.Z)
	local centerZ = floor.Position.Z
	for _, wall in ipairs(walls) do
		local inward = (floor.Position.X - wall.Position.X) > 0 and 1 or -1
		local x = wall.Position.X + inward * 1.45
		-- the trough: a half-sunk cylinder running the length of the lane
		local trough = visual(Instance.new("Part"))
		trough.Name = "Gutter"
		trough.Shape = Enum.PartType.Cylinder
		trough.Size = Vector3.new(length, 2.6, 2.6)
		trough.CFrame = CFrame.new(x, laneTop - 0.95, centerZ) * CFrame.Angles(0, math.pi / 2, 0)
		trough.Material = Enum.Material.Metal
		-- a thin polished lip where the lane meets the gutter
		local lip = visual(Instance.new("Part"))
		lip.Name = "GutterLip"
		lip.Size = Vector3.new(0.25, 0.12, length)
		lip.CFrame = CFrame.new(x - inward * 1.35, laneTop + 0.04, centerZ)
		lip.Material = Enum.Material.Neon
		table.insert(gutterParts, { Trough = trough, Lip = lip })
	end
end

-- the course is masked on this client while in the lobby (PreviewMask);
-- the gutters follow the lane floor so they never float on their own
local function syncGutters()
	gutterFolder.Parent = floor:IsDescendantOf(Workspace) and Workspace or nil
end
floor.AncestryChanged:Connect(syncGutters)
syncGutters()

local MAPLE = Color3.fromRGB(226, 186, 138)
local WORLD1 = { Gutter = Color3.fromRGB(46, 44, 56), Lip = Color3.fromRGB(235, 225, 210) }

local function apply()
	local world = WorldConfig.Of(player)
	local theme = world.Theme
	remember(floor)
	for _, wall in ipairs(walls) do
		remember(wall)
	end

	-- a real, opaque, polished maple bowling lane in every world (world 1 is
	-- classic maple; the higher worlds tint it toward their theme)
	floor.Material = Enum.Material.WoodPlanks
	floor.Transparency = 0
	floor.Color = theme and MAPLE:Lerp(theme.Floor, 0.3) or MAPLE
	floor.Reflectance = 0.18 + (theme and theme.Shine * 0.3 or 0)
	for _, wall in ipairs(walls) do
		wall.Color = theme and theme.Glow or original[wall].Color
	end

	for _, g in ipairs(gutterParts) do
		g.Trough.Color = theme and theme.Primary or WORLD1.Gutter
		g.Trough.Reflectance = theme and theme.Shine or 0.15
		g.Lip.Color = theme and theme.Accent or WORLD1.Lip
	end
end

player:GetAttributeChangedSignal("World"):Connect(apply)
apply()