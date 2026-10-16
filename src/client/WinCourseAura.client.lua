--------------------------------------------------
-- WIN COURSE AURA
--
-- CLIENT ONLY
--
-- PURPOSE:
--
-- 1. Listen for the server's SpawnAura event.
-- 2. Create a temporary white aura around the
--    player's WinCourse ball.
-- 3. Keep the effect purely visual.
-- 4. Remove the effect automatically.
--
-- IMPORTANT:
--
-- This script NEVER:
--
-- * moves the ball
-- * changes ball velocity
-- * changes network ownership
-- * changes WinCourse physics
-- * controls the course
--
-- The SERVER remains the only system controlling
-- WinCourse physics.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Debris =
	game:GetService("Debris")


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local remotes =
	ReplicatedStorage:WaitForChild(
		"Remotes"
	)


local SpawnAura =
	remotes:WaitForChild(
		"SpawnAura"
	)


if not SpawnAura:IsA("RemoteEvent") then

	error(
		"[WinCourseAura] " ..
			"Remotes.SpawnAura must be a RemoteEvent."
	)

end


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local DEBUG = true

local DEFAULT_DURATION = 2

local AURA_NAME =
	"WinCourseWhiteAura"


--------------------------------------------------
-- DEBUG
--------------------------------------------------

local function debugPrint(...)

	if DEBUG then

		print(
			"[WinCourseAura]",
			...
		)

	end

end


--------------------------------------------------
-- REMOVE EXISTING AURA
--------------------------------------------------

local function removeExistingAura(ball)

	if not ball then
		return
	end


	local existing =
		ball:FindFirstChild(
			AURA_NAME
		)


	if existing then

		existing:Destroy()

	end

end


--------------------------------------------------
-- CREATE AURA
--------------------------------------------------

local function createAura(
	ball,
	duration
)

	if not ball
		or not ball:IsA("BasePart")
		or not ball.Parent then

		return

	end


	--------------------------------------------------
	-- REMOVE OLD EFFECT
	--------------------------------------------------

	removeExistingAura(ball)


	--------------------------------------------------
	-- AURA HOLDER
	--------------------------------------------------

	local aura =
		Instance.new("Attachment")


	aura.Name =
		AURA_NAME


	aura.Parent =
		ball


	--------------------------------------------------
	-- PARTICLE EMITTER
	--------------------------------------------------

	local particles =
		Instance.new("ParticleEmitter")


	particles.Name =
		"WhiteAuraParticles"


	particles.Parent =
		aura


	--------------------------------------------------
	-- APPEARANCE
	--------------------------------------------------

	particles.Color =
		ColorSequence.new(
			Color3.new(
				1,
				1,
				1
			)
		)


	particles.LightEmission =
		1


	particles.LightInfluence =
		0


	particles.Transparency =
		NumberSequence.new(
			{
				NumberSequenceKeypoint.new(
					0,
					0.15
				),

				NumberSequenceKeypoint.new(
					0.65,
					0.35
				),

				NumberSequenceKeypoint.new(
					1,
					1
				),
			}
		)


	--------------------------------------------------
	-- SIZE
	--------------------------------------------------

	particles.Size =
		NumberSequence.new(
			{
				NumberSequenceKeypoint.new(
					0,
					0.8
				),

				NumberSequenceKeypoint.new(
					0.5,
					1.2
				),

				NumberSequenceKeypoint.new(
					1,
					0
				),
			}
		)


	--------------------------------------------------
	-- MOTION
	--------------------------------------------------

	particles.Speed =
		NumberRange.new(
			0.2,
			0.8
		)


	particles.SpreadAngle =
		Vector2.new(
			360,
			360
		)


	particles.Drag =
		2


	--------------------------------------------------
	-- LIFETIME
	--------------------------------------------------

	particles.Lifetime =
		NumberRange.new(
			0.6,
			1.1
		)


	--------------------------------------------------
	-- EMISSION
	--------------------------------------------------

	particles.Rate =
		35


	particles.Enabled =
		true


	particles.Rotation =
		NumberRange.new(
			0,
			360
		)


	particles.RotSpeed =
		NumberRange.new(
			-90,
			90
		)


	--------------------------------------------------
	-- LIGHT
	--------------------------------------------------

	particles.Brightness =
		2


	--------------------------------------------------
	-- SHAPE
	--------------------------------------------------

	particles.Shape =
		Enum.ParticleEmitterShape.Sphere


	particles.ShapeStyle =
		Enum.ParticleEmitterShapeStyle.Volume


	particles.ShapeInOut =
		Enum.ParticleEmitterShapeInOut.Outward


	--------------------------------------------------
	-- INITIAL BURST
	--------------------------------------------------

	particles:Emit(
		20
	)


	--------------------------------------------------
	-- AUTOMATIC CLEANUP
	--------------------------------------------------

	local cleanupTime =
		tonumber(duration)
		or DEFAULT_DURATION


	Debris:AddItem(
		aura,
		cleanupTime
	)


	debugPrint(
		"AURA CREATED:",
		ball:GetFullName(),
		"| Duration:",
		cleanupTime
	)

end


--------------------------------------------------
-- SPAWN AURA EVENT
--------------------------------------------------

SpawnAura.OnClientEvent:Connect(
	function(data)

		--------------------------------------------------
		-- SERVER SENDS A TABLE
		--
		-- {
		--     Duration = 2,
		--     Ball = ball,
		--     Style = "WhiteBallAura"
		-- }
		--------------------------------------------------

		if type(data) ~= "table" then

			warn(
				"[WinCourseAura]",
				"Invalid SpawnAura data."
			)

			return

		end


		local ball =
			data.Ball


		local duration =
			data.Duration


		local style =
			data.Style


		--------------------------------------------------
		-- STYLE CHECK
		--------------------------------------------------

		if style
			and style ~= "WhiteBallAura" then

			warn(
				"[WinCourseAura]",
				"Unknown aura style:",
				tostring(style)
			)

			return

		end


		--------------------------------------------------
		-- BALL CHECK
		--------------------------------------------------

		if not ball
			or not ball:IsA("BasePart") then

			warn(
				"[WinCourseAura]",
				"SpawnAura received invalid ball."
			)

			return

		end


		if not ball.Parent then

			return

		end


		--------------------------------------------------
		-- CREATE
		--------------------------------------------------

		createAura(
			ball,
			duration
		)

	end
)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")

print(
	"[WinCourseAura]",
	"CLIENT READY"
)

print(
	"[WinCourseAura]",
	"REMOTE:",
	"Remotes.SpawnAura"
)

print(
	"[WinCourseAura]",
	"STYLE:",
	"WhiteBallAura"
)

print(
	"[WinCourseAura]",
	"DEFAULT DURATION:",
	DEFAULT_DURATION
)

print(
	"[WinCourseAura]",
	"PHYSICS CONTROL:",
	"NONE"
)

print(
	"[WinCourseAura]",
	"BALL MOVEMENT:",
	"NONE"
)

print("================================")

