--------------------------------------------------
-- SHOP CASHIER (SERVER, decoration only)
--
-- Your StandPin1 model wearing sunglasses, standing under the shop's roof
-- behind the counter like a cashier. No animation, no collision.
--------------------------------------------------

local Workspace = game:GetService("Workspace")

local shop = Workspace:WaitForChild("BowlingShop")
local template = shop:WaitForChild("StandPin1")
local counter = shop:WaitForChild("Stand")
local pad = shop:WaitForChild("BallShopInteractionPoint")

local FLOOR_Y = 63.5
local SCALE = 2.7

local old = Workspace:FindFirstChild("ShopCashier")
if old then
	old:Destroy()
end

local model = Instance.new("Model")
model.Name = "ShopCashier"
model.Parent = Workspace

-- front = from the counter toward the customers (the interaction point)
local front = Vector3.new(pad.Position.X - counter.Position.X, 0, pad.Position.Z - counter.Position.Z).Unit
local base = Vector3.new(counter.Position.X, FLOOR_Y, counter.Position.Z) - front * 1.6

local pin = template:Clone()
pin.Name = "CashierPin"
pin.Anchored = true
pin.CanCollide = false
pin.CanTouch = false
pin.CanQuery = false
pin.CastShadow = false
pin.Size = template.Size * SCALE
local upright = template.CFrame - template.CFrame.Position
pin.CFrame = CFrame.new(base.X, FLOOR_Y + pin.Size.Y / 2, base.Z) * upright
pin.Parent = model

local height = pin.Size.Y
local radius = pin.Size.X / 2
local yaw = CFrame.lookAt(Vector3.zero, front)

local function shade(name, size, offsetX, offsetY, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	-- local frame: x = to the cashier's right, y = up, z = toward -front
	p.CFrame = CFrame.new(base.X, FLOOR_Y + offsetY, base.Z) * yaw
		* CFrame.new(offsetX, 0, -(radius * 0.62))
	p.Parent = model
	return p
end

local eyeY = height * 0.80
local dark = Color3.fromRGB(14, 14, 20)
shade("LensL", Vector3.new(radius * 0.62, radius * 0.38, 0.06), -radius * 0.34, eyeY, dark)
shade("LensR", Vector3.new(radius * 0.62, radius * 0.38, 0.06), radius * 0.34, eyeY, dark)
shade("Bridge", Vector3.new(radius * 0.18, 0.06, 0.06), 0, eyeY + radius * 0.06, dark)

print("[ShopCashier] READY")
