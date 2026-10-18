--------------------------------------------------
-- RECEIPT LEDGER (SERVER ONLY MODULE)
--
-- Durable, idempotent Developer Product receipts, in the same
-- DataStore the ball purchases use ("ProcessedReceipts_v1"):
--
--   1. IsRecorded(): was this PurchaseId already granted AND saved?
--   2. grant the item (caller)
--   3. save the player's data (caller)
--   4. Record(): remember the PurchaseId, then consume the receipt
--
-- Any failure makes the caller return false, so Roblox retries the
-- receipt later. Pending() remembers purchases granted in memory but not
-- yet recorded, so a retry never grants twice.
--------------------------------------------------

local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("ProcessedReceipts_v1")

local MAX_RECORDED = 100

local ReceiptLedger = {}

local pending = {} -- [purchaseId] = true

function ReceiptLedger.IsPending(purchaseId)
	return pending[purchaseId] == true
end

function ReceiptLedger.MarkPending(purchaseId)
	pending[purchaseId] = true
end

function ReceiptLedger.ClearPending(purchaseId)
	pending[purchaseId] = nil
end

-- true / false = recorded or not; nil = DataStore failure (retry later).
function ReceiptLedger.IsRecorded(player, purchaseId)
	local ok, list = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)

	if not ok then
		warn("[ReceiptLedger] Lookup failed:", player.Name, list)
		return nil
	end

	if typeof(list) == "table" then
		for _, id in ipairs(list) do
			if id == purchaseId then
				return true
			end
		end
	end

	return false
end

function ReceiptLedger.Record(player, purchaseId)
	local ok, err = pcall(function()
		store:UpdateAsync(tostring(player.UserId), function(list)
			list = typeof(list) == "table" and list or {}

			for _, id in ipairs(list) do
				if id == purchaseId then
					return nil
				end
			end

			table.insert(list, purchaseId)
			while #list > MAX_RECORDED do
				table.remove(list, 1)
			end

			return list
		end)
	end)

	if not ok then
		warn("[ReceiptLedger] Record failed:", player.Name, err)
	end

	return ok
end

--------------------------------------------------
-- CONSUME (the durable purchase pattern, shared by every product)
--
--   1. already recorded?          -> done (return true)
--   2. grant (once; remembered while pending)
--   3. SAVE the player's data
--   4. RECORD the purchase id
--   5. only then confirm to the client
--
-- Returns true only when the receipt can be marked PurchaseGranted.
-- `grantFunction()` must return true when the grant happened.
-- `onConfirmed(player)` is optional and runs after step 4.
--------------------------------------------------

function ReceiptLedger.Consume(player, receiptInfo, grantFunction, onConfirmed)
	local ServerScriptService = game:GetService("ServerScriptService")
	local PlayerDataService = require(
		ServerScriptService:WaitForChild("PlayerDataLoader"):WaitForChild("PlayerDataService")
	)

	local purchaseId = receiptInfo.PurchaseId

	local recorded = ReceiptLedger.IsRecorded(player, purchaseId)
	if recorded == nil then
		return false -- DataStore down: Roblox retries later
	end
	if recorded then
		return true
	end

	if not ReceiptLedger.IsPending(purchaseId) then
		if not grantFunction() then
			return false
		end
		ReceiptLedger.MarkPending(purchaseId)
	end

	if PlayerDataService.SavePlayer(player) ~= true then
		warn("[ReceiptLedger] Save failed; receipt stays pending:", player.Name, purchaseId)
		return false
	end

	if not ReceiptLedger.Record(player, purchaseId) then
		return false
	end

	ReceiptLedger.ClearPending(purchaseId)

	if onConfirmed then
		task.spawn(onConfirmed, player)
	end

	return true
end

return ReceiptLedger
