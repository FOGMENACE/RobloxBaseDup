local Players = game:GetService("Players")

local function hideCharacter(character)
	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("BasePart") then
			object.Transparency = 1
			object.CanCollide = false
			object.CastShadow = false

		elseif object:IsA("Decal") then
			object.Transparency = 1

		elseif object:IsA("ParticleEmitter") then
			object.Enabled = false

		elseif object:IsA("Trail") then
			object.Enabled = false
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

local function setupCharacter(character)
	hideCharacter(character)

	-- Catch accessories/clothing that may be inserted shortly
	character.DescendantAdded:Connect(function(object)
		if object:IsA("BasePart") then
			object.Transparency = 1
			object.CanCollide = false
			object.CastShadow = false

		elseif object:IsA("Decal") then
			object.Transparency = 1

		elseif object:IsA("ParticleEmitter") then
			object.Enabled = false

		elseif object:IsA("Trail") then
			object.Enabled = false
		end
	end)
end

local function setupPlayer(player)
	player.CharacterAdded:Connect(setupCharacter)

	if player.Character then
		setupCharacter(player.Character)
	end
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

--------------------------------------------------
-- NO SPAWN FORCEFIELD
--
-- The spawn forcefield draws a shimmering shell around the (hidden)
-- character. Nothing in this game can hurt the character, so remove it
-- the moment it appears, and set every SpawnLocation to Duration 0.
--------------------------------------------------

local function stripForceField(character)
	for _, object in ipairs(character:GetDescendants()) do
		if object:IsA("ForceField") then
			object:Destroy()
		end
	end

	character.DescendantAdded:Connect(function(object)
		if object:IsA("ForceField") then
			object.Visible = false
			task.defer(function()
				if object.Parent then
					object:Destroy()
				end
			end)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		stripForceField(player.Character)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(stripForceField)
end)

for _, object in ipairs(workspace:GetDescendants()) do
	if object:IsA("SpawnLocation") then
		object.Duration = 0
	end
end
workspace.DescendantAdded:Connect(function(object)
	if object:IsA("SpawnLocation") then
		object.Duration = 0
	end
end)
