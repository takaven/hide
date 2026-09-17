--!strict

local PowerObjectiveService = {}
PowerObjectiveService.__index = PowerObjectiveService

local function setLights(root: Model, state: string)
	root:SetAttribute("PowerState", state)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("Light") then
			local emergency = descendant.Parent ~= nil
				and string.find(descendant.Parent.Name, "Emergency") ~= nil
			descendant.Enabled = state == "Stable" or (state == "Emergency" and emergency)
			descendant.Brightness = if state == "Emergency" and emergency then 2.4 else 1.5
		elseif descendant:IsA("BasePart") and descendant.Name == "HouseLight" then
			descendant.Transparency = if state == "Stable" then 0 else 0.82
		elseif descendant:IsA("BasePart") and descendant.Name == "EmergencyLight" then
			descendant.Transparency = if state == "Blackout" then 0.72 else 0
		end
	end
end

function PowerObjectiveService.new(dependencies: any)
	local self = setmetatable({
		_config = dependencies.Config,
		_objective = dependencies.Objective,
		_round = dependencies.Round,
		_playerStates = dependencies.PlayerStates,
		_noise = dependencies.Noise,
		_analytics = dependencies.Analytics,
		_remotes = dependencies.Remotes,
		_audio = dependencies.Audio,
		_root = dependencies.WorldRoot,
		_lastPhase = "Lobby",
	}, PowerObjectiveService)
	local panel = dependencies.WorldRoot:FindFirstChild("FusePanel", true)
	if panel ~= nil and panel:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RestorePowerPrompt"
		prompt.ActionText = "RESET FUSE"
		prompt.ObjectText = "EMERGENCY POWER"
		prompt.HoldDuration = dependencies.Config.Fuse.InteractionDuration
		prompt.MaxActivationDistance = dependencies.Config.Fuse.MaxDistance
		prompt.RequiresLineOfSight = true
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.Enabled = false
		prompt.Parent = panel
		prompt.Triggered:Connect(function(player: Player)
			self:_complete(player, panel)
		end)
		self._prompt = prompt
		self._panel = panel
	end
	setLights(dependencies.WorldRoot, "Stable")
	return self
end

function PowerObjectiveService:_broadcast(state: string, playerId: string?)
	self._remotes.StateSnapshot:FireAllClients({ powerState = state, fusePlayerId = playerId })
end

function PowerObjectiveService:_complete(player: Player, panel: BasePart)
	local playerId = tostring(player.UserId)
	local state = self._playerStates:Get(playerId)
	if state ~= "Active" and state ~= "Rescued" then
		return
	end
	local character = player.Character
	if
		character == nil
		or (character:GetPivot().Position - panel.Position).Magnitude
			> self._config.Fuse.MaxDistance
	then
		return
	end
	local result = self._objective:Complete(playerId, workspace:GetServerTimeNow())
	if result == nil then
		return
	end
	if self._prompt ~= nil then
		self._prompt.Enabled = false
	end
	setLights(self._root, "Emergency")
	self._noise:Add({
		category = "Fuse",
		magnitude = result.noiseMagnitude,
		origin = panel.Position,
		sourcePlayerId = playerId,
		sourceId = "fuse-panel",
		hunterRelevant = true,
	}, workspace:GetServerTimeNow())
	self._analytics:Emit("fuse_restored", { playerId = playerId }, workspace:GetServerTimeNow())
	if self._audio ~= nil then
		self._audio:Play("FuseReset", panel)
	end
	self:_broadcast("Emergency", playerId)
end

function PowerObjectiveService:Tick(now: number)
	local phase = self._round:GetState()
	if phase == "Relocation" and self._lastPhase ~= "Relocation" then
		if self._objective:BeginBlackout() then
			setLights(self._root, "Blackout")
			if self._prompt ~= nil then
				self._prompt.Enabled = true
			end
			self._analytics:Emit("blackout_started", {}, now)
			if self._audio ~= nil then
				self._audio:Play("Blackout", self._panel)
			end
			self:_broadcast("Blackout", nil)
		end
	end
	self._lastPhase = phase
end

function PowerObjectiveService:ResetRound()
	self._objective:ResetRound()
	self._lastPhase = "Prepare"
	if self._prompt ~= nil then
		self._prompt.Enabled = false
	end
	setLights(self._root, "Stable")
	self:_broadcast("Stable", nil)
end

return PowerObjectiveService
