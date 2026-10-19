--------------------------------------------------
-- COURSE VISIBILITY (client, visual only)
--
-- Every player's oil course is built at the SAME place. With two players in
-- the server (or a leftover lobby preview) two courses overlap, which draws
-- two sets of platform numbers on top of each other (doubled / ghosted text).
-- This client only keeps what belongs to ITS player: other players'
-- PlayerCourse_* folders, and the lobby preview once this player is running,
-- are removed locally. The server's courses, collection and rewards are
-- untouched (the server decides everything).
--------------------------------------------------

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local course = workspace:WaitForChild("Course")

local function isRunning()
	local state = player:GetAttribute("RunState")
	return state == "Starting" or state == "Running" or state == "Finishing"
end

local function check(child)
	if not child:IsA("Folder") then
		return
	end

	local id = child.Name:match("^PlayerCourse_(%d+)$")
	if id and tonumber(id) ~= player.UserId then
		child:Destroy() -- someone else's course sitting at the same place
	elseif child.Name == "LobbyCourse" and isRunning() then
		child:Destroy()
	end
end

course.ChildAdded:Connect(function(child)
	task.defer(check, child)
end)

player:GetAttributeChangedSignal("RunState"):Connect(function()
	for _, child in ipairs(course:GetChildren()) do
		check(child)
	end
end)

for _, child in ipairs(course:GetChildren()) do
	check(child)
end