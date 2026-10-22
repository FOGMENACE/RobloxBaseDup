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
local AssetService = game:GetService("AssetService")

-- Oil Barrel model (uploaded assets). The mesh is loaded at runtime with
-- AssetService, so the repo needs no binary copy of it. Native size is the
-- mesh's own bounding box; OIL_BARREL_SCALE sizes it for a radius-2 ball.
local OIL_BARREL_MESH = 105517155573112
local OIL_BARREL_TEXTURE = "rbxassetid://105669825602431"
local OIL_BARREL_NATIVE = Vector3.new(5.785, 5.783, 9.582)
local OIL_BARREL_SCALE = 0.55

local barrelMesh = nil -- MeshPart template, filled in by the task below
local barrelMeshFailed = false

task.spawn(function()
	local ok, part = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromAssetId(OIL_BARREL_MESH))
	end)

	if ok and part then
		part.TextureID = OIL_BARREL_TEXTURE
		barrelMesh = part
	else
		barrelMeshFailed = true
		warn("[BallAccessories] Oil Barrel mesh could not load, using the parts barrel:", part)
	end
end)

-- Waits briefly for the mesh; nil means "use the parts-built barrel".
local function waitForBarrelMesh()
	local waited = 0
	while not barrelMesh and not barrelMeshFailed and waited < 4 do
		task.wait(0.1)
		waited += 0.1
	end
	return barrelMesh
end
-- Cone for spikes, prongs, horns and teeth. SpecialMesh MeshType.Pyramid no
-- longer renders at all, so every "Pyramid" accessory was invisible. The cone
-- is generated once in code (EditableMesh -> MeshPart, no uploaded asset) and
-- cloned per spike; if that API is unavailable a stretched sphere is used.
local coneTemplate = nil
local coneFailed = false

task.spawn(function()
	local ok, part = pcall(function()
		local em = AssetService:CreateEditableMesh()
		local SIDES = 12
		local tip = em:AddVertex(Vector3.new(0, 0.5, 0))
		local bottom = em:AddVertex(Vector3.new(0, -0.5, 0))
		local ring = {}
		for index = 0, SIDES - 1 do
			local angle = index / SIDES * math.pi * 2
			ring[index] = em:AddVertex(Vector3.new(math.cos(angle) * 0.5, -0.5, math.sin(angle) * 0.5))
		end
		for index = 0, SIDES - 1 do
			local nextIndex = (index + 1) % SIDES
			em:AddTriangle(tip, ring[nextIndex], ring[index])
			em:AddTriangle(bottom, ring[index], ring[nextIndex])
		end
		return AssetService:CreateMeshPartAsync(Content.fromObject(em))
	end)

	if ok and part then
		coneTemplate = part
	else
		coneFailed = true
		warn("[BallAccessories] Cone mesh unavailable, spikes use stretched spheres:", part)
	end
end)

local function waitForCone()
	local waited = 0
	while not coneTemplate and not coneFailed and waited < 3 do
		task.wait(0.1)
		waited += 0.1
	end
	return coneTemplate
end

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

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
-- Set by Apply(..., true) while swapping accessories onto a ball that is
-- already rolling: new parts are then anchored and un-welded, because
-- joining new parts to a live physics assembly makes the client freeze the
-- ball for ~0.25 s. Every client already positions anchored accessories by
-- hand each frame (see Pose).
local detachMode = false

local function make(ball, spec)
	local scale = scaleOf(ball)
	local kind = spec.Kind or "Block"

	local part
	-- code-built meshes never replicate: a cone made on the SERVER shows up as a
	-- red/green checker for every player, so only client-side builds (shop
	-- previews, racks) use it; server-built accessories use the block prong
	local cone = (kind == "Pyramid" and IS_CLIENT) and waitForCone() or nil
	if spec.Template then
		part = spec.Template:Clone()
	elseif cone then
		-- a plain Clone of a code-built MeshPart loses its mesh data (renders as a
		-- checker); ApplyMesh copies the real geometry onto the clone
		part = cone:Clone()
		pcall(function()
			part:ApplyMesh(cone)
		end)
	elseif kind == "Pyramid" then
		-- fallback (EditableMesh off): a slim block prong. SpecialMesh shapes now
		-- render as a red/green placeholder checker, so no SpecialMesh is used.
		part = Instance.new("Part")
		part.Shape = Enum.PartType.Block
	elseif kind == "Wedge" then
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
	part:SetAttribute("AccKind", kind)
	part.Size = spec.Size * scale
	part.Color = spec.Color or CREAM
	part.Material = spec.Mat or Enum.Material.SmoothPlastic
	part.Transparency = spec.Transp or 0
	if part:IsA("MeshPart") then
		part.DoubleSided = false
	end
	if part:IsA("Part") or part:IsA("WedgePart") then
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
	end
	part.Massless = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Anchored = ball.Anchored or detachMode
	part.Reflectance = spec.Refl or 0


	local mode = spec.Mode or "Rolling"
	part:SetAttribute("AccMode", mode)
	-- optional idle animation (see Pose): Bob/BobSpeed/Spin move Upright parts,
	-- Glow pulses transparency, Flicker flashes the part (and its light) like lightning
	for _, key in ipairs({ "Bob", "BobSpeed", "Spin", "Glow", "Flicker", "AnimPhase" }) do
		if spec[key] ~= nil then
			part:SetAttribute(key, spec[key])
		end
	end
	if spec.Glow or spec.Flicker then
		part:SetAttribute("BaseTransp", part.Transparency)
	end
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

	weld.Enabled = not detachMode
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

	-- cratered moon surface: darker rimmed dents rolling with the ball
	for index, dir in ipairs(sphereDirections(9)) do
		local size = (index % 3 == 0) and 1.3 or 0.85
		P(ball, "CraterRim" .. index, "Cylinder", Vector3.new(0.12, size * 1.25, size * 1.25), orientY(dir * (R - 0.02), dir) * CFrame.Angles(0, 0, math.pi / 2), rgb(150, 150, 165))
		P(ball, "Crater" .. index, "Cylinder", Vector3.new(0.14, size, size), orientY(dir * (R - 0.01), dir) * CFrame.Angles(0, 0, math.pi / 2), rgb(70, 70, 82))
	end

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
	-- A living storm cloud above the ball (Upright, massless, non-colliding):
	-- the whole cloud slowly swirls, every puff breathes on its own, lightning
	-- flashes with a real light, plus mist and rain. It sits high enough to
	-- never cover the lane.
	local top = rgb(222, 228, 240)
	local mid = rgb(158, 166, 186)
	local base = rgb(92, 100, 122)
	local H = 4.1
	local random = Random.new(18)
	local puffs = {
		{ 0, 0.4, 0, 1.6, top }, { 0.9, 0.3, 0.2, 1.3, top }, { -0.9, 0.25, -0.15, 1.35, top },
		{ 0.35, 0.7, -0.4, 1.1, top }, { -0.4, 0.65, 0.45, 1.05, top }, { 0.1, 0.85, 0.1, 0.9, top },
		{ 1.55, -0.05, -0.15, 1.0, mid }, { -1.6, -0.05, 0.2, 1.0, mid }, { 0.55, -0.05, 0.8, 1.05, mid },
		{ -0.5, -0.05, -0.8, 1.05, mid }, { 1.0, -0.1, -0.65, 0.9, mid }, { -1.0, -0.1, 0.7, 0.9, mid },
		{ 0, -0.35, 0, 1.7, base }, { 0.85, -0.35, 0.25, 1.15, base }, { -0.85, -0.35, -0.2, 1.2, base },
		{ 0.3, -0.38, -0.7, 1.0, base }, { -0.3, -0.38, 0.7, 1.0, base },
	}
	for index, c in ipairs(puffs) do
		P(ball, "Cloud" .. index, "Ball", Vector3.new(c[4], c[4], c[4]), at(c[1], H + c[2], c[3]), c[5], {
			Mode = "Upright", Mat = Enum.Material.SmoothPlastic,
			Spin = 0.35, Bob = 0.07 + random:NextNumber() * 0.06, BobSpeed = 1.4 + random:NextNumber(), AnimPhase = random:NextNumber() * 6,
		})
	end

	local mist = P(ball, "Mist", "Ball", Vector3.new(0.4, 0.4, 0.4), at(0, H, 0), mid, { Mode = "Upright", Transp = 1 })
	emitter(mist, {
		Texture = SMOKE, Rate = 7, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(0.1, 0.4),
		SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-15, 15),
		Color = ColorSequence.new(rgb(196, 202, 218)), Size = NumberSequence.new(2.4, 3.2),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.72), NumberSequenceKeypoint.new(1, 1) }),
	})

	-- two lightning bolts that flash at different times, one lights the ball
	local bolt = rgb(255, 240, 130)
	for b, x in ipairs({ -0.45, 0.55 }) do
		local zig = { { 0.0, -0.8, 0.4, 0.6 }, { -0.15, -1.3, -0.5, 0.65 }, { 0.1, -1.8, 0.45, 0.55 } }
		for index, piece in ipairs(zig) do
			local part = P(ball, "Bolt" .. b .. "_" .. index, "Block", Vector3.new(0.12, piece[4], 0.08),
				at(x + piece[1], H + piece[2], -0.35) * CFrame.Angles(0, 0, piece[3]), bolt,
				{ Mode = "Upright", Mat = Enum.Material.Neon, Flicker = true, AnimPhase = b * 1.3, Spin = 0.35 })
			if index == 2 and b == 1 then
				local light = Instance.new("PointLight")
				light.Color = rgb(200, 220, 255)
				light.Brightness = 3
				light.Range = 12
				light.Parent = part
			end
		end
	end

	local rain = P(ball, "Rain", "Ball", Vector3.new(0.4, 0.4, 0.4), at(0, H - 0.6, 0), base, { Mode = "Upright", Transp = 1 })
	emitter(rain, {
		Rate = 34, Lifetime = NumberRange.new(0.35, 0.5), Speed = NumberRange.new(7, 9),
		SpreadAngle = Vector2.new(20, 20), EmissionDirection = Enum.NormalId.Bottom,
		Color = ColorSequence.new(rgb(150, 205, 255)), Size = NumberSequence.new(0.08),
		Transparency = NumberSequence.new(0.2, 0.6), LightEmission = 0.3,
	})
end
----------------------------------------------------------------
-- 19  SINGLEKNOT: a dragon flying around the ball
----------------------------------------------------------------
local function partsDragon(ball)
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

----------------------------------------------------------------
-- OILBARREL (exclusive): a glossy rainbow oil barrel rolling on its side
--
-- The invisible physics sphere keeps the rolling; every visible part is
-- posed by Pose() in "Barrel" mode: it turns toward the direction of
-- travel and spins about its side axis. "OIL" is printed on three label
-- plates around the barrel, and sparks scrape off the bottom while it
-- rolls fast (their Rate is driven from Pose by the ball's speed).
----------------------------------------------------------------
designs.OilBarrel = function(ball)
	local function b(extra)
		extra = extra or {}
		extra.Mode = "Barrel"
		return extra
	end

	-- the physics sphere stays (so rolling and collisions are unchanged)
	-- but is invisible
	ball.Transparency = 1

	local function procedural()
	local rainbow = {
		rgb(236, 60, 72), rgb(255, 146, 40), rgb(255, 214, 54), rgb(70, 206, 100),
		rgb(54, 196, 236), rgb(82, 112, 240), rgb(172, 90, 238),
	}
	local radius = 1.75
	local bandLength = 0.62
	local count = #rainbow

	for index, color in ipairs(rainbow) do
		local x = (index - (count + 1) / 2) * bandLength
		P(ball, "Band" .. index, "Cylinder", Vector3.new(bandLength + 0.01, radius * 2, radius * 2), at(x, 0, 0), color, b({ Refl = 0.14 }))
	end

	-- dark metal hoops
	for _, x in ipairs({ -1.95, -1.1, 1.1, 1.95 }) do
		P(ball, "Hoop", "Cylinder", Vector3.new(0.16, radius * 2 + 0.14, radius * 2 + 0.14), at(x, 0, 0), rgb(50, 52, 70), b({ Mat = Enum.Material.Metal }))
	end

	-- lids with a bung
	for _, side in ipairs({ -1, 1 }) do
		P(ball, "Lid", "Cylinder", Vector3.new(0.12, radius * 2 - 0.3, radius * 2 - 0.3), at(side * 2.2, 0, 0), rgb(205, 208, 222), b({ Mat = Enum.Material.Metal, Refl = 0.2 }))
		P(ball, "Bung", "Cylinder", Vector3.new(0.2, 0.55, 0.55), at(side * 2.27, 0.55, 0), rgb(70, 72, 92), b())
	end

	-- three "OIL" label plates around the barrel
	for k = 0, 2 do
		local phi = k * (2 * math.pi / 3)
		local d = Vector3.new(0, math.cos(phi), math.sin(phi))
		local t = Vector3.new(0, -math.sin(phi), math.cos(phi))
		local cf = CFrame.fromMatrix(d * (radius + 0.03), Vector3.xAxis, t, -d)

		local plate = P(ball, "Label", "Block", Vector3.new(2.0, 1.25, 0.06), cf, CREAM, b())

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 80
		gui.LightInfluence = 0.2
		gui.Parent = plate

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.FredokaOne
		text.Text = "OIL"
		text.TextScaled = true
		text.TextColor3 = rgb(30, 28, 44)
		text.Parent = gui

		local stroke = Instance.new("UIStroke")
		stroke.Color = rgb(255, 255, 255)
		stroke.Thickness = 2
		stroke.Parent = text
	end
	end -- procedural

	-- the real model when it loaded, otherwise the parts-built barrel
	local template = waitForBarrelMesh()
	if template then
		P(
			ball,
			"Body",
			"Block",
			OIL_BARREL_NATIVE * OIL_BARREL_SCALE,
			CFrame.Angles(0, math.pi / 2, 0),
			Color3.new(1, 1, 1),
			b({ Template = template, Refl = 0.1 })
		)
	else
		procedural()
	end

	-- where the barrel touches the ground: sparks + a little rainbow glitter
	local spark = P(ball, "SparkPoint", "Block", Vector3.new(0.3, 0.3, 0.3), at(0, -1.8, 0.2), INK, { Mode = "BarrelYaw", Transp = 1 })

	-- Train-track sparks: short, hot streaks thrown back and up from the
	-- metal-on-lane contact, arcing down under gravity. White-hot core fading
	-- to orange and a dark rusty red (corroded steel), no star sparkles.
	emitter(spark, {
		Name = "Sparks",
		Texture = SMOKE, -- soft blob, stretched into a streak by VelocityParallel + Squash
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Rate = 0,
		Lifetime = NumberRange.new(0.12, 0.26),
		Speed = NumberRange.new(16, 30),
		SpreadAngle = Vector2.new(14, 24),
		Acceleration = Vector3.new(0, -85, 0),
		Drag = 0.4,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 252, 214)),
			ColorSequenceKeypoint.new(0.25, rgb(255, 176, 56)),
			ColorSequenceKeypoint.new(0.7, rgb(214, 84, 24)),
			ColorSequenceKeypoint.new(1, rgb(110, 40, 22)),
		}),
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.75),
			NumberSequenceKeypoint.new(1, 0.12),
		}),
		Squash = NumberSequence.new(-0.9),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Front,
	})

	-- a few slow glowing embers that float off the streaks
	emitter(spark, {
		Name = "Embers",
		Texture = SMOKE,
		Rate = 10,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(3, 8),
		SpreadAngle = Vector2.new(70, 70),
		Acceleration = Vector3.new(0, -6, 0),
		Color = ColorSequence.new(rgb(255, 150, 50), rgb(160, 60, 24)),
		Size = NumberSequence.new(0.14, 0),
		Transparency = NumberSequence.new(0.1, 1),
		LightEmission = 1,
		EmissionDirection = Enum.NormalId.Top,
	})
end

----------------------------------------------------------------
-- 19  SINGLEKNOT: "The Red Depth" dragon (Blender, assets/models/RedDepth_*.fbx)
-- plus a rope slip knot around the ball (assets/models/SlipKnot_Rope.fbx),
-- circling the ball. Uses the parts dragon above until the four meshes are
-- uploaded and their ids pasted here. Each piece keeps the model's shared
-- origin (the ball centre) via its bounding-box centre offset below.
----------------------------------------------------------------
local DRAGON = {
	-- "The Red Depth": black armoured leviathan coiling around the ball
	{ Key = "Body", Mesh = 99074531238023, Center = Vector3.new(0.572, 0.666, -0.243), Size = Vector3.new(9.831, 3.291, 9.855), Color = rgb(22, 18, 22), Mat = Enum.Material.SmoothPlastic, Refl = 0.12 },
	{ Key = "Spikes", Mesh = 106823113074233, Center = Vector3.new(0.671, 1.307, -0.449), Size = Vector3.new(10.702, 4.369, 10.606), Color = rgb(120, 6, 14), Mat = Enum.Material.SmoothPlastic, Refl = 0.1 },
	{ Key = "Glow", Mesh = 108274450389945, Center = Vector3.new(0.473, 0.493, -0.158), Size = Vector3.new(9.287, 2.977, 9.489), Color = rgb(255, 30, 30), Mat = Enum.Material.Neon },
}
-- the slip knot: a twisted rope tied around the ball; it stays upright while
-- the ball rolls inside it
local KNOT = { Mesh = 110792426705988, Center = Vector3.new(0.004, 0.176, 0), Size = Vector3.new(4.573, 4.709, 4.362), Color = rgb(150, 110, 62) }local dragonTemplates = {}
local dragonReady = false
task.spawn(function()
	for _, piece in ipairs(DRAGON) do
		if piece.Mesh == 0 then
			return -- not uploaded yet: keep the parts dragon
		end
	end
	for _, piece in ipairs(DRAGON) do
		local ok, part = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromAssetId(piece.Mesh))
		end)
		if not ok or not part then
			warn("[BallAccessories] dragon mesh failed to load:", piece.Key, part)
			return
		end
		dragonTemplates[piece.Key] = part
	end
	if KNOT.Mesh ~= 0 then
		local ok, part = pcall(function()
			return AssetService:CreateMeshPartAsync(Content.fromAssetId(KNOT.Mesh))
		end)
		if ok and part then
			dragonTemplates.Knot = part
		end
	end
	dragonReady = true
end)

designs.SingleKnot = function(ball)
	local waited = 0
	while not dragonReady and waited < 3 and DRAGON[1].Mesh ~= 0 do
		task.wait(0.1)
		waited += 0.1
	end
	if not dragonReady then
		return partsDragon(ball)
	end
	-- FBX export flips Z relative to the numbers measured in Blender, and the
	-- coil is drawn 25% smaller so it hugs the ball instead of filling the lane
	-- display balls (wall racks, shelves) sit against walls: a full-size coil
	-- poked through the walls and floated outside the lobby, so they get a small one
	local live = ball:GetAttribute("OwnerUserId") ~= nil or (ball.Parent ~= nil and ball.Parent.Name == "PlayerBalls")
	local DRAGON_SCALE = live and 0.75 or 0.45
	-- on a wall rack the coil is pushed toward the room so it stays in view
	local shift = Vector3.zero
	if not live then
		local okW, WC = pcall(function()
			return require(game:GetService("ReplicatedStorage"):WaitForChild("WorldConfig", 2))
		end)
		local centerX = -65 + ((okW and WC) and WC.AtPosition(ball.Position).Offset.X or 0)
		shift = Vector3.new((centerX > ball.Position.X) and 1.6 or -1.6, 0.6, 0)
	end
	for _, piece in ipairs(DRAGON) do
		local c = piece.Center
		P(ball, "Dragon" .. piece.Key, "Block", piece.Size * DRAGON_SCALE, CFrame.new(Vector3.new(c.X, c.Y, -c.Z) * DRAGON_SCALE + shift / scaleOf(ball)), piece.Color, {
			Template = dragonTemplates[piece.Key], Mat = piece.Mat, Refl = piece.Refl, Transp = piece.Transp,
			Mode = "Upright", Spin = -1.1, Bob = 0.35, BobSpeed = 1.6,
		})
	end
	if dragonTemplates.Knot then
		P(ball, "SlipKnot", "Block", KNOT.Size, CFrame.new(KNOT.Center), KNOT.Color, {
			Template = dragonTemplates.Knot, Mat = Enum.Material.Fabric, Mode = "Upright",
		})
	end
	local fire = P(ball, "DragonBreath", "Ball", Vector3.new(0.3, 0.3, 0.3), CFrame.new(Vector3.new(4.4, 1.6, -1.5) * 0.75), rgb(255, 140, 40), { Mode = "Upright", Transp = 1, Spin = -1.1, Bob = 0.35, BobSpeed = 1.6 })
	emitter(fire, {
		Texture = FIRE, Rate = 22, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(15, 15), Color = ColorSequence.new(rgb(255, 200, 80), rgb(255, 60, 20)),
		Size = NumberSequence.new(0.6, 0), LightEmission = 0.9,
	})
end
----------------------------------------------------------------
-- 2  AFTERSHOCK: glowing fault-line cracks and a pulsing shock ring
----------------------------------------------------------------
designs.Aftershock = function(ball)
	local glow = rgb(170, 120, 255)
	-- jagged crack lines that roll with the ball
	local cracks = {
		{ Vector3.new(0, 1, 0), 0.0 }, { Vector3.new(1, 0.2, 0), 1.1 }, { Vector3.new(-0.6, -0.3, 0.8), 2.3 },
		{ Vector3.new(0.3, -0.8, -0.6), 0.6 }, { Vector3.new(-0.8, 0.5, -0.4), 1.8 },
	}
	for index, crack in ipairs(cracks) do
		local dir = crack[1].Unit
		for segment = -1, 1 do
			P(ball, "Crack" .. index .. "_" .. segment, "Block", Vector3.new(0.14, 0.06, 0.95),
				orientY(dir * (R + 0.01), dir) * CFrame.Angles(0, crack[2] + segment * 0.7, 0) * CFrame.new(0, 0, segment * 0.75),
				glow, { Mat = Enum.Material.Neon })
		end
	end
	-- two flat rings orbiting like a shock wave
	for index = 1, 2 do
		for piece = 1, 10 do
			P(ball, "Shock" .. index .. "_" .. piece, "Block", Vector3.new(0.18, 0.08, 0.5), CFrame.new(), glow, {
				Mat = Enum.Material.Neon, Transp = 0.35, Mode = "Orbit",
				Orbit = { Radius = 2.9 + index * 0.35, Speed = index == 1 and 2.2 or -1.7, Height = -0.8 + index * 0.3, Phase = (piece / 10) * math.pi * 2, Tilt = 0 },
			})
		end
	end
end

----------------------------------------------------------------
-- 4  THRIFTY: a gold coin band, a price tag and a few orbiting coins
----------------------------------------------------------------
designs.Thrifty = function(ball)
	local gold = rgb(255, 205, 70)
	P(ball, "Band", "Cylinder", Vector3.new(0.55, 4.12, 4.12), CFrame.Angles(0, 0, math.pi / 2), gold, { Mat = Enum.Material.Metal })
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		P(ball, "Stud" .. index, "Cylinder", Vector3.new(0.12, 0.42, 0.42), orientY(dir * (R + 0.08), dir) * CFrame.Angles(0, 0, math.pi / 2), rgb(255, 240, 170), { Mat = Enum.Material.Neon })
	end
	-- price tag hanging upright beside the ball
	P(ball, "Tag", "Block", Vector3.new(0.9, 0.55, 0.08), at(1.6, 1.9, -0.6) * CFrame.Angles(0, 0, -0.35), CREAM, { Mode = "Upright" })
	P(ball, "TagHole", "Cylinder", Vector3.new(0.1, 0.16, 0.16), at(1.35, 2.05, -0.65) * CFrame.Angles(0, math.pi / 2, 0), INK, { Mode = "Upright" })
	P(ball, "TagMark", "Block", Vector3.new(0.4, 0.1, 0.1), at(1.65, 1.85, -0.66) * CFrame.Angles(0, 0, -0.35), rgb(60, 160, 80), { Mode = "Upright" })
	for index = 1, 3 do
		P(ball, "Coin" .. index, "Cylinder", Vector3.new(0.12, 0.8, 0.8), CFrame.new(), gold, {
			Mat = Enum.Material.Metal, Mode = "Orbit",
			Orbit = { Radius = 3.0, Speed = 1.3, Height = 0.4, Phase = index * 2.09, Tilt = 0.25, Bob = 0.35 },
		})
	end
end

----------------------------------------------------------------
-- QUALITY PASS: extra detail and idle animation on top of each design
----------------------------------------------------------------
local function extend(ballId, extra)
	local original = designs[ballId]
	designs[ballId] = function(ball)
		if original then
			original(ball)
		end
		extra(ball)
	end
end

local function animateUpright(ball, props)
	for _, child in ipairs(ball:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("AccMode") == "Upright" then
			for key, value in pairs(props) do
				if child:GetAttribute(key) == nil then
					child:SetAttribute(key, value)
				end
			end
		end
	end
end

local function sparkles(ball, color, rate, height)
	local holder = P(ball, "Sparkles", "Ball", Vector3.new(0.4, 0.4, 0.4), at(0, height or 0, 0), color, { Mode = "Upright", Transp = 1 })
	emitter(holder, {
		Texture = SPARKLE, Rate = rate or 6, Lifetime = NumberRange.new(0.6, 1.1),
		Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180),
		Color = ColorSequence.new(color), Size = NumberSequence.new(0.45, 0), LightEmission = 1,
	})
	holder:FindFirstChildOfClass("ParticleEmitter").Shape = Enum.ParticleEmitterShape.Sphere
	return holder
end

-- 2  AFTERSHOCK: rock debris circling and cracks that throb
extend("Aftershock", function(ball)
	for _, child in ipairs(ball:GetChildren()) do
		if child.Name:find("^Acc_Crack") then
			child:SetAttribute("Glow", 0.5)
			child:SetAttribute("BaseTransp", 0)
		end
	end
	local random = Random.new(2)
	for index = 1, 6 do
		local s = 0.35 + random:NextNumber() * 0.3
		P(ball, "Debris" .. index, "Block", Vector3.new(s, s * 0.8, s), CFrame.Angles(random:NextNumber() * 3, random:NextNumber() * 3, 0), rgb(90, 70, 120), {
			Mat = Enum.Material.Slate, Mode = "Orbit",
			Orbit = { Radius = 3.2, Speed = 1.1, Height = -0.6, Phase = index * 1.05, Tilt = 0.15, Bob = 0.5 },
		})
	end
end)

-- 3  CATPLZ: the cat breathes, gets a collar and a bell
extend("CatPlz", function(ball)
	P(ball, "Collar", "Cylinder", Vector3.new(0.18, 1.25, 1.25), at(0, 3.0, -0.15) * CFrame.Angles(0, 0, math.pi / 2), rgb(230, 60, 90), { Mode = "Upright" })
	P(ball, "Bell", "Ball", Vector3.new(0.3, 0.3, 0.3), at(0, 2.85, -0.78), rgb(255, 205, 70), { Mode = "Upright", Mat = Enum.Material.Metal })
	animateUpright(ball, { Bob = 0.06, BobSpeed = 2.2 })
end)

-- 4  THRIFTY: the tag sways, coins glint
extend("Thrifty", function(ball)
	animateUpright(ball, { Bob = 0.08, BobSpeed = 1.8 })
	sparkles(ball, rgb(255, 225, 120), 4, 0)
end)

-- 5  VOLTAGE: crackling arcs that flash between the prongs
extend("Voltage", function(ball)
	for index, dir in ipairs(sphereDirections(6)) do
		P(ball, "Arc" .. index, "Block", Vector3.new(0.08, 0.08, 1.6), orientY(dir * (R + 0.45), dir) * CFrame.Angles(0, index, math.pi / 2), rgb(180, 230, 255), {
			Mat = Enum.Material.Neon, Flicker = true, AnimPhase = index * 0.43,
		})
	end
end)

-- 6  VENOM: toxic bubbles rising off the spikes
extend("Venom", function(ball)
	local bubbles = P(ball, "Toxic", "Ball", Vector3.new(0.4, 0.4, 0.4), at(0, 1.2, 0), rgb(120, 255, 90), { Mode = "Upright", Transp = 1 })
	emitter(bubbles, {
		Rate = 8, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(1, 2.5),
		SpreadAngle = Vector2.new(40, 40), Color = ColorSequence.new(rgb(150, 255, 90)),
		Size = NumberSequence.new(0.3, 0.05), Transparency = NumberSequence.new(0.2, 1), LightEmission = 0.6,
	})
end)

-- 7  SNOTOOZE: slime glistens and drips
extend("SnotOoze", function(ball)
	for _, child in ipairs(ball:GetChildren()) do
		if child.Name:find("^Acc_Blob") then
			child.Reflectance = 0.25
		end
	end
	local drip = P(ball, "Dripper", "Ball", Vector3.new(0.4, 0.4, 0.4), at(0, -1.6, 0), rgb(150, 225, 60), { Mode = "Upright", Transp = 1 })
	emitter(drip, {
		Rate = 5, Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0, 1),
		Acceleration = Vector3.new(0, -25, 0), SpreadAngle = Vector2.new(60, 60),
		Color = ColorSequence.new(rgb(150, 225, 60)), Size = NumberSequence.new(0.28, 0.12),
	})
end)

-- 8  METEOR: molten seams throb, embers drift up
extend("Meteor", function(ball)
	for _, child in ipairs(ball:GetChildren()) do
		if child.Name:find("^Acc_Glow") then
			child:SetAttribute("Glow", 0.45)
			child:SetAttribute("BaseTransp", 0)
		end
	end
	sparkles(ball, rgb(255, 150, 60), 10, 0.5)
end)

-- 9  ATTITUDEPAUSIBLE: bling on the chain, the shades glint
extend("AttitudePausible", function(ball)
	for _, child in ipairs(ball:GetChildren()) do
		if child.Name == "Acc_Glint" then
			child:SetAttribute("Flicker", true)
			child:SetAttribute("BaseTransp", 0)
		end
	end
	sparkles(ball, rgb(255, 230, 120), 5, -0.5)
end)

-- 10  GREENNATURE: the flower turns to the sun, leaves drift off
extend("GreenNature", function(ball)
	for _, child in ipairs(ball:GetChildren()) do
		if child.Name:find("^Acc_Petal") or child.Name == "Acc_FlowerCenter" then
			child:SetAttribute("Spin", 0.6)
			child:SetAttribute("Bob", 0.08)
		end
	end
	local leaves = P(ball, "Leaves", "Ball", Vector3.new(0.4, 0.4, 0.4), at(0, 1.5, 0), rgb(90, 200, 90), { Mode = "Upright", Transp = 1 })
	emitter(leaves, {
		Rate = 2, Lifetime = NumberRange.new(1.5, 2.2), Speed = NumberRange.new(0.5, 1.2),
		Acceleration = Vector3.new(0, -2, 0), SpreadAngle = Vector2.new(90, 90), Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90), Color = ColorSequence.new(rgb(90, 200, 90)), Size = NumberSequence.new(0.35, 0.25),
	})
end)

-- 11  DETAILO: a glowing core inside the gyroscope
extend("Detailo", function(ball)
	P(ball, "Core", "Ball", Vector3.new(4.25, 4.25, 4.25), CFrame.new(), rgb(120, 220, 255), { Mat = Enum.Material.ForceField, Transp = 0.1, Glow = 0.5 })
end)

-- 12  NEONVESTOFF: a hazard beacon on top
extend("NeonVestOff", function(ball)
	local beacon = P(ball, "Beacon", "Ball", Vector3.new(0.6, 0.6, 0.6), at(0, 2.4, 0), rgb(255, 150, 30), { Mode = "Upright", Mat = Enum.Material.Neon, Flicker = true })
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 150, 30)
	light.Range = 8
	light.Parent = beacon
	P(ball, "BeaconBase", "Cylinder", Vector3.new(0.25, 0.7, 0.7), at(0, 2.08, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(40, 40, 46), { Mode = "Upright" })
end)

-- 13  STARDOODLE: twinkling stardust
extend("StarDoodle", function(ball)
	sparkles(ball, rgb(255, 235, 120), 9, 0.3)
end)

-- 14  PAINMOON: a soft lunar halo
extend("PainMoon", function(ball)
	P(ball, "Halo", "Ball", Vector3.new(4.9, 4.9, 4.9), CFrame.new(), rgb(170, 200, 255), { Mat = Enum.Material.ForceField, Transp = 0.2, Glow = 0.4 })
end)

-- 15  VOIDMINTER: the void orb swirls and leaks sparks
extend("VoidMinter", function(ball)
	for _, child in ipairs(ball:GetChildren()) do
		if child.Name == "Acc_Void" or child.Name == "Acc_VoidRim" then
			child:SetAttribute("Bob", 0.15)
		end
		if child.Name == "Acc_VoidRim" then
			child:SetAttribute("Glow", 0.2)
			child:SetAttribute("BaseTransp", child.Transparency)
		end
	end
	sparkles(ball, rgb(170, 90, 255), 8, 3.0)
end)

-- 16  VOIDWALKER: eyes blink
extend("Voidwalker", function(ball)
	for _, child in ipairs(ball:GetChildren()) do
		if child.Name == "Acc_Eye" then
			child:SetAttribute("Glow", 0.6)
			child:SetAttribute("BaseTransp", 0)
		end
	end
end)

-- 17  PINKMONSTER: bounces happily
extend("PinkMonster", function(ball)
	animateUpright(ball, { Bob = 0.1, BobSpeed = 3 })
end)

-- 19  SINGLEKNOT: golden embers around the dragon's ball
extend("SingleKnot", function(ball)
	sparkles(ball, rgb(255, 190, 80), 8, 0)
end)

--------------------------------------------------
--------------------------------------------------
-- PUBLIC API
--------------------------------------------------

function BallAccessories.HasDesign(ballId)
	return designs[ballId] ~= nil
end

function BallAccessories.Apply(ball, ballId, detached)
	local design = designs[ballId]
	if not design or not ball or ball:GetAttribute("AccessoriesApplied") then
		return
	end

	ball:SetAttribute("AccessoriesApplied", true)

	detachMode = detached == true
	local ok, err = pcall(design, ball)
	detachMode = false
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

-- Barrel designs (OilBarrel): the barrel keeps its own heading (it turns
-- toward where the ball travels) and spins about its side axis as the ball
-- covers ground, like a barrel rolling on its side.
local barrelStates = setmetatable({}, { __mode = "k" })
local barrelSparkClock = setmetatable({}, { __mode = "k" })

local function barrelFrame(ball, now)
	local state = barrelStates[ball]
	if not state then
		state = { Yaw = 0, Spin = 0, Last = now }
		barrelStates[ball] = state
	end

	local dt = math.clamp(now - state.Last, 0, 0.1)
	state.Last = now

	local velocity = ball.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local previewSpeed = ball:GetAttribute("PreviewSpeed")
	local speed = typeof(previewSpeed) == "number" and previewSpeed or flat.Magnitude

	if flat.Magnitude > 3 then
		local target = math.atan2(flat.X, flat.Z)
		local delta = (target - state.Yaw + math.pi) % (2 * math.pi) - math.pi
		state.Yaw += delta * math.min(1, dt * 8)
	end

	state.Spin += speed * dt / (1.75 * scaleOf(ball))

	return CFrame.Angles(0, state.Yaw, 0), CFrame.Angles(state.Spin, 0, 0), speed
end

-- Animate Upright / Orbit parts. `now` is a time in seconds.
-- Spikes/prongs built on the SERVER are plain blocks (code-built cone meshes do
-- not replicate). Each client swaps them for the real cone locally so a rolling
-- ball looks exactly like its shop preview. Returns the new part, or nil.
local function upgradeProng(ball, old)
	if not coneTemplate then
		return nil
	end
	local new = coneTemplate:Clone()
	pcall(function()
		new:ApplyMesh(coneTemplate)
	end)
	new.Name = old.Name
	new.Size = old.Size
	new.Color = old.Color
	new.Material = old.Material
	new.Transparency = old.Transparency
	new.Reflectance = old.Reflectance
	new.DoubleSided = false
	new.Massless = true
	new.CanCollide = false
	new.CanTouch = false
	new.CanQuery = false
	new.CastShadow = false
	new.Anchored = old.Anchored
	for key, value in pairs(old:GetAttributes()) do
		new:SetAttribute(key, value)
	end
	new:SetAttribute("AccKind", "Cone")

	local oldWeld = old:FindFirstChild("AccWeld")
	local weld = Instance.new("Weld")
	weld.Name = "AccWeld"
	weld.Part0 = ball
	weld.Part1 = new
	weld.C0 = oldWeld and oldWeld.C0 or CFrame.new()
	weld.Enabled = oldWeld == nil or oldWeld.Enabled
	weld.Parent = new
	new.CFrame = old.CFrame

	for _, extra in ipairs(old:GetChildren()) do
		if extra ~= oldWeld then
			extra.Parent = new
		end
	end
	new.Parent = ball
	old:Destroy()
	return new
end

function BallAccessories.Pose(ball, now)
	local scale = scaleOf(ball)
	local center = ball.Position
	local yawCF, spinCF, barrelSpeed = nil, nil, nil

	for _, child in ipairs(ball:GetChildren()) do
		if IS_CLIENT and child.ClassName == "Part" and child:GetAttribute("AccKind") == "Pyramid" then
			child = upgradeProng(ball, child) or child
		end
		if child:IsA("BasePart") then
			local mode = child:GetAttribute("AccMode")
			local animPhase = child:GetAttribute("AnimPhase") or 0

			local glow = child:GetAttribute("Glow")
			if glow then
				child.Transparency = (child:GetAttribute("BaseTransp") or 0) + (math.sin(now * 3 + animPhase) + 1) * 0.5 * glow
			end
			if child:GetAttribute("Flicker") then
				-- two quick flashes, then a pause (about every 2.6 s)
				local k = (now + animPhase) % 2.6
				local on = k < 0.09 or (k > 0.18 and k < 0.27)
				child.Transparency = on and (child:GetAttribute("BaseTransp") or 0) or 1
				local light = child:FindFirstChildOfClass("PointLight")
				if light then
					light.Enabled = on
				end
			end
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
						local offset = baseCF.Position * scale
						local rotation = baseCF - baseCF.Position
						local spin = child:GetAttribute("Spin")
						if spin then
							local turn = CFrame.Angles(0, now * spin, 0)
							offset = turn * offset
							rotation = turn * rotation
						end
						local bob = child:GetAttribute("Bob")
						if bob then
							offset += Vector3.new(0, math.sin(now * (child:GetAttribute("BobSpeed") or 2) + animPhase) * bob * scale, 0)
						end
						world = CFrame.new(center + offset) * rotation
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

			elseif mode == "Barrel" or mode == "BarrelYaw" then
				local weld = child:FindFirstChild("AccWeld")
				local baseCF = child:GetAttribute("BaseC0")

				if weld and typeof(baseCF) == "CFrame" then
					-- detach from the (rolling) ball on this client and place
					-- the part straight from the ball position every frame
					if IS_CLIENT and not child.Anchored then
						weld.Enabled = false
						child.Anchored = true
					end

					if not yawCF then
						yawCF, spinCF, barrelSpeed = barrelFrame(ball, now)
					end

					local turn = (mode == "Barrel") and (yawCF * spinCF) or yawCF
					local world = CFrame.new(center) * turn
						* CFrame.new(baseCF.Position * scale) * (baseCF - baseCF.Position)

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

	-- Train-track sparks: little hot streaks thrown back and up from the
	-- metal-on-lane contact. Real small parts (crisp, unlike a soft
	-- particle), made on this client only, arcing down under gravity and
	-- cooling from white-hot to rusty red. Purely visual.
	if barrelSpeed and IS_CLIENT then
		local spark = ball:FindFirstChild("Acc_SparkPoint")
		local now2 = os.clock()
		local last = barrelSparkClock[ball] or 0

		if spark and barrelSpeed > 12 and now2 - last > 0.025 then
			barrelSparkClock[ball] = now2

			local count = barrelSpeed > 40 and 3 or 2
			for _ = 1, count do
				local streak = Instance.new("Part")
				streak.Name = "TrackSpark"
				streak.Size = Vector3.new(0.06, 0.06, 0.5 + math.random() * 0.45)
				streak.Material = Enum.Material.Neon
				streak.Color = (math.random() < 0.55) and rgb(255, 214, 120)
					or ((math.random() < 0.6) and rgb(255, 130, 40) or rgb(190, 64, 26))
				streak.Anchored = false
				streak.CanCollide = false
				streak.CanTouch = false
				streak.CanQuery = false
				streak.CastShadow = false
				streak.Massless = true

				local back = -(ball.AssemblyLinearVelocity * Vector3.new(1, 0, 1))
				back = back.Magnitude > 1 and back.Unit or Vector3.new(0, 0, -1)
				local side = Vector3.new(-back.Z, 0, back.X)
				local velocity = back * (14 + math.random() * 22)
					+ side * ((math.random() - 0.5) * 12)
					+ Vector3.new(0, 7 + math.random() * 12, 0)

				streak.CFrame = CFrame.lookAt(spark.Position, spark.Position + velocity)
				streak.AssemblyLinearVelocity = velocity
				streak.Parent = workspace
				Debris:AddItem(streak, 0.32 + math.random() * 0.12)
			end
		end
	end
end

return BallAccessories
