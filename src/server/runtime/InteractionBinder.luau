--!strict

local InteractionBinder = {}
InteractionBinder.__index = InteractionBinder

local function promptParent(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		local primary = instance.PrimaryPart
		if primary ~= nil then
			return primary
		end
		local descendant = instance:FindFirstChildWhichIsA("BasePart", true)
		return descendant
	end
	return nil
end

function InteractionBinder.new(config: any, world: any, gateway: any)
	return setmetatable(
		{ _config = config, _world = world, _gateway = gateway, _counter = 0 },
		InteractionBinder
	)
end

function InteractionBinder:_requestId(): string
	self._counter += 1
	return `prompt-{math.floor(workspace:GetServerTimeNow() * 1000)}-{self._counter}`
end

function InteractionBinder:_bind(
	instance: Instance,
	name: string,
	label: string,
	callback: (Player) -> ()
)
	local parent = promptParent(instance)
	if parent == nil then
		warn(`[HIDE] cannot attach prompt to {instance:GetFullName()}`)
		return
	end
	local existing = parent:FindFirstChild(name)
	local prompt: ProximityPrompt
	if existing ~= nil then
		assert(
			existing:IsA("ProximityPrompt"),
			`{existing:GetFullName()} must be a ProximityPrompt`
		)
		prompt = existing
	else
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = name
		prompt.Parent = parent
	end
	prompt.ActionText = label
	prompt.ObjectText = "HIDE!"
	prompt.MaxActivationDistance = self._config.Interaction.MaxDistance
	prompt.RequiresLineOfSight = true
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Triggered:Connect(callback)
end

function InteractionBinder:BindAll()
	for hidingId, record in pairs(self._world.Hiding) do
		local targetId = hidingId
		self:_bind(record.instance, "HideEntryPrompt", "HIDE", function(player)
			self._gateway:Submit(player, {
				action = "RequestHideEntry",
				requestId = self:_requestId(),
				hidingId = targetId,
			})
		end)
	end
	for doorId, record in pairs(self._world.Doors) do
		local targetId = doorId
		self:_bind(record.instance, "HoldDoorPrompt", "HOLD DOOR", function(player)
			self._gateway:Submit(player, {
				action = "HoldDoor",
				requestId = self:_requestId(),
				doorId = targetId,
			})
		end)
	end
	for extractionId, record in pairs(self._world.Extractions) do
		local targetId = extractionId
		self:_bind(record.instance, "ExtractionPrompt", "ESCAPE", function(player)
			self._gateway:Submit(player, {
				action = "Escape",
				requestId = self:_requestId(),
				extractionId = targetId,
			})
		end)
	end
end

return InteractionBinder
