--------------------------------------------------
-- LEADERBOARD SERVICE
--
-- SERVER ONLY. Three boards in the lobby:
--   MOST WINS      (OrderedDataStore "LB_Wins_v1")
--   MOST REBIRTHS  (OrderedDataStore "LB_Rebirths_v1")
--   ROBUX SPENT    (OrderedDataStore "LB_RobuxSpent_v1", written by
--                   RobuxLedger from server-reported purchases)
--
-- The wall boards show the top 10 at a readable size. Tapping or
-- clicking a board opens the full TOP 20 as a scrollable list
-- (LeaderboardUI, client), fed by the RemoteFunction "LeaderboardData".
--
-- Wins and rebirths are read from PlayerDataService (the single source
-- of truth) and written periodically and when a player leaves.
-- The boards are Parts with SurfaceGuis built here; to move them, edit
-- BOARD_LAYOUT below (existing parts in Workspace.Leaderboards are
-- reused).
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataService = require(
	ServerScriptService
		:WaitForChild("PlayerDataLoader")
		:WaitForChild("PlayerDataService")
)

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local TOTAL_ROWS = 20      -- stored / shown in the full panel
local WALL_ROWS = 10       -- shown on the wall boards
local REFRESH_SECONDS = 90
local WRITE_SECONDS = 90

-- Lobby back wall (inner face at z = -242.3), facing +Z.
local BOARD_LAYOUT = {
	Y = 82.5,
	Z = -278.0,
	BOARD_WIDTH = 17,
	BOARD_HEIGHT = 18,
	Centers = { Wins = -88, Rebirths = -65, Robux = -42 },
}

local PIXELS_PER_STUD = 40

local INK = Color3.fromRGB(24, 22, 34)
local CREAM = Color3.fromRGB(255, 247, 232)
local LANE = Color3.fromRGB(240, 178, 82)
local PIN_RED = Color3.fromRGB(230, 70, 70)
local GOLD = Color3.fromRGB(255, 205, 70)
local SILVER = Color3.fromRGB(205, 210, 220)
local BRONZE = Color3.fromRGB(214, 140, 90)
local FONT = Enum.Font.FredokaOne

local function shortNumber(value)
	value = math.floor(tonumber(value) or 0)
	if value >= 1e12 then
		return string.format("%.1fT", value / 1e12)
	elseif value >= 1e9 then
		return string.format("%.1fB", value / 1e9)
	elseif value >= 1e6 then
		return string.format("%.2fM", value / 1e6)
	elseif value >= 1e5 then
		return string.format("%.1fK", value / 1e3)
	end
	return tostring(value)
end

local BOARDS = {
	{
		Key = "Wins",
		Title = "MOST WINS",
		Store = DataStoreService:GetOrderedDataStore("LB_Wins_v1"),
		Format = shortNumber,
		Read = function(player)
			return PlayerDataService.GetWins(player)
		end,
	},
	{
		Key = "Rebirths",
		Title = "MOST REBIRTHS",
		Store = DataStoreService:GetOrderedDataStore("LB_Rebirths_v1"),
		Format = tostring,
		Read = function(player)
			return PlayerDataService.GetRebirths(player)
		end,
	},
	{
		Key = "Robux",
		Title = "ROBUX SPENT",
		Store = DataStoreService:GetOrderedDataStore("LB_RobuxSpent_v1"),
		Format = function(value)
			return " " .. shortNumber(value)
		end,
		-- Written by RobuxLedger, never from player-reported numbers.
		Read = nil,
	},
}

local boardsByKey = {}
for _, board in ipairs(BOARDS) do
	board.Cache = {} -- { { Rank, Name, Value } ... } for the full panel
	boardsByKey[board.Key] = board
end

--------------------------------------------------
-- REMOTE (full top-20 for the panel)
--------------------------------------------------

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local dataRemote = remotes:FindFirstChild("LeaderboardData")
if not dataRemote then
	dataRemote = Instance.new("RemoteFunction")
	dataRemote.Name = "LeaderboardData"
	dataRemote.Parent = remotes
end

dataRemote.OnServerInvoke = function(_, key)
	local board = typeof(key) == "string" and boardsByKey[key]
	if not board then
		return nil
	end

	return {
		Title = board.Title,
		Entries = board.Cache,
	}
end

--------------------------------------------------
-- BOARD PARTS
--------------------------------------------------

local folder = workspace:FindFirstChild("Leaderboards")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = workspace
end

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function buildBoard(board)
	local partName = board.Key .. "Board"
	local part = folder:FindFirstChild(partName)

	if not part then
		local x = BOARD_LAYOUT.Centers[board.Key]
		local facing = CFrame.new(x, BOARD_LAYOUT.Y, BOARD_LAYOUT.Z) * CFrame.Angles(0, math.pi, 0)

		-- Frame (lane wood) BEHIND the screen (local +Z is away from the lobby)
		create("Part", {
			Name = partName .. "Frame",
			Anchored = true,
			CanCollide = false,
			Material = Enum.Material.WoodPlanks,
			Color = LANE,
			Size = Vector3.new(BOARD_LAYOUT.BOARD_WIDTH + 1, BOARD_LAYOUT.BOARD_HEIGHT + 1, 0.5),
			CFrame = facing * CFrame.new(0, 0, 0.35),
		}, folder)

		part = create("Part", {
			Name = partName,
			Anchored = true,
			CanCollide = false,
			Material = Enum.Material.SmoothPlastic,
			Color = INK,
			Size = Vector3.new(BOARD_LAYOUT.BOARD_WIDTH, BOARD_LAYOUT.BOARD_HEIGHT, 0.4),
			CFrame = facing,
		}, folder)
	end

	-- Rebuild the screen every start so the layout is always current.
	local old = part:FindFirstChild("Screen")
	if old then
		old:Destroy()
	end

	local height = BOARD_LAYOUT.BOARD_HEIGHT * PIXELS_PER_STUD
	local headerHeight = 76
	local footerHeight = 40

	local gui = create("SurfaceGui", {
		Name = "Screen",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PIXELS_PER_STUD,
		LightInfluence = 0,
		Brightness = 1.2,
	}, part)

	local root = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
	}, gui)

	local header = create("Frame", {
		Size = UDim2.new(1, 0, 0, headerHeight),
		BackgroundColor3 = PIN_RED,
		BorderSizePixel = 0,
	}, root)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = board.Title,
		TextColor3 = CREAM,
		TextSize = 44,
	}, header)

	local list = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, headerHeight + 2),
		Size = UDim2.new(1, 0, 1, -(headerHeight + footerHeight + 2)),
	}, root)

	create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)

	local rowHeight = (height - headerHeight - footerHeight - 2) / WALL_ROWS
	local rows = {}

	for index = 1, WALL_ROWS do
		local row = create("Frame", {
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, rowHeight),
			BackgroundColor3 = (index % 2 == 0) and Color3.fromRGB(40, 38, 58) or Color3.fromRGB(32, 30, 46),
			BorderSizePixel = 0,
		}, list)

		local rankColor = index == 1 and GOLD or index == 2 and SILVER or index == 3 and BRONZE or CREAM

		create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.fromOffset(64, rowHeight),
			Font = FONT,
			Text = "#" .. index,
			TextColor3 = rankColor,
			TextSize = 26,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)

		local name = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(80, 0),
			Size = UDim2.new(1, -240, 1, 0),
			Font = FONT,
			Text = "-",
			TextColor3 = rankColor,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, row)

		local value = create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			Size = UDim2.fromOffset(150, rowHeight),
			Font = FONT,
			Text = "",
			TextColor3 = rankColor,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)

		rows[index] = { Name = name, Value = value }
	end

	create("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, footerHeight),
		BackgroundColor3 = LANE,
		BorderSizePixel = 0,
		Font = FONT,
		Text = "TAP FOR TOP 20",
		TextColor3 = INK,
		TextSize = 24,
	}, root)

	board.Rows = rows
end

for _, board in ipairs(BOARDS) do
	buildBoard(board)
end

--------------------------------------------------
-- NAMES
--------------------------------------------------

local nameCache = {}

local function getName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	nameCache[userId] = ok and name or ("Player " .. tostring(userId))
	return nameCache[userId]
end

--------------------------------------------------
-- READ (refresh the boards)
--------------------------------------------------

local function refreshBoard(board)
	local ok, pages = pcall(function()
		return board.Store:GetSortedAsync(false, TOTAL_ROWS)
	end)

	if not ok then
		warn("[LeaderboardService] Read failed:", board.Key, pages)
		return
	end

	local okPage, entries = pcall(function()
		return pages:GetCurrentPage()
	end)

	if not okPage then
		return
	end

	local cache = {}

	for index = 1, TOTAL_ROWS do
		local entry = entries[index]

		if entry and entry.value > 0 then
			local userId = tonumber(entry.key)
			local name = userId and getName(userId) or tostring(entry.key)

			cache[index] = {
				Rank = index,
				UserId = userId,
				Name = name,
				Value = board.Format(entry.value),
			}
		end
	end

	board.Cache = cache

	for index = 1, WALL_ROWS do
		local row = board.Rows[index]
		local entry = cache[index]

		if entry then
			row.Name.Text = entry.Name
			row.Value.Text = entry.Value
		else
			row.Name.Text = "-"
			row.Value.Text = ""
		end
	end
end

task.spawn(function()
	while true do
		for _, board in ipairs(BOARDS) do
			refreshBoard(board)
			task.wait(2) -- stay well inside DataStore request budgets
		end

		task.wait(REFRESH_SECONDS)
	end
end)

--------------------------------------------------
-- WRITE (wins / rebirths of players currently here)
--------------------------------------------------

local lastWritten = {} -- [userId .. board key] = value

local function writePlayer(player)
	if not PlayerDataService.GetData(player) then
		return -- data not loaded: never write zeros over a real score
	end

	for _, board in ipairs(BOARDS) do
		if board.Read then
			local value = math.max(0, math.floor(board.Read(player)))
			local key = tostring(player.UserId) .. board.Key

			if value > 0 and lastWritten[key] ~= value then
				local ok, err = pcall(function()
					board.Store:SetAsync(tostring(player.UserId), value)
				end)

				if ok then
					lastWritten[key] = value
				else
					warn("[LeaderboardService] Write failed:", player.Name, board.Key, err)
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(WRITE_SECONDS)

		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(writePlayer, player)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	writePlayer(player)
end)

print("[LeaderboardService] READY | boards:", #BOARDS, "| wall rows:", WALL_ROWS, "| full:", TOTAL_ROWS)
