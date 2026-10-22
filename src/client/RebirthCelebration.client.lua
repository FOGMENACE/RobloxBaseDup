--------------------------------------------------
-- REBIRTH CELEBRATION (CLIENT, display only)
--
-- Every time the server raises the player's Rebirths attribute, a big card
-- tells them exactly what happened: "REBIRTH 2!", the new oil / wins / XP
-- bonuses, and what just unlocked (XP generators, balls, worlds). It points
-- at the rebirth badge in the bottom-left where the count always lives.
-- Nothing here grants anything; it only reads server-published values.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local RebirthBonuses = require(ReplicatedStorage:WaitForChild("RebirthBonuses"))
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local FONT = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(255, 214, 90)
local CREAM = Color3.fromRGB(255, 247, 232)
local INK = Color3.fromRGB(24, 22, 34)

-- Rookie Lanes generators and the rebirth they need (display copy of the
-- server rule in BallPhysicsController)
local LOBBY_GENERATORS = { [2] = "X2", [4] = "X4", [8] = "X8", [10] = "X10" }

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local gui = create("ScreenGui", {
	Name = "RebirthCelebration",
	ResetOnSpawn = false,
	DisplayOrder = 60,
	IgnoreGuiInset = true,
}, playerGui)

local function unlocksFor(rebirths)
	local list = {}
	if LOBBY_GENERATORS[rebirths] then
		table.insert(list, "⚡ " .. LOBBY_GENERATORS[rebirths] .. " XP generator (Rookie Lanes)")
	end
	for _, world in ipairs(WorldConfig.Worlds) do
		if world.Id > 1 and world.Rebirths == rebirths then
			table.insert(list, "🌍 New world: " .. world.Name)
		end
		for name, value in pairs(world.Generators or {}) do
			if value == rebirths and name ~= "GenX6" and world.Id > 1 then
				table.insert(list, "⚡ X" .. value .. " XP generator (" .. world.Name .. ")")
			end
		end
	end
	return list
end

-- balls whose rebirth requirement is exactly this rebirth (asks the server, so it can take a moment)
local function ballUnlocksFor(rebirths)
	local list = {}
	local ok, state = pcall(function()
		return remotes:WaitForChild("BallShopState"):InvokeServer()
	end)
	if ok and typeof(state) == "table" and typeof(state.Balls) == "table" then
		for _, ball in ipairs(state.Balls) do
			if ball.RequiredRebirths == rebirths then
				table.insert(list, "🎳 New ball in the shop: " .. tostring(ball.DisplayName or ball.BallId))
			end
		end
	end
	return list
end

local showing = nil

local function celebrate(rebirths)
	if showing then
		showing:Destroy()
	end

	local dim = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(10, 6, 30),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, gui)
	showing = dim
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = 0.45 }):Play()

	local card = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(520, 330),
		BackgroundColor3 = Color3.fromRGB(46, 26, 104),
	}, dim)
	create("UICorner", { CornerRadius = UDim.new(0, 24) }, card)
	create("UIStroke", { Color = GOLD, Thickness = 4 }, card)
	create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(150, 90, 255), Color3.fromRGB(40, 22, 96)), Rotation = 90 }, card)
	local scale = create("UIScale", { Scale = 0.3 }, card)
	local fitScale = math.clamp(math.min(gui.AbsoluteSize.X / 580, gui.AbsoluteSize.Y / 420), 0.5, 1.15)
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = fitScale }):Play()

	create("TextLabel", {
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "♻ YOU REBIRTHED!",
		TextColor3 = CREAM,
		TextSize = 24,
	}, card)
	local big = create("TextLabel", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "REBIRTH " .. rebirths,
		TextColor3 = GOLD,
		TextSize = 62,
	}, card)
	create("UIStroke", { Color = INK, Thickness = 4 }, big)

	-- the new bonuses, in the same units as the HUD
	local bonus = string.format("OIL x%s   •   WINS x%s   •   XP +%dx",
		tostring(RebirthBonuses.OilMultiplier(rebirths)),
		tostring(RebirthBonuses.WinsMultiplier(rebirths)),
		math.floor(RebirthBonuses.XPMultiplier(rebirths) - 1))
	create("TextLabel", {
		Position = UDim2.fromOffset(16, 122),
		Size = UDim2.new(1, -32, 0, 26),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = bonus,
		TextColor3 = Color3.fromRGB(150, 255, 170),
		TextSize = 20,
	}, card)

	local unlockBox = create("Frame", {
		Position = UDim2.fromOffset(24, 156),
		Size = UDim2.new(1, -48, 0, 112),
		BackgroundColor3 = Color3.fromRGB(24, 14, 60),
		BackgroundTransparency = 0.2,
	}, card)
	create("UICorner", { CornerRadius = UDim.new(0, 14) }, unlockBox)
	create("UIListLayout", { Padding = UDim.new(0, 2), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }, unlockBox)
	local unlockLines = { create("TextLabel", {
		Size = UDim2.new(1, -16, 0, 24),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "UNLOCKED:",
		TextColor3 = GOLD,
		TextSize = 18,
	}, unlockBox) }
	local shown = 0
	local function addLine(text)
		if shown >= 3 then
			return
		end
		shown += 1
		table.insert(unlockLines, create("TextLabel", {
			Size = UDim2.new(1, -16, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = text,
			TextColor3 = CREAM,
			TextSize = 16,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, unlockBox))
	end
	-- generators and worlds are known right away; the ball list follows
	for _, text in ipairs(unlocksFor(rebirths)) do
		addLine(text)
	end
	local filler = nil
	if shown == 0 then
		filler = create("TextLabel", {
			Size = UDim2.new(1, -16, 0, 24),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = "Bigger oil and wins on every run. Keep going!",
			TextColor3 = CREAM,
			TextSize = 16,
		}, unlockBox)
	end
	task.spawn(function()
		local balls = ballUnlocksFor(rebirths)
		if #balls > 0 and filler then
			filler:Destroy()
		end
		for _, text in ipairs(balls) do
			if unlockBox.Parent then
				addLine(text)
			end
		end
	end)

	create("TextLabel", {
		Position = UDim2.new(0, 0, 1, -54),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "Your rebirth level is always in the bottom-left badge ↙",
		TextColor3 = Color3.fromRGB(220, 214, 255),
		TextSize = 15,
	}, card)
	create("TextLabel", {
		Position = UDim2.new(0, 0, 1, -30),
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Text = "tap anywhere to continue",
		TextColor3 = Color3.fromRGB(170, 160, 210),
		TextSize = 13,
	}, card)

	local sound = create("Sound", { SoundId = "rbxasset://sounds/victory.wav", Volume = 0.6 }, SoundService)
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)

	-- flash the bottom-left rebirth badge so the eye knows where to look
	local hud = playerGui:FindFirstChild("HudUI")
	local badge = hud and hud:FindFirstChild("RebirthPanel", true)
	local badgeScale = badge and badge:FindFirstChildOfClass("UIScale")

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
		if badgeScale then
			local base = badgeScale.Scale
			for _ = 1, 3 do
				TweenService:Create(badgeScale, TweenInfo.new(0.18), { Scale = base * 1.15 }):Play()
				task.wait(0.2)
				TweenService:Create(badgeScale, TweenInfo.new(0.18), { Scale = base }):Play()
				task.wait(0.2)
			end
		end
		task.delay(0.3, function()
			dim:Destroy()
			if showing == dim then
				showing = nil
			end
		end)
	end
	dim.Activated:Connect(function()
		task.spawn(close)
	end)
	-- auto rebirth repeats quickly: shorter on screen when it is on
	task.delay(player:GetAttribute("AutoRebirth") == true and 5 or 9, function()
		task.spawn(close)
	end)
end

local last = player:GetAttribute("Rebirths")
player:GetAttributeChangedSignal("Rebirths"):Connect(function()
	local now = player:GetAttribute("Rebirths")
	-- the first value is the saved one at join: only celebrate a real increase
	if typeof(last) == "number" and typeof(now) == "number" and now > last then
		celebrate(now)
	end
	last = now
end)
