--------------------------------------------------
-- BALL COLLISION GROUP (server)
--
-- Players' balls must not collide with each other (they used to bump and
-- shove one another in the lobby and on the courses). The group still
-- collides with the floor / walls / generators ("Default"), so rolling,
-- jumping and every platform / wall touch behave exactly as before.
--------------------------------------------------

local PhysicsService = game:GetService("PhysicsService")

local GROUP = "PlayerBallsGroup"

pcall(function()
	PhysicsService:RegisterCollisionGroup(GROUP)
end)

pcall(function()
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", true)
end)

local function apply(instance)
	if instance:IsA("BasePart") then
		instance.CollisionGroup = GROUP
	end
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = GROUP
		end
	end
end

local folder = workspace:WaitForChild("PlayerBalls")

folder.ChildAdded:Connect(function(child)
	apply(child)
	child.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = GROUP
		end
	end)
end)

for _, child in ipairs(folder:GetChildren()) do
	apply(child)
end

print("[BallCollisionGroup] READY")