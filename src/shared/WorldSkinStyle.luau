--------------------------------------------------
-- WORLD SKIN STYLE (shared, cosmetic only)
--
-- The evolved look of a ball in a themed world: the world's chrome-swirl
-- texture (or a metallic colour coat until it is uploaded), clean polish, a
-- heavy mist rolling off the ball, rising dust, a few embers and a soft glow.
-- The Oil Barrel keeps its ridges and OIL sign: its texture is swapped for the
-- world's barrel texture (same layout, pearly sign).
--   WorldSkinStyle.Apply(ball, theme, withParticles)
--   WorldSkinStyle.Restore(ball)
--   WorldSkinStyle.Reset(ball, template)
--------------------------------------------------

local WorldSkinStyle = {}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local BARREL_TEXTURE = "rbxassetid://105669825602431"
local TAG = "WorldStyle"

local saved = setmetatable({}, { __mode = "k" })

local function remember(part)
	if not saved[part] then
		saved[part] = {
			Color = part.Color, Reflectance = part.Reflectance, Material = part.Material,
			Texture = part:IsA("MeshPart") and part.TextureID or nil,
		}
	end
end

function WorldSkinStyle.Restore(ball)
	for _, child in ipairs(ball:GetChildren()) do
		if child.Name == TAG then
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
end

-- The ball became a different ball (an upgrade / downgrade platform swaps it in place):
-- what was remembered belongs to the old ball and must never be painted back on the new
-- one. Forgets it, drops the old coat and takes the look of the new ball's own model.
function WorldSkinStyle.Reset(ball, template)
	for _, child in ipairs(ball:GetChildren()) do
		if child.Name == TAG then
			child:Destroy()
		end
	end
	for part in pairs(saved) do
		if part == ball or part:IsDescendantOf(ball) then
			saved[part] = nil
		end
	end
	if template and template:IsA("BasePart") then
		ball.Color, ball.Reflectance, ball.Material = template.Color, template.Reflectance, template.Material
		if ball:IsA("MeshPart") and template:IsA("MeshPart") then
			ball.TextureID = template.TextureID
		end
	end
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = TAG
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.SpreadAngle = Vector2.new(180, 180)
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = parent
	return e
end

local function coat(ball, t)
	remember(ball)
	if ball:IsA("MeshPart") and t.BallTexture ~= "" then
		ball.TextureID = t.BallTexture
		ball.Color = Color3.new(1, 1, 1)
	else
		if ball:IsA("MeshPart") then
			ball.TextureID = ""
		end
		ball.Color = t.Wrap:Lerp(ball.Color, 0.1)
	end
	ball.Material = t.WrapMaterial
	ball.Reflectance = 0.45 + t.Shine * 0.3

	for _, part in ipairs(ball:GetDescendants()) do
		if part:IsA("MeshPart") and part.TextureID == BARREL_TEXTURE then
			remember(part)
			if t.BarrelTexture ~= "" then
				part.TextureID = t.BarrelTexture
			end
			part.Reflectance = math.max(part.Reflectance, 0.25)
		elseif part:IsA("BasePart") and part.Transparency < 0.95 and not part.Name:find("^Acc_Dragon")
			and (part.Material == Enum.Material.SmoothPlastic or part.Material == Enum.Material.Plastic or part.Material == Enum.Material.Metal) then
			remember(part)
			part.Color = part.Color:Lerp(t.Wrap, 0.4)
			part.Reflectance = math.max(part.Reflectance, 0.22)
			-- parts drawn with a SpecialMesh render as a red/green checker in Metal:
			-- they keep their material and only take the colour and shine
			if (part.Material == Enum.Material.SmoothPlastic or part.Material == Enum.Material.Plastic)
				and not part:FindFirstChildOfClass("SpecialMesh") then
				part.Material = t.WrapMaterial
			end
		end
	end
end

local function aura(ball, t)
	local r = math.max(ball.Size.X, ball.Size.Y, ball.Size.Z) / 2
	-- heavy mist rolling off the ball and sinking to the floor
	emitter(ball, {
		Texture = SMOKE, Rate = 16, Lifetime = NumberRange.new(1.6, 2.6),
		Speed = NumberRange.new(0.4, 1.2), Acceleration = Vector3.new(0, -1.4, 0), Drag = 1.5,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-18, 18),
		Color = ColorSequence.new(t.Smog, t.Wrap),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.7), NumberSequenceKeypoint.new(1, r * 2.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 0.3,
	})
	-- lighter vapour lifting off the top
	emitter(ball, {
		Texture = SMOKE, Rate = 7, Lifetime = NumberRange.new(1.4, 2.2),
		Speed = NumberRange.new(0.6, 1.4), Acceleration = Vector3.new(0, 1.6, 0),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-25, 25),
		Color = ColorSequence.new(t.Smog),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, r * 0.6), NumberSequenceKeypoint.new(1, r * 1.8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.65), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 0.5,
	})
	-- glittering dust
	emitter(ball, {
		Texture = SPARKLE, Rate = 16, Lifetime = NumberRange.new(1, 1.8),
		Speed = NumberRange.new(0.4, 1.4), Acceleration = Vector3.new(0, 1.4, 0),
		Color = ColorSequence.new(t.Dust),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(0.5, 0.48), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 1,
	})
	-- embers
	emitter(ball, {
		Rate = 7, Lifetime = NumberRange.new(0.9, 1.6),
		Speed = NumberRange.new(1, 2.4), Acceleration = Vector3.new(0, 2.5, 0),
		Color = ColorSequence.new(t.Ember, t.Dust),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.24), NumberSequenceKeypoint.new(1, 0) }),
		LightEmission = 1, LightInfluence = 0,
	})
	local glow = Instance.new("PointLight")
	glow.Name = TAG
	glow.Color = t.Wrap
	glow.Brightness = 1.4
	glow.Range = r * 3.5
	glow.Shadows = false
	glow.Parent = ball
end

function WorldSkinStyle.Apply(ball, theme, withParticles)
	WorldSkinStyle.Restore(ball)
	coat(ball, theme)
	if withParticles ~= false then
		aura(ball, theme)
	end
end

return WorldSkinStyle