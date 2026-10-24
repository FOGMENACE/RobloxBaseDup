--------------------------------------------------
-- BOOST SERVICE (SERVER ONLY MODULE)
--
-- Timed multipliers (see shared/BoostConfig): x2 oil, x2 wins, x4 XP.
-- Stored as absolute end times in its own DataStore ("Boosts_v1") so a
-- boost keeps running (and cannot be extended) across rejoins.
--
-- Queries are non-yielding cache reads, so the oil / wins / XP code can
-- ask every time it pays out. The end times are also published as player
-- attributes (BoostOilUntil / BoostWinsUntil / BoostXPUntil, server
-- time) purely so the UI can show countdowns.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local BoostConfig = require(ReplicatedStorage:WaitForChild("BoostConfig"))

local store = DataStoreService:GetDataStore("Boosts_v1")

local BoostService = {}

local ATTRIBUTE_OF = {
	Oil2x = "BoostOilUntil",
	Wins2x = "BoostWinsUntil",
	XP4 = "BoostXPUntil",
	Captain = "BoostCaptainUntil",
}

local states = {} -- [player] = { Loaded, Ends = { [key] = epochSeconds } }

local function keyFor(player)
	return "Boosts_" .. tostring(player.UserId)
end

local function publish(player, state)
	for key, attribute in pairs(ATTRIBUTE_OF) do
		local untilTime = state.Ends[key] or 0
		if player:GetAttribute(attribute) ~= untilTime then
			player:SetAttribute(attribute, untilTime)
		end
	end
end

local function save(player, state)
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), state.Ends)
	end)

	if not ok then
		warn("[BoostService] Save failed:", player.Name, err)
	end

	return ok
end

local function loadPlayer(player)
	local state = { Loaded = false, Ends = {} }
	states[player] = state

	require(game:GetService("ServerScriptService"):WaitForChild("SessionGate")).Wait(player)

	local ok, value = pcall(function()
		return store:GetAsync(keyFor(player))
	end)

	if not ok then
		warn("[BoostService] Load failed:", player.Name, value)
		return
	end

	if typeof(value) == "table" then
		for key in pairs(ATTRIBUTE_OF) do
			state.Ends[key] = tonumber(value[key]) or 0
		end
	end

	state.Loaded = true
	publish(player, state)
end

--------------------------------------------------
-- FRIEND BONUS: +10% XP per friend in the same server (max 5 = +50%).
-- Computed here from Roblox's own friendship data, never from the client;
-- published as the FriendBonusPct attribute for the HUD.
--------------------------------------------------

local FRIEND_BONUS_PER = 0.10
local FRIEND_BONUS_MAX = 5

local friendCounts = {} -- [player] = number
local pairCache = {} -- [player] = { [otherUserId] = { IsFriend, At } }: each pair is asked once per 10 minutes
local PAIR_TTL = 600

local function refreshFriends()
	local all = Players:GetPlayers()

	for _, player in ipairs(all) do
		task.spawn(function()
			local count = 0
			for _, other in ipairs(all) do
				if other ~= player then
					local known = pairCache[player]
					if not known then
						known = {}
						pairCache[player] = known
					end
					local entry = known[other.UserId]
					local ok, isFriend
					if entry and os.clock() - entry.At < PAIR_TTL then
						ok, isFriend = true, entry.IsFriend
					else
						ok, isFriend = pcall(function()
							return player:IsFriendsWith(other.UserId)
						end)
						if ok then
							known[other.UserId] = { IsFriend = isFriend == true, At = os.clock() }
						end
					end
					if ok and isFriend then
						count += 1
					end
				end
			end

			if player.Parent then
				friendCounts[player] = math.min(count, FRIEND_BONUS_MAX)
				player:SetAttribute("FriendBonusPct", friendCounts[player] * FRIEND_BONUS_PER * 100)
			end
		end)
	end
end

Players.PlayerAdded:Connect(function()
	task.delay(2, refreshFriends)
end)
Players.PlayerRemoving:Connect(function(player)
	friendCounts[player] = nil
	pairCache[player] = nil
	task.delay(1, refreshFriends)
end)
task.defer(refreshFriends)

-- QUERIES
--------------------------------------------------

local function isActive(player, key)
	local state = states[player]
	return state ~= nil and state.Loaded and (state.Ends[key] or 0) > os.time()
end

function BoostService.IsActive(player, key)
	return isActive(player, key)
end

local function multiplierFor(player, key)
	if isActive(player, key) then
		return BoostConfig.Boosts[key].Multiplier
	end
	return 1
end

function BoostService.OilMultiplier(player)
	return multiplierFor(player, "Oil2x") * multiplierFor(player, "Captain")
end

function BoostService.WinsMultiplier(player)
	return multiplierFor(player, "Wins2x") * multiplierFor(player, "Captain")
end

function BoostService.XPMultiplier(player)
	return multiplierFor(player, "XP4") * (1 + (friendCounts[player] or 0) * FRIEND_BONUS_PER)
end

--------------------------------------------------
-- GRANT
--------------------------------------------------

-- Adds `seconds` to a boost (starting now if it is not running). Saves
-- before returning; returns true only if it was saved.
function BoostService.Grant(player, key, seconds)
	local state = states[player]
	if not state or not state.Loaded or not ATTRIBUTE_OF[key] then
		return false
	end

	seconds = tonumber(seconds) or BoostConfig.Boosts[key].Duration

	local base = math.max(state.Ends[key] or 0, os.time())
	state.Ends[key] = base + seconds

	publish(player, state)
	return save(player, state)
end

--------------------------------------------------
-- LIFECYCLE
--------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

return BoostService
