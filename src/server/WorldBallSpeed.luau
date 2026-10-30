--------------------------------------------------
-- WORLD BALL SPEED (SERVER ONLY MODULE)
--
-- A ball runs at full speed in world 1, and in a higher world only when the player
-- owns that ball's evolved skin FOR THAT WORLD. A ball brought in from another world
-- (no skin for this one) still works but rolls at the STARTER ball's speed, so the
-- player feels that this world wants its own ball, without being told.
--
-- A RE-THEMED ball taken to any world it has no skin for (it wears another world's
-- skin, higher or lower; the look stays with it, see WorldBallStyle) is braked on
-- the courses (Slowdown): just under the slowest ball on the oil course, a slower
-- WinCourse roll and a shorter WinCourse travel, so balls are worth the most in
-- their own world and a skinned ball never outruns that world's players. Everywhere
-- else (the lobby and its XP) it counts as the starter ball, like any off-world ball.
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

-- a re-themed ball outside its own world rolls the course 5 studs/s under the slowest
-- ball's cruise speed (52) and never speeds up; Slowdown is that share of the cruise
local COURSE_CRUISE_SPEED = 52 -- BallPhysicsController's cruise
local OFF_WORLD_UNDER_SLOWEST = 5
local OFF_WORLD_SHARE = (COURSE_CRUISE_SPEED - OFF_WORLD_UNDER_SLOWEST) / COURSE_CRUISE_SPEED
-- On the WinCourse its oil burns off much faster: it carries the ball only 60 % as far
-- as the same oil carries the starter ball (so far fewer wins), and the roll plays a
-- little slower (80 %) so the meter visibly drains instead of flashing empty
local OFF_WORLD_WIN_TRAVEL = 0.6
local OFF_WORLD_WIN_ROLL = 0.8

local WorldBallSpeed = {}

function WorldBallSpeed.StarterSpeed()
	local starter = BallDefinitions[STARTER_BALL]
	return starter and starter.ForwardSpeed or 50
end

local function worldOf(player)
	local worldId = player and player:GetAttribute("World") or 1
	return typeof(worldId) == "number" and worldId or 1
end

-- true when the ball wears ANOTHER world's skin (higher or lower) and has no skin for this world
function WorldBallSpeed.RethemedAway(player, ballId)
	if typeof(ballId) ~= "string" then
		return false
	end
	local worldId = worldOf(player)
	if WorldConfig.OwnsSkin(player, ballId, worldId) then
		return false
	end
	for _, world in ipairs(WorldConfig.Worlds) do
		if world.Id ~= worldId and WorldConfig.OwnsSkin(player, ballId, world.Id) then
			return true
		end
	end
	return false
end

-- the share of the course cruise speed a re-themed ball keeps outside its own world
-- (nil = no brake); the same share slows its WinCourse roll and shortens its travel
function WorldBallSpeed.Slowdown(player, ballId)
	if not WorldBallSpeed.RethemedAway(player, ballId) then
		return nil
	end
	return OFF_WORLD_SHARE
end

-- true when this ball is "at home" in the player's current world
function WorldBallSpeed.Fits(player, ballId)
	if WorldBallSpeed.RethemedAway(player, ballId) then
		return false
	end
	if worldOf(player) <= 1 then
		return true
	end
	if ballId == STARTER_BALL then
		return true
	end
	return typeof(ballId) == "string" and WorldConfig.OwnsSkin(player, ballId, worldOf(player))
end

-- the speed a ball really rolls at for its owner right now
function WorldBallSpeed.Effective(player, ballId, fullSpeed)
	if WorldBallSpeed.Fits(player, ballId) then
		return fullSpeed
	end
	return math.min(fullSpeed, WorldBallSpeed.StarterSpeed())
end

-- convenience for a ball part (BallId + OwnerUserId attributes are server-set).
-- A ball swapped in by an upgrade / downgrade platform during a run (BallSpawner sets
-- "RunTierBall") rolls at that ball's full speed in every world: an off-world ball
-- starts the course as the starter ball, and each upgrade really is the next ball.
function WorldBallSpeed.ForBall(ball, fullSpeed)
	if ball:GetAttribute("RunTierBall") == true then
		return fullSpeed
	end
	local owner = Players:GetPlayerByUserId(ball:GetAttribute("OwnerUserId") or 0)
	if not owner then
		return fullSpeed
	end
	return WorldBallSpeed.Effective(owner, ball:GetAttribute("BallId"), fullSpeed)
end

-- the course brake for a ball part right now (nil = none): a platform ball is never braked
function WorldBallSpeed.CourseSlowdown(ball)
	if ball:GetAttribute("RunTierBall") == true then
		return nil
	end
	local owner = Players:GetPlayerByUserId(ball:GetAttribute("OwnerUserId") or 0)
	return owner and WorldBallSpeed.Slowdown(owner, ball:GetAttribute("BallId")) or nil
end

-- The WinCourse (how far the oil carries the ball, so the wins) judges the ball the
-- player brought: an equipped ball from another world counts as the starter ball
-- there even after course upgrades, and a re-themed ball outside its own world counts as
-- far less (the starter speed times OFF_WORLD_WIN_TRAVEL; WinCourseProgressService turns
-- a speed under 50 into a matching share of the starter ball's travel), so it burns
-- its oil much faster and never out-earns this world.
function WorldBallSpeed.ForWinCourse(player, ball, fullSpeed)
	local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService"))
	local equipped = PlayerDataService.GetEquippedBall(player)
	if WorldBallSpeed.Slowdown(player, equipped) then
		return WorldBallSpeed.StarterSpeed() * OFF_WORLD_WIN_TRAVEL
	end
	if not WorldBallSpeed.Fits(player, equipped) then
		return math.min(fullSpeed, WorldBallSpeed.StarterSpeed())
	end
	return WorldBallSpeed.ForBall(ball, fullSpeed)
end

-- true when the ball the player has equipped belongs to the world they are in
function WorldBallSpeed.EquippedIsHome(player)
	local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService"))
	return WorldBallSpeed.Fits(player, PlayerDataService.GetEquippedBall(player))
end

-- how fast the WinCourse roll plays for this player's equipped ball (1 = normal)
function WorldBallSpeed.WinCourseRollScale(player)
	local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService"))
	return WorldBallSpeed.Slowdown(player, PlayerDataService.GetEquippedBall(player)) and OFF_WORLD_WIN_ROLL or 1
end

return WorldBallSpeed
