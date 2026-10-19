--------------------------------------------------
-- WIN COURSE GENERATOR
--
-- SERVER ONLY
--
-- SINGLE SOURCE OF TRUTH FOR:
--
-- 1. Win Course layout
-- 2. Win Course starting position
-- 3. Win Course direction
-- 4. Tile spacing
-- 5. Win amounts
-- 6. Win tile colors
--
-- TEMPLATE:
--
-- ServerStorage
--   > Templates
--       > WinTile
--
-- EXPECTED WIN TILE:
--
-- WinTile
-- ├── Floor
-- │
-- └── TrophyDisplay
--     └── SurfaceGui
--         ├── ImageLabel
--         └── WinAmount
--
-- IMPORTANT:
--
-- Floor is colored directly.
--
-- There is NO ColorOverlay.
-- There is NO TrophyDecal.
-- There is NO BillboardGui.
-- There is NO TrophyRenderPlane.
--
-- The SurfaceGui is part of the WinTile template
-- and is not recreated by this generator.
--------------------------------------------------

local ServerStorage =
	game:GetService("ServerStorage")


--------------------------------------------------
-- MODULE
--------------------------------------------------

local WinCourseGenerator = {}


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local templates =
	ServerStorage:WaitForChild(
		"Templates"
	)

local winTileTemplate =
	templates:WaitForChild(
		"WinTile"
	)

local course =
	workspace:WaitForChild(
		"Course"
	)


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local START_POSITION =
	Vector3.new(
		-64.726, 63.444, 353.244
	)


--------------------------------------------------
-- TILE SPACING
--------------------------------------------------

local TILE_SPACING =
	43


--------------------------------------------------
-- COURSE DIRECTION
--
-- IMPORTANT:
--
-- This is now the OFFICIAL direction of the
-- generated Win Course.
--
-- The tiles are currently generated forward
-- along +Z.
--
-- Tile 1:
--     StartPosition
--
-- Tile 2:
--     StartPosition + (0, 0, 43)
--
-- Tile 3:
--     StartPosition + (0, 0, 86)
--
-- etc.
--
-- WinCourseProgressService uses this exact
-- direction when moving the ball.
--------------------------------------------------

local COURSE_DIRECTION =
	Vector3.new(
		0,
		0,
		1
	)


--------------------------------------------------
-- WIN AMOUNTS
--------------------------------------------------

local WIN_AMOUNTS = {

	1,
	2,
	3,
	5,
	7,
	10,
	15,
	20,
	25,
	30,
	35,
	40,

}


--------------------------------------------------
-- WIN COLORS
--------------------------------------------------

local WIN_COLORS = {

	[1] =
		Color3.fromRGB(
			120,
			255,
			180
		),

	[2] =
		Color3.fromRGB(
			80,
			255,
			230
		),

	[3] =
		Color3.fromRGB(
			80,
			200,
			255
		),

	[5] =
		Color3.fromRGB(
			120,
			255,
			70
		),

	[7] =
		Color3.fromRGB(
			210,
			255,
			60
		),

	[10] =
		Color3.fromRGB(
			255,
			245,
			60
		),

	[15] =
		Color3.fromRGB(
			255,
			170,
			40
		),

	[20] =
		Color3.fromRGB(
			255,
			80,
			40
		),

	[25] =
		Color3.fromRGB(
			255,
			50,
			130
		),

	[30] =
		Color3.fromRGB(
			255,
			50,
			255
		),

	[35] =
		Color3.fromRGB(
			170,
			60,
			255
		),

	[40] =
		Color3.fromRGB(
			255,
			255,
			255
		),

}


--------------------------------------------------
-- RAINBOW COLORS
--------------------------------------------------

local RAINBOW_COLORS = {

	Color3.fromRGB(
		255,
		60,
		60
	),

	Color3.fromRGB(
		255,
		170,
		40
	),

	Color3.fromRGB(
		255,
		255,
		50
	),

	Color3.fromRGB(
		80,
		255,
		100
	),

	Color3.fromRGB(
		60,
		220,
		255
	),

	Color3.fromRGB(
		80,
		100,
		255
	),

	Color3.fromRGB(
		210,
		70,
		255
	),

	Color3.fromRGB(
		255,
		70,
		200
	),

}


--------------------------------------------------
-- FIND REQUIRED CHILD
--------------------------------------------------

local function findRequiredChild(
	parent,
	name,
	className
)

	local object =
		parent:FindFirstChild(
			name,
			true
		)

	if not object then

		error(
			"[WinCourseGenerator] Missing "
				.. name
				.. " inside "
				.. parent:GetFullName()
		)

	end


	if className
		and not object:IsA(className) then

		error(
			"[WinCourseGenerator] "
				.. object:GetFullName()
				.. " must be a "
				.. className
		)

	end


	return object

end


--------------------------------------------------
-- VALIDATE TEMPLATE
--
-- EXACT HIERARCHY:
--
-- WinTile
-- ├── Floor
-- └── TrophyDisplay
--     └── SurfaceGui
--         ├── ImageLabel
--         └── WinAmount
--------------------------------------------------

local function validateTemplate()

	if not winTileTemplate:IsA("Model") then

		error(
			"[WinCourseGenerator] "
				.. "Templates.WinTile must be a Model."
		)

	end


	--------------------------------------------------
	-- FLOOR
	--------------------------------------------------

	local floor =
		findRequiredChild(
			winTileTemplate,
			"Floor",
			"BasePart"
		)


	--------------------------------------------------
	-- TROPHY DISPLAY
	--------------------------------------------------

	local trophyDisplay =
		findRequiredChild(
			winTileTemplate,
			"TrophyDisplay",
			"BasePart"
		)


	--------------------------------------------------
	-- SURFACE GUI
	--------------------------------------------------

	local surfaceGui =
		findRequiredChild(
			trophyDisplay,
			"SurfaceGui",
			"SurfaceGui"
		)


	--------------------------------------------------
	-- IMAGE LABEL
	--------------------------------------------------

	local imageLabel =
		findRequiredChild(
			surfaceGui,
			"ImageLabel",
			"ImageLabel"
		)


	--------------------------------------------------
	-- WIN AMOUNT
	--------------------------------------------------

	local winAmount =
		findRequiredChild(
			surfaceGui,
			"WinAmount",
			"TextLabel"
		)


	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print("================================")

	print(
		"[WinCourseGenerator] TEMPLATE VALID"
	)

	print("================================")

	print(
		"[WinCourseGenerator] WinTile:",
		winTileTemplate:GetFullName()
	)

	print(
		"[WinCourseGenerator] Floor:",
		floor:GetFullName()
	)

	print(
		"[WinCourseGenerator] Floor Color:",
		floor.Color
	)

	print(
		"[WinCourseGenerator] TrophyDisplay:",
		trophyDisplay:GetFullName()
	)

	print(
		"[WinCourseGenerator] TrophyDisplay Transparency:",
		trophyDisplay.Transparency
	)

	print(
		"[WinCourseGenerator] SurfaceGui:",
		surfaceGui:GetFullName()
	)

	print(
		"[WinCourseGenerator] SurfaceGui Enabled:",
		surfaceGui.Enabled
	)

	print(
		"[WinCourseGenerator] SurfaceGui Face:",
		surfaceGui.Face.Name
	)

	print(
		"[WinCourseGenerator] ImageLabel:",
		imageLabel:GetFullName()
	)

	print(
		"[WinCourseGenerator] Image:",
		imageLabel.Image
	)

	print(
		"[WinCourseGenerator] WinAmount:",
		winAmount:GetFullName()
	)

	print(
		"[WinCourseGenerator] WinAmount Text:",
		winAmount.Text
	)

	print("================================")

	return true

end


--------------------------------------------------
-- GET TILE OBJECTS
--
-- EXACT HIERARCHY:
--
-- WinTile
-- ├── Floor
-- └── TrophyDisplay
--     └── SurfaceGui
--         ├── ImageLabel
--         └── WinAmount
--------------------------------------------------

local function getTileObjects(
	tile
)

	--------------------------------------------------
	-- FLOOR
	--------------------------------------------------

	local floor =
		tile:FindFirstChild(
			"Floor"
		)

	if not floor
		or not floor:IsA("BasePart") then

		return nil

	end


	--------------------------------------------------
	-- TROPHY DISPLAY
	--------------------------------------------------

	local trophyDisplay =
		tile:FindFirstChild(
			"TrophyDisplay",
			true
		)

	if not trophyDisplay
		or not trophyDisplay:IsA("BasePart") then

		return nil

	end


	--------------------------------------------------
	-- SURFACE GUI
	--------------------------------------------------

	local surfaceGui =
		trophyDisplay:FindFirstChild(
			"SurfaceGui"
		)

	if not surfaceGui
		or not surfaceGui:IsA("SurfaceGui") then

		return nil

	end


	--------------------------------------------------
	-- IMAGE LABEL
	--------------------------------------------------

	local imageLabel =
		surfaceGui:FindFirstChild(
			"ImageLabel"
		)

	if not imageLabel
		or not imageLabel:IsA("ImageLabel") then

		return nil

	end


	--------------------------------------------------
	-- WIN AMOUNT
	--------------------------------------------------

	local winAmount =
		surfaceGui:FindFirstChild(
			"WinAmount"
		)

	if not winAmount
		or not winAmount:IsA("TextLabel") then

		return nil

	end


	--------------------------------------------------
	-- RETURN
	--------------------------------------------------

	return {

		Floor =
			floor,

		TrophyDisplay =
			trophyDisplay,

		SurfaceGui =
			surfaceGui,

		ImageLabel =
			imageLabel,

		WinAmount =
			winAmount,

	}

end


--------------------------------------------------
-- CONFIGURE WIN AMOUNT
--------------------------------------------------

local function configureWinAmount(
	winAmount,
	winAmountValue
)

	if not winAmount
		or not winAmount:IsA("TextLabel") then

		return false

	end


	winAmount.Text =
		"+" ..
		tostring(
			winAmountValue
		)


	winAmount.Visible =
		true


	return true

end


--------------------------------------------------
-- APPLY RAINBOW
--
-- 40 TILE
--
-- Floor receives rainbow attributes.
--
-- No ColorOverlay.
--------------------------------------------------

local function applyRainbow(
	floor
)

	floor:SetAttribute(
		"Rainbow",
		true
	)

	floor:SetAttribute(
		"RainbowIndex",
		1
	)

	floor.Color =
		RAINBOW_COLORS[1]

end


--------------------------------------------------
-- VARIABLE TILE LENGTH
--
-- Small win numbers (1-40) get a SHORT box; the boxes grow with the number
-- and stay at MAX_TILE_LENGTH from +65 on. The tile's pivot
-- is its START edge, so a tile spans
--   [GetTileStartDistance(i), GetTileStartDistance(i) + GetTileLength(i)).
-- The Progress service credits the tile whose span contains the ball, so the
-- tile the ball lands on is the tile it is paid for.
--------------------------------------------------

local TILE_WIDTH_SCALE = 1.5 -- must match the oil course widening
local MIN_TILE_LENGTH = 40 -- the first tile is the smallest
local MAX_TILE_LENGTH = 80 -- reached at FULL_TILE_AMOUNT, then constant
local FULL_TILE_AMOUNT = 65
local RAINBOW_TILE_AMOUNT = 110 -- +110 and up are the long rainbow tiles
local RAINBOW_TILE_LENGTH = 130

local function amountForIndex(index)
	if index <= #WIN_AMOUNTS then
		return WIN_AMOUNTS[index]
	end
	return 40 + (index - #WIN_AMOUNTS)
end

local function tileLengthForAmount(amount)
	if amount >= RAINBOW_TILE_AMOUNT then
		return RAINBOW_TILE_LENGTH -- long, so the ball rarely chains more of them
	end
	if amount >= FULL_TILE_AMOUNT then
		return MAX_TILE_LENGTH
	end
	local alpha = (amount - 1) / (FULL_TILE_AMOUNT - 1)
	return math.floor((MIN_TILE_LENGTH + (MAX_TILE_LENGTH - MIN_TILE_LENGTH) * alpha) * 2 + 0.5) / 2
end

local tileStarts = { 0 } -- tileStarts[i] = start distance of tile i

local function tileStartDistance(index)
	while #tileStarts < index do
		local last = #tileStarts
		tileStarts[last + 1] = tileStarts[last] + tileLengthForAmount(amountForIndex(last))
	end
	return tileStarts[index]
end

local function tileIndexAtDistance(distance)
	local index = 1
	while tileStartDistance(index + 1) <= distance do
		index += 1
	end
	return index
end

-- Resizes a tile's Floor (and its trophy display) to this index's length,
-- keeping the pivot (the START edge) where it is.
local function shapeTile(tile, index)
	local objects = getTileObjects(tile)
	if not objects then
		return
	end

	local length = tileLengthForAmount(amountForIndex(index))
	local floor = objects.Floor
	local trophy = objects.TrophyDisplay

	local pivot = tile:GetPivot()
	local dirL = pivot:VectorToObjectSpace(COURSE_DIRECTION)

	local function alongAxis(part)
		if math.abs(part.CFrame.RightVector:Dot(COURSE_DIRECTION)) > 0.5 then
			return "X"
		end
		return "Z"
	end

	local floorAxis = alongAxis(floor)
	local trophyAxis = alongAxis(trophy)

	local floorRel = pivot:ToObjectSpace(floor.CFrame)
	local trophyRel = pivot:ToObjectSpace(trophy.CFrame)

	local oldFloorAlong = floorRel.Position:Dot(dirL)
	local trophyAhead = trophyRel.Position:Dot(dirL) - oldFloorAlong

	local floorSize = floor.Size
	local overlap = floorSize[floorAxis] - TILE_SPACING
	local newFloorLength = length + math.max(overlap, 0)

	local f = math.clamp(length / TILE_SPACING, 0.6, 1.5)

	-- the lane is wider than the original template (matches the oil course)
	local lane = TILE_WIDTH_SCALE
	floor.Size = Vector3.new(
		floorAxis == "X" and newFloorLength or floorSize.X * lane,
		floorSize.Y,
		floorAxis == "Z" and newFloorLength or floorSize.Z * lane
	)

	local newFloorAlong = newFloorLength / 2
	floor.CFrame = pivot * (floorRel + dirL * (newFloorAlong - oldFloorAlong))

	local trophySize = trophy.Size
	trophy.Size = Vector3.new(trophySize.X * f, trophySize.Y, trophySize.Z * f)
	local newTrophyAlong = newFloorAlong + trophyAhead * f
	trophy.CFrame = pivot * (trophyRel + dirL * (newTrophyAlong - trophyRel.Position:Dot(dirL)))

	tile:SetAttribute("TileLength", length)
	tile:SetAttribute("TileStart", tileStartDistance(index))
end
local VARIANT_COLORS = {
	Color3.fromRGB(240, 128, 128),
	Color3.fromRGB(240, 172, 100),
	Color3.fromRGB(232, 214, 104),
	Color3.fromRGB(128, 212, 138),
	Color3.fromRGB(104, 196, 224),
	Color3.fromRGB(138, 148, 240),
	Color3.fromRGB(196, 128, 232),
	Color3.fromRGB(240, 130, 190),
}

--------------------------------------------------
-- RAINBOW SURFACE (win amounts 110+)
--
-- A rainbow gradient is drawn on the Floor's top face. The trophy display
-- sits just above the floor, so the trophy and win amount stay on top.
--------------------------------------------------

local RAINBOW_FROM_AMOUNT = 110

local function applyRainbowSurface(floor)
	if floor:FindFirstChild("RainbowSurface") then
		return
	end

	local surface = Instance.new("SurfaceGui")
	surface.Name = "RainbowSurface"
	surface.Face = Enum.NormalId.Top
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 8
	surface.LightInfluence = 0
	surface.Brightness = 1.2
	surface.ZOffset = -5 -- draw behind the trophy display's gui
	surface.Parent = floor

	local band = Instance.new("Frame")
	band.Size = UDim2.fromScale(1, 1)
	band.BorderSizePixel = 0
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	-- translucent, so the floor's own material still shows through
	band.BackgroundTransparency = 0.42
	band.Parent = surface

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(226, 110, 120)),
		ColorSequenceKeypoint.new(0.17, Color3.fromRGB(230, 158, 96)),
		ColorSequenceKeypoint.new(0.34, Color3.fromRGB(226, 212, 108)),
		ColorSequenceKeypoint.new(0.50, Color3.fromRGB(120, 208, 138)),
		ColorSequenceKeypoint.new(0.67, Color3.fromRGB(106, 190, 220)),
		ColorSequenceKeypoint.new(0.84, Color3.fromRGB(150, 132, 224)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(220, 124, 186)),
	})
	gradient.Parent = band

	-- a light neutral base: the floor keeps the SAME material / texture as the
	-- other win tiles and the soft gradient tints it
	floor.Color = Color3.fromRGB(232, 232, 238)
	floor:SetAttribute("Rainbow", true)

	-- lift the trophy display a little so it always draws above the gradient
	local trophy = floor.Parent and floor.Parent:FindFirstChild("TrophyDisplay")
	if trophy then
		trophy.CFrame = trophy.CFrame + Vector3.new(0, 0.12, 0)
		local trophyGui = trophy:FindFirstChildOfClass("SurfaceGui")
		if trophyGui then
			trophyGui.ZOffset = 5
		end
	end
end
--------------------------------------------------
-- POSITION COMPLETE TILE
--
-- ONLY THE COMPLETE MODEL MOVES.
--
-- IMPORTANT:
--
-- This uses the SAME COURSE_DIRECTION that
-- WinCourseProgressService will use for the ball.
--------------------------------------------------

local function positionTile(
	tile,
	index
)

	shapeTile(tile, index)

	local templatePivot =
		tile:GetPivot()


	local rotationOnly =
		templatePivot
		-
		templatePivot.Position


	local targetPosition =
		START_POSITION
		+
		COURSE_DIRECTION
		*
		tileStartDistance(index)


	tile:PivotTo(
		CFrame.new(
			targetPosition
		)
		*
		rotationOnly
	)


	print(
		"[WinCourseGenerator] Positioned:",
		tile.Name,
		"| Index:",
		index,
		"| Position:",
		tile:GetPivot().Position
	)

end


--------------------------------------------------
-- CONFIGURE TILE
--------------------------------------------------

local function configureTile(
	tile,
	winAmount,
	index
)

	print(
		"[WinCourseGenerator] CONFIGURING:",
		tile.Name,
		"| Amount:",
		winAmount
	)


	--------------------------------------------------
	-- GET OBJECTS
	--------------------------------------------------

	local objects =
		getTileObjects(
			tile
		)


	if not objects then

		warn(
			"[WinCourseGenerator] Invalid WinTile hierarchy:",
			tile:GetFullName()
		)

		return false

	end


	--------------------------------------------------
	-- WIN TEXT
	--------------------------------------------------

	if not configureWinAmount(
		objects.WinAmount,
		winAmount
	) then

		warn(
			"[WinCourseGenerator] Failed to configure WinAmount:",
			tile:GetFullName()
		)

		return false

	end


	--------------------------------------------------
	-- FLOOR COLOR
	--------------------------------------------------

	local color =
		WIN_COLORS[winAmount]


	if color then

		objects.Floor.Color =
			color

	elseif winAmount > 40 and winAmount < RAINBOW_FROM_AMOUNT then

		-- Same floor material, a different colour per amount (cycling softly
		-- through the palette), so the long stretch before the rainbow stays
		-- varied instead of one flat colour.
		objects.Floor.Color =
			VARIANT_COLORS[(winAmount % #VARIANT_COLORS) + 1]

	end


	--------------------------------------------------
	-- RAINBOW 80+ (gradient surface)

	if winAmount >= RAINBOW_FROM_AMOUNT then
		applyRainbowSurface(objects.Floor)
	end

	-- RAINBOW 40
	--------------------------------------------------

	if winAmount == 40 then

		applyRainbow(
			objects.Floor
		)

	end


	--------------------------------------------------
	-- SURFACE GUI
	--
	-- EXISTING TEMPLATE ONLY.
	--
	-- We do not create anything.
	--------------------------------------------------

	objects.SurfaceGui.Enabled =
		true

	objects.ImageLabel.Visible =
		true

	objects.WinAmount.Visible =
		true


	--------------------------------------------------
	-- ATTRIBUTES
	--------------------------------------------------

	tile:SetAttribute(
		"WinAmount",
		winAmount
	)

	tile:SetAttribute(
		"Collected",
		false
	)

	tile:SetAttribute(
		"TileIndex",
		index
	)

	tile:SetAttribute(
		"IsRainbow",
		winAmount == 40
	)

	tile:SetAttribute(
		"IsWinCourseTile",
		true
	)


	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	print(
		"[WinCourseGenerator] TILE CONFIGURED:",
		tile.Name,
		"| Amount:",
		winAmount
	)

	print(
		"[WinCourseGenerator] Floor:",
		objects.Floor:GetFullName()
	)

	print(
		"[WinCourseGenerator] Floor Color:",
		objects.Floor.Color
	)

	print(
		"[WinCourseGenerator] TrophyDisplay:",
		objects.TrophyDisplay:GetFullName()
	)

	print(
		"[WinCourseGenerator] SurfaceGui:",
		objects.SurfaceGui:GetFullName()
	)

	print(
		"[WinCourseGenerator] ImageLabel:",
		objects.ImageLabel:GetFullName()
	)

	print(
		"[WinCourseGenerator] Image:",
		objects.ImageLabel.Image
	)

	print(
		"[WinCourseGenerator] WinAmount:",
		objects.WinAmount:GetFullName()
	)

	print(
		"[WinCourseGenerator] WinAmount Text:",
		objects.WinAmount.Text
	)


	return true

end


--------------------------------------------------
-- VERIFY TILE UI
--------------------------------------------------

local function verifyTileUI(
	tile
)

	local objects =
		getTileObjects(
			tile
	)


	if not objects then

		warn(
			"[WinCourseGenerator] UI verification failed:",
			tile:GetFullName()
		)

		return false

	end


	print(
		"[WinCourseGenerator] FINAL UI VERIFIED:",
		tile.Name
	)

	print(
		"[WinCourseGenerator] TrophyDisplay:",
		objects.TrophyDisplay:GetFullName()
	)

	print(
		"[WinCourseGenerator] TrophyDisplay Position:",
		objects.TrophyDisplay.Position
	)

	print(
		"[WinCourseGenerator] TrophyDisplay Transparency:",
		objects.TrophyDisplay.Transparency
	)

	print(
		"[WinCourseGenerator] SurfaceGui:",
		objects.SurfaceGui:GetFullName()
	)

	print(
		"[WinCourseGenerator] SurfaceGui Enabled:",
		objects.SurfaceGui.Enabled
	)

	print(
		"[WinCourseGenerator] SurfaceGui Face:",
		objects.SurfaceGui.Face.Name
	)

	print(
		"[WinCourseGenerator] ImageLabel:",
		objects.ImageLabel:GetFullName()
	)

	print(
		"[WinCourseGenerator] Image:",
		objects.ImageLabel.Image
	)

	print(
		"[WinCourseGenerator] Image Visible:",
		objects.ImageLabel.Visible
	)

	print(
		"[WinCourseGenerator] WinAmount:",
		objects.WinAmount:GetFullName()
	)

	print(
		"[WinCourseGenerator] WinAmount Text:",
		objects.WinAmount.Text
	)

	print(
		"[WinCourseGenerator] WinAmount Visible:",
		objects.WinAmount.Visible
	)


	return true

end


--------------------------------------------------
-- GENERATE
--------------------------------------------------

function WinCourseGenerator.Generate()

	print("================================")

	print(
		"[WinCourseGenerator] START GENERATE"
	)

	print("================================")


	--------------------------------------------------
	-- VALIDATE TEMPLATE
	--------------------------------------------------

	validateTemplate()


	--------------------------------------------------
	-- REMOVE OLD WIN COURSE
	--------------------------------------------------

	local oldCourse =
		course:FindFirstChild(
			"WinCourse"
		)


	if oldCourse then

		print(
			"[WinCourseGenerator] Removing old WinCourse:",
			oldCourse:GetFullName()
		)

		oldCourse:Destroy()

	end


	--------------------------------------------------
	-- REMOVE LEFTOVER PREVIEW
	--------------------------------------------------

	local oldPreview =
		course:FindFirstChild(
			"WinCoursePreview"
		)


	if oldPreview then

		print(
			"[WinCourseGenerator] Removing old preview:",
			oldPreview:GetFullName()
		)

		oldPreview:Destroy()

	end


	--------------------------------------------------
	-- CREATE WIN COURSE FOLDER
	--------------------------------------------------

	local winCourse =
		Instance.new(
			"Folder"
		)


	winCourse.Name =
		"WinCourse"


	winCourse:SetAttribute(
		"IsWinCourse",
		true
	)


	winCourse:SetAttribute(
		"TileCount",
		#WIN_AMOUNTS
	)


	winCourse:SetAttribute(
		"TileSpacing",
		TILE_SPACING
	)


	--------------------------------------------------
	-- STORE OFFICIAL DIRECTION ON COURSE
	--
	-- This is useful for debugging and allows other
	-- server systems to inspect the generated course.
	--------------------------------------------------

	winCourse:SetAttribute(
		"CourseDirectionX",
		COURSE_DIRECTION.X
	)

	winCourse:SetAttribute(
		"CourseDirectionY",
		COURSE_DIRECTION.Y
	)

	winCourse:SetAttribute(
		"CourseDirectionZ",
		COURSE_DIRECTION.Z
	)


	winCourse.Parent =
		course


	--------------------------------------------------
	-- GENERATE TILES
	--------------------------------------------------

	for index, winAmount in ipairs(
		WIN_AMOUNTS
	) do

		print("--------------------------------")

		print(
			"[WinCourseGenerator] TILE",
			index,
			"/",
			#WIN_AMOUNTS,
			"| WIN:",
			winAmount
		)


		--------------------------------------------------
		-- CLONE COMPLETE TILE
		--------------------------------------------------

		local tile =
			winTileTemplate:Clone()


		tile.Name =
			"WinTile_"
			..
			tostring(
				winAmount
			)


		--------------------------------------------------
		-- CONFIGURE
		--------------------------------------------------

		local configured =
			configureTile(
				tile,
				winAmount,
				index
			)


		if not configured then

			tile:Destroy()

			warn(
				"[WinCourseGenerator] FAILED TO CONFIGURE:",
				winAmount
			)

			continue

		end


		--------------------------------------------------
		-- POSITION COMPLETE TILE
		--------------------------------------------------

		positionTile(
			tile,
			index
		)


		--------------------------------------------------
		-- PARENT
		--------------------------------------------------

		tile.Parent =
			winCourse


		--------------------------------------------------
		-- VERIFY
		--------------------------------------------------

		verifyTileUI(
			tile
		)


		print(
			"[WinCourseGenerator] SPAWNED:",
			tile:GetFullName()
		)

	end


	--------------------------------------------------
	-- FINAL
	--------------------------------------------------

	print("================================")

	print(
		"[WinCourseGenerator] COMPLETE"
	)

	print(
		"[WinCourseGenerator] Tiles:",
		#winCourse:GetChildren(),
		"/",
		#WIN_AMOUNTS
	)

	print(
		"[WinCourseGenerator] Start:",
		START_POSITION
	)

	print(
		"[WinCourseGenerator] Direction:",
		COURSE_DIRECTION
	)

	print(
		"[WinCourseGenerator] Spacing:",
		TILE_SPACING
	)

	print(
		"[WinCourseGenerator] Existing Course flooring was NOT moved."
	)

	print(
		"[WinCourseGenerator] SurfaceGui comes from WinTile template."
	)

	print(
		"[WinCourseGenerator] SurfaceGui children:",
		"ImageLabel + WinAmount"
	)

	print(
		"[WinCourseGenerator] No UI Frame used."
	)

	print(
		"[WinCourseGenerator] No ColorOverlay used."
	)

	print(
		"[WinCourseGenerator] No BillboardGui used."
	)

	print(
		"[WinCourseGenerator] No TrophyDecal used."
	)

	print(
		"[WinCourseGenerator] No TrophyRenderPlane used."
	)

	print("================================")


	return winCourse

end

--------------------------------------------------
-- ENSURE TILES EXIST THROUGH A DISTANCE
--
-- Appends from the LAST existing tile index.
-- Generates farther ahead of the ball.
--------------------------------------------------

local TILE_LOOKAHEAD_DISTANCE = 1100 -- ~25 tile spacings (4+ s at top speed)

function WinCourseGenerator.EnsureTilesThroughDistance(distance)

	if typeof(distance) ~= "number"
		or distance ~= distance
		or distance == math.huge
		or distance == -math.huge then
		return false
	end

	local winCourse = course:FindFirstChild("WinCourse")

	if not winCourse
		or winCourse:GetAttribute("IsWinCourse") ~= true then
		return false
	end

	distance = math.max(0, distance)

	-- Generate ten tiles beyond the requested distance.
	local requiredIndex =
		tileIndexAtDistance(distance + TILE_LOOKAHEAD_DISTANCE) + 1

	local highestIndex = 0

	for _, child in ipairs(winCourse:GetChildren()) do
		if child:IsA("Model")
			and child.Name:match("^WinTile_") then

			local index = child:GetAttribute("TileIndex")

			if typeof(index) == "number"
				and index % 1 == 0
				and index > highestIndex then
				highestIndex = index
			end
		end
	end

	-- Never regenerate or reset existing indices.
	if requiredIndex <= highestIndex then
		return true
	end

	for index = highestIndex + 1, requiredIndex do

		--------------------------------------------------
-- CONTINUOUS WIN AMOUNTS
--
-- Tile 1  = +1
-- Tile 12 = +40
-- Tile 13 = +41
-- Tile 14 = +42
-- etc.
--------------------------------------------------

local winAmount

if index <= #WIN_AMOUNTS then
	winAmount = WIN_AMOUNTS[index]
else
	winAmount = 40 + (index - #WIN_AMOUNTS)
end

		local tile = winTileTemplate:Clone()

		tile.Name =
			"WinTile_"
			.. tostring(winAmount)
			.. "_"
			.. tostring(index)

		if not configureTile(tile, winAmount, index) then
			tile:Destroy()

			warn(
				"[WinCourseGenerator] Failed to configure tile:",
				index
			)

			return false
		end

		positionTile(tile, index)
		tile.Parent = winCourse

		print(
			"[WinCourseGenerator] APPENDED:",
			tile.Name,
			"| Index:",
			index,
			"| Win:",
			winAmount,
			"| Distance:",
			tileStartDistance(index)
		)
	end

	winCourse:SetAttribute("TileCount", requiredIndex)

	return true
end


--------------------------------------------------
-- PUBLIC CONFIG
--------------------------------------------------

function WinCourseGenerator.GetWinAmounts()

	local result = {}


	for index, amount in ipairs(
		WIN_AMOUNTS
	) do

		result[index] =
			amount

	end


	return result

end


--------------------------------------------------

function WinCourseGenerator.GetStartPosition()

	return START_POSITION

end


function WinCourseGenerator.GetTileStartDistance(index)
	return tileStartDistance(index)
end

function WinCourseGenerator.GetTileLength(index)
	return tileLengthForAmount(amountForIndex(index))
end

function WinCourseGenerator.GetTileIndexAtDistance(distance)
	return tileIndexAtDistance(math.max(0, distance))
end

function WinCourseGenerator.ShapeTile(tile, index)
	shapeTile(tile, index)
end

--------------------------------------------------

function WinCourseGenerator.GetTileSpacing()

	return TILE_SPACING

end


--------------------------------------------------
-- OFFICIAL COURSE DIRECTION
--
-- IMPORTANT:
--
-- WinCourseProgressService MUST use this instead
-- of calculating direction from the tiles.
--------------------------------------------------

function WinCourseGenerator.GetCourseDirection()

	return COURSE_DIRECTION

end


--------------------------------------------------
-- RETURN
--------------------------------------------------

return WinCourseGenerator
