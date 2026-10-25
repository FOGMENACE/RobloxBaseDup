--------------------------------------------------
-- TUTORIAL SERVICE
--
-- SERVER ONLY. Decides which tutorial step a player is on from SERVER
-- facts (run state, level, rebirths, owned / equipped balls, calendar
-- claim), saves it in its own DataStore ("Tutorial_v1"), and publishes it
-- as the player attribute "TutorialStep" for the client to display.
-- The client never advances the tutorial and the steps grant nothing.
--
-- Steps:
--    1  Roll onto the START wall to begin the first course
--    2  Finish the course (RunState returns to Waiting)
--    3  Stand on the X1 XP generator until the first level-up (max level)
--    4  Press REBIRTH in the hub (FREE: x1 oil -> x2 oil)
--    5  Roll again (start)
--    6  Finish that roll
--    7  Buy the tutorial ball (Aftershock) at the shop
--    8  Equip it
--    9  Roll again (start)
--   10  Finish that roll
--   11  The daily calendar appears: claim day 1
--   12  Done (no more prompts)
--
-- The hub's REBIRTH button is hidden until step 4 and the daily calendar
-- until step 11 (HubUI reads the same attribute).
--------------------------------------------------

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local PlayerDataService = require(
	ServerScriptService
		:WaitForChild("PlayerDataLoader")
		:WaitForChild("PlayerDataService")
)

local store = DataStoreService:GetDataStore("Tutorial_v1")

local TUTORIAL_BALL = "Aftershock"
local FIRST_GENERATOR = "GenX1"
local DONE = 12
local VERSION = 2

-- [player] = { Step = n, Loaded = bool }
local states = {}

local function key(player)
	return "Tutorial_" .. tostring(player.UserId)
end

local function save(player, step)
	task.spawn(function()
		-- retried, so a DataStore hiccup does not lose the player's tutorial progress
		for attempt = 1, 4 do
			local ok, err = pcall(function()
				store:SetAsync(key(player), { Step = step, Version = VERSION })
			end)

			if ok then
				return
			end

			warn("[TutorialService] Save failed (attempt " .. attempt .. "):", player.Name, err)
			task.wait(2 * attempt)
		end
	end)
end

local function setStep(player, state, step)
	if state.Step == step then
		return
	end

	state.Step = step
	state.StepAt = os.clock()
	player:SetAttribute("TutorialStep", step)
	save(player, step)
end

local function isRolling(player)
	local runState = player:GetAttribute("RunState")
	return typeof(runState) == "string" and runState ~= "Waiting" and runState ~= ""
end

local function loadPlayer(player)
	local state = { Step = 0, Loaded = false }
	states[player] = state

	require(game:GetService("ServerScriptService"):WaitForChild("SessionGate")).Wait(player)

	local ok, value = pcall(function()
		return store:GetAsync(key(player))
	end)

	if not ok then
		warn("[TutorialService] Load failed:", player.Name, value)
		-- Never hide the hub because the DataStore hiccuped: show everything
		-- for this session (nothing is saved, so the tutorial is not lost).
		state.Loaded = true
		state.Step = DONE
		player:SetAttribute("TutorialStep", DONE)
		return
	end

	-- wait for the player's data so facts (rebirths, balls) are real
	local waited = 0
	while waited < 15 and player.Parent and not PlayerDataService.GetData(player) do
		task.wait(0.5)
		waited += 0.5
	end

	local rebirths = PlayerDataService.GetRebirths(player)
	local step = 1

	if typeof(value) == "table" and tonumber(value.Step) then
		step = math.floor(value.Step)

		-- saves from the first tutorial version (7 steps; 7 = done)
		if value.Version ~= VERSION then
			step = (step >= 7) and DONE or 1
		end
	end

	step = math.clamp(step, 1, DONE)

	-- Steps 2, 6 and 10 mean "a run is in progress". If the player left during one,
	-- they come back in the lobby and would instantly count as having finished it,
	-- so rewind them to the step that starts that run.
	if step == 2 then
		step = 1
	elseif step == 6 then
		step = 5
	elseif step == 10 then
		step = 9
	end

	-- Veterans (rebirthed before this tutorial existed, or past it) never
	-- see the early steps again.
	if rebirths >= 1 and step < 5 then
		step = (rebirths >= 2) and DONE or 5
	end

	state.Loaded = true
	state.Step = -1 -- force publish
	setStep(player, state, step)
end

local function tick(player, state)
	if not state.Loaded or state.Step >= DONE then
		return
	end

	local step = state.Step
	local rolling = isRolling(player)

	if step == 1 then
		if rolling then
			setStep(player, state, 2)
		end

	elseif step == 2 then
		if not rolling then
			setStep(player, state, 3)
		end

	elseif step == 3 then
		-- first level-up reached = the bar is full and rebirth is possible
		if player:GetAttribute("RebirthMaxReached") == true then
			setStep(player, state, 4)
		end

	elseif step == 4 then
		if PlayerDataService.GetRebirths(player) >= 1 then
			setStep(player, state, 5)
		end

	elseif step == 5 then
		if rolling then
			setStep(player, state, 6)
		end

	elseif step == 6 then
		if not rolling then
			setStep(player, state, 7)
		end

	elseif step == 7 then
		if PlayerDataService.OwnsBall(player, TUTORIAL_BALL) then
			setStep(player, state, 8)
		end

	elseif step == 8 then
		if player:GetAttribute("EquippedBall") == TUTORIAL_BALL then
			setStep(player, state, 9)
		end

	elseif step == 9 then
		if rolling then
			setStep(player, state, 10)
		end

	elseif step == 10 then
		if not rolling then
			setStep(player, state, 11)
		end

	elseif step == 11 then
		-- Done once today's gift is claimed. If the calendar cannot be claimed for any reason (it did not
		-- load, or the record is out of step), the tutorial must never trap the player: after two
		-- minutes on this step it simply finishes. It grants nothing, so there is nothing to abuse.
		if player:GetAttribute("CalendarClaimedToday") == true
			or os.clock() - (state.StepAt or os.clock()) > 120 then
			setStep(player, state, DONE)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		for player, state in pairs(states) do
			if player.Parent then
				tick(player, state)
			end
		end
	end
end)

print("[TutorialService] READY")

-- Used by the admin `reset` command: the player (online or offline) starts
-- the tutorial again from step 1.
local resetEvent = Instance.new("BindableEvent")
resetEvent.Name = "TutorialReset"
resetEvent.Parent = ServerScriptService

resetEvent.Event:Connect(function(userId)
	if typeof(userId) ~= "number" then
		return
	end

	local online = Players:GetPlayerByUserId(userId)
	local state = online and states[online]

	if online and state then
		state.Loaded = true
		state.Step = -1
		setStep(online, state, 1)
	else
		pcall(function()
			store:SetAsync("Tutorial_" .. tostring(userId), { Step = 1, Version = VERSION })
		end)
	end
end)
