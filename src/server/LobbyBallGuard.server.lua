--------------------------------------------------
-- LOBBY BALL GUARD (SERVER ONLY)
--
-- In the lobby the player's own client drives the ball (smooth movement),
-- so an exploiter could teleport or speed-hack it. Rewards never depend on
-- that (XP, oil and wins are computed on the server; passes are checked
-- there), but this guard keeps the lobby honest: if a lobby ball moves
-- faster than any real ball can (or leaves the room), it is put back on
-- the spawn pad and its velocity cleared.
--------------------------------------------------

local Players = game:GetService("Players")

local playerBalls = workspace:WaitForChild("PlayerBalls")
local spawnPad = workspace:WaitForChild("BallSpawn")

local MAX_LOBBY_SPEED = 110 -- studs/s; the real lobby speed is far lower
local CHECK = 0.25
local last = {} -- [ball] = { Position, Time }

task.spawn(function()
	while true do
		task.wait(CHECK)

		for _, player in ipairs(Players:GetPlayers()) do
			local ball = playerBalls:FindFirstChild("PlayerBall_" .. player.UserId)

			if ball and ball:IsA("BasePart") and (player:GetAttribute("RunState") or "Waiting") == "Waiting" then
				local now = os.clock()
				local previous = last[ball]
				last[ball] = { Position = ball.Position, Time = now }

				if previous then
					local dt = math.max(now - previous.Time, 0.05)
					local flat = Vector3.new(ball.Position.X - previous.Position.X, 0, ball.Position.Z - previous.Position.Z)
					local speed = flat.Magnitude / dt
					local outOfRoom = ball.Position.Y < spawnPad.Position.Y - 60 or ball.Position.Y > spawnPad.Position.Y + 120

					if speed > MAX_LOBBY_SPEED or outOfRoom then
						ball.AssemblyLinearVelocity = Vector3.zero
						ball.AssemblyAngularVelocity = Vector3.zero
						ball.CFrame = spawnPad.CFrame + Vector3.new(0, 3, 0)
						last[ball] = nil
					end
				end
			end
		end
	end
end)

print("[LobbyBallGuard] READY")
