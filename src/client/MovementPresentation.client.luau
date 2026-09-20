--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Protocol = require(ReplicatedStorage.Hide.Shared.RemoteProtocol)
local remotes = ReplicatedStorage:WaitForChild("HideRemotes")
local actionRequest = remotes:WaitForChild(Protocol.RequestEventName) :: RemoteEvent
local player = Players.LocalPlayer
local crouched = false
local requestCounter = 0

local function requestId(): string
	requestCounter += 1
	return `movement-{math.floor(workspace:GetServerTimeNow() * 1000)}-{requestCounter}`
end

local function applyCameraPose()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid ~= nil then
		humanoid.CameraOffset = if crouched then Vector3.new(0, -1.35, 0) else Vector3.zero
	end
end

local function toggleCrouch(_, inputState: Enum.UserInputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	crouched = not crouched
	applyCameraPose()
	actionRequest:FireServer({
		action = "SetCrouch",
		requestId = requestId(),
		enabled = crouched,
	})
	ContextActionService:SetTitle("HideCrouch", if crouched then "STAND" else "CROUCH")
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction(
	"HideCrouch",
	toggleCrouch,
	true,
	Enum.KeyCode.LeftControl,
	Enum.KeyCode.ButtonB
)
ContextActionService:SetTitle("HideCrouch", "CROUCH")
ContextActionService:SetPosition(
	"HideCrouch",
	if UserInputService.TouchEnabled
		then UDim2.fromScale(0.16, 0.68)
		else UDim2.fromScale(0.12, 0.7)
)
task.defer(function()
	local button = ContextActionService:GetButton("HideCrouch")
	if button ~= nil then
		button.Size = UDim2.fromOffset(64, 64)
		button.BackgroundColor3 = Color3.fromRGB(43, 86, 81)
		button.BackgroundTransparency = 0.12
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = button
	end
end)

player.CharacterAdded:Connect(function()
	crouched = false
	ContextActionService:SetTitle("HideCrouch", "CROUCH")
	task.defer(applyCameraPose)
end)

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local camera = workspace.CurrentCamera
	local hud = player:FindFirstChildOfClass("PlayerGui")
	local breathPanel = if hud then hud:FindFirstChild("BreathPressure", true) else nil
	if
		humanoid == nil
		or camera == nil
		or crouched
		or (breathPanel ~= nil and breathPanel:IsA("GuiObject") and breathPanel.Visible)
	then
		return
	end
	local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
	local target = if speed > 11 then 73 else 70
	camera.FieldOfView += (target - camera.FieldOfView) * 0.08
end)
