--------------------------------------------------
-- BALL SERVICE
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > BallService
--
-- PURPOSE:
--
-- Central authoritative bowling-ball service.
--
-- Handles:
-- - Ball definitions
-- - Ball ownership
-- - Equipped ball
-- - Wins purchases
-- - Developer Product prompting
-- - Developer Product registration
-- - Rebirth requirements
-- - Ball movement attributes
-- - Wins synchronization
-- - Server-authoritative Win awarding
-- - Remote requests
-- - Shop state snapshots
--
-- SECURITY:
--
-- BallDefinitions is SERVER ONLY.
--
-- BallProductDefinitions is SERVER ONLY.
--
-- Clients NEVER provide:
-- - WinsCost
-- - RequiredRebirths
-- - ForwardSpeed
-- - HorizontalSpeed
-- - DeveloperProductId
--
-- Clients ONLY provide:
-- - Action
-- - BallId
--
-- The server resolves everything else.
--
-- IMPORTANT:
--
-- PurchaseServiceModule owns the Developer Product
-- registry.
--
-- BallService registers its ball products with
-- PurchaseServiceModule.
--
-- BallService does NOT assign MarketplaceService.ProcessReceipt.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService("Players")

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local MarketplaceService =
	game:GetService("MarketplaceService")

local ServerScriptService =
	game:GetService("ServerScriptService")

local ServerStorage =
	game:GetService("ServerStorage")


--------------------------------------------------
-- SERVER BALL DEFINITIONS
--------------------------------------------------

local BallDefinitions =
	require(
		ServerScriptService
			:WaitForChild("BallDefinitions")
	)


--------------------------------------------------
-- SERVER PRODUCT DEFINITIONS
--
-- Expected format:
--
-- return {
--
--     CatPlz = 3716938115,
--     Thrifty = 3716938576,
--     ...
--
-- }
--------------------------------------------------

local BallProductDefinitions =
	require(
		ServerScriptService
			:WaitForChild(
				"BallProductDefinitions"
			)
	)


--------------------------------------------------
-- PLAYER DATA SERVICE
--------------------------------------------------

local PlayerDataService =
	require(
		ServerScriptService
			:WaitForChild(
				"PlayerDataLoader"
			)
			:WaitForChild(
				"PlayerDataService"
			)
	)


--------------------------------------------------
-- PURCHASE SERVICE
--------------------------------------------------

local PurchaseService =
	require(
		ServerScriptService
			:WaitForChild(
				"PurchaseServiceModule"
			)
	)


--------------------------------------------------
-- REMOTES
--------------------------------------------------

local remotes =
	ReplicatedStorage:FindFirstChild(
		"Remotes"
	)


if not remotes then

	remotes =
		Instance.new("Folder")

	remotes.Name =
		"Remotes"

	remotes.Parent =
		ReplicatedStorage

end


--------------------------------------------------
-- BALL SHOP REMOTE
--------------------------------------------------

local ballRemote =
	remotes:FindFirstChild(
		"BallShop"
	)


if not ballRemote then

	ballRemote =
		Instance.new("RemoteEvent")

	ballRemote.Name =
		"BallShop"

	ballRemote.Parent =
		remotes

elseif not ballRemote:IsA("RemoteEvent") then

	error(
		"[BallService] Remotes.BallShop must be a RemoteEvent."
	)

end


--------------------------------------------------
-- BALL SHOP STATE REMOTE
--------------------------------------------------

local ballShopStateRemote =
	remotes:FindFirstChild(
		"BallShopState"
	)


if not ballShopStateRemote then

	ballShopStateRemote =
		Instance.new("RemoteFunction")

	ballShopStateRemote.Name =
		"BallShopState"

	ballShopStateRemote.Parent =
		remotes

elseif not ballShopStateRemote:IsA("RemoteFunction") then

	error(
		"[BallService] Remotes.BallShopState must be a RemoteFunction."
	)

end


--------------------------------------------------
-- SERVER-ONLY WIN AWARD INTERFACE
--
-- Other server scripts can use:
--
-- ServerStorage
--     > BallService
--         > AwardWin
--
-- Example:
--
-- local AwardWin =
--     ServerStorage.BallService.AwardWin
--
-- AwardWin:Invoke(player, 1)
--------------------------------------------------

local ballServiceFolder =
	ServerStorage:FindFirstChild(
		"BallService"
	)


if not ballServiceFolder then

	ballServiceFolder =
		Instance.new("Folder")

	ballServiceFolder.Name =
		"BallService"

	ballServiceFolder.Parent =
		ServerStorage

end


local awardWinFunction =
	ballServiceFolder:FindFirstChild(
		"AwardWin"
	)


if not awardWinFunction then

	awardWinFunction =
		Instance.new("BindableFunction")

	awardWinFunction.Name =
		"AwardWin"

	awardWinFunction.Parent =
		ballServiceFolder

elseif not awardWinFunction:IsA(
	"BindableFunction"
) then

	error(
		"[BallService] ServerStorage.BallService.AwardWin must be a BindableFunction."
	)

end


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local DEFAULT_BALL =
	"StraightBall"

local TUTORIAL_BALL =
	"Aftershock"

local REQUEST_COOLDOWN =
	0.15


--------------------------------------------------
-- SERVER LOCKS
--------------------------------------------------

local transactionLocks = {}

local lastRequestTime = {}


--------------------------------------------------
-- UTILITY
--------------------------------------------------

local function isFiniteNumber(value)

	if typeof(value) ~= "number" then
		return false
	end

	if value ~= value then
		return false
	end

	if value == math.huge
		or value == -math.huge then

		return false

	end

	return true

end


--------------------------------------------------
-- VALID BALL ID
--------------------------------------------------

local function isValidBallIdString(ballId)

	if typeof(ballId) ~= "string" then
		return false
	end

	if ballId == "" then
		return false
	end

	if #ballId > 64 then
		return false
	end

	return true

end


--------------------------------------------------
-- GET BALL DEFINITION
--------------------------------------------------

local function getBallDefinition(ballId)

	if not isValidBallIdString(ballId) then
		return nil
	end

	local definition =
		BallDefinitions[ballId]

	if typeof(definition) ~= "table" then
		return nil
	end

	return definition

end


--------------------------------------------------
-- GET DEVELOPER PRODUCT ID
--
-- SERVER ONLY.
--
-- The client never supplies this value.
--------------------------------------------------

local function getBallProductId(ballId)

	if not isValidBallIdString(ballId) then
		return nil
	end

	local productId =
		BallProductDefinitions[ballId]

	if not isFiniteNumber(productId) then
		return nil
	end

	if productId <= 0 then
		return nil
	end

	if productId % 1 ~= 0 then
		return nil
	end

	return productId

end


--------------------------------------------------
-- VALID BALL
--------------------------------------------------

local function isValidBallId(ballId)

	return getBallDefinition(ballId) ~= nil

end


--------------------------------------------------
-- IS TUTORIAL BALL
--------------------------------------------------

local function isTutorialBall(ballId)

	local definition =
		getBallDefinition(ballId)

	if not definition then
		return false
	end

	return definition.IsTutorial == true

end


--------------------------------------------------
-- VALIDATE BALL DEFINITION
--------------------------------------------------

local function validateBallDefinition(
	ballId,
	definition
)

	if not isValidBallIdString(ballId) then

		return false,
			"INVALID_BALL_ID"

	end


	if typeof(definition) ~= "table" then

		return false,
			"DEFINITION_NOT_TABLE"

	end


	if typeof(definition.DisplayName) ~= "string"
		or definition.DisplayName == "" then

		return false,
			"INVALID_DISPLAY_NAME"

	end


	if not isFiniteNumber(
		definition.ForwardSpeed
	)
		or definition.ForwardSpeed <= 0 then

		return false,
			"INVALID_FORWARD_SPEED"

	end


	if not isFiniteNumber(
		definition.HorizontalSpeed
	)
		or definition.HorizontalSpeed <= 0 then

		return false,
			"INVALID_HORIZONTAL_SPEED"

	end


	if not isFiniteNumber(
		definition.WinsCost
	)
		or definition.WinsCost < 0
		or definition.WinsCost % 1 ~= 0 then

		return false,
			"INVALID_WINS_COST"

	end


	if not isFiniteNumber(
		definition.RequiredRebirths
	)
		or definition.RequiredRebirths < 0
		or definition.RequiredRebirths % 1 ~= 0 then

		return false,
			"INVALID_REQUIRED_REBIRTHS"

	end


	if not isFiniteNumber(
		definition.DisplayOrder
	)
		or definition.DisplayOrder <= 0
		or definition.DisplayOrder % 1 ~= 0 then

		return false,
			"INVALID_DISPLAY_ORDER"

	end


	if definition.IsTutorial ~= nil
		and typeof(definition.IsTutorial) ~= "boolean" then

		return false,
			"INVALID_TUTORIAL_FLAG"

	end


	return true,
		"VALID"

end


--------------------------------------------------
-- VALIDATE ALL BALLS AND PRODUCTS
--------------------------------------------------

local function validateDefinitions()

	if typeof(BallDefinitions) ~= "table" then

		error(
			"[BallService] BallDefinitions must return a table."
		)

	end


	if typeof(BallProductDefinitions) ~= "table" then

		error(
			"[BallService] BallProductDefinitions must return a table."
		)

	end


	local ballCount =
		0

	local productCount =
		0

	local displayOrders =
		{}

	local productIds =
		{}


	--------------------------------------------------
	-- BALL DEFINITIONS
	--------------------------------------------------

	for ballId, definition in pairs(
		BallDefinitions
	) do

		local valid,
			reason =
			validateBallDefinition(
				ballId,
				definition
			)


		if not valid then

			error(
				"[BallService] Invalid ball definition '"
					.. tostring(ballId)
					.. "': "
					.. tostring(reason)
			)

		end


		ballCount += 1


		--------------------------------------------------
		-- DISPLAY ORDER MUST BE UNIQUE
		--------------------------------------------------

		local displayOrder =
			definition.DisplayOrder


		if displayOrders[displayOrder] then

			error(
				"[BallService] Duplicate DisplayOrder "
					.. tostring(displayOrder)
					.. " between '"
					.. tostring(
						displayOrders[displayOrder]
					)
					.. "' and '"
					.. tostring(ballId)
					.. "'."
			)

		end


		displayOrders[displayOrder] =
			ballId

	end


	--------------------------------------------------
	-- PRODUCT DEFINITIONS
	--------------------------------------------------

	for ballId, productId in pairs(
		BallProductDefinitions
	) do

		if not isValidBallIdString(ballId) then

			error(
				"[BallService] Invalid BallProductDefinitions key: "
					.. tostring(ballId)
			)

		end


		if not BallDefinitions[ballId] then

			error(
				"[BallService] Product references unknown ball: "
					.. tostring(ballId)
			)

		end


		if not isFiniteNumber(productId)
			or productId <= 0
			or productId % 1 ~= 0 then

			error(
				"[BallService] Invalid Developer Product ID for "
					.. tostring(ballId)
			)

		end


		if productIds[productId] then

			error(
				"[BallService] Duplicate Developer Product ID "
					.. tostring(productId)
					.. " used by '"
					.. tostring(productIds[productId])
					.. "' and '"
					.. tostring(ballId)
					.. "'."
			)

		end


		productIds[productId] =
			ballId


		productCount += 1

	end


	--------------------------------------------------
	-- STRAIGHT BALL
	--------------------------------------------------

	local straight =
		BallDefinitions[DEFAULT_BALL]


	if not straight then

		error(
			"[BallService] Missing required ball: "
				.. DEFAULT_BALL
		)

	end


	if straight.WinsCost ~= 0 then

		error(
			"[BallService] StraightBall must have WinsCost = 0."
		)

	end


	if straight.RequiredRebirths ~= 0 then

		error(
			"[BallService] StraightBall must have RequiredRebirths = 0."
		)

	end


	if getBallProductId(DEFAULT_BALL) ~= nil then

		error(
			"[BallService] StraightBall cannot have a Developer Product."
		)

	end


	--------------------------------------------------
	-- AFTERSHOCK
	--------------------------------------------------

	local aftershock =
		BallDefinitions[TUTORIAL_BALL]


	if not aftershock then

		error(
			"[BallService] Missing required tutorial ball: "
				.. TUTORIAL_BALL
		)

	end


	if aftershock.IsTutorial ~= true then

		error(
			"[BallService] Aftershock must have IsTutorial = true."
		)

	end


	if getBallProductId(TUTORIAL_BALL) ~= nil then

		error(
			"[BallService] Aftershock must NOT have a Developer Product."
		)

	end


	--------------------------------------------------
	-- ALL TUTORIAL BALLS CANNOT HAVE PRODUCTS
	--------------------------------------------------

	for ballId, definition in pairs(
		BallDefinitions
	) do

		if definition.IsTutorial == true then

			if getBallProductId(ballId) ~= nil then

				error(
					"[BallService] Tutorial ball cannot have Developer Product: "
						.. tostring(ballId)
				)

			end

		end

	end


	--------------------------------------------------
	-- ALL NON-TUTORIAL, NON-DEFAULT BALLS MUST
	-- HAVE A DEVELOPER PRODUCT.
	--------------------------------------------------

	for ballId, definition in pairs(
		BallDefinitions
	) do

		if ballId ~= DEFAULT_BALL
			and definition.IsTutorial ~= true then

			if getBallProductId(ballId) == nil then

				error(
					"[BallService] Missing Developer Product for: "
						.. tostring(ballId)
				)

			end

		end

	end


	print(
		"[BallService] Definitions validated:",
		ballCount,
		"balls /",
		productCount,
		"Developer Products"
	)

end


--------------------------------------------------
-- PLAYER DATA HELPERS
--------------------------------------------------

local function getWins(player)

	local wins =
		PlayerDataService.GetWins(player)


	if not isFiniteNumber(wins) then
		return 0
	end


	return math.max(
		0,
		math.floor(wins)
	)

end


--------------------------------------------------

local function getRebirths(player)

	local rebirths =
		PlayerDataService.GetRebirths(player)


	if not isFiniteNumber(rebirths) then
		return 0
	end


	return math.max(
		0,
		math.floor(rebirths)
	)

end


--------------------------------------------------
-- GET PLAYER DATA
--------------------------------------------------

local function getPlayerData(player)

	return PlayerDataService.GetData(
		player
	)

end


--------------------------------------------------
-- OWNS BALL
--------------------------------------------------

local function ownsBall(
	player,
	ballId
)

	if not isValidBallId(ballId) then
		return false
	end

	return PlayerDataService.OwnsBall(
		player,
		ballId
	) == true

end


--------------------------------------------------
-- GET EQUIPPED BALL
--------------------------------------------------

local function getEquippedBall(player)

	local equipped =
		PlayerDataService.GetEquippedBall(
			player
		)


	if not isValidBallId(equipped) then

		return DEFAULT_BALL

	end


	if not ownsBall(
		player,
		equipped
	) then

		return DEFAULT_BALL

	end


	return equipped

end


--------------------------------------------------
-- APPLY BALL MOVEMENT ATTRIBUTES
--
-- These attributes are copied from SERVER ONLY
-- BallDefinitions.
--------------------------------------------------

local function applyBallMovementAttributes(
	player,
	ballId
)

	local definition =
		getBallDefinition(ballId)


	if not definition then

		return false,
			"INVALID_BALL"

	end


	player:SetAttribute(
		"EquippedBall",
		ballId
	)


	player:SetAttribute(
		"BallForwardSpeed",
		definition.ForwardSpeed
	)


	player:SetAttribute(
		"BallHorizontalSpeed",
		definition.HorizontalSpeed
	)


	return true,
		"APPLIED"

end


--------------------------------------------------
-- SET EQUIPPED BALL
--------------------------------------------------

local function setEquippedBall(
	player,
	ballId
)

	if not player
		or not player:IsDescendantOf(Players) then

		return false,
			"INVALID_PLAYER"

	end


	if not isValidBallId(ballId) then

		return false,
			"INVALID_BALL"

	end


	if not ownsBall(
		player,
		ballId
	) then

		return false,
			"NOT_OWNED"

	end


	local equipped =
		PlayerDataService.EquipBall(
			player,
			ballId
		)


	if not equipped then

		return false,
			"EQUIP_FAILED"

	end


	local applied,
		reason =
		applyBallMovementAttributes(
			player,
			ballId
		)


	if not applied then

		return false,
			reason

	end


	return true,
		"EQUIPPED"

end


--------------------------------------------------
-- WINS DISPLAY
--------------------------------------------------

local function updateWinsDisplay(
	player,
	wins
)

	if not player
		or not player:IsDescendantOf(Players) then

		return false

	end


	if not isFiniteNumber(wins) then
		return false
	end


	wins =
		math.max(
			0,
			math.floor(wins)
		)


	player:SetAttribute(
		"Wins",
		wins
	)


	local leaderstats =
		player:FindFirstChild(
			"leaderstats"
		)


	if leaderstats then

		local winsValue =
			leaderstats:FindFirstChild(
				"Wins"
			)


		if winsValue
			and winsValue:IsA("IntValue") then

			winsValue.Value =
				wins

		end

	end


	return true

end


--------------------------------------------------
-- AUTHORITATIVE WIN AWARD
--------------------------------------------------

local function awardWin(
	player,
	amount
)

	if not player
		or not player:IsDescendantOf(Players) then

		return false,
			"INVALID_PLAYER",
			0

	end


	if amount == nil then
		amount = 1
	end


	if not isFiniteNumber(amount) then

		return false,
			"INVALID_AMOUNT",
			getWins(player)

	end


	amount =
		math.floor(amount)


	if amount <= 0 then

		return false,
			"INVALID_AMOUNT",
			getWins(player)

	end


	if amount > 1000000 then

		return false,
			"AMOUNT_TOO_LARGE",
			getWins(player)

	end


	local data =
		getPlayerData(player)


	if not data then

		return false,
			"DATA_NOT_LOADED",
			0

	end


	local added =
		PlayerDataService.AddWins(
			player,
			amount
		)


	if not added then

		return false,
			"ADD_WINS_FAILED",
			getWins(player)

	end


	local newWins =
		getWins(player)


	updateWinsDisplay(
		player,
		newWins
	)


	return true,
		"WIN_AWARDED",
		newWins

end


--------------------------------------------------
-- SERVER WIN API
--------------------------------------------------

awardWinFunction.OnInvoke =
	function(
		player,
		amount
	)

		return awardWin(
			player,
			amount
		)

	end


--------------------------------------------------
-- BUILD SHOP STATE
--
-- IMPORTANT:
--
-- The server may safely send display information
-- to the client.
--
-- ProductId is intentionally NOT included.
--
-- The client does NOT need ProductId to request
-- a purchase.
--------------------------------------------------

local function getShopState(player)

	if not player
		or not player:IsDescendantOf(Players) then

		return nil

	end


	local data =
		getPlayerData(player)


	if not data then
		return nil
	end


	local ownedBalls =
		{}


	if typeof(data.OwnedBalls) == "table" then

		for ballId, owned in pairs(
			data.OwnedBalls
		) do

			if owned == true
				and isValidBallId(ballId) then

				ownedBalls[ballId] =
					true

			end

		end

	end


	--------------------------------------------------
	-- STRAIGHT BALL IS ALWAYS OWNED
	--------------------------------------------------

	ownedBalls[DEFAULT_BALL] =
		true


	local equippedBall =
		getEquippedBall(player)


	local wins =
		getWins(player)


	local rebirths =
		getRebirths(player)


	updateWinsDisplay(
		player,
		wins
	)


	--------------------------------------------------
	-- BALL LIST
	--
	-- This is a sanitized copy.
	--
	-- No DeveloperProductId is sent.
	--------------------------------------------------

	local balls =
		{}


	for ballId, definition in pairs(
		BallDefinitions
	) do

		table.insert(
	balls,
	{
		BallId = ballId,
		DisplayName = definition.DisplayName,

		ForwardSpeed = definition.ForwardSpeed,
		HorizontalSpeed = definition.HorizontalSpeed,

		WinsCost = definition.WinsCost,
		RequiredRebirths = definition.RequiredRebirths,
		DisplayOrder = definition.DisplayOrder,

		IsTutorial = definition.IsTutorial == true,

		Owned = ownedBalls[ballId] == true,
		Equipped = equippedBall == ballId,

		HasDeveloperProduct =
			getBallProductId(ballId) ~= nil,

		-- Server resolves the product ID for this exact ball.
		DeveloperProductId =
			getBallProductId(ballId),
	}
)

	end


	table.sort(
		balls,

		function(a, b)

			return a.DisplayOrder
				< b.DisplayOrder

		end
	)


	return {

		Balls =
			balls,

		OwnedBalls =
			ownedBalls,

		EquippedBall =
			equippedBall,

		Wins =
			wins,

		Rebirths =
			rebirths,

	}

end


--------------------------------------------------
-- SHOP STATE REQUEST
--------------------------------------------------

ballShopStateRemote.OnServerInvoke =
	function(player)

		return getShopState(player)

	end


--------------------------------------------------
-- VALIDATE PURCHASE SERVICE
--------------------------------------------------

if typeof(PurchaseService) ~= "table" then

	error(
		"[BallService] PurchaseServiceModule must return a table."
	)

end


if typeof(
	PurchaseService.RegisterProduct
) ~= "function" then

	error(
		"[BallService] PurchaseService.RegisterProduct is missing."
	)

end


if typeof(
	PurchaseService.GetHandler
) ~= "function" then

	error(
		"[BallService] PurchaseService.GetHandler is missing."
	)

end


--------------------------------------------------
-- REGISTER BALL DEVELOPER PRODUCTS
--------------------------------------------------

local function registerBallProducts()

	local registered =
		0


	for ballId, productId in pairs(
		BallProductDefinitions
	) do

		local definition =
			getBallDefinition(ballId)


		if not definition then

			error(
				"[BallService] Product references invalid ball: "
					.. tostring(ballId)
			)

		end


		if ballId == DEFAULT_BALL then

			error(
				"[BallService] StraightBall cannot have a Developer Product."
			)

		end


		if isTutorialBall(ballId) then

			error(
				"[BallService] Tutorial ball cannot have a Developer Product: "
					.. tostring(ballId)
			)

		end


		if PurchaseService.GetHandler(
			productId
		) ~= nil then

			error(
				"[BallService] Developer Product already registered: "
					.. tostring(productId)
					.. " for "
					.. tostring(ballId)
			)

		end


		local registeredBallId =
			ballId

		local registeredProductId =
			productId


		PurchaseService.RegisterProduct(
			registeredProductId,

			function(
				player,
				receiptInfo
			)

				--------------------------------------------------
				-- PLAYER VALIDATION
				--------------------------------------------------

				if not player
					or not player:IsDescendantOf(
						Players
					) then

					return false

				end


				--------------------------------------------------
				-- RECEIPT VALIDATION
				--------------------------------------------------

				if typeof(receiptInfo) ~= "table" then

					return false

				end


				if receiptInfo.ProductId
					~= registeredProductId then

					warn(
						"[BallService] Receipt ProductId mismatch:",
						player.Name,
						registeredBallId
					)

					return false

				end


				local purchaseId =
					receiptInfo.PurchaseId


				if typeof(purchaseId) ~= "string"
					or purchaseId == "" then

					warn(
						"[BallService] Receipt missing PurchaseId:",
						player.Name,
						registeredBallId
					)

					return false

				end


				--------------------------------------------------
				-- REVALIDATE BALL
				--------------------------------------------------

				local currentDefinition =
					getBallDefinition(
						registeredBallId
					)


				if not currentDefinition then

					warn(
						"[BallService] Purchased ball no longer exists:",
						registeredBallId
					)

					return false

				end


				--------------------------------------------------
				-- REVALIDATE PRODUCT MAPPING
				--------------------------------------------------

				local currentProductId =
					getBallProductId(
						registeredBallId
					)


				if currentProductId
					~= registeredProductId then

					warn(
						"[BallService] Product mapping changed:",
						registeredBallId
					)

					return false

				end


				--------------------------------------------------
				-- TUTORIAL BALLS ARE NEVER ROBUX PURCHASES
				--------------------------------------------------

				if isTutorialBall(
					registeredBallId
				) then

					return false

				end


				--------------------------------------------------
				-- TRANSACTION LOCK
				--------------------------------------------------

				local lockKey =
					tostring(player.UserId)
					.. ":"
					.. tostring(
						registeredProductId
					)


				if transactionLocks[
					lockKey
				] then

					return false

				end


				transactionLocks[
					lockKey
				] =
					true


				local success,
					result =
					xpcall(

						function()

							--------------------------------------------------
							-- ALREADY OWNED
							--
							-- This is important for receipt retries.
							--
							-- If the ball was already granted, the receipt
							-- can safely be completed.
							--------------------------------------------------

							if ownsBall(
								player,
								registeredBallId
							) then

								return true

							end


							--------------------------------------------------
							-- DATA MUST BE LOADED
							--------------------------------------------------

							if not getPlayerData(
								player
							) then

								return false

							end


							--------------------------------------------------
							-- GRANT BALL
							--------------------------------------------------

							local granted =
								PlayerDataService.AddOwnedBall(
									player,
									registeredBallId
								)


							if not granted then

								warn(
									"[BallService] Failed to grant Robux ball:",
									player.Name,
									registeredBallId
								)

								return false

							end


							--------------------------------------------------
							-- AUTO EQUIP
							--------------------------------------------------

							local equipped,
								equipReason =
								setEquippedBall(
									player,
									registeredBallId
								)


							if not equipped then

								warn(
									"[BallService] Robux ball granted but auto-equip failed:",
									player.Name,
									registeredBallId,
									equipReason
								)

							end


							return true

						end,

						function(errorMessage)

							return errorMessage

						end
					)


				transactionLocks[
					lockKey
				] =
					nil


				if not success then

					warn(
						"[BallService] Developer Product handler error:",
						player.Name,
						registeredBallId,
						result
					)

					return false

				end


				return result == true

			end
		)


		registered += 1

	end


	print(
		"[BallService] Registered",
		registered,
		"ball Developer Products."
	)

end


--------------------------------------------------
-- BUY BALL WITH WINS
--
-- IMPORTANT:
--
-- Wins purchase:
--
-- RequiredRebirths MUST be satisfied.
--
-- Developer Product purchase:
--
-- RequiredRebirths are bypassed.
--------------------------------------------------

local function buyWithWins(
	player,
	ballId
)

	if not player
		or not player:IsDescendantOf(Players) then

		return false,
			"INVALID_PLAYER"

	end


	local definition =
		getBallDefinition(ballId)


	if not definition then

		return false,
			"INVALID_BALL"

	end


	if ballId == DEFAULT_BALL then

		return false,
			"STARTING_BALL"

	end


	if ownsBall(
		player,
		ballId
	) then

		return false,
			"ALREADY_OWNED"

	end


	--------------------------------------------------
	-- REBIRTH REQUIREMENT
	--------------------------------------------------

	local rebirths =
		getRebirths(player)


	if rebirths <
		definition.RequiredRebirths then

		return false,
			"REBIRTH_REQUIREMENT"

	end


	--------------------------------------------------
	-- WINS REQUIREMENT
	--------------------------------------------------

	local wins =
		getWins(player)


	if wins <
		definition.WinsCost then

		return false,
			"NOT_ENOUGH_WINS"

	end


	--------------------------------------------------
	-- DATA MUST BE LOADED
	--------------------------------------------------

	if not getPlayerData(player) then

		return false,
			"DATA_NOT_LOADED"

	end


	--------------------------------------------------
	-- LOCK
	--------------------------------------------------

	local lockKey =
		tostring(player.UserId)
		.. ":WinsPurchase"


	if transactionLocks[
		lockKey
	] then

		return false,
			"PURCHASE_BUSY"

	end


	transactionLocks[
		lockKey
	] =
		true


	local success,
		result =
		xpcall(

			function()

				--------------------------------------------------
				-- RECHECK OWNERSHIP
				--------------------------------------------------

				if ownsBall(
					player,
					ballId
				) then

					return {
						Success = false,
						Reason = "ALREADY_OWNED",
					}

				end


				--------------------------------------------------
				-- RECHECK REBIRTHS
				--------------------------------------------------

				local currentRebirths =
					getRebirths(player)


				if currentRebirths <
					definition.RequiredRebirths then

					return {
						Success = false,
						Reason = "REBIRTH_REQUIREMENT",
					}

				end


				--------------------------------------------------
				-- RECHECK WINS
				--------------------------------------------------

				local currentWins =
					getWins(player)


				if currentWins <
					definition.WinsCost then

					return {
						Success = false,
						Reason = "NOT_ENOUGH_WINS",
					}

				end


				--------------------------------------------------
				-- REMOVE WINS
				--------------------------------------------------

				local removed =
					PlayerDataService.RemoveWins(
						player,
						definition.WinsCost
					)


				if not removed then

					return {
						Success = false,
						Reason = "NOT_ENOUGH_WINS",
					}

				end


				updateWinsDisplay(
					player,
					getWins(player)
				)


				--------------------------------------------------
				-- GRANT BALL
				--------------------------------------------------

				local granted =
					PlayerDataService.AddOwnedBall(
						player,
						ballId
					)


				if not granted then

					--------------------------------------------------
					-- REFUND
					--------------------------------------------------

					local refunded =
						PlayerDataService.AddWins(
							player,
							definition.WinsCost
						)


					if refunded then

						updateWinsDisplay(
							player,
							getWins(player)
						)

					else

						warn(
							"[BallService] CRITICAL: Failed to refund Wins:",
							player.Name,
							ballId,
							definition.WinsCost
						)

					end


					return {
						Success = false,
						Reason = "PURCHASE_FAILED",
					}

				end


				--------------------------------------------------
				-- AUTO EQUIP
				--------------------------------------------------

				local equipped,
					equipReason =
					setEquippedBall(
						player,
						ballId
					)


				if not equipped then

					warn(
						"[BallService] Wins ball granted but auto-equip failed:",
						player.Name,
						ballId,
						equipReason
					)

				end


				return {
					Success = true,
					Reason = "PURCHASED",
				}

			end,

			function(errorMessage)

				return {
					Success = false,
					Reason = "PURCHASE_FAILED",
					Error = errorMessage,
				}

			end
		)


	transactionLocks[
		lockKey
	] =
		nil


	if not success then

		warn(
			"[BallService] Wins purchase error:",
			player.Name,
			ballId,
			result.Error
		)

		return false,
			"PURCHASE_FAILED"

	end


	if typeof(result) ~= "table" then

		return false,
			"PURCHASE_FAILED"

	end


	return result.Success == true,
		result.Reason

end


--------------------------------------------------
-- REQUEST ROBUX PURCHASE
--
-- CLIENT PROVIDES ONLY:
--
--     ballId
--
-- SERVER RESOLVES:
--
--     DeveloperProductId
--------------------------------------------------

local function requestRobuxPurchase(
	player,
	ballId
)

	if not player
		or not player:IsDescendantOf(Players) then

		return false,
			"INVALID_PLAYER"

	end


	local definition =
		getBallDefinition(ballId)


	if not definition then

		return false,
			"INVALID_BALL"

	end


	if ballId == DEFAULT_BALL then

		return false,
			"STARTING_BALL"

	end


	if isTutorialBall(ballId) then

		return false,
			"TUTORIAL_BALL"

	end


	if ownsBall(
		player,
		ballId
	) then

		return false,
			"ALREADY_OWNED"

	end


	--------------------------------------------------
	-- SERVER RESOLVES PRODUCT ID
	--------------------------------------------------

	local productId =
		getBallProductId(ballId)


	if not productId then

		warn(
			"[BallService] No Developer Product configured:",
			ballId
		)

		return false,
			"NO_DEVELOPER_PRODUCT"

	end


	--------------------------------------------------
	-- PRODUCT MUST BE REGISTERED
	--------------------------------------------------

	if PurchaseService.GetHandler(
		productId
	) == nil then

		warn(
			"[BallService] Product is not registered:",
			ballId,
			productId
		)

		return false,
			"PRODUCT_NOT_REGISTERED"

	end


	--------------------------------------------------
	-- PROMPT
	--------------------------------------------------

	local success,
		errorMessage =
		pcall(

			function()

				MarketplaceService:PromptProductPurchase(
					player,
					productId
				)

			end
		)


	if not success then

		warn(
			"[BallService] PromptProductPurchase failed:",
			player.Name,
			ballId,
			errorMessage
		)

		return false,
			"PROMPT_FAILED"

	end


	return true,
		"PROMPTED"

end


--------------------------------------------------
-- RATE LIMIT
--------------------------------------------------

local function isRateLimited(player)

	local now =
		os.clock()


	local previous =
		lastRequestTime[player]


	if previous
		and now - previous
			< REQUEST_COOLDOWN then

		return true

	end


	lastRequestTime[player] =
		now


	return false

end


--------------------------------------------------
-- PURCHASE RESULT
--------------------------------------------------

local function sendPurchaseResult(
	player,
	success,
	reason,
	ballId
)

	if not player
		or not player:IsDescendantOf(Players) then

		return

	end


	ballRemote:FireClient(
		player,
		"PurchaseResult",
		{

			Success =
				success,

			Reason =
				reason,

			BallId =
				ballId,

		}
	)

end


--------------------------------------------------
-- EQUIP RESULT
--------------------------------------------------

local function sendEquipResult(
	player,
	success,
	reason,
	ballId
)

	if not player
		or not player:IsDescendantOf(Players) then

		return

	end


	ballRemote:FireClient(
		player,
		"EquipResult",
		{

			Success =
				success,

			Reason =
				reason,

			BallId =
				ballId,

		}
	)

end


--------------------------------------------------
-- INITIALIZE PLAYER
--------------------------------------------------

local function initializePlayer(player)

	if not player
		or not player:IsDescendantOf(Players) then

		return

	end


	--------------------------------------------------
	-- WAIT FOR DATA
	--------------------------------------------------

	local data


	for _ = 1, 100 do

		if not player.Parent then
			return
		end


		data =
			getPlayerData(player)


		if data then
			break
		end


		task.wait(0.1)

	end


	if not data then

		warn(
			"[BallService] Player data did not load:",
			player.Name
		)

		return

	end


	--------------------------------------------------
	-- GUARANTEE STRAIGHT BALL
	--------------------------------------------------

	if not ownsBall(
		player,
		DEFAULT_BALL
	) then

		local added =
			PlayerDataService.AddOwnedBall(
				player,
				DEFAULT_BALL
			)


		if not added then

			warn(
				"[BallService] Failed to guarantee StraightBall:",
				player.Name
			)

			return

		end

	end


	--------------------------------------------------
	-- RESTORE EQUIPPED BALL
	--------------------------------------------------

	local equipped =
		PlayerDataService.GetEquippedBall(
			player
		)


	if not isValidBallId(equipped)
		or not ownsBall(
			player,
			equipped
		) then

		equipped =
			DEFAULT_BALL

	end


	local success,
		reason =
		setEquippedBall(
			player,
			equipped
		)


	if not success then

		warn(
			"[BallService] Failed to restore equipped ball:",
			player.Name,
			equipped,
			reason
		)


		setEquippedBall(
			player,
			DEFAULT_BALL
		)

	end


	--------------------------------------------------
	-- INITIAL WINS SYNC
	--------------------------------------------------

	updateWinsDisplay(
		player,
		getWins(player)
	)

end


--------------------------------------------------
-- REMOTE REQUESTS
--------------------------------------------------

ballRemote.OnServerEvent:Connect(
	function(
		player,
		action,
		ballId
	)

	--------------------------------------------------
	-- PLAYER
	--------------------------------------------------

	if not player
		or not player:IsDescendantOf(Players) then

		return

	end


	--------------------------------------------------
	-- RATE LIMIT
	--------------------------------------------------

	if isRateLimited(player) then
		return
	end


	--------------------------------------------------
	-- ACTION
	--------------------------------------------------

	if typeof(action) ~= "string"
		or #action > 32 then

		return

	end


	--------------------------------------------------
	-- BALL ID
	--------------------------------------------------

	if not isValidBallIdString(ballId) then
		return
	end


	if not isValidBallId(ballId) then

		sendPurchaseResult(
			player,
			false,
			"INVALID_BALL",
			ballId
		)

		return

	end


	--------------------------------------------------
	-- BUY WITH WINS
	--------------------------------------------------

	if action == "BuyWithWins" then

		local success,
			reason =
			buyWithWins(
				player,
				ballId
			)


		sendPurchaseResult(
			player,
			success,
			reason,
			ballId
		)


		return

	end


	--------------------------------------------------
	-- BUY WITH ROBUX
	--------------------------------------------------

	if action == "BuyWithRobux" then

		local success,
			reason =
			requestRobuxPurchase(
				player,
				ballId
			)


		if not success then

			sendPurchaseResult(
				player,
				false,
				reason,
				ballId
			)

		end


		return

	end


	--------------------------------------------------
	-- EQUIP
	--------------------------------------------------

	if action == "Equip" then

		local success,
			reason =
			setEquippedBall(
				player,
				ballId
			)


		sendEquipResult(
			player,
			success,
			reason,
			ballId
		)


		return

	end


	--------------------------------------------------
	-- UNEQUIP
	--
	-- Equipping StraightBall acts as unequipping.
	--------------------------------------------------

	if action == "Unequip" then

		local success,
			reason =
			setEquippedBall(
				player,
				DEFAULT_BALL
			)


		sendEquipResult(
			player,
			success,
			reason,
			DEFAULT_BALL
		)


		return

	end


	--------------------------------------------------
	-- UNKNOWN ACTION
	--------------------------------------------------

	warn(
		"[BallService] Unknown action:",
		player.Name,
		action
	)

end)


--------------------------------------------------
-- VALIDATE CONFIGURATION FIRST
--------------------------------------------------

validateDefinitions()


--------------------------------------------------
-- REGISTER BALL PRODUCTS
--------------------------------------------------

registerBallProducts()


--------------------------------------------------
-- PLAYER ADDED
--------------------------------------------------

Players.PlayerAdded:Connect(
	function(player)

		task.spawn(
			initializePlayer,
			player
		)

	end
)


--------------------------------------------------
-- EXISTING PLAYERS
--------------------------------------------------

for _, player in ipairs(
	Players:GetPlayers()
) do

	task.spawn(
		initializePlayer,
		player
	)

end


--------------------------------------------------
-- PLAYER REMOVING
--------------------------------------------------

Players.PlayerRemoving:Connect(
	function(player)

		lastRequestTime[player] =
			nil


		local prefix =
			tostring(player.UserId)
			.. ":"


		for key in pairs(
			transactionLocks
		) do

			if string.sub(
				key,
				1,
				#prefix
			) == prefix then

				transactionLocks[key] =
					nil

			end

		end

	end
)


--------------------------------------------------
-- READY
--------------------------------------------------

print("================================")

print(
	"[BallService] SERVER READY"
)

print(
	"[BallService] Ball Definitions = SERVER ONLY"
)

print(
	"[BallService] Product Definitions = SERVER ONLY"
)

print(
	"[BallService] Starting Ball =",
	DEFAULT_BALL
)

print(
	"[BallService] Tutorial Ball =",
	TUTORIAL_BALL
)

print(
	"[BallService] Ball Count =",
	#BallDefinitions
)

print(
	"[BallService] Wins Purchases = ENABLED"
)

print(
	"[BallService] Robux Purchases = ENABLED"
)

print(
	"[BallService] Robux Bypasses Rebirth = YES"
)

print(
	"[BallService] Wins Require Rebirth = YES"
)

print(
	"[BallService] PurchaseService Registry = ENABLED"
)

print(
	"[BallService] PurchaseService Owns ProcessReceipt = YES"
)

print(
	"[BallService] Client ProductId = NEVER TRUSTED"
)

print(
	"[BallService] Client Price = NEVER TRUSTED"
)

print(
	"[BallService] Client WinsCost = NEVER TRUSTED"
)

print(
	"[BallService] Client Rebirth Requirement = NEVER TRUSTED"
)

print(
	"[BallService] Client Ball Speed = NEVER TRUSTED"
)

print(
	"[BallService] Server Win Award API = ENABLED"
)

print(
	"[BallService] Transaction Locks = ENABLED"
)

print(
	"[BallService] Remote Rate Limiting = ENABLED"
)

print(
	"[BallService] Shop State = SERVER AUTHORITATIVE"
)

print("================================")