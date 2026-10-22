--------------------------------------------------
-- BALL GROUND RESCUE (SERVER)
--
-- A lobby ball can end up sunk into the (thin) lobby floor, e.g. when it spawns
-- or is moved before the client has streamed the floor in, so it falls past it
-- and the floor then stops it half buried. Collision cannot lift it out of a
-- thin slab, so this lifts it onto the floor again.
--
-- Safe by design: it only looks straight down from just above the ball's
-- centre, only trusts big up-facing parts (floors, not pins or furniture),
-- and only runs in the lobby (RunState Waiting, ball not anchored).
--------------------------------------------------

local Players = game:GetService("Players")

local CHECK_SECONDS = 0.3
local MIN_FLOOR_SIZE = 10 -- studs on both horizontal sides

local playerBalls = workspace:WaitForChild("PlayerBalls")
local lastRescue = {} -- [player] = os.clock()

local function floorUnder(ball, radius)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { playerBalls }
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true

	local hit = workspace:Raycast(
		ball.Position + Vector3.new(0, radius * 0.9, 0),
		Vector3.new(0, -radius * 3, 0),
		params
	)
	if not hit or hit.Normal.Y < 0.95 then
		return nil
	end
	local size = hit.Instance.Size
	if size.X < MIN_FLOOR_SIZE or size.Z < MIN_FLOOR_SIZE then
		return nil
	end
	return hit
end

local function rescue(player, ball)
	local radius = ball.Size.Y / 2
	local hit = floorUnder(ball, radius)
	if not hit then
		return
	end

	-- resting centre is floor + radius; anything well below that is sunk
	if ball.Position.Y >= hit.Position.Y + radius * 0.6 then
		return
	end
	if os.clock() - (lastRescue[player] or 0) < 1 then
		return
	end
	lastRescue[player] = os.clock()

	local target = Vector3.new(ball.Position.X, hit.Position.Y + radius + 0.05, ball.Position.Z)
	ball.Anchored = true
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.CFrame = CFrame.new(target) * (ball.CFrame - ball.CFrame.Position)
	task.wait(0.15)
	if ball.Parent then
		ball.Anchored = false
	end
	warn("[BallGroundRescue] lifted a sunken ball for", player.Name)
end

task.spawn(function()
	while true do
		task.wait(CHECK_SECONDS)
		for _, player in ipairs(Players:GetPlayers()) do
			local ball = playerBalls:FindFirstChild("PlayerBall_" .. player.UserId)
			if ball and ball:IsA("BasePart") and not ball.Anchored
				and (player:GetAttribute("RunState") or "Waiting") == "Waiting"
				and ball:GetAttribute("WinCourseActive") ~= true then
				rescue(player, ball)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRescue[player] = nil
end)
