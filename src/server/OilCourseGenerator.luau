local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OilCourseGenerator = {}

--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local templates =
	ServerStorage:WaitForChild("Templates")

local oilRowTemplate =
	templates:WaitForChild("OilRow")

local OilDefinitions =
	require(
		ReplicatedStorage:WaitForChild("OilDefinitions")
	)

local course =
	workspace:WaitForChild("Course")

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local NUMBER_OF_ROWS = 12
local ROW_SPACING = 20

local START_POSITION = Vector3.new(
	-64.718,
	67.994,
	-174.612
)

local oilTypes = {
	"Small",
	"Medium",
	"Large",
	"Mega",
}

local rng = Random.new()

--------------------------------------------------
-- COLORS
--------------------------------------------------

local POSITIVE_COLOR =
	Color3.fromRGB(
		60,
		220,
		90
	)

local NEGATIVE_COLOR =
	Color3.fromRGB(
		220,
		50,
		50
	)

--------------------------------------------------
-- FIND PLATFORM
--------------------------------------------------

local function findPlatform(
	oilRow,
	name
)

	local platform =
		oilRow:FindFirstChild(
			name,
			true
		)

	if not platform then

		warn(
			"[OilCourseGenerator] MISSING PLATFORM:",
			name,
			"inside",
			oilRow:GetFullName()
		)

		return nil

	end

	if not platform:IsA("BasePart")
		and not platform:IsA("Model") then

		warn(
			"[OilCourseGenerator] INVALID PLATFORM TYPE:",
			platform:GetFullName(),
			platform.ClassName
		)

		return nil

	end

	return platform

end

--------------------------------------------------
-- GET ALL BASEPARTS IN PLATFORM
--------------------------------------------------

local function getPlatformParts(
	platform
)

	local parts = {}

	if not platform then
		return parts
	end

	if platform:IsA("BasePart") then

		table.insert(
			parts,
			platform
		)

	elseif platform:IsA("Model") then

		for _, object in ipairs(
			platform:GetDescendants()
		) do

			if object:IsA("BasePart") then

				table.insert(
					parts,
					object
				)

			end

		end

	end

	return parts

end

--------------------------------------------------
-- FIND EXISTING OIL LABEL
--
-- IMPORTANT:
--
-- We DO NOT create a label.
-- We DO NOT change its properties.
-- We ONLY change Text.
--------------------------------------------------

local function findOilLabel(
	platform
)

	if not platform then
		return nil
	end

	--------------------------------------------------
	-- FIRST: exact OilAmount name
	--------------------------------------------------

	local namedLabel =
		platform:FindFirstChild(
			"OilAmount",
			true
		)

	if namedLabel
		and namedLabel:IsA("TextLabel") then

		return namedLabel

	end

	--------------------------------------------------
	-- SECOND: find existing TextLabel
	-- inside an existing SurfaceGui
	--------------------------------------------------

	for _, object in ipairs(
		platform:GetDescendants()
	) do

		if object:IsA("TextLabel") then

			local surfaceGui =
				object:FindFirstAncestorOfClass(
					"SurfaceGui"
				)

			if surfaceGui then

				return object

			end

		end

	end

	return nil

end

--------------------------------------------------
-- CONFIGURE NUMBER
--
-- ONLY THE TEXT IS CHANGED.
--
-- ALL EXISTING LABEL PROPERTIES ARE PRESERVED.
--------------------------------------------------

local function configureOilNumber(
	platform,
	amount,
	isPositive
)

	local label =
		findOilLabel(
			platform
		)

	if not label then

		warn(
			"[OilCourseGenerator] NO EXISTING OIL LABEL:",
			platform:GetFullName()
		)

		return false

	end

	--------------------------------------------------
	-- ONLY CHANGE TEXT
	--------------------------------------------------

	local displayAmount =
		math.abs(amount)

	if isPositive then

		label.Text =
			"+" .. tostring(displayAmount)

	else

		label.Text =
			"-" .. tostring(displayAmount)

	end

	print(
		"[OilCourseGenerator] LABEL:",
		label:GetFullName(),
		"TEXT:",
		label.Text
	)

	return true

end

--------------------------------------------------
-- CONFIGURE PLATFORM COLOR
--------------------------------------------------

local function configurePlatformVisuals(
	platform,
	isPositive
)

	local color

	if isPositive then

		color =
			POSITIVE_COLOR

	else

		color =
			NEGATIVE_COLOR

	end

	local parts =
		getPlatformParts(
			platform
		)

	if #parts == 0 then

		warn(
			"[OilCourseGenerator] PLATFORM HAS NO BASEPARTS:",
			platform:GetFullName()
		)

		return false

	end

	--------------------------------------------------
	-- COLOR EVERY PART
	--------------------------------------------------

	for _, part in ipairs(
		parts
	) do

		part.Color =
			color

		part.Transparency =
			0.15

		part.Anchored =
			true

		part.CanCollide =
			false

		part.CanTouch =
			false

		part.CanQuery =
			true

	end

	return true

end

--------------------------------------------------
-- CONFIGURE ONE PLATFORM
--------------------------------------------------

local function setupPlatform(
	platform,
	isPositive
)

	if not platform then
		return false
	end

	--------------------------------------------------
	-- RANDOM OIL TYPE
	--------------------------------------------------

	local oilType =
		oilTypes[
			rng:NextInteger(
				1,
				#oilTypes
			)
		]

	local definition =
		OilDefinitions[oilType]

	if not definition then

		warn(
			"[OilCourseGenerator] MISSING OIL DEFINITION:",
			oilType
		)

		return false

	end

	--------------------------------------------------
	-- AMOUNT
	--------------------------------------------------

	local amount =
		tonumber(
			definition.Oil
		)

	if not amount then

		warn(
			"[OilCourseGenerator] INVALID OIL AMOUNT:",
			oilType,
			definition.Oil
		)

		return false

	end

	if not isPositive then

		amount =
			-amount

	end

	--------------------------------------------------
	-- ATTRIBUTES
	--------------------------------------------------

	platform:SetAttribute(
		"OilType",
		oilType
	)

	platform:SetAttribute(
		"OilAmount",
		amount
	)

	platform:SetAttribute(
		"Positive",
		isPositive
	)

	platform:SetAttribute(
		"Collected",
		false
	)

	--------------------------------------------------
	-- COLOR
	--------------------------------------------------

	if not configurePlatformVisuals(
		platform,
		isPositive
	) then

		return false

	end

	--------------------------------------------------
	-- NUMBER
	--------------------------------------------------

	if not configureOilNumber(
		platform,
		amount,
		isPositive
	) then

		return false

	end

	return true

end

--------------------------------------------------
-- GENERATE
--------------------------------------------------

function OilCourseGenerator.Generate(
	player
)

	if not player then

		warn(
			"[OilCourseGenerator] Generate() received nil player"
		)

		return nil

	end

	print("================================")
	print(
		"[OilCourseGenerator] GENERATING FOR:",
		player.Name,
		player.UserId
	)

	--------------------------------------------------
	-- COURSE NAME
	--------------------------------------------------

	local courseName =
		"PlayerCourse_" ..
		player.UserId

	--------------------------------------------------
	-- REMOVE OLD PLAYER COURSE ONLY
	--
	-- DO NOT TOUCH LobbyCourse HERE.
	--------------------------------------------------

	local oldCourse =
		course:FindFirstChild(
			courseName
		)

	if oldCourse then

		print(
			"[OilCourseGenerator] Removing old:",
			oldCourse:GetFullName()
		)

		oldCourse:Destroy()

	end

	--------------------------------------------------
	-- CREATE PLAYER COURSE
	--------------------------------------------------

	local playerCourse =
		Instance.new("Folder")

	playerCourse.Name =
		courseName

	playerCourse.Parent =
		course

	--------------------------------------------------
	-- ROWS
	--------------------------------------------------

	local successfulRows = 0

	for rowNumber = 1, NUMBER_OF_ROWS do

		--------------------------------------------------
		-- CLONE ONE ROW
		--------------------------------------------------

		local oilRow =
			oilRowTemplate:Clone()

		oilRow.Name =
			"OilRow_" ..
			rowNumber

		--------------------------------------------------
		-- POSITION
		--------------------------------------------------

		local rowZ =
			START_POSITION.Z
			+
			(
				(rowNumber - 1)
				* ROW_SPACING
			)

		local currentPivot =
			oilRow:GetPivot()

		local rotation =
			currentPivot
			- currentPivot.Position

		oilRow:PivotTo(
			CFrame.new(
				START_POSITION.X,
				START_POSITION.Y,
				rowZ
			)
			* rotation
		)

		--------------------------------------------------
		-- RESET PHYSICS
		--------------------------------------------------

		for _, object in ipairs(
			oilRow:GetDescendants()
		) do

			if object:IsA("BasePart") then

				object.Anchored =
					true

				object.CanCollide =
					false

				object.CanTouch =
					false

				object.CanQuery =
					false

			end

		end

		--------------------------------------------------
		-- FIND PLATFORMS
		--------------------------------------------------

		local left =
			findPlatform(
				oilRow,
				"OilPlatformL"
			)

		local right =
			findPlatform(
				oilRow,
				"OilPlatformR"
			)

		if not left or not right then

			warn(
				"[OilCourseGenerator] ROW",
				rowNumber,
				"FAILED: missing platform"
			)

			oilRow:Destroy()

			continue

		end

		--------------------------------------------------
		-- RANDOM POSITIVE / NEGATIVE
		--
		-- At least one is ALWAYS green.
		--------------------------------------------------

		local leftPositive =
			rng:NextInteger(
				0,
				1
			) == 1

		local rightPositive =
			rng:NextInteger(
				0,
				1
			) == 1

		if not leftPositive
			and not rightPositive then

			if rng:NextInteger(
				0,
				1
			) == 1 then

				leftPositive =
					true

			else

				rightPositive =
					true

			end

		end

		--------------------------------------------------
		-- LEFT
		--------------------------------------------------

		local leftOK =
			setupPlatform(
				left,
				leftPositive
			)

		--------------------------------------------------
		-- RIGHT
		--------------------------------------------------

		local rightOK =
			setupPlatform(
				right,
				rightPositive
			)

		--------------------------------------------------
		-- ROW FAILED
		--------------------------------------------------

		if not leftOK
			or not rightOK then

			warn(
				"[OilCourseGenerator] ROW",
				rowNumber,
				"FAILED DURING CONFIGURATION"
			)

			oilRow:Destroy()

			continue

		end

		--------------------------------------------------
		-- ROW ATTRIBUTES
		--------------------------------------------------

		oilRow:SetAttribute(
			"RowNumber",
			rowNumber
		)

		oilRow:SetAttribute(
			"OilCollected",
			false
		)

		oilRow:SetAttribute(
			"CollectedPlatform",
			""
		)

		--------------------------------------------------
		-- PARENT
		--------------------------------------------------

		oilRow.Parent =
			playerCourse

		successfulRows += 1

		print(
			"[OilCourseGenerator] ROW",
			rowNumber,
			"SUCCESS"
		)

	end

	--------------------------------------------------
	-- FINAL
	--------------------------------------------------

	print(
		"[OilCourseGenerator] FINISHED:",
		successfulRows,
		"/",
		NUMBER_OF_ROWS,
		"rows"
	)

	print(
		"[OilCourseGenerator] COURSE:",
		playerCourse:GetFullName()
	)

	print("================================")

	return playerCourse

end

return OilCourseGenerator
