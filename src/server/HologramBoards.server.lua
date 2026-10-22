--------------------------------------------------
-- HOLOGRAM BOARDS (SERVER, geometry only)
--
-- A small projector on the floor beside the ball shop casts three thin
-- beams ( \ | / ) up into a hologram screen that faces the spawn, so players
-- rolling past see the top 20 for MOST WINS / MOST REBIRTHS / ROBUX SPENT.
-- The lists themselves are drawn per client (HologramBoardsUI) from the same
-- LeaderboardData remote as the wall boards; nothing here is authoritative.
-- Built straight away so WorldService copies it into every themed lobby.
--------------------------------------------------

local CollectionService = game:GetService("CollectionService")

local FLOOR_Y = 63.5
-- against the east wall, right of the ball shop (front end of the wall, where one
-- wall screen used to hang), facing into the room; clear of the shop corner
local BASE = Vector3.new(-30, FLOOR_Y, -208.5) -- far enough out that the angled screen clears the side and front walls
-- angled a little toward the back of the room (the spawn and the generators), like the shop
local FACE_TOWARD = BASE + Vector3.new(-10, 0, -4)
local SCREEN_WIDTH, SCREEN_HEIGHT = 22, 9 -- wide enough for full usernames
local SCREEN_BOTTOM = 5.2 -- studs above the floor: eye level from a rolling ball

local CYAN = Color3.fromRGB(90, 220, 255)
local METAL = Color3.fromRGB(40, 42, 70)

local old = workspace:FindFirstChild("HoloBoards")
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = "HoloBoards"

local function part(name, size, cframe, color, material, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- orientation: the screen's front (-Z) looks at the spawn
local flatTarget = Vector3.new(FACE_TOWARD.X, BASE.Y, FACE_TOWARD.Z)
local facing = CFrame.lookAt(BASE, flatTarget)
local upright = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y

-- projector device: squat metal puck with a glowing top ring and lens
part("Base", Vector3.new(0.6, 3.2, 3.2), CFrame.new(BASE + Vector3.new(0, 0.3, 0)) * upright, METAL, Enum.Material.Metal, 0, Enum.PartType.Cylinder)
part("Ring", Vector3.new(0.12, 2.7, 2.7), CFrame.new(BASE + Vector3.new(0, 0.65, 0)) * upright, CYAN, Enum.Material.Neon, 0.1, Enum.PartType.Cylinder)
local lens = part("Lens", Vector3.new(0.5, 0.9, 0.9), CFrame.new(BASE + Vector3.new(0, 0.85, 0)) * upright, Color3.new(1, 1, 1), Enum.Material.Neon, 0, Enum.PartType.Cylinder)
local light = Instance.new("PointLight")
light.Color = CYAN
light.Range = 10
light.Brightness = 1.5
light.Parent = lens

-- the screen (the hologram itself is a SurfaceGui made on each client)
local screenCenter = (facing * CFrame.new(0, SCREEN_BOTTOM + SCREEN_HEIGHT / 2, 0)).Position
local screen = part("HoloScreen", Vector3.new(SCREEN_WIDTH, SCREEN_HEIGHT, 0.05), CFrame.lookAt(screenCenter, screenCenter + facing.LookVector), CYAN, Enum.Material.SmoothPlastic, 1)
screen.CanQuery = true -- lets the client scroll the lists with the wheel / finger

-- three thin beams \ | / from the lens up to the bottom of the screen
local lensTop = BASE + Vector3.new(0, 1.1, 0)
local bottomY = SCREEN_BOTTOM - 0.1
for index, x in ipairs({ -SCREEN_WIDTH / 2 + 0.4, 0, SCREEN_WIDTH / 2 - 0.4 }) do
	local top = (facing * CFrame.new(x, bottomY, 0)).Position
	local length = (top - lensTop).Magnitude
	local beam = part("Beam" .. index, Vector3.new(0.12, 0.12, length), CFrame.lookAt((lensTop + top) / 2, top), CYAN, Enum.Material.Neon, 0.45)
	beam:SetAttribute("BeamIndex", index)
	CollectionService:AddTag(beam, "HoloBeam")
end
-- a faint glowing bar under the screen where the beams land
part("Emitter", Vector3.new(SCREEN_WIDTH, 0.08, 0.08), facing * CFrame.new(0, bottomY, 0), CYAN, Enum.Material.Neon, 0.35)

model.Parent = workspace
print("[HologramBoards] READY at", BASE)
