--------------------------------------------------
-- BALL TIER GATES
-- SERVER ONLY. Ball upgrade / downgrade platforms inside the normal
-- 12-row oil course. Rows 3, 6 and 9 (TIER_ROWS) have their two
-- platforms converted: GREEN = upgrade (next ball in the shop list),
-- RED = downgrade (the ball below). Each row is randomly green+green,
-- green+red or red+red. Rolling through one swaps the player ball model
-- for the rest of the run (its real speed stats apply, course speed
-- carries over). When the run ends the equipped ball comes back. At the
-- first/last ball a platform changes nothing and says so.
--
-- Everything is decided here from the real ball position; clients only
-- get a notification to display (Remotes.BallTier). The swap itself is
-- done by BallSpawner through a server-only BindableEvent.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local BallDefinitions = require(ServerScriptService:WaitForChild("BallDefinitions"))
local PlayerDataService = require(
	ServerScriptService
		:WaitForChild("PlayerDataLoader")
		:WaitForChild("PlayerDataService")
)

local SweptTouch = require(ServerScriptService:WaitForChild("SweptTouch"))
local swapEvent = ServerScriptService:WaitForChild("SwapRunBall")
local course = workspace:WaitForChild("Course")
local playerBalls = workspace:WaitForChild("PlayerBalls")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local tierRemote = remotes:FindFirstChild("BallTier")
if not tierRemote then
	tierRemote = Instance.new("RemoteEvent")
	tierRemote.Name = "BallTier"
	tierRemote.Parent = remotes
end

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local TIER_ROWS = { 3, 6, 9 }

local CREAM = Color3.fromRGB(255, 247, 232)
local INK = Color3.fromRGB(24, 22, 34)

--------------------------------------------------
-- BALL ORDER (the shop list)
--------------------------------------------------

local ordered = {}
for ballId, definition in pairs(BallDefinitions) do
	if definition.IsExclusive ~= true then
		table.insert(ordered, { Id = ballId, Order = definition.DisplayOrder or 0 })
	end
end
table.sort(ordered, function(a, b)
	return a.Order < b.Order
end)

local indexOf = {}
for index, entry in ipairs(ordered) do
	indexOf[entry.Id] = index
end

-- Exclusive balls (the Oil Barrel) are not in the tier list, but their owners
-- still roll through upgrade / downgrade platforms: an exclusive ball counts
-- as ONE STEP ABOVE the best normal ball. A downgrade drops it to the best
-- normal ball, an upgrade has nowhere to go ("best ball").
local EXCLUSIVE_INDEX = #ordered + 1
for ballId, definition in pairs(BallDefinitions) do
	if definition.IsExclusive == true then
		indexOf[ballId] = EXCLUSIVE_INDEX
	end
end
local function displayName(ballId)
	local definition = BallDefinitions[ballId]
	return definition and definition.DisplayName or tostring(ballId)
end

--------------------------------------------------
-- STATE
--------------------------------------------------

-- [player] = { BallId, GatesFor, Locked, Revert }
local states = {}
local rng = Random.new()

local function getState(player)
	local state = states[player]
	if not state then
		state = { BallId = nil, GatesFor = nil, Locked = false, Revert = false }
		states[player] = state
	end
	return state
end

--------------------------------------------------
-- APPLY A GATE
--------------------------------------------------

local function applyGate(player, state, ball, delta)
	if not state.BallId or not indexOf[state.BallId] then
		return
	end

	local currentIndex = indexOf[state.BallId]
	local topIndex = (currentIndex == EXCLUSIVE_INDEX) and EXCLUSIVE_INDEX or #ordered
	local newIndex = math.clamp(currentIndex + delta, 1, topIndex)
	local oldName = displayName(state.BallId)

	if newIndex == currentIndex then
		-- Already at the top / bottom of the list.
		tierRemote:FireClient(player, delta > 0 and "MaxUp" or "MinDown", oldName, oldName, currentIndex, #ordered)
		return
	end

	local newId = ordered[newIndex].Id
	local velocity = ball.AssemblyLinearVelocity
	local carrySpeed = math.abs(velocity.Z)

	state.BallId = newId
	player:SetAttribute("RunBallName", displayName(newId))

	swapEvent:Fire(player, newId, ball.CFrame, velocity, carrySpeed)

	tierRemote:FireClient(
		player,
		delta > 0 and "Up" or "Down",
		oldName,
		displayName(newId),
		newIndex,
		#ordered
	)

	print(
		"[BallTierGates]",
		player.Name,
		delta > 0 and "UPGRADE" or "DOWNGRADE",
		oldName, "->", displayName(newId)
	)
end

--------------------------------------------------
-- BALL TIER PLATFORMS (part of the normal 12-row oil course)
--
-- A few of the generator's own rows (TIER_ROWS) have their platforms
-- turned into ball-tier platforms: GREEN = upgrade, RED = downgrade.
-- Each row randomly becomes green+green, green+red or red+red, exactly
-- like oil rows, so nothing is inserted between rows and the row
-- spacing stays the generator's.
--------------------------------------------------

local UP_PLATFORM_COLOR = Color3.fromRGB(40, 222, 72)
local DOWN_PLATFORM_COLOR = Color3.fromRGB(236, 42, 52)

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

-- Row pattern: 30% green+green, 55% green+red, 15% red+red.
local function rollPattern()
	local roll = rng:NextNumber()
	if roll < 0.30 then
		return true, true
	elseif roll < 0.85 then
		local leftUp = rng:NextInteger(0, 1) == 1
		return leftUp, not leftUp
	end
	return false, false
end


local function convertPlatform(platform, isUp)
	-- Not oil any more: the oil collection handler skips collected platforms.
	platform:SetAttribute("Collected", true)
	platform:SetAttribute("TierEffect", isUp and "Up" or "Down")
	platform:SetAttribute("Positive", isUp)
	platform:SetAttribute("OilAmount", 0)
	platform:SetAttribute("Display", isUp and "UPGRADE" or "DOWNGRADE")
	-- no longer a special oil platform (it may have been a /2 or X2 underneath)
	platform:SetAttribute("IsDivider", false)
	platform:SetAttribute("IsMultiplier", false)
	platform:SetAttribute("IsSpecial", false)

	for _, part in ipairs(platformParts(platform)) do
		part.Color = isUp and UP_PLATFORM_COLOR or DOWN_PLATFORM_COLOR
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0.3
	end

	for _, object in ipairs(platform:GetDescendants()) do
		if object:IsA("TextLabel") then
			object.Text = isUp and "UPGRADE" or "DOWNGRADE"
			object.TextColor3 = CREAM
		end
	end
end

-- Upgrade / downgrade rows are a rare event: a course gets 0-3 of them
-- (most often 0 or 1), on randomly chosen candidate rows.
local TIER_COUNT_WEIGHTS = { [0] = 32, [1] = 40, [2] = 20, [3] = 8 }

local function chooseTierRows(playerCourse)
	local roll = rng:NextNumber() * 100
	local acc = 0
	local count = 0
	for candidate = 0, 3 do
		acc += TIER_COUNT_WEIGHTS[candidate]
		if roll <= acc then
			count = candidate
			break
		end
	end

	-- A course already full of X2 / X4 gets fewer upgrade platforms, so it is
	-- never wall-to-wall helpers (mixed difficulty).
	if (playerCourse:GetAttribute("MultiplierPlatforms") or 0) >= 2 then
		count = math.min(count, 1)
	elseif (playerCourse:GetAttribute("MultiplierPlatforms") or 0) == 1 then
		count = math.min(count, 2)
	end

	local pool = table.clone(TIER_ROWS)
	local chosen = {}
	for _ = 1, math.min(count, #pool) do
		chosen[table.remove(pool, rng:NextInteger(1, #pool))] = true
	end
	return chosen
end

local function buildGates(player, state, playerCourse)
	local chosenRows = chooseTierRows(playerCourse)

	for _, child in ipairs(playerCourse:GetChildren()) do
		local rowNumber = child:GetAttribute("RowNumber")
		if typeof(rowNumber) ~= "number" or not chosenRows[rowNumber] then
			continue
		end
		local left = child:FindFirstChild("OilPlatformL", true)
		local right = child:FindFirstChild("OilPlatformR", true)
		if not left or not right then
			continue
		end

		local leftUp, rightUp = rollPattern()
		local platforms = { { left, leftUp }, { right, rightUp } }
		local used = false

		for _, entry in ipairs(platforms) do
			local platform, isUp = entry[1], entry[2]
			convertPlatform(platform, isUp)

			for _, part in ipairs(platformParts(platform)) do
				local function onHit(hit)
					if used or state.Locked then
						return
					end

					if hit.Name ~= "PlayerBall_" .. tostring(player.UserId)
						or hit.Parent ~= playerBalls then
						return
					end

					if player:GetAttribute("RunState") ~= "Running" then
						return
					end

					used = true
					state.Locked = true

					applyGate(player, state, hit, isUp and 1 or -1)

					-- One platform per row, as with oil.
					for _, other in ipairs(platforms) do
						for _, otherPart in ipairs(platformParts(other[1])) do
							otherPart.Transparency = 0.7
						end
					end

					task.delay(0.3, function()
						state.Locked = false
					end)
				end

				part.Touched:Connect(onHit)
				SweptTouch.Register(part, player.UserId, onHit) -- fast balls skip Touched
			end
		end
	end
end

--------------------------------------------------
-- MONITOR (run lifecycle)
--------------------------------------------------

local function equippedId(player)
	local id = PlayerDataService.GetEquippedBall(player)
	return (id and indexOf[id]) and id or nil
end

task.spawn(function()
	while true do
		task.wait(0.25)

		for _, player in ipairs(Players:GetPlayers()) do
			local state = getState(player)
			local runState = player:GetAttribute("RunState")

			if runState == "Starting" or runState == "Running" or runState == "Finishing" then
				state.Revert = true

				if not state.BallId then
					state.BallId = equippedId(player)
				end

				if runState == "Running" then
					local playerCourse = course:FindFirstChild("PlayerCourse_" .. player.UserId)

					if playerCourse and state.GatesFor ~= playerCourse then
						state.GatesFor = playerCourse
						buildGates(player, state, playerCourse)
					end
				end

			elseif state.Revert then
				-- Back in the lobby: the equipped ball returns.
				state.Revert = false
				state.GatesFor = nil

				local swappedId = state.BallId
				state.BallId = nil
				player:SetAttribute("RunBallName", nil)

				local equipped = equippedId(player)
				if swappedId and equipped and swappedId ~= equipped then
					task.delay(1, function()
						if player.Parent
							and (player:GetAttribute("RunState") == "Waiting") then
							swapEvent:Fire(player, equipped)
						end
					end)
				end
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

print("[BallTierGates] READY | balls in shop order:", #ordered)
