--------------------------------------------------
-- GAME PASS SERVICE (SERVER ONLY MODULE)
--
-- Ownership is read from Roblox (UserOwnsGamePassAsync) on join and
-- re-verified whenever a purchase prompt finishes. The client's
-- "purchased" flag is never trusted: it only triggers a server check.
--
-- Results are cached in memory so physics code can query them every
-- frame without yielding. Only the best multiplier is replicated, so
-- the multiplier total is published as PassXPMultiplier (display only).
--------------------------------------------------

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local GamePassConfig = require(script.Parent:WaitForChild("GamePassConfig"))

local GamePassService = {}

local owned = {} -- [player] = { [gamePassId] = true }

local function checkPass(player, passId)
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)

	if not ok then
		warn("[GamePassService] Ownership check failed:", player.Name, passId, result)
		return nil
	end

	return result == true
end

local function allPassIds()
	local ids = {}

	for _, id in pairs(GamePassConfig.AdminGenerators) do
		table.insert(ids, id)
	end

	for id in pairs(GamePassConfig.SecretMultipliers) do
		table.insert(ids, id)
	end

	for _, perWorld in pairs(GamePassConfig.WorldAdminGenerators or {}) do
		for _, id in pairs(perWorld) do
			if id ~= 0 then
				table.insert(ids, id)
			end
		end
	end

	return ids
end

local function loadPlayer(player)
	owned[player] = owned[player] or {}

	for _, passId in ipairs(allPassIds()) do
		local result = checkPass(player, passId)
		if result == true and owned[player] then
			owned[player][passId] = true
		end
	end
end

--------------------------------------------------
-- QUERIES (non-yielding, cache only)
--------------------------------------------------

function GamePassService.Owns(player, passId)
	local set = owned[player]
	return set ~= nil and set[passId] == true
end

-- Can this player earn XP on the named admin generator?
-- worldId > 1 uses that world's own (stronger) admin pass; 0 = not on sale yet.
function GamePassService.OwnsAdminGenerator(player, generatorName, worldId)
	local passId = GamePassConfig.AdminGenerators[generatorName]
	if worldId and worldId > 1 then
		local perWorld = GamePassConfig.WorldAdminGenerators and GamePassConfig.WorldAdminGenerators[worldId]
		passId = perWorld and perWorld[generatorName]
	end
	return passId ~= nil and passId ~= 0 and GamePassService.Owns(player, passId)
end

-- Highest silent XP multiplier the player owns (1 = none).
function GamePassService.GetSecretMultiplier(player)
	local best = 1

	for passId, multiplier in pairs(GamePassConfig.SecretMultipliers) do
		if multiplier > best and GamePassService.Owns(player, passId) then
			best = multiplier
		end
	end

	return best
end


-- Published for the HUD only (display); the physics code reads the cache.
local function publish(player)
	if player.Parent then
		player:SetAttribute("PassXPMultiplier", GamePassService.GetSecretMultiplier(player))
	end
end
--------------------------------------------------
-- LIFECYCLE
--------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		loadPlayer(player)
		publish(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadPlayer(player)
		publish(player)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	owned[player] = nil
end)

-- A purchase just finished. Do not trust `purchased`; ask Roblox.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end

	local isKnown = GamePassConfig.SecretMultipliers[passId] ~= nil
	for _, id in ipairs(allPassIds()) do
		if id == passId then
			isKnown = true
		end
	end

	if not isKnown then
		return
	end

	task.spawn(function()
		local wasOwned = GamePassService.Owns(player, passId)

		if checkPass(player, passId) == true and owned[player] then
			owned[player][passId] = true
			publish(player)

			-- A brand-new purchase: count its price for the ROBUX SPENT board.
			if not wasOwned then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
				end)

				if ok and typeof(info) == "table" and info.PriceInRobux then
					require(script.Parent:WaitForChild("RobuxLedger")).Add(
						player.UserId,
						info.PriceInRobux
					)
				end
			end
		end
	end)
end)

return GamePassService
