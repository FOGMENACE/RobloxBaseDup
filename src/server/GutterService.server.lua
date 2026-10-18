--------------------------------------------------
-- GUTTER SERVICE
--
-- SERVER ONLY. The "gutter" is now a NEGATIVE PLATFORM inside the normal
-- 12-row oil course instead of two long edge strips (at 50-240 studs/s a
-- strip along the wall caught players no matter what they did).
--
-- Each run, GUTTER_ROWS of the course's rows swap ONE of their two
-- platforms for a dark-red "GUTTER" platform. Rolling through it costs a
-- share of the oil collected so far (same rule as before):
--
--     penalty fraction = pinsStillStanding / totalPins
--
-- where the course has one "pin" per row, so a gutter in row N leaves
-- (totalRows - N) pins standing. With 12 rows: row 2 = 10/12 (huge),
-- row 8 = 4/12, row 12 = nothing. Because the other platform of the row
-- stays a normal one, the player can always dodge it with a small move.
--
-- Rows 3, 6 and 9 belong to BallTierGates (upgrade / downgrade) and are
-- never used here. Each gutter platform penalises once per run.
--
-- Everything is computed here from the ball's real touch and the
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

-- A run gets 0-3 gutters (most runs 0 or 1): they are a rare surprise.
local GUTTER_COUNT_WEIGHTS = { [0] = 35, [1] = 38, [2] = 20, [3] = 7 }
local CANDIDATE_ROWS = { 2, 4, 5, 7, 8, 10, 11 } -- not the tier rows 3, 6, 9
local GUTTER_COLOR = Color3.fromRGB(96, 14, 34)
local CREAM = Color3.fromRGB(255, 247, 232)

local course = workspace:WaitForChild("Course")
local playerBalls = workspace:WaitForChild("PlayerBalls")
local rng = Random.new()

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

-- The old edge strips are gone; remove any left in the place file.
for _, name in ipairs({ "GutterLeft", "GutterRight" }) do
	local old = course:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

--------------------------------------------------
-- PENALTY
--------------------------------------------------

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
-- BUILD THE GUTTER PLATFORMS FOR ONE RUN
--------------------------------------------------

local function platformParts(platform)
	local parts = {}
	if platform:IsA("BasePart") then
		table.insert(parts, platform)
	end
	for _, object in ipairs(platform:GetDescendants()) do
		if object:IsA("BasePart") then
			table.insert(parts, object)
		end
	end
	return parts
end

local function convert(player, platform, row, totalRows)
	local fraction = math.max(0, totalRows - row) / totalRows
	local percent = math.floor(fraction * 100 + 0.5)
	local used = false

	-- Not oil any more: the oil collection handler skips collected platforms.
	platform:SetAttribute("Collected", true)
	platform:SetAttribute("GutterPlatform", true)
	platform:SetAttribute("OilAmount", 0)
	platform:SetAttribute("Positive", false)
	platform:SetAttribute("Display", "GUTTER")

	for _, part in ipairs(platformParts(platform)) do
		part.Color = GUTTER_COLOR
		part.Transparency = 0.2
	end

	for _, object in ipairs(platform:GetDescendants()) do
		if object:IsA("TextLabel") then
			object.Text = "GUTTER\n-" .. percent .. "%"
			object.TextColor3 = CREAM
		end
	end

	for _, part in ipairs(platformParts(platform)) do
		part.Touched:Connect(function(hit)
			if used then
				return
			end

			if hit.Name ~= "PlayerBall_" .. tostring(player.UserId) or hit.Parent ~= playerBalls then
				return
			end

			if player:GetAttribute("RunState") ~= "Running" then
				return
			end

			used = true

			for _, p in ipairs(platformParts(platform)) do
				p.Transparency = 0.75
			end

			applyPenalty(player, row, totalRows)
		end)
	end
end

local function build(player, playerCourse)
	local rows = {}
	for _, child in ipairs(playerCourse:GetChildren()) do
		local rowNumber = child:GetAttribute("RowNumber")
		if typeof(rowNumber) == "number" then
			rows[rowNumber] = child
		end
	end

	local totalRows = 0
	for _ in pairs(rows) do
		totalRows += 1
	end
	if totalRows <= 0 then
		return
	end

	local pool = {}
	for _, rowNumber in ipairs(CANDIDATE_ROWS) do
		if rows[rowNumber] then
			table.insert(pool, rowNumber)
		end
	end

	local gutters = 0
	do
		local roll = rng:NextNumber() * 100
		local acc = 0
		for count = 0, 3 do
			acc += GUTTER_COUNT_WEIGHTS[count]
			if roll <= acc then
				gutters = count
				break
			end
		end
	end

	for _ = 1, math.min(gutters, #pool) do
		local pick = table.remove(pool, rng:NextInteger(1, #pool))
		local row = rows[pick]

		local left = row:FindFirstChild("OilPlatformL", true)
		local right = row:FindFirstChild("OilPlatformR", true)
		if not left or not right then
			continue
		end

		-- Prefer replacing a negative platform so good ones stay good.
		local target
		if left:GetAttribute("Positive") == false and right:GetAttribute("Positive") ~= false then
			target = left
		elseif right:GetAttribute("Positive") == false and left:GetAttribute("Positive") ~= false then
			target = right
		else
			target = rng:NextInteger(0, 1) == 1 and left or right
		end

		convert(player, target, pick, totalRows)
	end
end

--------------------------------------------------
-- MONITOR (run lifecycle)
--------------------------------------------------

local builtFor = {} -- [player] = the PlayerCourse model already processed

task.spawn(function()
	while true do
		task.wait(0.25)

		for _, player in ipairs(Players:GetPlayers()) do
			if player:GetAttribute("RunState") == "Running" then
				local playerCourse = course:FindFirstChild("PlayerCourse_" .. player.UserId)

				if playerCourse and builtFor[player] ~= playerCourse then
					builtFor[player] = playerCourse
					build(player, playerCourse)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	builtFor[player] = nil
end)

print("[GutterService] READY | gutter platforms per run: 0-3 (random)")
