--!strict

local CaptureService = game:GetService("CaptureService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

if not RunService:IsStudio() then
	return
end

local recording = false
local savedCapture: any? = nil

local function createTitleCard(): (ScreenGui, TextLabel)
	local gui = Instance.new("ScreenGui")
	gui.Name = "MarketingCaptureOverlay"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	local cue = Instance.new("TextLabel")
	cue.AnchorPoint = Vector2.new(0.5, 1)
	cue.Position = UDim2.fromScale(0.5, 0.91)
	cue.Size = UDim2.fromScale(0.84, 0.14)
	cue.BackgroundColor3 = Color3.fromRGB(7, 16, 20)
	cue.BackgroundTransparency = 0.22
	cue.TextColor3 = Color3.fromRGB(237, 244, 239)
	cue.TextStrokeColor3 = Color3.fromRGB(5, 11, 14)
	cue.TextStrokeTransparency = 0.35
	cue.Font = Enum.Font.GothamBlack
	cue.TextScaled = true
	cue.TextWrapped = true
	cue.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, cue
end

local function playShot(
	camera: Camera,
	cue: TextLabel,
	text: string,
	target: CFrame,
	duration: number
)
	cue.Text = text
	local tween = TweenService:Create(
		camera,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ CFrame = target }
	)
	tween:Play()
	task.wait(duration)
end

local function setHudVisible(visible: boolean)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = if playerGui then playerGui:FindFirstChild("HideHUD") else nil
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = visible
	end
end

local function startCapture()
	if recording or workspace:GetAttribute("EnableMarketingCapture") ~= true then
		return
	end
	local result = CaptureService:StartVideoCaptureAsync(function(captureResult, capture)
		recording = false
		workspace:SetAttribute("MarketingCaptureResult", tostring(captureResult))
		if capture ~= nil then
			savedCapture = capture
			CaptureService:PromptSaveCapturesToGallery({ capture }, function()
				workspace:SetAttribute("MarketingCaptureSaved", true)
			end)
		end
	end, {})
	recording = result == Enum.VideoCaptureStartedResult.Success
	workspace:SetAttribute("MarketingCaptureStarted", tostring(result))
end

local function stopCapture()
	if recording then
		CaptureService:StopVideoCapture()
	end
end

local function runTrailer()
	if recording or workspace:GetAttribute("EnableMarketingCapture") ~= true then
		return
	end
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local previousType = camera.CameraType
	local previousSubject = camera.CameraSubject
	local overlay, cue = createTitleCard()
	setHudVisible(false)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 42, 132), Vector3.new(0, 18, -145))
	startCapture()
	if not recording then
		overlay:Destroy()
		setHudVisible(true)
		camera.CameraType = previousType
		camera.CameraSubject = previousSubject
		return
	end
	task.spawn(function()
		playShot(
			camera,
			cue,
			"HIDE!\nMAURITIUS — LE MORNE",
			CFrame.lookAt(Vector3.new(16, 32, 112), Vector3.new(0, 15, -150)),
			3
		)
		playShot(
			camera,
			cue,
			"HIDE BEFORE IT HEARS YOU",
			CFrame.lookAt(Vector3.new(-13, 10, 58), Vector3.new(0, 3, 34)),
			4
		)
		playShot(
			camera,
			cue,
			"LET THEM IN?",
			CFrame.lookAt(Vector3.new(-11, 7, 39), Vector3.new(-19, 3, 32)),
			4
		)
		playShot(
			camera,
			cue,
			"MORE PEOPLE = MORE NOISE\nSUSPICION • HOT",
			CFrame.lookAt(Vector3.new(-62, 8, 3), Vector3.new(-75, 3, -7)),
			4
		)
		local listener = workspace:FindFirstChild("TheListener", true)
		local listenerTarget = if listener and listener:IsA("Model")
			then listener:GetPivot().Position
			else Vector3.new(0, 4, -10)
		playShot(
			camera,
			cue,
			"PEEK — BUT IT MAKES NOISE",
			CFrame.lookAt(listenerTarget + Vector3.new(13, 6, 13), listenerTarget),
			4
		)
		playShot(
			camera,
			cue,
			"THE LIGHTS ARE GONE",
			CFrame.lookAt(Vector3.new(11, 9, -43), Vector3.new(0, 3, -56)),
			3
		)
		playShot(
			camera,
			cue,
			"HOLD THE DOOR — OR SAVE YOURSELF",
			CFrame.lookAt(Vector3.new(42, 8, -10), Vector3.new(51, 3, -18)),
			4
		)
		playShot(
			camera,
			cue,
			"HIDE! by TAKAVEN\nWOULD YOU LET THEM IN?",
			CFrame.lookAt(Vector3.new(0, 17, 91), Vector3.new(0, 4, 68)),
			3
		)
		stopCapture()
		overlay:Destroy()
		setHudVisible(true)
		camera.CameraType = previousType
		camera.CameraSubject = previousSubject
	end)
end

CaptureService.CaptureBegan:Connect(function()
	if workspace:GetAttribute("MarketingCleanHUD") == true then
		setHudVisible(false)
	end
end)

CaptureService.CaptureEnded:Connect(function()
	setHudVisible(true)
end)

workspace:GetAttributeChangedSignal("MarketingCaptureCommand"):Connect(function()
	local command = workspace:GetAttribute("MarketingCaptureCommand")
	if command == "Start" then
		startCapture()
	elseif command == "Stop" then
		stopCapture()
	elseif command == "Trailer" then
		runTrailer()
	elseif command == "Resave" and savedCapture ~= nil then
		CaptureService:PromptSaveCapturesToGallery({ savedCapture }, function()
			workspace:SetAttribute("MarketingCaptureSaved", true)
		end)
	end
end)
