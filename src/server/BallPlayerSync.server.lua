--------------------------------------------------
-- BALL PLAYER SYNC
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--
-- PURPOSE:
--
-- Keeps the player's hidden character synchronized
-- with their physical bowling ball.
--
-- IMPORTANT:
--
-- The BALL remains responsible for:
--
--   - movement
--   - physics
--   - network ownership
--   - WinCourse movement
--   - camera position/orientation
--
-- The CHARACTER exists for Roblox player
-- interactions only.
--
-- THIS SCRIPT DOES NOT:
--
--   - move the ball
--   - control LinearVelocity
--   - change ball velocity
--   - change ball ownership
--   - change WinCourseActive
--   - control WinCourse
--   - process player input
--
-- BallSpawner is responsible for preparing the
-- hidden character.
--
-- This script only keeps the character root
-- synchronized with the authoritative ball.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService(
		"Players"
	)


local RunService =
	game:GetService(
		"RunService"
	)


--------------------------------------------------
-- PLAYER BALLS
--------------------------------------------------

local playerBalls =
	workspace:WaitForChild(
		"PlayerBalls"
	)


--------------------------------------------------
-- GET PLAYER BALL
--------------------------------------------------

local function getPlayerBall(
	player
)

	if not player then

		return nil

	end


	local ball =
		playerBalls:FindFirstChild(
			"PlayerBall_"
				..
				player.UserId
		)


	if not ball then

		return nil

	end


	if not ball:IsA(
		"BasePart"
	) then

		return nil

	end


	return ball

end


--------------------------------------------------
-- VALIDATE BALL OWNERSHIP
--
-- The ball must belong to the player whose
-- character is being synchronized.
--
-- This prevents accidental or malicious
-- cross-player synchronization.
--------------------------------------------------

local function ballBelongsToPlayer(
	ball,
	player
)

	if not ball
		or not player then

		return false

	end


	local ownerUserId =
		ball:GetAttribute(
			"OwnerUserId"
		)


	return ownerUserId ==
		player.UserId

end


--------------------------------------------------
-- PREPARE CHARACTER
--
-- BallSpawner normally performs this setup.
--
-- This function exists as a safety layer in case
-- the character respawns or another Roblox system
-- restores a character property.
--
-- IMPORTANT:
--
-- We do NOT modify the ball here.
--------------------------------------------------

local function prepareCharacter(
	character
)

	if not character then

		return

	end


	for _, descendant in ipairs(
		character:GetDescendants()
	) do

		--------------------------------------------------
		-- BASEPART
		--------------------------------------------------

		if descendant:IsA(
			"BasePart"
		) then

			descendant.Transparency =
				1

			descendant.CanCollide =
				false

			descendant.CanTouch =
				false

			descendant.CanQuery =
				false

			descendant.Massless =
				true

			--------------------------------------------------
			-- CHARACTER IS NOT PHYSICS AUTHORITY
			--
			-- BallSpawner anchors the hidden character.
			-- Keep that behavior consistent.
			--------------------------------------------------

			descendant.Anchored =
				true


		--------------------------------------------------
		-- DECAL
		--------------------------------------------------

		elseif descendant:IsA(
			"Decal"
		) then

			descendant.Transparency =
				1


		--------------------------------------------------
		-- EFFECTS
		--------------------------------------------------

		elseif descendant:IsA(
			"ParticleEmitter"
		)
			or descendant:IsA(
				"Trail"
			)
			or descendant:IsA(
				"Beam"
			) then

			descendant.Enabled =
				false

		end

	end

end


--------------------------------------------------
-- CHARACTER CACHE
--
-- Avoid repeatedly walking every character's
-- entire hierarchy every Heartbeat.
--------------------------------------------------

local preparedCharacters = {}


--------------------------------------------------
-- PREPARE CHARACTER ONCE
--------------------------------------------------

local function ensureCharacterPrepared(
	player,
	character
)

	if not character then

		return

	end


	if preparedCharacters[player]
		== character then

		return

	end


	prepareCharacter(
		character
	)


	preparedCharacters[player] =
		character

end


--------------------------------------------------
-- PLAYER CHARACTER ADDED
--------------------------------------------------

local function setupPlayer(
	player
)

	player.CharacterAdded:Connect(
		function(character)

			preparedCharacters[player] =
				nil

			--------------------------------------------------
			-- Give Roblox time to finish constructing the
			-- character before preparing it.
			--------------------------------------------------

			task.defer(
				function()

					if not player.Parent
						or player.Character ~= character then

						return

					end


					ensureCharacterPrepared(
						player,
						character
					)

				end
			)

		end
	)


	--------------------------------------------------
	-- EXISTING CHARACTER
	--------------------------------------------------

	if player.Character then

		ensureCharacterPrepared(
			player,
			player.Character
		)

	end

end


--------------------------------------------------
-- EXISTING PLAYERS
--------------------------------------------------

for _, player in ipairs(
	Players:GetPlayers()
) do

	setupPlayer(
		player
	)

end


--------------------------------------------------
-- PLAYER ADDED
--------------------------------------------------

Players.PlayerAdded:Connect(
	setupPlayer
)


--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		preparedCharacters[player] =
			nil

	end
)


--------------------------------------------------
-- PLAYER FOLLOW
--------------------------------------------------

RunService.Heartbeat:Connect(
	function()

		for _, player in ipairs(
			Players:GetPlayers()
		) do

			--------------------------------------------------
			-- CHARACTER
			--------------------------------------------------

			local character =
				player.Character


			if not character then

				continue

			end


			--------------------------------------------------
			-- ROOT
			--------------------------------------------------

			local root =
				character:FindFirstChild(
					"HumanoidRootPart"
				)


			if not root then

				continue

			end


			--------------------------------------------------
			-- PREPARE CHARACTER
			--------------------------------------------------

			ensureCharacterPrepared(
				player,
				character
			)


			--------------------------------------------------
			-- BALL
			--------------------------------------------------

			local ball =
				getPlayerBall(
					player
				)


			if not ball then

				continue

			end


			--------------------------------------------------
			-- OWNERSHIP VALIDATION
			--
			-- Never synchronize a player's character to
			-- a ball that belongs to another player.
			--------------------------------------------------

			if not ballBelongsToPlayer(
				ball,
				player
			) then

				continue

			end


			--------------------------------------------------
			-- CHARACTER FOLLOW
			--
			-- The ball is the authoritative position.
			--
			-- We copy its complete CFrame so the hidden
			-- character remains aligned with the ball's
			-- position and orientation.
			--------------------------------------------------

			root.CFrame =
				ball.CFrame

		end

	end
)


--------------------------------------------------
-- READY
--------------------------------------------------

print(
	"[BallPlayerSync]",
	"SERVER READY"
)

print(
	"[BallPlayerSync]",
	"Character follows authoritative player ball"
)

print(
	"[BallPlayerSync]",
	"Ball movement remains owned by BallMovement"
)

print(
	"[BallPlayerSync]",
	"WinCourse remains owned by WinCourseProgressService"
)

print(
	"[BallPlayerSync]",
	"Character physics disabled"
)

print(
	"[BallPlayerSync]",
	"Ball ownership validation ENABLED"
)