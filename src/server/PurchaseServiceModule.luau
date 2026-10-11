--------------------------------------------------
-- PURCHASE SERVICE MODULE
--
-- SERVER ONLY
--
-- LOCATION:
-- ServerScriptService
--     > PurchaseServiceModule
--
-- PURPOSE:
--
-- Central server-side Developer Product registry.
--
-- This module stores exactly ONE authoritative
-- handler for each Developer Product.
--
-- RECEIPT PROCESSING:
--
-- PurchaseService owns:
--
--     MarketplaceService.ProcessReceipt
--
-- PurchaseService:
-- - Validates the receipt
-- - Finds the player
-- - Finds the registered handler
-- - Executes the handler
-- - Grants the receipt only when the handler
--   explicitly returns true
--
-- THIS MODULE:
--
-- - Registers Developer Products
-- - Prevents duplicate registrations
-- - Returns registered handlers
-- - Provides registration/debug information
--
-- THIS MODULE DOES NOT:
--
-- - Assign ProcessReceipt
-- - Process receipts
-- - Prompt purchases
-- - Grant Wins
-- - Grant Oil
-- - Grant balls
-- - Grant XP
-- - Grant Rebirths
-- - Modify PlayerData directly
-- - Trust client-supplied reward amounts
--
-- PRODUCT HANDLERS:
--
-- Individual server systems register their products.
--
-- Examples:
--
--     Ball purchase
--     Oil purchase
--     Boost purchase
--     Other Developer Products
--
-- Each handler receives:
--
--     player
--     receiptInfo
--
-- The handler must return:
--
--     true
--
-- ONLY when the purchase has been safely granted.
--
-- IMPORTANT:
--
-- receiptInfo.PurchaseId must be treated as the
-- authoritative purchase identifier.
--
-- Product handlers should make their grants
-- idempotent so a retried receipt cannot grant
-- the same purchase twice.
--------------------------------------------------


--------------------------------------------------
-- PRODUCT HANDLERS
--
-- [DeveloperProductId] = handler
--
-- Each Developer Product may have exactly ONE
-- authoritative handler.
--------------------------------------------------

local productHandlers = {}


--------------------------------------------------
-- MODULE
--------------------------------------------------

local PurchaseServiceModule = {}


--------------------------------------------------
-- VALIDATE PRODUCT ID
--------------------------------------------------

local function isValidProductId(
	productId
)

	if typeof(productId) ~= "number" then

		return false

	end


	--------------------------------------------------
	-- NaN
	--------------------------------------------------

	if productId ~= productId then

		return false

	end


	--------------------------------------------------
	-- Infinity
	--------------------------------------------------

	if productId == math.huge
		or productId == -math.huge then

		return false

	end


	--------------------------------------------------
	-- Developer Product IDs must be positive.
	--------------------------------------------------

	if productId <= 0 then

		return false

	end


	--------------------------------------------------
	-- Developer Product IDs must be integers.
	--------------------------------------------------

	if productId % 1 ~= 0 then

		return false

	end


	return true

end


--------------------------------------------------
-- REGISTER PRODUCT
--
-- Called by SERVER systems during startup.
--
-- Example:
--
-- PurchaseServiceModule.RegisterProduct(
--     123456789,
--     function(
--         player,
--         receiptInfo
--     )
--
--         -- Server-side grant logic.
--
--         return true
--
--     end
-- )
--
-- IMPORTANT:
--
-- The handler is NOT executed here.
--
-- This only registers the handler.
--------------------------------------------------

function PurchaseServiceModule.RegisterProduct(
	productId,
	handler
)

	--------------------------------------------------
	-- VALIDATE PRODUCT ID
	--------------------------------------------------

	if not isValidProductId(
		productId
	) then

		error(
			"[PurchaseServiceModule] Invalid Developer Product ID: "
				.. tostring(productId)
		)

	end


	--------------------------------------------------
	-- VALIDATE HANDLER
	--------------------------------------------------

	if typeof(handler) ~= "function" then

		error(
			"[PurchaseServiceModule] Handler must be a function for ProductId: "
				.. tostring(productId)
		)

	end


	--------------------------------------------------
	-- PREVENT DUPLICATE REGISTRATION
	--
	-- There must be exactly ONE handler for each
	-- Developer Product.
	--------------------------------------------------

	if productHandlers[
		productId
	] ~= nil then

		error(
			"[PurchaseServiceModule] Developer Product already registered: "
				.. tostring(productId)
		)

	end


	--------------------------------------------------
	-- REGISTER
	--------------------------------------------------

	productHandlers[
		productId
	] =
		handler


	print(
		"[PurchaseServiceModule]",
		"Registered Product:",
		productId
	)

end


--------------------------------------------------
-- GET PRODUCT HANDLER
--
-- Returns the SERVER-SIDE handler.
--
-- This does NOT execute the handler.
--------------------------------------------------

function PurchaseServiceModule.GetHandler(
	productId
)

	--------------------------------------------------
	-- Validate ProductId before lookup.
	--------------------------------------------------

	if not isValidProductId(
		productId
	) then

		return nil

	end


	return productHandlers[
		productId
	]

end


--------------------------------------------------
-- IS PRODUCT REGISTERED
--
-- Returns true when a valid handler exists.
--------------------------------------------------

function PurchaseServiceModule.IsRegistered(
	productId
)

	if not isValidProductId(
		productId
	) then

		return false

	end


	return productHandlers[
		productId
	] ~= nil

end


--------------------------------------------------
-- GET REGISTERED PRODUCT COUNT
--
-- SERVER/DEBUG UTILITY
--------------------------------------------------

function PurchaseServiceModule.GetRegisteredProductCount()

	local count =
		0


	for _ in pairs(
		productHandlers
	) do

		count += 1

	end


	return count

end


--------------------------------------------------
-- GET REGISTERED PRODUCT IDS
--
-- SERVER/DEBUG UTILITY
--
-- Returns a new table so callers cannot modify
-- the internal registry.
--------------------------------------------------

function PurchaseServiceModule.GetRegisteredProductIds()

	local productIds =
		{}


	for productId in pairs(
		productHandlers
	) do

		table.insert(
			productIds,
			productId
		)

	end


	table.sort(
		productIds
	)


	return productIds

end


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print(
	"================================"
)

print(
	"[PurchaseServiceModule]",
	"SERVER READY"
)

print(
	"[PurchaseServiceModule]",
	"Developer Product registry:",
	"ENABLED"
)

print(
	"[PurchaseServiceModule]",
	"Duplicate registrations:",
	"REJECTED"
)

print(
	"[PurchaseServiceModule]",
	"Client product handlers:",
	"NOT ALLOWED"
)

print(
	"[PurchaseServiceModule]",
	"ProcessReceipt ownership:",
	"PurchaseService"
)

print(
	"[PurchaseServiceModule]",
	"Registered products:",
	PurchaseServiceModule.GetRegisteredProductCount()
)

print(
	"================================"
)


--------------------------------------------------
-- RETURN MODULE
--------------------------------------------------

return PurchaseServiceModule
