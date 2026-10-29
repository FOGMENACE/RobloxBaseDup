--------------------------------------------------
-- WORLD BALL STYLE (CLIENT, cosmetic only)
--
-- A live ball shows its evolved world skin (WorldSkinStyle) when its owner is
-- in that themed world AND owns that ball's skin for it (server-set "Skins"
-- attribute). The re-themed look then STAYS with the ball when its owner moves
-- to another world (or back to world 1): in a world where the ball has no skin
-- of its own it keeps the theme of the highest world skin the owner owns for it
-- (the same answer on every client, and it survives rejoining). A ball with no
-- skin at all looks exactly like the original. This is the look only: how fast
-- the ball rolls is still decided by the server (WorldBallSpeed).
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local WorldSkinStyle = require(ReplicatedStorage:WaitForChild("WorldSkinStyle"))

-- highest world whose themed skin this owner has for the ball
local function highestOwnedSkin(owner, ballId)
	local best = nil
	for _, world in ipairs(WorldConfig.Worlds) do
		if world.Theme and WorldConfig.OwnsSkin(owner, ballId, world.Id) then
			best = world.Id
		end
	end
	return best
end

task.spawn(function()
	local balls = workspace:WaitForChild("PlayerBalls")
	while true do
		for _, ball in ipairs(balls:GetChildren()) do
			if ball:IsA("BasePart") then
				local userId = tonumber(string.match(ball.Name, "%d+$"))
				local owner = userId and Players:GetPlayerByUserId(userId)
				local world = owner and WorldConfig.Of(owner)
				local ballId = ball:GetAttribute("BallId")
				local want = nil
				if world and ballId then
					if world.Theme and WorldConfig.OwnsSkin(owner, ballId, world.Id) then
						want = world.Id
					else
						want = highestOwnedSkin(owner, ballId)
					end
				end
				local theme = want and WorldConfig.Get(want).Theme
				local count = #ball:GetChildren()
				local reset = theme and ball.Material ~= theme.WrapMaterial
				if ball:GetAttribute("StyledWorld") ~= want or (want and ball:GetAttribute("StyledParts") ~= count) or reset then
					if theme then
						WorldSkinStyle.Apply(ball, theme, true)
						ball:SetAttribute("StyledParts", #ball:GetChildren())
					else
						WorldSkinStyle.Restore(ball)
					end
					ball:SetAttribute("StyledWorld", want)
				end
			end
		end
		task.wait(0.5)
	end
end)
