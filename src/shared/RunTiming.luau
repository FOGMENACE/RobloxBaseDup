--------------------------------------------------
-- RUN TIMING (client presentation helper)
--
-- The oil course ball is simulated by the SERVER and the client sees it a
-- moment later (replication + interpolation, about 0.2 s). The server counts a
-- platform the instant the real ball touches it, so the number, sounds and pop
-- arrived while the ball the player SEES was still ~10 studs short of the gate:
-- "the platform is calculated before I touch it".
--
-- RunTiming.Delay() says how long until the ball the player sees reaches the
-- nearest oil row, so effects can wait for that moment. It only changes WHEN a
-- visual plays. The server's authoritative result is untouched.
--------------------------------------------------

local Players = game:GetService("Players")

local RunTiming = {}

local MAX_DELAY = 0.5

function RunTiming.Delay()
	local player = Players.LocalPlayer
	local balls = workspace:FindFirstChild("PlayerBalls")
	local courses = workspace:FindFirstChild("Course")
	local ball = balls and balls:FindFirstChild("PlayerBall_" .. player.UserId)
	local course = courses and courses:FindFirstChild("PlayerCourse_" .. player.UserId)
	if not ball or not course then
		return 0
	end

	local speed = ball.AssemblyLinearVelocity.Z
	if speed < 5 then
		return 0
	end

	local z = ball.Position.Z
	local radius = ball.Size.X / 2

	-- the row whose gate the visible ball is about to touch (or has just touched):
	-- the server fires at most ~0.3 s ahead of the visible ball
	local best = nil
	for _, row in ipairs(course:GetChildren()) do
		local gap = row:GetPivot().Position.Z - radius - z -- studs still to go until contact
		if gap > -4 and gap < 24 and (best == nil or math.abs(gap) < math.abs(best)) then
			best = gap
		end
	end

	if best == nil or best <= 0 then
		return 0
	end

	return math.clamp(best / speed, 0, MAX_DELAY)
end

return RunTiming
