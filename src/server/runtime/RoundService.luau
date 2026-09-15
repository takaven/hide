--!strict

local Players = game:GetService("Players")

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
	phaseRuntime: any?
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
		_running = false,
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
	local ids = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(ids, tostring(player.UserId))
	end
	return ids
end

function RoundService:_advance(nextState: string, now: number): boolean
	local ok = self._state:Advance(nextState, now, #Players:GetPlayers())
	if not ok then
		return false
	end
	if nextState == "Prepare" then
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
		self._analytics:Emit("round_started", { playerCount = #Players:GetPlayers() }, now)
	elseif nextState == "Extraction" then
		if self._phaseRuntime ~= nil then
			self._phaseRuntime:BeginExtraction(now)
		end
		self._extraction:Open(now)
		self._analytics:Emit("extraction_started", {}, now)
	elseif nextState == "Results" then
		self._analytics:Emit("round_completed", {}, now)
	end
	self._remotes.StateSnapshot:FireAllClients({
		phase = nextState,
		deadline = self._state:GetDeadline(),
	})
	return true
end

function RoundService:_tick(now: number)
	if now < self._state:GetDeadline() then
		return
	end
	local state = self:GetState()
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
