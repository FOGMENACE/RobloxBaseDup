--------------------------------------------------
-- GIFT SERVICE
--
-- SERVER ONLY. Owns the timed gift and the daily calendar.
--
-- Timed gift    : claimable every GiftConfig.TimedGift.IntervalSeconds of
--                 play time (session based).
-- Daily calendar: one manual claim per UTC day, 7-day consecutive streak
--                 (GiftConfig.DailyCalendar). Persisted per player in its
--                 own DataStore ("DailyCalendar_v1") so PlayerData_v1's
--                 schema is untouched.
--
-- Rewards are granted ONLY through PlayerDataService / StarterOil. The
-- client can ask to claim; it can never choose a reward, a slot, or
-- skip a cooldown.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local GiftConfig = require(ReplicatedStorage:WaitForChild("GiftConfig"))
local BallDefinitions = require(ServerScriptService:WaitForChild("BallDefinitions"))
local StarterOil = require(ServerScriptService:WaitForChild("StarterOil"))
local PlayerDataService = require(
	ServerScriptService
		:WaitForChild("PlayerDataLoader")
		:WaitForChild("PlayerDataService")
)

local calendarStore = DataStoreService:GetDataStore("DailyCalendar_v1")

local DAY_SECONDS = 24 * 60 * 60
local SLOT_COUNT = #GiftConfig.DailyCalendar.Days

--------------------------------------------------
-- REMOTES
--------------------------------------------------

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

local giftState = getOrCreate("RemoteFunction", "GiftState")
local giftClaim = getOrCreate("RemoteEvent", "GiftClaim")
local giftResult = getOrCreate("RemoteEvent", "GiftResult")

--------------------------------------------------
-- STATE
--------------------------------------------------

-- [player] = { NextTimed, Calendar = {LastDay, Streak, PendingOil} | nil, Busy }
local states = {}

local function today()
	return math.floor(os.time() / DAY_SECONDS)
end

local function calendarKey(player)
	return "Calendar_" .. tostring(player.UserId)
end

local function publishClaimedFlag(player, state)
	local calendar = state.Calendar
	player:SetAttribute(
		"CalendarClaimedToday",
		calendar ~= nil and calendar.LastDay == today()
	)
end

local function loadPlayer(player)
	local state = {
		NextTimed = os.time() + GiftConfig.TimedGift.IntervalSeconds,
		Calendar = nil,
		Busy = false,
	}
	states[player] = state

	local ok, value = pcall(function()
		return calendarStore:GetAsync(calendarKey(player))
	end)

	if not ok then
		warn("[GiftService] Calendar load failed:", player.Name, value)
		return
	end

	local record = typeof(value) == "table" and value or {}
	state.Calendar = {
		LastDay = tonumber(record.LastDay) or 0,
		Streak = tonumber(record.Streak) or 0,
		PendingOil = tonumber(record.PendingOil) or 0,
	}

	StarterOil.Restore(player, state.Calendar.PendingOil)
	publishClaimedFlag(player, state)
end

-- Persist starter oil changes (a run took it, or a claim added it).
StarterOil.Changed:Connect(function(player, amount)
	local state = states[player]
	if not state or not state.Calendar then
		return
	end

	state.Calendar.PendingOil = amount

	task.spawn(function()
		local ok, err = pcall(function()
			calendarStore:UpdateAsync(calendarKey(player), function(old)
				old = typeof(old) == "table" and old or {}
				old.PendingOil = amount
				return old
			end)
		end)

		if not ok then
			warn("[GiftService] Starter oil save failed:", player.Name, err)
		end
	end)
end)

--------------------------------------------------
-- CALENDAR MATH
--------------------------------------------------

-- Which slot (1..SLOT_COUNT) would be claimed next, or nil if today's
-- gift is already claimed.
local function nextSlot(calendar)
	local day = today()

	if calendar.LastDay >= day then
		return nil
	end

	if calendar.LastDay == day - 1 and calendar.Streak > 0 then
		return (calendar.Streak % SLOT_COUNT) + 1
	end

	return 1
end

-- Days of the current streak that are still alive (for the UI).
local function liveStreak(calendar)
	local day = today()

	if calendar.LastDay == day or calendar.LastDay == day - 1 then
		return calendar.Streak
	end

	return 0
end

--------------------------------------------------
-- GRANT
--------------------------------------------------

local function nextUnownedBall(player)
	local candidates = {}

	for ballId, definition in pairs(BallDefinitions) do
		if ballId ~= PlayerDataService.GetDefaultBallId()
			and definition.IsTutorial ~= true
			and definition.IsExclusive ~= true
			and not PlayerDataService.OwnsBall(player, ballId) then
			table.insert(candidates, { Id = ballId, Order = definition.DisplayOrder or 0 })
		end
	end

	table.sort(candidates, function(a, b)
		return a.Order < b.Order
	end)

	return candidates[1] and candidates[1].Id or nil
end

-- Returns the reward that was actually granted (BallNext resolved to a
-- real ball id), or nil if it could not be granted.
local function grant(player, reward)
	if reward.Type == "Wins" then
		return PlayerDataService.AddWins(player, reward.Amount) and reward or nil

	elseif reward.Type == "Oil" then
		StarterOil.Add(player, reward.Amount)
		return reward

	elseif reward.Type == "Ball" then
		return PlayerDataService.AddOwnedBall(player, reward.BallId) and reward or nil

	elseif reward.Type == "BallNext" then
		local ballId = nextUnownedBall(player)
		if not ballId then
			-- Owns everything: fall back to a Wins make-good.
			local fallback = { Type = "Wins", Amount = 5000 }
			return PlayerDataService.AddWins(player, fallback.Amount) and fallback or nil
		end

		return PlayerDataService.AddOwnedBall(player, ballId)
			and { Type = "Ball", BallId = ballId }
			or nil

	elseif reward.Type == "Rebirth" then
		return PlayerDataService.GrantRebirth(player) and reward or nil
	end

	warn("[GiftService] Unknown reward type:", reward.Type)
	return nil
end

--------------------------------------------------
-- STATE FOR THE CLIENT
--------------------------------------------------

giftState.OnServerInvoke = function(player)
	local state = states[player]
	if not state then
		return nil
	end

	local result = {
		Timed = math.max(0, state.NextTimed - os.time()),
	}

	local calendar = state.Calendar
	if calendar then
		local slot = nextSlot(calendar)

		result.Calendar = {
			Streak = liveStreak(calendar),
			NextSlot = slot, -- nil when already claimed today
			SecondsToNext = slot and 0
				or ((today() + 1) * DAY_SECONDS - os.time()),
		}
	end

	return result
end

--------------------------------------------------
-- CLAIM
--------------------------------------------------

local function claimTimed(player, state)
	if state.NextTimed - os.time() > 0 then
		return false, "Not ready yet."
	end

	-- Set the next window first so a repeated request cannot double-claim.
	state.NextTimed = os.time() + GiftConfig.TimedGift.IntervalSeconds

	local granted = grant(player, GiftConfig.TimedGift.Reward)
	if not granted then
		state.NextTimed = os.time()
		return false, "Could not grant the gift. Try again."
	end

	return true, granted
end

local function claimDaily(player, state)
	local calendar = state.Calendar
	if not calendar then
		return false, "The calendar is unavailable right now. Try again soon."
	end

	if not nextSlot(calendar) then
		return false, "Already claimed today."
	end

	local day = today()
	local slotClaimed = nil

	-- Atomic claim: the DataStore decides, so a second server or a
	-- rapid double click can never hand out the same day twice. The
	-- claim is saved BEFORE the reward is granted.
	local ok, err = pcall(function()
		calendarStore:UpdateAsync(calendarKey(player), function(old)
			old = typeof(old) == "table" and old or {}

			local record = {
				LastDay = tonumber(old.LastDay) or 0,
				Streak = tonumber(old.Streak) or 0,
				PendingOil = tonumber(old.PendingOil) or 0,
			}

			local slot = nextSlot(record)
			if not slot then
				slotClaimed = nil
				return nil -- already claimed elsewhere
			end

			slotClaimed = slot
			record.LastDay = day
			record.Streak = slot

			local reward = GiftConfig.DailyCalendar.Days[slot]
			if reward.Type == "Oil" then
				record.PendingOil += reward.Amount
			end

			return record
		end)
	end)

	if not ok then
		warn("[GiftService] Calendar claim failed:", player.Name, err)
		return false, "Could not save your gift. Try again."
	end

	if not slotClaimed then
		return false, "Already claimed today."
	end

	calendar.LastDay = day
	calendar.Streak = slotClaimed
	publishClaimedFlag(player, state)

	local reward = GiftConfig.DailyCalendar.Days[slotClaimed]

	if reward.Type == "Oil" then
		-- Already persisted in the claim record above; mirror it in memory
		-- without writing a second time.
		calendar.PendingOil += reward.Amount
		StarterOil.Restore(player, calendar.PendingOil)
		return true, reward, slotClaimed
	end

	local granted = grant(player, reward)
	if not granted then
		warn("[GiftService] Calendar claimed but grant failed:", player.Name, reward.Type)
		return false, "Could not grant the gift. Contact support."
	end

	return true, granted, slotClaimed
end

giftClaim.OnServerEvent:Connect(function(player, kind)
	local state = states[player]
	if not state or state.Busy then
		return
	end

	if kind ~= "Timed" and kind ~= "Daily" then
		return
	end

	state.Busy = true

	local success, result, slot
	if kind == "Timed" then
		success, result = claimTimed(player, state)
	else
		success, result, slot = claimDaily(player, state)
	end

	state.Busy = false

	giftResult:FireClient(player, kind, success, result, slot)
end)

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
	StarterOil.Clear(player)
end)

print("[GiftService] READY | Timed:", GiftConfig.TimedGift.IntervalSeconds, "s | Calendar slots:", SLOT_COUNT)
