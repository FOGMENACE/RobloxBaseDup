--------------------------------------------------
-- LOBBY FLOOR COLLIDERS (server)
--
-- The lobby floors are paper thin (0.06 - 0.43 studs). A ball landing from a
-- jump could sink into such a slab (stuck, "trying to move") or pass through it
-- (falling under the lobby), and with streaming a client could briefly not
-- have the floor at all. Under every thin lobby floor (in every world copy)
-- this adds an invisible 4-stud slab whose TOP is exactly the floor's top, so
-- the ball rests at the same height and nothing looks different.
-- The slabs live in a Persistent model, so every client always has them.
-- They are not queryable / touchable, so raycasts and touch logic are unchanged.
--------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))

local spawnPad = workspace:WaitForChild("BallSpawn")
local course = workspace:WaitForChild("Course")
local playerBalls = workspace:WaitForChild("PlayerBalls")

local THICKNESS = 4
local LOBBY_RADIUS = 250 -- studs around a world's spawn pad
local LOBBY_HEIGHT = 12 -- studs above / below the spawn pad

local holder = Instance.new("Model")
holder.Name = "LobbyFloorColliders"
pcall(function()
	holder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end)
holder.Parent = workspace

local done = {} -- [floor] = collider

local function nearLobby(position)
	local pad = spawnPad.Position
	if math.abs(position.Y - pad.Y) > LOBBY_HEIGHT then
		return false
	end
	for _, world in ipairs(WorldConfig.Worlds) do
		local center = pad + world.Offset
		if Vector3.new(position.X - center.X, 0, position.Z - center.Z).Magnitude < LOBBY_RADIUS then
			return true
		end
	end
	return false
end

local function isThinFloor(part)
	return part:IsA("BasePart")
		and part.Anchored
		and part.CanCollide
		and part.Size.Y < 1
		and part.Size.X >= 8
		and part.Size.Z >= 8
		and part.CFrame.UpVector.Y > 0.99
		and part.Parent ~= holder
		and not part:IsDescendantOf(course)
		and not part:IsDescendantOf(playerBalls)
		and nearLobby(part.Position)
end

local function addCollider(floor)
	if done[floor] or not isThinFloor(floor) then
		return
	end

	local collider = Instance.new("Part")
	collider.Name = "FloorCollider"
	collider.Anchored = true
	collider.CanCollide = true
	collider.CanQuery = false
	collider.CanTouch = false
	collider.CastShadow = false
	collider.Transparency = 1
	collider.Material = floor.Material
	collider.CustomPhysicalProperties = floor.CustomPhysicalProperties
	collider.Size = Vector3.new(floor.Size.X, THICKNESS, floor.Size.Z)
	-- top face flush with the floor's top face
	collider.CFrame = floor.CFrame * CFrame.new(0, floor.Size.Y / 2 - THICKNESS / 2, 0)
	collider.Parent = holder
	done[floor] = collider

	floor.AncestryChanged:Connect(function(_, parent)
		if not parent and done[floor] then
			done[floor]:Destroy()
			done[floor] = nil
		end
	end)
end

for _, part in ipairs(workspace:GetDescendants()) do
	addCollider(part)
end

-- world copies are built after start: give them colliders too
workspace.DescendantAdded:Connect(function(part)
	if part:IsA("BasePart") and part.Size.Y < 1 then
		task.defer(addCollider, part)
	end
end)

print("[LobbyFloorColliders] READY")
