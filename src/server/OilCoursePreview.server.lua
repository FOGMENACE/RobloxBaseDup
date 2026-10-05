local ServerStorage = game:GetService("ServerStorage")

--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local templates =
	ServerStorage:WaitForChild("Templates")

local oilRowTemplate =
	templates:WaitForChild("OilRow")

local course =
	workspace:WaitForChild("Course")

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local NUMBER_OF_ROWS = 5
local ROW_SPACING = 20

local START_POSITION = Vector3.new(
	-64.718,
	67.994,
	-174.612
)

--------------------------------------------------
-- PREVIEW COLOR
--------------------------------------------------

local PREVIEW_COLOR =
	Color3.fromRGB(
		100,
		100,
		100
	)

--------------------------------------------------
-- REMOVE OLD PREVIEW
--------------------------------------------------

local oldPreview =
	course:FindFirstChild(
		"LobbyCourse"
	)

if oldPreview then

	print(
		"[OilCoursePreview] Removing old LobbyCourse"
	)

	oldPreview:Destroy()

end

--------------------------------------------------
-- CREATE PREVIEW FOLDER
--------------------------------------------------

local lobbyCourse =
	Instance.new("Folder")

lobbyCourse.Name =
	"LobbyCourse"

lobbyCourse.Parent =
	course

--------------------------------------------------
-- GET PLATFORM PARTS
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
-- REMOVE GAMEPLAY ATTRIBUTES
--------------------------------------------------

local function clearGameplayAttributes(
	platform
)

	if not platform then
		return
	end

	platform:SetAttribute(
		"OilAmount",
		nil
	)

	platform:SetAttribute(
		"OilType",
		nil
	)

	platform:SetAttribute(
		"Positive",
		nil
	)

	platform:SetAttribute(
		"Collected",
		nil
	)

end

--------------------------------------------------
-- GENERATE PREVIEW
--------------------------------------------------

for rowNumber = 1, NUMBER_OF_ROWS do

	print(
		"[OilCoursePreview] Creating row:",
		rowNumber
	)

	--------------------------------------------------
	-- CLONE
	--------------------------------------------------

	local oilRow =
		oilRowTemplate:Clone()

	oilRow.Name =
		"PreviewRow_" ..
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
	-- FIND PLATFORMS
	--------------------------------------------------

	local left =
		oilRow:FindFirstChild(
			"OilPlatformL",
			true
		)

	local right =
		oilRow:FindFirstChild(
			"OilPlatformR",
			true
		)

	--------------------------------------------------
	-- LEFT
	--------------------------------------------------

	if left then

		clearGameplayAttributes(
			left
		)

		local parts =
			getPlatformParts(
				left
			)

		for _, part in ipairs(
			parts
		) do

			part.Anchored =
				true

			part.CanCollide =
				false

			part.CanTouch =
				false

			part.CanQuery =
				false

			part.Color =
				PREVIEW_COLOR

			part.Transparency =
				0.25

		end

	else

		warn(
			"[OilCoursePreview] Missing OilPlatformL in row:",
			rowNumber
		)

	end

	--------------------------------------------------
	-- RIGHT
	--------------------------------------------------

	if right then

		clearGameplayAttributes(
			right
		)

		local parts =
			getPlatformParts(
				right
			)

		for _, part in ipairs(
			parts
		) do

			part.Anchored =
				true

			part.CanCollide =
				false

			part.CanTouch =
				false

			part.CanQuery =
				false

			part.Color =
				PREVIEW_COLOR

			part.Transparency =
				0.25

		end

	else

		warn(
			"[OilCoursePreview] Missing OilPlatformR in row:",
			rowNumber
		)

	end

	--------------------------------------------------
	-- PARENT
	--------------------------------------------------

	oilRow.Parent =
		lobbyCourse

end

--------------------------------------------------
-- VERIFY
--------------------------------------------------

local partCount = 0
local collidableCount = 0
local queryableCount = 0
local touchableCount = 0

for _, object in ipairs(
	lobbyCourse:GetDescendants()
) do

	if object:IsA("BasePart") then

		partCount += 1

		if object.CanCollide then
			collidableCount += 1
		end

		if object.CanQuery then
			queryableCount += 1
		end

		if object.CanTouch then
			touchableCount += 1
		end

	end

end

--------------------------------------------------
-- RESULT
--------------------------------------------------

print("================================")
print("[OilCoursePreview] PREVIEW READY")
print(
	"[OilCoursePreview] Rows:",
	NUMBER_OF_ROWS
)
print(
	"[OilCoursePreview] Parts:",
	partCount
)
print(
	"[OilCoursePreview] Collidable:",
	collidableCount
)
print(
	"[OilCoursePreview] Queryable:",
	queryableCount
)
print(
	"[OilCoursePreview] Touchable:",
	touchableCount
)
print("================================")
