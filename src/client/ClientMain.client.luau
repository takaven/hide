--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Hide.Shared.RemoteProtocol)
local remotesFolder = ReplicatedStorage:WaitForChild("HideRemotes")
local actionRequest = remotesFolder:WaitForChild(Protocol.RequestEventName) :: RemoteEvent
local actionResult = remotesFolder:WaitForChild(Protocol.ResultEventName) :: RemoteEvent
local stateSnapshot = remotesFolder:WaitForChild(Protocol.SnapshotEventName) :: RemoteEvent
local getStateSnapshot = remotesFolder:WaitForChild(Protocol.SnapshotFunctionName) :: RemoteFunction

local currentContext: any? = nil
local requestCounter = 0
local entryRequestGeneration = 0
local currentPhase = "Lobby"
local phaseDeadline = 0
local currentState = "Spectating"

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local hud = Instance.new("ScreenGui")
hud.Name = "HideHUD"
hud.IgnoreGuiInset = true
hud.ResetOnSpawn = false
hud.DisplayOrder = 20
hud.Parent = playerGui

local top = Instance.new("Frame")
top.Name = "RoundPanel"
top.AnchorPoint = Vector2.new(0.5, 0)
top.Position = UDim2.fromScale(0.5, 0.035)
top.Size = UDim2.new(0.72, 0, 0, 70)
top.BackgroundColor3 = Color3.fromRGB(12, 24, 27)
top.BackgroundTransparency = 0.12
top.Parent = hud
local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 14)
topCorner.Parent = top
local topConstraint = Instance.new("UISizeConstraint")
topConstraint.MaxSize = Vector2.new(620, 80)
topConstraint.MinSize = Vector2.new(280, 64)
topConstraint.Parent = top

local phaseLabel = Instance.new("TextLabel")
phaseLabel.Name = "Phase"
phaseLabel.BackgroundTransparency = 1
phaseLabel.Position = UDim2.fromOffset(14, 7)
phaseLabel.Size = UDim2.new(1, -28, 0, 30)
phaseLabel.Font = Enum.Font.GothamBold
phaseLabel.TextColor3 = Color3.fromRGB(241, 233, 211)
phaseLabel.TextSize = 21
phaseLabel.Text = "HIDE!  •  LOBBY"
phaseLabel.Parent = top

local objectiveLabel = Instance.new("TextLabel")
objectiveLabel.Name = "Objective"
objectiveLabel.BackgroundTransparency = 1
objectiveLabel.Position = UDim2.fromOffset(14, 37)
objectiveLabel.Size = UDim2.new(1, -28, 0, 24)
objectiveLabel.Font = Enum.Font.GothamMedium
objectiveLabel.TextColor3 = Color3.fromRGB(138, 213, 204)
objectiveLabel.TextSize = 15
objectiveLabel.Text = "WAITING FOR SURVIVORS"
objectiveLabel.Parent = top

local silencePanel = Instance.new("Frame")
silencePanel.Name = "SharedSilence"
silencePanel.AnchorPoint = Vector2.new(0.5, 1)
silencePanel.Position = UDim2.fromScale(0.5, 0.94)
silencePanel.Size = UDim2.new(0.76, 0, 0, 58)
silencePanel.BackgroundColor3 = Color3.fromRGB(12, 24, 27)
silencePanel.BackgroundTransparency = 0.08
silencePanel.Visible = false
silencePanel.Parent = hud
local silenceConstraint = Instance.new("UISizeConstraint")
silenceConstraint.MaxSize = Vector2.new(620, 64)
silenceConstraint.MinSize = Vector2.new(280, 54)
silenceConstraint.Parent = silencePanel
local silenceCorner = Instance.new("UICorner")
silenceCorner.CornerRadius = UDim.new(0, 14)
silenceCorner.Parent = silencePanel
local silenceLabel = Instance.new("TextLabel")
silenceLabel.BackgroundTransparency = 1
silenceLabel.Position = UDim2.fromOffset(14, 5)
silenceLabel.Size = UDim2.new(1, -28, 0, 22)
silenceLabel.Font = Enum.Font.GothamBold
silenceLabel.TextColor3 = Color3.fromRGB(225, 238, 229)
silenceLabel.TextSize = 16
silenceLabel.TextXAlignment = Enum.TextXAlignment.Left
silenceLabel.Text = "SHARED SILENCE  •  SAFE"
silenceLabel.Parent = silencePanel
local meterBack = Instance.new("Frame")
meterBack.BackgroundColor3 = Color3.fromRGB(51, 63, 63)
meterBack.BorderSizePixel = 0
meterBack.Position = UDim2.fromOffset(14, 34)
meterBack.Size = UDim2.new(1, -28, 0, 12)
meterBack.Parent = silencePanel
local meterCorner = Instance.new("UICorner")
meterCorner.CornerRadius = UDim.new(1, 0)
meterCorner.Parent = meterBack
local meterFill = Instance.new("Frame")
meterFill.BackgroundColor3 = Color3.fromRGB(68, 196, 135)
meterFill.BorderSizePixel = 0
meterFill.Size = UDim2.fromScale(0, 1)
meterFill.Parent = meterBack
local meterFillCorner = Instance.new("UICorner")
meterFillCorner.CornerRadius = UDim.new(1, 0)
meterFillCorner.Parent = meterFill

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0.5)
toast.Position = UDim2.fromScale(0.5, 0.3)
toast.Size = UDim2.new(0.78, 0, 0, 58)
toast.BackgroundColor3 = Color3.fromRGB(12, 24, 27)
toast.BackgroundTransparency = 0.08
toast.Font = Enum.Font.GothamBold
toast.TextColor3 = Color3.fromRGB(245, 232, 203)
toast.TextSize = 20
toast.TextWrapped = true
toast.Visible = false
toast.Parent = hud
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 14)
toastCorner.Parent = toast
local toastGeneration = 0

local function showToast(message: string, seconds: number?)
	toastGeneration += 1
	local generation = toastGeneration
	toast.Text = message
	toast.Visible = true
	task.delay(seconds or 2.4, function()
		if toastGeneration == generation then
			toast.Visible = false
		end
	end)
end

local function styleAction(name: string, color: Color3)
	task.defer(function()
		local button = ContextActionService:GetButton(name)
		if button ~= nil then
			button.Size = UDim2.fromOffset(72, 72)
			button.BackgroundColor3 = color
			button.BackgroundTransparency = 0.1
			local corner = button:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = button
		end
	end)
end

local function nextRequestId(): string
	requestCounter += 1
	return `{math.floor(workspace:GetServerTimeNow() * 1000)}-{requestCounter}`
end

local function unbindContext()
	ContextActionService:UnbindAction("HidePrimaryAction")
	currentContext = nil
end

local function clearEntryRequest()
	entryRequestGeneration += 1
	ContextActionService:UnbindAction("HideAcceptEntry")
	ContextActionService:UnbindAction("HideRefuseEntry")
end

local function bindEntryRequest(entryRequest: any)
	clearEntryRequest()
	local generation = entryRequestGeneration
	local function respond(accepted: boolean)
		actionRequest:FireServer({
			action = "ResolveEntryRequest",
			requestId = nextRequestId(),
			entryRequestId = entryRequest.id,
			accepted = accepted,
		})
		clearEntryRequest()
	end
	ContextActionService:BindAction("HideAcceptEntry", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			respond(true)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.Y, Enum.KeyCode.ButtonA)
	ContextActionService:SetTitle("HideAcceptEntry", "LET IN")
	ContextActionService:SetPosition("HideAcceptEntry", UDim2.fromScale(0.66, 0.5))
	styleAction("HideAcceptEntry", Color3.fromRGB(49, 148, 110))

	ContextActionService:BindAction("HideRefuseEntry", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			respond(false)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.N, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("HideRefuseEntry", "REFUSE")
	ContextActionService:SetPosition("HideRefuseEntry", UDim2.fromScale(0.84, 0.5))
	styleAction("HideRefuseEntry", Color3.fromRGB(157, 59, 55))

	local remaining = math.max(0, (entryRequest.expiresAt or 0) - workspace:GetServerTimeNow())
	showToast("LET THEM IN?  MORE PEOPLE MEANS MORE NOISE.", remaining)
	task.delay(remaining, function()
		if entryRequestGeneration == generation then
			clearEntryRequest()
		end
	end)
end

local function bindContext(context: any)
	unbindContext()
	if
		type(context) ~= "table"
		or type(context.action) ~= "string"
		or type(context.targetField) ~= "string"
	then
		return
	end
	currentContext = context
	ContextActionService:BindAction("HidePrimaryAction", function(_, inputState)
		if inputState ~= Enum.UserInputState.Begin or currentContext == nil then
			return Enum.ContextActionResult.Pass
		end
		local payload = {
			action = currentContext.action,
			requestId = nextRequestId(),
		}
		payload[currentContext.targetField] = currentContext.targetId
		actionRequest:FireServer(payload)
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("HidePrimaryAction", context.label or "ACT")
	ContextActionService:SetPosition("HidePrimaryAction", UDim2.fromScale(0.82, 0.52))
	styleAction("HidePrimaryAction", Color3.fromRGB(216, 111, 48))
end

local function updateDecoyBinding()
	ContextActionService:UnbindAction("HideUseDecoy")
	if
		(currentState == "Active" or currentState == "Rescued")
		and (currentPhase == "Hunt" or currentPhase == "Relocation" or currentPhase == "Extraction")
	then
		ContextActionService:BindAction("HideUseDecoy", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				actionRequest:FireServer({
					action = "UseDecoy",
					requestId = nextRequestId(),
					decoyId = "storm-clicker",
				})
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonL1)
		ContextActionService:SetTitle("HideUseDecoy", "DECOY")
		ContextActionService:SetPosition("HideUseDecoy", UDim2.fromScale(0.16, 0.48))
		styleAction("HideUseDecoy", Color3.fromRGB(47, 103, 128))
	end
end

local function updateCamera()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	if
		currentState == "Eliminated"
		or currentState == "Spectating"
		or currentState == "Escaped"
	then
		local map = workspace:FindFirstChild("LeMorneStormResort")
		local spectatorCamera = if map then map:FindFirstChild("SpectatorCamera", true) else nil
		if spectatorCamera ~= nil and spectatorCamera:IsA("BasePart") then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = spectatorCamera.CFrame
		end
	else
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid ~= nil then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
		end
	end
end

local objectives = {
	Lobby = "WAITING FOR SURVIVORS",
	Prepare = "HIDE BEFORE IT HEARS YOU",
	Hunt = "STAY QUIET. LISTEN FOR THE LISTENER.",
	Relocation = "MOVE. YOUR HIDING PLACE IS GETTING HOT.",
	Extraction = "GET OUT NOW — REACH THE ARRIVAL GATE",
	Results = "THE STORM REMEMBERS",
}

local function updateRoundHud()
	local remaining = math.max(0, math.ceil(phaseDeadline - workspace:GetServerTimeNow()))
	phaseLabel.Text = `HIDE!  •  {string.upper(currentPhase)}  {remaining}`
	objectiveLabel.Text = objectives[currentPhase] or "SURVIVE"
end

task.spawn(function()
	while true do
		updateRoundHud()
		task.wait(0.25)
	end
end)

local function applySnapshot(snapshot: any)
	if type(snapshot) == "table" and type(snapshot.phase) == "string" then
		currentPhase = snapshot.phase
		phaseDeadline = if type(snapshot.deadline) == "number" then snapshot.deadline else 0
		if currentPhase == "Prepare" then
			showToast("HIDE BEFORE IT HEARS YOU", 3)
		elseif currentPhase == "Extraction" then
			showToast("GET OUT NOW", 3)
		end
		updateDecoyBinding()
	end
	if
		type(snapshot) == "table"
		and type(snapshot.state) == "string"
		and (
			snapshot.playerId == nil
			or tostring(snapshot.playerId) == tostring(Players.LocalPlayer.UserId)
		)
	then
		currentState = snapshot.state
		if currentState ~= "Hiding" then
			silencePanel.Visible = false
		end
		updateDecoyBinding()
		updateCamera()
	end
	if type(snapshot) == "table" and type(snapshot.silence) == "table" then
		local silence = snapshot.silence
		local risk = math.clamp(tonumber(silence.risk) or 0, 0, 1)
		silencePanel.Visible = true
		silenceLabel.Text =
			`SHARED SILENCE  •  {string.upper(tostring(silence.state))}  •  {silence.occupancy}/{silence.capacity}`
		meterFill.Size = UDim2.fromScale(risk, 1)
		meterFill.BackgroundColor3 = if risk >= 0.85
			then Color3.fromRGB(224, 53, 47)
			elseif risk >= 0.58 then Color3.fromRGB(230, 135, 38)
			elseif risk >= 0.35 then Color3.fromRGB(229, 197, 62)
			else Color3.fromRGB(68, 196, 135)
	end
	if type(snapshot) == "table" and snapshot.forceExtraction == true then
		showToast("THE RESORT IS COMPROMISED — GET OUT NOW", 3.5)
	end
	if type(snapshot) == "table" and snapshot.entryRequest ~= nil then
		bindEntryRequest(snapshot.entryRequest)
	elseif type(snapshot) == "table" and snapshot.clearEntryRequest == true then
		clearEntryRequest()
	elseif type(snapshot) == "table" and snapshot.contextAction ~= nil then
		bindContext(snapshot.contextAction)
	elseif type(snapshot) == "table" and snapshot.clearContext == true then
		unbindContext()
	end
end

stateSnapshot.OnClientEvent:Connect(applySnapshot)

task.defer(function()
	local ok, snapshot = pcall(function()
		return getStateSnapshot:InvokeServer()
	end)
	if ok and type(snapshot) == "table" then
		applySnapshot(snapshot)
	else
		warn("[HIDE] initial state snapshot unavailable")
	end
end)

actionResult.OnClientEvent:Connect(function(response)
	if type(response) ~= "table" then
		return
	end
	if response.ok ~= true then
		warn(`[HIDE] action refused: {tostring(response.error)}`)
		showToast(tostring(response.error or "ACTION REFUSED"), 2)
	elseif type(response.result) == "table" and response.result.status == "Used" then
		ContextActionService:UnbindAction("HideUseDecoy")
		showToast("DECOY THROWN — MOVE NOW", 2)
	end
end)
