--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Hide.Shared.Config)
local ConfigValidator = require(ReplicatedStorage.Hide.Shared.ConfigValidator)

local Domain = ServerScriptService.Hide.domain
local Runtime = ServerScriptService.Hide.runtime

local ActionService = require(Runtime.ActionService)
local AnalyticsBus = require(Domain.AnalyticsBus)
local CaptureService = require(Runtime.CaptureService)
local CharacterPresentationService = require(Runtime.CharacterPresentationService)
local DecoySystem = require(Domain.DecoySystem)
local DoorSystem = require(Domain.DoorSystem)
local DoorPresentationService = require(Runtime.DoorPresentationService)
local ExtractionSystem = require(Domain.ExtractionSystem)
local ExtractionRuntimeService = require(Runtime.ExtractionRuntimeService)
local HidingSystem = require(Domain.HidingSystem)
local HunterService = require(Runtime.HunterService)
local InteractionBinder = require(Runtime.InteractionBinder)
local NoiseLedger = require(Domain.NoiseLedger)
local MovementNoiseService = require(Runtime.MovementNoiseService)
local PlayerStates = require(Domain.PlayerStates)
local PlayerLifecycle = require(Domain.PlayerLifecycle)
local PlayerLifecycleService = require(Runtime.PlayerLifecycleService)
local RemoteGateway = require(Runtime.RemoteGateway)
local Remotes = require(Runtime.Remotes)
local RobloxAnalyticsProvider = require(Runtime.RobloxAnalyticsProvider)
local RescueSystem = require(Domain.RescueSystem)
local RescueMonitor = require(Runtime.RescueMonitor)
local RescueInteractionService = require(Runtime.RescueInteractionService)
local RoundService = require(Runtime.RoundService)
local SilenceMonitor = require(Runtime.SilenceMonitor)
local StormPresentationService = require(Runtime.StormPresentationService)
local StudioTestOverrides = require(Runtime.StudioTestOverrides)
local WorldRegistry = require(Runtime.WorldRegistry)
local WorldBuilder = require(Runtime.WorldBuilder)

StudioTestOverrides.Apply(Config)
local configValid, configErrors = ConfigValidator.validate(Config)
assert(configValid, `invalid HIDE config: {table.concat(configErrors, "; ")}`)

local worldRoot = WorldBuilder.Build()
local storm = StormPresentationService.new(worldRoot)
storm:Start()

local remotes = Remotes.create()
local analytics = AnalyticsBus.new(RobloxAnalyticsProvider.new("mauritius-le-morne-storm-resort"))
local playerStates = PlayerStates.new()
local noise = NoiseLedger.new(Config.Noise)
local hiding = HidingSystem.new(Config)
local doors = DoorSystem.new(Config)
local rescue = RescueSystem.new(Config)
local decoys = DecoySystem.new(Config)
local extraction = ExtractionSystem.new(Config)
local world = WorldRegistry.new()

for _, issue in ipairs(world:Scan()) do
	warn(`[HIDE] world binding: {issue}`)
end

local presentation = CharacterPresentationService.new(world)
for hidingId, record in pairs(world.Hiding) do
	local ok, err =
		hiding:Register(hidingId, record.capacity, record.position, record.approachPosition)
	if not ok then
		warn(`[HIDE] hiding registration failed: {err}`)
	end
end
for doorId, record in pairs(world.Doors) do
	local ok, err = doors:Register(doorId, record.position)
	if not ok then
		warn(`[HIDE] door registration failed: {err}`)
	end
end
for extractionId, record in pairs(world.Extractions) do
	local ok, err = extraction:Register(extractionId, record.position)
	if not ok then
		warn(`[HIDE] extraction registration failed: {err}`)
	end
end

local capture = CaptureService.new(Config, playerStates, hiding, analytics, remotes, presentation)
local extractionRuntime = ExtractionRuntimeService.new(hiding, playerStates, presentation, remotes)
local round = RoundService.new(
	Config,
	playerStates,
	extraction,
	decoys,
	analytics,
	remotes,
	extractionRuntime
)
remotes.GetStateSnapshot.OnServerInvoke = function(player: Player)
	local playerId = tostring(player.UserId)
	local state = playerStates:Get(playerId) or "Spectating"
	local snapshot: any = {
		state = state,
		phase = round:GetState(),
		deadline = round:GetDeadline(),
	}
	if state == "Hiding" then
		local hidingId = hiding:GetPlayerSpot(playerId)
		if hidingId ~= nil then
			snapshot.contextAction = {
				action = "ExitHiding",
				targetField = "hidingId",
				targetId = hidingId,
				label = "EXIT",
			}
		end
	end
	return snapshot
end
local lifecycle = PlayerLifecycle.new({
	PlayerStates = playerStates,
	Hiding = hiding,
	Doors = doors,
	Rescue = rescue,
	Capture = capture,
	Presentation = presentation,
})
local lifecycleService = PlayerLifecycleService.new(lifecycle, remotes)
local rescueMonitor = RescueMonitor.new(rescue, playerStates, world, analytics)
local actionService = ActionService.new({
	Config = Config,
	Round = round,
	PlayerStates = playerStates,
	Hiding = hiding,
	Doors = doors,
	Rescue = rescue,
	Capture = capture,
	Decoys = decoys,
	Extraction = extraction,
	Noise = noise,
	Analytics = analytics,
	WorldRegistry = world,
	Remotes = remotes,
	Presentation = presentation,
})
local gateway = RemoteGateway.new(Config, remotes, actionService)
local interactions = InteractionBinder.new(Config, world, gateway)
local silence = SilenceMonitor.new(hiding, noise, analytics, remotes)
local movementNoise = MovementNoiseService.new(Config, playerStates, noise, analytics)
local doorPresentation =
	DoorPresentationService.new(world, doors, playerStates, Config.Interaction.MaxDistance)
local rescueInteractions = RescueInteractionService.new(Config, playerStates, rescue, gateway)
local hunter =
	HunterService.new(Config, world, playerStates, hiding, noise, capture, analytics, round)

local function registerPlayer(player: Player)
	playerStates:Add(tostring(player.UserId), false)
	lifecycleService:Attach(player)
	remotes.StateSnapshot:FireClient(player, {
		state = "Spectating",
		phase = round:GetState(),
		deadline = round:GetDeadline(),
	})
end

for _, player in ipairs(Players:GetPlayers()) do
	registerPlayer(player)
end
Players.PlayerAdded:Connect(registerPlayer)

for _, resetter in ipairs({
	hiding,
	doors,
	rescue,
	extraction,
	noise,
	capture,
	silence,
	presentation,
	movementNoise,
	doorPresentation,
	rescueInteractions,
}) do
	round:AddResetter(resetter)
end

gateway:Start()
interactions:BindAll()
round:Start()
local hunterActive = hunter:Start()
if not hunterActive then
	warn("[HIDE] The Listener is inactive until Phase 2 supplies one tagged hunter model")
end

Players.PlayerRemoving:Connect(function(player)
	local playerId = tostring(player.UserId)
	lifecycleService:Remove(player)
	analytics:Emit(
		"player_quit",
		{ playerId = playerId, phase = round:GetState() },
		workspace:GetServerTimeNow()
	)
	playerStates:Remove(playerId)
end)

task.spawn(function()
	local lastTick = workspace:GetServerTimeNow()
	while true do
		local now = workspace:GetServerTimeNow()
		local elapsed = math.max(0, now - lastTick)
		lastTick = now
		capture:Tick(now)
		doors:Tick(now)
		doorPresentation:Tick(now)
		rescueMonitor:Tick(now)
		rescueInteractions:Tick()
		silence:Tick(elapsed, now)
		movementNoise:Tick(now)
		hunter:Tick(now)
		task.wait(0.25)
	end
end)
