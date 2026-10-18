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
-- TOUCH HANDLERS + SWEPT COLLISION
--
-- A platform is only ~0.3 studs thick. At high speed the ball moves several
-- studs per physics step and Touched can miss it entirely (that made X2 / X4
-- / dividers and oil randomly "not count"). A per-frame swept check runs the
-- same handler for every platform the ball's path crossed.
--------------------------------------------------

local touchHandlers = {}
local sweepParts = {} -- [playerCourse] = { { Part, Platform } }

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

        local function handler(hit)

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

            -- Special platforms (X2 / X4 / /2 / /4) are defined by OilType and act
            -- on CurrentOil, so their OilAmount is 0 BY DESIGN. Only normal oil
            -- platforms need a non-zero amount (this check used to reject every
            -- special platform, so X2 / X4 / dividers never did anything).
            local isSpecialPlatform = platform:GetAttribute("IsSpecial") == true

            if typeof(oilAmount) ~= "number"
                or oilAmount ~= oilAmount
                or oilAmount == math.huge
                or oilAmount == -math.huge
                or (oilAmount == 0 and not isSpecialPlatform) then

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

        end

        touchHandlers[part] = handler
        part.Touched:Connect(handler)

        sweepParts[playerCourse] = sweepParts[playerCourse] or {}
        table.insert(sweepParts[playerCourse], { Part = part, Platform = platform })

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
-- SWEPT COLLISION LOOP
--------------------------------------------------

local RunService = game:GetService("RunService")
local lastBallPosition = {}

RunService.Heartbeat:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player:GetAttribute("RunState") ~= "Running" then
            lastBallPosition[player] = nil
            continue
        end

        local ball = workspace:FindFirstChild("PlayerBalls")
            and workspace.PlayerBalls:FindFirstChild("PlayerBall_" .. player.UserId)
        if not ball then
            continue
        end

        local current = ball.Position
        local previous = lastBallPosition[player]
        lastBallPosition[player] = current

        if not previous or (current - previous).Magnitude < 1.5 then
            continue -- slow enough for Touched
        end

        local playerCourse = courseFolder:FindFirstChild("PlayerCourse_" .. player.UserId)
        local list = playerCourse and sweepParts[playerCourse]
        if not list then
            continue
        end

        local radius = ball.Size.X / 2

        for _, entry in ipairs(list) do
            local part = entry.Part
            local platform = entry.Platform

            if part.Parent and platform:GetAttribute("Collected") ~= true then
                local size = part.Size
                local axis = "X"
                if size.Y < size[axis] then axis = "Y" end
                if size.Z < size[axis] then axis = "Z" end

                local a = part.CFrame:PointToObjectSpace(previous)
                local b = part.CFrame:PointToObjectSpace(current)
                local pa, pb = a[axis], b[axis]
                local half = size[axis] / 2 + radius

                -- crossed (or ended inside) the thin slab?
                local crossed = (pa < -half and pb > -half) or (pa > half and pb < half)
                    or (math.abs(pa) <= half) or (math.abs(pb) <= half)

                if crossed and pa ~= pb then
                    local t = math.clamp((0 - pa) / (pb - pa), 0, 1)
                    local at = a:Lerp(b, t)
                    local inside = true
                    for _, other in ipairs({ "X", "Y", "Z" }) do
                        if other ~= axis and math.abs(at[other]) > size[other] / 2 + radius then
                            inside = false
                        end
                    end

                    if inside then
                        local handler = touchHandlers[part]
                        if handler then
                            task.spawn(handler, ball)
                        end
                    end
                end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    lastBallPosition[player] = nil
end)

--------------------------------------------------
-- CLEANUP
--------------------------------------------------

courseFolder.ChildRemoved:Connect(function(playerCourse)

    connectingCourses[playerCourse] = nil
    sweepParts[playerCourse] = nil

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