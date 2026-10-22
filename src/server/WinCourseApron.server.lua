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

-- the oil floor is turned 90 degrees: its LENGTH is Size.X (along Z), its width Size.Z
local floorEnd = floor.Position.Z + floor.Size.X / 2
local startZ = WinCourseGenerator.GetStartPosition().Z
local length = math.max(startZ + 2.4 - floorEnd, 1) -- ends right at the first tile (its edge is START + 2.45)

local apron = Instance.new("Part")
apron.Name = "WinCourseApron"
apron.Anchored = true
apron.CanCollide = true
apron.CanTouch = false
apron.CanQuery = true
apron.Size = Vector3.new(floor.Size.Z, floor.Size.Y, length)
apron.Position = Vector3.new(floor.Position.X, floor.Position.Y, floorEnd + length / 2 - 0.05)
apron.Color = floor.Color
apron.Material = floor.Material
apron.Reflectance = floor.Reflectance
apron.TopSurface = Enum.SurfaceType.Smooth
apron.BottomSurface = Enum.SurfaceType.Smooth
apron.Parent = course
