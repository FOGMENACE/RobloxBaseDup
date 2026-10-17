--------------------------------------------------
-- LEVEL-UP + XP ORB EFFECTS
--
-- CLIENT ONLY, visual. Driven by the server's Level / XPIntoLevel
-- attributes; nothing here changes progression.
--   * XP gain: oil-drop orbs "sprout" from random spots around the screen
--     and fly to the level badge (uses the uploaded oil image once
--     UiAssets.OilImages has an id, otherwise a drawn droplet).
--   * Level up: a big "LEVEL UP!" in the middle of the screen with the new
--     level, a spinning burst and a pop sound.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UiAssets = require(ReplicatedStorage:WaitForChild("UiAssets"))

local INK = Color3.fromRGB(24, 22, 34)
local FONT = Enum.Font.FredokaOne
local RNG = Random.new()
local LEVEL_SOUND = "rbxassetid://9125402735"

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local old = playerGui:FindFirstChild("LevelUpFX")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "LevelUpFX",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 35,
}, playerGui)

--------------------------------------------------
-- XP ORBS
--------------------------------------------------

local function makeOrb(parent)
	local image = UiAssets.OilImages.Black
	if image ~= "" then
		return create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(34, 34),
			ImageTransparency = 0.5,
		}, parent)
	end

	local drop = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 44, 70),
		BackgroundTransparency = 0.55,
		Size = UDim2.fromOffset(26, 26),
	}, parent)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, drop)
	create("UIStroke", { Color = Color3.fromRGB(120, 220, 255), Thickness = 2, Transparency = 0.6 }, drop)
	return drop
end

local lastOrbs = 0

local function spawnOrbs(count)
	if os.clock() - lastOrbs < 0.35 then
		return
	end
	lastOrbs = os.clock()

	local target = UDim2.new(0.5, -230, 1, -70) -- near the level badge

	for i = 1, math.clamp(count, 3, 12) do
		task.delay(i * 0.06, function()
			local orb = makeOrb(gui)
			orb.AnchorPoint = Vector2.new(0.5, 0.5)
			orb.Position = UDim2.fromScale(RNG:NextNumber(0.03, 0.97), RNG:NextNumber(0.05, 0.88))
			local final = orb.Size
			orb.Size = UDim2.fromOffset(0, 0)

			TweenService:Create(orb, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = final }):Play()
			task.wait(0.35)
			local fly = TweenService:Create(
				orb,
				TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = target, Size = UDim2.fromOffset(10, 10) }
			)
			fly:Play()
			fly.Completed:Wait()
			orb:Destroy()
		end)
	end
end

--------------------------------------------------
-- LEVEL UP
--------------------------------------------------

local function levelUp(level)
	local holder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(600, 220),
		BackgroundTransparency = 1,
	}, gui)
	local scale = create("UIScale", { Scale = 0 }, holder)

	-- spinning burst behind the text
	local burst = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(260, 260),
		BackgroundTransparency = 1,
	}, holder)
	for i = 1, 8 do
		local ray = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(18, 260),
			BackgroundColor3 = Color3.fromRGB(255, 232, 110),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Rotation = i * 22.5,
		}, burst)
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, ray)
	end

	local title = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, 90),
		Font = FONT,
		Text = "LEVEL UP!",
		TextColor3 = Color3.fromRGB(255, 232, 90),
		TextSize = 84,
	}, holder)
	create("UIStroke", { Color = INK, Thickness = 6 }, title)

	local number = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 118),
		Size = UDim2.new(1, 0, 0, 60),
		Font = FONT,
		Text = "LEVEL " .. tostring(level),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 50,
	}, holder)
	create("UIStroke", { Color = INK, Thickness = 5 }, number)

	local sound = create("Sound", { SoundId = LEVEL_SOUND, Volume = 0.6 }, SoundService)
	sound:Play()
	task.delay(5, function()
		sound:Destroy()
	end)

	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(burst, TweenInfo.new(2.6, Enum.EasingStyle.Linear), { Rotation = 140 }):Play()

	spawnOrbs(12)
	task.wait(0.2)
	lastOrbs = 0
	spawnOrbs(12)

	task.wait(2.1)
	local out = TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
	out:Play()
	out.Completed:Wait()
	holder:Destroy()
end

--------------------------------------------------
-- HOOKS
--------------------------------------------------

local previousLevel = player:GetAttribute("Level")
local previousInto = player:GetAttribute("XPIntoLevel")

player:GetAttributeChangedSignal("Level"):Connect(function()
	local level = player:GetAttribute("Level")
	if typeof(level) == "number" and typeof(previousLevel) == "number" and level > previousLevel then
		task.spawn(levelUp, level)
	end
	previousLevel = level
end)

player:GetAttributeChangedSignal("XPIntoLevel"):Connect(function()
	local into = player:GetAttribute("XPIntoLevel")
	if typeof(into) == "number" and typeof(previousInto) == "number" and into > previousInto then
		spawnOrbs(6)
	end
	previousInto = into
end)
