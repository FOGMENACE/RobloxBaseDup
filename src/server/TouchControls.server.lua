--------------------------------------------------
-- TOUCH CONTROLS (server)
--
-- The ball is steered by BallController's own on-screen stick (lobby) and
-- arrow buttons (oil course). Roblox's built-in thumbstick and jump button
-- would be a second, slower stick on top of it, so touch movement is set to
-- Scriptable, which removes them. Keyboard and gamepad are unaffected.
--------------------------------------------------

local Players = game:GetService("Players")

local function apply(player)
	player.DevTouchMovementMode = Enum.DevTouchMovementMode.Scriptable
end

Players.PlayerAdded:Connect(apply)
for _, player in ipairs(Players:GetPlayers()) do
	apply(player)
end
