--------------------------------------------------
-- GUTTER SERVICE
--
-- SERVER ONLY. The oil course lane has two gutters (strips along its
-- side edges). While a player is RUNNING and their ball rolls into a
-- gutter, they lose a share of the oil collected so far:
--
--     penalty fraction = pinsStillStanding / totalPins
--
-- where the course has one "pin" per row, and a gutter in row N leaves
-- (totalRows - N) pins standing. With 12 rows: row 1 = 11/12 (huge),
-- row 8 = 4/12 (a third), row 12 = nothing.
--
-- Each row can penalise a run only once (staying in a gutter does not
-- keep draining oil), with a short cooldown on top.
--
-- Everything is computed here from the ball's real position and the
-- player's real CurrentOil; the client only gets a notification to
-- display. Oil accounting follows OilCollectionService: the lifetime
-- total (PlayerDataService) is reduced by the amount actually removed,
-- and the CurrentOil ATTRIBUTE is this run's oil.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = require(
	ServerScriptService
		:WaitForChild("PlayerDataLoader")
		:WaitForChild("PlayerDataService")
)

local GUTTER_WIDTH = 2.6      -- studs of each side strip
local CHECK_INTERVAL = 0.1
local COOLDOWN = 1.5          -- seconds between penalties

local course = workspace:WaitForChild("Course")
local leftBoundary = course:WaitForChild("LeftBoundary")
local rightBoundary = course:WaitForChild("RightBoundary")
local startWall = workspace:WaitForChild("StartWall")
local finishWall = workspace:WaitForChild("FinishWall")
local floorPart = course:WaitForChild("Floor")
local playerBalls = workspace:WaitForChild("PlayerBalls")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local gutterRemote = remotes:FindFirstChild("GutterPenalty")
if not gutterRemote then
	gutterRemote = Instance.new("RemoteEvent")
	gutterRemote.Name = "GutterPenalty"
	gutterRemote.Parent = remotes
end

--------------------------------------------------
-- LANE GEOMETRY
--------------------------------------------------

local laneCenterX = (leftBoundary.Position.X + rightBoundary.Position.X) / 2
local laneHalfWidth = math.abs(leftBoundary.Position.X - rightBoundary.Position.X) / 2
local gutterEdge = laneHalfWidth - GUTTER_WIDTH -- |dx| beyond this is "in the gutter"

--------------------------------------------------
-- VISIBLE GUTTER STRIPS (decor only: no collision, no touch)
--------------------------------------------------

local function ensureGutterStrip(name, sign)
	if course:FindFirstChild(name) then
		return
	end

	local zMin = math.min(startWall.Position.Z, finishWall.Position.Z)
	local zMax = math.max(startWall.Position.Z, finishWall.Position.Z)
	local length = zMax - zMin
	local floorTop = floorPart.Position.Y + floorPart.Size.Y / 2

	local strip = Instance.new("Part")
	strip.Name = name
	strip.Anchored = true
	strip.CanCollide = false
	strip.CanTouch = false
	strip.CanQuery = false
	strip.CastShadow = false
	strip.Material = Enum.Material.Slate
	strip.Color = Color3.fromRGB(46, 42, 58)
	strip.Size = Vector3.new(GUTTER_WIDTH, 0.3, length)
	strip.Position = Vector3.new(
		laneCenterX + sign * (laneHalfWidth - GUTTER_WIDTH / 2),
		floorTop + 0.05,
		(zMin + zMax) / 2
	)
	strip.Parent = course
end

ensureGutterStrip("GutterLeft", 1)
ensureGutterStrip("GutterRight", -1)

--------------------------------------------------
-- ROW LOOKUP
--------------------------------------------------

-- Returns rowNumber, totalRows for the row nearest the ball (by Z).
local function getRow(player, ballZ)
	local playerCourse = course:FindFirstChild("PlayerCourse_" .. player.UserId)
	if not playerCourse then
		return nil, nil
	end

	local bestRow, bestDistance, total = nil, math.huge, 0

	for _, child in ipairs(playerCourse:GetChildren()) do
		local rowNumber = child:GetAttribute("RowNumber")
		if typeof(rowNumber) == "number" then
			total += 1
			local z = child:IsA("Model") and child:GetPivot().Position.Z
				or (child:IsA("BasePart") and child.Position.Z)

			if z then
				local distance = math.abs(z - ballZ)
				if distance < bestDistance then
					bestDistance = distance
					bestRow = rowNumber
				end
			end
		end
	end

	return bestRow, total
end

--------------------------------------------------
-- PENALTY
--------------------------------------------------

local penalised = {}    -- [player] = { [rowNumber] = true } for this run
local lastPenalty = {}  -- [player] = os.clock()

local function applyPenalty(player, row, totalRows)
	local before = player:GetAttribute("CurrentOil")
	if typeof(before) ~= "number" or before <= 0 then
		return
	end

	local standing = math.max(0, totalRows - row)
	local fraction = standing / totalRows
	if fraction <= 0 then
		return
	end

	local amount = math.min(before, math.max(1, math.floor(before * fraction)))

	-- Lifetime total first (it rewrites the CurrentOil attribute), then
	-- restore the run oil: this run's oil minus what was removed.
	local persistent = PlayerDataService.GetOil(player)
	local removeFromTotal = math.min(amount, persistent)
	if removeFromTotal > 0 then
		PlayerDataService.RemoveOil(player, removeFromTotal)
	end

	player:SetAttribute("CurrentOil", before - amount)

	print(
		"[GutterService]",
		player.Name,
		"| Row:", row, "/", totalRows,
		"| Standing:", standing,
		"| Fraction:", string.format("%.2f", fraction),
		"| Removed:", amount,
		"| Left:", before - amount
	)

	gutterRemote:FireClient(player, amount, fraction, row, totalRows, before - amount)
end

--------------------------------------------------
-- MONITOR
--------------------------------------------------

local lastRunState = {}

task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)

		for _, player in ipairs(Players:GetPlayers()) do
			local runState = player:GetAttribute("RunState")

			-- A fresh run clears the per-row memory.
			if runState == "Starting" and lastRunState[player] ~= "Starting" then
				penalised[player] = nil
			end
			lastRunState[player] = runState

			if runState ~= "Running" then
				continue
			end

			local ball = playerBalls:FindFirstChild("PlayerBall_" .. player.UserId)
			if not ball or not ball:IsA("BasePart") then
				continue
			end

			local offset = math.abs(ball.Position.X - laneCenterX)
			if offset <= gutterEdge then
				continue
			end

			-- Nothing to lose: do not consume this row's one-time penalty.
			local carried = player:GetAttribute("CurrentOil")
			if typeof(carried) ~= "number" or carried <= 0 then
				continue
			end

			local now = os.clock()
			if lastPenalty[player] and now - lastPenalty[player] < COOLDOWN then
				continue
			end

			local row, totalRows = getRow(player, ball.Position.Z)
			if not row or not totalRows or totalRows <= 0 then
				continue
			end

			penalised[player] = penalised[player] or {}
			if penalised[player][row] then
				continue
			end

			penalised[player][row] = true
			lastPenalty[player] = now

			applyPenalty(player, row, totalRows)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	penalised[player] = nil
	lastPenalty[player] = nil
	lastRunState[player] = nil
end)

print(
	"[GutterService] READY | lane center X:",
	string.format("%.1f", laneCenterX),
	"| gutter edge:",
	string.format("%.1f", gutterEdge)
)
