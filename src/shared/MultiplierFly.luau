--------------------------------------------------
-- MULTIPLIER FLY (client presentation only)
--
-- A multiplier chip (barrel = oil, trophy = wins) lifts off from its HUD
-- tile in the bottom-left panel, counts up from x1 to its real value with
-- ticking sounds that speed up (faster for bigger numbers), then is dragged
-- into the number it multiplies. Every number comes from the server; this
-- module only animates. It never awards or changes anything.
--
--   MultiplierFly.Fly({
--       Gui        = ScreenGui to draw in (IgnoreGuiInset = true),
--       Source     = GuiObject to start from (optional),
--       Target     = Vector2, absolute screen point to fly into,
--       Multiplier = number,
--       Kind       = "Oil" | "Wins",
--       Color      = Color3,
--       Label      = string (optional small caption, e.g. "CAPTAIN"),
--       FromLeft   = bool (when there is no Source),
--       Sound      = function(id, volume, speed),
--   })   -- yields until the chip has landed
--   MultiplierFly.FindTile(playerGui, "Oil" | "Wins") -> GuiObject?
--------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local UiAssets = require(ReplicatedStorage:WaitForChild("UiAssets"))
local Haptics = require(ReplicatedStorage:WaitForChild("Haptics"))
local SoftPop = require(ReplicatedStorage:WaitForChild("SoftPop"))

local TICK_SOUND = "rbxassetid://9120386436"
local WHOOSH_SOUND = "rbxassetid://9125402735"
local INK = Color3.fromRGB(24, 22, 34)
local FONT = Enum.Font.FredokaOne

local MultiplierFly = {}

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function compact(value)
	value = math.floor(value)
	-- each step starts where the one below would round up to "1000.0" (999,960,000 is 1.0B)
	if value >= 999.95e6 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 999.95e3 then
		return string.format("%.1fM", value / 1e6)
	elseif value >= 1e4 then
		return string.format("%.1fK", value / 1e3)
	end
	local text = tostring(value)
	return (text:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- The two big tiles of the HUD's bottom-left rebirth panel: oil (x = 10)
-- and wins (x = 140).
function MultiplierFly.FindTile(playerGui, kind)
	for _, inst in ipairs(playerGui:GetDescendants()) do
		if inst.Name == "RebirthPanel" and inst:IsA("GuiObject") then
			for _, child in ipairs(inst:GetChildren()) do
				if child:IsA("Frame") and child.Size.X.Offset >= 100 then
					local x = child.Position.X.Offset
					if (kind == "Oil" and x < 60) or (kind == "Wins" and x >= 60) then
						return child
					end
				end
			end
		end
	end
	return nil
end

-- A burst of little sparkles flying outward from a screen point.
local function burst(gui, point, color, count, spread)
	for index = 1, count do
		local size = math.random(8, 18)
		local spark = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(point.X, point.Y),
			Size = UDim2.fromOffset(size, size),
			Rotation = math.random(0, 90),
			BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), math.random() * 0.6),
			BorderSizePixel = 0,
			ZIndex = 79,
		}, gui)
		create("UICorner", { CornerRadius = UDim.new(0.3, 0) }, spark)

		local angle = (index / count) * math.pi * 2 + math.random() * 0.5
		local distance = spread * (0.55 + math.random() * 0.6)
		local tween = TweenService:Create(
			spark,
			TweenInfo.new(0.55 + math.random() * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Position = UDim2.fromOffset(point.X + math.cos(angle) * distance, point.Y + math.sin(angle) * distance),
				Size = UDim2.fromOffset(2, 2),
				Rotation = spark.Rotation + math.random(-200, 200),
				BackgroundTransparency = 1,
			}
		)
		tween.Completed:Once(function()
			spark:Destroy()
		end)
		tween:Play()
	end
end

-- An expanding ring (shockwave) at a screen point.
local function ring(gui, point, color, size)
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(point.X, point.Y),
		Size = UDim2.fromOffset(40, 40),
		BackgroundTransparency = 1,
		ZIndex = 78,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(1, 0) }, frame)
	local stroke = create("UIStroke", { Color = color, Thickness = 8 }, frame)
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(frame, info, { Size = UDim2.fromOffset(size, size) }):Play()
	local fade = TweenService:Create(stroke, info, { Thickness = 1, Transparency = 1 })
	fade.Completed:Once(function()
		frame:Destroy()
	end)
	fade:Play()
end

function MultiplierFly.Fly(options)
	local gui = options.Gui
	local multiplier = math.max(tonumber(options.Multiplier) or 1, 1)
	local playSound = options.Sound or function() end
	local viewport = gui.AbsoluteSize
	-- size follows the screen (phone ~0.75x, laptop ~1.2x, big monitor 1.9x); every scale below is times this
	local f = math.clamp(math.min(viewport.X / 1100, viewport.Y / 620), 0.6, 1.5) * 1.1

	-- Just the big icon and number: no box, no background.
	local width = options.Label and 400 or 330
	local chip = create("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(width, 120),
		BackgroundTransparency = 1,
		ZIndex = 80,
	}, gui)
	local chipScale = create("UIScale", { Scale = 0.6 * f }, chip)

	if options.Kind == "Wins" then
		create("ImageLabel", {
			Position = UDim2.fromOffset(6, 8),
			Size = UDim2.fromOffset(104, 104),
			BackgroundTransparency = 1,
			Image = UiAssets.TrophyImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 81,
		}, chip)
	else
		create("ImageLabel", {
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.fromOffset(112, 104),
			BackgroundTransparency = 1,
			Image = UiAssets.OilImages.Black,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 81,
		}, chip)
	end

	local label = create("TextLabel", {
		Position = UDim2.fromOffset(118, options.Label and 6 or 0),
		Size = UDim2.new(1, -122, options.Label and 0.68 or 1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "x1",
		TextColor3 = options.Color and options.Color:Lerp(Color3.new(1, 1, 1), 0.55) or Color3.new(1, 1, 1),
		TextSize = 84,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 81,
	}, chip)
	create("UIStroke", { Color = INK, Thickness = 6 }, label)

	if options.Label then
		local caption = create("TextLabel", {
			Position = UDim2.new(0, 118, 0.7, 0),
			Size = UDim2.new(1, -122, 0.28, 0),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = options.Label,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 81,
		}, chip)
		create("UIStroke", { Color = INK, Thickness = 3.5 }, caption)
	end

	-- start point: lift off from the HUD tile, or slide in from a screen edge
	local startPoint
	if options.Source and options.Source.Parent then
		startPoint = options.Source.AbsolutePosition + options.Source.AbsoluteSize / 2

		-- a source in a ScreenGui that keeps the top-bar inset is offset
		local sourceGui = options.Source:FindFirstAncestorWhichIsA("ScreenGui")
		if sourceGui and not sourceGui.IgnoreGuiInset and gui.IgnoreGuiInset then
			startPoint += GuiService:GetGuiInset()
		end
	else
		startPoint = Vector2.new(options.FromLeft and -width or viewport.X + width, viewport.Y * 0.6)
	end
	chip.Position = UDim2.fromOffset(startPoint.X, startPoint.Y)

	-- 1) rise a little and pop in
	-- it flies to the MIDDLE of the screen (not a short hop in the corner) so the player
	-- watches the count-up; wins sit a little higher, clear of the big total below them
	local halfWidth = width / 2 * f * 1.2
	local halfHeight = 60 * f * 1.2
	local rise = Vector2.new(
		math.clamp(viewport.X / 2, halfWidth, viewport.X - halfWidth),
		math.clamp(viewport.Y * (options.Kind == "Wins" and 0.40 or 0.46), halfHeight, viewport.Y - halfHeight)
	)
	TweenService:Create(chipScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1.1 * f }):Play()
	local up = TweenService:Create(
		chip,
		TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(rise.X, rise.Y) }
	)
	up:Play()
	up.Completed:Wait()

	-- 2) count up x1 -> xN. Longer for bigger numbers; the ticks speed up as
	-- the count accelerates, and big numbers tick faster overall.
	local duration = math.clamp(0.5 + math.log10(multiplier) * 0.45, 0.55, 2.2)
	local tickBase = math.clamp(0.14 - math.log10(multiplier) * 0.025, 0.04, 0.14)
	local started = os.clock()
	local nextTick = 0
	local ticks = 0
	local baseColor = options.Color and options.Color:Lerp(Color3.new(1, 1, 1), 0.55) or Color3.new(1, 1, 1)
	local rainbow = multiplier >= 10
	local center = Vector2.new(rise.X, rise.Y)
	local milestone = 0
	while true do
		local t = (os.clock() - started) / duration
		if t >= 1 then
			break
		end
		local alpha = t * t * (1.7 - 0.7 * t)
		label.Text = "x" .. compact(1 + (multiplier - 1) * alpha)

		-- the number heats up as it climbs: rainbow for big multipliers
		if rainbow then
			label.TextColor3 = Color3.fromHSV((os.clock() * 1.6) % 1, 0.5, 1)
		else
			label.TextColor3 = baseColor:Lerp(Color3.fromRGB(255, 236, 120), alpha * 0.6)
		end

		if t >= nextTick then
			ticks += 1
			nextTick = t + math.max(0.015, tickBase * (1 - t * 0.85) / duration)
			playSound(TICK_SOUND, 0.28, 0.85 + math.min(ticks, 30) * 0.045)
			-- a soft buzz per tick that builds as the count climbs
			Haptics.Pulse(0.25 + 0.5 * alpha, 0.045)
			-- every tick punches the number a little
			chipScale.Scale = (1.1 + 0.1 * alpha + 0.05) * f
		end

		-- shockwave + sparkles at each quarter of the climb
		if t >= (milestone + 1) * 0.25 then
			milestone += 1
			ring(gui, center + Vector2.new(50 * f, 0), baseColor, 220 + milestone * 40)
			burst(gui, center + Vector2.new(50 * f, 0), baseColor, 6 + milestone * 2, 120 + milestone * 20)
		end

		chipScale.Scale += ((1.1 + 0.12 * alpha + 0.04 * math.sin(os.clock() * 34)) * f - chipScale.Scale) * 0.35
		chip.Rotation = math.sin(os.clock() * 22) * (1 + alpha * 3.5)
		RunService.RenderStepped:Wait()
	end
	label.Text = "x" .. compact(multiplier)
	label.TextColor3 = Color3.fromRGB(255, 240, 130)
	chip.Rotation = 0
	chipScale.Scale = 1.45 * f
	TweenService:Create(chipScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1.15 * f }):Play()
	playSound(WHOOSH_SOUND, 0.45, 1.1 + math.min(multiplier, 40) * 0.01)
	Haptics.Thump()
	ring(gui, center + Vector2.new(50 * f, 0), Color3.fromRGB(255, 240, 130), 420)
	burst(gui, center + Vector2.new(50 * f, 0), Color3.fromRGB(255, 226, 90), 22, 220)
	task.wait(0.28)

	-- 3) drag it into the number, leaving a glittering trail
	local target = options.Target
	local drag = TweenService:Create(
		chip,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.fromOffset(target.X, target.Y), GroupTransparency = 0.2 }
	)
	TweenService:Create(chipScale, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.35 * f }):Play()
	drag:Play()
	task.spawn(function()
		while chip.Parent and drag.PlaybackState == Enum.PlaybackState.Playing do
			local abs = chip.AbsolutePosition + chip.AbsoluteSize / 2
			burst(gui, abs, Color3.fromRGB(255, 226, 90), 2, 60)
			task.wait(0.05)
		end
	end)
	drag.Completed:Wait()
	SoftPop.Play(0.9)
	chip:Destroy()
	ring(gui, target, Color3.fromRGB(255, 240, 130), 300)
	burst(gui, target, Color3.fromRGB(255, 226, 90), 16, 160)
end

return MultiplierFly
