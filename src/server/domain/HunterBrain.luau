--!strict

local StateMachine = if script
	then require(script.Parent.StateMachine)
	else require("./StateMachine")
local StateDefinitions
if script then
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	StateDefinitions = require(ReplicatedStorage.Hide.Shared.StateDefinitions)
else
	StateDefinitions = require("../../shared/StateDefinitions")
end

local HunterBrain = {}
HunterBrain.__index = HunterBrain

local function bestEvidence(config: any, noises: { any }, heatSources: { any }): any?
	local best = nil
	for _, evidence in ipairs(noises) do
		local distanceFactor = 1 / (1 + math.max(0, evidence.distance or 0) / 50)
		local score = evidence.score * config.NoiseScoreScale * distanceFactor
		if best == nil or score > best.score then
			best = {
				kind = "Noise",
				score = score,
				position = evidence.origin,
				evidenceId = evidence.id,
			}
		end
	end
	for _, heat in ipairs(heatSources) do
		local distanceFactor = 1 / (1 + math.max(0, heat.distance or 0) / 50)
		local score = math.max(0, heat.value) * config.HeatScoreScale * distanceFactor
		if best == nil or score > best.score then
			best = {
				kind = "Heat",
				score = score,
				position = heat.position,
				evidenceId = heat.hidingId,
			}
		end
	end
	return best
end

function HunterBrain.new(config: any)
	return setmetatable({
		_config = config,
		_machine = StateMachine.new(
			StateDefinitions.Hunter.Initial,
			StateDefinitions.Hunter.Transitions
		),
		_target = nil,
		_searchUntil = nil,
	}, HunterBrain)
end

function HunterBrain:GetState(): string
	return self._machine:GetState()
end

function HunterBrain:_transition(nextState: string, reason: string, now: number): (boolean, string?)
	if self:GetState() == nextState then
		return true, nil
	end
	return self._machine:Transition(nextState, reason, now)
end

function HunterBrain:Decide(now: number, observation: any): any
	local visual = observation.visual
	if visual ~= nil and visual.visible == true then
		local ok, err = self:_transition("CHASE", "direct visual contact", now)
		if ok then
			self._target = visual.position
			self._searchUntil = nil
		end
		return {
			state = self:GetState(),
			target = self._target,
			reason = err or "Visual",
			score = self._config.VisualScore,
		}
	end

	local current = self:GetState()
	if current == "CHASE" then
		self:_transition("SEARCH", "lost visual contact", now)
		self._searchUntil = now + self._config.SearchDuration
		return { state = self:GetState(), target = self._target, reason = "LostVisual" }
	end

	local evidence =
		bestEvidence(self._config, observation.noises or {}, observation.heatSources or {})
	if evidence ~= nil and evidence.score >= self._config.InvestigateThreshold then
		local ok = self:_transition("INVESTIGATE", evidence.kind, now)
		if ok then
			self._target = evidence.position
			self._searchUntil = nil
		end
		return {
			state = self:GetState(),
			target = self._target,
			reason = evidence.kind,
			score = evidence.score,
			evidenceId = evidence.evidenceId,
		}
	end

	current = self:GetState()
	if current == "INVESTIGATE" and observation.reachedTarget == true then
		self:_transition("SEARCH", "reached evidence", now)
		self._searchUntil = now + self._config.SearchDuration
	elseif current == "SEARCH" and self._searchUntil ~= nil and now >= self._searchUntil then
		self:_transition("RETURN", "search exhausted", now)
		self._target = observation.patrolReturnPosition
	elseif current == "RETURN" and observation.reachedTarget == true then
		self:_transition("PATROL", "returned to route", now)
		self._target = nil
	end

	return { state = self:GetState(), target = self._target, reason = "Fallback" }
end

return HunterBrain
