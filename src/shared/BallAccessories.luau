--------------------------------------------------
-- BALL ACCESSORIES (shared module)
--
-- Gives the premium balls their own look on top of the base ball model
-- (ReplicatedStorage.BallModels): a cat sitting on CatPlz, spikes on
-- Venom, a dragon flying around SingleKnot, and so on. Everything is
-- built from simple Parts welded to the ball, so no extra mesh assets
-- are needed.
--
--   BallAccessories.Apply(ball, ballId)   build the parts (idempotent)
--   BallAccessories.SetScale(ball)        resize them after ball.Size changed
--   BallAccessories.Pose(ball, now)       animate (orbits / upright parts)
--
-- Part behaviour (attribute AccMode):
--   Rolling : fixed on the ball, rolls with it (spikes, fur, bands)
--   Upright : keeps a fixed offset in WORLD axes while the ball rolls
--             (the cat, faces, the cloud)
--   Orbit   : circles the ball in world space (the dragon, moons, coins)
--
-- Upright/Orbit are animated by whoever calls Pose every frame (the
-- client animator, shop previews, racks). All parts are Massless,
-- non-colliding and non-touchable, so they can never affect physics,
-- oil gates or purchases.
--
-- Offsets/sizes below are written for a ball of radius 2 (size 4) and
-- are scaled by ball.Size.X / 4.
--------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local IS_CLIENT = RunService:IsClient()

local BallAccessories = {}

local BASE_DIAMETER = 4
local R = 2 -- base radius

--------------------------------------------------
-- COLOURS
--------------------------------------------------

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local CREAM = rgb(255, 247, 232)
local INK = rgb(24, 22, 34)

--------------------------------------------------
-- GEOMETRY HELPERS
--------------------------------------------------

-- Evenly spread unit vectors over a sphere.
local function sphereDirections(count)
	local directions = {}
	local golden = math.pi * (3 - math.sqrt(5))

	for index = 0, count - 1 do
		local y = 1 - (index / math.max(count - 1, 1)) * 2
		local radius = math.sqrt(math.max(0, 1 - y * y))
		local theta = golden * index
		directions[#directions + 1] = Vector3.new(math.cos(theta) * radius, y, math.sin(theta) * radius)
	end

	return directions
end

-- CFrame at `position` whose local +Y points along `direction`.
local function orientY(position, direction)
	direction = direction.Unit
	local helper = math.abs(direction.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
	local right = helper:Cross(direction).Unit
	local back = right:Cross(direction)
	return CFrame.fromMatrix(position, right, direction, back)
end

local function worldOffsetCFrame(ball, baseCF, scale)
	return CFrame.new(ball.Position + baseCF.Position * scale) * (baseCF - baseCF.Position)
end

--------------------------------------------------
-- PART FACTORY
--------------------------------------------------

local function scaleOf(ball)
	return ball.Size.X / BASE_DIAMETER
end

-- spec: Name, Kind (Ball/Block/Cylinder/Pyramid/Wedge), Size, CF, Color,
--       Mat, Transp, Mode, Orbit = {Radius, Speed, Height, Phase, Tilt, Bob, Flap}
local function make(ball, spec)
	local scale = scaleOf(ball)
	local kind = spec.Kind or "Block"

	local part
	if kind == "Wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
		if kind == "Ball" then
			part.Shape = Enum.PartType.Ball
		elseif kind == "Cylinder" then
			part.Shape = Enum.PartType.Cylinder
		else
			part.Shape = Enum.PartType.Block
		end
	end

	part.Name = "Acc_" .. spec.Name
	part.Size = spec.Size * scale
	part.Color = spec.Color or CREAM
	part.Material = spec.Mat or Enum.Material.SmoothPlastic
	part.Transparency = spec.Transp or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Anchored = ball.Anchored

	if kind == "Pyramid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Pyramid
		mesh.Parent = part
	end

	local mode = spec.Mode or "Rolling"
	part:SetAttribute("AccMode", mode)
	part:SetAttribute("BaseSize", spec.Size)
	part:SetAttribute("BaseC0", spec.CF)

	if spec.Orbit then
		part:SetAttribute("OrbitRadius", spec.Orbit.Radius or 3)
		part:SetAttribute("OrbitSpeed", spec.Orbit.Speed or 1)
		part:SetAttribute("OrbitHeight", spec.Orbit.Height or 0)
		part:SetAttribute("OrbitPhase", spec.Orbit.Phase or 0)
		part:SetAttribute("OrbitTilt", spec.Orbit.Tilt or 0)
		part:SetAttribute("OrbitBob", spec.Orbit.Bob or 0)
		part:SetAttribute("Flap", spec.Orbit.Flap or 0)
	end

	local weld = Instance.new("Weld")
	weld.Name = "AccWeld"
	weld.Part0 = ball
	weld.Part1 = part

	if mode == "Rolling" then
		weld.C0 = CFrame.new(spec.CF.Position * scale) * (spec.CF - spec.CF.Position)
	else
		weld.C0 = ball.CFrame:ToObjectSpace(worldOffsetCFrame(ball, spec.CF, scale))
	end

	weld.Parent = part
	part.CFrame = ball.CFrame * weld.C0
	part.Parent = ball

	return part
end

local function emitter(part, props)
	local e = Instance.new("ParticleEmitter")
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = part
	return e
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

--------------------------------------------------
-- DESIGNS
--------------------------------------------------

local designs = {}

-- Small shorthands so each design reads like a parts list.
local function P(ball, name, kind, size, cf, color, extra)
	extra = extra or {}
	extra.Name = name
	extra.Kind = kind
	extra.Size = size
	extra.CF = cf
	extra.Color = color
	return make(ball, extra)
end

local function at(x, y, z)
	return CFrame.new(x, y, z)
end

----------------------------------------------------------------
-- 3  CATPLZ: a cat sitting on top of the ball
----------------------------------------------------------------
designs.CatPlz = function(ball)
	local orange = rgb(238, 150, 58)
	local up = { Mode = "Upright" }
	local function u(extra)
		extra = extra or {}
		extra.Mode = "Upright"
		return extra
	end

	P(ball, "Body", "Ball", Vector3.new(1.8, 1.6, 1.8), at(0, 2.5, 0.1), orange, u())
	P(ball, "Belly", "Ball", Vector3.new(1.1, 1.0, 0.8), at(0, 2.4, -0.55), CREAM, u())
	P(ball, "Head", "Ball", Vector3.new(1.4, 1.25, 1.3), at(0, 3.5, -0.25), orange, u())

	for _, side in ipairs({ -1, 1 }) do
		P(ball, "Ear", "Wedge", Vector3.new(0.3, 0.7, 0.55), at(side * 0.5, 4.2, -0.25) * CFrame.Angles(0, math.pi / 2 * side, 0), orange, u())
		P(ball, "Eye", "Ball", Vector3.new(0.28, 0.32, 0.18), at(side * 0.32, 3.6, -0.85), rgb(90, 200, 90), u())
		P(ball, "Pupil", "Ball", Vector3.new(0.1, 0.22, 0.1), at(side * 0.32, 3.6, -0.93), INK, u())
		P(ball, "Paw", "Ball", Vector3.new(0.45, 0.35, 0.5), at(side * 0.35, 2.05, -0.85), CREAM, u())
		P(ball, "Whisker", "Block", Vector3.new(0.9, 0.03, 0.03), at(side * 0.75, 3.38, -0.9) * CFrame.Angles(0, 0, side * 0.12), CREAM, u())
		P(ball, "Whisker", "Block", Vector3.new(0.9, 0.03, 0.03), at(side * 0.75, 3.28, -0.9) * CFrame.Angles(0, 0, -side * 0.12), CREAM, u())
	end

	P(ball, "Nose", "Ball", Vector3.new(0.2, 0.16, 0.14), at(0, 3.38, -0.95), rgb(255, 130, 150), u())

	local tail = {
		{ 0.5, 2.3, 0.95, 0.5 }, { 0.95, 2.7, 1.05, 0.45 }, { 1.2, 3.2, 1.0, 0.4 }, { 1.1, 3.7, 0.9, 0.34 },
	}
	for index, t in ipairs(tail) do
		P(ball, "Tail" .. index, "Ball", Vector3.new(t[4], t[4], t[4]), at(t[1], t[2], t[3]), orange, u())
	end
end

----------------------------------------------------------------
-- 5  VOLTAGE: neon prongs + orbiting sparks
----------------------------------------------------------------
designs.Voltage = function(ball)
	local yellow = rgb(255, 230, 60)

	for index, dir in ipairs(sphereDirections(14)) do
		P(ball, "Prong" .. index, "Pyramid", Vector3.new(0.4, 1.0, 0.4), orientY(dir * (R + 0.2), dir), yellow, { Mat = Enum.Material.Neon })
	end

	for index = 1, 3 do
		local spark = P(ball, "Spark" .. index, "Ball", Vector3.new(0.6, 0.6, 0.6), CFrame.new(), yellow, {
			Mat = Enum.Material.Neon,
			Mode = "Orbit",
			Orbit = { Radius = 3.4, Speed = 2.4, Height = 0.3, Phase = index * 2.09, Tilt = 0.4 * index, Bob = 0.4 },
		})
		if index == 1 then
			emitter(spark, {
				Texture = SPARKLE, Rate = 30, Lifetime = NumberRange.new(0.3, 0.6),
				Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(180, 180),
				Color = ColorSequence.new(yellow), Size = NumberSequence.new(0.5, 0),
				LightEmission = 1,
			})
		end
	end
end

----------------------------------------------------------------
-- 6  VENOM: toxic spikes
----------------------------------------------------------------
designs.Venom = function(ball)
	local green = rgb(90, 205, 60)
	for index, dir in ipairs(sphereDirections(34)) do
		local long = (index % 5 == 0)
		P(
			ball, "Spike" .. index, "Pyramid",
			Vector3.new(0.6, long and 1.8 or 1.2, 0.6),
			orientY(dir * (R + (long and 0.6 or 0.3)), dir),
			(index % 3 == 0) and INK or green
		)
	end
end

----------------------------------------------------------------
-- 7  SNOTOOZE: slime blobs and drips
----------------------------------------------------------------
designs.SnotOoze = function(ball)
	local slime = rgb(150, 225, 60)
	local blobs = {
		{ Vector3.new(0, 1, 0.1), 1.5 }, { Vector3.new(0.8, 0.7, -0.4), 1.1 }, { Vector3.new(-0.7, 0.75, 0.5), 1.2 },
		{ Vector3.new(0.2, 0.2, -1), 1.0 }, { Vector3.new(-1, 0.1, -0.2), 1.0 }, { Vector3.new(0.95, -0.1, 0.4), 0.9 },
	}
	for index, blob in ipairs(blobs) do
		local dir = blob[1].Unit
		P(ball, "Blob" .. index, "Ball", Vector3.new(blob[2], blob[2] * 0.8, blob[2]), CFrame.new(dir * (R + 0.15)), slime, { Transp = 0.12 })
		P(ball, "Drip" .. index, "Block", Vector3.new(0.25, 1.2, 0.25), CFrame.new(dir * (R + 0.15)) * CFrame.new(0, -0.9, 0), slime, { Transp = 0.12 })
	end
end

----------------------------------------------------------------
-- 8  METEOR: rocks and a fiery trail
----------------------------------------------------------------
designs.Meteor = function(ball)
	local rock = rgb(78, 66, 66)
	local random = Random.new(8)

	for index, dir in ipairs(sphereDirections(9)) do
		local size = 0.9 + random:NextNumber() * 0.8
		local cf = orientY(dir * (R + 0.1), dir) * CFrame.Angles(random:NextNumber() * 2, random:NextNumber() * 2, 0)
		P(ball, "Rock" .. index, "Block", Vector3.new(size, size * 0.7, size), cf, rock, { Mat = Enum.Material.Slate })
		if index % 2 == 0 then
			P(ball, "Glow" .. index, "Block", Vector3.new(0.2, 0.2, size * 0.9), cf, rgb(255, 120, 30), { Mat = Enum.Material.Neon })
		end
	end

	local trail = P(ball, "Trail", "Ball", Vector3.new(0.4, 0.4, 0.4), at(0, 0.3, 2.4), rgb(255, 140, 40), {
		Mode = "Upright", Transp = 1,
	})
	emitter(trail, {
		Texture = FIRE, Rate = 45, Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(12, 12),
		Color = ColorSequence.new(rgb(255, 170, 60), rgb(255, 60, 20)),
		Size = NumberSequence.new(1.8, 0), LightEmission = 0.8,
		EmissionDirection = Enum.NormalId.Back,
	})
end

----------------------------------------------------------------
-- 9  ATTITUDEPAUSIBLE: shades and a gold chain
----------------------------------------------------------------
designs.AttitudePausible = function(ball)
	local u = { Mode = "Upright" }
	local function up(extra)
		extra = extra or {}
		extra.Mode = "Upright"
		return extra
	end

	for _, side in ipairs({ -1, 1 }) do
		P(ball, "Lens", "Block", Vector3.new(1.05, 0.6, 0.14), at(side * 0.7, 0.6, -2.05), INK, up({ Mat = Enum.Material.Glass }))
		P(ball, "Glint", "Block", Vector3.new(0.3, 0.08, 0.02), at(side * 0.45, 0.8, -2.14), CREAM, up())
		P(ball, "Arm", "Block", Vector3.new(0.12, 0.12, 1.4), at(side * 1.3, 0.62, -1.4), INK, up())
	end
	P(ball, "Bridge", "Block", Vector3.new(0.4, 0.12, 0.14), at(0, 0.7, -2.05), INK, up())

	-- Gold chain around the middle (rolls with the ball)
	local gold = rgb(255, 205, 70)
	for index = 1, 16 do
		local angle = (index / 16) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 2.12, -0.5, math.sin(angle) * 2.12)
		P(ball, "Link" .. index, "Ball", Vector3.new(0.3, 0.3, 0.3), CFrame.new(pos), gold, { Mat = Enum.Material.Metal })
	end
end

----------------------------------------------------------------
-- 10  GREENNATURE: leaves and a flower
----------------------------------------------------------------
designs.GreenNature = function(ball)
	local leaf = rgb(70, 190, 80)
	for index, dir in ipairs(sphereDirections(12)) do
		local cf = orientY(dir * (R + 0.35), dir) * CFrame.Angles(0, index, 0)
		P(ball, "Leaf" .. index, "Block", Vector3.new(0.7, 0.9, 0.12), cf, (index % 2 == 0) and leaf or rgb(40, 150, 70))
	end

	local up = { Mode = "Upright" }
	P(ball, "FlowerCenter", "Ball", Vector3.new(0.7, 0.4, 0.7), at(0, 2.5, 0), rgb(255, 210, 60), { Mode = "Upright" })
	for index = 1, 6 do
		local angle = (index / 6) * math.pi * 2
		P(ball, "Petal" .. index, "Ball", Vector3.new(0.6, 0.25, 0.8), at(math.cos(angle) * 0.7, 2.45, math.sin(angle) * 0.7) * CFrame.Angles(0, -angle, 0), rgb(255, 150, 190), { Mode = "Upright" })
	end
end

----------------------------------------------------------------
-- 11  DETAILO: a gyroscope of orbiting rings
----------------------------------------------------------------
designs.Detailo = function(ball)
	local rings = {
		{ speed = 1.3, tilt = 0, color = rgb(90, 210, 255) },
		{ speed = -1.0, tilt = 1.05, color = rgb(255, 205, 70) },
		{ speed = 0.8, tilt = -1.05, color = CREAM },
	}

	for ringIndex, ring in ipairs(rings) do
		for index = 1, 12 do
			P(ball, "Ring" .. ringIndex .. "_" .. index, "Ball", Vector3.new(0.26, 0.26, 0.26), CFrame.new(), ring.color, {
				Mat = Enum.Material.Metal,
				Mode = "Orbit",
				Orbit = { Radius = 3.0 + ringIndex * 0.15, Speed = ring.speed, Height = 0, Phase = (index / 12) * math.pi * 2, Tilt = ring.tilt },
			})
		end
	end
end

----------------------------------------------------------------
-- 12  NEONVESTOFF: hi-vis bands and an orbiting cone
----------------------------------------------------------------
designs.NeonVestOff = function(ball)
	local orange = rgb(255, 130, 20)
	local silver = rgb(215, 220, 225)

	for _, band in ipairs({ { 0.7, orange }, { -0.7, orange }, { 0, silver } }) do
		local y = band[1]
		local radius = math.sqrt(math.max(R * R - y * y, 0.1)) + 0.08
		for index = 1, 18 do
			local angle = (index / 18) * math.pi * 2
			local pos = Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
			P(ball, "Band", "Block", Vector3.new(0.5, 0.32, 0.12), CFrame.lookAt(pos, Vector3.new(0, y, 0)), band[2], {
				Mat = (band[2] == orange) and Enum.Material.Neon or Enum.Material.Metal,
			})
		end
	end

	P(ball, "Cone", "Pyramid", Vector3.new(0.9, 1.2, 0.9), CFrame.new(), orange, {
		Mat = Enum.Material.Neon, Mode = "Orbit",
		Orbit = { Radius = 3.3, Speed = 1.6, Height = 0.6, Phase = 0, Tilt = 0.2, Bob = 0.3 },
	})
end

----------------------------------------------------------------
-- 13  STARDOODLE: orbiting stars and a doodle trail
----------------------------------------------------------------
designs.StarDoodle = function(ball)
	local yellow = rgb(255, 225, 70)
	local pink = rgb(255, 120, 190)

	for star = 1, 5 do
		local orbit = { Radius = 3.2, Speed = 1.4, Height = 0.2, Phase = star * 1.26, Tilt = 0.5, Bob = 0.5 }
		P(ball, "StarA" .. star, "Block", Vector3.new(1.0, 0.22, 0.12), CFrame.new(), yellow, { Mat = Enum.Material.Neon, Mode = "Orbit", Orbit = orbit })
		P(ball, "StarB" .. star, "Block", Vector3.new(0.22, 1.0, 0.12), CFrame.new(), yellow, { Mat = Enum.Material.Neon, Mode = "Orbit", Orbit = orbit })
	end

	for index = 1, 14 do
		P(ball, "Doodle" .. index, "Ball", Vector3.new(0.22, 0.22, 0.22), CFrame.new(), pink, {
			Mat = Enum.Material.Neon, Mode = "Orbit",
			Orbit = { Radius = 2.7 + math.sin(index) * 0.35, Speed = -0.9, Height = math.cos(index * 1.7) * 0.8, Phase = index * 0.22, Tilt = -0.4 },
		})
	end
end

----------------------------------------------------------------
-- 14  PAINMOON: a glowing crescent moon in orbit
----------------------------------------------------------------
designs.PainMoon = function(ball)
	local moon = rgb(235, 240, 255)

	for index = 1, 9 do
		local t = (index - 5) / 4 -- -1 .. 1 along the arc
		local size = 0.8 * (1 - math.abs(t) * 0.55)
		P(ball, "Moon" .. index, "Ball", Vector3.new(size, size, size), CFrame.new(), moon, {
			Mat = Enum.Material.Neon, Mode = "Orbit",
			Orbit = { Radius = 3.5 - math.abs(t) * 0.5, Speed = 0.9, Height = 1.0, Phase = t * 0.42, Tilt = 0.25, Bob = 0.3 },
		})
	end

	for index = 1, 3 do
		P(ball, "Star" .. index, "Ball", Vector3.new(0.25, 0.25, 0.25), CFrame.new(), rgb(150, 190, 255), {
			Mat = Enum.Material.Neon, Mode = "Orbit",
			Orbit = { Radius = 2.8, Speed = -1.6, Height = -0.4, Phase = index * 2.1, Tilt = -0.3, Bob = 0.4 },
		})
	end
end

----------------------------------------------------------------
-- 15  VOIDMINTER: a void orb and orbiting gold coins
----------------------------------------------------------------
designs.VoidMinter = function(ball)
	P(ball, "Void", "Ball", Vector3.new(1.4, 1.4, 1.4), at(0, 3.0, 0), rgb(18, 8, 34), { Mode = "Upright", Mat = Enum.Material.Glass })
	P(ball, "VoidRim", "Ball", Vector3.new(1.7, 1.7, 1.7), at(0, 3.0, 0), rgb(140, 60, 255), { Mode = "Upright", Mat = Enum.Material.Neon, Transp = 0.75 })

	for index = 1, 4 do
		P(ball, "Coin" .. index, "Cylinder", Vector3.new(0.12, 1.0, 1.0), CFrame.new(), rgb(255, 205, 70), {
			Mat = Enum.Material.Metal, Mode = "Orbit",
			Orbit = { Radius = 3.1, Speed = 1.5, Height = 0.2, Phase = index * 1.57, Tilt = 0.3, Bob = 0.4 },
		})
	end
end

----------------------------------------------------------------
-- 16  VOIDWALKER: shadow tendrils and glowing eyes
----------------------------------------------------------------
designs.Voidwalker = function(ball)
	local shadow = rgb(14, 8, 26)

	for index, dir in ipairs(sphereDirections(10)) do
		P(ball, "Tendril" .. index, "Pyramid", Vector3.new(0.35, 2.4, 0.35), orientY(dir * (R + 0.7), dir), shadow)
	end

	for _, side in ipairs({ -1, 1 }) do
		P(ball, "Eye", "Ball", Vector3.new(0.4, 0.55, 0.2), at(side * 0.55, 0.45, -2.0), rgb(190, 90, 255), { Mode = "Upright", Mat = Enum.Material.Neon })
	end

	local smoke = P(ball, "Smoke", "Ball", Vector3.new(0.4, 0.4, 0.4), at(0, 2.6, 0), shadow, { Mode = "Upright", Transp = 1 })
	emitter(smoke, {
		Texture = SMOKE, Rate = 14, Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(35, 35),
		Color = ColorSequence.new(rgb(60, 20, 90)), Size = NumberSequence.new(1.6, 3),
		Transparency = NumberSequence.new(0.4, 1),
	})
end

----------------------------------------------------------------
-- 17  PINKMONSTER: fuzz, horns, three eyes and teeth
----------------------------------------------------------------
designs.PinkMonster = function(ball)
	local pink = rgb(255, 150, 205)

	for index, dir in ipairs(sphereDirections(40)) do
		P(ball, "Fuzz" .. index, "Pyramid", Vector3.new(0.4, 0.55, 0.4), orientY(dir * (R + 0.1), dir), pink)
	end

	local function up(extra)
		extra = extra or {}
		extra.Mode = "Upright"
		return extra
	end

	for _, eye in ipairs({ { -0.75, 0.6 }, { 0, 1.0 }, { 0.75, 0.6 } }) do
		P(ball, "Eye", "Ball", Vector3.new(0.6, 0.6, 0.3), at(eye[1], eye[2], -1.92), CREAM, up())
		P(ball, "Pupil", "Ball", Vector3.new(0.26, 0.26, 0.14), at(eye[1], eye[2], -2.1), INK, up())
	end

	P(ball, "Mouth", "Block", Vector3.new(1.5, 0.5, 0.14), at(0, -0.45, -1.98), rgb(70, 10, 40), up())
	for index = 1, 5 do
		P(ball, "Tooth", "Pyramid", Vector3.new(0.22, 0.3, 0.12), at(-0.6 + (index - 1) * 0.3, -0.3, -2.06) * CFrame.Angles(math.pi, 0, 0), CREAM, up())
	end

	for _, side in ipairs({ -1, 1 }) do
		P(ball, "Horn", "Pyramid", Vector3.new(0.5, 1.1, 0.5), at(side * 0.9, 2.3, -0.2) * CFrame.Angles(0, 0, -side * 0.35), rgb(255, 215, 90), up())
	end
end

----------------------------------------------------------------
-- 18  STORMGATHERER: a storm cloud with rain and lightning
----------------------------------------------------------------
designs.StormGatherer = function(ball)
	local cloud = rgb(120, 130, 150)
	local up = { Mode = "Upright" }

	for index, c in ipairs({ { 0, 0, 1.5 }, { 0.9, 0.1, 1.1 }, { -0.9, 0.05, 1.2 }, { 0.3, 0.45, 0.9 }, { -0.4, 0.5, 0.95 } }) do
		P(ball, "Cloud" .. index, "Ball", Vector3.new(c[3], c[3] * 0.7, c[3]), at(c[1], 3.4 + c[2], 0), cloud, { Mode = "Upright" })
	end

	-- Lightning bolt zig-zag under the cloud
	local bolt = rgb(255, 235, 90)
	local pieces = { { 0.1, 2.6, 0.2 }, { -0.15, 2.2, -0.35 }, { 0.15, 1.8, 0.4 } }
	for index, piece in ipairs(pieces) do
		P(ball, "Bolt" .. index, "Block", Vector3.new(0.18, 0.6, 0.12), at(piece[1], piece[2] + 0.9, -0.6) * CFrame.Angles(0, 0, piece[3]), bolt, { Mode = "Upright", Mat = Enum.Material.Neon })
	end

	local rain = P(ball, "Rain", "Ball", Vector3.new(0.4, 0.4, 0.4), at(0, 3.2, 0), cloud, { Mode = "Upright", Transp = 1 })
	emitter(rain, {
		Rate = 26, Lifetime = NumberRange.new(0.6, 0.9), Speed = NumberRange.new(6, 8),
		SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Bottom,
		Color = ColorSequence.new(rgb(120, 190, 255)), Size = NumberSequence.new(0.18),
		LightEmission = 0.4,
	})
end

----------------------------------------------------------------
-- 19  SINGLEKNOT: a dragon flying around the ball
----------------------------------------------------------------
designs.SingleKnot = function(ball)
	local red = rgb(205, 40, 52)
	local darkRed = rgb(140, 25, 42)
	local gold = rgb(255, 205, 70)
	local membrane = rgb(165, 30, 60)
	local radius = 4.8

	local function orbit(phase, flap)
		return { Radius = radius, Speed = 1.0, Height = 1.0, Phase = phase, Tilt = 0.16, Bob = 0.5, Flap = flap or 0 }
	end

	-- HEAD (leads the flight; local -Z is the direction of travel)
	local headPhase = 0.0
	P(ball, "DragonHead", "Ball", Vector3.new(1.8, 1.45, 1.9), CFrame.new(), red, { Mode = "Orbit", Orbit = orbit(headPhase) })
	P(ball, "DragonSnout", "Ball", Vector3.new(1.0, 0.75, 1.2), CFrame.new(0, -0.15, -1.1), rgb(225, 90, 80), { Mode = "Orbit", Orbit = orbit(headPhase) })
	P(ball, "DragonJaw", "Block", Vector3.new(0.8, 0.2, 1.0), CFrame.new(0, -0.5, -1.0), darkRed, { Mode = "Orbit", Orbit = orbit(headPhase) })

	for _, side in ipairs({ -1, 1 }) do
		-- big glowing eyes
		P(ball, "DragonEye", "Ball", Vector3.new(0.38, 0.38, 0.2), CFrame.new(side * 0.52, 0.3, -0.6), rgb(255, 235, 70), { Mode = "Orbit", Mat = Enum.Material.Neon, Orbit = orbit(headPhase) })
		P(ball, "DragonPupil", "Ball", Vector3.new(0.14, 0.3, 0.1), CFrame.new(side * 0.52, 0.3, -0.7), INK, { Mode = "Orbit", Orbit = orbit(headPhase) })
		-- long swept-back horns
		P(ball, "DragonHorn", "Pyramid", Vector3.new(0.36, 1.5, 0.36), CFrame.new(side * 0.55, 0.85, 0.35) * CFrame.Angles(0.9, 0, -side * 0.35), gold, { Mode = "Orbit", Orbit = orbit(headPhase) })
		-- nostrils
		P(ball, "DragonNostril", "Ball", Vector3.new(0.12, 0.12, 0.12), CFrame.new(side * 0.2, 0.05, -1.62), INK, { Mode = "Orbit", Orbit = orbit(headPhase) })
	end

	local breath = P(ball, "DragonBreath", "Ball", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, -0.15, -1.9), red, { Mode = "Orbit", Transp = 1, Orbit = orbit(headPhase) })
	emitter(breath, {
		Texture = FIRE, Rate = 70, Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(7, 10), SpreadAngle = Vector2.new(9, 9),
		Color = ColorSequence.new(rgb(255, 215, 90), rgb(255, 60, 20)),
		Size = NumberSequence.new(1.3, 0), LightEmission = 1,
		EmissionDirection = Enum.NormalId.Front,
	})

	-- NECK + BODY: tapering segments trailing behind the head
	local segments = 12
	local spacing = 0.15
	for index = 1, segments do
		local t = index / segments
		local size = 1.75 - t * 1.15
		local phase = -index * spacing - 0.18
		local color = (index % 2 == 0) and red or darkRed

		P(ball, "DragonBody" .. index, "Ball", Vector3.new(size, size * 0.92, size * 1.3), CFrame.new(), color, { Mode = "Orbit", Orbit = orbit(phase) })
		-- gold belly plate
		P(ball, "DragonBelly" .. index, "Ball", Vector3.new(size * 0.7, size * 0.4, size * 1.1), CFrame.new(0, -size * 0.42, 0), gold, { Mode = "Orbit", Orbit = orbit(phase) })
		-- gold spine spike
		P(ball, "DragonSpine" .. index, "Pyramid", Vector3.new(0.28, 0.5 + (1 - t) * 0.35, 0.28), CFrame.new(0, size * 0.62, 0), gold, { Mode = "Orbit", Orbit = orbit(phase) })
	end

	-- TAIL: thin tail and a gold blade tip
	local tailBase = -segments * spacing - 0.18
	for index = 1, 3 do
		local size = 0.5 - index * 0.1
		P(ball, "DragonTail" .. index, "Ball", Vector3.new(size, size, size * 1.4), CFrame.new(), darkRed, { Mode = "Orbit", Orbit = orbit(tailBase - index * 0.17) })
	end
	P(ball, "DragonTailBlade", "Pyramid", Vector3.new(0.5, 1.1, 0.12), CFrame.new(0, 0, 0.5) * CFrame.Angles(math.pi / 2, 0, 0), gold, { Mode = "Orbit", Orbit = orbit(tailBase - 0.72) })

	-- WINGS: large membrane with a gold leading bone, flapping
	local wingPhase = -2 * spacing - 0.18
	for _, side in ipairs({ -1, 1 }) do
		local flap = 0.7 * side
		local tilt = CFrame.Angles(0, 0, side * 0.35)
		local rootX, rootY = side * 0.7, 1.0

		-- Arm: a gold bone rising from the shoulder (root sits ON the body,
		-- so the flap pivots around the shoulder).
		P(ball, "DragonWingBone", "Block", Vector3.new(3.4, 0.28, 0.28),
			CFrame.new(rootX + side * 1.65, rootY + 0.3, 0) * tilt,
			gold, { Mode = "Orbit", Orbit = orbit(wingPhase, flap) })

		-- Membrane: three overlapping panels fanning back from the arm.
		local lengths = { 3.2, 2.7, 2.0 }
		for index, length in ipairs(lengths) do
			P(ball, "DragonWing" .. index, "Block", Vector3.new(length, 0.07, 1.25),
				CFrame.new(rootX + side * (length / 2 + 0.05), rootY + 0.2 - index * 0.12, 0.45 + (index - 1) * 0.85) * tilt,
				membrane, { Mode = "Orbit", Transp = 0.08, Orbit = orbit(wingPhase, flap) })
		end
	end
end

--------------------------------------------------
-- PUBLIC API
--------------------------------------------------

function BallAccessories.HasDesign(ballId)
	return designs[ballId] ~= nil
end

function BallAccessories.Apply(ball, ballId)
	local design = designs[ballId]
	if not design or not ball or ball:GetAttribute("AccessoriesApplied") then
		return
	end

	ball:SetAttribute("AccessoriesApplied", true)

	local ok, err = pcall(design, ball)
	if not ok then
		warn("[BallAccessories] Could not build", ballId, err)
		return
	end

	CollectionService:AddTag(ball, "AccBall")

	-- Start orbit/upright parts in a sensible pose right away (clients
	-- keep animating them every frame).
	BallAccessories.Pose(ball, 0)
end

function BallAccessories.SetScale(ball)
	local scale = scaleOf(ball)

	for _, child in ipairs(ball:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("AccMode") then
			local baseSize = child:GetAttribute("BaseSize")
			if typeof(baseSize) == "Vector3" then
				child.Size = baseSize * scale
			end

			local weld = child:FindFirstChild("AccWeld")
			local baseCF = child:GetAttribute("BaseC0")
			if weld and typeof(baseCF) == "CFrame"
				and child:GetAttribute("AccMode") == "Rolling" then
				weld.C0 = CFrame.new(baseCF.Position * scale) * (baseCF - baseCF.Position)
			end
		end
	end
end

-- Animate Upright / Orbit parts. `now` is a time in seconds.
function BallAccessories.Pose(ball, now)
	local scale = scaleOf(ball)
	local center = ball.Position

	for _, child in ipairs(ball:GetChildren()) do
		if child:IsA("BasePart") then
			local mode = child:GetAttribute("AccMode")

			if mode == "Upright" or mode == "Orbit" then
				local weld = child:FindFirstChild("AccWeld")
				local baseCF = child:GetAttribute("BaseC0")

				if weld and typeof(baseCF) == "CFrame" then
					local world

					-- Welded to a ROLLING ball, these parts get thrown around by
					-- the ball's spin between frames (that was the choppiness).
					-- Each client therefore detaches them locally and places
					-- them straight from the ball's position every frame.
					if IS_CLIENT and not child.Anchored then
						weld.Enabled = false
						child.Anchored = true
					end

					if mode == "Upright" then
						world = CFrame.new(center + baseCF.Position * scale) * (baseCF - baseCF.Position)
					else
						local speed = child:GetAttribute("OrbitSpeed") or 1
						local phase = child:GetAttribute("OrbitPhase") or 0
						local radius = (child:GetAttribute("OrbitRadius") or 3) * scale
						local height = (child:GetAttribute("OrbitHeight") or 0) * scale
						local bob = (child:GetAttribute("OrbitBob") or 0) * scale
						local tilt = child:GetAttribute("OrbitTilt") or 0
						local flap = child:GetAttribute("Flap") or 0

						local angle = now * speed + phase
						local direction = speed >= 0 and 1 or -1
						local position = Vector3.new(
							math.cos(angle) * radius,
							height + math.sin(now * 2.2 + phase) * bob,
							math.sin(angle) * radius
						)
						local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * direction

						local frame = CFrame.lookAt(center + position, center + position + tangent)
						if tilt ~= 0 then
							frame = CFrame.new(center) * CFrame.Angles(tilt, 0, 0) * CFrame.new(-center) * frame
						end

						if flap ~= 0 then
							frame = frame * CFrame.Angles(0, 0, math.sin(now * 8 + phase) * math.abs(flap) * (flap > 0 and 1 or -1))
						end

						world = frame * CFrame.new(baseCF.Position * scale) * (baseCF - baseCF.Position)
					end

					weld.C0 = ball.CFrame:ToObjectSpace(world)

					if child.Anchored then
						child.CFrame = world
					end
				end

			elseif mode == "Rolling" and child.Anchored then
				-- An anchored ball (rack, shop preview) has no physics to
				-- carry its welded parts, so follow it by hand.
				local weld = child:FindFirstChild("AccWeld")
				if weld then
					child.CFrame = ball.CFrame * weld.C0
				end
			end
		end
	end
end

return BallAccessories
