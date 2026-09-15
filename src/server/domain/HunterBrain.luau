--!strict

local StateMachine = if script
	then require(script.Parent.StateMachine)
	else require("./StateMachine")
local StateDefinitions = if script
	then require(script.Parent.StateDefinitions)
	else require("./StateDefinitions")

local HunterBrain = {}
HunterBrain.__index = HunterBrain

local function bestEvidence(
	config: any,
	noises: { any },
	heatSources: { any },
	ignoredEvidenceId: string?,
	ignoredHidingId: string?
): any?
	local best = nil
	for _, evidence in ipairs(noises) do
		local distanceFactor = 1 / (1 + math.max(0, evidence.distance or 0) / 50)
		local score = evidence.score * config.NoiseScoreScale * distanceFactor
		if
			(ignoredEvidenceId == nil or evidence.id ~= ignoredEvidenceId)
			and (ignoredHidingId == nil or evidence.hidingId ~= ignoredHidingId)
			and (best == nil or score > best.score)
		then
			best = {
				kind = "Noise",
				score = score,
				position = evidence.origin,
				evidenceId = evidence.id,
				hidingId = evidence.hidingId,
			}
		end
	end
	for _, heat in ipairs(heatSources) do
		local distanceFactor = 1 / (1 + math.max(0, heat.distance or 0) / 50)
		local score = math.max(0, heat.value) * config.HeatScoreScale * distanceFactor
		if
			(ignoredHidingId == nil or heat.hidingId ~= ignoredHidingId)
			and (best == nil or score > best.score)
		then
			best = {
				kind = "Heat",
				score = score,
				position = heat.position,
				evidenceId = heat.hidingId,
				hidingId = heat.hidingId,
			}
		end
	end
	return best
end

function HunterBrain.new(config: any)
	local self: any = setmetatable({
		_config = config,
		_machine = StateMachine.new(
			StateDefinitions.Hunter.Initial,
			StateDefinitions.Hunter.Transitions
		),
		_target = nil,
		_searchUntil = nil,
		_investigationStartedAt = nil,
		_investigationHidingId = nil,
		_investigationEvidenceId = nil,
		_investigationNavigationGeneration = nil,
		_ignoredEvidenceId = nil,
		_ignoredHidingId = nil,
		_ignoreEvidenceUntil = 0,
	}, HunterBrain)
	return self
end

function HunterBrain:GetState(): string
	return self._machine:GetState()
end

function HunterBrain:Reset()
	self._machine =
		StateMachine.new(StateDefinitions.Hunter.Initial, StateDefinitions.Hunter.Transitions)
	self._target = nil
	self._searchUntil = nil
	self._investigationStartedAt = nil
	self._investigationHidingId = nil
	self._investigationEvidenceId = nil
	self._investigationNavigationGeneration = nil
	self._ignoredEvidenceId = nil
	self._ignoredHidingId = nil
	self._ignoreEvidenceUntil = 0
end

function HunterBrain:BindInvestigationNavigation(generation: number): boolean
	if self:GetState() ~= "INVESTIGATE" then
		return false
	end
	self._investigationNavigationGeneration = generation
	return true
end

function HunterBrain:_transition(nextState: string, reason: string, now: number): (boolean, string?)
	if self:GetState() == nextState then
		return true, nil
	end
	return self._machine:Transition(nextState, reason, now)
end

function HunterBrain:_beginSearch(now: number, reason: string, inspectionReady: boolean): any
	local hidingId = self._investigationHidingId
	if not inspectionReady and self._investigationEvidenceId ~= nil then
		self._ignoredEvidenceId = self._investigationEvidenceId
		self._ignoredHidingId = self._investigationHidingId
		self._ignoreEvidenceUntil = now + self._config.SearchDuration
	end
	self:_transition("SEARCH", reason, now)
	self._searchUntil = now + self._config.SearchDuration
	self._investigationStartedAt = nil
	self._investigationHidingId = nil
	self._investigationEvidenceId = nil
	self._investigationNavigationGeneration = nil
	return {
		state = self:GetState(),
		target = self._target,
		reason = reason,
		inspectionReady = inspectionReady,
		hidingId = hidingId,
	}
end

function HunterBrain:Decide(now: number, observation: any): any
	local visual = observation.visual
	if visual ~= nil and visual.visible == true then
		local ok, err = self:_transition("CHASE", "direct visual contact", now)
		if ok then
			self._target = visual.position
			self._searchUntil = nil
			self._investigationStartedAt = nil
			self._investigationHidingId = nil
			self._investigationEvidenceId = nil
			self._investigationNavigationGeneration = nil
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

	if current == "INVESTIGATE" then
		local navigationMatches = self._investigationNavigationGeneration ~= nil
			and observation.navigationGeneration == self._investigationNavigationGeneration
		local navigationStatus = if navigationMatches then observation.navigationStatus else "Stale"
		if navigationMatches and observation.reachedTarget == true then
			return self:_beginSearch(now, "InvestigationArrived", true)
		elseif navigationStatus == "Completed" then
			local near = type(observation.targetDistance) == "number"
				and observation.targetDistance <= self._config.InvestigationArrivalDistance
			return self:_beginSearch(
				now,
				if near
					then "InvestigationCompletedNearTarget"
					else "InvestigationIncompleteArrival",
				near
			)
		elseif navigationStatus == "Failed" then
			return self:_beginSearch(now, "InvestigationUnreachable", false)
		elseif navigationStatus == "Cancelled" then
			return self:_beginSearch(now, "InvestigationCancelled", false)
		elseif
			self._investigationStartedAt ~= nil
			and now - self._investigationStartedAt >= self._config.InvestigationTimeout
		then
			return self:_beginSearch(now, "InvestigationTimeout", false)
		end
		return {
			state = current,
			target = self._target,
			reason = "InvestigationInProgress",
			evidenceId = self._investigationEvidenceId,
			hidingId = self._investigationHidingId,
		}
	end

	if now >= self._ignoreEvidenceUntil then
		self._ignoredEvidenceId = nil
		self._ignoredHidingId = nil
	end
	local evidence = bestEvidence(
		self._config,
		observation.noises or {},
		observation.heatSources or {},
		self._ignoredEvidenceId,
		self._ignoredHidingId
	)
	if evidence ~= nil and evidence.score >= self._config.InvestigateThreshold then
		local ok = self:_transition("INVESTIGATE", evidence.kind, now)
		if ok then
			self._target = evidence.position
			self._searchUntil = nil
			self._investigationStartedAt = now
			self._investigationHidingId = evidence.hidingId
			self._investigationEvidenceId = evidence.evidenceId
			self._investigationNavigationGeneration = nil
		end
		return {
			state = self:GetState(),
			target = self._target,
			reason = evidence.kind,
			score = evidence.score,
			evidenceId = evidence.evidenceId,
			hidingId = evidence.hidingId,
		}
	end

	current = self:GetState()
	if current == "SEARCH" and self._searchUntil ~= nil and now >= self._searchUntil then
		self:_transition("RETURN", "search exhausted", now)
		self._target = observation.patrolReturnPosition
	elseif current == "RETURN" and observation.reachedTarget == true then
		self:_transition("PATROL", "returned to route", now)
		self._target = nil
	end
	return { state = self:GetState(), target = self._target, reason = "Fallback" }
end

return HunterBrain
