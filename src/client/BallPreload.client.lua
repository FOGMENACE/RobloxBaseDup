--------------------------------------------------
-- BALL PRELOAD
--
-- Downloads every ball mesh/texture in ReplicatedStorage.BallModels (plus the Oil Barrel) at join so a
-- mid-run tier swap never waits on the network. Visual only.
--------------------------------------------------

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

task.spawn(function()
	local assets = {}

	local folder = ReplicatedStorage:WaitForChild("BallModels", 30)
	if folder then
		for _, stub in ipairs(folder:GetChildren()) do
			table.insert(assets, stub)
		end
	end

	pcall(function()
		ContentProvider:PreloadAsync(assets)
	end)
end)
