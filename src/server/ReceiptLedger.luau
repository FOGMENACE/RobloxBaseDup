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

return ReceiptLedger
