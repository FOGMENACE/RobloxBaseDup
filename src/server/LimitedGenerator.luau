--------------------------------------------------
-- LIMITED GENERATOR (GenX6) - SERVER ONLY MODULE
--
-- The x6 generator only pays out while the player has an ACTIVE boost.
-- Offers repeat all session long (no daily cap):
--
--   Waiting : a random 7 - 14 minute wait
--   Ready   : a FREE claim popup is offered for CLAIM_WINDOW seconds
--             (missed? the next offer is rescheduled with a new wait)
--   Active  : the boost lasts BOOST_SECONDS, then the cycle restarts
--
-- Protections:
--   * all timers are server time (os.time), never client-supplied
--   * state is saved in its own DataStore ("LimitedGen_v1") with absolute
--     timestamps, so leaving and rejoining never skips a wait or grants
--     a second boost
--   * a claim is validated against the real state and saved BEFORE the
--     boost starts; the physics code asks IsActive() every frame (a
--     cached, non-yielding read)
--
-- Edit the constants below to change the waits or durations.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local WAIT_MIN = 7 * 60
local WAIT_MAX = 14 * 60
local CLAIM_WINDOW = 120
local BOOST_SECONDS = 3 * 60

local store = DataStoreService:GetDataStore("LimitedGen_v1")
local rng = Random.new()

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

local states = {} -- [player] = { NextReady, ReadyUntil, ActiveUntil, Loaded, Busy }

local function newOffer(from)
	local nextReady = from + rng:NextInteger(WAIT_MIN, WAIT_MAX)
	return nextReady, nextReady + CLAIM_WINDOW
end

local function freshRecord()
	local nextReady, readyUntil = newOffer(os.time())
	return { NextReady = nextReady, ReadyUntil = readyUntil, ActiveUntil = 0 }
end

local function keyFor(player)
	return "X6_" .. tostring(player.UserId)
end

-- Waiting / Ready / Active
local function modeOf(state)
	local now = os.time()

	if now < state.ActiveUntil then
		return "Active"
	end

	if now < state.NextReady then
		return "Waiting"
	end

	if now < state.ReadyUntil then
		return "Ready"
	end

	return "Missed" -- the updater loop reschedules this right away
end

local function untilOf(state, mode)
	if mode == "Active" then
		return state.ActiveUntil
	elseif mode == "Waiting" then
		return state.NextReady
	elseif mode == "Ready" then
		return state.ReadyUntil
	end
	return 0
end

local function publish(player, state)
	local mode = modeOf(state)
	if mode == "Missed" then
		mode = "Waiting"
	end
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
			NextReady = state.NextReady,
			ReadyUntil = state.ReadyUntil,
			ActiveUntil = state.ActiveUntil,
		})
	end)

	if not ok then
		warn("[LimitedGenerator] Save failed:", player.Name, err)
	end

	return ok
end

local function reschedule(player, state)
	state.NextReady, state.ReadyUntil = newOffer(os.time())
	save(player, state)
end

local function loadPlayer(player)
	local state = freshRecord()
	state.Loaded = false
	state.Busy = false
	states[player] = state

	require(game:GetService("ServerScriptService"):WaitForChild("SessionGate")).Wait(player)

	local ok, value = require(game:GetService("ServerScriptService"):WaitForChild("DataRetry")).Get(store, keyFor(player))

	if not ok then
		warn("[LimitedGenerator] Load failed:", player.Name, value)
		return
	end

	if typeof(value) == "table" and tonumber(value.NextReady) and tonumber(value.ReadyUntil) then
		state.NextReady = tonumber(value.NextReady)
		state.ReadyUntil = tonumber(value.ReadyUntil)
		state.ActiveUntil = tonumber(value.ActiveUntil) or 0
	else
		save(player, state)
	end

	if modeOf(state) == "Missed" then
		reschedule(player, state)
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

	-- the free gifts are not part of the tutorial: no claims until it is finished
	if (player:GetAttribute("TutorialStep") or 0) < 12 then
		resultRemote:FireClient(player, false, "Finish the tutorial first.")
		return
	end

	if modeOf(state) ~= "Ready" then
		resultRemote:FireClient(player, false, "Not ready yet.")
		publish(player, state)
		return
	end

	state.Busy = true

	local now = os.time()
	local activeUntil = now + BOOST_SECONDS
	local nextReady, readyUntil = newOffer(activeUntil)

	-- Save first; the boost only starts if the claim was recorded.
	local ok = pcall(function()
		store:SetAsync(keyFor(player), {
			NextReady = nextReady,
			ReadyUntil = readyUntil,
			ActiveUntil = activeUntil,
		})
	end)

	if not ok then
		state.Busy = false
		resultRemote:FireClient(player, false, "Could not save your boost. Try again.")
		return
	end

	state.ActiveUntil = activeUntil
	state.NextReady = nextReady
	state.ReadyUntil = readyUntil
	state.Busy = false

	publish(player, state)
	resultRemote:FireClient(player, true, BOOST_SECONDS)
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

-- Keep the published attributes current and reschedule missed offers.
task.spawn(function()
	while true do
		task.wait(1)

		for player, state in pairs(states) do
			if state.Loaded and player.Parent then
				if modeOf(state) == "Missed" then
					reschedule(player, state)
				end

				publish(player, state)
			end
		end
	end
end)

return LimitedGenerator
