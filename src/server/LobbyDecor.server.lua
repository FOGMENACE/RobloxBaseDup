--------------------------------------------------
-- LOBBY DECOR
--
-- SERVER ONLY, additive. Dresses the existing lobby room as a cartoon
-- bowling alley WITHOUT replacing the Studio-built parts:
--   * repaints the grey walls (navy with a pin-red / cream wainscot)
--   * adds a ceiling with warm hanging lamps
--   * ball racks along the east wall, built from the real ball models
--   * clusters of bowling pins in the corners
--   * entrance signs (OIL COURSE over the lane opening, BALL SHOP)
--   * warmer, more colourful lighting
--
-- Everything new lives in Workspace.LobbyDecor (rebuilt on every
-- start; delete the folder to remove it) and is non-colliding, so it
-- cannot affect ball physics. Spinning/pulsing is done client-side by
-- LobbyAnimator, which finds parts tagged "LobbySpin" / "LobbyLamp".
--------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BallAccessories = require(ReplicatedStorage:WaitForChild("BallAccessories"))

-- Room interior (from the Studio layout).
local X_MIN, X_MAX = -105.7, -24.1
local Z_MIN, Z_MAX = -278.4, -196.8
local FLOOR_Y = 63.5
local WALL_TOP = 95

local INK = Color3.fromRGB(24, 22, 34)
local NAVY = Color3.fromRGB(34, 36, 74)
local NAVY_LIGHT = Color3.fromRGB(46, 50, 98)
local CREAM = Color3.fromRGB(255, 247, 232)
local LANE = Color3.fromRGB(240, 178, 82)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local FONT = Enum.Font.FredokaOne

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local old = workspace:FindFirstChild("LobbyDecor")
if old then
	old:Destroy()
end

local decor = create("Folder", { Name = "LobbyDecor" }, workspace)

local function part(name, size, cframe, color, material, extra)
	local props = {
		Name = name,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		CastShadow = false,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	}

	for key, value in pairs(extra or {}) do
		props[key] = value
	end

	return create("Part", props, decor)
end

--------------------------------------------------
-- WALLS: repaint the grey boxes (properties only; parts stay as built)
--------------------------------------------------

local function isWall(instance)
	return instance:IsA("Part")
		and instance.Name == "Part"
		and math.abs(instance.Size.Y - 31.7) < 0.5
end

local paintIndex = 0
for _, instance in ipairs(workspace:GetChildren()) do
	if isWall(instance) then
		paintIndex += 1
		instance.Color = (paintIndex % 2 == 0) and NAVY or NAVY_LIGHT
		instance.Material = Enum.Material.SmoothPlastic
	end
end

-- Wainscot: pin-red band with a cream stripe, hugging the inside of the walls.
local function wainscot(centerX, centerZ, sizeX, sizeZ)
	part("WainscotRed", Vector3.new(sizeX, 4, sizeZ), CFrame.new(centerX, FLOOR_Y + 2.1, centerZ), PIN_RED)
	part("WainscotCream", Vector3.new(sizeX, 0.7, sizeZ), CFrame.new(centerX, FLOOR_Y + 4.5, centerZ), CREAM)
end

local width = X_MAX - X_MIN
local depth = Z_MAX - Z_MIN
wainscot((X_MIN + X_MAX) / 2, Z_MIN + 0.15, width, 0.3) -- back
wainscot(X_MIN + 0.15, (Z_MIN + Z_MAX) / 2, 0.3, depth) -- west
wainscot(X_MAX - 0.15, (Z_MIN + Z_MAX) / 2, 0.3, depth) -- east

--------------------------------------------------
-- CEILING + LAMPS
--------------------------------------------------

part(
	"Ceiling",
	Vector3.new(width + 1, 1, depth + 1),
	CFrame.new((X_MIN + X_MAX) / 2, WALL_TOP - 0.3, (Z_MIN + Z_MAX) / 2),
	Color3.fromRGB(28, 30, 60)
)

local lampPositions = {
	Vector3.new(-100, 0, -258), Vector3.new(-76.5, 0, -258), Vector3.new(-53.5, 0, -258), Vector3.new(-30, 0, -258),
	Vector3.new(-90, 0, -240), Vector3.new(-77.5, 0, -240), Vector3.new(-65, 0, -240), Vector3.new(-52.5, 0, -240), Vector3.new(-40, 0, -240),
	Vector3.new(-90, 0, -222), Vector3.new(-77.5, 0, -222), Vector3.new(-65, 0, -222), Vector3.new(-52.5, 0, -222), Vector3.new(-40, 0, -222),
	Vector3.new(-90, 0, -206), Vector3.new(-77.5, 0, -206), Vector3.new(-65, 0, -206), Vector3.new(-52.5, 0, -206), Vector3.new(-40, 0, -206),
}

for index, position in ipairs(lampPositions) do
	local y = WALL_TOP - 7
	-- Cord
	part("LampCord", Vector3.new(0.2, 6, 0.2), CFrame.new(position.X, y + 3.2, position.Z), INK)
	-- Shade
	local shade = part(
		"Lamp" .. index,
		Vector3.new(2.6, 3.6, 3.6), -- cylinder: X = height after the 90 degree turn
		CFrame.new(position.X, y, position.Z),
		LANE,
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder }
	)
	shade.CFrame = shade.CFrame * CFrame.Angles(0, 0, math.pi / 2)

	local glow = part(
		"LampGlow" .. index,
		Vector3.new(0.4, 2.6, 2.6),
		CFrame.new(position.X, y - 1.25, position.Z),
		Color3.fromRGB(255, 236, 190),
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder }
	)
	glow.CFrame = glow.CFrame * CFrame.Angles(0, 0, math.pi / 2)

	create("PointLight", {
		Color = Color3.fromRGB(255, 226, 170),
		Brightness = 1.0,
		Range = 22,
		Shadows = false,
	}, glow)

	CollectionService:AddTag(glow, "LobbyLamp")
end

--------------------------------------------------
-- BALL RACKS (both side walls), using the real ball models
--------------------------------------------------

local ballModels = ReplicatedStorage:WaitForChild("BallModels")

local ballIds = {}
for _, model in ipairs(ballModels:GetChildren()) do
	if model:IsA("MeshPart") then
		table.insert(ballIds, model.Name)
	end
end
table.sort(ballIds)

local ballsPerShelf = 9
local ballSpacing = 3.6
local RACK_Z_START = -252 -- clear of the generator row at the back

-- One rack against a side wall. side = +1 for the east wall (balls face
-- west), -1 for the west wall. ballOffset spreads the ball models so the
-- two racks do not show the same balls.
local function buildRack(rackX, side, ballOffset)
	for shelf = 1, 2 do
		local shelfY = FLOOR_Y + 3.2 + (shelf - 1) * 5.2
		local length = ballsPerShelf * ballSpacing + 1

		-- Shelf board (lane wood) with cream lip
		part(
			"RackShelf" .. shelf,
			Vector3.new(3.6, 0.5, length),
			CFrame.new(rackX, shelfY, RACK_Z_START + length / 2),
			LANE,
			Enum.Material.WoodPlanks
		)
		part(
			"RackLip" .. shelf,
			Vector3.new(0.4, 0.4, length),
			CFrame.new(rackX - side * 1.7, shelfY + 0.4, RACK_Z_START + length / 2),
			Color3.fromRGB(196, 140, 66)
		)

		for slot = 1, ballsPerShelf do
			local index = ((shelf - 1) * ballsPerShelf + slot - 1 + ballOffset) % math.max(#ballIds, 1) + 1
			local ballId = ballIds[index]
			local template = ballId and ballModels:FindFirstChild(ballId)

			if template then
				local ball = template:Clone()
				ball.Anchored = true
				ball.CanCollide = false
				ball.CanTouch = false
				ball.CanQuery = false
				ball.CastShadow = false
				ball.Name = "RackBall_" .. ballId

				local scale = 0.62
				ball.Size = ball.Size * scale
				ball.CFrame = CFrame.new(
					rackX,
					shelfY + 0.25 + ball.Size.Y / 2,
					RACK_Z_START + 1.2 + (slot - 1) * ballSpacing
				)
				ball.Parent = decor

				CollectionService:AddTag(ball, "LobbySpin")

				-- Premium balls show their unique accessories on the rack too.
				BallAccessories.Apply(ball, ballId)
			end
		end
	end

	-- Backboard behind the balls
	part(
		"RackBack",
		Vector3.new(0.5, 12.5, ballsPerShelf * ballSpacing + 3),
		CFrame.new(rackX + side * 2.0, FLOOR_Y + 7.4, RACK_Z_START + (ballsPerShelf * ballSpacing + 1) / 2),
		NAVY
	)
end

buildRack(X_MAX - 2.2, 1, 0)
buildRack(X_MIN + 2.2, -1, 9)

--------------------------------------------------
-- PIN CLUSTERS
--------------------------------------------------

-- Your modelled pin (Workspace.BowlingShop.StandPin1: textured mesh).
local shop = workspace:FindFirstChild("BowlingShop")
local pinTemplate = shop and shop:FindFirstChild("StandPin1")
local PIN_SCALE = 2.4 -- the shop prop is miniature; make it floor-sized

local function buildPin(position, parent)
	if pinTemplate and pinTemplate:IsA("MeshPart") then
		local pin = pinTemplate:Clone()
		pin.Name = "Pin"
		pin.Anchored = true
		pin.CanCollide = false
		pin.CanTouch = false
		pin.CanQuery = false
		pin.CastShadow = false
		pin.Size = pinTemplate.Size * PIN_SCALE

		-- Keep the model's own upright orientation, stand it on the floor.
		local rotation = pinTemplate.CFrame - pinTemplate.CFrame.Position
		pin.CFrame = CFrame.new(position.X, FLOOR_Y + pin.Size.Y / 2, position.Z) * rotation
		pin.Parent = parent
		return
	end

	local body = part(
		"Pin",
		Vector3.new(2.6, 1.3, 1.3),
		CFrame.new(position + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		CREAM,
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder }
	)
	body.Parent = parent

	part(
		"PinBelly",
		Vector3.new(1.4, 1.5, 1.5),
		CFrame.new(position + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		CREAM,
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder }
	).Parent = parent

	part(
		"PinNeckBand",
		Vector3.new(0.35, 1.0, 1.0),
		CFrame.new(position + Vector3.new(0, 2.25, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		PIN_RED,
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Cylinder }
	).Parent = parent

	part(
		"PinHead",
		Vector3.new(0.9, 0.9, 0.9),
		CFrame.new(position + Vector3.new(0, 2.95, 0)),
		CREAM,
		Enum.Material.SmoothPlastic,
		{ Shape = Enum.PartType.Ball }
	).Parent = parent
end

local function pinTriangle(origin, direction)
	local cluster = create("Folder", { Name = "PinCluster" }, decor)
	local rows = 4
	for row = 1, rows do
		for index = 1, row do
			local offsetAcross = (index - (row + 1) / 2) * 2.3
			local offsetAlong = (row - 1) * 2.0 * direction
			buildPin(
				origin + Vector3.new(offsetAlong, 0, offsetAcross),
				cluster
			)
		end
	end
end

-- Away from the generator row (back wall) and the shop (west-front)
pinTriangle(Vector3.new(X_MIN + 5, FLOOR_Y + 0.1, -226), 1)
pinTriangle(Vector3.new(X_MAX - 5, FLOOR_Y + 0.1, Z_MAX - 7), -1)

--------------------------------------------------
-- WALL SCREENS: two flat screens on each side wall, one at each end of the
-- ball rack, with short tips. Decoration only.
--------------------------------------------------

local SCREEN_TEXTS = {
	{ "ROLL. WIN.", "REBIRTH!" },
	{ "DAILY QUESTS", "= FREE WINS" },
	{ "GRAB OIL.", "DODGE GUTTERS!" },
	{ "FASTER BALLS", "= MORE WINS" },
}

do
	local count = 0
	local screenY = FLOOR_Y + 11.5

	for _, wall in ipairs({ { X_MIN, 1 }, { X_MAX, -1 } }) do
		for _, z in ipairs({ -260, -203 }) do
			count += 1
			local x = wall[1] + wall[2] * 0.75 -- just off the wall, facing the room
			local face = CFrame.new(x, screenY, z) * CFrame.Angles(0, wall[2] == 1 and -math.pi / 2 or math.pi / 2, 0)

			part("ScreenFrame", Vector3.new(11, 6.4, 0.6), face, Color3.fromRGB(24, 22, 34))
			local screen = part("Screen", Vector3.new(10.2, 5.6, 0.2), face * CFrame.new(0, 0, -0.35), Color3.fromRGB(16, 30, 70))

			local gui = create("SurfaceGui", {
				Face = Enum.NormalId.Front,
				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud = 50,
				LightInfluence = 0,
				Brightness = 0.7,
			}, screen)

			create("UIGradient", {}, create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(40, 110, 255),
			}, gui)).Color = ColorSequence.new(Color3.fromRGB(30, 80, 200), Color3.fromRGB(14, 24, 70))

			local texts = SCREEN_TEXTS[((count - 1) % #SCREEN_TEXTS) + 1]
			for lineIndex, text in ipairs(texts) do
				local label = create("TextLabel", {
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0, 0.12 + (lineIndex - 1) * 0.42),
					Size = UDim2.fromScale(1, lineIndex == 1 and 0.42 or 0.34),
					Font = FONT,
					Text = text,
					TextScaled = true,
					TextColor3 = lineIndex == 1 and Color3.fromRGB(255, 226, 90) or CREAM,
				}, gui)
				create("UIStroke", { Color = Color3.fromRGB(10, 14, 40), Thickness = 3 }, label)
			end
		end
	end
end

--------------------------------------------------
--------------------------------------------------
-- ENTRANCE SIGNS
--------------------------------------------------

local function sign(name, text, subtext, size, cframe, color)
	local board = part(name, size, cframe, color or PIN_RED)


	local gui = create("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		Brightness = 0.6, -- the bloom effect washes signs out at full brightness
	}, board)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, subtext and 0.65 or 1),
		Font = FONT,
		Text = text,
		TextColor3 = CREAM,
		TextScaled = true,
	}, gui)

	if subtext then
		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, 0.62),
			Size = UDim2.fromScale(1, 0.3),
			Font = FONT,
			Text = subtext,
			TextColor3 = INK,
			TextScaled = true,
		}, gui)
	end

	-- Cream frame
	part(
		name .. "Frame",
		size + Vector3.new(0.8, 0.8, -0.1),
		cframe * CFrame.new(0, 0, 0.12),
		CREAM
	)

	return board
end

-- Over the lane opening, facing the room (-Z)
sign(
	"OilCourseSign",
	"OIL COURSE",
	"ROLL THROUGH TO START",
	Vector3.new(22, 5, 0.5),
	CFrame.new(-65, 91.2, -197.2),
	PIN_RED
)

-- Behind the ball shop, standing on two posts, facing the room (+X).
-- (The shop model no longer touches a wall now that the room is wider.)
-- The shop now stands on the east side (x ~ -46); the sign is behind it and
-- turned a little toward the middle of the room, like the shop itself.
local shopSignX = -38.5
local shopSignZ = -210

local roomMiddle = Vector3.new(-88.6, 0, -272) -- the x2 XP generator: the shop and its sign turn toward it
local signToMiddle = (roomMiddle - Vector3.new(shopSignX, 0, shopSignZ)).Unit
local signFacing = (Vector3.new(-1, 0, 0) * 0.15 + signToMiddle * 0.85).Unit
-- The sign's front is local -Z: yaw psi turns it to (-sin psi, 0, -cos psi).
local signYaw = math.atan2(-signFacing.X, -signFacing.Z)
local signRight = Vector3.new(signFacing.Z, 0, -signFacing.X) -- perpendicular, in the floor plane

sign(
	"BallShopSign",
	"BALL SHOP",
	"ROLL IN. ROLL UP. ROLL RICH!",
	Vector3.new(20, 6.5, 0.5),
	CFrame.new(shopSignX, FLOOR_Y + 14, shopSignZ) * CFrame.Angles(0, signYaw, 0),
	Color3.fromRGB(86, 168, 240)
)

for _, side in ipairs({ -1, 1 }) do
	local postPosition = Vector3.new(shopSignX, FLOOR_Y + 6.2, shopSignZ) + signRight * (8 * side) - signFacing * 0.1
	part(
		"BallShopSignPost",
		Vector3.new(0.8, 12.4, 0.8),
		CFrame.new(postPosition),
		LANE,
		Enum.Material.WoodPlanks
	)
end

-- Floating call-to-action above the shop sign, readable from across the room.
do
	local anchor = part(
		"BallShopAdAnchor",
		Vector3.new(1, 1, 1),
		CFrame.new(-47.5, FLOOR_Y + 9.2, -210.5), -- just above the shop roof, eye level from the lobby
		CREAM
	)
	anchor.Transparency = 1

	local ad = create("BillboardGui", {
		Name = "ShopCall",
		Size = UDim2.fromScale(7.6, 1.45), -- studs: shrinks with distance
		LightInfluence = 0,
		MaxDistance = 110,
	}, anchor)

	local function line(text, y, h, thickness, c1, c2)
		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(1, h),
			Font = FONT,
			Text = text,
			TextScaled = true,
			TextColor3 = Color3.new(1, 1, 1),
		}, ad)
		create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = thickness }, label)
		create("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = 90 }, label)
	end

	line("BUY BOWLING GEAR!", 0, 1, 3, Color3.fromRGB(255, 224, 70), Color3.fromRGB(255, 130, 30))
end

--------------------------------------------------
--------------------------------------------------
-- LIGHTING (warmer, more colourful; existing Sky/Atmosphere/Bloom stay)
--------------------------------------------------

Lighting.ClockTime = 17.2
Lighting.Brightness = 2.4
Lighting.Ambient = Color3.fromRGB(96, 88, 128)
Lighting.OutdoorAmbient = Color3.fromRGB(112, 104, 150)
Lighting.ColorShift_Top = Color3.fromRGB(255, 206, 150)

local grade = Lighting:FindFirstChild("LobbyColorGrade")
if not grade then
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LobbyColorGrade"
	grade.Parent = Lighting
end
grade.Saturation = 0.18
grade.Contrast = 0.06
grade.TintColor = Color3.fromRGB(255, 244, 232)

-- WorldService copies the lobby only once everything (racks included) is built
decor:SetAttribute("Built", true)
print("[LobbyDecor] READY | parts:", #decor:GetDescendants(), "| ball models on racks:", #ballIds)
