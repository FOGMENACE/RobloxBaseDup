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
	-- a "strike" scattering far off to the right
	{ Vector3.new(330, 230, 560), Vector3.new(1.2, 0.3, 0.6) },
	{ Vector3.new(380, 190, 610), Vector3.new(-0.3, 0.9, 1.4) },
	{ Vector3.new(300, 280, 640), Vector3.new(0.7, -1.0, -0.5) },
}
local CollectionService = game:GetService("CollectionService")
-- the client (SkyAnimator) turns tagged parts slowly so the sky feels alive
local function animate(part, spin, bob)
	part:SetAttribute("SkyBase", part.CFrame)
	part:SetAttribute("SkySpin", spin)
	part:SetAttribute("SkyBob", bob or 0)
	CollectionService:AddTag(part, "SkyDecorSpin")
end
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
		animate(moon, Vector3.new(0, 0.05, 0), 0)
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
			-- each pin tumbles slowly on its own, different speeds
			animate(copy, Vector3.new(0.08 + index * 0.02, 0.05, 0.12 - index * 0.01), 6 + index)
		end
	end

	-- a big glossy oil drop (the game's currency); glows in the world's colour
	local tint = world.Theme and world.Theme.Glow or Color3.fromRGB(20, 18, 28)
	local dark = Color3.fromRGB(20, 18, 28):Lerp(tint, world.Theme and 0.25 or 0)
	ball("OilDrop", 70, DROP + offset, dark, Enum.Material.Glass, 0, folder)
	-- a smooth teardrop: a stack of shrinking, overlapping spheres (diameter, height above the centre)
	for index, step in ipairs({ { 62, 20 }, { 52, 36 }, { 40, 50 }, { 28, 61 }, { 17, 69 }, { 8, 75 } }) do
		ball("OilDropTaper" .. index, step[1], DROP + offset + Vector3.new(0, step[2], 0), dark, Enum.Material.Glass, 0, folder)
	end
	-- a soft white glint on the drop's shoulder, flat against it (not a second ball)
	local glint = ball("OilShine", 9, DROP + offset + Vector3.new(-17, 12, -24), Color3.new(1, 1, 1), Enum.Material.Neon, 0.25, folder)
	glint.Size = Vector3.new(9, 22, 5)
	if world.Theme then
		local glow = Instance.new("PointLight")
		glow.Color = tint
		glow.Range = 60
		glow.Brightness = 3
		glow.Parent = folder:FindFirstChild("OilDrop")
	end
	for _, part in ipairs(folder:GetChildren()) do
		if part.Name:find("^OilDrop") or part.Name == "OilShine" then
			animate(part, Vector3.zero, 10) -- the whole drop bobs gently together
		end
	end

	folder.Parent = root
end

for _, world in ipairs(WorldConfig.Worlds) do
	build(world)
end

root.Parent = Workspace

-- soft drifting clouds (Roblox's animated Clouds): warm cream with a pink
-- tint, matching the lobby's sunset lighting; light cover so the sky
-- objects stay visible
local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
clouds.Cover = 0.5
clouds.Density = 0.55
clouds.Color = Color3.fromRGB(255, 226, 232)
clouds.Enabled = true
clouds.Parent = Workspace.Terrain
