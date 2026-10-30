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

local pending = {} -- [purchaseId] = player whose data holds the grant

function ReceiptLedger.IsPending(purchaseId)
	return pending[purchaseId] ~= nil
end

function ReceiptLedger.MarkPending(purchaseId, player)
	pending[purchaseId] = player or true
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

-- LEAVE: a purchase granted in memory whose save or record failed is still pending.
-- If the player's leave-save then SUCCEEDS, the grant is stored, so its PurchaseId
-- must be recorded now; otherwise the next server would see an unrecorded receipt and
-- grant it a second time. Called by PlayerDataLoader only after a confirmed save.
-- (A failed leave-save records nothing: the grant was lost, so a retry is correct.)
function ReceiptLedger.FlushPending(player)
	local ids = {}
	for purchaseId, owner in pairs(pending) do
		if owner == player then
			table.insert(ids, purchaseId)
		end
	end
	for _, purchaseId in ipairs(ids) do
		if ReceiptLedger.Record(player, purchaseId) then
			pending[purchaseId] = nil
			print("[AUDIT] pending purchase recorded on leave:", player.Name, player.UserId, "purchase", purchaseId)
		end
	end
	return #ids
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
			warn("[AUDIT] purchase grant FAILED (receipt stays pending):", player.Name, player.UserId, "product", receiptInfo.ProductId, "purchase", purchaseId)
			return false
		end
		ReceiptLedger.MarkPending(purchaseId, player)
	end

	if PlayerDataService.SavePlayer(player) ~= true then
		warn("[ReceiptLedger] Save failed; receipt stays pending:", player.Name, purchaseId)
		return false
	end

	if not ReceiptLedger.Record(player, purchaseId) then
		return false
	end

	ReceiptLedger.ClearPending(purchaseId)
	print("[AUDIT] purchase granted+recorded:", player.Name, player.UserId, "product", receiptInfo.ProductId, "purchase", purchaseId)

	if onConfirmed then
		task.spawn(onConfirmed, player)
	end

	return true
end

return ReceiptLedger
