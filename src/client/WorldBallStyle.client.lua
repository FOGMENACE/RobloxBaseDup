--------------------------------------------------
-- WORLD BALL STYLE (CLIENT, cosmetic only)
--
-- A live ball shows its evolved world skin (WorldSkinStyle) when its owner is
-- in a themed world AND owns that ball's skin for that world (server-set
-- "Skins" attribute). Otherwise it looks exactly like the original. World 1
-- and the ball templates are never touched.
--------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage:WaitForChild("WorldConfig"))
local WorldSkinStyle = require(ReplicatedStorage:WaitForChild("WorldSkinStyle"))

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
				if world and world.Theme and ballId and WorldConfig.OwnsSkin(owner, ballId, world.Id) then
					want = world.Id
				end
				local count = #ball:GetChildren()
				local reset = want and ball.Material ~= world.Theme.WrapMaterial
				if ball:GetAttribute("StyledWorld") ~= want or (want and ball:GetAttribute("StyledParts") ~= count) or reset then
					if want then
						WorldSkinStyle.Apply(ball, world.Theme, true)
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