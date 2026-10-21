--[[
	WinCoursePreviewService

	LOCATION:
	ServerScriptService
		> WinCoursePreviewService

	TEMPLATE:
	ServerStorage
		> Templates
			> WinTile

	EXPECTED WIN TILE:

	WinTile
	├── Floor
	│
	└── TrophyDisplay
	    └── SurfaceGui
	        ├── ImageLabel
	        └── WinAmount

	PURPOSE:
	- Creates the lobby Win Course preview.
	- Clones the COMPLETE WinTile.
	- Colors the Floor directly.
	- Uses the existing TrophyDisplay SurfaceGui.
	- Uses the existing SurfaceGui ImageLabel.
	- Uses the existing SurfaceGui WinAmount.
	- Does NOT create a SurfaceGui.
	- Does NOT create a BillboardGui.
	- Does NOT create a UI Frame.
	- Does NOT create a TrophyRenderPlane.
	- Does NOT create ColorOverlay.
	- Does NOT create extra parts.
	- Moves only the complete WinTile model.

	IMPORTANT:
	WinCourseGenerator is the source of truth for:
	- Win amounts
	- Start position
	- Tile spacing
]]

--------------------------------------------------
-- SERVICES
--------------------------------------------------

local ServerStorage =
	game:GetService("ServerStorage")

local ServerScriptService =
	game:GetService("ServerScriptService")

local Workspace =
	game:GetService("Workspace")

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local DEBUG = true

local COURSE_NAME =
	"Course"

local PREVIEW_NAME =
	"WinCoursePreview"

local TEMPLATE_FOLDER_NAME =
	"Templates"

local TEMPLATE_NAME =
	"WinTile"

local START_EVENT_NAME =
	"StartWinCourse"

--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local templates =
	ServerStorage:WaitForChild(
		TEMPLATE_FOLDER_NAME
	)

local winTileTemplate =
	templates:WaitForChild(
		TEMPLATE_NAME
	)

local course =
	Workspace:WaitForChild(
		COURSE_NAME
	)

--------------------------------------------------
-- WIN COURSE GENERATOR
--------------------------------------------------

local generatorModule =
	ServerScriptService:WaitForChild(
		"WinCourseGenerator"
	)

assert(
	generatorModule:IsA("ModuleScript"),
	"[WinCoursePreviewService] WinCourseGenerator must be a ModuleScript."
)

local requireSuccess,
	WinCourseGenerator =
	pcall(function()

		return require(generatorModule)

	end)

assert(
	requireSuccess,
	"[WinCoursePreviewService] Failed to require WinCourseGenerator: "
		.. tostring(WinCourseGenerator)
)

assert(
	type(WinCourseGenerator) == "table",
	"[WinCoursePreviewService] WinCourseGenerator must return a table."
)

assert(
	type(WinCourseGenerator.GetWinAmounts) == "function",
	"[WinCoursePreviewService] WinCourseGenerator.GetWinAmounts() is missing."
)

assert(
	type(WinCourseGenerator.GetStartPosition) == "function",
	"[WinCoursePreviewService] WinCourseGenerator.GetStartPosition() is missing."
)

assert(
	type(WinCourseGenerator.GetTileSpacing) == "function",
	"[WinCoursePreviewService] WinCourseGenerator.GetTileSpacing() is missing."
)

--------------------------------------------------
-- OFFICIAL CONFIG
--------------------------------------------------

local WIN_AMOUNTS =
	WinCourseGenerator.GetWinAmounts()

local START_POSITION =
	WinCourseGenerator.GetStartPosition()

local TILE_SPACING =
	WinCourseGenerator.GetTileSpacing()

assert(
	type(WIN_AMOUNTS) == "table",
	"[WinCoursePreviewService] Generator win amounts must be a table."
)

assert(
	typeof(START_POSITION) == "Vector3",
	"[WinCoursePreviewService] Generator start position must be a Vector3."
)

assert(
	typeof(TILE_SPACING) == "number",
	"[WinCoursePreviewService] Generator tile spacing must be a number."
)

--------------------------------------------------
-- WIN COLORS
--------------------------------------------------

local WIN_COLORS = {

	[1] = Color3.fromRGB(120, 255, 180),

	[2] = Color3.fromRGB(80, 255, 230),

	[3] = Color3.fromRGB(80, 200, 255),

	[5] = Color3.fromRGB(120, 255, 70),

	[7] = Color3.fromRGB(210, 255, 60),

	[10] = Color3.fromRGB(255, 245, 60),

	[15] = Color3.fromRGB(255, 170, 40),

	[20] = Color3.fromRGB(255, 80, 40),

	[25] = Color3.fromRGB(255, 50, 130),

	[30] = Color3.fromRGB(255, 50, 255),

	[35] = Color3.fromRGB(170, 60, 255),

	[40] = Color3.fromRGB(255, 255, 255),

}

--------------------------------------------------
-- RAINBOW COLORS
--------------------------------------------------

local RAINBOW_COLORS = {

	Color3.fromRGB(255, 60, 60),

	Color3.fromRGB(255, 170, 40),

	Color3.fromRGB(255, 255, 50),

	Color3.fromRGB(80, 255, 100),

	Color3.fromRGB(60, 220, 255),

	Color3.fromRGB(80, 100, 255),

	Color3.fromRGB(210, 70, 255),

	Color3.fromRGB(255, 70, 200),

}

--------------------------------------------------
-- DEBUG
--------------------------------------------------

local function debugPrint(...)

	if DEBUG then

		print(
			"[WinCoursePreviewService]",
			...
		)

	end

end

--------------------------------------------------
-- FIND REQUIRED DIRECT CHILD
--------------------------------------------------

local function findRequiredDirectChild(
	parent,
	name,
	className
)

	local object =
		parent:FindFirstChild(
			name
		)

	assert(
		object,
		"[WinCoursePreviewService] Missing "
			.. name
			.. " inside "
			.. parent:GetFullName()
	)

	if className then

		assert(
			object:IsA(className),
			"[WinCoursePreviewService] "
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
-- │
-- └── TrophyDisplay
--     └── SurfaceGui
--         ├── ImageLabel
--         └── WinAmount
--------------------------------------------------

local function validateTemplate()

	--------------------------------------------------
	-- MODEL
	--------------------------------------------------

	assert(
		winTileTemplate:IsA("Model"),
		"[WinCoursePreviewService] Templates.WinTile must be a Model."
	)

	--------------------------------------------------
	-- FLOOR
	--------------------------------------------------

	local floor =
		findRequiredDirectChild(
			winTileTemplate,
			"Floor",
			"BasePart"
		)

	--------------------------------------------------
	-- TROPHY DISPLAY
	--------------------------------------------------

	local trophyDisplay =
		findRequiredDirectChild(
			winTileTemplate,
			"TrophyDisplay",
			"BasePart"
		)

	--------------------------------------------------
	-- SURFACE GUI
	--------------------------------------------------

	local surfaceGui =
		findRequiredDirectChild(
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
		findRequiredDirectChild(
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
		findRequiredDirectChild(
			surfaceGui,
			"WinAmount",
			"TextLabel"
		)

	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	debugPrint("================================")
	debugPrint("TEMPLATE VALID")
	debugPrint("================================")

	debugPrint(
		"WinTile:",
		winTileTemplate:GetFullName()
	)

	debugPrint(
		"Floor:",
		floor:GetFullName()
	)

	debugPrint(
		"TrophyDisplay:",
		trophyDisplay:GetFullName()
	)

	debugPrint(
		"SurfaceGui:",
		surfaceGui:GetFullName()
	)

	debugPrint(
		"SurfaceGui Face:",
		surfaceGui.Face.Name
	)

	debugPrint(
		"ImageLabel:",
		imageLabel:GetFullName()
	)

	debugPrint(
		"ImageLabel Image:",
		imageLabel.Image
	)

	debugPrint(
		"WinAmount:",
		winAmount:GetFullName()
	)

	debugPrint(
		"WinAmount Text:",
		winAmount.Text
	)

	debugPrint("================================")

	return true

end

--------------------------------------------------
-- GET TILE OBJECTS
--
-- EXACT HIERARCHY:
--
-- Tile
-- ├── Floor
-- │
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
			"TrophyDisplay"
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

		Floor = floor,

		TrophyDisplay = trophyDisplay,

		SurfaceGui = surfaceGui,

		ImageLabel = imageLabel,

		WinAmount = winAmount,

	}

end

--------------------------------------------------
-- APPLY RAINBOW
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
-- ONLY THE COMPLETE MODEL IS MOVED.
--------------------------------------------------

local function positionTile(
	tile,
	index
)

	WinCourseGenerator.ShapeTile(tile, index)

	local templatePivot =
		tile:GetPivot()

	local rotationOnly =
		templatePivot
		-
		templatePivot.Position

	local targetPosition =
		START_POSITION
		+
		Vector3.new(
			0,
			0,
			WinCourseGenerator.GetTileStartDistance(index)
		)

	tile:PivotTo(
		CFrame.new(
			targetPosition
		)
		*
		rotationOnly
	)

	debugPrint(
		"Positioned:",
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
	index,
	amount
)

	debugPrint(
		"CONFIGURING:",
		tile.Name,
		"| Amount:",
		amount
	)

	--------------------------------------------------
	-- GET EXISTING OBJECTS
	--------------------------------------------------

	local objects =
		getTileObjects(tile)

	if not objects then

		warn(
			"[WinCoursePreviewService] Invalid WinTile hierarchy:",
			tile:GetFullName()
		)

		return false

	end

	--------------------------------------------------
	-- NAME
	--------------------------------------------------

	-- always streamed in (see OilCoursePreview): otherwise the far tiles never show
	if tile:IsA("Model") then
		tile.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end

	tile.Name =
		"WinTile_"
		..
		tostring(amount)

	--------------------------------------------------
	-- FLOOR COLOR
	--------------------------------------------------

	local color =
		WIN_COLORS[amount]

	if color then

		objects.Floor.Color =
			color

	end

	--------------------------------------------------
	-- RAINBOW 40
	--------------------------------------------------

	if amount == 40 then

		applyRainbow(
			objects.Floor
		)

	end

	--------------------------------------------------
	-- WIN AMOUNT
	--
	-- Existing TextLabel.
	--------------------------------------------------

	objects.WinAmount.Text =
		"+" ..
		tostring(amount)

	objects.WinAmount.Visible =
		true

	--------------------------------------------------
	-- DO NOT TOUCH IMAGE LABEL
	--
	-- The template owns its image.
	--------------------------------------------------

	--------------------------------------------------
	-- ATTRIBUTES
	--------------------------------------------------

	tile:SetAttribute(
		"WinAmount",
		amount
	)

	tile:SetAttribute(
		"TileIndex",
		index
	)

	tile:SetAttribute(
		"IsWinCoursePreview",
		true
	)

	tile:SetAttribute(
		"IsRainbow",
		amount == 40
	)

	tile:SetAttribute(
		"IsWinCourseTile",
		true
	)

	--------------------------------------------------
	-- DEBUG
	--------------------------------------------------

	debugPrint(
		"TILE CONFIGURED:",
		tile.Name,
		"| Amount:",
		amount
	)

	debugPrint(
		"Floor:",
		objects.Floor:GetFullName()
	)

	debugPrint(
		"Floor Color:",
		objects.Floor.Color
	)

	debugPrint(
		"TrophyDisplay:",
		objects.TrophyDisplay:GetFullName()
	)

	debugPrint(
		"SurfaceGui:",
		objects.SurfaceGui:GetFullName()
	)

	debugPrint(
		"ImageLabel:",
		objects.ImageLabel:GetFullName()
	)

	debugPrint(
		"ImageLabel Image:",
		objects.ImageLabel.Image
	)

	debugPrint(
		"WinAmount:",
		objects.WinAmount:GetFullName()
	)

	debugPrint(
		"WinAmount Text:",
		objects.WinAmount.Text
	)

	return true

end

--------------------------------------------------
-- VERIFY FINAL TILE
--------------------------------------------------

local function verifyClone(tile)

	local objects =
		getTileObjects(tile)

	if not objects then

		warn(
			"[WinCoursePreviewService] Final tile verification failed:",
			tile:GetFullName()
		)

		return false

	end

	debugPrint("================================")

	debugPrint(
		"FINAL TILE CHECK:",
		tile:GetFullName()
	)

	debugPrint(
		"Floor:",
		objects.Floor:GetFullName()
	)

	debugPrint(
		"Floor Color:",
		objects.Floor.Color
	)

	debugPrint(
		"TrophyDisplay:",
		objects.TrophyDisplay:GetFullName()
	)

	debugPrint(
		"TrophyDisplay Transparency:",
		objects.TrophyDisplay.Transparency
	)

	debugPrint(
		"SurfaceGui:",
		objects.SurfaceGui:GetFullName()
	)

	debugPrint(
		"SurfaceGui Face:",
		objects.SurfaceGui.Face.Name
	)

	debugPrint(
		"ImageLabel:",
		objects.ImageLabel:GetFullName()
	)

	debugPrint(
		"ImageLabel Image:",
		objects.ImageLabel.Image
	)

	debugPrint(
		"WinAmount:",
		objects.WinAmount:GetFullName()
	)

	debugPrint(
		"WinAmount Text:",
		objects.WinAmount.Text
	)

	debugPrint(
		"WinAmount Visible:",
		objects.WinAmount.Visible
	)

	debugPrint("================================")

	return true

end

--------------------------------------------------
-- DESTROY PREVIEW
--------------------------------------------------

local function destroyPreview()

	local existing =
		course:FindFirstChild(
			PREVIEW_NAME
		)

	if existing then

		debugPrint(
			"Destroying preview:",
			existing:GetFullName()
		)

		existing:Destroy()

	end

end

--------------------------------------------------
-- CREATE PREVIEW
--------------------------------------------------

local function createPreview()

	destroyPreview()

	--------------------------------------------------
	-- CREATE CONTAINER
	--------------------------------------------------

	local preview =
		Instance.new("Folder")

	preview.Name =
		PREVIEW_NAME

	preview:SetAttribute(
		"IsWinCoursePreview",
		true
	)

	preview:SetAttribute(
		"TileCount",
		#WIN_AMOUNTS
	)

	preview:SetAttribute(
		"TileSpacing",
		TILE_SPACING
	)

	preview.Parent =
		course

	debugPrint("================================")
	debugPrint(
		"CREATING WIN COURSE PREVIEW"
	)
	debugPrint("================================")

	--------------------------------------------------
	-- CREATE TILES
	--------------------------------------------------

	for index, amount in ipairs(
		WIN_AMOUNTS
	) do

		debugPrint(
			"Creating tile:",
			index,
			"| Amount:",
			amount
		)

		--------------------------------------------------
		-- CLONE COMPLETE TILE
		--------------------------------------------------

		local tile =
			winTileTemplate:Clone()

		--------------------------------------------------
		-- CONFIGURE
		--------------------------------------------------

		local success =
			configureTile(
				tile,
				index,
				amount
			)

		if not success then

			tile:Destroy()

			warn(
				"[WinCoursePreviewService] Failed to configure:",
				amount
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
			preview

		--------------------------------------------------
		-- VERIFY
		--------------------------------------------------

		verifyClone(
			tile
		)

		debugPrint(
			"Preview tile created:",
			tile:GetFullName()
		)

	end

	--------------------------------------------------
	-- FINAL DEBUG
	--------------------------------------------------

	debugPrint("================================")

	debugPrint(
		"PREVIEW READY:",
		#preview:GetChildren(),
		"tiles"
	)

	debugPrint(
		"Start:",
		START_POSITION
	)

	debugPrint(
		"Spacing:",
		TILE_SPACING
	)

	debugPrint(
		"Hierarchy:",
		"WinTile > TrophyDisplay > SurfaceGui > ImageLabel + WinAmount"
	)

	debugPrint(
		"Floor is colored directly."
	)

	debugPrint(
		"No UI Frame."
	)

	debugPrint(
		"No ColorOverlay."
	)

	debugPrint(
		"No BillboardGui."
	)

	debugPrint(
		"No TrophyRenderPlane."
	)

	debugPrint("================================")

	return preview

end

--------------------------------------------------
-- FIND START EVENT
--------------------------------------------------

local function findStartEvent()

	local event =
		ServerScriptService:FindFirstChild(
			START_EVENT_NAME
		)

	if event then

		return event

	end

	event =
		ServerStorage:FindFirstChild(
			START_EVENT_NAME
		)

	if event then

		return event

	end

	return nil

end

--------------------------------------------------
-- START EVENT
--------------------------------------------------

local startWinCourse =
	findStartEvent()

assert(
	startWinCourse,
	"[WinCoursePreviewService] Could not find StartWinCourse."
)

assert(
	startWinCourse:IsA("BindableEvent"),
	"[WinCoursePreviewService] StartWinCourse must be a BindableEvent."
)

debugPrint(
	"StartWinCourse:",
	startWinCourse:GetFullName()
)

startWinCourse.Event:Connect(
	function(player)

		debugPrint(
			"StartWinCourse received."
		)

		if player then

			debugPrint(
				"Player:",
				player.Name
			)

		end

		destroyPreview()

		debugPrint(
			"Preview removed."
		)

	end
)

--------------------------------------------------
-- STARTUP
--------------------------------------------------

validateTemplate()

debugPrint("================================")

debugPrint(
	"WinCoursePreviewService STARTING"
)

debugPrint("================================")

createPreview()

debugPrint("================================")

debugPrint(
	"WinCoursePreviewService READY"
)

debugPrint("================================")
