--!strict

local Players = game:GetService("Players")

local RescueInteractionService = {}
RescueInteractionService.__index = RescueInteractionService

function RescueInteractionService.new(config: any, playerStates: any, rescue: any, gateway: any)
	return setmetatable({
		_config = config,
		_playerStates = playerStates,
		_rescue = rescue,
		_gateway = gateway,
		_prompts = {},
		_attemptByRescuer = {},
		_counter = 0,
	}, RescueInteractionService)
end

function RescueInteractionService:_requestId(): string
	self._counter += 1
	return `rescue-prompt-{math.floor(workspace:GetServerTimeNow() * 1000)}-{self._counter}`
end

function RescueInteractionService:_remove(playerId: string)
	local prompt = self._prompts[playerId]
	if prompt ~= nil then
		prompt:Destroy()
		self._prompts[playerId] = nil
	end
end

function RescueInteractionService:_attach(target: Player)
	local playerId = tostring(target.UserId)
	if self._prompts[playerId] ~= nil then
		return
	end
	local character = target.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RescuePrompt"
	prompt.ActionText = "RESCUE"
	prompt.ObjectText = target.DisplayName
	prompt.HoldDuration = self._config.Rescue.Duration
	prompt.MaxActivationDistance = self._config.Rescue.MaxDistance
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.R
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.Parent = root
	self._prompts[playerId] = prompt
	prompt.PromptButtonHoldBegan:Connect(function(rescuer)
		local result = self._gateway:Submit(rescuer, {
			action = "StartRescue",
			requestId = self:_requestId(),
			targetPlayerId = playerId,
		})
		if result ~= nil then
			self._attemptByRescuer[tostring(rescuer.UserId)] = result.id
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(rescuer)
		local rescuerId = tostring(rescuer.UserId)
		local attemptId = self._attemptByRescuer[rescuerId]
		if attemptId ~= nil then
			self._rescue:Cancel(
				attemptId,
				rescuerId,
				"rescue input abandoned",
				workspace:GetServerTimeNow()
			)
			self._attemptByRescuer[rescuerId] = nil
		end
	end)
	prompt.Triggered:Connect(function(rescuer)
		local rescuerId = tostring(rescuer.UserId)
		local attemptId = self._attemptByRescuer[rescuerId]
		if attemptId ~= nil then
			self._gateway:Submit(rescuer, {
				action = "CompleteRescue",
				requestId = self:_requestId(),
				rescueId = attemptId,
			})
			self._attemptByRescuer[rescuerId] = nil
		end
	end)
end

function RescueInteractionService:Tick()
	for _, player in ipairs(Players:GetPlayers()) do
		local playerId = tostring(player.UserId)
		if self._playerStates:Get(playerId) == "Downed" then
			self:_attach(player)
		else
			self:_remove(playerId)
		end
	end
end

function RescueInteractionService:ResetRound()
	for playerId in pairs(self._prompts) do
		self:_remove(playerId)
	end
	table.clear(self._attemptByRescuer)
end

return RescueInteractionService
