local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")

if not remotes then
    remotes = Instance.new("Folder")
    remotes.Name = "Remotes"
    remotes.Parent = ReplicatedStorage
end

local ballMovement = remotes:FindFirstChild("BallMovement")

if not ballMovement then
    ballMovement = Instance.new("RemoteEvent")
    ballMovement.Name = "BallMovement"
    ballMovement.Parent = remotes
end
