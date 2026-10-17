--------------------------------------------------
-- LIMITED GENERATOR (GenX6) - SERVER ONLY MODULE
--
-- The x6 generator only pays out while the player has an ACTIVE boost,
-- and a boost has to be claimed by clicking CLAIM in the hub:
--
--   chance 1: becomes claimable 14 minutes after the player's first
--             join of the day
--   chance 2: becomes claimable 7 minutes after chance 1's boost ends
--   after the last chance: "back tomorrow" (resets at UTC midnight)
--
-- Each boost lasts CHANCES[n].Duration seconds.
--
-- Protections:
--   * all timers are server time (os.time), never client-supplied
--   * progress is saved in its own DataStore ("LimitedGen_v1") with
--     absolute timestamps, so leaving and rejoining never resets a wait
--     or grants a second boost
--   * a claim is validated against the real state and saved BEFORE the
--     boost starts; the physics code asks IsActive() every frame (a
--     cached, non-yielding read)
--
-- Edit CHANCES to change the waits or durations.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local CHANCES = {
	{ Wait = 14 * 60, Duration = 3 * 60 },
	{ Wait = 7 * 60, Duration = 3 * 60 },
}

local DAY_SECONDS = 24 * 60 * 60

local store = DataStoreService:GetDataStore("LimitedGen_v1")

local LimitedGenerator = {}

--------------------------------------------------
-- REMOTES
--------------------------------------------------

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function getOrCreate(name)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end

	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = remotes
	return created
end

local claimRemote = getOrCreate("X6Claim")
local resultRemote = getOrCreate("X6Result")

--------------------------------------------------
-- STATE
--------------------------------------------------

local states = {} -- [player] = { Day, Used, NextReady, ActiveUntil, Loaded, Busy }

local function today()
	return math.floor(os.time() / DAY_SECONDS)
end

local function freshRecord()
	return {
		Day = today(),
		Used = 0,
		NextReady = os.time() + CHANCES[1].Wait,
		ActiveUntil = 0,
	}
end

local function keyFor(player)
	return "X6_" .. tostring(player.UserId)
end

-- Waiting / Ready / Active / Done
local function modeOf(state)
	local now = os.time()

	if now < state.ActiveUntil then
		return "Active"
	end

	if state.Used >= #CHANCES then
		return "Done"
	end

	if now < state.NextReady then
		return "Waiting"
	end

	return "Ready"
end

local function untilOf(state, mode)
	if mode == "Active" then
		return state.ActiveUntil
	elseif mode == "Waiting" then
		return state.NextReady
	elseif mode == "Done" then
		return (today() + 1) * DAY_SECONDS
	end
	return 0
end

local function publish(player, state)
	local mode = modeOf(state)
	local untilTime = untilOf(state, mode)

	if player:GetAttribute("X6Mode") ~= mode then
		player:SetAttribute("X6Mode", mode)
	end
	if player:GetAttribute("X6Until") ~= untilTime then
		player:SetAttribute("X6Until", untilTime)
	end
end

local function save(player, state)
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), {
			Day = state.Day,
			Used = state.Used,
			NextReady = state.NextReady,
			ActiveUntil = state.ActiveUntil,
		})
	end)

	if not ok then
		warn("[LimitedGenerator] Save failed:", player.Name, err)
	end

	return ok
end

local function loadPlayer(player)
	local state = freshRecord()
	state.Loaded = false
	state.Busy = false
	states[player] = state

	local ok, value = pcall(function()
		return store:GetAsync(keyFor(player))
	end)

	if not ok then
		warn("[LimitedGenerator] Load failed:", player.Name, value)
		return
	end

	if typeof(value) == "table" and tonumber(value.Day) == today() then
		state.Day = value.Day
		state.Used = tonumber(value.Used) or 0
		state.NextReady = tonumber(value.NextReady) or state.NextReady
		state.ActiveUntil = tonumber(value.ActiveUntil) or 0
	else
		-- A new day: fresh chances, and remember them right away.
		save(player, state)
	end

	state.Loaded = true
	publish(player, state)
end

--------------------------------------------------
-- QUERY (non-yielding; used by the XP code every frame)
--------------------------------------------------

function LimitedGenerator.IsActive(player)
	local state = states[player]
	return state ~= nil and state.Loaded and modeOf(state) == "Active"
end

--------------------------------------------------
-- CLAIM
--------------------------------------------------

claimRemote.OnServerEvent:Connect(function(player)
	local state = states[player]
	if not state or not state.Loaded or state.Busy then
		return
	end

	-- Day rollover while the player stayed in the server.
	if state.Day ~= today() then
		local fresh = freshRecord()
		state.Day, state.Used = fresh.Day, fresh.Used
		state.NextReady, state.ActiveUntil = fresh.NextReady, fresh.ActiveUntil
	end

	if modeOf(state) ~= "Ready" then
		resultRemote:FireClient(player, false, "Not ready yet.")
		publish(player, state)
		return
	end

	state.Busy = true

	local chance = CHANCES[state.Used + 1]
	local nextChance = CHANCES[state.Used + 2]
	local now = os.time()

	local updated = {
		Day = state.Day,
		Used = state.Used + 1,
		ActiveUntil = now + chance.Duration,
		NextReady = nextChance and (now + chance.Duration + nextChance.Wait) or math.huge,
	}

	-- Save first; the boost only starts if the claim was recorded.
	local ok = pcall(function()
		store:SetAsync(keyFor(player), {
			Day = updated.Day,
			Used = updated.Used,
			NextReady = updated.NextReady == math.huge and 0 or updated.NextReady,
			ActiveUntil = updated.ActiveUntil,
		})
	end)

	if not ok then
		state.Busy = false
		resultRemote:FireClient(player, false, "Could not save your boost. Try again.")
		return
	end

	state.Used = updated.Used
	state.ActiveUntil = updated.ActiveUntil
	state.NextReady = updated.NextReady
	state.Busy = false

	publish(player, state)
	resultRemote:FireClient(player, true, chance.Duration)
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
end)

-- Keep the published attributes current (and roll the day over).
task.spawn(function()
	while true do
		task.wait(1)

		for player, state in pairs(states) do
			if state.Loaded and player.Parent then
				if state.Day ~= today() and modeOf(state) ~= "Active" then
					local fresh = freshRecord()
					state.Day, state.Used = fresh.Day, fresh.Used
					state.NextReady, state.ActiveUntil = fresh.NextReady, fresh.ActiveUntil
					save(player, state)
				end

				publish(player, state)
			end
		end
	end
end)

return LimitedGenerator
