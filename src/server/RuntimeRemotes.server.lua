--------------------------------------------------
-- RUNTIME REMOTES
--
-- SERVER ONLY
--------------------------------------------------

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")


--------------------------------------------------
-- REMOTES FOLDER
--------------------------------------------------

local remotes =
	ReplicatedStorage:FindFirstChild("Remotes")

if not remotes then

	remotes =
		Instance.new("Folder")

	remotes.Name =
		"Remotes"

	remotes.Parent =
		ReplicatedStorage

end


--------------------------------------------------
-- BALL MOVEMENT
--------------------------------------------------

local ballMovement =
	remotes:FindFirstChild("BallMovement")

if not ballMovement then

	ballMovement =
		Instance.new("RemoteEvent")

	ballMovement.Name =
		"BallMovement"

	ballMovement.Parent =
		remotes

end


--------------------------------------------------
-- WIN COURSE
--------------------------------------------------

local winCourse =
	remotes:FindFirstChild("WinCourse")

if not winCourse then

	winCourse =
		Instance.new("RemoteEvent")

	winCourse.Name =
		"WinCourse"

	winCourse.Parent =
		remotes

end


--------------------------------------------------
-- STARTUP
--------------------------------------------------

print(
	"[RuntimeRemotes]",
	"Remotes ready."
)