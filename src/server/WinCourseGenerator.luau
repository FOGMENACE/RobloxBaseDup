--------------------------------------------------
-- WIN COURSE GENERATOR
--
-- SERVER ONLY
--
-- SINGLE SOURCE OF TRUTH FOR:
--
-- 1. Win Course layout
-- 2. Win Course starting position
-- 3. Tile spacing
-- 4. Win amounts
-- 5. Win tile colors
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
		-64.726,
		63.444,
		60.539
	)

local TILE_SPACING = 43

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
	--
	-- DIRECT CHILD OF SURFACEGUI
	--------------------------------------------------

	local imageLabel =
		findRequiredChild(
			surfaceGui,
			"ImageLabel",
			"ImageLabel"
		)

	--------------------------------------------------
	-- WIN AMOUNT
	--
	-- DIRECT CHILD OF SURFACEGUI
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

local function getTileObjects(tile)

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
	--
	-- DIRECT CHILD
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
	--
	-- DIRECT CHILD
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
		"+" .. tostring(
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
-- POSITION COMPLETE TILE
--
-- ONLY THE COMPLETE MODEL MOVES.
--------------------------------------------------

local function positionTile(
	tile,
	index
)

	local templatePivot =
		tile:GetPivot()

	local rotationOnly =
		templatePivot
		- templatePivot.Position

	local targetPosition =
		START_POSITION
		+
		Vector3.new(
			0,
			0,
			(index - 1)
				* TILE_SPACING
		)

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

	end

	--------------------------------------------------
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
		Instance.new("Folder")

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
			.. tostring(winAmount)

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

--------------------------------------------------

function WinCourseGenerator.GetTileSpacing()

	return TILE_SPACING

end

--------------------------------------------------
-- RETURN
--------------------------------------------------

return WinCourseGenerator
