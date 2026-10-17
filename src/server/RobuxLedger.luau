--------------------------------------------------
-- ROBUX LEDGER (SERVER ONLY MODULE)
--
-- Adds Robux a player has spent to the "ROBUX SPENT" leaderboard
-- (OrderedDataStore "LB_RobuxSpent_v1"). It only records numbers that
-- the server itself reported (a developer product receipt's
-- CurrencySpent, or a game pass price looked up from Roblox). It can
-- never block or fail a purchase: every write is fire-and-forget.
--------------------------------------------------

local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetOrderedDataStore("LB_RobuxSpent_v1")

local RobuxLedger = {}

function RobuxLedger.Add(userId, amount)
	amount = math.floor(tonumber(amount) or 0)
	if typeof(userId) ~= "number" or amount <= 0 then
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			store:IncrementAsync(tostring(userId), amount)
		end)

		if not ok then
			warn("[RobuxLedger] Could not record Robux spent:", userId, amount, err)
		end
	end)
end

return RobuxLedger
