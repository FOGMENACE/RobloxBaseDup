--------------------------------------------------
-- LOBBY FURNITURE (server, decor only)
--
-- Three small poufs and a small arcade corner on the left wall. (The rug,
-- couches and plants were tried and removed: too busy for the room.)
--
-- Everything is anchored, lives in Workspace.LobbyFurniture, and gameplay never
-- reads it. The pieces are solid but sit well away from the centre lane
-- (x ~ -65) and the objects that already exist (racks, mailbox, shop, podium,
-- generators).
--------------------------------------------------

local FLOOR_Y = 63.5

local INK = Color3.fromRGB(24, 22, 34)
local NAVY = Color3.fromRGB(34, 36, 74)
local NAVY_LIGHT = Color3.fromRGB(52, 58, 112)
local CREAM = Color3.fromRGB(255, 247, 232)
local LANE = Color3.fromRGB(240, 178, 82)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local TEAL = Color3.fromRGB(70, 200, 200)
local GREEN = Color3.fromRGB(70, 190, 100)
local FONT = Enum.Font.FredokaOne

local old = workspace:FindFirstChild("LobbyFurniture")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "LobbyFurniture"
folder.Parent = workspace

local function part(name, size, cframe, color, options)
	options = options or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = options.Material or Enum.Material.SmoothPlastic
	p.Transparency = options.Transparency or 0
	p.Anchored = true
	p.CanCollide = options.Collide == true
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = options.Shadow ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if options.Shape then
		p.Shape = options.Shape
	end
	p.Parent = folder
	return p
end

local function label(parent, face, text, size, color, canvas)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = canvas or Vector2.new(400, 120)
	gui.LightInfluence = 0
	gui.Parent = parent

	local text_ = Instance.new("TextLabel")
	text_.Size = UDim2.fromScale(1, 1)
	text_.BackgroundTransparency = 1
	text_.Font = FONT
	text_.Text = text
	text_.TextScaled = true
	text_.TextColor3 = color
	text_.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = text_
	return gui
end

--------------------------------------------------
-- SINGLE SEATS (poufs)
--------------------------------------------------

local function pouf(center, color)
	part(
		"Pouf",
		Vector3.new(1.3, 2.4, 2.4),
		CFrame.new(center + Vector3.new(0, 0.65, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		{ Shape = Enum.PartType.Cylinder, Collide = true }
	)
	part(
		"PoufTop",
		Vector3.new(0.3, 2.1, 2.1),
		CFrame.new(center + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color:Lerp(Color3.new(1, 1, 1), 0.25),
		{ Shape = Enum.PartType.Cylinder, Collide = true }
	)
end

-- small, tucked along the right wall under the ball rack, out of the way
pouf(Vector3.new(-30, FLOOR_Y, -248), TEAL)
pouf(Vector3.new(-30, FLOOR_Y, -241), LANE)
pouf(Vector3.new(-30, FLOOR_Y, -234), TEAL)

--------------------------------------------------
-- ARCADE CORNER (left wall, front)
--------------------------------------------------

local SCREEN_COLORS = {
	Color3.fromRGB(70, 230, 255),
	Color3.fromRGB(255, 90, 190),
	Color3.fromRGB(150, 255, 90),
}
local GAME_TITLES = { "PIN BLAST", "LANE RUSH", "STRIKE!" }

local function cabinet(position, yaw, tint, screenColor, title)
	local base = CFrame.new(position.X, FLOOR_Y, position.Z) * CFrame.Angles(0, yaw, 0)
	local function rel(name, size, offset, color, options)
		return part(name, size, base * CFrame.new(offset), color, options)
	end

	rel("CabinetBody", Vector3.new(3.8, 6.6, 3.4), Vector3.new(0, 3.3, 0.2), tint, { Collide = true })
	rel("CabinetBase", Vector3.new(4.1, 0.8, 3.7), Vector3.new(0, 0.4, 0.2), NAVY, { Collide = true })
	rel("CabinetHead", Vector3.new(4.1, 2.3, 3.0), Vector3.new(0, 7.7, 0.3), NAVY, { Collide = true })

	local marquee = rel("Marquee", Vector3.new(3.8, 1.4, 0.2), Vector3.new(0, 8.05, -1.25), INK, { Material = Enum.Material.Neon })
	marquee.Color = screenColor
	label(marquee, Enum.NormalId.Front, title, 0, CREAM, Vector2.new(380, 140))

	local screen = rel("Screen", Vector3.new(3.1, 2.7, 0.2), Vector3.new(0, 5.2, -1.45), screenColor, { Material = Enum.Material.Neon })
	screen.Color = screenColor:Lerp(Color3.new(0, 0, 0), 0.35)
	-- a tiny pixel "game": three blocks drawn on the screen
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(310, 270)
	gui.LightInfluence = 0
	gui.Parent = screen
	for index = 1, 3 do
		local block = Instance.new("Frame")
		block.Size = UDim2.fromOffset(40, 40)
		block.Position = UDim2.fromOffset(40 + (index - 1) * 85, 50 + (index % 2) * 90)
		block.BackgroundColor3 = screenColor:Lerp(Color3.new(1, 1, 1), 0.55)
		block.BorderSizePixel = 0
		block.Parent = gui
	end

	rel("Controls", Vector3.new(3.4, 0.5, 1.6), Vector3.new(0, 3.1, -1.7), INK, { Collide = true })
	rel("Stick", Vector3.new(0.3, 0.9, 0.3), Vector3.new(-0.8, 3.7, -1.7), PIN_RED)
	rel("StickBall", Vector3.new(0.7, 0.7, 0.7), Vector3.new(-0.8, 4.2, -1.7), PIN_RED, { Shape = Enum.PartType.Ball })
	for index = 1, 3 do
		rel(
			"Button",
			Vector3.new(0.45, 0.45, 0.45),
			Vector3.new(0.2 + index * 0.55, 3.5, -1.7),
			index == 2 and LANE or CREAM,
			{ Shape = Enum.PartType.Ball }
		)
	end

	-- stool in front (a cylinder's axis is X, so turn it upright)
	part(
		"StoolSeat",
		Vector3.new(0.5, 2.2, 2.2),
		base * CFrame.new(0, 2.2, -4.2) * CFrame.Angles(0, 0, math.pi / 2),
		tint,
		{ Shape = Enum.PartType.Cylinder, Collide = true }
	)
	rel("StoolPole", Vector3.new(0.4, 2, 0.4), Vector3.new(0, 1.1, -4.2), INK, { Collide = true })
end

-- facing +X (into the room): yaw -90
for index, z in ipairs({ -214, -207, -200 }) do
	cabinet(Vector3.new(-103.4, 0, z), -math.pi / 2, NAVY_LIGHT, SCREEN_COLORS[index], GAME_TITLES[index])
end

-- glowing wall sign above the cabinets
local sign = part(
	"ArcadeSign",
	Vector3.new(0.4, 3.6, 14),
	CFrame.new(-105.6, FLOOR_Y + 18.2, -207), -- above the wall screen (it tops out at FLOOR_Y + 14.7)
	INK,
	{ Material = Enum.Material.Neon, Shadow = false }
)
sign.Color = Color3.fromRGB(255, 110, 200)
label(sign, Enum.NormalId.Right, "ARCADE", 0, CREAM, Vector2.new(600, 160))

print("[LobbyFurniture] READY |", #folder:GetChildren(), "parts")