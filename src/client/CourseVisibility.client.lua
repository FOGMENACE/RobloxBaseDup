--------------------------------------------------
-- COURSE VISIBILITY (client, visual only)
--
-- Every player's oil course is built at the SAME place per world. This client
-- only keeps what belongs to ITS player:
--   * other players' PlayerCourse_* folders are removed locally (they sit at
--     the same spot and would draw a second set of platform numbers);
--   * the lobby preview (LobbyCourse, and each themed world's copy of it) is
--     hidden locally while THIS player is running - the real course takes its
--     place - and shown again when the run ends. It used to be destroyed, so it
--     never came back and one player's run removed it for everyone.
-- The server's courses, collection and rewards are untouched.
--------------------------------------------------

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local course = workspace:WaitForChild("Course")

local function isRunning()
	local state = player:GetAttribute("RunState")
	return state == "Starting" or state == "Running" or state == "Finishing"
end

local function previewFolders()
	local list = {}
	local own = course:FindFirstChild("LobbyCourse")
	if own then
		table.insert(list, own)
	end
	local worlds = workspace:FindFirstChild("Worlds")
	if worlds then
		for _, world in ipairs(worlds:GetChildren()) do
			local copy = world:FindFirstChild("LobbyCourse")
			if copy then
				table.insert(list, copy)
			end
		end
	end
	return list
end

local function setHidden(folder, hidden)
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d.Enabled = not hidden
		end
	end
	folder:SetAttribute("LocallyHidden", hidden)
end

local function refreshPreview()
	local hide = isRunning()
	for _, folder in ipairs(previewFolders()) do
		if folder:GetAttribute("LocallyHidden") ~= hide then
			setHidden(folder, hide)
		end
	end
end

local function check(child)
	if not child:IsA("Folder") then
		return
	end

	local id = child.Name:match("^PlayerCourse_(%d+)$")
	if id and tonumber(id) ~= player.UserId then
		child:Destroy() -- someone else's course sitting at the same place
	elseif child.Name == "LobbyCourse" then
		task.defer(refreshPreview)
	end
end

course.ChildAdded:Connect(function(child)
	task.defer(check, child)
end)

player:GetAttributeChangedSignal("RunState"):Connect(function()
	for _, child in ipairs(course:GetChildren()) do
		check(child)
	end
	refreshPreview()
end)

-- world copies stream in / are added after startup
task.spawn(function()
	local worlds = workspace:WaitForChild("Worlds", 60)
	if worlds then
		worlds.DescendantAdded:Connect(function(d)
			if d.Name == "LobbyCourse" then
				task.defer(refreshPreview)
			end
		end)
	end
end)

for _, child in ipairs(course:GetChildren()) do
	check(child)
end
refreshPreview()