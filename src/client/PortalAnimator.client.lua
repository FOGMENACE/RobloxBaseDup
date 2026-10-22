--------------------------------------------------
-- PORTAL ANIMATOR
--
-- CLIENT ONLY, visual. The WORLDS portal (built by WorldService) tags its
-- spokes and runes "PortalSpin"; each frame this turns them about the
-- disc's axis, locally, so the portal swirls without any server traffic.
--------------------------------------------------

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local parts = {}
local VIEW_DISTANCE = 160

local function add(instance)
	if instance:IsA("BasePart") then
		parts[instance] = true
	end
end

for _, instance in ipairs(CollectionService:GetTagged("PortalSpin")) do
	add(instance)
end
CollectionService:GetInstanceAddedSignal("PortalSpin"):Connect(add)
CollectionService:GetInstanceRemovedSignal("PortalSpin"):Connect(function(instance)
	parts[instance] = nil
end)

RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local now = os.clock()
	local cameraPosition = camera.CFrame.Position

	for part in pairs(parts) do
		if not part.Parent then
			parts[part] = nil
		else
			local center = part:GetAttribute("PortalCenter")
			local offset = part:GetAttribute("PortalOffset")
			local speed = part:GetAttribute("SpinSpeed")
			if typeof(center) == "Vector3" and typeof(offset) == "CFrame" and typeof(speed) == "number"
				and (center - cameraPosition).Magnitude < VIEW_DISTANCE then
				part.CFrame = CFrame.new(center) * CFrame.Angles(now * speed, 0, 0) * offset
			end
		end
	end
end)