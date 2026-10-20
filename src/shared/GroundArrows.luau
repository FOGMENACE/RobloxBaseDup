--------------------------------------------------
-- GROUND ARROWS (shared, client-side visuals)
--
-- A clean trail of chunky white arrows with a black outline lying on the
-- floor, streaming from the ball toward a target (tutorial objectives, the
-- Bowling Shop after a world teleport). The arrows flow forward
-- continuously and fade in/out at the ends of the trail.
--
--   local trail = GroundArrows.new("Name")
--   trail:Update(ball, targetPosition)   -- call every frame
--   trail:Hide()
--   trail:Destroy()
--------------------------------------------------

local GroundArrows = {}
GroundArrows.__index = GroundArrows

local COUNT = 9
local SPACING = 6.5
local SPEED = 0.9 -- trail cycles per second
local FILL = Color3.fromRGB(235, 250, 255)
local INK = Color3.fromRGB(18, 18, 26)
local HIDDEN = Vector3.new(0, -5000, 0)

local function makeArrow(parent)
	local part = Instance.new("Part")
	part.Size = Vector3.new(5.5, 0.2, 5.5)
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CastShadow = false
	part.Transparency = 1
	part.Position = HIDDEN
	part.Parent = parent

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Top
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(200, 200)
	surface.LightInfluence = 0
	surface.Brightness = 1.6
	surface.Parent = part

	local group = Instance.new("CanvasGroup")
	group.Size = UDim2.fromScale(1, 1)
	group.BackgroundTransparency = 1
	group.Parent = surface

	-- filled arrow pointing to the top of the canvas: a shaft and a diamond
	-- head (the diamond's lower half hides behind the shaft's top)
	local function piece(size, position, rotation, z)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(size.X, size.Y)
		f.Position = UDim2.fromOffset(position.X, position.Y)
		f.Rotation = rotation
		f.BackgroundColor3 = FILL
		f.BorderSizePixel = 0
		f.ZIndex = z
		f.Parent = group
		local stroke = Instance.new("UIStroke")
		stroke.Color = INK
		stroke.Thickness = 7
		stroke.LineJoinMode = Enum.LineJoinMode.Miter
		stroke.Parent = f
		return f
	end
	piece(Vector2.new(96, 96), Vector2.new(100, 74), 45, 1) -- head
	piece(Vector2.new(54, 86), Vector2.new(100, 150), 0, 2) -- shaft
	-- cover the outline where shaft and head meet
	local seam = piece(Vector2.new(44, 22), Vector2.new(100, 108), 0, 3)
	seam:FindFirstChildOfClass("UIStroke"):Destroy()

	return { Part = part, Group = group }
end

function GroundArrows.new(name)
	local folder = Instance.new("Folder")
	folder.Name = name or "GroundArrows"
	folder.Parent = workspace
	local self = setmetatable({ Folder = folder, Arrows = {} }, GroundArrows)
	for index = 1, COUNT do
		self.Arrows[index] = makeArrow(folder)
	end
	return self
end

function GroundArrows:Hide()
	for _, arrow in ipairs(self.Arrows) do
		arrow.Part.Position = HIDDEN
		arrow.Group.GroupTransparency = 1
	end
end

-- Lays the trail from the ball toward targetPosition. Returns the last
-- visible point (for a distance label), or nil when hidden.
function GroundArrows:Update(ball, targetPosition)
	if not ball or not targetPosition then
		self:Hide()
		return nil
	end
	local flat = Vector3.new(targetPosition.X - ball.Position.X, 0, targetPosition.Z - ball.Position.Z)
	if flat.Magnitude < 4 then
		self:Hide()
		return nil
	end
	local direction = flat.Unit
	local groundY = ball.Position.Y - ball.Size.Y / 2 + 0.15
	local phase = (os.clock() * SPEED) % 1
	local reach = math.min(flat.Magnitude - 3, COUNT * SPACING)
	local lastPoint = nil

	for index, arrow in ipairs(self.Arrows) do
		local distance = 5 + (index - 1 + phase) * SPACING
		if distance > reach + 5 then
			arrow.Part.Position = HIDDEN
			arrow.Group.GroupTransparency = 1
		else
			local point = Vector3.new(ball.Position.X + direction.X * distance, groundY, ball.Position.Z + direction.Z * distance)
			-- the canvas "up" of a Top-face SurfaceGui is the part's local -X
			arrow.Part.CFrame = CFrame.fromMatrix(point, -direction, Vector3.yAxis)
			local fraction = math.clamp((index - 1 + phase) / COUNT, 0, 1)
			arrow.Group.GroupTransparency = 1 - math.sin(fraction * math.pi) * 0.97
			lastPoint = point
		end
	end
	return lastPoint
end

function GroundArrows:Destroy()
	self.Folder:Destroy()
end

return GroundArrows