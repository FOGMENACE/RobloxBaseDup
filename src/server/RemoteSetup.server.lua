local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")

if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
end

local ballMovement = remotes:FindFirstChild("BallMovement")

if not ballMovement then
    ballMovement = Instance.new("RemoteEvent")
    ballMovement.Name = "BallMovement"
    ballMovement.Parent = remotes
end


--------------------------------------------------
-- GET OR CREATE REMOTE EVENT
--------------------------------------------------

local function getOrCreateRemoteEvent(
	name
)

	local remote =
		remotes:FindFirstChild(name)

	if remote then

		if not remote:IsA("RemoteEvent") then

			error(
				"[RemoteSetup] "
					.. name
					.. " exists but is not a RemoteEvent"
			)

		end

		return remote

	end

	remote =
		Instance.new("RemoteEvent")

	remote.Name =
		name

	remote.Parent =
		remotes

	print(
		"[RemoteSetup] Created RemoteEvent:",
		name
	)

	return remote

end

--------------------------------------------------
-- GET OR CREATE REMOTE FUNCTION
--------------------------------------------------

local function getOrCreateRemoteFunction(
	name
)

	local remote =
		remotes:FindFirstChild(name)

	if remote then

		if not remote:IsA("RemoteFunction") then

			error(
				"[RemoteSetup] "
					.. name
					.. " exists but is not a RemoteFunction"
			)

		end

		return remote

	end

	remote =
		Instance.new("RemoteFunction")

	remote.Name =
		name

	remote.Parent =
		remotes

	print(
		"[RemoteSetup] Created RemoteFunction:",
		name
	)

	return remote

end

--------------------------------------------------
-- BOWLING SHOP
--------------------------------------------------

-- Client -> Server:
--
-- "BuyWithWins", ballId
-- "Equip", ballId
--
-- Server -> Client:
--
-- "PurchaseResult", result
-- "EquipResult", result

local ballShop =
	getOrCreateRemoteEvent(
		"BallShop"
	)

--------------------------------------------------
-- BOWLING SHOP STATE
--------------------------------------------------

-- Client:
--
-- BallShopState:InvokeServer()
--
-- Server:
--
-- Returns authoritative shop state.

local ballShopState =
	getOrCreateRemoteFunction(
		"BallShopState"
	)

--------------------------------------------------
-- OPEN BOWLING SHOP
--------------------------------------------------

-- Server -> Client only.

local openBowlingShop =
	getOrCreateRemoteEvent(
		"OpenBowlingShop"
	)

--------------------------------------------------
-- OPTIONAL: EXPLICIT REFERENCES
--
-- These aren't required, but keeping the variables
-- above makes it very obvious which remotes this
-- setup script owns.
--------------------------------------------------

assert(
	ballShop:IsA("RemoteEvent"),
	"[RemoteSetup] BallShop setup failed"
)

assert(
	ballShopState:IsA("RemoteFunction"),
	"[RemoteSetup] BallShopState setup failed"
)

assert(
	openBowlingShop:IsA("RemoteEvent"),
	"[RemoteSetup] OpenBowlingShop setup failed"
)

--------------------------------------------------
-- READY
--------------------------------------------------

print(
	"=========================================="
)

print(
	"[RemoteSetup]",
	"SERVER READY"
)

print(
	"[RemoteSetup]",
	"Remotes folder:",
	remotes:GetFullName()
)

print(
	"[RemoteSetup]",
	"BallShop:",
	ballShop.ClassName
)

print(
	"[RemoteSetup]",
	"BallShopState:",
	ballShopState.ClassName
)

print(
	"[RemoteSetup]",
	"OpenBowlingShop:",
	openBowlingShop.ClassName
)

print(
	"=========================================="
)