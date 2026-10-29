--------------------------------------------------
-- WORLD BALL SPEED (SERVER ONLY MODULE)
--
-- A ball runs at full speed in world 1, and in a higher world only when the player
-- owns that ball's evolved skin FOR THAT WORLD. A ball brought in from another world
-- (no skin for this one) still works but rolls at the STARTER ball's speed, so the
-- player feels that this world wants its own ball, without being told.
--
-- Ownership is read from the server-set "Skins" attribute (SkinService) and the
-- player's server-set "World" attribute; nothing comes from the client.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local BallDefinitions = require(ServerScriptService:WaitForChild("BallDefinitions"))

local STARTER_BALL = "StraightBall"

local WorldBallSpeed = {}

function WorldBallSpeed.StarterSpeed()
	local starter = BallDefinitions[STARTER_BALL]
	return starter and starter.ForwardSpeed or 50
end

-- true when this ball is "at home" in the player's current world
function WorldBallSpeed.Fits(player, ballId)
	local worldId = player and player:GetAttribute("World") or 1
	if typeof(worldId) ~= "number" or worldId <= 1 then
		return true
	end
	if ballId == STARTER_BALL then
		return true
	end
	return typeof(ballId) == "string" and WorldConfig.OwnsSkin(player, ballId, worldId)
end

-- the speed a ball really rolls at for its owner right now
function WorldBallSpeed.Effective(player, ballId, fullSpeed)
	if WorldBallSpeed.Fits(player, ballId) then
		return fullSpeed
	end
	return math.min(fullSpeed, WorldBallSpeed.StarterSpeed())
end

-- convenience for a ball part (BallId + OwnerUserId attributes are server-set)
function WorldBallSpeed.ForBall(ball, fullSpeed)
	local owner = Players:GetPlayerByUserId(ball:GetAttribute("OwnerUserId") or 0)
	if not owner then
		return fullSpeed
	end
	return WorldBallSpeed.Effective(owner, ball:GetAttribute("BallId"), fullSpeed)
end

return WorldBallSpeed
