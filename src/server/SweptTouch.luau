--------------------------------------------------
-- SWEPT TOUCH (server module)
--
-- Thin platforms (~0.3 studs) can be skipped by a fast ball: it moves
-- several studs per physics step, so Touched sometimes never fires. This
-- adds a per-frame check of the ball's path (previous -> current position)
-- against registered parts and calls the same callback Touched would.
--
--   SweptTouch.Register(part, userId, callback)   -- callback(ballPart)
--
-- Only the owning player's ball (PlayerBall_<userId>) is considered, and
-- only while RunState is "Running".
--------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SweptTouch = {}

local entries = {} -- [part] = { UserId, Callback }
local lastPosition = {} -- [player] = Vector3

function SweptTouch.Register(part, userId, callback)
	entries[part] = { UserId = userId, Callback = callback }
end

local function crossed(part, previous, current, radius)
	local size = part.Size
	local axis = "X"
	if size.Y < size[axis] then
		axis = "Y"
	end
	if size.Z < size[axis] then
		axis = "Z"
	end

	local a = part.CFrame:PointToObjectSpace(previous)
	local b = part.CFrame:PointToObjectSpace(current)
	local pa, pb = a[axis], b[axis]
	local half = size[axis] / 2 + radius

	local touchesSlab = (pa < -half and pb > -half) or (pa > half and pb < half)
		or math.abs(pa) <= half or math.abs(pb) <= half
	if not touchesSlab or pa == pb then
		return false
	end

	local t = math.clamp((0 - pa) / (pb - pa), 0, 1)
	local at = a:Lerp(b, t)
	for _, other in ipairs({ "X", "Y", "Z" }) do
		if other ~= axis and math.abs(at[other]) > size[other] / 2 + radius then
			return false
		end
	end

	return true
end

RunService.Heartbeat:Connect(function()
	local balls = workspace:FindFirstChild("PlayerBalls")
	if not balls then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local ball = balls:FindFirstChild("PlayerBall_" .. player.UserId)
		if player:GetAttribute("RunState") ~= "Running" or not ball then
			lastPosition[player] = nil
			continue
		end

		local current = ball.Position
		local previous = lastPosition[player]
		lastPosition[player] = current

		-- slow enough for Touched to do its job
		if not previous or (current - previous).Magnitude < 1.5 then
			continue
		end

		local radius = ball.Size.X / 2
		for part, entry in pairs(entries) do
			if not part.Parent then
				entries[part] = nil
			elseif entry.UserId == player.UserId and crossed(part, previous, current, radius) then
				task.spawn(entry.Callback, ball)
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastPosition[player] = nil
end)

return SweptTouch
