--------------------------------------------------
-- NEXT GOAL (SERVER)
--
-- When a run ends, works out the cheapest thing the player can chase next and
-- publishes it for the small hint in WinCelebration:
--   NextGoalBall      display name of the ball (world 1) or skin (higher worlds)
--   NextGoalWinsLeft  wins still needed (0 = can buy it now)
--   NextGoalRun       bumped each time, so the client knows a run just ended
-- Display only: buying still goes through BallService / SkinService.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local BallDefinitions = require(ServerScriptService:WaitForChild("BallDefinitions"))
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService"))

-- the Wins price of the next thing to buy for this ball, or nil if it is not a goal
local function goalCost(player, ballId, definition, worldId, rebirths)
	local cost = tonumber(definition.WinsCost)
	if worldId <= 1 then
		if definition.IsExclusive == true or not cost or cost <= 0
			or (tonumber(definition.RequiredRebirths) or 0) > rebirths
			or PlayerDataService.OwnsBall(player, ballId) then
			return nil
		end
		return cost
	end
	-- a higher world: its skin of a ball the player owns (the Wins route needs the original)
	if not PlayerDataService.OwnsBall(player, ballId) or WorldConfig.OwnsSkin(player, ballId, worldId) then
		return nil
	end
	return tonumber(WorldConfig.SkinWinsCost(ballId, worldId, cost))
end

local function publish(player)
	local worldId = player:GetAttribute("World") or 1
	local rebirths = PlayerDataService.GetRebirths(player) or 0
	local wins = PlayerDataService.GetWins(player) or 0

	local bestName, bestCost = nil, math.huge
	for ballId, definition in pairs(BallDefinitions) do
		local cost = goalCost(player, ballId, definition, worldId, rebirths)
		if cost and cost < bestCost then
			bestName, bestCost = definition.DisplayName, cost
		end
	end

	player:SetAttribute("NextGoalBall", bestName)
	player:SetAttribute("NextGoalWinsLeft", bestName and math.max(0, bestCost - wins) or nil)
	player:SetAttribute("NextGoalRun", (player:GetAttribute("NextGoalRun") or 0) + 1)
end

local function watch(player)
	local last = player:GetAttribute("RunState")
	player:GetAttributeChangedSignal("RunState"):Connect(function()
		local state = player:GetAttribute("RunState")
		if state == "Waiting" and last ~= nil and last ~= "Waiting" then
			local ok, err = pcall(publish, player)
			if not ok then
				warn("[NextGoalService]", player.Name, err)
			end
		end
		last = state
	end)
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
