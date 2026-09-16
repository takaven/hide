--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Protocol = require(ReplicatedStorage.Hide.Shared.RemoteProtocol)
local Config = require(ReplicatedStorage.Hide.Shared.Config)
local remotesFolder = ReplicatedStorage:WaitForChild("HideRemotes")
local actionRequest = remotesFolder:WaitForChild(Protocol.RequestEventName) :: RemoteEvent
local actionResult = remotesFolder:WaitForChild(Protocol.ResultEventName) :: RemoteEvent
local stateSnapshot = remotesFolder:WaitForChild(Protocol.SnapshotEventName) :: RemoteEvent
local getStateSnapshot = remotesFolder:WaitForChild(Protocol.SnapshotFunctionName) :: RemoteFunction
local SuspicionTier = require(ReplicatedStorage.Hide.Shared.SuspicionTier)

local currentContext: any? = nil
local requestCounter = 0
local entryRequestGeneration = 0
local entryDecisionActive = false
local currentPhase = "Lobby"
local phaseDeadline = 0
local currentState = "Spectating"
local peekEnabled = false
local peekCFrame: CFrame? = nil
local spectatorIndex = 0
local activeExtractionId: string? = nil
local bindContext: (any) -> ()
local nextRequestId: () -> string
local onboardingSeen: { [string]: boolean } = {}

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
silencePanel.Size = UDim2.new(0.76, 0, 0, 82)
silencePanel.BackgroundColor3 = Color3.fromRGB(12, 24, 27)
silencePanel.BackgroundTransparency = 0.08
silencePanel.Visible = false
silencePanel.Parent = hud
local silenceConstraint = Instance.new("UISizeConstraint")
silenceConstraint.MaxSize = Vector2.new(620, 90)
silenceConstraint.MinSize = Vector2.new(280, 76)
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
silenceLabel.Text = "SHARED SILENCE  •  QUIET"
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
local suspicionLabel = Instance.new("TextLabel")
suspicionLabel.Name = "Suspicion"
suspicionLabel.BackgroundTransparency = 1
suspicionLabel.Position = UDim2.fromOffset(14, 51)
suspicionLabel.Size = UDim2.new(1, -28, 0, 22)
suspicionLabel.Font = Enum.Font.GothamMedium
suspicionLabel.TextColor3 = Color3.fromRGB(138, 213, 204)
suspicionLabel.TextSize = 14
suspicionLabel.TextXAlignment = Enum.TextXAlignment.Left
suspicionLabel.Text = "SUSPICION  •  SAFE"
suspicionLabel.Parent = silencePanel

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

local resultsPanel = Instance.new("Frame")
resultsPanel.Name = "ResultsActions"
resultsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
resultsPanel.Position = UDim2.fromScale(0.5, 0.55)
resultsPanel.Size = UDim2.new(0.82, 0, 0, 210)
resultsPanel.BackgroundColor3 = Color3.fromRGB(12, 24, 27)
resultsPanel.BackgroundTransparency = 0.05
resultsPanel.Visible = false
resultsPanel.Parent = hud
local resultsConstraint = Instance.new("UISizeConstraint")
resultsConstraint.MaxSize = Vector2.new(560, 230)
resultsConstraint.MinSize = Vector2.new(290, 190)
resultsConstraint.Parent = resultsPanel
local resultsCorner = Instance.new("UICorner")
resultsCorner.CornerRadius = UDim.new(0, 16)
resultsCorner.Parent = resultsPanel
local resultsSummary = Instance.new("TextLabel")
resultsSummary.BackgroundTransparency = 1
resultsSummary.Position = UDim2.fromOffset(16, 12)
resultsSummary.Size = UDim2.new(1, -32, 0, 92)
resultsSummary.Font = Enum.Font.GothamBold
resultsSummary.TextColor3 = Color3.fromRGB(241, 233, 211)
resultsSummary.TextSize = 18
resultsSummary.TextWrapped = true
resultsSummary.Text = "MOMENT OF THE ROUND\nTHE STORM REMEMBERS"
resultsSummary.Parent = resultsPanel

local function makeResultsButton(text: string, position: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0.44, 0, 0, 64)
	button.Position = position
	button.BackgroundColor3 = color
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 17
	button.TextWrapped = true
	button.Text = text
	button.Parent = resultsPanel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 13)
	corner.Parent = button
	return button
end

local playAgainButton =
	makeResultsButton("PLAY AGAIN", UDim2.fromScale(0.04, 0.62), Color3.fromRGB(216, 111, 48))
local inviteButton = makeResultsButton(
	"INVITE A FRIEND\nBRING SOMEONE YOU TRUST",
	UDim2.fromScale(0.52, 0.62),
	Color3.fromRGB(47, 103, 128)
)

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

local function recordOnboarding(stepId: string, message: string)
	if onboardingSeen[stepId] then
		return
	end
	onboardingSeen[stepId] = true
	showToast(message, 3)
	actionRequest:FireServer({
		action = "OnboardingStep",
		requestId = nextRequestId(),
		stepId = stepId,
	})
end

playAgainButton.Activated:Connect(function()
	actionRequest:FireServer({ action = "RequestRematch", requestId = nextRequestId() })
	playAgainButton.Text = "READY"
end)

inviteButton.Activated:Connect(function()
	actionRequest:FireServer({ action = "InviteFriend", requestId = nextRequestId() })
	task.spawn(function()
		local ok, canInvite =
			pcall(SocialService.CanSendGameInviteAsync, SocialService, Players.LocalPlayer)
		if ok and canInvite then
			local prompted =
				pcall(SocialService.PromptGameInvite, SocialService, Players.LocalPlayer)
			if not prompted then
				showToast("INVITES ARE UNAVAILABLE ON THIS DEVICE", 2)
			end
		else
			showToast("INVITES ARE UNAVAILABLE ON THIS DEVICE", 2)
		end
	end)
end)

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

nextRequestId = function(): string
	requestCounter += 1
	return `{math.floor(workspace:GetServerTimeNow() * 1000)}-{requestCounter}`
end

local function unbindContext()
	ContextActionService:UnbindAction("HidePrimaryAction")
	currentContext = nil
end

local function setPeek(enabled: boolean)
	if currentState ~= "Hiding" or currentContext == nil then
		return
	end
	actionRequest:FireServer({
		action = "PeekHiding",
		requestId = nextRequestId(),
		hidingId = currentContext.targetId,
		enabled = enabled,
	})
end

local function unbindPeek()
	ContextActionService:UnbindAction("HidePeek")
	peekEnabled = false
	peekCFrame = nil
end

local function bindPeek(hidingId: string)
	ContextActionService:UnbindAction("HidePeek")
	if entryDecisionActive then
		return
	end
	ContextActionService:BindAction("HidePeek", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			setPeek(not peekEnabled)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.V, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("HidePeek", "PEEK")
	ContextActionService:SetPosition("HidePeek", UDim2.fromScale(0.66, 0.68))
	styleAction("HidePeek", Color3.fromRGB(47, 103, 128))
	if currentContext == nil then
		currentContext = {
			action = "ExitHiding",
			targetField = "hidingId",
			targetId = hidingId,
			label = "EXIT",
		}
	end
end

local function clearEntryRequest(restoreHidingActions: boolean?)
	entryRequestGeneration += 1
	entryDecisionActive = false
	ContextActionService:UnbindAction("HideAcceptEntry")
	ContextActionService:UnbindAction("HideRefuseEntry")
	if restoreHidingActions == true and currentState == "Hiding" and currentContext ~= nil then
		task.defer(function()
			bindContext(currentContext)
			bindPeek(currentContext.targetId)
		end)
	end
end

local function bindEntryRequest(entryRequest: any)
	clearEntryRequest(false)
	entryDecisionActive = true
	ContextActionService:UnbindAction("HidePrimaryAction")
	ContextActionService:UnbindAction("HidePeek")
	local generation = entryRequestGeneration
	local function respond(accepted: boolean)
		actionRequest:FireServer({
			action = "ResolveEntryRequest",
			requestId = nextRequestId(),
			entryRequestId = entryRequest.id,
			accepted = accepted,
		})
		clearEntryRequest(true)
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
			clearEntryRequest(true)
		end
	end)
end

bindContext = function(context: any)
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
	if currentState == "Hiding" and peekEnabled and peekCFrame ~= nil then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = peekCFrame
	elseif
		currentState == "Eliminated"
		or currentState == "Spectating"
		or currentState == "Escaped"
	then
		local candidates = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if
				player ~= Players.LocalPlayer
				and character ~= nil
				and (character:FindFirstChild("Head") == nil or (character.Head :: BasePart).Transparency < 1)
				and humanoid ~= nil
				and humanoid.Health > 0
			then
				table.insert(candidates, humanoid)
			end
		end
		if #candidates > 0 then
			spectatorIndex = (spectatorIndex % #candidates) + 1
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = candidates[spectatorIndex]
		else
			local map = workspace:FindFirstChild("LeMorneStormResort")
			local spectatorCamera = if map then map:FindFirstChild("SpectatorCamera", true) else nil
			if spectatorCamera ~= nil and spectatorCamera:IsA("BasePart") then
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = spectatorCamera.CFrame
			end
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

local function updateSpectatorBinding()
	ContextActionService:UnbindAction("HideSpectateNext")
	if
		currentState == "Eliminated"
		or currentState == "Spectating"
		or currentState == "Escaped"
	then
		ContextActionService:BindAction("HideSpectateNext", function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				updateCamera()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, true, Enum.KeyCode.C, Enum.KeyCode.ButtonR1)
		ContextActionService:SetTitle("HideSpectateNext", "NEXT")
		ContextActionService:SetPosition("HideSpectateNext", UDim2.fromScale(0.82, 0.68))
		styleAction("HideSpectateNext", Color3.fromRGB(79, 83, 91))
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
	if currentPhase == "Extraction" and activeExtractionId ~= nil then
		objectiveLabel.Text = if activeExtractionId == "service-coast-gate"
			then "GET OUT NOW — SERVICE COAST EXIT"
			else "GET OUT NOW — ARRIVAL EVACUATION GATE"
	else
		objectiveLabel.Text = objectives[currentPhase] or "SURVIVE"
	end
end

task.spawn(function()
	while true do
		updateRoundHud()
		task.wait(0.25)
	end
end)

local function applySnapshot(snapshot: any)
	if type(snapshot) == "table" and type(snapshot.phase) == "string" then
		local previousPhase = currentPhase
		currentPhase = snapshot.phase
		phaseDeadline = if type(snapshot.deadline) == "number" then snapshot.deadline else 0
		if currentPhase == "Prepare" then
			recordOnboarding("spawn_hide", "HIDE BEFORE IT HEARS YOU")
		elseif currentPhase == "Extraction" then
			recordOnboarding("extraction", "GET OUT NOW")
		end
		resultsPanel.Visible = currentPhase == "Results"
		if previousPhase ~= "Results" and currentPhase == "Results" then
			playAgainButton.Text = "PLAY AGAIN"
		end
		updateDecoyBinding()
	end
	if type(snapshot) == "table" and type(snapshot.activeExtractionId) == "string" then
		activeExtractionId = snapshot.activeExtractionId
		updateRoundHud()
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
		if currentState == "Hiding" then
			recordOnboarding("first_hiding", "MORE PEOPLE = MORE NOISE")
		end
		if currentState ~= "Hiding" then
			silencePanel.Visible = false
			unbindPeek()
		end
		updateDecoyBinding()
		updateCamera()
		updateSpectatorBinding()
	end
	if type(snapshot) == "table" and type(snapshot.silence) == "table" then
		local silence = snapshot.silence
		local risk = math.clamp(tonumber(silence.risk) or 0, 0, 1)
		silencePanel.Visible = true
		silenceLabel.Text =
			`NOISE  •  {string.upper(tostring(silence.state))}  •  {silence.occupancy}/{silence.capacity}`
		meterFill.Size = UDim2.fromScale(risk, 1)
		meterFill.BackgroundColor3 = if risk >= 0.85
			then Color3.fromRGB(224, 53, 47)
			elseif risk >= 0.58 then Color3.fromRGB(230, 135, 38)
			elseif risk >= 0.35 then Color3.fromRGB(229, 197, 62)
			else Color3.fromRGB(68, 196, 135)
		local heat = math.clamp(tonumber(silence.heat) or 0, 0, 1)
		local tier = SuspicionTier.fromValues(Config, heat, silence.exposed == true)
		if tier == "HOT" or tier == "EXPOSED" then
			recordOnboarding("hot_spot", "HOT SPOTS GET CHECKED")
		end
		local suspicion = if tier == "EXPOSED"
			then "EXPOSED — IT CAN FIND YOU"
			elseif tier == "HOT" then "HOT — MOVE SOON"
			elseif tier == "WARM" then "WARM — IT IS LEARNING"
			else "SAFE"
		suspicionLabel.Text = `SUSPICION  •  {suspicion}`
		suspicionLabel.TextColor3 = if silence.exposed == true
			then Color3.fromRGB(255, 92, 76)
			elseif heat >= Config.Hiding.InspectionHeatThreshold then Color3.fromRGB(
				239,
				147,
				52
			)
			elseif heat >= Config.Hiding.WarmHeatThreshold then Color3.fromRGB(229, 197, 62)
			else Color3.fromRGB(138, 213, 204)
	end
	if type(snapshot) == "table" and snapshot.forceExtraction == true then
		showToast("THE RESORT IS COMPROMISED — GET OUT NOW", 3.5)
	end
	if type(snapshot) == "table" and snapshot.entryRequest ~= nil then
		recordOnboarding("let_them_in", "LET THEM IN?")
		bindEntryRequest(snapshot.entryRequest)
	elseif type(snapshot) == "table" and snapshot.clearEntryRequest == true then
		clearEntryRequest(true)
	elseif type(snapshot) == "table" and snapshot.contextAction ~= nil then
		bindContext(snapshot.contextAction)
	elseif type(snapshot) == "table" and snapshot.clearContext == true then
		unbindContext()
	end
	if type(snapshot) == "table" and snapshot.peekAction ~= nil then
		recordOnboarding("peek", "PEEK — BUT IT MAKES NOISE")
		if not entryDecisionActive then
			bindPeek(snapshot.peekAction.hidingId)
		end
	elseif type(snapshot) == "table" and snapshot.clearPeek == true then
		unbindPeek()
		updateCamera()
	end
	if type(snapshot) == "table" and type(snapshot.peek) == "table" then
		peekEnabled = snapshot.peek.enabled == true
		peekCFrame = if typeof(snapshot.peek.cframe) == "CFrame" then snapshot.peek.cframe else nil
		ContextActionService:SetTitle("HidePeek", if peekEnabled then "STOP" else "PEEK")
		updateCamera()
	end
	if type(snapshot) == "table" and type(snapshot.movieMoment) == "table" then
		showToast(tostring(snapshot.movieMoment.message or "THE STORM SHIFTS"), 3)
	end
	if type(snapshot) == "table" and snapshot.state == "Downed" and snapshot.playerId ~= nil then
		recordOnboarding("rescue", "RESCUE THEM BEFORE IT RETURNS")
	end
	if type(snapshot) == "table" and type(snapshot.results) == "table" then
		local moment = snapshot.results.moment
		local summary = if type(moment) == "table" and type(moment.label) == "string"
			then moment.label
			else "THE STORM REMEMBERS"
		local awardLines = {}
		if type(snapshot.results.awards) == "table" then
			for index, award in ipairs(snapshot.results.awards) do
				if index > 2 then
					break
				end
				if type(award) == "table" and type(award.title) == "string" then
					table.insert(awardLines, award.title)
				end
			end
		end
		resultsSummary.Text = `MOMENT OF THE ROUND\n{summary}{if #awardLines > 0
			then "\n" .. table.concat(awardLines, "  •  ")
			else ""}`
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
