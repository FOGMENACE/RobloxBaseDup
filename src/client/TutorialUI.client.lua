--------------------------------------------------
-- TUTORIAL UI
--
-- CLIENT ONLY. Shows a banner and an arrow that points from the
-- player's ball toward the current objective. The step itself comes
-- from the server attribute "TutorialStep" (see TutorialService); this
-- script never advances anything.
--
-- Steps (7 = done, nothing is shown):
--   1 START wall    2 FINISH wall    3 shop pad (buy Aftershock)
--   4 X1 generator  5 Rebirth (hub)  6 Daily calendar (hub)
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local LANE = Color3.fromRGB(240, 178, 82)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local FONT = Enum.Font.FredokaOne

local DONE = 7
local TUTORIAL_BALL = "Aftershock"

local old = playerGui:FindFirstChild("TutorialUI")
if old then
	old:Destroy()
end

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local gui = create("ScreenGui", {
	Name = "TutorialUI",
	ResetOnSpawn = false,
	IgnoreGuiInset = true, -- matches WorldToViewportPoint coordinates
	DisplayOrder = 9,
}, playerGui)

--------------------------------------------------
-- BANNER
--------------------------------------------------

local banner = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 84),
	Size = UDim2.fromOffset(520, 44),
	BackgroundColor3 = LANE,
	Font = FONT,
	Text = "",
	TextColor3 = INK,
	TextSize = 14,
	TextWrapped = true,
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 14) }, banner)
create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, banner)
local bannerScale = create("UIScale", { Scale = 1 }, banner)

local function fitBanner()
	local viewport = gui.AbsoluteSize
	bannerScale.Scale = math.clamp(viewport.X / 740, 0.6, 1.1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBanner)
fitBanner()

--------------------------------------------------
-- ARROW (screen space, orbits the ball toward the target)
--------------------------------------------------

local arrow = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(40, 40),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = ">",
	TextColor3 = PIN_RED,
	TextSize = 38,
	Visible = false,
}, gui)
create("UIStroke", { Color = INK, Thickness = 2 }, arrow)

local distanceLabel = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(90, 22),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 16,
	Visible = false,
}, gui)
create("UIStroke", { Color = INK, Thickness = 2 }, distanceLabel)

--------------------------------------------------
-- TARGETS
--------------------------------------------------

local function findTarget(step)
	if step == 1 then
		return workspace:FindFirstChild("StartWall")
	elseif step == 2 then
		-- Only during the oil course. Once the finish wall is hit (RunState
		-- Finishing) and the WinCourse runs, there is nothing to point at.
		if player:GetAttribute("RunState") ~= "Running" then
			return nil
		end
		return workspace:FindFirstChild("FinishWall")
	elseif step == 3 then
		local shop = workspace:FindFirstChild("BowlingShop")
		return shop and shop:FindFirstChild("BallShopInteractionPoint")
	elseif step == 4 then
		local generators = workspace:FindFirstChild("XPGenerators")
		return generators and generators:FindFirstChild("GenX1")
	end

	return nil
end

local function positionOf(target)
	if target:IsA("BasePart") then
		return target.Position
	elseif target:IsA("Model") then
		return target:GetPivot().Position
	end
	return nil
end

local function getOwnBall()
	local balls = workspace:FindFirstChild("PlayerBalls")
	return balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
end

--------------------------------------------------
-- TEXT
--------------------------------------------------

local aftershockCost = nil

local function fetchAftershockCost()
	if aftershockCost then
		return
	end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local state = remotes and remotes:FindFirstChild("BallShopState")
	if not state then
		return
	end

	local ok, result = pcall(function()
		return state:InvokeServer()
	end)

	if ok and typeof(result) == "table" and typeof(result.Balls) == "table" then
		for _, ball in ipairs(result.Balls) do
			if ball.BallId == TUTORIAL_BALL then
				aftershockCost = ball.WinsCost
			end
		end
	end
end

local function textFor(step)
	if step == 1 then
		return "Roll onto the START wall to begin your first course!"
	elseif step == 2 then
		if player:GetAttribute("RunState") == "Running" then
			return "Collect oil, avoid the gutters, then roll into the FINISH wall!"
		end
		return "Nice! Your WinCourse is next. Roll through the tiles to collect Wins!"
	elseif step == 3 then
		local cost = aftershockCost
		local wins = player:GetAttribute("Wins") or 0
		if cost and wins < cost then
			return "Win " .. cost .. " Wins, then roll onto the SHOP pad to buy AFTERSHOCK!"
		end
		return "Roll onto the SHOP pad and buy AFTERSHOCK!"
	elseif step == 4 then
		return "Roll onto the X1 generator to start earning XP!"
	elseif step == 5 then
		return "Keep earning XP. When you hit the level, press REBIRTH in the hub!"
	elseif step == 6 then
		return "Open the DAILY calendar on the left and claim your gift!"
	end

	return ""
end

--------------------------------------------------
-- UPDATE
--------------------------------------------------

local shownStep = nil

local function updateBanner(step)
	if step == shownStep then
		return
	end
	shownStep = step

	if step == nil or step >= DONE or step < 1 then
		banner.Visible = false
		return
	end

	if step == 3 then
		task.spawn(fetchAftershockCost)
	end

	banner.Text = textFor(step)
	banner.Visible = (player:GetAttribute("RunState") or "Waiting") == "Waiting"
	fitBanner()
	local finalScale = bannerScale.Scale
	bannerScale.Scale = finalScale * 0.85
	TweenService:Create(
		bannerScale,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = finalScale }
	):Play()
end

RunService.RenderStepped:Connect(function()
	local step = player:GetAttribute("TutorialStep")
	updateBanner(step)

	-- Step 3's text depends on Wins, so keep it fresh.
	if (step == 2 or step == 3) and banner.Visible then
		banner.Text = textFor(step)
	end

	local target = typeof(step) == "number" and findTarget(step) or nil
	local ball = getOwnBall()

	if not target or not ball then
		arrow.Visible = false
		distanceLabel.Visible = false
		return
	end

	local targetPosition = positionOf(target)
	if not targetPosition then
		arrow.Visible = false
		distanceLabel.Visible = false
		return
	end

	local ballScreen, ballOnScreen = camera:WorldToViewportPoint(ball.Position)
	local targetScreen, targetInFront = camera:WorldToViewportPoint(targetPosition)

	local origin = Vector2.new(ballScreen.X, ballScreen.Y)
	local direction = Vector2.new(targetScreen.X, targetScreen.Y) - origin

	-- Target behind the camera: the projected direction is mirrored.
	if targetScreen.Z < 0 then
		direction = -direction
	end

	if direction.Magnitude < 1 then
		direction = Vector2.new(0, -1)
	end

	direction = direction.Unit

	local orbit = 90
	local bob = math.sin(os.clock() * 5) * 6

	arrow.Position = UDim2.fromOffset(
		origin.X + direction.X * (orbit + bob),
		origin.Y + direction.Y * (orbit + bob)
	)
	arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X))
	arrow.Visible = ballOnScreen

	local distance = (targetPosition - ball.Position).Magnitude
	distanceLabel.Position = UDim2.fromOffset(
		origin.X + direction.X * (orbit + 40),
		origin.Y + direction.Y * (orbit + 40)
	)
	distanceLabel.Text = math.floor(distance) .. " studs"
	distanceLabel.Visible = ballOnScreen
end)

-- Keep the banner out of the way while rolling (only shown in the lobby).
player:GetAttributeChangedSignal("RunState"):Connect(function()
	if shownStep ~= nil and shownStep < DONE and shownStep >= 1 then
		banner.Visible = (player:GetAttribute("RunState") or "Waiting") == "Waiting"
	end
end)
