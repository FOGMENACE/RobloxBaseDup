local RunService =
	game:GetService("RunService")

local Players =
	game:GetService("Players")

local player =
	Players.LocalPlayer

local playerBalls =
	workspace:WaitForChild("PlayerBalls")


--------------------------------------------------
-- WAIT FOR PLAYER BALL
--------------------------------------------------

local ballName =
	"PlayerBall_" .. player.UserId

local ball

repeat

	ball =
		playerBalls:FindFirstChild(
			ballName
		)

	if not ball then

		task.wait(0.1)

	end

until ball


--------------------------------------------------
-- VISUAL ROLL
--------------------------------------------------

RunService.RenderStepped:Connect(function()

	if not ball
		or not ball.Parent then

		return

	end

	local velocity =
		ball.AssemblyLinearVelocity

	if velocity.Magnitude > 0.1 then

		local horizontalVelocity =
			Vector3.new(
				velocity.X,
				0,
				velocity.Z
			)

		if horizontalVelocity.Magnitude > 0.1 then

			local axis =
				Vector3.new(
					horizontalVelocity.Z,
					0,
					-horizontalVelocity.X
				).Unit

			local radius =
				math.max(
					ball.Size.X * 0.5,
					0.01
				)

			ball.AssemblyAngularVelocity =
				axis
				*
				(
					horizontalVelocity.Magnitude
					/
					radius
				)

		end

	end

end)

print(
	"[BallVisualController]",
	"CLIENT READY"
)
