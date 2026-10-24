--------------------------------------------------
-- GHOST LANES (CLIENT, visual only)
--
-- Everyone in a world rolls the same course line, so other players' runs
-- would overlap yours. On this client:
--   * players in OTHER worlds are hidden completely;
--   * players in YOUR world who are on a run are drawn as a "ghost" ball
--     floating in a lane beside yours (left / right), so you can watch
--     them race next to you without anything covering your own course.
-- The real balls are untouched on the server (physics, rewards, checks).
--------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local LANE = 44 -- studs between lanes
local RUNNING = { Starting = true, Running = true, Finishing = true }

-- OFF: runners in your world stay visible ON the course (balls never collide with each other).
-- ON would hide them and draw a copy in a side lane 44 studs away, which looked like players
-- rolling outside the course and made their real ball disappear when they hit the start wall.
local SIDE_LANES = false

local ghosts = {} -- [otherPlayer] = { Real = ball, Ghost = model }

local hiddenState = setmetatable({}, { __mode = "k" }) -- [ball] = { Hidden, At }

local function setHidden(ball, hidden)
	-- only touch the parts when the state changes (or once a second, for
	-- accessories that were added later)
	local state = hiddenState[ball]
	local now = os.clock()
	if state and state.Hidden == hidden and now - state.At < 1 then
		return
	end
	hiddenState[ball] = { Hidden = hidden, At = now }
	for _, d in ipairs(ball:GetDescendants()) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		elseif d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Enabled = not hidden
		end
	end
	ball.LocalTransparencyModifier = hidden and 1 or 0
end

local function dropGhost(other)
	local entry = ghosts[other]
	if entry then
		if entry.Ghost then
			entry.Ghost:Destroy()
		end
		if entry.Real and entry.Real.Parent then
			setHidden(entry.Real, false)
		end
		ghosts[other] = nil
	end
end

local function makeGhost(ball)
	local archivable = ball.Archivable
	ball.Archivable = true
	local ok, copy = pcall(function()
		return ball:Clone()
	end)
	ball.Archivable = archivable
	if not ok or not copy then
		return nil
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Constraint") or d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			d:Destroy()
		end
	end
	local model = Instance.new("Model")
	model.Name = "GhostBall"
	copy.Parent = model
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
			d.LocalTransparencyModifier = 0
		end
	end
	model.PrimaryPart = copy
	model.Parent = workspace
	return model
end

RunService.RenderStepped:Connect(function()
	local myWorld = player:GetAttribute("World") or 1
	local balls = workspace:FindFirstChild("PlayerBalls")
	if not balls then
		return
	end

	-- lane order: same-world runners sorted by UserId, alternating right/left
	local runners = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local ball = balls:FindFirstChild("PlayerBall_" .. other.UserId)
			local sameWorld = (other:GetAttribute("World") or 1) == myWorld
			if ball and not sameWorld then
				setHidden(ball, true) -- other worlds: never visible
				dropGhost(other)
			elseif SIDE_LANES and ball and RUNNING[other:GetAttribute("RunState")] then
				table.insert(runners, other)
			else
				dropGhost(other)
				if ball then
					setHidden(ball, false)
				end
			end
		end
	end
	table.sort(runners, function(a, b)
		return a.UserId < b.UserId
	end)

	for index, other in ipairs(runners) do
		local ball = balls:FindFirstChild("PlayerBall_" .. other.UserId)
		local entry = ghosts[other]
		if entry and entry.Real ~= ball then
			dropGhost(other)
			entry = nil
		end
		if not entry then
			local ghost = makeGhost(ball)
			entry = { Real = ball, Ghost = ghost }
			ghosts[other] = entry
		end
		setHidden(ball, true)
		if entry.Ghost then
			local side = (index % 2 == 1) and 1 or -1
			local lane = math.ceil(index / 2) * LANE * side
			entry.Ghost:PivotTo(ball.CFrame + Vector3.new(lane, 0, 0))
		end
	end
end)

Players.PlayerRemoving:Connect(dropGhost)