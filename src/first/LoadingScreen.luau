--------------------------------------------------
-- LOADING SCREEN (ReplicatedFirst, client)
--
-- One branded screen used for every join, the AFK rejoin and server moves:
-- the welcome thumbnail (or the game's purple sky gradient when no image id
-- is set yet), a soft dark fade at the bottom, the title, floating "+1"s and
-- a status line. Build(status) returns the ScreenGui (not parented), so it can
-- be shown here or handed to TeleportService:SetTeleportGui.
--------------------------------------------------

local LoadingScreen = {}

-- Thumbnail art (FOGMENACE group images). The screen always uses this one image
-- (it used to rotate at random between three). Empty list = purple sky gradient only.
LoadingScreen.IMAGES = {
	"rbxassetid://117374859939690", -- Neon Skyway Oil Barrel Challenge
}

local function make(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

function LoadingScreen.Build(status)
	local gui = make("ScreenGui", {
		Name = "OilLoadingScreen",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 1000,
	})
	pcall(function()
		gui.ScreenInsets = Enum.ScreenInsets.None
	end)

	local bg = make("Frame", { Name = "Background", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, gui)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(88, 70, 214)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(196, 110, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 200)),
		}),
	}, bg)

	if #LoadingScreen.IMAGES > 0 then
		make("ImageLabel", {
			Name = "Art",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = LoadingScreen.IMAGES[math.random(1, #LoadingScreen.IMAGES)],
			ScaleType = Enum.ScaleType.Crop,
			ImageTransparency = 0.12,
		}, bg)
	end

	-- gradient fade so the text reads and the art blends into the screen
	local fade = make("Frame", { Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 12, 46), BorderSizePixel = 0 }, bg)
	make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.45, 0.85),
			NumberSequenceKeypoint.new(0.7, 0.45),
			NumberSequenceKeypoint.new(1, 0.05),
		}),
	}, fade)

	-- floating +1s
	local spots = { { 0.08, 0.2, 46, -12 }, { 0.88, 0.16, 54, 10 }, { 0.16, 0.62, 38, 8 }, { 0.84, 0.58, 42, -8 }, { 0.52, 0.1, 30, 6 } }
	for i, s in ipairs(spots) do
		local plus = make("TextLabel", {
			Name = "PlusOne",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(s[1], s[2]),
			Size = UDim2.fromOffset(120, 70),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Text = "+1",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = s[3],
			Rotation = s[4],
			TextTransparency = 0.1,
		}, gui)
		plus:SetAttribute("Phase", i * 1.3)
		make("UIStroke", { Color = Color3.fromRGB(30, 20, 60), Thickness = 3 }, plus)
	end

	local title = make("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.new(0.9, 0, 0, 80),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Text = "STRIKE OIL!",
		TextColor3 = Color3.fromRGB(255, 214, 70),
		TextScaled = true,
	}, gui)
	make("UITextSizeConstraint", { MaxTextSize = 72 }, title)
	make("UIStroke", { Color = Color3.fromRGB(30, 20, 60), Thickness = 4 }, title)

	-- retro arcade progress line, slightly see-through: "LOADING DATA...  47%"
	local load = make("TextLabel", {
		Name = "LoadText",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -98),
		Size = UDim2.new(0.9, 0, 0, 44),
		BackgroundTransparency = 1,
		Font = Enum.Font.Arcade,
		Text = "LOADING DATA",
		TextColor3 = Color3.fromRGB(255, 214, 70),
		TextScaled = true,
		TextTransparency = 0.25,
	}, gui)
	make("UITextSizeConstraint", { MaxTextSize = 40 }, load)
	make("UIStroke", { Color = Color3.fromRGB(30, 20, 60), Thickness = 3, Transparency = 0.35 }, load)

	make("TextLabel", {
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		Size = UDim2.new(0.9, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Text = status or "Loading...",
		TextColor3 = Color3.fromRGB(240, 236, 255),
		TextSize = 20,
	}, gui)

	-- three bouncing dots
	local dots = make("Frame", { Name = "Dots", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -32), Size = UDim2.fromOffset(84, 18), BackgroundTransparency = 1 }, gui)
	for i = 1, 3 do
		local d = make("Frame", { Name = "Dot", Position = UDim2.fromOffset((i - 1) * 32, 4), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.fromRGB(255, 214, 70), BorderSizePixel = 0 }, dots)
		d:SetAttribute("Phase", i * 0.6)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
	end

	return gui
end

-- The status line.
function LoadingScreen.SetStatus(gui, text)
	local label = gui and gui:FindFirstChild("Status", true)
	if label then
		label.Text = text
	end
end

-- Loading progress for the "LOADING DATA  %" line. The number moves smoothly from
-- `from` toward `to` while a step is waiting (slowing near `to`, never passing it),
-- then the next Step continues from there. Screens that never call this (world
-- moves, server moves) fill up slowly by themselves.
function LoadingScreen.Step(gui, from, to)
	gui:SetAttribute("ProgFrom", from)
	gui:SetAttribute("ProgTo", to)
	gui:SetAttribute("ProgStart", os.clock())
end

-- Animates +1s, dots and the progress line while the gui is parented; stops by itself after.
function LoadingScreen.Animate(gui)
	local RunService = game:GetService("RunService")
	local load = gui:FindFirstChild("LoadText")
	local born = os.clock()
	local shown = 0
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not gui.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock()

		local from, to = gui:GetAttribute("ProgFrom"), gui:GetAttribute("ProgTo")
		local target
		if typeof(from) == "number" and typeof(to) == "number" then
			local since = t - (gui:GetAttribute("ProgStart") or t)
			target = (to >= 1) and 1 or from + (to - from) * (1 - math.exp(-since / 2.5)) * 0.92
		else
			target = 0.92 * (1 - math.exp(-(t - born) / 3))
		end
		shown += (target - shown) * math.min(1, dt * 4)
		if target >= 1 and shown > 0.995 then
			shown = 1
		end
		gui:SetAttribute("ProgShown", shown)
		if load then
			local ticks = string.rep(".", math.floor(t * 3) % 4)
			load.Text = string.format("LOADING DATA%-3s  %d%%", ticks, math.floor(shown * 100 + 0.5))
		end

		for _, c in ipairs(gui:GetChildren()) do
			if c.Name == "PlusOne" then
				local p = c:GetAttribute("Phase") or 0
				c.Position = UDim2.new(c.Position.X.Scale, 0, c.Position.Y.Scale, math.sin(t * 1.6 + p) * 10)
			end
		end
		local dots = gui:FindFirstChild("Dots")
		if dots then
			for _, d in ipairs(dots:GetChildren()) do
				local p = d:GetAttribute("Phase") or 0
				d.Position = UDim2.fromOffset(d.Position.X.Offset, 4 - math.max(0, math.sin(t * 6 - p)) * 8)
			end
		end
	end)
end

-- Fades every element out, then destroys the gui.
function LoadingScreen.FadeOut(gui, seconds)
	local TweenService = game:GetService("TweenService")
	local info = TweenInfo.new(seconds or 0.6)
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("Frame") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		elseif d:IsA("ImageLabel") then
			TweenService:Create(d, info, { ImageTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
	task.delay((seconds or 0.6) + 0.05, function()
		gui:Destroy()
	end)
end

return LoadingScreen