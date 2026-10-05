local Players = game:GetService("Players")

local playerBalls =
	workspace:WaitForChild("PlayerBalls")

--------------------------------------------------
-- SETUP BALL
--------------------------------------------------

local function setupBall(ball)

	if not ball:IsA("BasePart") then
		return
	end

	--------------------------------------------------
	-- PHYSICAL BALL
	--------------------------------------------------

	ball.Anchored = false
	ball.CanCollide = true
	ball.CanTouch = true
	ball.CanQuery = true

	--------------------------------------------------
	-- BALL ATTACHMENT
	--------------------------------------------------

	local attachment =
		ball:FindFirstChild("BallAttachment")

	if not attachment then

		attachment =
			Instance.new("Attachment")

		attachment.Name =
			"BallAttachment"

		attachment.Parent =
			ball

	end

	--------------------------------------------------
	-- LINEAR VELOCITY
	--------------------------------------------------

	local linearVelocity =
		ball:FindFirstChild("BallLinearVelocity")

	if not linearVelocity then

		linearVelocity =
			Instance.new("LinearVelocity")

		linearVelocity.Name =
			"BallLinearVelocity"

		linearVelocity.Attachment0 =
			attachment

		linearVelocity.RelativeTo =
			Enum.ActuatorRelativeTo.World

		linearVelocity.VelocityConstraintMode =
			Enum.VelocityConstraintMode.Vector

		linearVelocity.MaxForce =
			math.huge

		linearVelocity.VectorVelocity =
			Vector3.zero

		linearVelocity.Enabled =
			false

		linearVelocity.Parent =
			ball

	end

	print(
		"[BallPhysicsController] READY:",
		ball.Name
	)

end

--------------------------------------------------
-- EXISTING BALLS
--------------------------------------------------

for _, ball in ipairs(
	playerBalls:GetChildren()
) do

	setupBall(ball)

end

--------------------------------------------------
-- NEW BALLS
--------------------------------------------------

playerBalls.ChildAdded:Connect(
	function(ball)

		setupBall(ball)

	end
)

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		local ball =
			playerBalls:FindFirstChild(
				"PlayerBall_" .. player.UserId
			)

		if ball then

			local linearVelocity =
				ball:FindFirstChild(
					"BallLinearVelocity"
				)

			if linearVelocity then

				linearVelocity.Enabled = false
				linearVelocity.VectorVelocity =
					Vector3.zero

			end

		end

	end
)

print(
	"[BallPhysicsController] SERVER READY"
)
