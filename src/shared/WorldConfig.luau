--------------------------------------------------
-- WORLD CONFIG (shared, display + server rules)
--
-- World 1 is the original lobby. Every higher world is a full copy of the
-- lobby placed Offset studs away, re-themed, with harder XP generator
-- requirements and bigger rewards. The oil course and win course are shared:
-- a player rolling through their world's start wall is moved onto the course
-- and comes back to their own world's spawn.
--
-- XpMult      : multiplies the normal XP generators (X1..X10) in that world
-- GenReqScale : generator rebirth requirement = Rebirths + base * GenReqScale
-- WinSpeedMult/WinRewardMult : win course speed and wins in that world
-- Admin       : the two admin generators in that world (multiplier, pass key)
--------------------------------------------------

local WorldConfig = {}

WorldConfig.Worlds = {
	{
		Id = 1, Name = "ROOKIE LANES", Rebirths = 0, Offset = Vector3.zero,
		XpMult = 1, GenReqScale = 1, WinSpeedMult = 1, WinRewardMult = 1,
		Admin = { ["GenX100 Admin XP"] = 100, ["GenX1000 Admin XP"] = 1000 },
	},
	{
		Id = 2, Name = "PRO ALLEY", Rebirths = 25, Offset = Vector3.new(1600, 0, 0),
		XpMult = 3, GenReqScale = 3, WinSpeedMult = 1.2, WinRewardMult = 2,
		Admin = { ["GenX100 Admin XP"] = 200, ["GenX1000 Admin XP"] = 1300 },
		Theme = {
			Primary = Color3.fromRGB(150, 175, 205), Accent = Color3.fromRGB(80, 180, 255),
			Floor = Color3.fromRGB(196, 206, 222), Glow = Color3.fromRGB(120, 210, 255),
			Ambient = Color3.fromRGB(150, 165, 190), Tint = Color3.fromRGB(225, 236, 255),
			Smog = Color3.fromRGB(170, 210, 255), Shine = 0.25,
		},
	},
	{
		Id = 3, Name = "MASTER ARENA", Rebirths = 75, Offset = Vector3.new(3200, 0, 0),
		XpMult = 8, GenReqScale = 7, WinSpeedMult = 1.4, WinRewardMult = 4,
		Admin = { ["GenX100 Admin XP"] = 400, ["GenX1000 Admin XP"] = 2600 },
		Theme = {
			Primary = Color3.fromRGB(40, 32, 26), Accent = Color3.fromRGB(255, 196, 70),
			Floor = Color3.fromRGB(60, 46, 30), Glow = Color3.fromRGB(255, 205, 90),
			Ambient = Color3.fromRGB(150, 120, 80), Tint = Color3.fromRGB(255, 236, 200),
			Smog = Color3.fromRGB(255, 200, 110), Shine = 0.35,
		},
	},
	{
		Id = 4, Name = "GRANDMASTER PALACE", Rebirths = 150, Offset = Vector3.new(4800, 0, 0),
		XpMult = 20, GenReqScale = 14, WinSpeedMult = 1.6, WinRewardMult = 8,
		Admin = { ["GenX100 Admin XP"] = 800, ["GenX1000 Admin XP"] = 5200 },
		Theme = {
			Primary = Color3.fromRGB(70, 40, 120), Accent = Color3.fromRGB(190, 240, 255),
			Floor = Color3.fromRGB(110, 80, 170), Glow = Color3.fromRGB(200, 150, 255),
			Ambient = Color3.fromRGB(150, 120, 200), Tint = Color3.fromRGB(236, 225, 255),
			Smog = Color3.fromRGB(215, 175, 255), Shine = 0.45,
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