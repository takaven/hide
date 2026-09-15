--!strict

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new(initialState: string, transitions: { [string]: { [string]: boolean } })
	assert(
		type(initialState) == "string" and initialState ~= "",
		"initialState must be a non-empty string"
	)
	assert(type(transitions) == "table", "transitions must be a table")
	assert(transitions[initialState] ~= nil, `missing transition definition for {initialState}`)

	return setmetatable({
		_state = initialState,
		_transitions = transitions,
		_history = {},
	}, StateMachine)
end

function StateMachine:GetState(): string
	return self._state
end

function StateMachine:CanTransition(nextState: string): boolean
	local allowed = self._transitions[self._state]
	return allowed ~= nil and allowed[nextState] == true
end

function StateMachine:Transition(
	nextState: string,
	reason: string?,
	now: number?
): (boolean, string?)
	if not self:CanTransition(nextState) then
		return false, `invalid transition {self._state} -> {nextState}`
	end

	local previous = self._state
	self._state = nextState
	table.insert(self._history, {
		from = previous,
		to = nextState,
		reason = reason,
		timestamp = now,
	})

	return true, nil
end

function StateMachine:GetHistory(): { any }
	return table.clone(self._history)
end

return StateMachine
