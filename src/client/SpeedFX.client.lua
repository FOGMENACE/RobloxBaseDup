--------------------------------------------------
-- SPEED FX (oil course + win course)
--
-- CLIENT ONLY, visual. Replaces the old falling "sweat drop" streaks.
--   * Screen: thin speed lines rush OUTWARD from the middle of the screen,
--     like a dash/warp effect. How many lines, how long and how fast all
--     scale with the ball's real speed.
--   * World: two ribbons of dash trail stream from the sides of the ball
--     and a little wind puffs out behind it.
-- Nothing here touches physics or gameplay.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerBalls = workspace:WaitForChild("PlayerBalls")

local LINE_COUNT = 26
local MIN_SPEED = 28 -- below this nothing shows
local FULL_SPEED = 220 -- full intensity
local TINT = Color3.fromRGB(235, 244, 255)

local rng = Random.new()

local old = playerGui:FindFirstChild("SpeedFX")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "SpeedFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2
gui.Parent = playerGui

--------------------------------------------------
-- SCREEN LINES
--------------------------------------------------

local lines = {}

for index = 1, LINE_COUNT do
	local frame = Instance.new("Frame")
	frame.Name = "Line"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = TINT
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui

	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Rotation = 90
	fade.Parent = frame

	lines[index] = {
		Frame = frame,
		Angle = (index / LINE_COUNT) * math.pi * 2 + rng:NextNumber(-0.1, 0.1),
		Phase = rng:NextNumber(),
		Rate = rng:NextNumber(0.85, 1.25),
		Width = rng:NextInteger(2, 4),
	}
end

--------------------------------------------------
-- WORLD DASH (trails behind the ball)
--------------------------------------------------

local anchor = Instance.new("Part")
anchor.Name = "DashAnchor"
anchor.Anchored = true
anchor.CanCollide = false
anchor.CanTouch = false
anchor.CanQuery = false
anchor.CastShadow = false
anchor.Transparency = 1
anchor.Size = Vector3.new(0.2, 0.2, 0.2)
anchor.Parent = workspace

local TRAIL_COLOR = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(200, 228, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 190, 255)),
})

-- Thin, tapered air ribbons (like vapour off a fast object) instead of two
-- fat flat bars: four of them around the ball at different heights.
local function makeTrail(sideX, height, width, lifetime)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(sideX, height - width / 2, 0)
	a0.Parent = anchor

	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(sideX, height + width / 2, 0)
	a1.Parent = anchor

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = lifetime
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.75
	trail.Color = TRAIL_COLOR
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.35, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Enabled = false
	trail.Parent = anchor
	return trail
end

local trails = {
	makeTrail(-2.1, 0.2, 0.35, 0.26),
	makeTrail(2.1, 0.2, 0.35, 0.26),
	makeTrail(-1.3, 1.1, 0.25, 0.2),
	makeTrail(1.3, 1.1, 0.25, 0.2),
}
local wind = Instance.new("ParticleEmitter")
wind.Rate = 0
wind.Lifetime = NumberRange.new(0.22, 0.38)
wind.Speed = NumberRange.new(26, 44)
wind.SpreadAngle = Vector2.new(14, 14)
wind.Squash = NumberSequence.new(-0.85)
wind.EmissionDirection = Enum.NormalId.Front -- local -Z: behind the ball
wind.Orientation = Enum.ParticleOrientation.VelocityParallel
wind.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.9),
	NumberSequenceKeypoint.new(1, 0.05),
})
wind.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.5),
	NumberSequenceKeypoint.new(1, 1),
})
wind.Color = ColorSequence.new(TINT)
wind.LightEmission = 0.4
wind.Parent = anchor

--------------------------------------------------
-- LOOP
--------------------------------------------------

local function getOwnBall()
	return playerBalls:FindFirstChild("PlayerBall_" .. player.UserId)
end

-- WINCOURSE PULSE: the dash switches ON when a tile is hit and fades back OFF\n-- before the next one, so the speed effect follows the rhythm of the tiles.
local lastHit = 0
local lastInterval = 0.4

task.spawn(function()
	local winRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("WinCourse")
	winRemote.OnClientEvent:Connect(function(eventName)
		if eventName == "WinCourseTileCollected" then
			local now = os.clock()
			if lastHit > 0 then
				lastInterval = math.clamp(now - lastHit, 0.08, 0.7)
			end
			lastHit = now
			end
		end)
end)

local function winPulse()
	local age = os.clock() - lastHit
	local span = lastInterval * 0.85
	if age >= span then
		return 0
	end
	-- sharp flash that decays smoothly
	return (1 - age / span) ^ 1.5
end

local function racing()
	local state = player:GetAttribute("RunState")
	return state == "Running" or typeof(player:GetAttribute("WinTravelBudget")) == "number"
end

RunService.RenderStepped:Connect(function(deltaTime)
	local ball = getOwnBall()
	local speed = 0

	if ball and racing() then
		speed = ball.AssemblyLinearVelocity.Magnitude
	end

	local intensity = math.clamp((speed - MIN_SPEED) / (FULL_SPEED - MIN_SPEED), 0, 1)
	if ball and ball:GetAttribute("WinCourseActive") == true then
		intensity *= winPulse()
	end

	-- world dash
	if ball and intensity > 0 then
		anchor.CFrame = CFrame.new(ball.Position)
	end
	for _, trail in ipairs(trails) do
		trail.Enabled = intensity > 0.08
	end
	wind.Rate = intensity > 0.08 and (10 + intensity * 50) or 0

	-- screen lines
	local viewport = gui.AbsoluteSize
	local center = viewport / 2
	local maxRadius = math.sqrt(viewport.X ^ 2 + viewport.Y ^ 2) / 2
	local innerRadius = math.min(viewport.X, viewport.Y) * 0.27
	local active = math.floor(LINE_COUNT * math.clamp(intensity * 1.15, 0, 1) + 0.5)

	for index, line in ipairs(lines) do
		local frame = line.Frame

		if index > active then
			frame.Visible = false
		else
			line.Phase = (line.Phase + deltaTime * line.Rate * (0.9 + intensity * 2.1)) % 1
			local t = line.Phase

			-- rushes outward and accelerates as it goes
			local eased = t * t
			local radius = innerRadius + eased * (maxRadius - innerRadius)
			local length = (30 + intensity * 120) * (0.4 + t * 1.6)

			local dx, dy = math.cos(line.Angle), math.sin(line.Angle)
			frame.Position = UDim2.fromOffset(center.X + dx * radius, center.Y + dy * radius)
			frame.Size = UDim2.fromOffset(line.Width, length)
			frame.Rotation = math.deg(math.atan2(-dx, dy))
			frame.BackgroundTransparency = 0.2 + (1 - intensity) * 0.5
			frame.Visible = true
		end
	end
end)
