--------------------------------------------------
-- OFF-WORLD BALL FLAG (SERVER)
--
-- Publishes the player attribute "BallNotHome" (true / nil): the equipped ball
-- does not belong to the world the player is in (WorldBallSpeed.Fits), so it is
-- braked on the courses. The client only shows a small notice for it
-- (OffWorldNotice); every speed / travel rule stays in WorldBallSpeed.
--------------------------------------------------

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldBallSpeed = require(ServerScriptService:WaitForChild("WorldBallSpeed"))

local function refresh(player)
	if not player.Parent then
		return
	end
	local ok, home = pcall(WorldBallSpeed.EquippedIsHome, player)
	player:SetAttribute("BallNotHome", (ok and not home) or nil)
end

local function watch(player)
	for _, attribute in ipairs({ "World", "Skins", "EquippedBall" }) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			refresh(player)
		end)
	end
	task.defer(refresh, player)
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
