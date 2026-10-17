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

local upSound = create("Sound", { SoundId = "rbxasset://sounds/victory.wav", Volume = 0.55, PlaybackSpeed = 1.25 }, gui)
local downSound = create("Sound", { SoundId = "rbxasset://sounds/uuhhh.mp3", Volume = 0.6 }, gui)

--------------------------------------------------
-- CURRENT BALL CHIP
--------------------------------------------------

local chip = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 84),
	Size = UDim2.fromOffset(240, 30),
	BackgroundColor3 = CREAM,
	Font = FONT,
	Text = "",
	TextColor3 = INK,
	TextSize = 16,
	Visible = false,
	ZIndex = 5,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 15) }, chip)
create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
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

	for index = 1, 12 do
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
			TextSize = 30 + math.random() * 16,
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

local function banner(title, subtitle, color)
	local holder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(560, 130),
		BackgroundColor3 = color,
		ZIndex = 9,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, holder)
	create("UIStroke", { Color = INK, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, holder)
	local scale = create("UIScale", { Scale = 0.3 }, holder)

	local fit = math.clamp(gui.AbsoluteSize.X / 700, 0.6, 1)

	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 64),
		Font = FONT,
		Text = title,
		TextColor3 = CREAM,
		TextSize = 46,
		ZIndex = 10,
	}, holder)
	create("UIStroke", { Color = INK, Thickness = 3 }, titleLabel)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 38),
		Font = FONT,
		Text = subtitle,
		TextColor3 = INK,
		TextSize = 28,
		ZIndex = 10,
	}, holder)

	TweenService:Create(
		scale,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = fit }
	):Play()

	task.delay(1.9, function()
		local out = TweenService:Create(
			holder,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromScale(0.5, 0.2), BackgroundTransparency = 1 }
		)
		out.Completed:Once(function()
			holder:Destroy()
		end)
		out:Play()
		for _, descendant in ipairs(holder:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				TweenService:Create(descendant, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
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

task.spawn(function()
	local tierRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BallTier")

	tierRemote.OnClientEvent:Connect(function(kind, oldName, newName)
		oldName = string.upper(tostring(oldName))
		newName = string.upper(tostring(newName))

		if kind == "Up" then
			banner("BALL UPGRADE!", oldName .. "  >  " .. newName, GREEN)
			particles("^", GREEN, true)
			flashScreen(GREEN, 0.35)
			upSound:Play()

		elseif kind == "Down" then
			local holder = banner("BALL DOWNGRADE", oldName .. "  >  " .. newName, PURPLE)
			particles("v", RED, false)
			flashScreen(PURPLE, 0.45)
			shake(holder)
			downSound:Play()

		elseif kind == "MaxUp" then
			banner("BEST BALL!", newName .. " cannot go higher", GOLD)
			flashScreen(GOLD, 0.25)
			upSound:Play()

		elseif kind == "MinDown" then
			banner("SAFE!", newName .. " is already the lowest", GOLD)
			flashScreen(GOLD, 0.2)
		end
	end)
end)
