--------------------------------------------------
-- WIN COURSE APRON (SERVER)
--
-- The win course now starts just past the end of the oil course (it used to
-- start 13 studs inside it and clip through the finish wall and the floor).
-- That leaves a few studs between the oil floor's end and the first win tile,
-- right where the ball waits for the countdown. This short floor piece fills
-- the gap, copying the oil floor's look, so the ball never sits over thin air.
--------------------------------------------------

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local course = Workspace:WaitForChild("Course")
local floor = course:WaitForChild("Floor")
local WinCourseGenerator = require(ServerScriptService:WaitForChild("WinCourseGenerator"))

local old = course:FindFirstChild("WinCourseApron")
if old then
	old:Destroy()
end

-- Join the two lanes exactly: the apron runs from the oil floor's end to the first
-- win tile's edge and is as wide as the win tiles (they are wider than the oil
-- floor), so there is no gap and no step at the tile.
-- The oil floor is turned 90 degrees: its LENGTH is Size.X (along Z), its width Size.Z.
local floorEnd = floor.Position.Z + floor.Size.X / 2

-- the win course preview is built by WinCoursePreviewService; read the first tile from it
local tileEdge = WinCourseGenerator.GetStartPosition().Z + 2.45
local tileWidth = floor.Size.Z
local preview = course:WaitForChild("WinCoursePreview", 30)
if preview then
	task.wait(1) -- the preview builder is still adding tiles
	local best
	for _, d in ipairs(preview:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Floor" and (not best or d.Position.Z < best.Position.Z) then
			best = d
		end
	end
	if best then
		tileEdge = best.Position.Z - best.Size.Z / 2
		tileWidth = math.max(best.Size.X, tileWidth)
	end
end

local length = math.max(tileEdge - floorEnd, 1)

local apron = Instance.new("Part")
apron.Name = "WinCourseApron"
apron.Anchored = true
apron.CanCollide = true
apron.CanTouch = false
apron.CanQuery = true
apron.Size = Vector3.new(tileWidth, floor.Size.Y, length)
apron.Position = Vector3.new(floor.Position.X, floor.Position.Y - 0.01, floorEnd + length / 2)
apron.Color = floor.Color
apron.Material = floor.Material
apron.Reflectance = floor.Reflectance
apron.TopSurface = Enum.SurfaceType.Smooth
apron.BottomSurface = Enum.SurfaceType.Smooth
apron.Parent = course