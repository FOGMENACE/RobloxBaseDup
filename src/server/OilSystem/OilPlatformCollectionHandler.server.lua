--------------------------------------------------
-- OIL PLATFORM COLLECTION HANDLER
--
-- LOCATION:
-- ServerScriptService
--     > OilPlatformCollectionHandler
--
-- PURPOSE:
-- - Detect oil platform touches.
-- - Identify the player from ball/course names.
-- - Validate platform ownership and oil attributes.
-- - Prevent duplicate collection.
-- - Call the existing CollectOilRequest BindableFunction.
--
-- DOES NOT:
-- - Award oil directly.
-- - Replace OilCollectionService.
-- - Create RemoteEvents.
--------------------------------------------------


--------------------------------------------------
-- SERVICES
--------------------------------------------------

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")


--------------------------------------------------
-- REFERENCES
--------------------------------------------------

local oilSystem =
    ServerScriptService:WaitForChild("OilSystem")

local collectionBridge =
    oilSystem:WaitForChild("CollectOilRequest")

local courseFolder =
    workspace:WaitForChild("Course")


--------------------------------------------------
-- VALIDATE COLLECTION BRIDGE
--------------------------------------------------

assert(
    collectionBridge:IsA("BindableFunction"),
    "[OilPlatformCollectionHandler] CollectOilRequest must be a BindableFunction."
)


--------------------------------------------------
-- STATE
--------------------------------------------------

local connectedParts = {}
local connectingCourses = {}


--------------------------------------------------
-- VALIDATE PLAYER
--------------------------------------------------

local function isValidPlayer(player)
    return player ~= nil
        and player:IsA("Player")
        and player.Parent == Players
end


--------------------------------------------------
-- GET USER ID FROM GENERATED NAME
--------------------------------------------------

local function getUserIdFromName(name, pattern)
    if typeof(name) ~= "string" then
        return nil
    end

    return tonumber(name:match(pattern))
end


--------------------------------------------------
-- FIND PLAYER FROM MATCHING PLAYER BALL
--------------------------------------------------

local function getPlayerFromHit(hit, playerCourse)

    if not hit or not hit:IsA("BasePart") then
        return nil
    end

    local ballFolder = workspace:FindFirstChild("PlayerBalls")

    if not ballFolder then
        warn("[OilPlatformCollectionHandler] PlayerBalls folder missing")
        return nil
    end

    --------------------------------------------------
    -- FIND THE PLAYER BALL MODEL
    --------------------------------------------------

    local ball = hit

    while ball and ball.Parent ~= ballFolder do
        ball = ball.Parent
    end

    if not ball or ball.Parent ~= ballFolder then
        warn(
            "[OilPlatformCollectionHandler] Hit is not inside PlayerBalls:",
            hit:GetFullName()
        )
        return nil
    end

    --------------------------------------------------
    -- EXTRACT USER ID FROM BALL NAME
    --------------------------------------------------

    local ballUserId = tonumber(
        ball.Name:match("^PlayerBall_(%d+)$")
    )

    if not ballUserId then
        warn(
            "[OilPlatformCollectionHandler] Invalid player ball name:",
            ball.Name
        )
        return nil
    end

    --------------------------------------------------
    -- MATCH BALL TO GENERATED COURSE
    --------------------------------------------------

    local courseUserId = tonumber(
        playerCourse.Name:match("^PlayerCourse_(%d+)$")
    )

    if not courseUserId or courseUserId ~= ballUserId then
        warn(
            "[OilPlatformCollectionHandler] BALL/COURSE MISMATCH:",
            ball.Name,
            playerCourse.Name
        )
        return nil
    end

    --------------------------------------------------
    -- RESOLVE ACTUAL PLAYER
    --------------------------------------------------

    local player = Players:GetPlayerByUserId(ballUserId)

    if not player or player.Parent ~= Players then
        warn(
            "[OilPlatformCollectionHandler] No active Player for ball:",
            ball.Name,
            "| UserId:", ballUserId
        )
        return nil
    end

    print(
        "[OilPlatformCollectionHandler] MATCHED PLAYER BALL:",
        ball:GetFullName(),
        "| Player:", player.Name,
        "| UserId:", ballUserId,
        "| Course:", playerCourse.Name
    )

    return player
end

--------------------------------------------------
-- GET PLATFORM PARTS
--------------------------------------------------

local function getPlatformParts(platform)

    local parts = {}

    if platform:IsA("BasePart") then

        table.insert(parts, platform)

    elseif platform:IsA("Model") then

        for _, object in ipairs(platform:GetDescendants()) do

            if object:IsA("BasePart") then
                table.insert(parts, object)
            end

        end

    end

    return parts
end


--------------------------------------------------
-- CONNECT PLATFORM
--------------------------------------------------

local function connectPlatform(platform, playerCourse)

    if not platform:IsA("BasePart")
        and not platform:IsA("Model") then
        return
    end

    for _, part in ipairs(getPlatformParts(platform)) do

        if connectedParts[part] then
            continue
        end

        connectedParts[part] = true
        part.CanTouch = true

        part.Touched:Connect(function(hit)

            --------------------------------------------------
            -- VALIDATE PLATFORM
            --------------------------------------------------

            if not platform:IsDescendantOf(playerCourse) then
                return
            end

            if platform:GetAttribute("Collected") == true then
                return
            end

            if not hit or not hit:IsA("BasePart") then
                return
            end

            --------------------------------------------------
            -- IDENTIFY PLAYER
            --------------------------------------------------

            local player =
                getPlayerFromHit(hit, playerCourse)

            if not isValidPlayer(player) then
                return
            end

            --------------------------------------------------
            -- VALIDATE COURSE OWNERSHIP
            --------------------------------------------------

            if player.UserId ~= tonumber(
                playerCourse.Name:match("^PlayerCourse_(%d+)$")
            ) then
                return
            end

            --------------------------------------------------
            -- VALIDATE OIL ATTRIBUTES
            --------------------------------------------------

            local oilType =
                platform:GetAttribute("OilType")

            local oilAmount =
                platform:GetAttribute("OilAmount")

            if typeof(oilType) ~= "string"
                or oilType == "" then

                warn(
                    "[OilPlatformCollectionHandler] Missing OilType:",
                    platform:GetFullName()
                )

                return
            end

            if typeof(oilAmount) ~= "number"
                or oilAmount ~= oilAmount
                or oilAmount == math.huge
                or oilAmount == -math.huge
                or oilAmount == 0 then

                warn(
                    "[OilPlatformCollectionHandler] Invalid OilAmount:",
                    platform:GetFullName(),
                    oilAmount
                )

                return
            end

            --------------------------------------------------
            -- RESERVE PLATFORM
            --------------------------------------------------

            platform:SetAttribute("Collected", true)

            print(
                "[OilPlatformCollectionHandler] COLLECTION REQUEST:",
                player.Name,
                "| Type:", oilType,
                "| Amount:", oilAmount,
                "| Platform:", platform:GetFullName(),
                "| CurrentOil Before:",
                player:GetAttribute("CurrentOil")
            )

            --------------------------------------------------
            -- AUTHORITATIVE COLLECTION
            --------------------------------------------------

            local invokeOK, success, result = pcall(function()

                return collectionBridge:Invoke(
                    player,
                    oilType,
                    platform
                )

            end)

            --------------------------------------------------
            -- HANDLE FAILURE
            --------------------------------------------------

            if not invokeOK or success ~= true then

                platform:SetAttribute("Collected", false)

                warn(
                    "[OilPlatformCollectionHandler] COLLECTION FAILED:",
                    player.Name,
                    "| InvokeOK:", invokeOK,
                    "| Success:", success,
                    "| Result:", result
                )

                return
            end

            --------------------------------------------------
            -- SUCCESS AUDIT
            --------------------------------------------------

            print(
                "[OilPlatformCollectionHandler] COLLECTION SUCCESS:",
                player.Name,
                "| Type:", oilType,
                "| Result:", result,
                "| CurrentOil After:",
                player:GetAttribute("CurrentOil"),
                "| CollectedOilCount:",
                player:GetAttribute("CollectedOilCount")
            )

        end)

    end

end


--------------------------------------------------
-- CONNECT GENERATED COURSE
--------------------------------------------------

local function connectCourse(playerCourse)

    if not playerCourse:IsA("Folder") then
        return
    end

    if not playerCourse.Name:match("^PlayerCourse_%d+$") then
        return
    end

    if connectingCourses[playerCourse] then
        return
    end

    connectingCourses[playerCourse] = true

    for _, object in ipairs(playerCourse:GetDescendants()) do

        if object.Name == "OilPlatformL"
            or object.Name == "OilPlatformR" then

            connectPlatform(object, playerCourse)

        end

    end

    print(
        "[OilPlatformCollectionHandler] Connected course:",
        playerCourse.Name
    )

end


--------------------------------------------------
-- INITIAL COURSES
--------------------------------------------------

for _, playerCourse in ipairs(courseFolder:GetChildren()) do
    connectCourse(playerCourse)
end


--------------------------------------------------
-- FUTURE COURSES
--------------------------------------------------

courseFolder.ChildAdded:Connect(function(playerCourse)

    connectCourse(playerCourse)

end)


--------------------------------------------------
-- CLEANUP
--------------------------------------------------

courseFolder.ChildRemoved:Connect(function(playerCourse)

    connectingCourses[playerCourse] = nil

end)


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print(
    "[OilPlatformCollectionHandler] SERVER READY"
)

print(
    "[OilPlatformCollectionHandler] CollectOilRequest:",
    collectionBridge:GetFullName()
)