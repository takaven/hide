--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StudioCaptureRunnerService = {}
StudioCaptureRunnerService.__index = StudioCaptureRunnerService

local SHELTER_ID = "suite-wardrobe"

local function rootPart(model: Model?): BasePart?
	local root = if model then model:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

function StudioCaptureRunnerService.new(dependencies: any)
	return setmetatable({
		Config = dependencies.Config,
		WorldRoot = dependencies.WorldRoot,
		World = dependencies.World,
		PlayerStates = dependencies.PlayerStates,
		Hiding = dependencies.Hiding,
		Presentation = dependencies.Presentation,
		Hunter = dependencies.Hunter,
		Power = dependencies.Power,
		Audio = dependencies.Audio,
		Remotes = dependencies.Remotes,
		Event = nil,
	}, StudioCaptureRunnerService)
end

function StudioCaptureRunnerService:_snapshotBreath(player: Player, stopActive: boolean?)
	local spot = self.Hiding:GetSpot(SHELTER_ID)
	if spot == nil then
		return
	end
	local level = self.Hiding:GetBreath(SHELTER_ID)
	local state = if level >= self.Config.Breath.CriticalThreshold
		then "Critical"
		elseif level >= self.Config.Breath.WarningThreshold then "Warning"
		else "Calm"
	self.Audio:SetBreathPressure(if stopActive then math.max(level, 0.86) else level)
	self.Remotes.StateSnapshot:FireClient(player, {
		breath = {
			state = state,
			level = level,
			rate = self.Config.Breath.BaseRatePerSecond,
			occupancy = self.Hiding:GetOccupancy(SHELTER_ID),
			capacity = spot.capacity,
			stopActive = stopActive == true,
			stopRemaining = if stopActive then self.Config.ListenerStop.DefaultDuration else 0,
		},
	})
end

function StudioCaptureRunnerService:_resetPlayer(player: Player)
	local playerId = tostring(player.UserId)
	local hidingId = self.Hiding:GetPlayerSpot(playerId)
	if hidingId ~= nil then
		self.Hiding:Exit(playerId, hidingId, workspace:GetServerTimeNow())
		self.Presentation:Reveal(player, hidingId)
	end
	self.PlayerStates:ResetForRound({ playerId }, workspace:GetServerTimeNow())
	self.Audio:SetBreathPressure(0)
	self.Remotes.StateSnapshot:FireClient(player, {
		state = "Active",
		clearContext = true,
		clearPeek = true,
	})
end

function StudioCaptureRunnerService:_placePlayer(player: Player, position: Vector3, lookAt: Vector3)
	local character = player.Character
	if character ~= nil then
		character:PivotTo(CFrame.lookAt(position, lookAt))
	end
end

function StudioCaptureRunnerService:_placeListener(position: Vector3, lookAt: Vector3)
	local listener = self.WorldRoot:FindFirstChild("TheListener", true)
	if listener ~= nil and listener:IsA("Model") then
		listener:PivotTo(CFrame.lookAt(position, lookAt))
		local root = rootPart(listener)
		if root ~= nil then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

function StudioCaptureRunnerService:_enterShelter(player: Player)
	self:_resetPlayer(player)
	local playerId = tostring(player.UserId)
	local now = workspace:GetServerTimeNow()
	local result = self.Hiding:RequestEntry(playerId, SHELTER_ID, now)
	if result == nil or result.status ~= "Entered" then
		return
	end
	self.PlayerStates:Transition(playerId, "Hiding", "studio capture shelter", now)
	self.Presentation:Hide(player, SHELTER_ID)
	-- Advance only the isolated capture shelter to a visible warning level; production
	-- timing and configuration remain untouched.
	self.Hiding:Tick(SHELTER_ID, 42, now, 0)
	local record = self.World.Hiding[SHELTER_ID]
	self.Remotes.StateSnapshot:FireClient(player, {
		state = "Hiding",
		hidingCamera = if record then { cframe = record.hidingCameraCFrame } else nil,
		contextAction = {
			action = "VolunteerOut",
			targetField = "hidingId",
			targetId = SHELTER_ID,
			label = "VOLUNTEER OUT",
		},
	})
	self:_snapshotBreath(player, false)
end

function StudioCaptureRunnerService:_startStop(player: Player)
	local spot = self.Hiding:GetSpot(SHELTER_ID)
	if spot == nil then
		return
	end
	local listener = self.WorldRoot:FindFirstChild("TheListener", true)
	if listener == nil or not listener:IsA("Model") then
		return
	end
	self.Hunter:ResetRound()
	self:_placeListener(spot.approachPosition + Vector3.new(0, 2.5, 11), spot.approachPosition)
	local root = rootPart(listener)
	if root ~= nil then
		self.Hunter:_tryStartStop(root, workspace:GetServerTimeNow())
		self:_snapshotBreath(player, true)
	end
end

function StudioCaptureRunnerService:_exitShelter(player: Player)
	local playerId = tostring(player.UserId)
	self.Hiding:Exit(playerId, SHELTER_ID, workspace:GetServerTimeNow())
	self.Presentation:Reveal(player, SHELTER_ID)
	self.PlayerStates:Transition(
		playerId,
		"Active",
		"studio capture exit",
		workspace:GetServerTimeNow()
	)
	self.Audio:SetBreathPressure(0)
	self.Remotes.StateSnapshot:FireClient(player, {
		state = "Active",
		clearContext = true,
		clearPeek = true,
	})
end

function StudioCaptureRunnerService:_startChase(player: Player)
	self:_resetPlayer(player)
	local start = Vector3.new(0, 3.5, -7)
	local destination = Vector3.new(0, 3.5, 35)
	self:_placePlayer(player, start, destination)
	self.Hunter:ResetRound()
	self:_placeListener(Vector3.new(0, 3.5, -31), start)
	local humanoid = if player.Character
		then player.Character:FindFirstChildOfClass("Humanoid")
		else nil
	if humanoid ~= nil then
		humanoid:MoveTo(destination)
	end
end

function StudioCaptureRunnerService:_handle(player: Player, command: string)
	if command == "Prepare" then
		self:_resetPlayer(player)
		self.Power:ResetRound()
		self.Hunter:ResetRound()
		self:_placePlayer(player, Vector3.new(0, 3.5, 48), Vector3.new(0, 3.5, 30))
	elseif command == "Lobby" then
		self:_placePlayer(player, Vector3.new(9, 3.5, 45), Vector3.new(-7, 3.5, 30))
	elseif command == "Corridor" then
		self:_placePlayer(player, Vector3.new(-48, 3.5, 14), Vector3.new(-69, 3.5, 9))
	elseif command == "EnterShelter" then
		self:_enterShelter(player)
	elseif command == "StartStop" then
		self:_startStop(player)
	elseif command == "ExitShelter" then
		self:_exitShelter(player)
	elseif command == "Pool" then
		self:_placePlayer(player, Vector3.new(24, 3.5, 55), Vector3.new(56, 2, 54))
	elseif command == "Blackout" then
		self.Power:StudioBeginBlackout()
	elseif command == "Fuse" then
		local panel = self.WorldRoot:FindFirstChild("FusePanel", true)
		if panel ~= nil and panel:IsA("BasePart") then
			self:_placePlayer(player, panel.Position + Vector3.new(0, 0, 5), panel.Position)
			self.Power:StudioCompleteFuse(player)
		end
	elseif command == "Chase" then
		self:_startChase(player)
	elseif command == "Finish" then
		self.Hunter:ResetRound()
		self:_resetPlayer(player)
	end
end

function StudioCaptureRunnerService:Start(): boolean
	if not RunService:IsStudio() or workspace:GetAttribute("EnableQACaptureRunner") ~= true then
		return false
	end
	local folder = ReplicatedStorage:WaitForChild("HideRemotes")
	local event = Instance.new("RemoteEvent")
	event.Name = "QACaptureControl"
	event.OnServerEvent:Connect(function(player: Player, command: any)
		if typeof(command) == "string" and player == Players:GetPlayers()[1] then
			self:_handle(player, command)
		end
	end)
	event.Parent = folder
	self.Event = event
	workspace:SetAttribute("QACaptureServerReady", true)
	return true
end

return StudioCaptureRunnerService
