--------------------------------------------------
-- WORLDS UI (CLIENT)
--
-- WORLDS menu (TELEPORT / YOU'RE HERE / LOCKED), opened from the World Machine, hides world copies
-- the player has not unlocked, tints the lighting to the current world's
-- theme, shows a smooth arrow + guide line to a newly unlocked world's portal,
-- and a short branded transition when changing worlds. The server
-- (WorldService) validates every move; this only asks and displays.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local worldTeleport = remotes:WaitForChild("WorldTeleport")
local worldNotice = remotes:WaitForChild("WorldNotice")

local INK = Color3.fromRGB(24, 22, 34)
local FONT = Enum.Font.FredokaOne

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function rebirths()
	return player:GetAttribute("Rebirths") or 0
end
local function currentWorld()
	return player:GetAttribute("World") or 1
end

--------------------------------------------------
-- GUI
--------------------------------------------------

local old = playerGui:FindFirstChild("WorldsUI")
if old then
	old:Destroy()
end
local gui = create("ScreenGui", { Name = "WorldsUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 19 }, playerGui)

local panel = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(560, 470),
	BackgroundColor3 = Color3.fromRGB(28, 34, 52),
	Visible = false,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, panel)
create("UIStroke", { Color = INK, Thickness = 4 }, panel)
local panelScale = create("UIScale", {}, panel)
local function fit()
	local size = gui.AbsoluteSize
	panelScale.Scale = math.clamp(math.min((size.X - 24) / 560, (size.Y - 24) / 470), 0.5, 1.2)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

local header = create("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Color3.fromRGB(40, 200, 245) }, panel)
create("UICorner", { CornerRadius = UDim.new(0, 18) }, header)
create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(120, 235, 255), Color3.fromRGB(20, 160, 230)) }, header)
local title = create("TextLabel", {
	Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -90, 1, 0), BackgroundTransparency = 1,
	Font = FONT, Text = "WORLDS!", TextColor3 = Color3.new(1, 1, 1), TextSize = 40, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
create("UIStroke", { Color = INK, Thickness = 3 }, title)
local close = create("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(52, 48),
	BackgroundColor3 = Color3.fromRGB(225, 45, 50), Font = FONT, Text = "X", TextColor3 = Color3.new(1, 1, 1), TextSize = 34,
}, header)
create("UICorner", { CornerRadius = UDim.new(0, 10) }, close)
create("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, close)

local list = create("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 1, -90), BackgroundTransparency = 1,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, BorderSizePixel = 0,
}, panel)
create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, list)

local ROW_COLORS = {
	{ Color3.fromRGB(190, 255, 90), Color3.fromRGB(40, 200, 60) },
	{ Color3.fromRGB(215, 235, 255), Color3.fromRGB(70, 160, 240) },
	{ Color3.fromRGB(255, 240, 120), Color3.fromRGB(240, 140, 20) },
	{ Color3.fromRGB(235, 200, 255), Color3.fromRGB(130, 70, 230) },
}

local rows = {}
for _, world in ipairs(WorldConfig.Worlds) do
	local row = create("Frame", { LayoutOrder = world.Id, Size = UDim2.new(1, -8, 0, 100), BackgroundColor3 = Color3.new(1, 1, 1) }, list)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, row)
	create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, row)
	local colors = ROW_COLORS[world.Id] or ROW_COLORS[1]
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(colors[1], colors[2]) }, row)
	local name = create("TextLabel", {
		Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -210, 0, 44), BackgroundTransparency = 1,
		Font = FONT, Text = world.Name, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	create("UIStroke", { Color = INK, Thickness = 3 }, name)
	local need = create("TextLabel", {
		Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -210, 0, 30), BackgroundTransparency = 1,
		Font = FONT, Text = world.Rebirths > 0 and (world.Rebirths .. " REBIRTHS REQUIRED") or "STARTING WORLD",
		TextColor3 = Color3.fromRGB(255, 80, 90), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	create("UIStroke", { Color = INK, Thickness = 2 }, need)
	local button = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(170, 58),
		BackgroundColor3 = Color3.fromRGB(60, 210, 70), Font = FONT, Text = "TELEPORT", TextColor3 = Color3.new(1, 1, 1), TextScaled = true,
	}, row)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
	create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, button)
	create("UIStroke", { Color = INK, Thickness = 2 }, button)
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, button)
	button.Activated:Connect(function()
		if button.Text == "TELEPORT" then
			worldTeleport:FireServer(world.Id)
			panel.Visible = false
		end
	end)
	rows[world.Id] = button
end

local function refreshRows()
	for id, button in pairs(rows) do
		if id == currentWorld() then
			button.Text, button.BackgroundColor3 = "YOU'RE HERE", Color3.fromRGB(255, 190, 40)
		elseif WorldConfig.Unlocked(rebirths(), id) then
			button.Text, button.BackgroundColor3 = "TELEPORT", Color3.fromRGB(60, 210, 70)
		else
			button.Text, button.BackgroundColor3 = "LOCKED", Color3.fromRGB(225, 45, 50)
		end
	end
end

-- opened by rolling onto the World Machine in the lobby (WorldService says so)
local function openMenu()
	refreshRows()
	panel.Visible = true
end
close.Activated:Connect(function()
	panel.Visible = false
end)

--------------------------------------------------
-- HIDE LOCKED WORLDS + THEMED LIGHTING
--------------------------------------------------

local hidden = {} -- [id] = folder kept out of the workspace on this client
local worldsFolder = workspace:WaitForChild("Worlds", 60)

local function refreshVisibility()
	if not worldsFolder then
		return
	end
	for _, world in ipairs(WorldConfig.Worlds) do
		local folder = hidden[world.Id] or worldsFolder:FindFirstChild("World" .. world.Id)
		if folder then
			-- only the world you are in is shown (other worlds and their courses stay hidden)
			local balls = workspace:FindFirstChild("PlayerBalls")
			local ball = balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
			local underBall = ball and WorldConfig.AtPosition(ball.Position).Id == world.Id
			if world.Id == currentWorld() or underBall then
				if folder.Parent ~= worldsFolder then
					folder.Parent = worldsFolder
				end
				hidden[world.Id] = nil
			else
				hidden[world.Id] = folder
				folder.Parent = nil
			end
		end
	end
end
if worldsFolder then
	worldsFolder.ChildAdded:Connect(function()
		task.defer(refreshVisibility)
	end)
end

local baseLighting = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
local tint = Lighting:FindFirstChild("WorldTint") or Instance.new("ColorCorrectionEffect")
tint.Name = "WorldTint"
tint.Parent = Lighting

local function applyTheme()
	local world = WorldConfig.Get(currentWorld())
	local info = TweenInfo.new(1.2)
	if world.Theme then
		TweenService:Create(Lighting, info, { Ambient = world.Theme.Ambient, OutdoorAmbient = world.Theme.Ambient }):Play()
		TweenService:Create(tint, info, { TintColor = world.Theme.Tint, Saturation = 0.08 }):Play()
	else
		TweenService:Create(Lighting, info, baseLighting):Play()
		TweenService:Create(tint, info, { TintColor = Color3.new(1, 1, 1), Saturation = 0 }):Play()
	end
end

--------------------------------------------------
-- ARROW TO A NEWLY UNLOCKED WORLD'S PORTAL (smooth, RenderStepped)
--------------------------------------------------

local arrowClear = nil
local function showArrowTo(targetId)
	if arrowClear then
		arrowClear()
	end
	if not worldsFolder then
		return
	end
	local here = currentWorld()
	local searchIn = here == 1 and worldsFolder or worldsFolder:FindFirstChild("World" .. here)
	local portal = searchIn and searchIn:FindFirstChild("Portal_To_" .. targetId)
	local core = portal and portal:FindFirstChild("Core")
	if not core then
		return
	end
	local parts = {}
	local bb = create("BillboardGui", { Size = UDim2.fromOffset(90, 110), AlwaysOnTop = true, Adornee = core }, playerGui)
	local arrow = create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = FONT, Text = "V", TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 214, 70),
	}, bb)
	create("UIStroke", { Color = INK, Thickness = 4 }, arrow)
	table.insert(parts, bb)
	local a1 = create("Attachment", {}, core)
	local beam = create("Beam", {
		Color = ColorSequence.new(Color3.fromRGB(255, 214, 70)), LightEmission = 1, Width0 = 0.7, Width1 = 0.7,
		FaceCamera = true, Attachment1 = a1, Transparency = NumberSequence.new(0.15),
	}, core)
	table.insert(parts, a1)
	table.insert(parts, beam)
	local a0 = nil
	local started = os.clock()
	local conn
	local function clear()
		conn:Disconnect()
		for _, p in ipairs(parts) do
			p:Destroy()
		end
		arrowClear = nil
	end
	conn = RunService.RenderStepped:Connect(function()
		bb.StudsOffsetWorldSpace = Vector3.new(0, 8 + math.sin(os.clock() * 4) * 1.2, 0)
		local balls = workspace:FindFirstChild("PlayerBalls")
		local ball = balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
		if ball and (not a0 or a0.Parent ~= ball) then
			a0 = create("Attachment", {}, ball)
			table.insert(parts, a0)
			beam.Attachment0 = a0
		end
		if currentWorld() == targetId or os.clock() - started > 180 or not core.Parent then
			clear()
		end
	end)
	arrowClear = clear
end

--------------------------------------------------
-- ARROW TO THE BOWLING SHOP (after every world teleport; cleared when the
-- shop opens - the shop's own pad fires Remotes.OpenBowlingShop)
--------------------------------------------------

local shopArrowClear = nil
local function showShopArrow()
	if shopArrowClear then
		shopArrowClear()
	end
	local id = currentWorld()
	local root = id == 1 and workspace or (worldsFolder and worldsFolder:FindFirstChild("World" .. id))
	local shop = root and root:FindFirstChild("BowlingShop")
	local pad = shop and shop:FindFirstChild("BallShopInteractionPoint")
	if not pad or not pad:IsA("BasePart") then
		return
	end
	local parts = {}
	local bb = create("BillboardGui", { Size = UDim2.fromOffset(80, 100), AlwaysOnTop = true, Adornee = pad }, playerGui)
	local arrow = create("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = FONT, Text = "V", TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 214, 70),
	}, bb)
	create("UIStroke", { Color = INK, Thickness = 4 }, arrow)
	table.insert(parts, bb)
	local a1 = create("Attachment", {}, pad)
	local beam = create("Beam", {
		Color = ColorSequence.new(Color3.fromRGB(255, 214, 70)), LightEmission = 1, Width0 = 0.7, Width1 = 0.7,
		FaceCamera = true, Attachment1 = a1, Transparency = NumberSequence.new(0.15),
	}, pad)
	table.insert(parts, a1)
	table.insert(parts, beam)
	local a0 = nil
	local started = os.clock()
	local conn
	local function clear()
		conn:Disconnect()
		for _, p in ipairs(parts) do
			p:Destroy()
		end
		shopArrowClear = nil
	end
	conn = RunService.RenderStepped:Connect(function()
		bb.StudsOffsetWorldSpace = Vector3.new(0, 7 + math.sin(os.clock() * 4) * 1.2, 0)
		local balls = workspace:FindFirstChild("PlayerBalls")
		local ball = balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
		if ball and (not a0 or a0.Parent ~= ball) then
			a0 = create("Attachment", {}, ball)
			table.insert(parts, a0)
			beam.Attachment0 = a0
		end
		if currentWorld() ~= id or os.clock() - started > 120 or not pad.Parent then
			clear()
		end
	end)
	shopArrowClear = clear
end

remotes:WaitForChild("OpenBowlingShop").OnClientEvent:Connect(function()
	if shopArrowClear then
		shopArrowClear()
	end
end)

--------------------------------------------------
-- NOTICES + TRANSITION
--------------------------------------------------

local toast = create("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(460, 50),
	BackgroundColor3 = Color3.fromRGB(35, 37, 39), Font = Enum.Font.GothamBold, TextSize = 18,
	TextColor3 = Color3.new(1, 1, 1), Text = "", TextWrapped = true,
}, gui)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, toast)
create("UIStroke", { Color = Color3.fromRGB(255, 200, 70), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, toast)
local toastToken = 0
local function showToast(text)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 70) }):Play()
	task.delay(3.5, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) }):Play()
		end
	end)
end

worldNotice.OnClientEvent:Connect(function(kind, data)
	if kind == "OpenMenu" then
		openMenu()
	elseif kind == "Locked" and typeof(data) == "table" then
		showToast(string.format("%s needs %d rebirths (you have %d).", WorldConfig.Get(data.World).Name, data.Need or 0, data.Have or 0))
	elseif kind == "Entered" and typeof(data) == "table" and data.Reason ~= "Join" then
		task.delay(1, showShopArrow)
		local module = ReplicatedFirst:FindFirstChild("LoadingScreen")
		if module then
			local LS = require(module)
			local screen = LS.Build("Entering " .. WorldConfig.Get(data.World).Name .. "...")
			screen.Parent = playerGui
			LS.Animate(screen)
			task.delay(0.45, function()
				LS.FadeOut(screen, 0.35)
			end)
		end
	end
end)

local lastRebirths = rebirths()
player:GetAttributeChangedSignal("Rebirths"):Connect(function()
	local now = rebirths()
	for _, world in ipairs(WorldConfig.Worlds) do
		if world.Id > 1 and lastRebirths < world.Rebirths and now >= world.Rebirths then
			showToast(world.Name .. " UNLOCKED! Follow the arrow to its portal.")
			task.delay(1, function()
				showArrowTo(world.Id)
			end)
		end
	end
	lastRebirths = now
	refreshVisibility()
	refreshRows()
end)
player:GetAttributeChangedSignal("World"):Connect(function()
	refreshVisibility()
	applyTheme()
	refreshRows()
end)

refreshVisibility()
applyTheme()
refreshRows()

-- keep it right through moves, joins and respawns
task.spawn(function()
	while true do
		task.wait(0.3)
		refreshVisibility()
	end
end)