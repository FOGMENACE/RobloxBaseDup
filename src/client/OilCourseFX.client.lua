--------------------------------------------------
-- OIL COURSE FX
--
-- CLIENT ONLY, visual. Makes the oil course feel alive:
--   * oil gates breathe (gentle transparency pulse) until collected
--   * collecting a gate pops a burst of sparks at the ball: green for a
--     gain, red for a loss, gold for multipliers, blue for dividers
--   * speed streaks rush past the screen edges while rolling fast
-- The collection state comes from the gate's own attributes (set by the
-- server); nothing here changes gameplay.
--------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local course = workspace:WaitForChild("Course")
local playerBalls = workspace:WaitForChild("PlayerBalls")

local GREEN = Color3.fromRGB(88, 220, 120)
local RED = Color3.fromRGB(235, 70, 70)
local GOLD = Color3.fromRGB(255, 205, 70)
local BLUE = Color3.fromRGB(86, 168, 240)
local CREAM = Color3.fromRGB(255, 247, 232)

local function colorFor(gate)
	local kind = gate:GetAttribute("Kind")

	if kind == "Multiplier" then
		return GOLD
	elseif kind == "Divider" then
		return BLUE
	end

	return gate:GetAttribute("Positive") and GREEN or RED
end

--------------------------------------------------
-- GATE TRACKING
--------------------------------------------------

local tracked = {} -- [gate] = { Phase, Collected }

local function trackGate(gate)
	if tracked[gate] or not gate:IsA("BasePart") then
		return
	end

	tracked[gate] = {
		Phase = math.random() * math.pi * 2,
		Collected = gate:GetAttribute("Collected") == true,
		BaseTransparency = gate.Transparency,
	}
end

local function scanCourse()
	local playerCourse = course:FindFirstChild("PlayerCourse_" .. player.UserId)
	if not playerCourse then
		return
	end

	for _, descendant in ipairs(playerCourse:GetDescendants()) do
		if descendant.Name == "OilPlatformL" or descendant.Name == "OilPlatformR" then
			trackGate(descendant)
		end
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		scanCourse()
	end
end)

--------------------------------------------------
-- BURST
--------------------------------------------------

local function burst(position, color)
	for index = 1, 14 do
		local spark = Instance.new("Part")
		spark.Size = Vector3.new(0.5, 0.5, 0.5)
		spark.Shape = Enum.PartType.Ball
		spark.Material = Enum.Material.SmoothPlastic
		spark.Color = color
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanTouch = false
		spark.CanQuery = false
		spark.CastShadow = false
		spark.Position = position
		spark.Parent = workspace

		local angle = (index / 14) * math.pi * 2
		local radius = 5 + math.random() * 4
		local target = position + Vector3.new(
			math.cos(angle) * radius,
			3 + math.random() * 5,
			math.sin(angle) * radius
		)

		local tween = TweenService:Create(
			spark,
			TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = target, Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) }
		)
		tween:Play()
		Debris:AddItem(spark, 0.9)
	end
end

local function getOwnBall()
	return playerBalls:FindFirstChild("PlayerBall_" .. player.UserId)
end

--------------------------------------------------
-- SPEED STREAKS
--------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "OilCourseFX"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 3
gui.Parent = playerGui

local streakTimer = 0
local random = Random.new()

local function spawnStreak(speed)
	local fromLeft = random:NextInteger(0, 1) == 0
	local startX = fromLeft and random:NextNumber(0.0, 0.22) or random:NextNumber(0.78, 1.0)
	local length = random:NextInteger(60, 130) + math.floor(speed)

	local streak = Instance.new("Frame")
	streak.AnchorPoint = Vector2.new(0.5, 0.5)
	streak.Position = UDim2.fromScale(startX, random:NextNumber(0.05, 0.95))
	streak.Size = UDim2.fromOffset(2, length)
	streak.BackgroundColor3 = CREAM
	streak.BackgroundTransparency = 0.82
	streak.BorderSizePixel = 0
	streak.Rotation = fromLeft and -8 or 8
	streak.Parent = gui

	local tween = TweenService:Create(
		streak,
		TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = UDim2.fromScale(startX + (fromLeft and 0.05 or -0.05), streak.Position.Y.Scale + 0.3),
			BackgroundTransparency = 1,
		}
	)
	tween.Completed:Once(function()
		streak:Destroy()
	end)
	tween:Play()
end

--------------------------------------------------
-- LOOP
--------------------------------------------------

RunService.RenderStepped:Connect(function(deltaTime)
	local now = os.clock()

	-- Gates breathe; a newly collected gate pops.
	for gate, data in pairs(tracked) do
		if not gate.Parent then
			tracked[gate] = nil
		else
			local collected = gate:GetAttribute("Collected") == true

			if collected and not data.Collected then
				data.Collected = true

				-- Both gates of a row flip to "collected" together; only pop
				-- the half the ball actually rolled through.
				local ball = getOwnBall()
				if ball and math.abs(ball.Position.X - gate.Position.X) < 6.2 then
					burst(ball.Position, colorFor(gate))
				end
			end

			if not collected then
				gate.Transparency = math.clamp(
					data.BaseTransparency + math.sin(now * 3 + data.Phase) * 0.08,
					0,
					1
				)
			end
		end
	end

	-- Speed streaks while rolling fast in the oil course.
	local runState = player:GetAttribute("RunState")
	local ball = getOwnBall()

	if ball and (runState == "Running") then
		local speed = ball.AssemblyLinearVelocity.Magnitude
		if speed > 30 then
			streakTimer += deltaTime
			local interval = math.clamp(0.34 - speed / 500, 0.06, 0.34)

			if streakTimer >= interval then
				streakTimer = 0
				spawnStreak(speed)
			end
		end
	end
end)
