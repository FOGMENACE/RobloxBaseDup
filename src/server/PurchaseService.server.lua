--------------------------------------------------
-- PURCHASE SERVICE
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > PurchaseService
--
-- PURPOSE:
--
-- Central Developer Product receipt processor.
--
-- RESPONSIBILITIES:
--
-- - Owns MarketplaceService.ProcessReceipt
-- - Validates receipt information
-- - Finds the player
-- - Finds the registered product handler
-- - Executes the handler safely
-- - Grants the receipt ONLY when the handler
--   explicitly returns true
--
-- DOES NOT OWN:
--
-- - Player data
-- - Oil collection
-- - Oil definitions
-- - Ball ownership
-- - Ball equipping
-- - Wins
-- - XP
-- - Rebirths
-- - Developer Product definitions
--
-- PRODUCT HANDLERS:
--
-- Individual products are registered through:
--
--     PurchaseServiceModule
--
-- The handler is responsible for deciding what
-- the specific Developer Product grants.
--
-- IMPORTANT:
--
-- Clients NEVER determine:
--
-- - ProductId
-- - Reward amount
-- - Reward type
-- - Player receiving the reward
--
-- Roblox provides receiptInfo to the server.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players =
	game:GetService(
		"Players"
	)

local MarketplaceService =
	game:GetService(
		"MarketplaceService"
	)

local ServerScriptService =
	game:GetService(
		"ServerScriptService"
	)


--------------------------------------------------
-- PURCHASE SERVICE MODULE
--------------------------------------------------

local PurchaseServiceModule =
	require(
		ServerScriptService
			:WaitForChild(
				"PurchaseServiceModule"
			)
	)


--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local DEBUG =
	true


--------------------------------------------------
-- DEBUG
--------------------------------------------------

local function debugPrint(...)

	if not DEBUG then

		return

	end


	print(
		"[PurchaseService]",
		...
	)

end


--------------------------------------------------
-- FINITE NUMBER
--------------------------------------------------

local function isFiniteNumber(
	value
)

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
-- VALIDATE RECEIPT
--------------------------------------------------

local function validateReceipt(
	receiptInfo
)

	--------------------------------------------------
	-- RECEIPT TABLE
	--------------------------------------------------

	if typeof(receiptInfo) ~= "table" then

		warn(
			"[PurchaseService]",
			"Invalid receipt table."
		)

		return false

	end


	--------------------------------------------------
	-- PLAYER ID
	--------------------------------------------------

	local playerId =
		receiptInfo.PlayerId


	if not isFiniteNumber(
		playerId
	)
		or playerId <= 0
		or playerId % 1 ~= 0 then

		warn(
			"[PurchaseService]",
			"Invalid PlayerId."
		)

		return false

	end


	--------------------------------------------------
	-- PRODUCT ID
	--------------------------------------------------

	local productId =
		receiptInfo.ProductId


	if not isFiniteNumber(
		productId
	)
		or productId <= 0
		or productId % 1 ~= 0 then

		warn(
			"[PurchaseService]",
			"Invalid ProductId."
		)

		return false

	end


	--------------------------------------------------
	-- PURCHASE ID
	--------------------------------------------------

	local purchaseId =
		receiptInfo.PurchaseId


	if typeof(purchaseId) ~= "string"
		or purchaseId == "" then

		warn(
			"[PurchaseService]",
			"Invalid PurchaseId."
		)

		return false

	end


	--------------------------------------------------
	-- PURCHASE ID LENGTH
	--------------------------------------------------

	if #purchaseId > 256 then

		warn(
			"[PurchaseService]",
			"PurchaseId is too long."
		)

		return false

	end


	return true

end


--------------------------------------------------
-- PROCESS RECEIPT
--
-- THIS IS THE ONLY ProcessReceipt OWNER.
--------------------------------------------------

MarketplaceService.ProcessReceipt =
	function(
		receiptInfo
	)

		--------------------------------------------------
		-- VALIDATE RECEIPT
		--------------------------------------------------

		if not validateReceipt(
			receiptInfo
		) then

			--------------------------------------------------
			-- Invalid receipts remain unprocessed.
			--------------------------------------------------

			return Enum.ProductPurchaseDecision.NotProcessedYet

		end


		--------------------------------------------------
		-- RECEIPT VALUES
		--------------------------------------------------

		local playerId =
			receiptInfo.PlayerId

		local productId =
			receiptInfo.ProductId

		local purchaseId =
			receiptInfo.PurchaseId


		--------------------------------------------------
		-- FIND PLAYER
		--------------------------------------------------

		local player =
			Players:GetPlayerByUserId(
				playerId
			)


		--------------------------------------------------
		-- PLAYER NOT PRESENT
		--------------------------------------------------

		if not player then

			debugPrint(
				"Player not currently in server:",
				playerId,
				"| ProductId:",
				productId,
				"| PurchaseId:",
				purchaseId
			)


			--------------------------------------------------
			-- Do NOT grant the product.
			--
			-- Roblox will retry the receipt later.
			--------------------------------------------------

			return Enum.ProductPurchaseDecision.NotProcessedYet

		end


		--------------------------------------------------
		-- FIND PRODUCT HANDLER
		--------------------------------------------------

		local handler =
			PurchaseServiceModule.GetHandler(
				productId
			)


		--------------------------------------------------
		-- UNKNOWN PRODUCT
		--------------------------------------------------

		if typeof(handler) ~= "function" then

			warn(
				"[PurchaseService]",
				"No handler registered.",
				"| ProductId:",
				productId,
				"| Player:",
				player.Name,
				"| PurchaseId:",
				purchaseId
			)


			--------------------------------------------------
			-- NEVER consume an unknown product.
			--------------------------------------------------

			return Enum.ProductPurchaseDecision.NotProcessedYet

		end


		--------------------------------------------------
		-- EXECUTE PRODUCT HANDLER
		--------------------------------------------------

		local success,
			granted =
			pcall(
				function()

					return handler(
						player,
						receiptInfo
					)

				end
			)


		--------------------------------------------------
		-- HANDLER ERROR
		--------------------------------------------------

		if not success then

			warn(
				"[PurchaseService]",
				"Product handler crashed.",
				"| Error:",
				granted,
				"| ProductId:",
				productId,
				"| Player:",
				player.Name,
				"| PurchaseId:",
				purchaseId
			)


			--------------------------------------------------
			-- Keep the receipt pending.
			--------------------------------------------------

			return Enum.ProductPurchaseDecision.NotProcessedYet

		end


		--------------------------------------------------
		-- HANDLER DID NOT GRANT
		--------------------------------------------------

		if granted ~= true then

			warn(
				"[PurchaseService]",
				"Product handler did not grant purchase.",
				"| ProductId:",
				productId,
				"| Player:",
				player.Name,
				"| PurchaseId:",
				purchaseId
			)


			--------------------------------------------------
			-- Handler MUST explicitly return true.
			--------------------------------------------------

			return Enum.ProductPurchaseDecision.NotProcessedYet

		end


		--------------------------------------------------
		-- PURCHASE SUCCESSFULLY GRANTED
		--------------------------------------------------

		debugPrint(
			"Purchase granted.",
			"| ProductId:",
			productId,
			"| Player:",
			player.Name,
			"| PurchaseId:",
			purchaseId
		)


		--------------------------------------------------
		-- CONSUME RECEIPT
		--------------------------------------------------

		-- Leaderboard bookkeeping (never affects the purchase itself).
		if receiptInfo.CurrencyType == Enum.CurrencyType.Robux then

			pcall(
				function()
					require(
						ServerScriptService:WaitForChild(
							"RobuxLedger"
						)
					).Add(
						receiptInfo.PlayerId,
						receiptInfo.CurrencySpent
					)
				end
			)

		end

		return Enum.ProductPurchaseDecision.PurchaseGranted

	end


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print(
	"================================"
)

print(
	"[PurchaseService]",
	"SERVER READY"
)

print(
	"[PurchaseService]",
	"Central receipt processing:",
	"ENABLED"
)

print(
	"[PurchaseService]",
	"ProcessReceipt owner:",
	"PurchaseService"
)

print(
	"[PurchaseService]",
	"PurchaseServiceModule:",
	"CONNECTED"
)

print(
	"[PurchaseService]",
	"Unknown products:",
	"NOT GRANTED"
)

print(
	"[PurchaseService]",
	"Handler errors:",
	"NOT GRANTED"
)

print(
	"[PurchaseService]",
	"Client reward amounts:",
	"NOT TRUSTED"
)

print(
	"[PurchaseService]",
	"Server-side receipt validation:",
	"ENABLED"
)

print(
	"================================"
)