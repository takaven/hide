--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Hide.Shared.Config)
local ConfigValidator = require(ReplicatedStorage.Hide.Shared.ConfigValidator)

local Domain = ServerScriptService.Hide.domain
local Runtime = ServerScriptService.Hide.runtime

local ActionService = require(Runtime.ActionService)
local AnalyticsBus = require(Domain.AnalyticsBus)
local AudioPresentationService = require(Runtime.AudioPresentationService)
local CaptureService = require(Runtime.CaptureService)
local CharacterPresentationService = require(Runtime.CharacterPresentationService)
local DecoySystem = require(Domain.DecoySystem)
local DoorSystem = require(Domain.DoorSystem)
local DoorPresentationService = require(Runtime.DoorPresentationService)
local DownedEvidenceService = require(Runtime.DownedEvidenceService)
local ExtractionSystem = require(Domain.ExtractionSystem)
local ExtractionRuntimeService = require(Runtime.ExtractionRuntimeService)
local HidingSystem = require(Domain.HidingSystem)
local HunterService = require(Runtime.HunterService)
local InteractionBinder = require(Runtime.InteractionBinder)
local NoiseLedger = require(Domain.NoiseLedger)
local MovementNoiseService = require(Runtime.MovementNoiseService)
local MovieMomentDirector = require(Runtime.MovieMomentDirector)
local PlayerStates = require(Domain.PlayerStates)
local PlayerLifecycle = require(Domain.PlayerLifecycle)
local PlayerLifecycleService = require(Runtime.PlayerLifecycleService)
local PlayerStatePresentationService = require(Runtime.PlayerStatePresentationService)
local RemoteGateway = require(Runtime.RemoteGateway)
local Remotes = require(Runtime.Remotes)
local RobloxAnalyticsProvider = require(Runtime.RobloxAnalyticsProvider)
local RescueSystem = require(Domain.RescueSystem)
local RescueMonitor = require(Runtime.RescueMonitor)
local RescueInteractionService = require(Runtime.RescueInteractionService)
local RoundService = require(Runtime.RoundService)
local SilenceMonitor = require(Runtime.SilenceMonitor)
local SoakMetricsService = require(Runtime.SoakMetricsService)
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
local audio = AudioPresentationService.new(worldRoot)

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
		activeExtractionId = extraction:GetActiveId(),
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
			snapshot.peekAction = { hidingId = hidingId }
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
	Audio = audio,
})
local gateway = RemoteGateway.new(Config, remotes, actionService)
local interactions = InteractionBinder.new(Config, world, gateway)
local silence = SilenceMonitor.new(Config, hiding, noise, analytics, remotes)
local movementNoise = MovementNoiseService.new(Config, playerStates, noise, analytics)
local downedEvidence = DownedEvidenceService.new(Config, playerStates, noise)
local statePresentation = PlayerStatePresentationService.new(playerStates, worldRoot)
local doorPresentation =
	DoorPresentationService.new(world, doors, playerStates, Config.Interaction.MaxDistance, audio)
local rescueInteractions = RescueInteractionService.new(Config, playerStates, rescue, gateway)
local hunter =
	HunterService.new(Config, world, playerStates, hiding, noise, capture, analytics, round, audio)
local movieMoments = MovieMomentDirector.new({
	Config = Config,
	WorldRoot = worldRoot,
	Noise = noise,
	Extraction = extraction,
	Hunter = hunter,
	Audio = audio,
	Analytics = analytics,
	Remotes = remotes,
})
local soakMetrics = SoakMetricsService.new(hiding, noise, analytics)
if RunService:IsStudio() then
	local momentTestTrigger = Instance.new("BindableFunction")
	momentTestTrigger.Name = "MovieMomentTestTrigger"
	momentTestTrigger.OnInvoke = function(kind: string)
		movieMoments:ResetRound()
		return movieMoments:Trigger(kind, workspace:GetServerTimeNow())
	end
	momentTestTrigger.Parent = ServerStorage
	local diagnostics = Instance.new("BindableFunction")
	diagnostics.Name = "HideStudioDiagnostics"
	diagnostics.OnInvoke = function()
		return soakMetrics:GetReport()
	end
	diagnostics.Parent = ServerStorage
	local stagingGateTest = Instance.new("BindableFunction")
	stagingGateTest.Name = "HideStudioStagingGate"
	stagingGateTest.OnInvoke = function(mode: string?)
		local player = Players:GetPlayers()[1]
		if player == nil then
			return { ok = false, error = "no player" }
		end
		local playerId = tostring(player.UserId)
		local now = workspace:GetServerTimeNow()
		playerStates:ResetForRound({ playerId }, now)
		capture:Down(playerId, now, "studio_reset_regression")
		playerStates:ResolveDowned(playerId, 1, false, now)
		statePresentation:Tick()
		local spectatorSpawn = worldRoot:FindFirstChild("SpectatorSpawn", true)
		local terminalPosition = if player.Character
			then player.Character:GetPivot().Position
			else nil
		if mode == "eliminate_only" then
			return {
				ok = playerStates:Get(playerId) == "Eliminated",
				state = playerStates:Get(playerId),
				positionY = if terminalPosition then terminalPosition.Y else nil,
			}
		end
		capture:ResetRound()
		statePresentation:ResetRound()
		playerStates:ResetForRound({ playerId }, now + 1)
		statePresentation:Tick()
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local arrivalSpawn = worldRoot:FindFirstChild("ArrivalSpawn", true)
		local finalPosition = if character then character:GetPivot().Position else nil
		return {
			ok = playerStates:Get(playerId) == "Active"
				and humanoid ~= nil
				and humanoid.Health > 0
				and finalPosition ~= nil
				and arrivalSpawn ~= nil
				and arrivalSpawn:IsA("BasePart")
				and (finalPosition - arrivalSpawn.Position).Magnitude < 8,
			state = playerStates:Get(playerId),
			captureCount = playerStates:GetCaptureCount(playerId),
			health = if humanoid then humanoid.Health else 0,
			terminalPosition = terminalPosition,
			finalPosition = finalPosition,
			spectatorSpawnPosition = if spectatorSpawn and spectatorSpawn:IsA("BasePart")
				then spectatorSpawn.Position
				else nil,
			arrivalPosition = if arrivalSpawn and arrivalSpawn:IsA("BasePart")
				then arrivalSpawn.Position
				else nil,
		}
	end
	stagingGateTest.Parent = ServerStorage
end

local function registerPlayer(player: Player)
	local phase = round:GetState()
	local joinActive = phase == "Lobby" or phase == "Prepare"
	playerStates:Add(tostring(player.UserId), joinActive)
	lifecycleService:Attach(player)
	remotes.StateSnapshot:FireClient(player, {
		state = playerStates:Get(tostring(player.UserId)),
		phase = phase,
		deadline = round:GetDeadline(),
		activeExtractionId = extraction:GetActiveId(),
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
	downedEvidence,
	statePresentation,
	hunter,
	movieMoments,
	soakMetrics,
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
		downedEvidence:Tick(now)
		statePresentation:Tick()
		hunter:Tick(now)
		movieMoments:Tick(now, round:GetState())
		soakMetrics:Tick(now)
		task.wait(0.25)
	end
end)
