--------------------------------------------------
-- HUD UI
--
-- CLIENT ONLY. Replaces the old top-right Wins/Oil/Level panel
-- (StarterGui.MainUI) and the bottom-right ProgressionUI.
--
-- Bottom-center : global "Strike" level badge, rebirth-cycle LEVEL
--                 with its XP bar, and this run's OIL.
-- Bottom-left   : rebirth progress with the oil image and the current
--                 XP multiplier (it grows with every rebirth).
-- Effects       : floating "+XP" that flies into the bar, and a bright
--                 LEVEL UP burst with a sound.
--
-- Every number comes from server-owned player attributes
-- (Level, GlobalLevel, XPIntoLevel, XPNeededForLevel, LevelProgress,
-- Rebirths, RebirthLevelRequirement, CurrentOil). Wins live in the
-- left hub (HubUI). Nothing is calculated here.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UiAssets = require(ReplicatedStorage:WaitForChild("UiAssets"))
local Shine = require(ReplicatedStorage:WaitForChild("Shine"))
local RebirthBonuses = require(ReplicatedStorage:WaitForChild("RebirthBonuses"))

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local LANE = Color3.fromRGB(240, 178, 82)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local GREEN = Color3.fromRGB(88, 196, 110)
local OIL_DARK = Color3.fromRGB(38, 34, 52)
local FONT = Enum.Font.FredokaOne

-- Rebirth XP multiplier shown to the player. Mirrors the server rule in
-- BallPhysicsController (1 + 10 per rebirth); display only.

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function round(inst, radius)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, inst)
end

local function outline(inst, thickness, color)
	create("UIStroke", { Color = color or INK, Thickness = thickness }, inst)
end

local function formatNumber(value)
	value = math.floor(tonumber(value) or 0)
	if value >= 1e12 then
		return string.format("%.1fT", value / 1e12)
	elseif value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e3 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(value)
end

local function bump(scaleObject, amount)
	scaleObject.Scale = amount
	TweenService:Create(
		scaleObject,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

-- The oil image (once uploaded) or a drawn droplet.
local function addOilIcon(parent, size)
	local id = UiAssets.OilImages.Black
	if id ~= "" then
		return create("ImageLabel", {
			BackgroundTransparency = 1,
			Size = size,
			Image = id,
			ScaleType = Enum.ScaleType.Fit,
		}, parent)
	end

	local drop = create("Frame", {
		BackgroundColor3 = OIL_DARK,
		Size = size,
	}, parent)
	round(drop, 100)
	outline(drop, 2)
	local shine = create("Frame", {
		BackgroundColor3 = CREAM,
		BackgroundTransparency = 0.2,
		Position = UDim2.fromScale(0.2, 0.18),
		Size = UDim2.fromScale(0.22, 0.16),
	}, drop)
	round(shine, 100)
	return drop
end

--------------------------------------------------
-- ROOT
--------------------------------------------------

local old = playerGui:FindFirstChild("HudUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "HudUI",
	ResetOnSpawn = false,
	DisplayOrder = 4,
	IgnoreGuiInset = false,
}, playerGui)

--------------------------------------------------
-- BOTTOM-CENTER HUD
--------------------------------------------------

local hud = create("Frame", {
	Name = "Hud",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(540, 148),
	BackgroundTransparency = 1,
}, gui)
local hudScale = create("UIScale", { Scale = 1 }, hud)

-- Global (Strike) level badge
local badge = create("Frame", {
	Name = "GlobalBadge",
	Position = UDim2.fromOffset(0, 4),
	Size = UDim2.fromOffset(88, 88),
	BackgroundColor3 = PIN_RED,
}, hud)
round(badge, 44)
outline(badge, 4)
local badgeScale = create("UIScale", { Scale = 1 }, badge)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 8),
	Size = UDim2.new(1, 0, 0, 16),
	Font = FONT,
	Text = "STRIKE",
	TextColor3 = CREAM,
	TextSize = 11,
}, badge)

local globalLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 22),
	Size = UDim2.new(1, 0, 0, 40),
	Font = FONT,
	Text = "1",
	TextColor3 = CREAM,
	TextSize = 34,
}, badge)
create("UIStroke", { Color = INK, Thickness = 2 }, globalLabel)

create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 62),
	Size = UDim2.new(1, 0, 0, 16),
	Font = FONT,
	Text = "LEVEL",
	TextColor3 = CREAM,
	TextSize = 11,
}, badge)

-- Rebirth-cycle level + XP bar
local levelPanel = create("Frame", {
	Name = "LevelPanel",
	Position = UDim2.fromOffset(98, 14),
	Size = UDim2.fromOffset(300, 70),
	BackgroundColor3 = CREAM,
}, hud)
round(levelPanel, 14)
outline(levelPanel, 4)
local levelScale = create("UIScale", { Scale = 1 }, levelPanel)

local levelLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 4),
	Size = UDim2.new(1, -24, 0, 26),
	Font = FONT,
	Text = "LEVEL 1",
	TextColor3 = INK,
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
}, levelPanel)

local barTrack = create("Frame", {
	Position = UDim2.fromOffset(12, 36),
	Size = UDim2.new(1, -24, 0, 24),
	BackgroundColor3 = Color3.fromRGB(70, 66, 90),
}, levelPanel)
round(barTrack, 12)
outline(barTrack, 2)

local barFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = GREEN,
}, barTrack)
round(barFill, 12)

local barLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 14,
	ZIndex = 3,
}, barTrack)
create("UIStroke", { Color = INK, Thickness = 2 }, barLabel)

-- Run oil chip
local oilChip = create("Frame", {
	Name = "OilChip",
	Position = UDim2.fromOffset(410, 24),
	Size = UDim2.fromOffset(130, 50),
	BackgroundColor3 = CREAM,
}, hud)
round(oilChip, 14)
outline(oilChip, 4)
local oilScale = create("UIScale", { Scale = 1 }, oilChip)

local oilIconHolder = create("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(8, 7),
	Size = UDim2.fromOffset(34, 34),
}, oilChip)
addOilIcon(oilIconHolder, UDim2.fromScale(1, 1))

local oilLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(46, 0),
	Size = UDim2.new(1, -52, 1, 0),
	Font = FONT,
	Text = "0",
	TextColor3 = INK,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
}, oilChip)

--------------------------------------------------
-- XP KITS (developer products), under the level display
--
-- Three buttons whose XP grows with the player's level (shared/XPKits is
-- the formula; the server recomputes it from real data and sells exactly
-- what the prompt quoted). A glare sweeps over them every 5 seconds and a
-- "!" badge pops in and out on one of them every so often.
--------------------------------------------------

local XPKits = require(ReplicatedStorage:WaitForChild("XPKits"))

local kitRow = create("Frame", {
	Name = "KitRow",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 102),
	Size = UDim2.fromOffset(540, 42),
}, hud)

local KIT_STYLES = {
	{ Top = Color3.fromRGB(70, 170, 255), Bottom = Color3.fromRGB(30, 90, 200) },
	{ Top = Color3.fromRGB(255, 170, 40), Bottom = Color3.fromRGB(220, 60, 40) },
	{ Top = Color3.fromRGB(255, 70, 200), Bottom = Color3.fromRGB(60, 220, 255) },
}

local kitButtons = {}

for index = 1, 3 do
	local style = KIT_STYLES[index]

	local button = create("TextButton", {
		Name = "Kit" .. index,
		Position = UDim2.fromOffset((index - 1) * 182, 0),
		Size = UDim2.fromOffset(176, 42),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "",
		AutoButtonColor = false,
	}, kitRow)
	round(button, 12)
	outline(button, 3)

	local gradient = create("UIGradient", {
		Color = ColorSequence.new(style.Top, style.Bottom),
		Rotation = 90,
	}, button)

	local scale = create("UIScale", { Scale = 1 }, button)

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = "+0 XP",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 21,
	}, button)
	create("UIStroke", { Color = INK, Thickness = 2.5 }, label)

	-- "!" notification badge that pops in and out
	local badge = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 6, 0, -8),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = PIN_RED,
		Font = FONT,
		Text = "!",
		TextColor3 = CREAM,
		TextSize = 15,
		Visible = false,
		ZIndex = 10,
	}, button)
	round(badge, 11)
	outline(badge, 2)
	local badgeScale = create("UIScale", { Scale = 0 }, badge)

	Shine.Attach(button, { Offset = index * 1.1 })

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)

	button.Activated:Connect(function()
		bump(scale, 0.94)
		local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("XPKitPrompt")
		remote:FireServer(index)
	end)

	kitButtons[index] = { Label = label, Gradient = gradient, Badge = badge, BadgeScale = badgeScale }
end

local function refreshKits()
	local needed = player:GetAttribute("XPNeededForLevel")
	local rebirths = player:GetAttribute("Rebirths") or 0

	for index, kit in ipairs(kitButtons) do
		local amount = XPKits.Amount(index, needed, rebirths)
		local text = "+" .. formatNumber(amount) .. " XP"

		if kit.Label.Text ~= text then
			kit.Label.Text = text
			-- A bigger kit after a level-up gets a little pulse.
			if kit.Label.Text ~= "+0 XP" then
				bump(kit.BadgeScale, 1)
			end
		end
	end
end

player:GetAttributeChangedSignal("XPNeededForLevel"):Connect(refreshKits)
player:GetAttributeChangedSignal("Rebirths"):Connect(refreshKits)
refreshKits()

-- The rainbow kit's gradient slowly rotates; a random kit pops its "!".
task.spawn(function()
	local rng = Random.new()
	local nextPop = os.clock() + 4

	while true do
		task.wait(0.05)
		kitButtons[3].Gradient.Rotation = (os.clock() * 40) % 360

		if os.clock() >= nextPop then
			nextPop = os.clock() + rng:NextNumber(8, 14)

			local kit = kitButtons[rng:NextInteger(1, 3)]
			kit.Badge.Visible = true
			kit.BadgeScale.Scale = 0
			TweenService:Create(
				kit.BadgeScale,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()

			task.delay(2.4, function()
				local out = TweenService:Create(
					kit.BadgeScale,
					TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In),
					{ Scale = 0 }
				)
				out.Completed:Once(function()
					kit.Badge.Visible = false
				end)
				out:Play()
			end)
		end
	end
end)

--------------------------------------------------
-- XP BONUS PILL (small, above the oil counter)
--
-- Top line: rebirth XP bonus. Bottom line: the Game Pass multiplier,
-- 0% until a pass is owned. Display only; the server applies the real
-- multipliers (RebirthBonuses / GamePassService).
--------------------------------------------------

local bonusPill = create("Frame", {
	Name = "XPBonusPill",
	Position = UDim2.fromOffset(366, -44),
	Size = UDim2.fromOffset(174, 40),
	BackgroundColor3 = CREAM,
}, hud)
round(bonusPill, 10)
outline(bonusPill, 3)
local bonusScale = create("UIScale", { Scale = 1 }, bonusPill)

local function bonusLine(y, color)
	local line = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, y),
		Size = UDim2.new(1, -16, 0, 17),
		Font = FONT,
		Text = "",
		TextColor3 = color,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, bonusPill)
	return line
end

local rebirthBonusLine = bonusLine(2, Color3.fromRGB(110, 70, 160))
local passBonusLine = bonusLine(20, Color3.fromRGB(30, 130, 70))

local function percentText(value)
	value = math.floor(value + 0.5)
	local text = tostring(value)
	-- thousands separators
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return "+" .. formatted .. "%"
end

local function refreshBonusPill()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local rebirthPercent = (RebirthBonuses.XPMultiplier(rebirths) - 1) * 100
	local passMultiplier = player:GetAttribute("PassXPMultiplier") or 1
	local passPercent = math.max(passMultiplier - 1, 0) * 100

	rebirthBonusLine.Text = "REBIRTH XP " .. percentText(rebirthPercent)
	passBonusLine.Text = "PASS XP " .. percentText(passPercent)
	bump(bonusScale, 1.08)
end

player:GetAttributeChangedSignal("Rebirths"):Connect(refreshBonusPill)
player:GetAttributeChangedSignal("PassXPMultiplier"):Connect(refreshBonusPill)
refreshBonusPill()

local function fitHud()
	local viewport = gui.AbsoluteSize
	hudScale.Scale = math.clamp(viewport.X / 620, 0.5, 1.15)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHud)
fitHud()

--------------------------------------------------
-- BOTTOM-LEFT REBIRTH PANEL
--------------------------------------------------

local touch = UserInputService.TouchEnabled

local rebirthPanel = create("TextButton", {
	Name = "RebirthPanel",
	AnchorPoint = Vector2.new(0, 1),
	-- On touch devices the left-bottom corner belongs to the thumbstick.
	Position = touch and UDim2.new(0, 10, 1, -190) or UDim2.new(0, 10, 1, -10),
	Size = UDim2.fromOffset(300, 124),
	BackgroundColor3 = CREAM,
	Text = "",
	AutoButtonColor = false,
}, gui)
round(rebirthPanel, 14)
outline(rebirthPanel, 4)
local rebirthScale = create("UIScale", { Scale = 1 }, rebirthPanel)
Shine.Attach(rebirthPanel, { Offset = 2.2 })

-- Percentage to the next rebirth, on top of the panel.
local percentLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(10, 4),
	Size = UDim2.new(1, -20, 0, 22),
	Font = FONT,
	Text = "0% TO NEXT REBIRTH",
	TextColor3 = INK,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
}, rebirthPanel)

local rebirthIconHolder = create("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(8, 30),
	Size = UDim2.fromOffset(52, 52),
}, rebirthPanel)
addOilIcon(rebirthIconHolder, UDim2.fromScale(1, 1))

-- Kept under the old name: shows the rebirth count title.
local multiplierLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(66, 28),
	Size = UDim2.new(1, -74, 0, 22),
	Font = FONT,
	Text = "REBIRTH 0",
	TextColor3 = INK,
	TextSize = 19,
	TextXAlignment = Enum.TextXAlignment.Left,
}, rebirthPanel)

local nextLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(66, 50),
	Size = UDim2.new(1, -74, 0, 14),
	Font = FONT,
	Text = "",
	TextColor3 = Color3.fromRGB(110, 70, 30),
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
}, rebirthPanel)

-- Two multiplier chips next to the rebirth: OIL / WINS (XP is shown in the bonus pill instead)
local function makeChip(index, caption, color)
	local chip = create("Frame", {
		Position = UDim2.fromOffset(70 + (index - 1) * 110, 66),
		Size = UDim2.fromOffset(104, 22),
		BackgroundColor3 = color,
	}, rebirthPanel)
	round(chip, 11)
	outline(chip, 2)

	local label = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = caption,
		TextColor3 = CREAM,
		TextSize = 15,
	}, chip)
	create("UIStroke", { Color = INK, Thickness = 1.5 }, label)

	return label, create("UIScale", { Scale = 1 }, chip)
end

local oilChip2, oilChipScale = makeChip(1, "🛢️ x1", Color3.fromRGB(110, 90, 160))
local winsChip, winsChipScale = makeChip(2, "🏆 x1", Color3.fromRGB(88, 196, 110))

local rebirthTrack = create("Frame", {
	Position = UDim2.fromOffset(10, 96),
	Size = UDim2.new(1, -20, 0, 18),
	BackgroundColor3 = Color3.fromRGB(70, 66, 90),
}, rebirthPanel)
round(rebirthTrack, 9)
outline(rebirthTrack, 2)

local rebirthFill = create("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = LANE,
}, rebirthTrack)
round(rebirthFill, 9)

local rebirthLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextSize = 11,
	ZIndex = 3,
}, rebirthTrack)
create("UIStroke", { Color = INK, Thickness = 1.5 }, rebirthLabel)

-- Opens the existing rebirth panel (owned by RebirthUIClient).
rebirthPanel.Activated:Connect(function()
	local toggle = playerGui:FindFirstChild("ToggleRebirthPanel")
	if toggle then
		toggle:Fire()
	end
end)

local function fitRebirth()
	local viewport = gui.AbsoluteSize
	rebirthScale.Scale = math.clamp(viewport.X / 900, 0.6, 1)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitRebirth)
fitRebirth()

--------------------------------------------------
-- LEVEL UP
--------------------------------------------------

local levelUpSound = create("Sound", {
	SoundId = "rbxasset://sounds/victory.wav",
	Volume = 0.5,
}, gui)

local function levelUpBurst(newLevel)
	levelUpSound:Play()

	local banner = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -170),
		Size = UDim2.fromOffset(360, 64),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "LEVEL UP!  " .. tostring(newLevel),
		TextColor3 = LANE,
		TextSize = 40,
		ZIndex = 30,
	}, gui)
	create("UIStroke", { Color = INK, Thickness = 4 }, banner)
	local bannerScale = create("UIScale", { Scale = 0.3 }, banner)

	TweenService:Create(
		bannerScale,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	-- Confetti-style sparks around the level panel
	local origin = levelPanel.AbsolutePosition + levelPanel.AbsoluteSize / 2
	for index = 1, 14 do
		local angle = (index / 14) * math.pi * 2
		local spark = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(origin.X, origin.Y),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = (index % 2 == 0) and LANE or PIN_RED,
			Rotation = index * 25,
			ZIndex = 29,
		}, gui)
		round(spark, 3)

		local distance = 70 + (index % 3) * 25
		local tween = TweenService:Create(
			spark,
			TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromOffset(
					origin.X + math.cos(angle) * distance,
					origin.Y + math.sin(angle) * distance - 20
				),
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(4, 4),
			}
		)
		tween.Completed:Once(function()
			spark:Destroy()
		end)
		tween:Play()
	end

	bump(levelScale, 1.12)
	bump(badgeScale, 1.1)

	task.delay(1.6, function()
		local fade = TweenService:Create(
			banner,
			TweenInfo.new(0.4),
			{ TextTransparency = 1, Position = UDim2.new(0.5, 0, 1, -200) }
		)
		fade.Completed:Once(function()
			banner:Destroy()
		end)
		fade:Play()
	end)
end

--------------------------------------------------
-- REFRESH FROM SERVER ATTRIBUTES
--------------------------------------------------

local lastLevel = nil
local barTween = nil

local function refreshLevel()
	local level = player:GetAttribute("Level")
	local into = player:GetAttribute("XPIntoLevel")
	local needed = player:GetAttribute("XPNeededForLevel")
	local progress = player:GetAttribute("LevelProgress")

	if typeof(level) ~= "number" then
		return
	end

	levelLabel.Text = "LEVEL " .. math.floor(level)

	if typeof(into) == "number" and typeof(needed) == "number" then
		barLabel.Text = formatNumber(into) .. " / " .. formatNumber(needed)
	end

	if typeof(progress) == "number" then
		if barTween then
			barTween:Cancel()
		end
		barTween = TweenService:Create(
			barFill,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1) }
		)
		barTween:Play()
	end

	if lastLevel ~= nil and level > lastLevel then
		levelUpBurst(math.floor(level))
	end
	lastLevel = level
end

local function refreshGlobal()
	local value = player:GetAttribute("GlobalLevel")
	if typeof(value) == "number" then
		local text = tostring(math.floor(value))
		if globalLabel.Text ~= text then
			globalLabel.Text = text
			bump(badgeScale, 1.12)
		end
	end
end

local lastOil = nil

local function refreshOil()
	local oil = player:GetAttribute("CurrentOil")
	if typeof(oil) ~= "number" then
		return
	end

	oilLabel.Text = formatNumber(oil)

	if lastOil ~= nil and oil > lastOil then
		bump(oilScale, 1.12)
	end
	lastOil = oil
end

local lastRebirths = nil

local function refreshRebirth()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local level = player:GetAttribute("Level") or 1
	local required = player:GetAttribute("RebirthLevelRequirement") or 65

	-- Display only: the server applies these same rules (RebirthBonuses).
	local oilMultiplier = RebirthBonuses.OilMultiplier(rebirths)
	local winsMultiplier = RebirthBonuses.WinsMultiplier(rebirths)

	multiplierLabel.Text = "REBIRTH " .. rebirths
	oilChip2.Text = "🛢️ x" .. formatNumber(oilMultiplier)
	winsChip.Text = "🏆 x" .. formatNumber(winsMultiplier)

	-- What the next rebirth adds
	local nextWins = RebirthBonuses.WinsMultiplier(rebirths + 1)
	nextLabel.Text = "NEXT: 🛢️ x" .. formatNumber(RebirthBonuses.OilMultiplier(rebirths + 1))
		.. (nextWins > winsMultiplier and (" + 🏆 x" .. formatNumber(nextWins)) or "")

	local fraction = math.clamp(level / math.max(required, 1), 0, 1)
	TweenService:Create(
		rebirthFill,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad),
		{ Size = UDim2.fromScale(fraction, 1) }
	):Play()

	percentLabel.Text = fraction >= 1
		and "READY! TAP TO REBIRTH"
		or (math.floor(fraction * 100) .. "% TO NEXT REBIRTH")
	rebirthLabel.Text = "LV " .. math.floor(level) .. " / " .. required

	if lastRebirths ~= nil and rebirths > lastRebirths then
		-- A rebirth just happened: pop the panel and every chip that grew.
		bump(rebirthScale, 1.15)
		bump(oilChipScale, 1.3)
		bump(winsChipScale, 1.3)
	end
	lastRebirths = rebirths
end

for _, name in ipairs({ "Level", "XPIntoLevel", "XPNeededForLevel", "LevelProgress" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshLevel)
end
player:GetAttributeChangedSignal("GlobalLevel"):Connect(refreshGlobal)
player:GetAttributeChangedSignal("CurrentOil"):Connect(refreshOil)
for _, name in ipairs({ "Rebirths", "RebirthLevelRequirement", "Level" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshRebirth)
end

refreshLevel()
refreshGlobal()
refreshOil()
refreshRebirth()

--------------------------------------------------
-- FLOATING XP -> LEVEL BAR
--
-- The server fires XPAward with the amount it actually granted. Awards
-- arrive many times a second, so they are batched into one label per
-- quarter second that flies into the bar.
--------------------------------------------------

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local xpAward = remotes:WaitForChild("XPAward")

	local batched = 0
	local scheduled = false

	local function flush()
		scheduled = false
		local amount = batched
		batched = 0
		if amount <= 0 then
			return
		end

		local viewport = gui.AbsoluteSize
		local label = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(
				viewport.X * 0.5 + math.random(-60, 60),
				viewport.Y * 0.55
			),
			Size = UDim2.fromOffset(200, 36),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = "+" .. formatNumber(amount) .. " XP",
			TextColor3 = GREEN,
			TextSize = 26,
			ZIndex = 25,
		}, gui)
		create("UIStroke", { Color = INK, Thickness = 3 }, label)

		local target = barTrack.AbsolutePosition + barTrack.AbsoluteSize / 2
		local tween = TweenService:Create(
			label,
			TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.fromOffset(target.X, target.Y),
				TextSize = 14,
				TextTransparency = 0.4,
			}
		)
		tween.Completed:Once(function()
			label:Destroy()
			bump(levelScale, 1.05)
		end)
		tween:Play()
	end

	xpAward.OnClientEvent:Connect(function(amount)
		if typeof(amount) ~= "number" or amount <= 0 then
			return
		end

		batched += amount
		if not scheduled then
			scheduled = true
			task.delay(0.25, flush)
		end
	end)
end)
