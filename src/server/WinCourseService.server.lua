--------------------------------------------------
-- WIN COURSE SERVICE
--
-- SERVER ONLY
--
-- FLOW:
--
-- RunController
--      |
--      v
-- StartWinCourse (BindableEvent)
--      |
--      v
-- WinCourseService
--      |
--      v
-- WinCourseGenerator.Generate()
--
-- RESPONSIBILITIES:
--
-- 1. Receive StartWinCourse
-- 2. Validate player + ball
-- 3. Freeze ball
-- 4. Remove lobby Win Course preview
-- 5. Generate actual WinCourse
-- 6. Ask WinCourseGenerator for the official
--    Win Course starting position
-- 7. Move ball to that position
-- 8. Release ball
--
-- IMPORTANT:
--
-- WinCourseGenerator is the SINGLE SOURCE OF TRUTH
-- for Win Course positioning and tile configuration.
--
-- THIS SERVICE DOES NOT:
--
-- - Duplicate START_POSITION
-- - Duplicate TILE_SPACING
-- - Configure tile colors
-- - Configure trophy UI
-- - Create SurfaceGui
-- - Create BillboardGui
-- - Create ImageLabel
-- - Create WinAmount
-- - Create TrophyDecal
-- - Create ColorOverlay
-- - Move individual tile children
--
-- CURRENT WIN TILE HIERARCHY:
--
-- WinTile
-- ├── Floor
-- │
-- └── TrophyDisplay
--     └── SurfaceGui
--         ├── ImageLabel
--         └── WinAmount
--
-- SurfaceGui is directly inside TrophyDisplay.
--
-- ImageLabel and WinAmount are directly inside SurfaceGui.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService("Players")

local ServerScriptService =
	game:GetService("ServerScriptService")

local Workspace =
	game:GetService("Workspace")


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local playerBalls =
	Workspace:WaitForChild(
		"PlayerBalls"
	)

local course =
	Workspace:WaitForChild(
		"Course"
	)


--------------------------------------------------
-- START WIN COURSE EVENT
--------------------------------------------------

local startWinCourse =
	ServerScriptService:WaitForChild(
		"StartWinCourse"
	)

if not startWinCourse:IsA("BindableEvent") then

	error(
		"[WinCourseService] StartWinCourse MUST be a BindableEvent."
	)

end


--------------------------------------------------
-- WIN COURSE GENERATOR
--------------------------------------------------

local generatorModule =
	ServerScriptService:WaitForChild(
		"WinCourseGenerator"
	)

if not generatorModule:IsA("ModuleScript") then

	error(
		"[WinCourseService] WinCourseGenerator must be a ModuleScript."
	)

end


local requireSuccess,
	WinCourseGenerator =
	pcall(function()

		return require(generatorModule)

	end)


if not requireSuccess then

	error(
		"[WinCourseService] Failed to require WinCourseGenerator:\n"
		.. tostring(WinCourseGenerator)
	)

end


if type(WinCourseGenerator) ~= "table" then

	error(
		"[WinCourseService] WinCourseGenerator must return a table."
	)

end


if type(WinCourseGenerator.Generate) ~= "function" then

	error(
		"[WinCourseService] WinCourseGenerator.Generate() is missing."
	)

end


--------------------------------------------------
-- OFFICIAL START POSITION
--------------------------------------------------

if type(WinCourseGenerator.GetStartPosition) ~= "function" then

	error(
		"[WinCourseService] WinCourseGenerator.GetStartPosition() is missing."
	)

end


--------------------------------------------------
-- TILE SPACING
--------------------------------------------------

if type(WinCourseGenerator.GetTileSpacing) ~= "function" then

	error(
		"[WinCourseService] WinCourseGenerator.GetTileSpacing() is missing."
	)

end


--------------------------------------------------
-- STATE
--------------------------------------------------

local winCourseBusy = {}


--------------------------------------------------
-- GET OFFICIAL START POSITION
--------------------------------------------------

local function getWinCourseStartPosition()

	local startPosition =
		WinCourseGenerator.GetStartPosition()

	if typeof(startPosition) ~= "Vector3" then

		error(
			"[WinCourseService] " ..
			"WinCourseGenerator.GetStartPosition() " ..
			"must return a Vector3."
		)

	end

	return startPosition

end


--------------------------------------------------
-- REMOVE LOBBY WIN PREVIEW
--------------------------------------------------

local function removeLobbyWinPreview()

	local previewNames = {

		"LobbyWinCourse",
		"WinCoursePreview",

	}

	for _, previewName in ipairs(
		previewNames
	) do

		local preview =
			course:FindFirstChild(
				previewName
			)

		if preview then

			print(
				"[WinCourseService] Removing lobby preview:",
				preview:GetFullName()
			)

			preview:Destroy()

		end

	end

end


--------------------------------------------------
-- REMOVE OLD ACTUAL WIN COURSE
--------------------------------------------------

local function removeOldWinCourse()

	local oldCourse =
		course:FindFirstChild(
			"WinCourse"
		)

	if oldCourse then

		print(
			"[WinCourseService] Removing old WinCourse:",
			oldCourse:GetFullName()
		)

		oldCourse:Destroy()

	end

end


--------------------------------------------------
-- HARD FREEZE BALL
--------------------------------------------------

local function freezeBall(ball)

	if not ball
		or not ball:IsA("BasePart")
		or not ball.Parent then

		return false

	end


	--------------------------------------------------
	-- STOP PHYSICS
	--------------------------------------------------

	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	--------------------------------------------------
	-- DISABLE BALL LINEAR VELOCITY
	--------------------------------------------------

	local linearVelocity =
		ball:FindFirstChild(
			"BallLinearVelocity"
		)

	if linearVelocity
		and linearVelocity:IsA("LinearVelocity") then

		linearVelocity.VectorVelocity =
			Vector3.zero

		linearVelocity.Enabled =
			false

	end


	--------------------------------------------------
	-- SERVER OWNERSHIP
	--------------------------------------------------

	pcall(function()

		ball:SetNetworkOwner(nil)

	end)


	--------------------------------------------------
	-- HARD FREEZE
	--------------------------------------------------

	ball.Anchored =
		true

	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	return true

end


--------------------------------------------------
-- MOVE BALL TO OFFICIAL WIN START
--------------------------------------------------

local function moveBallToStart(ball)

	if not ball
		or not ball:IsA("BasePart")
		or not ball.Parent then

		return false

	end


	--------------------------------------------------
	-- GET POSITION FROM GENERATOR
	--------------------------------------------------

	local winStartPosition =
		getWinCourseStartPosition()


	print(
		"[WinCourseService] Official Win Course start:",
		winStartPosition
	)


	--------------------------------------------------
	-- KEEP BALL FROZEN
	--------------------------------------------------

	ball.Anchored =
		true

	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	--------------------------------------------------
	-- MOVE BALL
	--------------------------------------------------

	ball.CFrame =
		CFrame.new(
			winStartPosition
		)


	--------------------------------------------------
	-- CLEAR MOTION
	--------------------------------------------------

	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	print(
		"[WinCourseService] Ball moved to official Win Course start:",
		winStartPosition
	)


	return true

end


--------------------------------------------------
-- RELEASE BALL
--------------------------------------------------

local function releaseBall(ball)

	if not ball
		or not ball:IsA("BasePart")
		or not ball.Parent then

		return false

	end


	--------------------------------------------------
	-- SERVER OWNS PHYSICS
	--------------------------------------------------

	pcall(function()

		ball:SetNetworkOwner(nil)

	end)


	--------------------------------------------------
	-- CLEAR MOTION
	--------------------------------------------------

	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	--------------------------------------------------
	-- UNFREEZE
	--------------------------------------------------

	ball.Anchored =
		false


	--------------------------------------------------
	-- CLEAR AGAIN
	--------------------------------------------------

	ball.AssemblyLinearVelocity =
		Vector3.zero

	ball.AssemblyAngularVelocity =
		Vector3.zero


	return true

end


--------------------------------------------------
-- VALIDATE REQUEST
--------------------------------------------------

local function validateWinCourseRequest(
	player,
	ball
)

	--------------------------------------------------
	-- PLAYER
	--------------------------------------------------

	if not player
		or not player:IsA("Player") then

		warn(
			"[WinCourseService] Invalid player."
		)

		return false

	end


	--------------------------------------------------
	-- BALL
	--------------------------------------------------

	if not ball
		or not ball:IsA("BasePart")
		or not ball.Parent then

		warn(
			"[WinCourseService]",
			player.Name,
			"Invalid ball."
		)

		return false

	end


	--------------------------------------------------
	-- BALL MUST BE DIRECTLY INSIDE PLAYERBALLS
	--------------------------------------------------

	if ball.Parent ~= playerBalls then

		warn(
			"[WinCourseService]",
			player.Name,
			"Ball is not directly inside PlayerBalls."
		)

		return false

	end


	--------------------------------------------------
	-- BALL NAME
	--------------------------------------------------

	local expectedName =
		"PlayerBall_" ..
		player.UserId


	if ball.Name ~= expectedName then

		warn(
			"[WinCourseService]",
			player.Name,
			"Invalid ball:",
			ball.Name,
			"Expected:",
			expectedName
		)

		return false

	end


	--------------------------------------------------
	-- OWNER
	--------------------------------------------------

	local ownerUserId =
		ball:GetAttribute(
			"OwnerUserId"
		)


	if ownerUserId ~= player.UserId then

		warn(
			"[WinCourseService]",
			player.Name,
			"Ball ownership mismatch."
		)

		return false

	end


	--------------------------------------------------
	-- RUN STATE
	--------------------------------------------------

	local runState =
		player:GetAttribute(
			"RunState"
		)


	if runState ~= "Finishing" then

		warn(
			"[WinCourseService]",
			player.Name,
			"Invalid RunState:",
			runState
		)

		return false

	end


	return true

end


--------------------------------------------------
-- COUNT GENERATED TILES
--------------------------------------------------

local function countGeneratedTiles(
	winCourse
)

	local tileCount = 0


	for _, child in ipairs(
		winCourse:GetChildren()
	) do

		if child:IsA("Model")
			and child.Name:match(
				"^WinTile_"
			) then

			tileCount += 1

		end

	end


	return tileCount

end


--------------------------------------------------
-- VERIFY GENERATED WIN COURSE
--
-- EXACT CURRENT HIERARCHY:
--
-- WinCourse
-- └── WinTile_X
--     ├── Floor
--     │
--     └── TrophyDisplay
--         └── SurfaceGui
--             ├── ImageLabel
--             └── WinAmount
--
-- IMPORTANT:
--
-- SurfaceGui is NOT searched recursively.
-- It must be directly inside TrophyDisplay.
--
-- ImageLabel is NOT searched recursively.
-- It must be directly inside SurfaceGui.
--
-- WinAmount is NOT searched recursively.
-- It must be directly inside SurfaceGui.
--------------------------------------------------

local function verifyGeneratedWinCourse(
	winCourse
)

	--------------------------------------------------
	-- COURSE TYPE
	--------------------------------------------------

	if not winCourse
		or not winCourse:IsA("Folder") then

		warn(
			"[WinCourseService] Generated WinCourse is not a Folder."
		)

		return false

	end


	--------------------------------------------------
	-- COURSE LOCATION
	--------------------------------------------------

	if winCourse.Parent ~= course then

		warn(
			"[WinCourseService] Generated WinCourse is not directly inside Workspace.Course."
		)

		return false

	end


	--------------------------------------------------
	-- COURSE ATTRIBUTE
	--------------------------------------------------

	if winCourse:GetAttribute(
		"IsWinCourse"
	) ~= true then

		warn(
			"[WinCourseService] Generated WinCourse is missing IsWinCourse attribute."
		)

		return false

	end


	--------------------------------------------------
	-- COUNT
	--------------------------------------------------

	local tileCount =
		countGeneratedTiles(
			winCourse
		)


	local expectedCount =
		winCourse:GetAttribute(
			"TileCount"
		)


	if expectedCount
		and tileCount ~= expectedCount then

		warn(
			"[WinCourseService] Tile count mismatch:",
			tileCount,
			"expected",
			expectedCount
		)

		return false

	end


	--------------------------------------------------
	-- VERIFY EACH TILE
	--------------------------------------------------

	for _, tile in ipairs(
		winCourse:GetChildren()
	) do

		if tile:IsA("Model")
			and tile.Name:match(
				"^WinTile_"
			) then


			--------------------------------------------------
			-- FLOOR
			--------------------------------------------------

			local floor =
				tile:FindFirstChild(
					"Floor"
				)


			if not floor
				or not floor:IsA("BasePart") then

				warn(
					"[WinCourseService] Tile missing Floor:",
					tile:GetFullName()
				)

				return false

			end


			--------------------------------------------------
			-- TROPHY DISPLAY
			--
			-- Must be directly inside WinTile.
			--------------------------------------------------

			local trophyDisplay =
				tile:FindFirstChild(
					"TrophyDisplay"
				)


			if not trophyDisplay
				or not trophyDisplay:IsA("BasePart") then

				warn(
					"[WinCourseService] Tile missing direct TrophyDisplay:",
					tile:GetFullName()
				)

				return false

			end


			--------------------------------------------------
			-- SURFACE GUI
			--
			-- Must be directly inside TrophyDisplay.
			--------------------------------------------------

			local surfaceGui =
				trophyDisplay:FindFirstChild(
					"SurfaceGui"
				)


			if not surfaceGui
				or not surfaceGui:IsA("SurfaceGui") then

				warn(
					"[WinCourseService] Tile missing TrophyDisplay.SurfaceGui:",
					tile:GetFullName()
				)

				return false

			end


			--------------------------------------------------
			-- IMAGE LABEL
			--
			-- Must be directly inside SurfaceGui.
			--------------------------------------------------

			local imageLabel =
				surfaceGui:FindFirstChild(
					"ImageLabel"
				)


			if not imageLabel
				or not imageLabel:IsA("ImageLabel") then

				warn(
					"[WinCourseService] Tile missing SurfaceGui.ImageLabel:",
					tile:GetFullName()
				)

				return false

			end


			--------------------------------------------------
			-- WIN AMOUNT
			--
			-- Must be directly inside SurfaceGui.
			--------------------------------------------------

			local winAmount =
				surfaceGui:FindFirstChild(
					"WinAmount"
				)


			if not winAmount
				or not winAmount:IsA("TextLabel") then

				warn(
					"[WinCourseService] Tile missing SurfaceGui.WinAmount:",
					tile:GetFullName()
				)

				return false

			end


			--------------------------------------------------
			-- DEBUG
			--------------------------------------------------

			print(
				"[WinCourseService] Verified tile:",
				tile:GetFullName()
			)

			print(
				"[WinCourseService] Floor:",
				floor:GetFullName()
			)

			print(
				"[WinCourseService] TrophyDisplay:",
				trophyDisplay:GetFullName()
			)

			print(
				"[WinCourseService] SurfaceGui:",
				surfaceGui:GetFullName()
			)

			print(
				"[WinCourseService] ImageLabel:",
				imageLabel:GetFullName()
			)

			print(
				"[WinCourseService] WinAmount:",
				winAmount:GetFullName()
			)

		end

	end


	return true

end


--------------------------------------------------
-- GENERATE WIN COURSE
--------------------------------------------------

local function generateWinCourse(
	player
)

	print("================================")

	print(
		"[WinCourseService] GENERATING WIN COURSE FOR:",
		player.Name
	)

	print("================================")


	--------------------------------------------------
	-- REMOVE LOBBY PREVIEW
	--------------------------------------------------

	removeLobbyWinPreview()


	--------------------------------------------------
	-- REMOVE OLD ACTUAL COURSE
	--------------------------------------------------

	removeOldWinCourse()


	--------------------------------------------------
	-- GENERATE
	--------------------------------------------------

	local success,
		result =
		pcall(function()

			return WinCourseGenerator.Generate()

		end)


	if not success then

		warn(
			"[WinCourseService] WinCourseGenerator ERROR:"
		)

		warn(
			tostring(result)
		)

		return nil

	end


	--------------------------------------------------
	-- RESULT EXISTS
	--------------------------------------------------

	if not result then

		warn(
			"[WinCourseService] WinCourseGenerator returned nil."
		)

		return nil

	end


	--------------------------------------------------
	-- RESULT INSIDE COURSE
	--------------------------------------------------

	if not result:IsDescendantOf(course) then

		warn(
			"[WinCourseService] Generated WinCourse is not inside Workspace.Course."
		)

		return nil

	end


	--------------------------------------------------
	-- VERIFY
	--------------------------------------------------

	if not verifyGeneratedWinCourse(
		result
	) then

		warn(
			"[WinCourseService] Generated WinCourse failed verification."
		)

		return nil

	end


	--------------------------------------------------
	-- COUNT
	--------------------------------------------------

	local tileCount =
		countGeneratedTiles(
			result
		)


	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print("================================")

	print(
		"[WinCourseService] WIN COURSE GENERATED"
	)

	print(
		"[WinCourseService] Folder:",
		result:GetFullName()
	)

	print(
		"[WinCourseService] Tiles:",
		tileCount
	)

	print(
		"[WinCourseService] Start Position:",
		getWinCourseStartPosition()
	)

	print(
		"[WinCourseService] Tile Spacing:",
		WinCourseGenerator.GetTileSpacing()
	)

	print(
		"[WinCourseService] Trophy UI:",
		"TrophyDisplay > SurfaceGui > ImageLabel + WinAmount"
	)

	print("================================")


	return result

end


--------------------------------------------------
-- PLAYER CLEANUP
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		winCourseBusy[player] = nil

	end
)


--------------------------------------------------
-- START WIN COURSE
--------------------------------------------------

startWinCourse.Event:Connect(
	function(
		player,
		ball
	)

		print("================================")

		print(
			"[WinCourseService] StartWinCourse EVENT RECEIVED:",
			player and player.Name,
			ball and ball.Name
		)

		print("================================")


		--------------------------------------------------
		-- VALIDATE
		--------------------------------------------------

		if not validateWinCourseRequest(
			player,
			ball
		) then

			return

		end


		--------------------------------------------------
		-- PREVENT DOUBLE START
		--------------------------------------------------

		if winCourseBusy[player] then

			warn(
				"[WinCourseService]",
				player.Name,
				"WinCourse already active."
			)

			return

		end


		winCourseBusy[player] =
			true


		--------------------------------------------------
		-- FREEZE BALL
		--------------------------------------------------

		if not freezeBall(ball) then

			winCourseBusy[player] =
				nil

			warn(
				"[WinCourseService]",
				player.Name,
				"FAILED TO FREEZE BALL"
			)

			return

		end


		print(
			"[WinCourseService]",
			player.Name,
			"BALL HARD FROZEN"
		)


		--------------------------------------------------
		-- MARK ACTIVE
		--------------------------------------------------

		ball:SetAttribute(
			"WinCourseActive",
			true
		)


		--------------------------------------------------
		-- GENERATE ACTUAL WIN COURSE
		--------------------------------------------------

		local winCourse =
			generateWinCourse(
				player
			)


		if not winCourse then

			warn(
				"[WinCourseService]",
				player.Name,
				"FAILED TO GENERATE WIN COURSE"
			)

			ball:SetAttribute(
				"WinCourseActive",
				false
			)

			winCourseBusy[player] =
				nil

			return

		end


		--------------------------------------------------
		-- MOVE BALL TO OFFICIAL START
		--------------------------------------------------

		if not moveBallToStart(
			ball
		) then

			warn(
				"[WinCourseService]",
				player.Name,
				"FAILED TO MOVE BALL TO WIN COURSE"
			)

			ball:SetAttribute(
				"WinCourseActive",
				false
			)

			winCourseBusy[player] =
				nil

			return

		end


		--------------------------------------------------
		-- READY
		--------------------------------------------------

		print(
			"[WinCourseService]",
			player.Name,
			"BALL READY FOR WIN COURSE"
		)


		--------------------------------------------------
		-- RELEASE
		--------------------------------------------------

		if not releaseBall(
			ball
		) then

			warn(
				"[WinCourseService]",
				player.Name,
				"FAILED TO RELEASE BALL"
			)

			ball:SetAttribute(
				"WinCourseActive",
				false
			)

			winCourseBusy[player] =
				nil

			return

		end


		--------------------------------------------------
		-- ACTIVE
		--------------------------------------------------

		print(
			"[WinCourseService]",
			player.Name,
			"BALL RELEASED INTO WIN COURSE"
		)
--------------------------------------------------
-- ENTER BONUS / WIN COURSE STATE
--------------------------------------------------

player:SetAttribute(
    "RunState",
    "Bonus"
)

	print(
    	"[WinCourseService]",
   	 player.Name,
   	 "RunState = Bonus"
)

		print("================================")

		print(
			"[WinCourseService]",
			player.Name,
			"WIN COURSE ACTIVE"
		)

		print("================================")

	end
)


--------------------------------------------------
-- SERVER READY
--------------------------------------------------

print("================================")

print(
	"[WinCourseService] SERVER READY"
)

print(
	"[WinCourseService] StartWinCourse:",
	startWinCourse:GetFullName()
)

print(
	"[WinCourseService] StartWinCourse Class:",
	startWinCourse.ClassName
)

print(
	"[WinCourseService] WinCourseGenerator:",
	generatorModule:GetFullName()
)

print(
	"[WinCourseService] Win Course Start:",
	getWinCourseStartPosition()
)

print(
	"[WinCourseService] Win Course Spacing:",
	WinCourseGenerator.GetTileSpacing()
)

print(
	"[WinCourseService] WinTile UI:",
	"TrophyDisplay > SurfaceGui > ImageLabel + WinAmount"
)

print(
	"[WinCourseService] Floor coloring:",
	"Owned by WinCourseGenerator"
)

print("================================")
