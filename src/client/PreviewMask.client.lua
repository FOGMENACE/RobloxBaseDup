--------------------------------------------------
-- PREVIEW MASK
--
-- CLIENT ONLY, visual. The lobby previews of the OilCourse ("OilAmount"
-- labels) and the WinCourse ("WinAmount" labels) hide their numbers behind
-- "???" until the player crosses the StartWall (RunState leaves Waiting).
-- Only this client's copy of the text changes; the server's labels (and
-- the real course) are untouched.
--------------------------------------------------

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local MASKS = {
	OilAmount = "???",
	WinAmount = "---",
}

local originals = {} -- [label] = real text

local function isMasked()
	local state = player:GetAttribute("RunState")
	return state == nil or state == "Waiting"
end

local function apply(label)
	local mask = MASKS[label.Name]
	if not mask or not label:IsA("TextLabel") then
		return
	end

	if originals[label] == nil then
		originals[label] = label.Text

		-- keep up with later server edits to the real text
		label:GetPropertyChangedSignal("Text"):Connect(function()
			if label.Text ~= mask then
				originals[label] = label.Text
				if isMasked() then
					label.Text = mask
				end
			end
		end)
	end

	label.Text = isMasked() and mask or originals[label]
end

local function applyAll()
	for label in pairs(originals) do
		apply(label)
	end
end

local function watch(folder)
	for _, descendant in ipairs(folder:GetDescendants()) do
		apply(descendant)
	end
	folder.DescendantAdded:Connect(apply)
end

local course = workspace:WaitForChild("Course")

for _, name in ipairs({ "LobbyCourse", "WinCoursePreview" }) do
	task.spawn(function()
		watch(course:WaitForChild(name))
	end)
end

player:GetAttributeChangedSignal("RunState"):Connect(applyAll)
