--------------------------------------------------
-- QUEST SERVICE (SERVER ONLY)
--
-- DAILY: three quests per player (shared/QuestConfig.Pool), reset at UTC
-- midnight, optional paid "Skip Quest" (Developer Product).
-- WEEKLY: seven milestones fed by the same signals, reset Monday 00:00 UTC.
--
-- Progress comes only from server-side signals (RunState, Level, WinCourse
-- winnings, collected platforms); the client cannot report progress.
-- Claims are validated here and the claimed flag is saved BEFORE the
-- reward is granted. Daily state: DataStore "DailyQuests_v1". Weekly
-- state: "WeeklyMilestones_v1".
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local StoreConfig = require(ServerScriptService:WaitForChild("StoreConfig"))
local BoostService = require(ServerScriptService:WaitForChild("BoostService"))
local ReceiptLedger = require(ServerScriptService:WaitForChild("ReceiptLedger"))
local PurchaseService = require(ServerScriptService:WaitForChild("PurchaseServiceModule"))
local GameAnalytics = require(ServerScriptService:WaitForChild("GameAnalytics"))
local DataRetry = require(ServerScriptService:WaitForChild("DataRetry"))
local PlayerDataService = require(
	ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService")
)

local dailyStore = DataStoreService:GetDataStore("DailyQuests_v1")
local weeklyStore = DataStoreService:GetDataStore("WeeklyMilestones_v1")

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
local weeklyClaimFunction = getOrCreate("RemoteFunction", "WeeklyClaim")
local updateEvent = getOrCreate("RemoteEvent", "QuestsUpdate")
local skipPromptEvent = getOrCreate("RemoteEvent", "QuestSkipPrompt")
local purchaseConfirmed = getOrCreate("RemoteEvent", "PurchaseConfirmed")

-- [player] = { Day, Quests, BonusClaimed, Dirty, Loaded,
--              Weekly = { Week, Counters, Claimed, Dirty, Loaded } }
local states = {}
local busy = {}
local pendingSkip = {} -- [player] = { Index, Time }

local PENDING_SECONDS = 10 * 60

local function today()
	return math.floor(os.time() / 86400)
end

-- Weeks start Monday 00:00 UTC (the Unix epoch was a Thursday).
local function thisWeek()
	return math.floor((os.time() - 4 * 86400) / (7 * 86400))
end

local function dailyKey(player)
	return "u_" .. player.UserId
end

-- Wins paid for a reward, scaled up by rebirths (+25% each, capped).
local function payout(player, base)
	local rebirths = math.min(PlayerDataService.GetRebirths(player) or 0, 10)
	return math.floor(base * (1 + 0.15 * rebirths))
end

-- Targets that grow with the player, so quests stay a real task at every rebirth. Wins per win-course
-- run (and levels per rebirth) explode with rebirths: a flat "win 150 wins" was done by one run for
-- anyone past the first rebirths. The easy pick asks for about 3-4 average runs / 1.5 rebirth cycles
-- and the harder picks scale from that. Count-based quests (runs, platforms, minutes...) stay as they
-- are, they are time.
local RebirthBonusesQ = require(ReplicatedStorage:WaitForChild("RebirthBonuses"))
-- average wins of one good win-course run per rebirth count (from the economy simulation)
local WINS_PER_RUN = { { 0, 6 }, { 1, 28 }, { 2, 176 }, { 3, 459 }, { 5, 1815 }, { 10, 12030 }, { 20, 98760 }, { 52, 823888 } }

local function winsPerRun(rebirths)
	local last = WINS_PER_RUN[#WINS_PER_RUN]
	if rebirths >= last[1] then
		return last[2] * (rebirths / last[1]) ^ 2
	end
	for i = 2, #WINS_PER_RUN do
		local a, b = WINS_PER_RUN[i - 1], WINS_PER_RUN[i]
		if rebirths <= b[1] then
			local t = (rebirths - a[1]) / (b[1] - a[1])
			return math.exp(math.log(a[2]) + (math.log(b[2]) - math.log(a[2])) * t) -- smooth between points
		end
	end
	return last[2]
end

local function scaledTarget(id, target, rebirths, firstTarget)
	local ratio = target / math.max(firstTarget, 1) -- 1 (easy), 2-3 (medium), up to ~7 (hard)
	local scaled = target
	if id == "WinCourse" then
		scaled = math.max(10, 3.5 * winsPerRun(rebirths) * ratio)
	elseif id == "Levels" then
		local cycle = math.max(1, (RebirthBonusesQ.RequiredLevel(rebirths) or 6) - 1)
		scaled = math.max(5, 1.5 * cycle * ratio)
	end
	scaled = math.ceil(scaled)
	if scaled >= 1000 then
		-- keep it readable: two significant figures
		local step = 10 ^ (math.floor(math.log10(scaled)) - 1)
		scaled = math.floor(scaled / step + 0.5) * step
	end
	return scaled
end

local function rewardFor(entry, tier, target)
	local ratio = target / entry.Targets[1]
	local scale = ratio > 1 and ratio ^ 0.35 or 1
	return math.floor(entry.Reward * (1 + (tier - 1) * 0.6) * scale)
end

local function rollQuests(player, day)
	local rng = Random.new(player.UserId + day * 7919)
	local rebirths = PlayerDataService.GetRebirths(player) or 0
	local pool = {}
	for _, entry in ipairs(QuestConfig.Pool) do
		if rebirths >= (entry.MinRebirths or 0) then
			table.insert(pool, entry)
		end
	end
	local quests = {}

	for _ = 1, math.min(QuestConfig.QUESTS_PER_DAY, #pool) do
		local entry = table.remove(pool, rng:NextInteger(1, #pool))
		local tier = rng:NextInteger(1, #entry.Targets)
		local baseTarget = entry.Targets[tier]
		local target = scaledTarget(entry.Id, baseTarget, rebirths, entry.Targets[1])
		table.insert(quests, {
			Id = entry.Id,
			Target = target,
			Reward = rewardFor(entry, tier, baseTarget),
			Progress = 0,
			Claimed = false,
		})
	end

	return quests
end

local function freshWeekly()
	return {
		Week = thisWeek(),
		Counters = { Runs = 0, Levels = 0, WinCourse = 0, Platforms = 0 },
		Claimed = {},
	}
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
			Title = (entry and quest.Target == 1 and entry.TitleOne) or string.format(entry and entry.Title or quest.Id, quest.Target),
			Target = quest.Target,
			Progress = math.min(quest.Progress, quest.Target),
			Reward = payout(player, quest.Reward),
			Claimed = quest.Claimed,
		}
	end

	local weekly = {}
	local w = state.Weekly
	for index, milestone in ipairs(QuestConfig.Weekly) do
		local count = w and w.Counters[milestone.Id] or 0
		weekly[index] = {
			Title = string.format(milestone.Title, milestone.Target),
			Target = milestone.Target,
			Progress = math.min(count, milestone.Target),
			Reward = payout(player, milestone.Reward),
			BoostMinutes = milestone.Boost and math.floor(milestone.Boost / 60) or 0,
			Claimed = w ~= nil and w.Claimed[index] == true,
		}
	end

	return {
		Quests = list,
		BonusWins = QuestConfig.BonusWins,
		BonusClaimed = state.BonusClaimed,
		AllDone = allClaimed(state),
		Weekly = weekly,
		WeekEndsAt = (thisWeek() + 1) * 7 * 86400 + 4 * 86400,
	}
end

local function push(player)
	local state = states[player]
	if state then
		updateEvent:FireClient(player, publicState(state, player))
	end
end

local function saveDaily(player)
	local state = states[player]
	-- a failed read must never be overwritten: no save, so every claim fails safely
	if not state or not state.Loaded then
		return false
	end

	local ok = pcall(function()
		dailyStore:SetAsync(dailyKey(player), {
			Day = state.Day,
			Quests = state.Quests,
			BonusClaimed = state.BonusClaimed,
		})
	end)

	state.Dirty = not ok
	return ok
end

local function saveWeekly(player)
	local state = states[player]
	local w = state and state.Weekly
	if not w or not w.Loaded then
		return false
	end

	local ok = pcall(function()
		weeklyStore:SetAsync(dailyKey(player), {
			Week = w.Week,
			Counters = w.Counters,
			Claimed = w.Claimed,
		})
	end)

	w.Dirty = not ok
	return ok
end

local function load(player)
	require(ServerScriptService:WaitForChild("SessionGate")).Wait(player)

	local ok, value = DataRetry.Get(dailyStore, dailyKey(player))
	local okW, weeklyValue = DataRetry.Get(weeklyStore, dailyKey(player))

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

	local weekly
	if okW and typeof(weeklyValue) == "table" and weeklyValue.Week == thisWeek()
		and typeof(weeklyValue.Counters) == "table" then
		weekly = {
			Week = weeklyValue.Week,
			Counters = {
				Runs = tonumber(weeklyValue.Counters.Runs) or 0,
				Levels = tonumber(weeklyValue.Counters.Levels) or 0,
				WinCourse = tonumber(weeklyValue.Counters.WinCourse) or 0,
				Platforms = tonumber(weeklyValue.Counters.Platforms) or 0,
			},
			Claimed = typeof(weeklyValue.Claimed) == "table" and weeklyValue.Claimed or {},
		}
	else
		weekly = freshWeekly()
	end
	weekly.Loaded = okW
	state.Weekly = weekly

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

	-- day / week rollover while playing
	if state.Day ~= today() then
		state.Day = today()
		state.Quests = rollQuests(player, state.Day)
		state.BonusClaimed = false
	end
	if state.Weekly and state.Weekly.Week ~= thisWeek() then
		local loaded = state.Weekly.Loaded
		state.Weekly = freshWeekly()
		state.Weekly.Loaded = loaded
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
	end

	local w = state.Weekly
	if w and w.Counters[id] ~= nil then
		w.Counters[id] += amount
		w.Dirty = true
		changed = true
	end

	if changed then
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
			if (player:GetAttribute("World") or 1) >= 2 then
				addProgress(player, "WorldRuns", 1)
			end
		end
		lastRunState = runState
	end)

	local lastRebirths = player:GetAttribute("Rebirths")
	player:GetAttributeChangedSignal("Rebirths"):Connect(function()
		local now = player:GetAttribute("Rebirths")
		if typeof(now) == "number" and typeof(lastRebirths) == "number" and now > lastRebirths then
			addProgress(player, "Rebirths", now - lastRebirths)
		end
		lastRebirths = now
	end)

	-- a ball upgrade / downgrade gate swaps the run ball (BallTierGates sets RunBallName)
	player:GetAttributeChangedSignal("RunBallName"):Connect(function()
		if player:GetAttribute("RunBallName") ~= nil then
			addProgress(player, "Gates", 1)
		end
	end)

	-- the free XP gift was claimed (LimitedGenerator: X6Mode becomes Active)
	local lastX6 = player:GetAttribute("X6Mode")
	player:GetAttributeChangedSignal("X6Mode"):Connect(function()
		local mode = player:GetAttribute("X6Mode")
		if mode == "Active" and lastX6 ~= "Active" then
			addProgress(player, "Gift", 1)
		end
		lastX6 = mode
	end)

	-- x2 / x4 oil panels: the run counts them (OilCourseGenerator / collection)
	local lastMult = player:GetAttribute("MultipliersHit") or 0
	player:GetAttributeChangedSignal("MultipliersHit"):Connect(function()
		local now = player:GetAttribute("MultipliersHit") or 0
		if now > lastMult then
			addProgress(player, "Multipliers", now - lastMult)
		end
		lastMult = now
	end)

	-- minutes on an XP generator (lobby): counted once a minute of standing time adds up
	task.spawn(function()
		local seconds = 0
		while player.Parent do
			task.wait(1)
			local gen = player:GetAttribute("ActiveXPGenerator")
			if typeof(gen) == "string" and gen ~= "" then
				seconds += 1
				if seconds >= 60 then
					seconds -= 60
					addProgress(player, "GenMinutes", 1)
				end
			end
		end
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
			if saveDaily(player) then
				local winsBefore = GameAnalytics.WinsBefore(player)
				PlayerDataService.AddWins(player, payout(player, quest.Reward))
				GameAnalytics.WinsChanged(player, winsBefore, "Quest", "Daily")
				GameAnalytics.QuestClaimed(player, quest.Id)
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
			if saveDaily(player) then
				local winsBefore = GameAnalytics.WinsBefore(player)
				PlayerDataService.AddWins(player, QuestConfig.BonusWins)
				GameAnalytics.WinsChanged(player, winsBefore, "Quest", "DailyBonus")
				GameAnalytics.QuestClaimed(player, "DailyBonus")
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

-- Weekly milestone claim (index 1..7).
weeklyClaimFunction.OnServerInvoke = function(player, index)
	local state = states[player]
	local w = state and state.Weekly
	if not w or busy[player] or typeof(index) ~= "number" then
		return false, "BUSY"
	end

	index = math.floor(index)
	local milestone = QuestConfig.Weekly[index]
	if not milestone then
		return false, "INVALID"
	end

	if w.Week ~= thisWeek() then
		return false, "NOT_DONE"
	end
	if w.Claimed[index] == true then
		return false, "CLAIMED"
	end
	if (w.Counters[milestone.Id] or 0) < milestone.Target then
		return false, "NOT_DONE"
	end

	busy[player] = true
	w.Claimed[index] = true

	local ok, reason
	if saveWeekly(player) then
		local winsBefore = GameAnalytics.WinsBefore(player)
		PlayerDataService.AddWins(player, payout(player, milestone.Reward))
		GameAnalytics.WinsChanged(player, winsBefore, "Quest", "Weekly")
		GameAnalytics.QuestClaimed(player, "Weekly_" .. tostring(milestone.Id))
		if milestone.Boost then
			BoostService.Grant(player, "XP4", milestone.Boost)
		end
		PlayerDataService.SavePlayer(player)
		ok, reason = true, "OK"
	else
		w.Claimed[index] = nil
		ok, reason = false, "SAVE_FAILED"
	end

	busy[player] = nil
	push(player)
	return ok, reason
end

--------------------------------------------------
-- SKIP QUEST (Developer Product, R$ 29)
--
-- The client asks for a quest index; the server validates it, remembers
-- it and opens the purchase prompt. The grant happens in the receipt
-- handler through the durable ReceiptLedger flow.
--------------------------------------------------

skipPromptEvent.OnServerEvent:Connect(function(player, index, kind)
	local state = states[player]
	if not state or typeof(index) ~= "number" then
		return
	end

	index = math.floor(index)
	kind = (kind == "Weekly") and "Weekly" or "Daily"

	if kind == "Weekly" then
		local w = state.Weekly
		local milestone = QuestConfig.Weekly[index]
		if not w or not w.Loaded or not milestone or w.Claimed[index] == true
			or (w.Counters[milestone.Id] or 0) >= milestone.Target then
			return
		end
	else
		local quest = state.Quests[index]
		if not state.Loaded or not quest or quest.Claimed or quest.Progress >= quest.Target then
			return
		end
	end

	pendingSkip[player] = { Index = index, Kind = kind, Time = os.time() }

	pcall(function()
		MarketplaceService:PromptProductPurchase(player, StoreConfig.QuestSkip.ProductId)
	end)
end)

PurchaseService.RegisterProduct(StoreConfig.QuestSkip.ProductId, function(player, receiptInfo)
	local state = player and states[player]
	if not state or not state.Loaded then
		return false -- not loaded (or the read failed): Roblox will retry
	end

	return ReceiptLedger.Consume(player, receiptInfo, function()
		local pending = pendingSkip[player]
		local done = false

		if pending and os.time() - pending.Time <= PENDING_SECONDS then
			if pending.Kind == "Weekly" then
				local w = state.Weekly
				local milestone = QuestConfig.Weekly[pending.Index]
				if w and milestone and w.Claimed[pending.Index] ~= true
					and (w.Counters[milestone.Id] or 0) < milestone.Target then
					-- jump the counter to the target (a shared counter also helps
					-- other milestones of the same kind, which is expected)
					w.Counters[milestone.Id] = milestone.Target
					w.Dirty = true
					saveWeekly(player)
					done = true
				end
			else
				local quest = state.Quests[pending.Index]
				if quest and not quest.Claimed and quest.Progress < quest.Target then
					quest.Progress = quest.Target
					state.Dirty = true
					saveDaily(player)
					done = true
				end
			end
		end

		-- the chosen quest was finished meanwhile: use another unfinished daily
		if not done then
			for _, quest in ipairs(state.Quests) do
				if not quest.Claimed and quest.Progress < quest.Target then
					quest.Progress = quest.Target
					state.Dirty = true
					saveDaily(player)
					done = true
					break
				end
			end
		end

		if not done then
			-- nothing left to skip: pay the player a quest's worth of wins instead
			local winsBefore = GameAnalytics.WinsBefore(player)
			PlayerDataService.AddWins(player, payout(player, 300))
			GameAnalytics.WinsChanged(player, winsBefore, "IAP", "QuestSkip")
		end

		pendingSkip[player] = nil
		return true
	end, function(buyer)
		push(buyer)
		purchaseConfirmed:FireClient(buyer, "QUEST SKIP")
	end)
end)


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
	if state then
		if state.Dirty and state.Loaded then
			saveDaily(player)
		end
		if state.Weekly and state.Weekly.Dirty and state.Weekly.Loaded then
			saveWeekly(player)
		end
	end
	states[player] = nil
	busy[player] = nil
	pendingSkip[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(45)
		for player, state in pairs(states) do
			if state.Dirty and state.Loaded then
				task.spawn(saveDaily, player)
			end
			if state.Weekly and state.Weekly.Dirty and state.Weekly.Loaded then
				task.spawn(saveWeekly, player)
			end
		end
	end
end)

game:BindToClose(function()
	for player, state in pairs(states) do
		if state.Dirty and state.Loaded then
			saveDaily(player)
		end
		if state.Weekly and state.Weekly.Dirty and state.Weekly.Loaded then
			saveWeekly(player)
		end
	end
end)

print("[QuestService] READY")
