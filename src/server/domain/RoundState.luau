--!strict

local StateMachine = if script
	then require(script.Parent.StateMachine)
	else require("./StateMachine")
local StateDefinitions = if script
	then require(script.Parent.StateDefinitions)
	else require("./StateDefinitions")

local RoundState = {}
RoundState.__index = RoundState

function RoundState.new(config: any, now: number)
	local self: any = setmetatable({
		_config = config,
		_machine = StateMachine.new(
			StateDefinitions.Round.Initial,
			StateDefinitions.Round.Transitions
		),
		_startedAt = now,
		_huntCount = 0,
	}, RoundState)
	return self
end

function RoundState:GetState(): string
	return self._machine:GetState()
end

function RoundState:GetDeadline(): number
	return self._startedAt + self._config.Durations[self:GetState()]
end

function RoundState:GetHuntCount(): number
	return self._huntCount
end

function RoundState:Advance(
	nextState: string,
	now: number,
	activePlayerCount: number
): (boolean, string?)
	if nextState == "Prepare" and activePlayerCount < self._config.MinimumPlayers then
		return false, "not enough players"
	end
	if nextState == "Relocation" and self._huntCount >= 2 then
		return false, "relocation limit reached"
	end

	local ok, err = self._machine:Transition(nextState, "round advance", now)
	if ok then
		self._startedAt = now
		if nextState == "Hunt" then
			self._huntCount += 1
		elseif nextState == "Lobby" then
			self._huntCount = 0
		end
	end
	return ok, err
end

function RoundState:GetHistory(): { any }
	return self._machine:GetHistory()
end

return RoundState
