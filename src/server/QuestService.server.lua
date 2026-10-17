--------------------------------------------------
-- QUEST SERVICE (SERVER ONLY)
--
-- Three daily quests per player (shared/QuestConfig). Progress comes only
-- from server-side signals (RunState, Level, WinCourse winnings, collected
-- platforms); the client cannot report progress. Claims are validated
-- here, the claimed flag is saved BEFORE the reward is granted, and the
-- state lives in its own DataStore ("DailyQuests_v1"), keyed by UTC day
-- so quests reset at UTC midnight.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local BoostService = require(ServerScriptService:WaitForChild("BoostService"))
local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService")
)

local store = DataStoreService:GetDataStore("DailyQuests_v1")

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

local stateFunction = getOrCreate("RemoteFunction", "QuestsState")
local claimFunction = getOrCreate("RemoteFunction", "QuestsClaim")
local updateEvent = getOrCreate("RemoteEvent", "QuestsUpdate")

-- [player] = { Day, Quests = { {Id, Target, Reward, Progress, Claimed} }, BonusClaimed, Dirty, Loaded }
local states = {}
local busy = {}

local function today()
	return math.floor(os.time() / 86400)
end

local function key(player)
	return "u_" .. player.UserId
end

-- Wins paid for a quest, scaled up by rebirths (+25% each, capped).
local function payout(player, quest)
	local rebirths = math.min(PlayerDataService.GetRebirths(player) or 0, 20)
	return math.floor(quest.Reward * (1 + 0.25 * rebirths))
end

local function rewardFor(entry, tier, target)
	local ratio = target / entry.Targets[1]
	local scale = ratio > 1 and ratio ^ 0.35 or 1
	return math.floor(entry.Reward * (1 + (tier - 1) * 0.6) * scale)
end

local function rollQuests(player, day)
	local rng = Random.new(player.UserId + day * 7919)
	local pool = table.clone(QuestConfig.Pool)
	local quests = {}

	for _ = 1, math.min(QuestConfig.QUESTS_PER_DAY, #pool) do
		local entry = table.remove(pool, rng:NextInteger(1, #pool))
		local tier = rng:NextInteger(1, #entry.Targets)
		local target = entry.Targets[tier]
		table.insert(quests, {
			Id = entry.Id,
			Target = target,
			Reward = rewardFor(entry, tier, target),
			Progress = 0,
			Claimed = false,
		})
	end

	return quests
end

local function allClaimed(state)
	for _, quest in ipairs(state.Quests) do
		if not quest.Claimed then
			return false
		end
	end
	return true
end

local function publicState(state, player)
	local list = {}
	for index, quest in ipairs(state.Quests) do
		local entry = QuestConfig.Find(quest.Id)
		list[index] = {
			Title = string.format(entry and entry.Title or quest.Id, quest.Target),
			Target = quest.Target,
			Progress = math.min(quest.Progress, quest.Target),
			Reward = payout(player, quest),
			Claimed = quest.Claimed,
		}
	end

	return {
		Quests = list,
		BonusWins = QuestConfig.BonusWins,
		BonusClaimed = state.BonusClaimed,
		AllDone = allClaimed(state),
	}
end

local function push(player)
	local state = states[player]
	if state then
		updateEvent:FireClient(player, publicState(state, player))
	end
end

local function save(player)
	local state = states[player]
	if not state then
		return false
	end

	local ok = pcall(function()
		store:SetAsync(key(player), {
			Day = state.Day,
			Quests = state.Quests,
			BonusClaimed = state.BonusClaimed,
		})
	end)

	state.Dirty = not ok
	return ok
end

local function load(player)
	local ok, value = pcall(function()
		return store:GetAsync(key(player))
	end)

	if not player.Parent then
		return
	end

	local day = today()
	local state

	if ok and typeof(value) == "table" and value.Day == day and typeof(value.Quests) == "table" then
		state = { Day = day, Quests = value.Quests, BonusClaimed = value.BonusClaimed == true }
	else
		state = { Day = day, Quests = rollQuests(player, day), BonusClaimed = false }
	end

	-- A failed read must never overwrite saved progress later.
	state.Loaded = ok
	states[player] = state
	push(player)
end

--------------------------------------------------
-- PROGRESS (server signals only)
--------------------------------------------------

local function addProgress(player, id, amount)
	local state = states[player]
	if not state or amount <= 0 then
		return
	end

	-- day rollover while playing
	if state.Day ~= today() then
		state.Day = today()
		state.Quests = rollQuests(player, state.Day)
		state.BonusClaimed = false
	end

	local changed = false
	for _, quest in ipairs(state.Quests) do
		if quest.Id == id and not quest.Claimed and quest.Progress < quest.Target then
			quest.Progress = math.min(quest.Progress + amount, quest.Target)
			changed = true
		end
	end

	if changed then
		state.Dirty = true
		push(player)
	end
end

local function watch(player)
	local lastLevel = player:GetAttribute("Level")
	local lastPlatforms = player:GetAttribute("CollectedOilCount")
	local lastRunState = player:GetAttribute("RunState")

	player:GetAttributeChangedSignal("Level"):Connect(function()
		local level = player:GetAttribute("Level")
		if typeof(level) == "number" and typeof(lastLevel) == "number" and level > lastLevel then
			addProgress(player, "Levels", level - lastLevel)
		end
		lastLevel = level
	end)

	player:GetAttributeChangedSignal("CollectedOilCount"):Connect(function()
		local count = player:GetAttribute("CollectedOilCount")
		if typeof(count) == "number" and typeof(lastPlatforms) == "number" and count > lastPlatforms then
			addProgress(player, "Platforms", count - lastPlatforms)
		end
		lastPlatforms = count
	end)

	player:GetAttributeChangedSignal("RunState"):Connect(function()
		local runState = player:GetAttribute("RunState")
		if runState == "Finishing" and lastRunState ~= "Finishing" then
			addProgress(player, "Runs", 1)
		end
		lastRunState = runState
	end)

	player:GetAttributeChangedSignal("LastWinCourseWinnings"):Connect(function()
		local amount = player:GetAttribute("LastWinCourseWinnings")
		if typeof(amount) == "number" then
			addProgress(player, "WinCourse", amount)
		end
	end)
end

--------------------------------------------------
-- REMOTES
--------------------------------------------------

stateFunction.OnServerInvoke = function(player)
	local state = states[player]
	return state and publicState(state, player) or nil
end

-- index 1..N claims that quest; index 0 claims the all-done bonus.
claimFunction.OnServerInvoke = function(player, index)
	local state = states[player]
	if not state or busy[player] or typeof(index) ~= "number" then
		return false, "BUSY"
	end

	index = math.floor(index)
	busy[player] = true
	local ok, reason = false, "INVALID"

	if index >= 1 and index <= #state.Quests then
		local quest = state.Quests[index]

		if quest.Claimed then
			reason = "CLAIMED"
		elseif quest.Progress < quest.Target then
			reason = "NOT_DONE"
		else
			quest.Claimed = true
			if save(player) then
				PlayerDataService.AddWins(player, payout(player, quest))
				PlayerDataService.SavePlayer(player)
				ok, reason = true, "OK"
			else
				quest.Claimed = false
				reason = "SAVE_FAILED"
			end
		end
	elseif index == 0 then
		if state.BonusClaimed then
			reason = "CLAIMED"
		elseif not allClaimed(state) then
			reason = "NOT_DONE"
		else
			state.BonusClaimed = true
			if save(player) then
				PlayerDataService.AddWins(player, QuestConfig.BonusWins)
				BoostService.Grant(player, "XP4", QuestConfig.BonusBoostSeconds)
				PlayerDataService.SavePlayer(player)
				ok, reason = true, "OK"
			else
				state.BonusClaimed = false
				reason = "SAVE_FAILED"
			end
		end
	end

	busy[player] = nil
	push(player)
	return ok, reason
end

--------------------------------------------------
-- LIFECYCLE
--------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	watch(player)
	task.spawn(load, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
	task.spawn(load, player)
end

Players.PlayerRemoving:Connect(function(player)
	local state = states[player]
	if state and state.Dirty and state.Loaded then
		save(player)
	end
	states[player] = nil
	busy[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(45)
		for player, state in pairs(states) do
			if state.Dirty and state.Loaded then
				task.spawn(save, player)
			end
		end
	end
end)

game:BindToClose(function()
	for player, state in pairs(states) do
		if state.Dirty and state.Loaded then
			save(player)
		end
	end
end)

print("[QuestService] READY")
