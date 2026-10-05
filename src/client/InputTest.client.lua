local left = false
local right = false

local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.A then
    left = true
    print("Left:", left)
elseif input.KeyCode == Enum.KeyCode.D then
    right = true
    print("Right:", right)
end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.A then
        print("A released")
        left = false
    elseif input.KeyCode == Enum.KeyCode.D then
        print("D released")
        right = false
    end
end)