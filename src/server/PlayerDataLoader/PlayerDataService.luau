--------------------------------------------------
-- PLAYER DATA SERVICE
-- SERVER ONLY
-- LOCATION:
-- ServerScriptService
--   > PlayerDataLoader
--     > PlayerDataService
--------------------------------------------------

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataService = {}

local BallDefinitions = require(
    ServerScriptService:WaitForChild("BallDefinitions")
)

--------------------------------------------------
-- SETTINGS
--------------------------------------------------

local DATASTORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 60
local SAVE_TIMEOUT = 20

local MAX_XP = 1e15
local MAX_LEVEL = 1000000
local MAX_WINS = 1e15
local MAX_REBIRTHS = 1000000
local MAX_OIL = 1e9
local MAX_BALL_NAME_LENGTH = 64

-- LEVEL CURVE (retuned): total XP to reach level L = XP_CURVE_A * (L^XP_CURVE_Q - 1).
-- The old geometric curve (x1.35 per level) became impossible after ~3 rebirths
-- (reach level 45 needed ~10^8 times what a player earns). This polynomial curve
-- is fitted to the XP income (rebirth XP x(1+10r), generators, ball speed) so a
-- rebirth takes roughly 1 min early, 2-5 min mid game and 5-8 min deep in.
local XP_CURVE_A = 76 -- 20% less XP per rebirth than before: a steady challenge, not a grind
local XP_CURVE_Q = 2.46
-- levels are 3x finer than the curve below was fitted for (RebirthBonuses.LEVEL_SCALE):
-- level L uses the old curve at (L - 1) / 3 + 1, so total XP to each rebirth is unchanged
local LEVEL_SCALE = 5
local BASE_REBIRTH_LEVEL = 6 -- first (tutorial) requirement; see RebirthBonuses.RequiredLevel
local REBIRTH_LEVEL_INCREMENT = 15

local DEFAULT_BALL_ID = "StraightBall"

local playerDataStore = DataStoreService:GetDataStore(
    DATASTORE_NAME
)

--------------------------------------------------
-- DEFAULT DATA
--------------------------------------------------

local DEFAULT_DATA = {
    XP = 0,
    Level = 1,
    GlobalLevel = 1,
    Wins = 0,
    Rebirths = 0,
    RebirthLevelRequirement = BASE_REBIRTH_LEVEL,
    CurrentOil = 0,

    OwnedBalls = {
        [DEFAULT_BALL_ID] = true,
    },

    EquippedBall = DEFAULT_BALL_ID,
}

--------------------------------------------------
-- SERVER MEMORY
--------------------------------------------------

local loadedData = {}
local saving = {}
local saveRequested = {}
local shuttingDown = false

--------------------------------------------------
-- NUMBER VALIDATION
--------------------------------------------------

local function isFiniteNumber(value)
    return typeof(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function sanitizeNumber(value, defaultValue, maximum)
    if not isFiniteNumber(value) or value < 0 then
        return defaultValue
    end

    return math.min(value, maximum)
end

--------------------------------------------------
-- REBIRTH REQUIREMENT
--------------------------------------------------

local RebirthBonuses = require(
    game:GetService("ReplicatedStorage"):WaitForChild("RebirthBonuses")
)

local function getRequiredRebirthLevel(rebirths)
    rebirths = math.clamp(
        math.floor(tonumber(rebirths) or 0),
        0,
        MAX_REBIRTHS
    )

    return math.min(
        MAX_LEVEL,
        math.floor(RebirthBonuses.RequiredLevel(rebirths))
    )
end

--------------------------------------------------
-- XP CALCULATIONS
--------------------------------------------------

local function getTotalXPForLevel(level)
    level = math.max(
        1,
        math.floor(tonumber(level) or 1)
    )

    if level <= 1 then
        return 0
    end

    return XP_CURVE_A * (((level - 1) / LEVEL_SCALE + 1) ^ XP_CURVE_Q - 1)
end

local function getXPRequiredForLevel(level)
    level = math.clamp(
        math.floor(tonumber(level) or 1),
        1,
        MAX_LEVEL
    )

    return getTotalXPForLevel(level + 1) - getTotalXPForLevel(level)
end
local function calculateLevelFromXP(xp, maxLevel)
    if not isFiniteNumber(xp) or xp <= 0 then
        return 1
    end

    xp = math.clamp(xp, 0, MAX_XP)

    maxLevel = math.clamp(
        math.floor(tonumber(maxLevel) or BASE_REBIRTH_LEVEL),
        1,
        MAX_LEVEL
    )

    local level = math.floor(1 + LEVEL_SCALE * ((xp / XP_CURVE_A + 1) ^ (1 / XP_CURVE_Q) - 1))

    level = math.clamp(level, 1, maxLevel)

    while level > 1 and xp < getTotalXPForLevel(level) do
        level -= 1
    end

    while level < maxLevel
        and xp >= getTotalXPForLevel(level + 1) do
        level += 1
    end

    return level
end

local function getXPProgress(xp, maxLevel)
    xp = sanitizeNumber(xp, 0, MAX_XP)

    maxLevel = math.clamp(
        math.floor(tonumber(maxLevel) or BASE_REBIRTH_LEVEL),
        1,
        MAX_LEVEL
    )

    local level = calculateLevelFromXP(xp, maxLevel)
    local currentLevelXP = getTotalXPForLevel(level)
    local nextLevelXP = getTotalXPForLevel(level + 1)

    local xpIntoLevel = math.max(0, xp - currentLevelXP)
    local xpNeededForLevel = math.max(
        0,
        nextLevelXP - currentLevelXP
    )

    local maxReached = level >= maxLevel
    local progress = 0

    if maxReached then
        xpIntoLevel = xpNeededForLevel
        progress = 1
    elseif xpNeededForLevel > 0 then
        progress = xpIntoLevel / xpNeededForLevel
    end

    return {
        Level = level,
        CurrentLevelXP = currentLevelXP,
        NextLevelXP = nextLevelXP,
        XPIntoLevel = xpIntoLevel,
        XPNeededForLevel = xpNeededForLevel,
        Progress = math.clamp(progress, 0, 1),
        MaxLevel = maxLevel,
        MaxReached = maxReached,
    }
end

--------------------------------------------------
-- BALL VALIDATION
--------------------------------------------------

local function isValidBallId(ballId)
    if typeof(ballId) ~= "string"
        or ballId == ""
        or #ballId > MAX_BALL_NAME_LENGTH then
        return false
    end

    return typeof(BallDefinitions[ballId]) == "table"
end

local function getBallDefinition(ballId)
    if not isValidBallId(ballId) then
        return nil
    end

    return BallDefinitions[ballId]
end

local function validateBallDefinition(ballId, definition)
    if not isValidBallId(ballId)
        or typeof(definition) ~= "table" then
        return false, "INVALID_DEFINITION"
    end

    for _, field in ipairs({
        "ForwardSpeed",
        "HorizontalSpeed",
    }) do
        if not isFiniteNumber(definition[field])
            or definition[field] < 0 then
            return false, "INVALID_" .. string.upper(field)
        end
    end

    for _, field in ipairs({
        "WinsCost",
        "RequiredRebirths",
        "DeveloperProductId",
        "DisplayOrder",
    }) do
        local value = definition[field]

        if value ~= nil and not isFiniteNumber(value) then
            return false, "INVALID_" .. string.upper(field)
        end

        if value ~= nil and field ~= "DisplayOrder" and value < 0 then
            return false, "NEGATIVE_" .. string.upper(field)
        end
    end

    if definition.DeveloperProductId ~= nil
        and definition.DeveloperProductId % 1 ~= 0 then
        return false, "NON_INTEGER_DEVELOPER_PRODUCT_ID"
    end

    return true, "VALID"
end

do
    local definition = getBallDefinition(DEFAULT_BALL_ID)

    if not definition then
        error(
            "[PlayerDataService] Missing default ball: "
                .. DEFAULT_BALL_ID
        )
    end

    local valid, reason = validateBallDefinition(
        DEFAULT_BALL_ID,
        definition
    )

    if not valid then
        error(
            "[PlayerDataService] Invalid default ball: "
                .. reason
        )
    end

    if definition.DeveloperProductId ~= nil
        and definition.DeveloperProductId ~= 0 then
        error(
            "[PlayerDataService] StraightBall cannot have a DeveloperProductId."
        )
    end
end

--------------------------------------------------
-- COPY AND SANITIZE OWNED BALLS
--------------------------------------------------

local function copyOwnedBalls(value)
    local result = {}

    if typeof(value) == "table" then
        for ballId, owned in pairs(value) do
            if owned == true and isValidBallId(ballId) then
                result[ballId] = true
            end
        end
    end

    result[DEFAULT_BALL_ID] = true
    return result
end

local function copyData(data)
    local result = {}

    for key, value in pairs(data) do
        if key == "OwnedBalls" then
            result.OwnedBalls = copyOwnedBalls(value)
        else
            result[key] = value
        end
    end

    return result
end

--------------------------------------------------
-- SANITIZE SAVED DATA
--------------------------------------------------

local function sanitizeData(data)
    if typeof(data) ~= "table" then
        data = {}
    end

    local rebirths = math.floor(sanitizeNumber(
        data.Rebirths,
        DEFAULT_DATA.Rebirths,
        MAX_REBIRTHS
    ))

    -- Use the rebirth count to determine the authoritative
    -- requirement. This repairs inconsistent older saves.
    local requirement = getRequiredRebirthLevel(rebirths)

    local xp = sanitizeNumber(
        data.XP,
        DEFAULT_DATA.XP,
        MAX_XP
    )

    local oldLevel = math.floor(sanitizeNumber(
        data.Level,
        DEFAULT_DATA.Level,
        MAX_LEVEL
    ))

    local globalLevel = math.floor(sanitizeNumber(
        data.GlobalLevel,
        oldLevel,
        MAX_LEVEL
    ))

    globalLevel = math.clamp(
        math.max(1, globalLevel, oldLevel),
        1,
        MAX_LEVEL
    )

    local result = {
        XP = xp,
        Level = 1,
        GlobalLevel = globalLevel,

        Wins = math.floor(sanitizeNumber(
            data.Wins,
            DEFAULT_DATA.Wins,
            MAX_WINS
        )),

        Rebirths = rebirths,
        RebirthLevelRequirement = requirement,

        CurrentOil = sanitizeNumber(
            data.CurrentOil,
            DEFAULT_DATA.CurrentOil,
            MAX_OIL
        ),

        OwnedBalls = copyOwnedBalls(data.OwnedBalls),
        EquippedBall = DEFAULT_BALL_ID,
    }

    result.Level = calculateLevelFromXP(
        result.XP,
        result.RebirthLevelRequirement
    )

    local equipped = data.EquippedBall

    if typeof(equipped) == "string"
        and isValidBallId(equipped)
        and result.OwnedBalls[equipped] == true then

        local definition = getBallDefinition(equipped)
        local valid = validateBallDefinition(equipped, definition)

        if valid then
            result.EquippedBall = equipped
        end
    end

    return result
end

--------------------------------------------------
-- PLAYER DATA KEY
--------------------------------------------------

local function getDataKey(player)
    return "Player_" .. tostring(player.UserId)
end

--------------------------------------------------
-- UPDATE ATTRIBUTES AND LEADERSTATS
--------------------------------------------------

local function updatePlayerValues(player, data)
    data.Level = calculateLevelFromXP(
        data.XP,
        data.RebirthLevelRequirement
    )

    local progress = getXPProgress(
        data.XP,
        data.RebirthLevelRequirement
    )

    -- Attributes consumed by ProgressionUI and RebirthUIClient.
    player:SetAttribute("XP", data.XP)
    player:SetAttribute("Level", data.Level)
    player:SetAttribute("GlobalLevel", data.GlobalLevel)
    player:SetAttribute("Wins", data.Wins)
    player:SetAttribute("Rebirths", data.Rebirths)
    player:SetAttribute("RebirthLevelRequirement",
        data.RebirthLevelRequirement)
    player:SetAttribute("RebirthMaxReached", progress.MaxReached)
    -- the lifetime oil total has its OWN attribute: "CurrentOil" is the oil collected on the current run
    -- (OilCollectionService / RunController), and sharing it let any XP or wins update overwrite a run in progress
    -- with the whole total (e.g. 160k appearing on the first platform of a run)
    player:SetAttribute("OilTotal", data.CurrentOil)
    player:SetAttribute("EquippedBall", data.EquippedBall)

    player:SetAttribute("XPForCurrentLevel",
        progress.CurrentLevelXP)
    player:SetAttribute("XPForNextLevel",
        progress.NextLevelXP)
    player:SetAttribute("XPIntoLevel",
        progress.XPIntoLevel)
    player:SetAttribute("XPNeededForLevel",
        progress.XPNeededForLevel)
    player:SetAttribute("LevelProgress",
        progress.Progress)

    local leaderstats = player:FindFirstChild("leaderstats")

    if not leaderstats then
        return
    end

    for name, value in pairs({
        Wins = data.Wins,
        Rebirths = data.Rebirths,
    }) do
        local stat = leaderstats:FindFirstChild(name)

        if stat and stat:IsA("IntValue") then
            stat.Value = math.floor(value)
        end
    end
end

--------------------------------------------------
-- CREATE LEADERSTATS
--------------------------------------------------

local function createLeaderstats(player, data)
    local leaderstats = player:FindFirstChild("leaderstats")

    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

    for _, name in ipairs({
        "Rebirths",
        "Wins",
    }) do
        local stat = leaderstats:FindFirstChild(name)

        if not stat then
            stat = Instance.new("IntValue")
            stat.Name = name
            stat.Parent = leaderstats
        end
    end

    updatePlayerValues(player, data)
end

--------------------------------------------------
-- LOAD DATA
--------------------------------------------------

-- SESSION LOCK + LOAD RETRY
--
-- A record carries a `SessionLock = { JobId, Time }` field (kept OUT of the
-- in-memory data). Loading claims the lock with UpdateAsync; if another
-- server holds a FRESH lock the load waits and retries, then gives up (the
-- loader kicks the player) instead of loading a second live copy. Saving
-- refuses to overwrite a record whose lock belongs to another live server.
-- A lock older than LOCK_TIMEOUT (crashed server) is taken over. Every save
-- refreshes the lock. Failed DataStore calls are retried with exponential
-- backoff; if the load still fails no data is loaded, and the loader never
-- saves a player whose load did not succeed.
local LOCK_TIMEOUT = 150 -- seconds; autosave (60 s) refreshes it
local LOAD_ATTEMPTS = 5
local LOAD_BACKOFF = 1 -- 1, 2, 4, 8 s between attempts
local LOCK_WAIT_ATTEMPTS = 8 -- x 3 s while another server still holds it
local RELEASE_GRACE = 2 -- seconds before the lock is dropped on leave

local lockLost = {} -- [player] = true: another server took the record

local function lockIsLive(lock)
    return typeof(lock) == "table"
        and lock.JobId ~= game.JobId
        and typeof(lock.Time) == "number"
        and os.time() - lock.Time < LOCK_TIMEOUT
end

local function loadData(player)
    if shuttingDown then
        return nil
    end

    if loadedData[player] then
        return loadedData[player]
    end

    local key = getDataKey(player)
    local result = nil
    local lockedElsewhere = 0
    local failures = 0

    while player.Parent do
        local blocked = false

        local success, value = pcall(function()
            return playerDataStore:UpdateAsync(key, function(old)
                if old ~= nil and typeof(old) ~= "table" then
                    return nil -- unreadable record: never touch it
                end

                if old and lockIsLive(old.SessionLock) then
                    blocked = true
                    return nil
                end

                local record = old or {}
                record.SessionLock = { JobId = game.JobId, Time = os.time() }
                return record
            end)
        end)

        if success and not blocked then
            result = value
            break
        end

        if blocked then
            lockedElsewhere += 1
            warn("[PlayerDataService] AUDIT load blocked by another server:", player.Name, player.UserId, lockedElsewhere)
            if lockedElsewhere >= LOCK_WAIT_ATTEMPTS then
                warn("[PlayerDataService] AUDIT load gave up (session still active elsewhere):", player.Name)
                return nil
            end
            task.wait(3)
        else
            failures += 1
            warn("[PlayerDataService] AUDIT load failed (attempt", failures, "):", player.Name, value)
            if failures >= LOAD_ATTEMPTS then
                return nil
            end
            task.wait(LOAD_BACKOFF * 2 ^ (failures - 1))
        end
    end

    if not player.Parent then
        return nil
    end

    local data = sanitizeData(result)
    loadedData[player] = data
    lockLost[player] = nil

    return data
end
function PlayerDataService.LoadPlayer(player)
    if not player or not player:IsA("Player") or shuttingDown then
        return false
    end

    if loadedData[player] then
        return true
    end

    local data = loadData(player)

    if not data then
        return false
    end

    createLeaderstats(player, data)
    updatePlayerValues(player, data)

    print(
        "[PlayerDataService] Loaded:",
        player.Name,
        "| Level:", data.Level,
        "| GlobalLevel:", data.GlobalLevel,
        "| Rebirths:", data.Rebirths,
        "| Requirement:", data.RebirthLevelRequirement
    )

    return true
end

--------------------------------------------------
-- READ DATA
--------------------------------------------------

function PlayerDataService.GetData(player)
    local data = loadedData[player]
    return data and copyData(data) or nil
end

function PlayerDataService.GetXP(player)
    local data = loadedData[player]
    return data and data.XP or 0
end

function PlayerDataService.GetWins(player)
    local data = loadedData[player]
    return data and data.Wins or 0
end

function PlayerDataService.GetRebirths(player)
    local data = loadedData[player]
    return data and data.Rebirths or 0
end

function PlayerDataService.GetOil(player)
    local data = loadedData[player]
    return data and math.max(0, data.CurrentOil) or 0
end

function PlayerDataService.GetXPRequiredForLevel(level)
    return getXPRequiredForLevel(level)
end

function PlayerDataService.GetTotalXPForLevel(level)
    return getTotalXPForLevel(level)
end

function PlayerDataService.GetXPProgress(player)
    local data = loadedData[player]

    if not data then
        return nil
    end

    return getXPProgress(
        data.XP,
        data.RebirthLevelRequirement
    )
end

--------------------------------------------------
-- ADD XP
--------------------------------------------------

function PlayerDataService.AddXP(player, amount)
    if not player or not player:IsA("Player")
        or not isFiniteNumber(amount) or amount <= 0 then
        return false
    end

    local data = loadedData[player]

    if not data then
        return false
    end

    amount = math.floor(amount)

    if amount <= 0 then
        return false
    end

    local oldLevel = calculateLevelFromXP(
        data.XP,
        data.RebirthLevelRequirement
    )

    local xpCap = math.min(
        MAX_XP,
        getTotalXPForLevel(data.RebirthLevelRequirement + 1) - 1
    )

    if data.XP >= xpCap then
        data.XP = xpCap
        updatePlayerValues(player, data)
        -- nothing was added (a rebirth is required), but the caller can still show
        -- the XP flying to the full bar: second value "CAPPED"
        return false, "CAPPED"
    end

    data.XP = math.min(data.XP + amount, xpCap)

    local newLevel = calculateLevelFromXP(
        data.XP,
        data.RebirthLevelRequirement
    )

    -- Lifetime level increases when the current run gains levels.
    local levelsGained = math.max(0, newLevel - oldLevel)

    data.GlobalLevel = math.min(
        MAX_LEVEL,
        data.GlobalLevel + levelsGained
    )

    updatePlayerValues(player, data)
    return true
end

--------------------------------------------------
-- WINS
--------------------------------------------------

function PlayerDataService.AddWins(player, amount)
    if not player or not player:IsA("Player")
        or not isFiniteNumber(amount) or amount <= 0 then
        return false
    end

    local data = loadedData[player]
    amount = math.floor(amount)

    if not data or amount <= 0 then
        return false
    end

    data.Wins = math.min(data.Wins + amount, MAX_WINS)
    updatePlayerValues(player, data)

    return true
end

function PlayerDataService.RemoveWins(player, amount)
    if not player or not player:IsA("Player")
        or not isFiniteNumber(amount) or amount <= 0 then
        return false
    end

    local data = loadedData[player]
    amount = math.floor(amount)

    if not data or amount <= 0 or data.Wins < amount then
        return false
    end

    data.Wins -= amount
    updatePlayerValues(player, data)

    return true
end

--------------------------------------------------
-- BALL API
--------------------------------------------------

function PlayerDataService.GetDefaultBallId()
    return DEFAULT_BALL_ID
end

function PlayerDataService.GetBallDefinition(ballId)
    local definition = getBallDefinition(ballId)

    if not definition then
        return nil
    end

    local result = {}

    for key, value in pairs(definition) do
        result[key] = value
    end

    return result
end

function PlayerDataService.IsValidBallId(ballId)
    return isValidBallId(ballId)
end

function PlayerDataService.GetOwnedBalls(player)
    local data = loadedData[player]
    return data and copyOwnedBalls(data.OwnedBalls) or {}
end

function PlayerDataService.OwnsBall(player, ballId)
    local data = loadedData[player]

    return data ~= nil
        and isValidBallId(ballId)
        and data.OwnedBalls[ballId] == true
end

function PlayerDataService.AddOwnedBall(player, ballId)
    if not player or not player:IsA("Player")
        or not isValidBallId(ballId) then
        return false
    end

    local data = loadedData[player]
    local definition = getBallDefinition(ballId)

    if not data or not validateBallDefinition(ballId, definition) then
        return false
    end

    data.OwnedBalls[ballId] = true
    updatePlayerValues(player, data)

    return true
end

function PlayerDataService.RemoveOwnedBall(player, ballId)
    if not player or not player:IsA("Player")
        or not isValidBallId(ballId)
        or ballId == DEFAULT_BALL_ID then
        return false
    end

    local data = loadedData[player]

    if not data or data.OwnedBalls[ballId] ~= true then
        return false
    end

    data.OwnedBalls[ballId] = nil

    if data.EquippedBall == ballId then
        data.EquippedBall = DEFAULT_BALL_ID
    end

    updatePlayerValues(player, data)
    return true
end

function PlayerDataService.GetEquippedBall(player)
    local data = loadedData[player]

    if not data then
        return DEFAULT_BALL_ID
    end

    if not isValidBallId(data.EquippedBall)
        or data.OwnedBalls[data.EquippedBall] ~= true then
        return DEFAULT_BALL_ID
    end

    return data.EquippedBall
end

function PlayerDataService.EquipBall(player, ballId)
    if not player or not player:IsA("Player")
        or not isValidBallId(ballId) then
        return false
    end

    local data = loadedData[player]
    local definition = getBallDefinition(ballId)

    if not data
        or not validateBallDefinition(ballId, definition)
        or data.OwnedBalls[ballId] ~= true then
        return false
    end

    data.EquippedBall = ballId
    updatePlayerValues(player, data)

    return true
end

--------------------------------------------------
-- OIL
--------------------------------------------------

function PlayerDataService.SetOil(player, amount)
    if not player or not player:IsA("Player")
        or not isFiniteNumber(amount) or amount < 0 then
        return false
    end

    local data = loadedData[player]

    if not data then
        return false
    end

    data.CurrentOil = math.clamp(amount, 0, MAX_OIL)
    updatePlayerValues(player, data)

    return true
end

function PlayerDataService.AddOil(player, amount)
    if not player or not player:IsA("Player")
        or not isFiniteNumber(amount) or amount <= 0 then
        return false
    end

    local data = loadedData[player]

    if not data then
        return false
    end

    data.CurrentOil = math.min(
        data.CurrentOil + amount,
        MAX_OIL
    )

    updatePlayerValues(player, data)
    return true
end

function PlayerDataService.RemoveOil(player, amount)
    if not player or not player:IsA("Player")
        or not isFiniteNumber(amount) or amount <= 0 then
        return false
    end

    local data = loadedData[player]

    if not data or data.CurrentOil < amount then
        return false
    end

    data.CurrentOil -= amount
    updatePlayerValues(player, data)

    return true
end

--------------------------------------------------
-- LEVEL AND REBIRTH SETTERS
--------------------------------------------------

function PlayerDataService.SetLevel(player, level)
    if not isFiniteNumber(level) then
        return false
    end

    local data = loadedData[player]
    level = math.floor(level)

    if not data or level < 1
        or level > data.RebirthLevelRequirement then
        return false
    end

    local actualLevel = calculateLevelFromXP(
        data.XP,
        data.RebirthLevelRequirement
    )

    -- XP remains authoritative; this cannot grant levels.
    if level > actualLevel then
        return false
    end

    data.Level = actualLevel
    updatePlayerValues(player, data)

    return true
end

function PlayerDataService.SetRebirths(player, rebirths)
    if not isFiniteNumber(rebirths) then
        return false
    end

    local data = loadedData[player]
    rebirths = math.floor(rebirths)

    if not data or rebirths ~= data.Rebirths then
        return false
    end

    -- Rebirths can only be changed by the rebirth function.
    return true
end
--------------------------------------------------
-- PERFORM REBIRTH
--------------------------------------------------

function PlayerDataService.RebirthPlayer(player)
    if not player or not player:IsA("Player") then
        return false, "INVALID_PLAYER"
    end

    local data = loadedData[player]

    if not data then
        return false, "DATA_NOT_LOADED"
    end

    if shuttingDown then
        return false, "SERVER_SHUTTING_DOWN"
    end

    if data.Rebirths >= MAX_REBIRTHS then
        return false, "MAX_REBIRTHS_REACHED"
    end

    local requiredLevel = getRequiredRebirthLevel(data.Rebirths)

    local currentLevel = calculateLevelFromXP(
        data.XP,
        requiredLevel
    )

    if currentLevel < requiredLevel then
        warn("[AUDIT] rebirth refused LEVEL_REQUIREMENT_NOT_MET:", player.Name, "level", currentLevel, "need", requiredLevel)
        return false, "LEVEL_REQUIREMENT_NOT_MET"
    end

    -- Advance rebirth count and calculate the next requirement.
    data.Rebirths += 1
    data.RebirthLevelRequirement = getRequiredRebirthLevel(
        data.Rebirths
    )

    -- Reset current-run progress; preserve lifetime progress.
    data.XP = 0
    data.Level = 1

    updatePlayerValues(player, data)

    print("[AUDIT] rebirth ok:", player.Name, player.UserId, "rebirths", data.Rebirths)
    print(
        "[PlayerDataService] REBIRTH COMPLETE:",
        player.Name,
        "| GlobalLevel:", data.GlobalLevel,
        "| Rebirths:", data.Rebirths,
        "| Next Requirement:", data.RebirthLevelRequirement
    )

    -- Return success only if the new state is saved.
    local saved = PlayerDataService.SavePlayer(player)

    if not saved then
        warn("[AUDIT] rebirth SAVE FAILED (in memory only):", player.Name, player.UserId)
        warn(
            "[PlayerDataService] Rebirth save failed:",
            player.Name
        )

        -- The rebirth already happened in memory.
        -- Do not tell the client it was rolled back.
    end

    return true, "REBIRTH_SUCCESS"
end

--------------------------------------------------
-- GRANT REBIRTH (reward use only)
--
-- Adds one rebirth WITHOUT the level requirement and WITHOUT
-- resetting XP / Level. Only for server-side rewards such as the
-- daily calendar; the normal path is still RebirthPlayer.
--------------------------------------------------

function PlayerDataService.GrantRebirth(player)
    local data = loadedData[player]

    if not data or shuttingDown or data.Rebirths >= MAX_REBIRTHS then
        return false
    end

    data.Rebirths += 1
    data.RebirthLevelRequirement = getRequiredRebirthLevel(data.Rebirths)
    updatePlayerValues(player, data)

    return true
end

--------------------------------------------------
-- FORCE REBIRTH (paid "Skip Rebirth" product only)
--
-- Same effect as a normal rebirth (XP and level reset, next requirement,
-- saved) but WITHOUT the level requirement. Only the purchase handler in
-- ProductService may call this.
--------------------------------------------------

function PlayerDataService.ForceRebirth(player)
    local data = loadedData[player]

    if not data or shuttingDown or data.Rebirths >= MAX_REBIRTHS then
        return false
    end

    data.Rebirths += 1
    data.RebirthLevelRequirement = getRequiredRebirthLevel(data.Rebirths)
    data.XP = 0
    data.Level = 1

    updatePlayerValues(player, data)
    return true
end

--------------------------------------------------
-- SAVE PLAYER
--------------------------------------------------

function PlayerDataService.SavePlayer(player)
    if not player or not player:IsA("Player") then
        return false
    end

    if not loadedData[player] then
        return false
    end

    if saving[player] then
        saveRequested[player] = true

        local deadline = os.clock() + SAVE_TIMEOUT

        while saving[player] and os.clock() < deadline do
            task.wait(0.1)
        end

        return not saving[player]
    end

    saving[player] = true

    local overallSuccess = true

    repeat
        saveRequested[player] = nil

        local currentData = loadedData[player]

        if not currentData then
            overallSuccess = false
            break
        end

        local sanitized = sanitizeData(currentData)

        loadedData[player] = sanitized
        updatePlayerValues(player, sanitized)

        local dataToSave = copyData(sanitized)
        local key = getDataKey(player)

        local lostThisSave = false
        local success, errorMessage = pcall(function()
            playerDataStore:UpdateAsync(key, function(old)
                if typeof(old) == "table" and lockIsLive(old.SessionLock) then
                    lostThisSave = true
                    return nil -- another server owns this record: do NOT overwrite
                end

                dataToSave.SessionLock = { JobId = game.JobId, Time = os.time() }
                return dataToSave
            end)
        end)

        if lostThisSave then
            lockLost[player] = true
            warn("[PlayerDataService] AUDIT save blocked: record owned by another server:", player.Name, player.UserId)
            overallSuccess = false
            task.defer(function()
                if player.Parent then
                    player:Kick("Your account was opened in another server. Please rejoin.")
                end
            end)
            break
        end

        if not success then
            warn(
                "[PlayerDataService] Failed to save:",
                player.Name,
                errorMessage
            )

            overallSuccess = false
            break
        end
    until not saveRequested[player]

    saving[player] = nil
    saveRequested[player] = nil

    return overallSuccess
end

--------------------------------------------------
-- RELEASE (leave / shutdown): drop our lock and free the memory
--------------------------------------------------

function PlayerDataService.ReleasePlayer(player)
    if player and loadedData[player] and not lockLost[player] then
        -- Let the other per-player services (quests, boosts, calendar ...)
        -- finish their own leave-saves before another server can claim this
        -- player (see SessionGate).
        task.wait(RELEASE_GRACE)

        pcall(function()
            playerDataStore:UpdateAsync(getDataKey(player), function(old)
                if typeof(old) == "table" and typeof(old.SessionLock) == "table"
                    and old.SessionLock.JobId == game.JobId then
                    old.SessionLock = nil
                    return old
                end
                return nil
            end)
        end)
    end

    loadedData[player] = nil
    lockLost[player] = nil
    saving[player] = nil
    saveRequested[player] = nil
end
--------------------------------------------------
-- SAVE STATE
--------------------------------------------------

function PlayerDataService.IsSaving(player)
    return saving[player] == true
end

--------------------------------------------------
-- SHUTDOWN
--------------------------------------------------
--------------------------------------------------
-- ADMIN API (called ONLY by server/AdminService)
--
-- Resets progression fields to valid defaults for ONE explicit UserId.
-- Receipt / idempotency records live in other DataStores
-- (ProcessedReceipts_v1) and are never touched here. Every reset first
-- stores a full backup copy in "PlayerDataBackup_v1".
--------------------------------------------------

local backupStore = DataStoreService:GetDataStore("PlayerDataBackup_v1")

local function freshDefaults()
    local fresh = copyData(DEFAULT_DATA)
    fresh.OwnedBalls = { [DEFAULT_BALL_ID] = true }

    -- Explicit, so a reset can never keep a higher Strike / Reach level:
    -- the rebirth requirement is derived from the rebirth count (0 rebirths
    -- = the base requirement), and the global level restarts too.
    fresh.Rebirths = 0
    fresh.RebirthLevelRequirement = getRequiredRebirthLevel(0)
    fresh.GlobalLevel = 1
    fresh.Level = 1
    fresh.XP = 0
    return fresh
end

local function backup(userId, previous)
    local key = tostring(userId) .. "_" .. tostring(os.time())
    local ok, err = pcall(function()
        backupStore:SetAsync(key, previous or { Empty = true })
    end)

    if not ok then
        warn("[PlayerDataService] Backup failed:", userId, err)
    end

    return ok and key or nil
end

-- Read a user's saved record (does not change anything).
function PlayerDataService.AdminRead(userId)
    local ok, value = pcall(function()
        return playerDataStore:GetAsync("Player_" .. tostring(userId))
    end)

    if not ok then
        return nil, value
    end

    return value
end

-- Online player: back up, replace in-memory data, update attributes, save.
function PlayerDataService.AdminResetOnline(player)
    local data = loadedData[player]

    if not data or shuttingDown then
        return false, "NOT_LOADED"
    end

    local key = backup(player.UserId, copyData(data))
    if not key then
        return false, "BACKUP_FAILED"
    end

    loadedData[player] = freshDefaults()
    updatePlayerValues(player, loadedData[player])

    -- Make the Strike badge / "Reach level" and rebirth count show the reset
    -- values immediately, whatever the HUD last displayed.
    player:SetAttribute("Rebirths", 0)
    player:SetAttribute("RebirthLevelRequirement", loadedData[player].RebirthLevelRequirement)
    player:SetAttribute("GlobalLevel", 1)
    player:SetAttribute("RebirthMaxReached", false)

    local saved = PlayerDataService.SavePlayer(player)
    return saved, saved and key or "SAVE_FAILED"
end

-- Offline player: back up, then overwrite the stored record.
-- The backup is written BEFORE the UpdateAsync: Roblox does not allow a
-- DataStore call inside an UpdateAsync callback, so a backup made there
-- always failed (every offline reset ended in BACKUP_FAILED).
function PlayerDataService.AdminResetOffline(userId)
    local key = "Player_" .. tostring(userId)

    local okRead, old = pcall(function()
        return playerDataStore:GetAsync(key)
    end)
    if not okRead then
        return false, "READ_FAILED"
    end

    -- in another live server right now: that server would save over the reset
    if typeof(old) == "table" and lockIsLive(old.SessionLock) then
        return false, "PLAYER_ONLINE_ELSEWHERE"
    end

    local backupKey = backup(userId, old)
    if not backupKey then
        return false, "BACKUP_FAILED" -- never overwrite without a backup
    end

    local joinedMeanwhile = false
    local ok, err = pcall(function()
        playerDataStore:UpdateAsync(key, function(current)
            if typeof(current) == "table" and lockIsLive(current.SessionLock) then
                joinedMeanwhile = true
                return nil -- they joined a server since the read: abort
            end
            local fresh = freshDefaults()
            fresh.SessionLock = nil
            return fresh
        end)
    end)

    if not ok then
        return false, tostring(err)
    end
    if joinedMeanwhile then
        return false, "PLAYER_ONLINE_ELSEWHERE"
    end

    return true, backupKey
end

-- Forget a player's in-memory data WITHOUT saving it (used right after a
-- reset so a stale session cannot write the old progression back).
function PlayerDataService.AdminForget(player)
    loadedData[player] = nil
end


function PlayerDataService.BeginShutdown()
    shuttingDown = true
end

function PlayerDataService.IsShuttingDown()
    return shuttingDown
end

--------------------------------------------------
-- AUTOSAVE
--------------------------------------------------

task.spawn(function()
    while not shuttingDown do
        task.wait(AUTOSAVE_INTERVAL)

        if shuttingDown then
            break
        end

        for player in pairs(loadedData) do
            if player.Parent then
                task.spawn(function()
                    PlayerDataService.SavePlayer(player)
                end)
            end
        end
    end
end)

--------------------------------------------------
-- STARTUP
--------------------------------------------------

print("================================")
print("[PlayerDataService] Loaded.")
print("[PlayerDataService] DataStore:", DATASTORE_NAME)
print("[PlayerDataService] Default Ball:", DEFAULT_BALL_ID)
print("[PlayerDataService] Server Authoritative: ENABLED")
print("[PlayerDataService] Rebirth + Progression Attributes: ENABLED")
print("================================")

--------------------------------------------------
-- RETURN MODULE
--------------------------------------------------

return PlayerDataService