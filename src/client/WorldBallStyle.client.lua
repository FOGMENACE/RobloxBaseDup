--------------------------------------------------
-- WORLD BALL STYLE (CLIENT, cosmetic only)
--
-- In the higher worlds every ball is shown as an evolved version of itself:
-- same shape, same accessories, but wrapped in that world's premium finish
-- (chrome-ice in Pro Alley, rich metallic gold in Master Arena, amethyst in
-- the Grandmaster Palace) with clean full colour coverage and reflective
-- highlights, plus a tasteful particle aura: a soft haze of the world's
-- colour, slowly drifting dust and a few glowing embers.
-- The original lobby (world 1) and the ball templates are never touched:
-- this only re-dresses the live balls on this client and restores them.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local STYLE = "WorldStyle"

local saved = setmetatable({}, { __mode = "k" }) -- [part] = { Color, Reflectance, Material }

local function remember(part)
	if not saved[part] then
		saved[part] = {
			Color = part.Color, Reflectance = part.Reflectance, Material = part.Material,
			Texture = part:IsA("MeshPart") and part.TextureID or nil,
		}
	end
end

local function restore(ball)
	for _, child in ipairs(ball:GetChildren()) do
		if child.Name == STYLE then
			child:Destroy()
		end
	end
	for part, o in pairs(saved) do
		if part == ball or part:IsDescendantOf(ball) then
			part.Color, part.Reflectance, part.Material = o.Color, o.Reflectance, o.Material
			if o.Texture and part:IsA("MeshPart") then
				part.TextureID = o.Texture
			end
			saved[part] = nil
		end
	end
	ball:SetAttribute("StyledWorld", nil)
end

-- the wrap: the ball itself gets the full premium coating; its accessories
-- keep their colours but pick up the world tint and a polished sheen, so the
-- design still reads (glowing parts stay glowing)
local function wrap(ball, t)
	remember(ball)
	-- the painted texture would hide the coating: the evolved ball is fully wrapped
	if ball:IsA("MeshPart") then
		ball.TextureID = ""
	end
	ball.Color = t.Wrap:Lerp(ball.Color, 0.12) -- a hint of the original hue survives
	ball.Material = t.WrapMaterial
	-- strong mirror-like highlights on top of the metal finish
	ball.Reflectance = 0.45 + t.Shine * 0.3
	for _, part in ipairs(ball:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 0.95 and part.Material ~= Enum.Material.Neon then
			remember(part)
			part.Color = part.Color:Lerp(t.Wrap, 0.4)
			part.Reflectance = math.max(part.Reflectance, 0.2)
			if part.Material == Enum.Material.SmoothPlastic or part.Material == Enum.Material.Plastic then
				part.Material = t.WrapMaterial
			end
		end
	end
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.SpreadAngle = Vector2.new(180, 180)
	e.LockedToPart = false
	e.Name = STYLE
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = parent
	return e
end

local function aura(ball, t)
	-- emitters sit on the ball part itself so they emit from its SURFACE (an
	-- attachment emits from the centre, hidden inside the ball)
	local holder = ball
	local r = ball.Size.X / 2

	-- soft haze hugging the ball and lifting away
	emitter(holder, {
		Texture = SMOKE, Rate = 8, Lifetime = NumberRange.new(1.6, 2.4),
		Speed = NumberRange.new(0.3, 0.8), Acceleration = Vector3.new(0, 1.2, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20),
		Color = ColorSequence.new(t.Smog),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.9), NumberSequenceKeypoint.new(1, r * 2.1) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 0.4,
	})
	-- fine dust drifting upward and twinkling
	emitter(holder, {
		Texture = SPARKLE, Rate = 12, Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(0.4, 1.2), Acceleration = Vector3.new(0, 1.5, 0),
		Color = ColorSequence.new(t.Dust),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.38), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 1,
	})
	-- a few small glowing embers
	emitter(holder, {
		Rate = 6, Lifetime = NumberRange.new(0.9, 1.5),
		Speed = NumberRange.new(1, 2.2), Acceleration = Vector3.new(0, 2.5, 0),
		Color = ColorSequence.new(t.Ember, t.Dust),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.26), NumberSequenceKeypoint.new(1, 0) }),
		LightEmission = 1, LightInfluence = 0,
	})
	local glow = Instance.new("PointLight")
	glow.Name = STYLE
	glow.Color = t.Wrap
	glow.Brightness = 1.6
	glow.Range = r * 3.5
	glow.Shadows = false
	glow.Parent = holder
end

local function apply(ball, world)
	restore(ball)
	wrap(ball, world.Theme)
	aura(ball, world.Theme)
	ball:SetAttribute("StyledWorld", world.Id)
end

-- owners' worlds change rarely: a light poll keeps every ball right, and
-- re-wraps accessories added after the first pass (they are built late)
task.spawn(function()
	local balls = workspace:WaitForChild("PlayerBalls")
	while true do
		for _, ball in ipairs(balls:GetChildren()) do
			if ball:IsA("BasePart") then
				local userId = tonumber(string.match(ball.Name, "%d+$"))
				local owner = userId and Players:GetPlayerByUserId(userId)
				local world = owner and WorldConfig.Of(owner)
				local want = world and world.Theme and world.Id or nil
				local count = #ball:GetChildren()
				-- (re)apply when the world changed, accessories were added, or another
				-- script reset the ball's look (e.g. a ball swap)
				local reset = want and ball.Material ~= world.Theme.WrapMaterial
				if ball:GetAttribute("StyledWorld") ~= want or (want and ball:GetAttribute("StyledParts") ~= count) or reset then
					if want then
						apply(ball, world)
						ball:SetAttribute("StyledParts", #ball:GetChildren())
					else
						restore(ball)
					end
				end
			end
		end
		task.wait(0.5)
	end
end)