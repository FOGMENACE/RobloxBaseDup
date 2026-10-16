-- FLOATING XP UI
-- LOCATION: StarterPlayer > StarterPlayerScripts
-- Displays server-confirmed XP awards above the player's ball.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local xpAward = remotes:WaitForChild("XPAward")

local FONT = Enum.Font.FredokaOne

local COLORS = {
    Green = Color3.fromRGB(83, 255, 130),
    White = Color3.fromRGB(255, 255, 255),
    Dark = Color3.fromRGB(20, 16, 28),
}

local function formatNumber(value)
    value = math.max(0, math.floor(value))

    if value >= 1e12 then
        return string.format("%.2fT", value / 1e12)
    elseif value >= 1e9 then
        return string.format("%.2fB", value / 1e9)
    elseif value >= 1e6 then
        return string.format("%.2fM", value / 1e6)
    elseif value >= 1e3 then
        return string.format("%.1fK", value / 1e3)
    end

    return tostring(value)
end

local function getPlayerBall()
    local folder = workspace:FindFirstChild("PlayerBalls")
    if not folder then
        return nil
    end

    local ball = folder:FindFirstChild(
        "PlayerBall_" .. tostring(player.UserId)
    )

    if ball and ball:IsA("BasePart") then
        return ball
    end

    return nil
end

local function showFloatingXP(amount)
    if typeof(amount) ~= "number"
        or amount <= 0
        or amount ~= amount
        or amount == math.huge then
        return
    end

    local ball = getPlayerBall()
    if not ball then
        return
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "FloatingXP"
    billboard.Adornee = ball
    billboard.Size = UDim2.fromOffset(180, 55)
    billboard.StudsOffsetWorldSpace = Vector3.new(
        math.random(-10, 10) / 10,
        3,
        0
    )
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.MaxDistance = 150
    billboard.Parent = player:WaitForChild("PlayerGui")

    local label = Instance.new("TextLabel")
    label.Name = "XPText"
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = FONT
    label.Text = "+" .. formatNumber(amount) .. " XP"
    label.TextColor3 = COLORS.Green
    label.TextScaled = true
    label.TextStrokeColor3 = COLORS.Dark
    label.TextStrokeTransparency = 0.1
    label.Parent = billboard

    local scale = Instance.new("UIScale")
    scale.Scale = 0.7
    scale.Parent = label

    TweenService:Create(
        scale,
        TweenInfo.new(0.15, Enum.EasingStyle.Back),
        { Scale = 1 }
    ):Play()

    local floatTween = TweenService:Create(
        billboard,
        TweenInfo.new(
            0.9,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        {
            StudsOffsetWorldSpace =
                billboard.StudsOffsetWorldSpace
                + Vector3.new(0, 3, 0),
        }
    )

    local fadeTween = TweenService:Create(
        label,
        TweenInfo.new(0.9, Enum.EasingStyle.Quad),
        {
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        }
    )

    floatTween:Play()
    fadeTween:Play()

    task.delay(1, function()
        if billboard.Parent then
            billboard:Destroy()
        end
    end)
end

xpAward.OnClientEvent:Connect(showFloatingXP)

print("[FloatingXPUI] Loaded.")