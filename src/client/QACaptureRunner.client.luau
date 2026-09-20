--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

if not RunService:IsStudio() or workspace:GetAttribute("EnableQACaptureRunner") ~= true then
	return
end

local player = Players.LocalPlayer
local running = false

local gui = Instance.new("ScreenGui")
gui.Name = "QACaptureOverlay"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2000
gui.ResetOnSpawn = false

local cue = Instance.new("TextLabel")
cue.AnchorPoint = Vector2.new(0.5, 0.5)
cue.Position = UDim2.fromScale(0.5, 0.5)
cue.Size = UDim2.fromScale(0.62, 0.16)
cue.BackgroundColor3 = Color3.fromRGB(7, 15, 18)
cue.BackgroundTransparency = 0.16
cue.TextColor3 = Color3.fromRGB(241, 231, 204)
cue.TextStrokeColor3 = Color3.fromRGB(3, 7, 9)
cue.TextStrokeTransparency = 0.35
cue.Font = Enum.Font.GothamBlack
cue.TextScaled = true
cue.TextWrapped = true
cue.Text = "READY TO RECORD\nPRESS K TO START"
cue.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = cue
gui.Parent = player:WaitForChild("PlayerGui")

local function command(event: RemoteEvent, name: string)
	event:FireServer(name)
	task.wait(0.25)
end

local function setCamera(target: CFrame)
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = target
	end
end

local function moveCamera(target: CFrame, duration: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		task.wait(duration)
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = target }
	)
	tween:Play()
	task.wait(duration)
end

local function normalCamera()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if camera ~= nil and humanoid ~= nil then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid
	end
end

local function sceneLabel(text: string, duration: number)
	workspace:SetAttribute("QACaptureScene", text)
	workspace:SetAttribute("QACaptureSceneDuration", duration)
	cue.Visible = false
end

local function runSequence(event: RemoteEvent)
	running = true
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	command(event, "Prepare")
	for count = 3, 1, -1 do
		cue.Text = `READY TO RECORD\n{count}`
		task.wait(1)
	end
	cue.Visible = false

	-- A: honest exterior/lobby approach with the normal storm and Le Morne in frame.
	sceneLabel("A  •  ESTABLISHING", 5)
	setCamera(CFrame.lookAt(Vector3.new(20, 25, 112), Vector3.new(0, 22, -155)))
	moveCamera(CFrame.lookAt(Vector3.new(3, 12, 78), Vector3.new(0, 5, 35)), 5)

	-- B: lobby materials, architecture and motivated practicals.
	command(event, "Lobby")
	sceneLabel("B  •  LOBBY", 4)
	setCamera(CFrame.lookAt(Vector3.new(18, 8, 51), Vector3.new(-7, 4, 31)))
	moveCamera(CFrame.lookAt(Vector3.new(-13, 7, 45), Vector3.new(-7, 4, 30)), 4)

	-- C: primary guest shelter corridor at playable eye height.
	command(event, "Corridor")
	sceneLabel("C  •  SHELTER CORRIDOR", 4)
	setCamera(CFrame.lookAt(Vector3.new(-42, 6.5, 16), Vector3.new(-70, 4, 8)))
	moveCamera(CFrame.lookAt(Vector3.new(-61, 6, 13), Vector3.new(-76, 4, 0)), 4)

	-- D: real occupied-shelter Stop path and Listener animation.
	command(event, "EnterShelter")
	sceneLabel("D  •  LISTENER STOP", 8)
	setCamera(CFrame.lookAt(Vector3.new(-55, 7.5, 20), Vector3.new(-68, 5, 10)))
	task.wait(1.5)
	command(event, "StartStop")
	task.wait(6.25)

	-- E: player-facing Breath HUD from the authored shelter camera.
	sceneLabel("E  •  SHELTER / BREATH", 7)
	local record = workspace:FindFirstChild("Wardrobe_suite-wardrobe", true)
	local hidingCamera = if record then record:FindFirstChild("HidingCamera", true) else nil
	if hidingCamera ~= nil and hidingCamera:IsA("BasePart") then
		setCamera(hidingCamera.CFrame)
	end
	task.wait(7)
	command(event, "ExitShelter")

	-- F: pool, wet surfaces, planting and storm separation.
	command(event, "Pool")
	sceneLabel("F  •  POOL / MAURITIUS", 4)
	setCamera(CFrame.lookAt(Vector3.new(18, 9, 70), Vector3.new(56, 2, 54)))
	moveCamera(CFrame.lookAt(Vector3.new(34, 7, 70), Vector3.new(67, 2, 51)), 4)

	-- G: deterministic real blackout state.
	sceneLabel("G  •  BLACKOUT", 4)
	setCamera(CFrame.lookAt(Vector3.new(10, 8, -42), Vector3.new(0, 4, -62)))
	command(event, "Blackout")
	task.wait(3.75)

	-- H: same fuse completion handler used by the prompt, invoked by Studio harness.
	sceneLabel("H  •  FUSE", 4)
	setCamera(CFrame.lookAt(Vector3.new(8, 7, -63), Vector3.new(0, 4, -71)))
	task.wait(2)
	command(event, "Fuse")
	task.wait(1.75)

	-- I: real visual acquisition and normal player camera during the chase.
	sceneLabel("I  •  CHASE", 7)
	command(event, "Chase")
	normalCamera()
	task.wait(7)
	command(event, "Finish")

	setCamera(CFrame.lookAt(Vector3.new(0, 13, 82), Vector3.new(0, 4, 48)))
	cue.Position = UDim2.fromScale(0.5, 0.5)
	cue.Size = UDim2.fromScale(0.62, 0.16)
	cue.BackgroundTransparency = 0.16
	cue.Text = "CAPTURE COMPLETE"
	cue.Visible = true
	task.wait(3)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
	running = false
end

local function startAction(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin or running then
		return Enum.ContextActionResult.Sink
	end
	local folder = ReplicatedStorage:FindFirstChild("HideRemotes")
	local event = if folder then folder:FindFirstChild("QACaptureControl") else nil
	if event == nil or not event:IsA("RemoteEvent") then
		cue.Text = "CAPTURE RUNNER NOT READY"
		return Enum.ContextActionResult.Sink
	end
	task.spawn(runSequence, event)
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("StartQACapture", startAction, false, Enum.KeyCode.K)
