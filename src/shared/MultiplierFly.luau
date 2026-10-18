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
	if value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
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

function MultiplierFly.Fly(options)
	local gui = options.Gui
	local multiplier = math.max(tonumber(options.Multiplier) or 1, 1)
	local playSound = options.Sound or function() end
	local viewport = gui.AbsoluteSize

	local width = options.Label and 250 or 190
	local chip = create("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(width, 66),
		BackgroundColor3 = options.Color or Color3.fromRGB(150, 90, 235),
		ZIndex = 80,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, chip)
	create("UIStroke", { Color = INK, Thickness = 4 }, chip)
	local chipScale = create("UIScale", { Scale = 0.6 }, chip)

	if options.Kind == "Wins" then
		create("ImageLabel", {
			Position = UDim2.fromOffset(8, 7),
			Size = UDim2.fromOffset(52, 52),
			BackgroundTransparency = 1,
			Image = UiAssets.TrophyImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 81,
		}, chip)
	else
		create("TextLabel", {
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.fromOffset(56, 62),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = "🛢️",
			TextSize = 44,
			TextColor3 = INK,
			ZIndex = 81,
		}, chip)
	end

	local label = create("TextLabel", {
		Position = UDim2.fromOffset(64, options.Label and 4 or 0),
		Size = UDim2.new(1, -70, options.Label and 0.62 or 1, 0),
		BackgroundTransparency = 1,
		Font = FONT,
		Text = "x1",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 81,
	}, chip)
	create("UIStroke", { Color = INK, Thickness = 3.5 }, label)

	if options.Label then
		local caption = create("TextLabel", {
			Position = UDim2.new(0, 64, 0.62, 0),
			Size = UDim2.new(1, -70, 0.34, 0),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = options.Label,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 81,
		}, chip)
		create("UIStroke", { Color = INK, Thickness = 2.5 }, caption)
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
	local rise = Vector2.new(
		math.clamp(startPoint.X, 140, viewport.X - 140),
		math.clamp(startPoint.Y - 130, 120, viewport.Y - 120)
	)
	TweenService:Create(chipScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1.1 }):Play()
	local up = TweenService:Create(
		chip,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
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
	while true do
		local t = (os.clock() - started) / duration
		if t >= 1 then
			break
		end
		local alpha = t * t * (1.7 - 0.7 * t)
		label.Text = "x" .. compact(1 + (multiplier - 1) * alpha)
		if t >= nextTick then
			ticks += 1
			nextTick = t + math.max(0.015, tickBase * (1 - t * 0.85) / duration)
			playSound(TICK_SOUND, 0.28, 0.85 + math.min(ticks, 30) * 0.045)
		end
		chipScale.Scale = 1.1 + 0.06 * math.sin(os.clock() * 30)
		RunService.RenderStepped:Wait()
	end
	label.Text = "x" .. compact(multiplier)
	chipScale.Scale = 1.25
	TweenService:Create(chipScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.1 }):Play()
	playSound(WHOOSH_SOUND, 0.4, 1.1 + math.min(multiplier, 40) * 0.01)
	task.wait(0.22)

	-- 3) drag it into the number
	local target = options.Target
	local drag = TweenService:Create(
		chip,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.fromOffset(target.X, target.Y), GroupTransparency = 0.2 }
	)
	TweenService:Create(chipScale, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.35 }):Play()
	drag:Play()
	drag.Completed:Wait()
	chip:Destroy()
end

return MultiplierFly
