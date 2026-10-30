--------------------------------------------------
-- BALL TIER UI
--
-- CLIENT ONLY. Feedback for the oil course's upgrade / downgrade gates
-- (decided by BallTierGates on the server):
--   Up        green banner, rising arrows, bright flash, happy sound
--   Down      purple/red banner, shake, dark flash, sad sound
--   MaxUp     gold "already the best ball" note
--   MinDown   safe "already the lowest ball" note
-- Plus a small chip under the oil meter showing which ball you are
-- currently rolling (the server attribute RunBallName).
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local GREEN = Color3.fromRGB(88, 196, 110)
local GOLD = Color3.fromRGB(255, 205, 70)
local PURPLE = Color3.fromRGB(150, 98, 230)
local RED = Color3.fromRGB(230, 70, 70)
local FONT = Enum.Font.FredokaOne

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local old = playerGui:FindFirstChild("BallTierUI")
if old then
	old:Destroy()
end

local gui = create("ScreenGui", {
	Name = "BallTierUI",
	ResetOnSpawn = false,
	DisplayOrder = 14,
	IgnoreGuiInset = true,
}, playerGui)

local flash = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ZIndex = 1,
}, gui)

-- Upgrade = a bright three-part chime (ping + button click + victory sparkle),
-- downgrade = a falling "swoop" (water-slide whoosh + low thud). Both are
-- mixes of built-in sounds so they differ from the oil platform sounds.
local function mix(parts)
	return {
		Play = function()
			for _, part in ipairs(parts) do
				task.delay(part[4] or 0, function()
					local sound = create("Sound", { SoundId = part[1], Volume = part[2], PlaybackSpeed = part[3] }, gui)
					sound:Play()
					task.delay(3, function()
						sound:Destroy()
					end)
				end)
			end
		end,
	}
end

local upSound = mix({
	{ "rbxasset://sounds/electronicpingshort.wav", 0.32, 1.35, 0 },
	{ "rbxasset://sounds/button.wav", 0.3, 1.7, 0.08 },
	{ "rbxasset://sounds/victory.wav", 0.16, 2.0, 0.14 },
})
local downSound = mix({
	{ "rbxasset://sounds/impact_water.mp3", 0.45, 1.9, 0 },
	{ "rbxasset://sounds/bass.mp3", 0.4, 0.7, 0.06 },
})
--------------------------------------------------
-- CURRENT BALL CHIP
--------------------------------------------------

local chip = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 104),
	Size = UDim2.fromOffset(240, 22),
	BackgroundTransparency = 1, -- no box, so the lane ahead stays visible
	Font = FONT,
	Text = "",
	TextColor3 = CREAM,
	TextTransparency = 0.1,
	TextSize = 15,
	Visible = false,
	ZIndex = 5,
}, gui)
create("UIStroke", { Color = INK, Thickness = 2.5 }, chip)
local chipScale = create("UIScale", { Scale = 1 }, chip)

local function refreshChip()
	local name = player:GetAttribute("RunBallName")
	local runState = player:GetAttribute("RunState")
	local active = typeof(name) == "string" and name ~= ""
		and (runState == "Running" or runState == "Finishing" or runState == "Starting")

	chip.Visible = active
	if active then
		chip.Text = "BALL: " .. string.upper(name)
	end
end

player:GetAttributeChangedSignal("RunBallName"):Connect(function()
	refreshChip()
	chipScale.Scale = 1.25
	TweenService:Create(
		chipScale,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end)
player:GetAttributeChangedSignal("RunState"):Connect(refreshChip)
refreshChip()

--------------------------------------------------
-- BANNER + EFFECTS
--------------------------------------------------

local function particles(symbol, color, rising)
	local viewport = gui.AbsoluteSize

	for index = 1, 4 do
		local piece = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(
				viewport.X * (0.3 + math.random() * 0.4),
				viewport.Y * (rising and (0.7 + math.random() * 0.1) or (0.25 + math.random() * 0.1))
			),
			Size = UDim2.fromOffset(40, 40),
			Font = FONT,
			Text = symbol,
			TextColor3 = color,
			TextSize = 22 + math.random() * 8,
			ZIndex = 8,
		}, gui)
		create("UIStroke", { Color = INK, Thickness = 2 }, piece)

		local drift = rising and -viewport.Y * 0.35 or viewport.Y * 0.35
		local tween = TweenService:Create(
			piece,
			TweenInfo.new(0.9 + math.random() * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = piece.Position + UDim2.fromOffset((math.random() - 0.5) * 80, drift),
				TextTransparency = 1,
			}
		)
		tween.Completed:Once(function()
			piece:Destroy()
		end)
		task.delay(index * 0.03, function()
			tween:Play()
		end)
	end
end

-- Compact toast just under the oil meter (never over the lane ahead).
local function banner(title, subtitle, color)
	local holder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 134),
		Size = UDim2.fromOffset(300, 46),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.12,
		ZIndex = 9,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 14) }, holder)
	create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, holder)
	local scale = create("UIScale", { Scale = 0.5 }, holder)

	local fit = math.clamp(gui.AbsoluteSize.X / 900, 0.7, 1)

	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.new(1, 0, 0, 24),
		Font = FONT,
		Text = title,
		TextColor3 = CREAM,
		TextSize = 20,
		ZIndex = 10,
	}, holder)
	create("UIStroke", { Color = INK, Thickness = 2 }, titleLabel)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 25),
		Size = UDim2.new(1, 0, 0, 18),
		Font = FONT,
		Text = subtitle,
		TextColor3 = INK,
		TextSize = 13,
		ZIndex = 10,
	}, holder)

	TweenService:Create(
		scale,
		TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = fit }
	):Play()

	task.delay(1.1, function()
		local out = TweenService:Create(
			holder,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(0.5, 0, 0, 118), BackgroundTransparency = 1 }
		)
		out.Completed:Once(function()
			holder:Destroy()
		end)
		out:Play()
		for _, descendant in ipairs(holder:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				TweenService:Create(descendant, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif descendant:IsA("UIStroke") then
				TweenService:Create(descendant, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
	end)

	return holder
end

local function flashScreen(color, strength)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	TweenService:Create(
		flash,
		TweenInfo.new(0.6),
		{ BackgroundTransparency = 1 }
	):Play()
end

local function shake(holder)
	for index = 1, 8 do
		task.delay(index * 0.04, function()
			if holder.Parent then
				holder.Rotation = (index % 2 == 0 and 1 or -1) * (9 - index)
			end
		end)
	end
	task.delay(0.4, function()
		if holder.Parent then
			holder.Rotation = 0
		end
	end)
end

-- The ball itself reacts (local only, never replicated): a punchy explosion sound,
-- a coloured aura that flashes around the ball (green up, red down) with a burst
-- of light, and the ball blinking see-through and back while it changes.
local RunService = game:GetService("RunService")
local RunTiming = require(ReplicatedStorage:WaitForChild("RunTiming"))

local AURA_TIME = 0.7

local function ballAura(color, isUp)
	local balls = workspace:FindFirstChild("PlayerBalls")
	local ball = balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
	if not ball or not ball:IsA("BasePart") then
		return
	end

	local boom = create("Sound", {
		SoundId = "rbxasset://sounds/impact_explosion_03.mp3",
		Volume = 0.42,
		PlaybackSpeed = isUp and 1.3 or 0.85,
	}, gui)
	boom:Play()
	task.delay(3, function()
		boom:Destroy()
	end)

	local aura = create("Highlight", {
		Name = "TierAura",
		Adornee = ball,
		FillColor = color,
		OutlineColor = isUp and Color3.fromRGB(220, 255, 225) or Color3.fromRGB(255, 200, 200),
		FillTransparency = 1,
		OutlineTransparency = 1,
		DepthMode = Enum.HighlightDepthMode.Occluded,
	}, ball)
	local light = create("PointLight", {
		Color = color,
		Range = 18,
		Brightness = 0,
		Shadows = false,
	}, ball)

	-- the ball and its accessories blink: see-through, solid, see-through, solid
	local parts = { ball }
	for _, d in ipairs(ball:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end

	local started = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / AURA_TIME
		if t >= 1 or not ball.Parent then
			connection:Disconnect()
			for _, part in ipairs(parts) do
				if part.Parent then
					part.LocalTransparencyModifier = 0
				end
			end
			aura:Destroy()
			light:Destroy()
			return
		end
		-- two quick pulses, the second softer, then the aura fades out
		local pulse = math.abs(math.sin(t * math.pi * 2)) * (1 - t * 0.6)
		aura.FillTransparency = 1 - 0.75 * pulse
		aura.OutlineTransparency = 1 - pulse
		light.Brightness = 7 * pulse
		local blink = (t < 0.6) and (0.55 * math.abs(math.sin(t * math.pi * 5))) or 0
		for _, part in ipairs(parts) do
			part.LocalTransparencyModifier = blink
		end
	end)
end

task.spawn(function()
	local tierRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BallTier")

	tierRemote.OnClientEvent:Connect(function(kind, oldName, newName)
		oldName = string.upper(tostring(oldName))
		newName = string.upper(tostring(newName))

		-- the burst lands when the ball the player SEES reaches the platform
		if kind == "Up" or kind == "Down" then
			task.delay(RunTiming.Delay(), ballAura, kind == "Up" and GREEN or RED, kind == "Up")
		end

		if kind == "Up" then
			banner("BALL UPGRADE!", oldName .. "  >  " .. newName, GREEN)
			particles("^", GREEN, true)
			flashScreen(GREEN, 0.1)
			upSound:Play()

		elseif kind == "Down" then
			local holder = banner("BALL DOWNGRADE", oldName .. "  >  " .. newName, PURPLE)
			particles("v", RED, false)
			flashScreen(PURPLE, 0.12)
			shake(holder)
			downSound:Play()

		elseif kind == "MaxUp" then
			banner("BEST BALL!", newName .. " cannot go higher", GOLD)
			flashScreen(GOLD, 0.08)
			upSound:Play()

		elseif kind == "MinDown" then
			banner("SAFE!", newName .. " is already the lowest", GOLD)
			flashScreen(GOLD, 0.2)
		end
	end)
end)
