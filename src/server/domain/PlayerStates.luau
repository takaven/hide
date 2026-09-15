--!strict

local StateMachine = if script
	then require(script.Parent.StateMachine)
	else require("./StateMachine")
local StateDefinitions = if script
	then require(script.Parent.StateDefinitions)
	else require("./StateDefinitions")

local PlayerStates = {}
PlayerStates.__index = PlayerStates

function PlayerStates.new()
	return setmetatable({ _players = {}, _captures = {} }, PlayerStates)
end

function PlayerStates:Add(playerId: string, joinActive: boolean?): boolean
	if self._players[playerId] ~= nil then
		return false
	end
	local machine =
		StateMachine.new(StateDefinitions.Player.Initial, StateDefinitions.Player.Transitions)
	self._players[playerId] = machine
	self._captures[playerId] = 0
	if joinActive then
		machine:Transition("Active", "round join", 0)
	end
	return true
end

function PlayerStates:ResetForRound(playerIds: { string }, now: number)
	for _, playerId in ipairs(playerIds) do
		local state = self:Get(playerId)
		if state == nil then
			self:Add(playerId, true)
		elseif state ~= "Active" then
			local machine = StateMachine.new(
				StateDefinitions.Player.Initial,
				StateDefinitions.Player.Transitions
			)
			machine:Transition("Active", "round reset", now)
			self._players[playerId] = machine
		end
		self._captures[playerId] = 0
	end
end

function PlayerStates:Remove(playerId: string)
	self._players[playerId] = nil
	self._captures[playerId] = nil
end

function PlayerStates:Get(playerId: string): string?
	local machine = self._players[playerId]
	return if machine then machine:GetState() else nil
end

function PlayerStates:Transition(
	playerId: string,
	nextState: string,
	reason: string?,
	now: number?
): (boolean, string?)
	local machine = self._players[playerId]
	if machine == nil then
		return false, "unknown player"
	end
	return machine:Transition(nextState, reason, now)
end

function PlayerStates:Capture(
	playerId: string,
	captureLimit: number,
	now: number
): (boolean, string?)
	local state = self:Get(playerId)
	if state ~= "Active" and state ~= "Hiding" and state ~= "Rescued" then
		return false, "player cannot be captured from current state"
	end

	local captures = (self._captures[playerId] or 0) + 1
	self._captures[playerId] = captures
	return self:Transition(playerId, "Downed", `capture {captures}/{captureLimit}`, now)
end

function PlayerStates:GetCaptureCount(playerId: string): number
	return self._captures[playerId] or 0
end

function PlayerStates:ResolveDowned(
	playerId: string,
	captureLimit: number,
	rescued: boolean,
	now: number
): (boolean, string?)
	if self:Get(playerId) ~= "Downed" then
		return false, "player is not downed"
	end
	local captures = self:GetCaptureCount(playerId)
	local nextState = if rescued and captures < captureLimit then "Rescued" else "Eliminated"
	return self:Transition(
		playerId,
		nextState,
		if rescued then "rescued" else "downed expired",
		now
	)
end

function PlayerStates:ActivateRescued(playerId: string, now: number): (boolean, string?)
	return self:Transition(playerId, "Active", "rescue recovery complete", now)
end

function PlayerStates:IsSpectatorOnly(playerId: string): boolean
	local state = self:Get(playerId)
	return state == "Eliminated" or state == "Escaped" or state == "Spectating"
end

return PlayerStates
