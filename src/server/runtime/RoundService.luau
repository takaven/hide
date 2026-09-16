--!strict

local Players = game:GetService("Players")

local ParticipantMetrics = require(script.Parent.Parent.domain.ParticipantMetrics)
local RoundState = require(script.Parent.Parent.domain.RoundState)

local RoundService = {}
RoundService.__index = RoundService

function RoundService.new(
	config: any,
	playerStates: any,
	extraction: any,
	decoys: any,
	analytics: any,
	remotes: any,
	phaseRuntime: any?,
	options: any?
)
	local now = workspace:GetServerTimeNow()
	return setmetatable({
		_config = config,
		_state = RoundState.new(config.Round, now),
		_playerStates = playerStates,
		_extraction = extraction,
		_analytics = analytics,
		_remotes = remotes,
		_phaseRuntime = phaseRuntime,
		_rematch = if options then options.Rematch else nil,
		_recognition = if options then options.Recognition else nil,
		_participantIds = if options then options.ParticipantIds else nil,
		_running = false,
		_roundNumber = 0,
		_resetters = { decoys },
	}, RoundService)
end

function RoundService:AddResetter(resetter: any)
	assert(
		type(resetter) == "table" and type(resetter.ResetRound) == "function",
		"round resetter must expose ResetRound"
	)
	table.insert(self._resetters, resetter)
end

function RoundService:GetState(): string
	return self._state:GetState()
end

function RoundService:GetDeadline(): number
	return self._state:GetDeadline()
end

function RoundService:_playerIds(): { string }
	if self._participantIds ~= nil then
		return self._participantIds()
	end
	local ids = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(ids, tostring(player.UserId))
	end
	return ids
end

function RoundService:_participantCount(): number
	return #self:_playerIds()
end

function RoundService:_advance(nextState: string, now: number): boolean
	local ok = self._state:Advance(nextState, now, self:_participantCount())
	if not ok then
		return false
	end
	if nextState == "Prepare" then
		self._roundNumber += 1
		for _, resetter in ipairs(self._resetters) do
			resetter:ResetRound()
		end
		self._playerStates:ResetForRound(self:_playerIds(), now)
		for _, player in ipairs(Players:GetPlayers()) do
			self._remotes.StateSnapshot:FireClient(
				player,
				{ state = self._playerStates:Get(tostring(player.UserId)) }
			)
		end
		self._analytics:Emit("round_started", {
			playerCount = #Players:GetPlayers(),
			aiGuestCount = math.max(0, self:_participantCount() - #Players:GetPlayers()),
			roundNumber = self._roundNumber,
		}, now)
	elseif nextState == "Extraction" then
		local activeExtractionId = self._extraction:Open(now)
		if self._phaseRuntime ~= nil then
			self._phaseRuntime:BeginExtraction(now)
		end
		self._analytics:Emit("extraction_started", { extractionId = activeExtractionId }, now)
	elseif nextState == "Results" then
		local counts = ParticipantMetrics.countResults(self:_playerIds(), function(playerId)
			return self._playerStates:Get(playerId)
		end)
		counts.roundNumber = self._roundNumber
		self._analytics:Emit("round_completed", counts, now)
		local results = if self._recognition ~= nil
			then {
				moment = self._recognition:MomentOfRound(),
				awards = self._recognition:BuildAwards(),
			}
			else nil
		self._remotes.StateSnapshot:FireAllClients({ results = results })
		for _, player in ipairs(Players:GetPlayers()) do
			self._analytics:Emit("invite_cta_shown", { playerId = tostring(player.UserId) }, now)
		end
	end
	self._remotes.StateSnapshot:FireAllClients({
		phase = nextState,
		deadline = self._state:GetDeadline(),
		activeExtractionId = self._extraction:GetActiveId(),
	})
	return true
end

function RoundService:_tick(now: number)
	if now < self._state:GetDeadline() then
		return
	end
	local state = self:GetState()
	if state == "Results" and self._rematch ~= nil and self._rematch:ShouldRestart(now) then
		if self:_advance("Lobby", now) and self:_advance("Prepare", now) then
			self._analytics:Emit("rematch_started", { playerCount = #Players:GetPlayers() }, now)
		end
		return
	end
	if state == "Lobby" then
		self:_advance("Prepare", now)
	elseif state == "Prepare" or state == "Relocation" then
		self:_advance("Hunt", now)
	elseif state == "Hunt" then
		if self._state:GetHuntCount() == 1 then
			self:_advance("Relocation", now)
		else
			self:_advance("Extraction", now)
		end
	elseif state == "Extraction" then
		self:_advance("Results", now)
	elseif state == "Results" then
		self:_advance("Lobby", now)
	end
end

function RoundService:Start()
	if self._running then
		return
	end
	self._running = true
	task.spawn(function()
		while self._running do
			self:_tick(workspace:GetServerTimeNow())
			task.wait(0.25)
		end
	end)
end

return RoundService
