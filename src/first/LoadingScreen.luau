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

-- Thumbnail art (FOGMENACE group images). One is picked at random per screen;
-- add more ids here to rotate them. Empty list = purple sky gradient only.
LoadingScreen.IMAGES = {
	"rbxassetid://117374859939690", -- Neon Skyway Oil Barrel Challenge
	"rbxassetid://76074930356028", -- Neon Bowling Ball Scoreboards
	"rbxassetid://94774229870375",
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
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0.9, 0, 0, 80),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Text = "+1 OIL BOWLING",
		TextColor3 = Color3.fromRGB(255, 214, 70),
		TextScaled = true,
	}, gui)
	make("UITextSizeConstraint", { MaxTextSize = 72 }, title)
	make("UIStroke", { Color = Color3.fromRGB(30, 20, 60), Thickness = 4 }, title)

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

-- Animates +1s and dots while the gui is parented; stops by itself after.
function LoadingScreen.Animate(gui)
	local RunService = game:GetService("RunService")
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not gui.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock()
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