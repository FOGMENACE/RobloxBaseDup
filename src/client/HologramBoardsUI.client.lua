--------------------------------------------------
-- HOLOGRAM BOARDS UI (CLIENT, visual only)
--
-- Draws the three top-20 lists (MOST WINS / MOST REBIRTHS / ROBUX SPENT) on
-- every HoloScreen part (the lobby and its themed copies) built by the server
-- script HologramBoards. Data comes from Remotes.LeaderboardData, the same
-- read-only source as the wall boards. Each list shows the top 8 and scrolls
-- (mouse wheel / finger drag) for the rest; no clicking needed.
-- A light glitch (jitter, flicker, a sweeping scan bar) and flickering beams
-- make it read as a projected hologram.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local dataRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LeaderboardData")

local BOARDS = {
	{ Key = "Wins", Title = "MOST WINS", Color = Color3.fromRGB(255, 205, 70) },
	{ Key = "Rebirths", Title = "MOST REBIRTHS", Color = Color3.fromRGB(255, 90, 90) },
	{ Key = "Robux", Title = "ROBUX SPENT", Color = Color3.fromRGB(110, 240, 130) },
}
local ROWS, VISIBLE_ROWS = 20, 8
local REFRESH_SECONDS = 60
local SCREEN_PIXELS_HIGH = 350 -- every screen is drawn 350 px high, whatever its size in studs
local LIST_HEIGHT = SCREEN_PIXELS_HIGH - 20 - 48 -- screen height minus padding and header
local ROW_HEIGHT = math.floor(LIST_HEIGHT / VISIBLE_ROWS)
local FONT = Enum.Font.FredokaOne

local CYAN = Color3.fromRGB(110, 230, 255)
local WHITE = Color3.fromRGB(235, 252, 255)
local RANK_COLORS = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(215, 225, 240), Color3.fromRGB(235, 160, 110) }

local screens = {} -- [part] = { Gui, Content, Columns, Scan, Lists = { [key] = rows } }
local latest = {} -- [key] = entries

local function create(className, props, parent)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function fill(rows, entries)
	for index, row in ipairs(rows) do
		local entry = entries and entries[index]
		row.Name.Text = entry and entry.Name or "-"
		row.Avatar.Image = (entry and entry.UserId) and ("rbxthumb://type=AvatarHeadShot&id=" .. entry.UserId .. "&w=48&h=48") or ""
		row.Avatar.Visible = entry ~= nil and entry.UserId ~= nil
		row.Value.Text = entry and tostring(entry.Value) or ""
		local mine = entry ~= nil and entry.UserId == player.UserId
		row.Frame.BackgroundTransparency = mine and 0.55 or (index % 2 == 0 and 0.9 or 1)
	end
end

local function buildScreen(part)
	if screens[part] then
		return
	end
	local gui = create("SurfaceGui", {
		Name = "HoloBoards",
		Adornee = part,
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		-- drawn at twice the layout resolution (see the UIScale below) so the text
		-- stays sharp from across the room
		PixelsPerStud = SCREEN_PIXELS_HIGH * 2 / part.Size.Y,
		LightInfluence = 0,
		Brightness = 1.6,
		AlwaysOnTop = false,
		MaxDistance = 140,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	-- faint projected glass + border (the "light" of the hologram)
	local content = create("Frame", {
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(16, 70, 120),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, gui)
	create("UIScale", { Scale = 2 }, content)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, content)
	create("UIStroke", { Color = CYAN, Thickness = 3, Transparency = 0.25 }, content)

	-- scanlines
	for y = 0, 0.96, 0.05 do
		create("Frame", {
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = CYAN,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, content)
	end

	local scan = create("Frame", {
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		ZIndex = 6,
	}, content)

	local columns = create("Frame", {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 1, -20),
		BackgroundTransparency = 1,
	}, content)
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, columns)

	local lists = {}
	for order, board in ipairs(BOARDS) do
		local column = create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1 / 3, -8, 1, 0),
			BackgroundColor3 = Color3.fromRGB(8, 30, 60),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
		}, columns)
		create("UICorner", { CornerRadius = UDim.new(0, 12) }, column)
		create("UIStroke", { Color = CYAN, Thickness = 1.5, Transparency = 0.45 }, column)

		local header = create("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			Font = FONT,
			Text = board.Title,
			TextColor3 = board.Color,
			TextSize = 26,
		}, column)
		create("UIStroke", { Color = Color3.fromRGB(0, 120, 170), Thickness = 2 }, header)

		local scroller = create("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 42),
			Size = UDim2.new(1, 0, 1, -48),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = CYAN,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = UDim2.fromOffset(0, ROWS * ROW_HEIGHT),
			Active = true,
		}, column)
		create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, scroller)

		local rows = {}
		for index = 1, ROWS do
			local frame = create("Frame", {
				LayoutOrder = index,
				Size = UDim2.new(1, -8, 0, ROW_HEIGHT),
				BackgroundColor3 = CYAN,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, scroller)
			create("UICorner", { CornerRadius = UDim.new(0, 6) }, frame)
			create("TextLabel", {
				Size = UDim2.new(0, 38, 1, 0),
				BackgroundTransparency = 1,
				Font = FONT,
				Text = "#" .. index,
				TextColor3 = RANK_COLORS[index] or CYAN,
				TextSize = 18,
			}, frame)
			local avatar = create("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 40, 0.5, 0),
				Size = UDim2.fromOffset(ROW_HEIGHT - 8, ROW_HEIGHT - 8),
				BackgroundColor3 = Color3.fromRGB(20, 60, 100),
				BackgroundTransparency = 0.2,
				Image = "",
				Visible = false,
			}, frame)
			create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, avatar)
			create("UIStroke", { Color = RANK_COLORS[index] or CYAN, Thickness = 1.5, Transparency = 0.2 }, avatar)
			local name = create("TextLabel", {
				Position = UDim2.fromOffset(40 + ROW_HEIGHT - 2, 0),
				Size = UDim2.new(1, -(116 + ROW_HEIGHT - 2), 1, 0),
				BackgroundTransparency = 1,
				Font = FONT,
				Text = "-",
				TextColor3 = WHITE,
				TextSize = 17,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, frame)
			local value = create("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -4, 0, 0),
				Size = UDim2.new(0, 72, 1, 0),
				BackgroundTransparency = 1,
				Font = FONT,
				Text = "",
				TextColor3 = RANK_COLORS[index] or CYAN,
				TextSize = 17,
				TextXAlignment = Enum.TextXAlignment.Right,
			}, frame)
			rows[index] = { Frame = frame, Avatar = avatar, Name = name, Value = value }
		end
		lists[board.Key] = rows
		fill(rows, latest[board.Key])
	end

	screens[part] = { Gui = gui, Content = content, Columns = columns, Scan = scan, Lists = lists }
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			gui:Destroy()
			screens[part] = nil
		end
	end)
end

local function isScreen(d)
	return d.Name == "HoloScreen" and d:IsA("BasePart")
end

workspace.DescendantAdded:Connect(function(d)
	if isScreen(d) then
		task.defer(buildScreen, d)
	end
end)
for _, d in ipairs(workspace:GetDescendants()) do
	if isScreen(d) then
		buildScreen(d)
	end
end

-- data (read only; same source as the wall boards)
task.spawn(function()
	while true do
		for _, board in ipairs(BOARDS) do
			local ok, data = pcall(function()
				return dataRemote:InvokeServer(board.Key)
			end)
			if ok and typeof(data) == "table" and typeof(data.Entries) == "table" then
				latest[board.Key] = data.Entries
				for _, screen in pairs(screens) do
					fill(screen.Lists[board.Key], data.Entries)
				end
			end
		end
		-- the server fills its cache a few seconds after start: ask again soon until it has rows
		task.wait((latest.Wins and #latest.Wins > 0) and REFRESH_SECONDS or 5)
	end
end)

-- glitch: scan bar sweep, faint flicker, and now and then a quick sideways jitter
local beams = {}
for _, b in ipairs(CollectionService:GetTagged("HoloBeam")) do
	beams[b] = true
end
CollectionService:GetInstanceAddedSignal("HoloBeam"):Connect(function(b)
	beams[b] = true
end)

local nextGlitch, glitchUntil, glitchOffset = os.clock() + 2, 0, 0
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if now > nextGlitch then
		glitchUntil = now + 0.12
		glitchOffset = math.random(-7, 7)
		nextGlitch = now + 2 + math.random() * 3
	end
	local glitching = now < glitchUntil

	for _, screen in pairs(screens) do
		screen.Scan.Position = UDim2.fromScale(0, (now * 0.35) % 1)
		screen.Columns.Position = UDim2.fromOffset(12 + (glitching and glitchOffset or 0), 10)
		screen.Content.BackgroundTransparency = glitching and 0.65 or (0.45 + math.sin(now * 9) * 0.03)
	end

	for beam in pairs(beams) do
		if not beam.Parent then
			beams[beam] = nil
		else
			local index = beam:GetAttribute("BeamIndex") or 1
			local flicker = math.sin(now * 13 + index * 2.1) * 0.12 + (glitching and 0.3 or 0)
			beam.Transparency = math.clamp(0.45 + flicker, 0.2, 0.9)
		end
	end
end)
