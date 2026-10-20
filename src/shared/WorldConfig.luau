--------------------------------------------------
-- WORLD CONFIG (shared, display + server rules)
--
-- World 1 is the original lobby. Every higher world is a full copy of the
-- lobby placed Offset studs away, re-themed, with harder XP generator
-- requirements and bigger rewards. The oil course and win course are shared:
-- a player rolling through their world's start wall is moved onto the course
-- and comes back to their own world's spawn.
--
-- Generators  : the normal XP generators of that world (same six spots as the
--               original lobby), continuing world 1's ladder in steps of 5.
--               Each one needs as many rebirths as its multiplier (like world 1:
--               X8 needs 8). The world itself opens at its first generator.
-- WinSpeedMult/WinRewardMult : win course speed and wins in that world
-- Admin       : the two admin generators in that world (multiplier, pass key)
--------------------------------------------------

local WorldConfig = {}

WorldConfig.Worlds = {
	{
		Id = 1, Name = "ROOKIE LANES", Rebirths = 0, Offset = Vector3.zero,
		WinSpeedMult = 1, WinRewardMult = 1,
		Admin = { ["GenX100 Admin XP"] = 100, ["GenX1000 Admin XP"] = 1000 },
	},
	{
		Id = 2, Name = "PRO ALLEY", Rebirths = 15, Offset = Vector3.new(1600, 0, 0),
		Generators = { GenX1 = 15, GenX2 = 20, GenX4 = 25, GenX6 = 30, GenX8 = 35, GenX10 = 40 },
		WinSpeedMult = 1.2, WinRewardMult = 2,
		Admin = { ["GenX100 Admin XP"] = 240, ["GenX1000 Admin XP"] = 1900 },
		AdminPass = { ["GenX100 Admin XP"] = 2036415199, ["GenX1000 Admin XP"] = 2040578649 }, -- R$ 575 / R$ 1,650
		Theme = {
			Primary = Color3.fromRGB(150, 175, 205), Accent = Color3.fromRGB(80, 180, 255),
			Floor = Color3.fromRGB(196, 206, 222), Glow = Color3.fromRGB(120, 210, 255),
			Ambient = Color3.fromRGB(150, 165, 190), Tint = Color3.fromRGB(225, 236, 255),
			Smog = Color3.fromRGB(170, 210, 255), Shine = 0.25,
			-- evolved ball wrap: polished chrome-ice, frost shimmer
			Wrap = Color3.fromRGB(196, 222, 248), WrapMaterial = Enum.Material.Metal, Dust = Color3.fromRGB(220, 245, 255), Ember = Color3.fromRGB(120, 210, 255),
		},
	},
	{
		Id = 3, Name = "MASTER ARENA", Rebirths = 45, Offset = Vector3.new(3200, 0, 0),
		Generators = { GenX1 = 45, GenX2 = 50, GenX4 = 55, GenX6 = 60, GenX8 = 65, GenX10 = 70 },
		WinSpeedMult = 1.4, WinRewardMult = 4,
		Admin = { ["GenX100 Admin XP"] = 360, ["GenX1000 Admin XP"] = 2200 },
		AdminPass = { ["GenX100 Admin XP"] = 2037033103, ["GenX1000 Admin XP"] = 2039960889 }, -- R$ 710 / R$ 1,899
		Theme = {
			Primary = Color3.fromRGB(40, 32, 26), Accent = Color3.fromRGB(255, 196, 70),
			Floor = Color3.fromRGB(60, 46, 30), Glow = Color3.fromRGB(255, 205, 90),
			Ambient = Color3.fromRGB(150, 120, 80), Tint = Color3.fromRGB(255, 236, 200),
			Smog = Color3.fromRGB(255, 200, 110), Shine = 0.35,
			-- evolved ball wrap: rich metallic gold, golden haze and embers
			Wrap = Color3.fromRGB(238, 168, 36), WrapMaterial = Enum.Material.Metal, Dust = Color3.fromRGB(255, 226, 120), Ember = Color3.fromRGB(255, 150, 40),
		},
	},
	{
		Id = 4, Name = "GRANDMASTER PALACE", Rebirths = 75, Offset = Vector3.new(4800, 0, 0),
		Generators = { GenX1 = 75, GenX2 = 80, GenX4 = 85, GenX6 = 90, GenX8 = 95, GenX10 = 100 },
		WinSpeedMult = 1.6, WinRewardMult = 8,
		Admin = { ["GenX100 Admin XP"] = 490, ["GenX1000 Admin XP"] = 2800 },
		AdminPass = { ["GenX100 Admin XP"] = 2036387283, ["GenX1000 Admin XP"] = 2039765108 }, -- R$ 869 / R$ 2,299
		Theme = {
			Primary = Color3.fromRGB(70, 40, 120), Accent = Color3.fromRGB(190, 240, 255),
			Floor = Color3.fromRGB(110, 80, 170), Glow = Color3.fromRGB(200, 150, 255),
			Ambient = Color3.fromRGB(150, 120, 200), Tint = Color3.fromRGB(236, 225, 255),
			Smog = Color3.fromRGB(215, 175, 255), Shine = 0.45,
			-- evolved ball wrap: amethyst crystal, violet mist and stardust
			Wrap = Color3.fromRGB(176, 120, 255), WrapMaterial = Enum.Material.Metal, Dust = Color3.fromRGB(235, 215, 255), Ember = Color3.fromRGB(205, 140, 255),
		},
	},
}

function WorldConfig.Get(id)
	return WorldConfig.Worlds[id] or WorldConfig.Worlds[1]
end

-- the world a player is in (server-set attribute "World", default 1)
function WorldConfig.Of(player)
	local id = player and player:GetAttribute("World")
	return WorldConfig.Get(typeof(id) == "number" and id or 1)
end

function WorldConfig.Offset(player)
	return WorldConfig.Of(player).Offset
end

function WorldConfig.Unlocked(rebirths, id)
	return (rebirths or 0) >= WorldConfig.Get(id).Rebirths
end

-- which world a world-space position belongs to (nearest offset along X)
function WorldConfig.AtPosition(position)
	local best, bestDistance = WorldConfig.Worlds[1], math.huge
	for _, world in ipairs(WorldConfig.Worlds) do
		local distance = math.abs(position.X - world.Offset.X)
		if distance < bestDistance then
			best, bestDistance = world, distance
		end
	end
	return best
end

return WorldConfig