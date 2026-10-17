--------------------------------------------------
-- TUTORIAL SERVICE
--
-- SERVER ONLY. Decides which tutorial step a player is on from
-- SERVER facts (run state, owned balls, rebirths, calendar claim),
-- saves it in its own DataStore ("Tutorial_v1"), and publishes it as
-- the player attribute "TutorialStep" for the client to display.
-- The client never advances the tutorial.
--
-- Steps:
--   1  Roll onto the START wall to begin a course
--   2  Finish the course (RunState returns to Waiting)
--   3  Buy the tutorial ball (Aftershock) at the shop pad
--   4  Roll onto the X1 XP generator
--   5  Earn your first rebirth
--   6  Claim the daily calendar
--   7  Done (no more prompts)
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
local DONE = 7

-- [player] = { Step = n, Loaded = bool }
local states = {}

local function key(player)
	return "Tutorial_" .. tostring(player.UserId)
end

local function setStep(player, state, step)
	if state.Step == step then
		return
	end

	state.Step = step
	player:SetAttribute("TutorialStep", step)

	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(key(player), { Step = step })
		end)

		if not ok then
			warn("[TutorialService] Save failed:", player.Name, err)
		end
	end)
end

local function loadPlayer(player)
	local state = { Step = 0, Loaded = false }
	states[player] = state

	local ok, value = pcall(function()
		return store:GetAsync(key(player))
	end)

	if not ok then
		warn("[TutorialService] Load failed:", player.Name, value)
		return
	end

	local step = typeof(value) == "table" and tonumber(value.Step) or 1
	step = math.clamp(step, 1, DONE)

	-- Veterans (already rebirthed) never see the tutorial.
	local waited = 0
	while waited < 15 and player.Parent and not PlayerDataService.GetData(player) do
		task.wait(0.5)
		waited += 0.5
	end

	if PlayerDataService.GetRebirths(player) >= 1 then
		step = DONE
	end

	state.Loaded = true
	state.Step = -1 -- force publish
	setStep(player, state, step)
end

local function tick(player, state)
	if not state.Loaded or state.Step >= DONE then
		return
	end

	local runState = player:GetAttribute("RunState")
	local step = state.Step

	if step == 1 then
		if typeof(runState) == "string" and runState ~= "Waiting" and runState ~= "" then
			setStep(player, state, 2)
		end

	elseif step == 2 then
		-- Course complete = the run state came back to the lobby.
		if runState == "Waiting" then
			setStep(player, state, 3)
		end

	end

	-- Steps 3..6 are facts, so a player who is already past one skips it.
	step = state.Step
	if step == 3 and PlayerDataService.OwnsBall(player, TUTORIAL_BALL) then
		setStep(player, state, 4)
		step = 4
	end

	if step == 4 and player:GetAttribute("ActiveXPGenerator") == FIRST_GENERATOR then
		setStep(player, state, 5)
		step = 5
	end

	if step == 5 and PlayerDataService.GetRebirths(player) >= 1 then
		setStep(player, state, 6)
		step = 6
	end

	if step == 6 and player:GetAttribute("CalendarClaimedToday") == true then
		setStep(player, state, DONE)
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
