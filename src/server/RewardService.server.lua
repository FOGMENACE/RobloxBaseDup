--------------------------------------------------
-- REWARD SERVICE (SERVER ONLY)
--
--   * LEAVE REWARD ("WAIT! Don't Leave!"): 360 wins + x4 XP for 8 minutes,
--     claimable once per 25 minutes. The cooldown is saved as an absolute
--     timestamp ("LeaveReward_v1"), so rejoining never resets it.
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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local BoostService = require(ServerScriptService:WaitForChild("BoostService"))
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

Players.PlayerAdded:Connect(function(player)
	local ok, value = pcall(function()
		return leaveStore:GetAsync(key(player))
	end)
	if player.Parent then
		publishLeave(player, ok and tonumber(value) or 0)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		local ok, value = pcall(function()
			return leaveStore:GetAsync(key(player))
		end)
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
	PlayerDataService.AddWins(player, LEAVE_WINS)
	BoostService.Grant(player, "XP4", LEAVE_BOOST_SECONDS)
	PlayerDataService.SavePlayer(player)

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
	local ok, value = pcall(function()
		return flagStore:GetAsync("Flags_" .. tostring(player.UserId))
	end)
	return ok and typeof(value) == "table" and value.FavoriteVerified == true
end

local function alreadyClaimed(player)
	local ok, value = pcall(function()
		return communityStore:GetAsync(key(player))
	end)
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
	elseif not (isMember(player) and hasFavorited(player)) then
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

		if not ok then
			reason = "SAVE_FAILED"
		elseif not won then
			reason = "CLAIMED"
		elseif PlayerDataService.AddWins(player, COMMUNITY_WINS) then
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
