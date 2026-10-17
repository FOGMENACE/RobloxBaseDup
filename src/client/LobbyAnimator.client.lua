--------------------------------------------------
-- LOBBY ANIMATOR
--
-- CLIENT ONLY, visual. Animates parts that LobbyDecor tags:
--   "LobbySpin" : ball-rack balls turn slowly
--   "LobbyLamp" : hanging lamps breathe (light brightness pulses)
-- Purely local; the server parts are anchored and non-colliding.
--------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local spinners = {} -- [part] = phase
local lamps = {}    -- [part] = PointLight

local function addSpinner(instance)
	if instance:IsA("BasePart") then
		spinners[instance] = math.random() * math.pi * 2
	end
end

local function addLamp(instance)
	local light = instance:FindFirstChildOfClass("PointLight")
	if light then
		lamps[instance] = light
	end
end

for _, instance in ipairs(CollectionService:GetTagged("LobbySpin")) do
	addSpinner(instance)
end
for _, instance in ipairs(CollectionService:GetTagged("LobbyLamp")) do
	addLamp(instance)
end

CollectionService:GetInstanceAddedSignal("LobbySpin"):Connect(addSpinner)
CollectionService:GetInstanceAddedSignal("LobbyLamp"):Connect(addLamp)
CollectionService:GetInstanceRemovedSignal("LobbySpin"):Connect(function(instance)
	spinners[instance] = nil
end)
CollectionService:GetInstanceRemovedSignal("LobbyLamp"):Connect(function(instance)
	lamps[instance] = nil
end)

local camera = workspace.CurrentCamera
local SPIN_DISTANCE = 90 -- only animate what is near the camera

RunService.RenderStepped:Connect(function(deltaTime)
	local now = os.clock()
	local cameraPosition = camera.CFrame.Position

	for instance, phase in pairs(spinners) do
		if instance.Parent
			and (instance.Position - cameraPosition).Magnitude < SPIN_DISTANCE then
			instance.CFrame = instance.CFrame * CFrame.Angles(0, deltaTime * (0.6 + phase % 0.4), 0)
		end
	end

	for instance, light in pairs(lamps) do
		if instance.Parent then
			light.Brightness = 1.4 + math.sin(now * 1.6 + instance.Position.X) * 0.25
		end
	end
end)

--------------------------------------------------
-- TIER GATES (oil course upgrade / downgrade gates, tagged by BallTierGates)
-- They pulse and their light breathes so they read as "live" choices.
--------------------------------------------------

local gates = {} -- [part] = phase

local function addGate(instance)
	if instance:IsA("BasePart") then
		gates[instance] = math.random() * math.pi * 2
	end
end

for _, instance in ipairs(CollectionService:GetTagged("TierGate")) do
	addGate(instance)
end
CollectionService:GetInstanceAddedSignal("TierGate"):Connect(addGate)
CollectionService:GetInstanceRemovedSignal("TierGate"):Connect(function(instance)
	gates[instance] = nil
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()

	for instance, phase in pairs(gates) do
		if instance.Parent then
			instance.Transparency = 0.32 + math.sin(now * 3.2 + phase) * 0.14

			local light = instance:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = 1.2 + math.sin(now * 3.2 + phase) * 0.5
			end
		else
			gates[instance] = nil
		end
	end
end)
