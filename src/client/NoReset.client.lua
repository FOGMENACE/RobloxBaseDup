--------------------------------------------------
-- NO RESET (client)
--
-- Turns off the Reset Character button / menu entry. The game cannot be
-- played from a respawned character, so nobody should be able to trigger it
-- by accident. (An exploiter who bypasses this is handled by the server:
-- RunController.recoverFromRespawn cuts the run and returns them to the
-- lobby with their progress saved.)
--------------------------------------------------

local StarterGui = game:GetService("StarterGui")

task.spawn(function()
	-- SetCore is not ready right at join, so retry for a while
	for _ = 1, 30 do
		local ok = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if ok then
			return
		end
		task.wait(1)
	end
end)