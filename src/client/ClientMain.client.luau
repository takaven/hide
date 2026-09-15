--!strict

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Hide.Shared.RemoteProtocol)
local remotesFolder = ReplicatedStorage:WaitForChild("HideRemotes")
local actionRequest = remotesFolder:WaitForChild(Protocol.RequestEventName) :: RemoteEvent
local actionResult = remotesFolder:WaitForChild(Protocol.ResultEventName) :: RemoteEvent
local stateSnapshot = remotesFolder:WaitForChild(Protocol.SnapshotEventName) :: RemoteEvent

local currentContext: any? = nil
local requestCounter = 0
local entryRequestGeneration = 0

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
	ContextActionService:SetPosition("HideAcceptEntry", UDim2.fromScale(0.66, 0.68))

	ContextActionService:BindAction("HideRefuseEntry", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			respond(false)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.N, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("HideRefuseEntry", "REFUSE")
	ContextActionService:SetPosition("HideRefuseEntry", UDim2.fromScale(0.84, 0.68))

	local remaining = math.max(0, (entryRequest.expiresAt or 0) - workspace:GetServerTimeNow())
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
	end, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("HidePrimaryAction", context.label or "ACT")
	ContextActionService:SetPosition("HidePrimaryAction", UDim2.fromScale(0.78, 0.72))
end

stateSnapshot.OnClientEvent:Connect(function(snapshot)
	if type(snapshot) == "table" and snapshot.entryRequest ~= nil then
		bindEntryRequest(snapshot.entryRequest)
	elseif type(snapshot) == "table" and snapshot.clearEntryRequest == true then
		clearEntryRequest()
	elseif type(snapshot) == "table" and snapshot.contextAction ~= nil then
		bindContext(snapshot.contextAction)
	elseif type(snapshot) == "table" and snapshot.clearContext == true then
		unbindContext()
	end
end)

actionResult.OnClientEvent:Connect(function(response)
	if type(response) ~= "table" then
		return
	end
	if response.ok ~= true then
		warn(`[HIDE] action refused: {tostring(response.error)}`)
	end
end)
