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

-- Hidden player characters (BallSpawner parks them at the spawn, invisible) must
-- never block a ball either. Their owner's Humanoid turns CanCollide back on for
-- its body parts, so the collision GROUP is what keeps them out of the way: this
-- pair used to stay collidable, and a friend's invisible character could stop your
-- ball (you could even roll up onto it).
local CHARACTER_GROUP = "HiddenPlayerCharacter"
pcall(function()
	PhysicsService:RegisterCollisionGroup(CHARACTER_GROUP)
end)
pcall(function()
	PhysicsService:CollisionGroupSetCollidable(CHARACTER_GROUP, GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(CHARACTER_GROUP, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(CHARACTER_GROUP, CHARACTER_GROUP, false)
end)

-- keep EVERY part of every character (also accessories that load later) in the
-- hidden group, so nothing a character owns is ever solid to a ball
local Players = game:GetService("Players")
local function groupCharacter(character)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = CHARACTER_GROUP
		end
	end
	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = CHARACTER_GROUP
		end
	end)
end
local function watchPlayer(player)
	if player.Character then
		groupCharacter(player.Character)
	end
	player.CharacterAdded:Connect(groupCharacter)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

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