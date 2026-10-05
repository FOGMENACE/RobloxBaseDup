--------------------------------------------------
-- OIL COURSE SERVICE
--
-- SERVER ONLY
--
-- Explorer:
--
-- ServerScriptService
--   OilCourseService
--   OilCourseGenerator
--   GenerateOilCourse      <-- BindableEvent
--
--------------------------------------------------

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")
print("[OilCourseService] SCRIPT STARTED")
print("================================")

--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local course =
	Workspace:WaitForChild("Course")

--------------------------------------------------
-- GENERATE EVENT
--------------------------------------------------

local generateEvent =
	ServerScriptService:WaitForChild(
		"GenerateOilCourse"
	)

if not generateEvent:IsA("BindableEvent") then

	error(
		"[OilCourseService] GenerateOilCourse must be a BindableEvent"
	)

end

print(
	"[OilCourseService] GenerateOilCourse found:",
	generateEvent:GetFullName()
)

--------------------------------------------------
-- GENERATOR
--------------------------------------------------

local generatorModule =
	ServerScriptService:WaitForChild(
		"OilCourseGenerator"
	)

if not generatorModule:IsA("ModuleScript") then

	error(
		"[OilCourseService] OilCourseGenerator must be a ModuleScript"
	)

end

--------------------------------------------------
-- REQUIRE GENERATOR
--------------------------------------------------

local success, OilCourseGenerator =
	pcall(function()

		return require(generatorModule)

	end)

if not success then

	error(
		"[OilCourseService] Failed to require OilCourseGenerator: "
		.. tostring(OilCourseGenerator)
	)

end

if type(OilCourseGenerator) ~= "table" then

	error(
		"[OilCourseService] OilCourseGenerator must return a table"
	)

end

if type(OilCourseGenerator.Generate) ~= "function" then

	error(
		"[OilCourseService] OilCourseGenerator.Generate does not exist"
	)

end

print(
	"[OilCourseService] OilCourseGenerator loaded successfully"
)

--------------------------------------------------
-- GENERATION LOCK
--------------------------------------------------

local generating = {}

--------------------------------------------------
-- GET PLAYER COURSE
--------------------------------------------------

local function getPlayerCourse(player)

	if not player then
		return nil
	end

	return course:FindFirstChild(
		"PlayerCourse_" .. player.UserId
	)

end

--------------------------------------------------
-- GENERATE COURSE
--------------------------------------------------

local function generatePlayerCourse(player)

	if not player then

		warn(
			"[OilCourseService] Generate request had no player"
		)

		return nil

	end

	if not player:IsA("Player") then

		warn(
			"[OilCourseService] Invalid player:",
			player
		)

		return nil

	end

	--------------------------------------------------
	-- PLAYER MUST STILL EXIST
	--------------------------------------------------

	if not player:IsDescendantOf(Players) then

		warn(
			"[OilCourseService] Player is no longer in Players:",
			player.Name
		)

		return nil

	end

	--------------------------------------------------
	-- PREVENT DUPLICATE GENERATION
	--------------------------------------------------

	if generating[player] then

		warn(
			"[OilCourseService]",
			player.Name,
			"generation already in progress"
		)

		return getPlayerCourse(player)

	end

	--------------------------------------------------
	-- CHECK EXISTING COURSE
	--------------------------------------------------

	local existingCourse =
		getPlayerCourse(player)

	if existingCourse then

		print(
			"[OilCourseService]",
			player.Name,
			"already has:",
			existingCourse:GetFullName()
		)

		return existingCourse

	end

	--------------------------------------------------
	-- LOCK
	--------------------------------------------------

	generating[player] = true

	print("================================")
	print(
		"[OilCourseService] GENERATING COURSE FOR:",
		player.Name
	)
	print(
		"[OilCourseService] UserId:",
		player.UserId
	)
	print("================================")

	--------------------------------------------------
	-- CALL GENERATOR
	--------------------------------------------------

	local generateSuccess, result =
		pcall(function()

			return OilCourseGenerator.Generate(
				player
			)

		end)

	--------------------------------------------------
	-- UNLOCK
	--------------------------------------------------

	generating[player] = nil

	--------------------------------------------------
	-- GENERATOR ERROR
	--------------------------------------------------

	if not generateSuccess then

		warn("================================")
		warn(
			"[OilCourseService] GENERATOR ERROR"
		)
		warn(
			"[OilCourseService] Player:",
			player.Name
		)
		warn(
			tostring(result)
		)
		warn("================================")

		return nil

	end

	--------------------------------------------------
	-- NIL RESULT
	--------------------------------------------------

	if not result then

		warn(
			"[OilCourseService]",
			player.Name,
			"generator returned nil"
		)

		return nil

	end

	--------------------------------------------------
	-- VERIFY COURSE
	--------------------------------------------------

	if not result:IsA("Folder")
		and not result:IsA("Model") then

		warn(
			"[OilCourseService] Generator returned invalid object:",
			result.ClassName
		)

		return nil

	end

	if not result:IsDescendantOf(course) then

		warn(
			"[OilCourseService]",
			player.Name,
			"course was not created inside Workspace.Course"
		)

		return nil

	end

	--------------------------------------------------
	-- COUNT ROWS
	--------------------------------------------------

	local rowCount = 0

	for _, child in ipairs(
		result:GetChildren()
	) do

		if child:IsA("Model")
			and child.Name:match("^OilRow_") then

			rowCount += 1

		end

	end

	--------------------------------------------------
	-- SUCCESS
	--------------------------------------------------

	print("================================")
	print(
		"[OilCourseService] COURSE READY"
	)
	print(
		"[OilCourseService] Player:",
		player.Name
	)
	print(
		"[OilCourseService] Course:",
		result:GetFullName()
	)
	print(
		"[OilCourseService] Oil Rows:",
		rowCount
	)
	print("================================")

	if rowCount ~= 12 then

		warn(
			"[OilCourseService] WARNING: Expected 12 rows but got",
			rowCount
		)

	end

	return result

end

--------------------------------------------------
-- GENERATE OIL COURSE EVENT
--------------------------------------------------

generateEvent.Event:Connect(
	function(player)

		print("================================")
		print(
			"[OilCourseService] GenerateOilCourse EVENT RECEIVED"
		)
		print(
			"[OilCourseService] Player:",
			player and player.Name or "NIL"
		)
		print("================================")

		generatePlayerCourse(player)

	end
)

--------------------------------------------------
-- PLAYER JOIN
--------------------------------------------------

Players.PlayerAdded:Connect(
	function(player)

		print(
			"[OilCourseService] Player joined:",
			player.Name
		)

	end
)

--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		generating[player] = nil

		local playerCourse =
			getPlayerCourse(player)

		if playerCourse then

			print(
				"[OilCourseService] Removing:",
				playerCourse:GetFullName()
			)

			playerCourse:Destroy()

		end

	end
)

--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")
print("[OilCourseService] READY")
print(
	"[OilCourseService] Listening to:",
	generateEvent:GetFullName()
)
print(
	"[OilCourseService] Generator:",
	generatorModule:GetFullName()
)
print("================================")
