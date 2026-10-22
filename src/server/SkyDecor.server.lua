--------------------------------------------------
-- SKY DECOR (SERVER, decoration only)
--
-- Fills the empty sky the player rolls toward: a giant StraightBall planet,
-- giant pins tumbling through the sky and a big oil drop. One set per world,
-- placed over that world's lobby; in the themed worlds the planet wears the
-- world's evolved-ball coat and the oil drop glows in the world's colour.
-- Far away, non-colliding, never copied by WorldService (SKIP list).
--------------------------------------------------

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local WorldSkinStyle = require(ReplicatedStorage:WaitForChild("WorldSkinStyle"))
local straight = ReplicatedStorage:WaitForChild("BallModels"):WaitForChild("StraightBall", 10)

local old = Workspace:FindFirstChild("SkyDecor")
if old then
	old:Destroy()
end

-- a persistent model: instance streaming would otherwise never send parts this far away
local root = Instance.new("Model")
root.Name = "SkyDecor"
root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

local shop = Workspace:FindFirstChild("BowlingShop")
local pinTemplate = shop and shop:FindFirstChild("StandPin1")

local MOON = Vector3.new(130, 200, 420)
local PINS = {
	{ Vector3.new(-150, 150, 300), Vector3.new(0.4, 0.2, 0.9) },
	{ Vector3.new(-40, 230, 520), Vector3.new(-0.6, 1.1, -0.4) },
	{ Vector3.new(200, 130, 260), Vector3.new(0.9, -0.5, 0.3) },
}
local DROP = Vector3.new(-230, 190, 470)

local function settle(p, parent)
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

local function ball(name, size, position, color, material, transparency, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.CFrame = CFrame.new(position)
	p.Color = color
	p.Material = material
	p.Transparency = transparency or 0
	return settle(p, parent)
end

local function build(world)
	local folder = Instance.new("Folder")
	folder.Name = "World" .. world.Id
	local offset = world.Offset

	-- the game's own StraightBall as a planet (finger holes face the lobby)
	if straight then
		local moon = straight:Clone()
		moon.Name = "BallMoon"
		moon:ClearAllChildren()
		moon.Size = straight.Size * (150 / math.max(straight.Size.X, 0.1))
		moon.CFrame = CFrame.lookAt(MOON + offset, Vector3.new(-65, 70, -220) + offset)
		settle(moon, folder)
		if world.Theme then
			pcall(WorldSkinStyle.Apply, moon, world.Theme, false)
		end
	end

	-- giant pins tumbling through the sky
	if pinTemplate and pinTemplate:IsA("MeshPart") then
		for index, pin in ipairs(PINS) do
			local copy = pinTemplate:Clone()
			copy.Name = "SkyPin" .. index
			copy:ClearAllChildren()
			copy.Size = pinTemplate.Size * 34
			copy.CFrame = CFrame.new(pin[1] + offset) * CFrame.Angles(pin[2].X, pin[2].Y, pin[2].Z)
			settle(copy, folder)
		end
	end

	-- a big glossy oil drop (the game's currency); glows in the world's colour
	local tint = world.Theme and world.Theme.Glow or Color3.fromRGB(20, 18, 28)
	local dark = Color3.fromRGB(20, 18, 28):Lerp(tint, world.Theme and 0.25 or 0)
	ball("OilDrop", 70, DROP + offset, dark, Enum.Material.Glass, 0, folder)
	local tip = ball("OilDropTip", 1, DROP + offset + Vector3.new(0, 44, 0), dark, Enum.Material.Glass, 0, folder)
	tip.Size = Vector3.new(42, 52, 42)
	ball("OilShine", 14, DROP + offset + Vector3.new(-16, 18, -28), Color3.new(1, 1, 1), Enum.Material.Neon, 0.2, folder)
	if world.Theme then
		local glow = Instance.new("PointLight")
		glow.Color = tint
		glow.Range = 60
		glow.Brightness = 3
		glow.Parent = folder:FindFirstChild("OilDrop")
	end

	folder.Parent = root
end

for _, world in ipairs(WorldConfig.Worlds) do
	build(world)
end

root.Parent = Workspace
