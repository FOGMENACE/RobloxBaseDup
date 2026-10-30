--------------------------------------------------
-- REWARD SERVICE (SERVER ONLY)
--
--   * LEAVE REWARD ("WAIT! Don't Leave!"): 360 wins + x4 XP for 8 minutes,
--     claimable once per 25 minutes. The cooldown is saved as an absolute
--     timestamp ("LeaveReward_v1"), so rejoining never resets it. It also has
--     to be unlocked by playing each session (LeaveOfferAt, see below).
--   * COMMUNITY REWARD: +500 wins once per account, only if the player is
--     in the group (verified here) and has completed the favorite prompt
--     (flag written by PromptService). Roblox exposes no API to verify a
--     like, so that part relies on the prompt having been completed.
--
-- Clients only send "claim"; amounts, cooldowns and eligibility live here.
-- The claim flag is written BEFORE the reward is granted (and rolled back
-- if the grant fails), so a crash can lose a reward but never duplicate it.
--------------------------------------------------

local Players = game:GetService("Players")
local DataRetry = require(game:GetService("ServerScriptService"):WaitForChild("DataRetry"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local BoostService = require(ServerScriptService:WaitForChild("BoostService"))
local GameAnalytics = require(ServerScriptService:WaitForChild("GameAnalytics"))
local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService")
)

local GROUP_ID = 42308423
local LEAVE_WINS = 360
local LEAVE_COOLDOWN = 25 * 60
local LEAVE_BOOST_SECONDS = 8 * 60
local COMMUNITY_WINS = 500

local leaveStore = DataStoreService:GetDataStore("LeaveReward_v1")
local communityStore = DataStoreService:GetDataStore("CommunityReward_v1")
local flagStore = DataStoreService:GetDataStore("PromptFlags_v1")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreate(className, name)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = remotes
	return created
end

local leaveClaim = getOrCreate("RemoteFunction", "LeaveRewardClaim")
local communityState = getOrCreate("RemoteFunction", "CommunityRewardState")
local communityClaim = getOrCreate("RemoteFunction", "CommunityRewardClaim")

local busy = {} -- [player] = true while a claim is in flight

local function key(player)
	return "u_" .. player.UserId
end

--------------------------------------------------
-- LEAVE REWARD
--------------------------------------------------

-- Published so the client can skip the popup during the cooldown.
local function publishLeave(player, nextAt)
	player:SetAttribute("LeaveRewardNextAt", nextAt)
end

-- The offer is earned by playing, and rolled once per session so reopening the menu
-- cannot re-roll it: most sessions unlock it after LEAVE_OFFER_MINUTES of play, some
-- earlier as a surprise to catch a player leaving early. Never in the first 3 minutes,
-- and the claim below enforces the same time, so calling the remote early pays nothing.
local LEAVE_OFFER_SECONDS = 10 * 60
local LEAVE_EARLY_CHANCE = 0.35
local LEAVE_EARLY_MIN, LEAVE_EARLY_MAX = 3 * 60, 5 * 60
local offerRng = Random.new()

local offerKind = {} -- [player] = "Early" / "Regular" (analytics only)
local lastCardEvent = {} -- [player] = os.clock() of the last reported card event

local function rollLeaveOffer(player)
	local wait = LEAVE_OFFER_SECONDS
	offerKind[player] = "Regular"
	if offerRng:NextNumber() < LEAVE_EARLY_CHANCE then
		wait = offerRng:NextInteger(LEAVE_EARLY_MIN, LEAVE_EARLY_MAX)
		offerKind[player] = "Early"
	end
	player:SetAttribute("LeaveOfferAt", os.time() + wait)
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	offerKind[player] = nil
	lastCardEvent[player] = nil
end)

-- The client reports when the card is shown or closed. Analytics only: it pays nothing,
-- is rate limited and is ignored while this session has not unlocked the offer.
getOrCreate("RemoteEvent", "LeaveCardEvent").OnServerEvent:Connect(function(player, action)
	if action ~= "Shown" and action ~= "Dismissed" then
		return
	end
	local offerAt = player:GetAttribute("LeaveOfferAt")
	if typeof(offerAt) ~= "number" or os.time() < offerAt then
		return
	end
	local now = os.clock()
	if now - (lastCardEvent[player] or -math.huge) < 2 then
		return
	end
	lastCardEvent[player] = now
	GameAnalytics.LeaveCard(player, action, offerKind[player])
end)

Players.PlayerAdded:Connect(function(player)
	rollLeaveOffer(player)
	local ok, value = DataRetry.Get(leaveStore, key(player))
	if player.Parent then
		publishLeave(player, ok and tonumber(value) or 0)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	rollLeaveOffer(player)
	task.spawn(function()
		local ok, value = DataRetry.Get(leaveStore, key(player))
		publishLeave(player, ok and tonumber(value) or 0)
	end)
end

leaveClaim.OnServerInvoke = function(player)
	if busy[player] then
		return false, "BUSY"
	end

	local nextAt = player:GetAttribute("LeaveRewardNextAt")
	if typeof(nextAt) ~= "number" then
		return false, "LOADING"
	end

	local now = os.time()
	if now < nextAt then
		return false, "COOLDOWN"
	end

	local offerAt = player:GetAttribute("LeaveOfferAt")
	if typeof(offerAt) ~= "number" or now < offerAt then
		return false, "TOO_SOON"
	end

	busy[player] = true

	local newNext = now + LEAVE_COOLDOWN
	-- Atomic across servers: the stored cooldown is re-checked inside UpdateAsync,
	-- so two servers cannot both pay out the same claim.
	local won = false
	local saved = pcall(function()
		leaveStore:UpdateAsync(key(player), function(old)
			if typeof(old) == "number" and old > now then
				return nil
			end
			won = true
			return newNext
		end)
	end)

	if not saved then
		busy[player] = nil
		return false, "SAVE_FAILED"
	end

	if not won then
		busy[player] = nil
		return false, "COOLDOWN"
	end

	publishLeave(player, newNext)
	local winsBefore = GameAnalytics.WinsBefore(player)
	PlayerDataService.AddWins(player, LEAVE_WINS)
	GameAnalytics.WinsChanged(player, winsBefore, "Social", "LeaveReward")
	BoostService.Grant(player, "XP4", LEAVE_BOOST_SECONDS)
	PlayerDataService.SavePlayer(player)
	GameAnalytics.LeaveCard(player, "Claimed", offerKind[player])

	busy[player] = nil
	return true, "OK"
end

--------------------------------------------------
-- COMMUNITY REWARD
--------------------------------------------------

local function isMember(player)
	local ok, result = pcall(function()
		return player:IsInGroupAsync(GROUP_ID)
	end)
	return ok and result == true
end

local function hasFavorited(player)
	local ok, value = DataRetry.Get(flagStore, "Flags_" .. tostring(player.UserId), 3)
	return ok and typeof(value) == "table" and value.FavoriteVerified == true
end

local function alreadyClaimed(player)
	local ok, value = DataRetry.Get(communityStore, key(player), 3)
	if not ok then
		return nil
	end
	return value == true
end

communityState.OnServerInvoke = function(player)
	return {
		Wins = COMMUNITY_WINS,
		Group = isMember(player),
		Liked = hasFavorited(player),
		Claimed = alreadyClaimed(player) == true,
	}
end

communityClaim.OnServerInvoke = function(player)
	if busy[player] then
		return false, "BUSY"
	end
	busy[player] = true

	local result, reason = false, "UNKNOWN"

	local claimed = alreadyClaimed(player)
	if claimed == nil then
		reason = "SAVE_FAILED"
	elseif claimed then
		reason = "CLAIMED"
	elseif not isMember(player) then -- the like cannot be verified, only the group
		reason = "REQUIREMENTS"
	else
		-- atomic across servers: only the call that flips false -> true pays out
		local won = false
		local ok = pcall(function()
			communityStore:UpdateAsync(key(player), function(old)
				if old == true then
					return nil
				end
				won = true
				return true
			end)
		end)

		local winsBefore = GameAnalytics.WinsBefore(player)

		if not ok then
			reason = "SAVE_FAILED"
		elseif not won then
			reason = "CLAIMED"
		elseif PlayerDataService.AddWins(player, COMMUNITY_WINS) then
			GameAnalytics.WinsChanged(player, winsBefore, "Social", "CommunityReward")
			PlayerDataService.SavePlayer(player)
			result, reason = true, "OK"
		else
			pcall(function()
				communityStore:RemoveAsync(key(player))
			end)
			reason = "GRANT_FAILED"
		end
	end

	busy[player] = nil
	return result, reason
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

print("[RewardService] READY")
