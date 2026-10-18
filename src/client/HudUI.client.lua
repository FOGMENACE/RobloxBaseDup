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
	Position = UDim2.fromOffset(6, 8),
	Size = UDim2.fromOffset(46, 34),
}, oilChip)
addOilIcon(oilIconHolder, UDim2.fromScale(1, 1))

local oilLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(56, 0),
	Size = UDim2.new(1, -60, 1, 0),
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
local BadgeOverlay = require(ReplicatedStorage:WaitForChild("BadgeOverlay"))

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
	BadgeOverlay.Attach(badge, button, { Dx = 6, Dy = -8 })

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
	Position = UDim2.fromOffset(366, -60),
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
	-- plain digits, no thousands separators (commas looked choppy)
	return "+" .. tostring(value) .. "%"
end

local function refreshBonusPill()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local rebirthPercent = (RebirthBonuses.XPMultiplier(rebirths) - 1) * 100
	local passMultiplier = player:GetAttribute("PassXPMultiplier") or 1
	local passPercent = math.max(passMultiplier - 1, 0) * 100

	-- Stays at +1000% up to the x10 wins multiplier, then follows it 1:1 (x11 = +1100%,
	-- x12 = +1200%, x13 = +1300% ...): 100% per extra wins multiplier.
	local winsNow = RebirthBonuses.WinsMultiplier(rebirths)
	local pillPercent = math.max(1000, winsNow * 100)
	rebirthBonusLine.Text = "REBIRTH XP " .. percentText(pillPercent)
	passBonusLine.Text = "PASS XP " .. percentText(passPercent)
	bump(bonusScale, 1.08)
end

player:GetAttributeChangedSignal("Rebirths"):Connect(refreshBonusPill)
player:GetAttributeChangedSignal("PassXPMultiplier"):Connect(refreshBonusPill)
refreshBonusPill()

--------------------------------------------------
-- SOFT SHADOWS under the main bottom panels (depth, "premium" feel)
--------------------------------------------------

for _, entry in ipairs({ { "GlobalBadge", 44 }, { "LevelPanel", 20 }, { "OilChip", 20 } }) do
	local panel = hud:FindFirstChild(entry[1])
	if panel then
		local shadow = create("Frame", {
			Name = entry[1] .. "Shadow",
			Position = panel.Position + UDim2.fromOffset(0, 6),
			Size = panel.Size,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.62,
			ZIndex = 0,
		}, hud)
		round(shadow, entry[2])
	end
end

--------------------------------------------------
-- FIT + COMPACT MODE
--
-- While rolling (RunState is not Waiting) the HUD shrinks and the XP kit
-- row and bonus pill hide, so the bottom of the screen stays clear and the
-- ball is never covered.
--------------------------------------------------

local running = false

local function applyHudScale(animated)
	local viewport = gui.AbsoluteSize
	local target = math.clamp(viewport.X / 620, 0.5, 1.15) * (running and 0.76 or 1)

	if animated then
		TweenService:Create(hudScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Scale = target }):Play()
	else
		hudScale.Scale = target
	end
end

local function fitHud()
	applyHudScale(false)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitHud)
fitHud()

local function refreshCompact()
	local state = player:GetAttribute("RunState")
	local nowRunning = state ~= nil and state ~= "Waiting"

	if nowRunning ~= running then
		running = nowRunning
		kitRow.Visible = not running
		bonusPill.Visible = not running
		TweenService:Create(hud, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Position = running and UDim2.new(0.5, 0, 1, 190) or UDim2.new(0.5, 0, 1, -10),
		}):Play()
		applyHudScale(true)
	end
end
player:GetAttributeChangedSignal("RunState"):Connect(refreshCompact)
refreshCompact()

--------------------------------------------------
-- BOTTOM-LEFT REBIRTH PANEL
--------------------------------------------------

local touch = UserInputService.TouchEnabled

local rebirthPanel = create("TextButton", {
	Name = "RebirthPanel",
	AnchorPoint = Vector2.new(0, 1),
	-- On touch devices the left-bottom corner belongs to the thumbstick.
	Position = touch and UDim2.new(0, 10, 1, -190) or UDim2.new(0, 10, 1, -10),
	Size = UDim2.fromOffset(270, 132),
	BackgroundColor3 = CREAM,
	Text = "",
	AutoButtonColor = false,
}, gui)
round(rebirthPanel, 18)
outline(rebirthPanel, 4)
local rebirthScale = create("UIScale", { Scale = 1 }, rebirthPanel)
Shine.Attach(rebirthPanel, { Offset = 2.2 })

-- Header: which rebirth you are on.
local multiplierLabel = create("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(0, 5),
	Size = UDim2.new(1, 0, 0, 18),
	Font = FONT,
	Text = "REBIRTH 0",
	TextColor3 = Color3.fromRGB(110, 70, 160),
	TextSize = 15,
}, rebirthPanel)

-- Two big tiles: TROPHY = wins multiplier (left), BARREL = oil multiplier (right).
local function makeTile(x, tint)
	local tile = create("Frame", {
		Position = UDim2.fromOffset(x, 26),
		Size = UDim2.fromOffset(120, 100),
		BackgroundColor3 = tint,
	}, rebirthPanel)
	round(tile, 14)
	outline(tile, 3)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 225)),
		Rotation = 90,
	}, tile)

	local scale = create("UIScale", { Scale = 1 }, tile)
	return tile, scale
end

local winsTile, winsChipScale = makeTile(140, Color3.fromRGB(255, 236, 160))
local oilTile, oilChipScale = makeTile(10, Color3.fromRGB(196, 186, 235))

-- trophy image (left)
create("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 4),
	Size = UDim2.fromOffset(58, 58),
	BackgroundTransparency = 1,
	Image = UiAssets.TrophyImage,
	ScaleType = Enum.ScaleType.Fit,
}, winsTile)

-- barrel (right): a big emoji (renders crisply at this size)
create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 2),
	Size = UDim2.fromOffset(62, 60),
	BackgroundTransparency = 1,
	Font = FONT,
	Text = "🛢️",
	TextSize = 50,
	TextColor3 = INK,
}, oilTile)

local function multiplierText(tile, textColor)
	local label = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -8, 0, 34),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "x1",
		TextColor3 = textColor,
		TextSize = 30,
	}, tile)
	create("UIStroke", { Color = INK, Thickness = 2.5 }, label)
	return label
end

local winsChip = multiplierText(winsTile, Color3.fromRGB(255, 255, 255))
local oilChip2 = multiplierText(oilTile, Color3.fromRGB(255, 255, 255))

-- New players do not see the multiplier panel until the tutorial reaches\n-- the rebirth step (TutorialService step 4); veterans see it at once.
local tutorialTimedOut = false
local function applyTutorialVisibility()
	local step = player:GetAttribute("TutorialStep")
	local known = typeof(step) == "number"
	rebirthPanel.Visible = known and step >= 4 or (not known and tutorialTimedOut)
end
player:GetAttributeChangedSignal("TutorialStep"):Connect(applyTutorialVisibility)
applyTutorialVisibility()
task.delay(8, function()
	tutorialTimedOut = true
	applyTutorialVisibility()
end)

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
local levelMaxed = false
local shakeToken = 0

-- "REBIRTH REQUIRED" shakes side to side every time XP lands on the full bar.
local function shakeRebirthRequired()
	shakeToken += 1
	local token = shakeToken
	task.spawn(function()
		for step = 1, 8 do
			if token ~= shakeToken then
				return
			end
			local amount = (9 - step) * 1.2
			barLabel.Position = UDim2.fromOffset((step % 2 == 0 and 1 or -1) * amount, 0)
			barLabel.Rotation = (step % 2 == 0 and 1 or -1) * (9 - step) * 0.5
			task.wait(0.035)
		end
		barLabel.Position = UDim2.fromOffset(0, 0)
		barLabel.Rotation = 0
	end)
end

local function refreshLevel()
	local level = player:GetAttribute("Level")
	local into = player:GetAttribute("XPIntoLevel")
	local needed = player:GetAttribute("XPNeededForLevel")
	local progress = player:GetAttribute("LevelProgress")

	if typeof(level) ~= "number" then
		return
	end

	local maxed = player:GetAttribute("RebirthMaxReached") == true
	levelMaxed = maxed

	if maxed then
		-- At the reach level the bar is full: say so, and ask for the rebirth.
		levelLabel.Text = "MAX LEVEL"
		barLabel.Text = "REBIRTH REQUIRED"
		barLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	else
		levelLabel.Text = "LEVEL " .. math.floor(level)
		barLabel.TextColor3 = CREAM
		if typeof(into) == "number" and typeof(needed) == "number" then
			barLabel.Text = formatNumber(into) .. " / " .. formatNumber(needed)
		end
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
	local value = player:GetAttribute("RebirthLevelRequirement")
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
local lastShowWins = nil

local function refreshRebirth()
	local rebirths = player:GetAttribute("Rebirths") or 0

	-- Display only: the server applies these same rules (RebirthBonuses).
	local oilMultiplier = RebirthBonuses.OilMultiplier(rebirths)
	local winsMultiplier = RebirthBonuses.WinsMultiplier(rebirths)

	multiplierLabel.Text = "REBIRTH " .. rebirths

	-- The wins multiplier tile only exists once a rebirth grants it (rebirth 2).
	-- Until then the panel is just the oil tile; when it is earned the panel
	-- expands and the trophy tile pops in.
	local showWins = winsMultiplier > 1
	if showWins ~= lastShowWins then
		local targetWidth = showWins and 270 or 140
		if lastShowWins == nil then
			rebirthPanel.Size = UDim2.fromOffset(targetWidth, rebirthPanel.Size.Y.Offset)
			winsTile.Visible = showWins
		else
			TweenService:Create(
				rebirthPanel,
				TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Size = UDim2.fromOffset(targetWidth, rebirthPanel.Size.Y.Offset) }
			):Play()
			winsTile.Visible = showWins
			if showWins then
				winsChipScale.Scale = 0.2
				TweenService:Create(winsChipScale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end
		end
		lastShowWins = showWins
	end
	oilChip2.Text = "x" .. formatNumber(oilMultiplier)
	winsChip.Text = "x" .. formatNumber(winsMultiplier)

	if lastRebirths ~= nil and rebirths > lastRebirths then
		-- A rebirth just happened: pop the panel and both tiles.
		bump(rebirthScale, 1.15)
		bump(oilChipScale, 1.3)
		bump(winsChipScale, 1.3)
	end
	lastRebirths = rebirths
end

for _, name in ipairs({ "Level", "XPIntoLevel", "XPNeededForLevel", "LevelProgress", "RebirthMaxReached" }) do
	player:GetAttributeChangedSignal(name):Connect(refreshLevel)
end
player:GetAttributeChangedSignal("RebirthLevelRequirement"):Connect(refreshGlobal)
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

		if levelMaxed then
			shakeRebirthRequired()
		end

		batched += amount
		if not scheduled then
			scheduled = true
			task.delay(0.25, flush)
		end
	end)
end)
