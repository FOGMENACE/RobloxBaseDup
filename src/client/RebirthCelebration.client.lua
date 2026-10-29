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

-- A smooth BANNER instead of a blocking card (auto rebirth would make a card
-- annoying): it slides down under the top bar, says "REBIRTH n", the new bonus
-- and the first unlock, then slides away. Nothing to tap, nothing blocked.
-- Repeated rebirths just update the same banner and restart its timer.
local banner = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -120),
	Size = UDim2.fromOffset(460, 78),
	BackgroundColor3 = Color3.fromRGB(46, 26, 104),
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, banner)
create("UIStroke", { Color = GOLD, Thickness = 3 }, banner)
create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(140, 84, 240), Color3.fromRGB(46, 26, 104)), Rotation = 90 }, banner)
local bannerScale = create("UIScale", {}, banner)
local function fitBanner()
	bannerScale.Scale = math.clamp(gui.AbsoluteSize.X / 600, 0.6, 1)
end
fitBanner()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBanner)

local title = create("TextLabel", {
	Position = UDim2.fromOffset(14, 6),
	Size = UDim2.new(1, -28, 0, 36),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "",
	TextColor3 = GOLD,
	TextSize = 30,
}, banner)
create("UIStroke", { Color = INK, Thickness = 2.5 }, title)
local detail = create("TextLabel", {
	Position = UDim2.fromOffset(14, 44),
	Size = UDim2.new(1, -28, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamMedium,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 15,
	TextTruncate = Enum.TextTruncate.AtEnd,
}, banner)

local SHOWN = UDim2.new(0.5, 0, 0, 64)
local HIDDEN = UDim2.new(0.5, 0, 0, -120)
local hideToken = 0


local function celebrate(rebirths)
	local auto = player:GetAttribute("AutoRebirth") == true
	title.Text = "♻ REBIRTH " .. rebirths .. "!"
	local bonus = string.format("Oil x%s • Wins x%s", tostring(RebirthBonuses.OilMultiplier(rebirths)), tostring(RebirthBonuses.WinsMultiplier(rebirths)))
	local unlocks = unlocksFor(rebirths)
	detail.Text = (#unlocks > 0) and (unlocks[1] .. "  •  " .. bonus) or bonus
	-- a newly unlocked ball shows up a moment later (asks the server)
	task.spawn(function()
		if #unlocks == 0 then
			local balls = ballUnlocksFor(rebirths)
			if balls[1] and title.Text == "♻ REBIRTH " .. rebirths .. "!" then
				detail.Text = balls[1] .. "  •  " .. bonus
			end
		end
	end)

	banner.Visible = true
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = SHOWN }):Play()
	-- (the multipliers panel pops by itself in HudUI; a second pulse here read its mid-pop size
	-- as "normal" and left it 15% too big, on phones even full desktop size)
	if not auto then
		local sound = create("Sound", { SoundId = "rbxasset://sounds/victory.wav", Volume = 0.45 }, SoundService)
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end

	hideToken += 1
	local token = hideToken
	task.delay(auto and 2.5 or 4, function()
		if token == hideToken then
			local out = TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = HIDDEN })
			out:Play()
			out.Completed:Once(function()
				if token == hideToken then
					banner.Visible = false
				end
			end)
		end
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
