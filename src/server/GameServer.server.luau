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
local DecoySystem = require(Domain.DecoySystem)
local DoorSystem = require(Domain.DoorSystem)
local ExtractionSystem = require(Domain.ExtractionSystem)
local HidingSystem = require(Domain.HidingSystem)
local HunterService = require(Runtime.HunterService)
local InteractionBinder = require(Runtime.InteractionBinder)
local NoiseLedger = require(Domain.NoiseLedger)
local PlayerStates = require(Domain.PlayerStates)
local PlayerLifecycle = require(Domain.PlayerLifecycle)
local PlayerLifecycleService = require(Runtime.PlayerLifecycleService)
local RemoteGateway = require(Runtime.RemoteGateway)
local Remotes = require(Runtime.Remotes)
local RescueSystem = require(Domain.RescueSystem)
local RescueMonitor = require(Runtime.RescueMonitor)
local RoundService = require(Runtime.RoundService)
local SilenceMonitor = require(Runtime.SilenceMonitor)
local WorldRegistry = require(Runtime.WorldRegistry)

local configValid, configErrors = ConfigValidator.validate(Config)
assert(configValid, `invalid HIDE config: {table.concat(configErrors, "; ")}`)

local remotes = Remotes.create()
local analytics = AnalyticsBus.new()
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

local round = RoundService.new(Config, playerStates, extraction, decoys, analytics, remotes)
local capture = CaptureService.new(Config, playerStates, hiding, analytics, remotes)
local lifecycle = PlayerLifecycle.new({
	PlayerStates = playerStates,
	Hiding = hiding,
	Doors = doors,
	Rescue = rescue,
	Capture = capture,
})
local lifecycleService = PlayerLifecycleService.new(lifecycle, remotes)
local rescueMonitor = RescueMonitor.new(rescue, playerStates, world)
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
})
local gateway = RemoteGateway.new(Config, remotes, actionService)
local interactions = InteractionBinder.new(Config, world, gateway)
local silence = SilenceMonitor.new(hiding, noise, analytics)
local hunter =
	HunterService.new(Config, world, playerStates, hiding, noise, capture, analytics, round)

local function registerPlayer(player: Player)
	playerStates:Add(tostring(player.UserId), false)
	lifecycleService:Attach(player)
	remotes.StateSnapshot:FireClient(player, { state = "Spectating" })
end

for _, player in ipairs(Players:GetPlayers()) do
	registerPlayer(player)
end
Players.PlayerAdded:Connect(registerPlayer)

for _, resetter in ipairs({ hiding, doors, rescue, extraction, noise, capture, silence }) do
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
		rescueMonitor:Tick(now)
		silence:Tick(elapsed, now)
		hunter:Tick(now)
		task.wait(0.25)
	end
end)
