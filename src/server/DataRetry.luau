--------------------------------------------------
-- DATA RETRY (server, shared module)
--
-- A DataStore read can fail for a moment (InternalServerError, throttling, a
-- bad connection). The old code tried once and gave up for the whole session,
-- so settings / skins / world memory silently stayed at defaults.
--
--   local ok, value = DataRetry.Get(store, key)
--
-- Retries a few times with a growing, slightly random wait, and returns the
-- same (ok, value) pair as pcall. ok = false only after every try failed, and
-- the callers then still refuse to save over the stored data (their "loaded"
-- guards stay exactly as they were).
--------------------------------------------------

local DataRetry = {}

local DEFAULT_TRIES = 5
local rng = Random.new()

function DataRetry.Get(store, key, tries)
	tries = tries or DEFAULT_TRIES
	local ok, value
	for attempt = 1, tries do
		ok, value = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return true, value
		end
		if attempt < tries then
			task.wait(math.min(2 ^ (attempt - 1), 8) + rng:NextNumber(0, 0.5))
		end
	end
	return false, value
end

return DataRetry
