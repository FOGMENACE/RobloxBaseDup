--------------------------------------------------
-- BALL ACCESSORY ANIMATOR
--
-- CLIENT ONLY, visual. Animates the unique parts of premium balls
-- (the dragon around SingleKnot, orbiting moons and coins, the cat that
-- stays upright on CatPlz, ...). Every ball tagged "AccBall" is posed
-- each frame while it is near the camera. The parts themselves are
-- built by shared/BallAccessories and replicate from the server; this
-- only moves their welds locally, so it can never change physics.
--------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BallAccessories = require(ReplicatedStorage:WaitForChild("BallAccessories"))

local balls = {}
local VIEW_DISTANCE = 140

local function add(instance)
	if instance:IsA("BasePart") then
		balls[instance] = true
	end
end

for _, instance in ipairs(CollectionService:GetTagged("AccBall")) do
	add(instance)
end
CollectionService:GetInstanceAddedSignal("AccBall"):Connect(add)
CollectionService:GetInstanceRemovedSignal("AccBall"):Connect(function(instance)
	balls[instance] = nil
end)

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local now = os.clock()
	local cameraPosition = camera.CFrame.Position

	for ball in pairs(balls) do
		if not ball.Parent then
			balls[ball] = nil
		elseif (ball.Position - cameraPosition).Magnitude < VIEW_DISTANCE then
			BallAccessories.Pose(ball, now)
		end
	end
end)
