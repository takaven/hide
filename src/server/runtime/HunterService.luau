--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HunterBrain = require(script.Parent.Parent.domain.HunterBrain)
local HunterInspection = require(script.Parent.Parent.domain.HunterInspection)
local NearMissPolicy = require(script.Parent.Parent.domain.NearMissPolicy)
local NativeNavigationProvider = require(script.Parent.NativeNavigationProvider)
local NavigationProvider = require(script.Parent.NavigationProvider)

local HunterService = {}
HunterService.__index = HunterService

function HunterService.new(
	config: any,
	world: any,
	playerStates: any,
	hiding: any,
	noise: any,
	capture: any,
	analytics: any,
	round: any,
	audio: any?
)
	return setmetatable({
		_config = config,
		_world = world,
		_playerStates = playerStates,
		_hiding = hiding,
		_noise = noise,
		_capture = capture,
		_analytics = analytics,
		_round = round,
		_audio = audio,
		_brain = HunterBrain.new(config.Hunter),
		_hunter = nil,
		_navigation = nil,
		_lastTarget = nil,
		_lastMoveAt = 0,
		_patrolIndex = 0,
		_patrolTarget = nil,
		_lastSeenPlayerId = nil,
		_lastEvidenceId = nil,
		_lastRoundPhase = nil,
		_wasActive = false,
		_random = Random.new(),
		_patrolOrder = {},
		_searchCenter = nil,
		_searchTarget = nil,
		_searchPointsRemaining = 0,
		_doubleTakeRequested = false,
		_chaseStartedAt = nil,
		_chaseClosestDistance = math.huge,
		_spawnCFrame = nil,
	}, HunterService)
end

function HunterService:RequestDoubleTake()
	if
		self._doubleTakeRequested
		or self._brain:GetState() ~= "SEARCH"
		or self._lastTarget == nil
	then
		return false
	end
	self._doubleTakeRequested = true
	return true
end

function HunterService:_root(): BasePart?
	local hunter = self._hunter
	if hunter == nil or not hunter:IsA("Model") then
		return nil
	end
	local root = hunter:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function HunterService:_visiblePlayer(root: BasePart): (Player?, Vector3?)
	local nearestPlayer = nil
	local nearestPosition = nil
	local nearestDistance = math.huge
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { self._hunter }

	local worldRoot = Workspace:FindFirstChild("LeMorneStormResort")
	local visionMultiplier = if worldRoot
		then tonumber(worldRoot:GetAttribute("HunterVisionMultiplier")) or 1
		else 1
	local visionDistance = self._config.Hunter.VisionDistance * visionMultiplier
	for _, player in ipairs(Players:GetPlayers()) do
		local state = self._playerStates:Get(tostring(player.UserId))
		if state == "Active" or state == "Rescued" then
			local character = player.Character
			local position = self._world.GetPlayerPosition(player)
			if character ~= nil and position ~= nil then
				local offset = position - root.Position
				local distance = offset.Magnitude
				if distance > 0 and distance <= visionDistance then
					local facing = root.CFrame.LookVector:Dot(offset.Unit)
					if facing >= self._config.Hunter.VisionDotThreshold then
						local hit = Workspace:Raycast(root.Position, offset, raycastParams)
						if
							hit ~= nil
							and hit.Instance:IsDescendantOf(character)
							and distance < nearestDistance
						then
							nearestPlayer = player
							nearestPosition = position
							nearestDistance = distance
						end
					end
				end
			end
		end
	end
	return nearestPlayer, nearestPosition
end

function HunterService:_shufflePatrol()
	self._patrolOrder = table.clone(self._world.PatrolPoints)
	table.sort(self._patrolOrder, function(a, b)
		return a.Name < b.Name
	end)
	for index = #self._patrolOrder, 2, -1 do
		local swap = self._random:NextInteger(1, index)
		self._patrolOrder[index], self._patrolOrder[swap] =
			self._patrolOrder[swap], self._patrolOrder[index]
	end
	self._patrolIndex = 0
end

function HunterService:_nextSearchPosition(center: Vector3): Vector3
	if self._searchPointsRemaining == self._config.Hunter.SearchPointCount then
		return center
	end
	if self._searchPointsRemaining == self._config.Hunter.SearchPointCount - 1 then
		local nearest = nil
		local nearestDistance = math.huge
		for _, record in pairs(self._world.Hiding) do
			local distance = (record.approachPosition - center).Magnitude
			if
				distance < nearestDistance
				and distance <= self._config.Hunter.SearchRadius * 1.5
			then
				nearest = record.approachPosition
				nearestDistance = distance
			end
		end
		if nearest ~= nil then
			return nearest
		end
	end
	local angle = self._random:NextNumber(0, math.pi * 2)
	local radius = self._random:NextNumber(
		self._config.Hunter.SearchRadius * 0.45,
		self._config.Hunter.SearchRadius
	)
	return center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

function HunterService:_noiseEvidence(root: BasePart, now: number): { any }
	local evidence = self._noise:GetEvidence(now)
	for _, item in ipairs(evidence) do
		local hidingNoise = item.category == "FailedSilence"
			or item.category == "HidingEntry"
			or item.category == "HidingExit"
		local spot = if hidingNoise and item.sourceId
			then self._hiding:GetSpot(item.sourceId)
			else nil
		if spot ~= nil then
			item.hidingId = spot.id
			item.origin = spot.approachPosition
		end
		item.distance = (root.Position - item.origin).Magnitude
	end
	return evidence
end

function HunterService:_heatEvidence(root: BasePart, now: number): { any }
	local evidence = {}
	for _, hidingId in ipairs(self._hiding:GetSpotIds()) do
		local spot = self._hiding:GetSpot(hidingId)
		if spot ~= nil then
			table.insert(evidence, {
				hidingId = hidingId,
				position = spot.approachPosition,
				value = self._hiding:GetHeat(hidingId, now),
				distance = (root.Position - spot.approachPosition).Magnitude,
			})
		end
	end
	return evidence
end

function HunterService:_nextPatrolPosition(): Vector3?
	local points = self._patrolOrder
	if #points == 0 then
		return nil
	end
	self._patrolIndex = (self._patrolIndex % #points) + 1
	local point = points[self._patrolIndex]
	if point:IsA("BasePart") then
		return point.Position
	elseif point:IsA("Model") then
		return point:GetPivot().Position
	end
	return nil
end

function HunterService:Start(): (boolean, string?)
	local candidate = self._world.Hunters[1]
	if candidate == nil or not candidate:IsA("Model") then
		return false, "no tagged hunter model; HunterService remains safely inactive"
	end
	self._hunter = candidate
	self._spawnCFrame = candidate:GetPivot()
	self._navigation = NativeNavigationProvider.new(candidate, self._config.Hunter)
	local valid, err = NavigationProvider.validate(self._navigation)
	if not valid then
		return false, err
	end
	return true, nil
end

function HunterService:ResetRound()
	if self._navigation ~= nil and self._navigation:GetStatus() ~= "Idle" then
		self._navigation:Cancel()
	end
	self._brain:Reset()
	self._lastTarget = nil
	self._patrolTarget = nil
	self._lastEvidenceId = nil
	self._lastSeenPlayerId = nil
	self._searchCenter = nil
	self._searchTarget = nil
	self._searchPointsRemaining = 0
	self._doubleTakeRequested = false
	self._chaseStartedAt = nil
	self._chaseClosestDistance = math.huge
	self._wasActive = false
	if self._hunter ~= nil and self._spawnCFrame ~= nil then
		self._hunter:PivotTo(self._spawnCFrame)
		local root = self:_root()
		if root ~= nil then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

function HunterService:Tick(now: number)
	local phase = self._round:GetState()
	local active = phase == "Hunt" or phase == "Relocation" or phase == "Extraction"
	if not active then
		if self._lastRoundPhase ~= phase then
			if self._navigation ~= nil and self._navigation:GetStatus() ~= "Idle" then
				self._navigation:Cancel()
			end
			self._brain:Reset()
			self._lastTarget = nil
			self._patrolTarget = nil
			self._lastEvidenceId = nil
			self._lastSeenPlayerId = nil
			self._searchCenter = nil
			self._searchTarget = nil
			self._searchPointsRemaining = 0
		end
		self._wasActive = false
		self._lastRoundPhase = phase
		return
	end
	if not self._wasActive then
		self:_shufflePatrol()
		self._wasActive = true
	end
	self._lastRoundPhase = phase

	local root = self:_root()
	if root == nil or self._navigation == nil then
		return
	end
	local visiblePlayer, visiblePosition = self:_visiblePlayer(root)
	local previousBrainState = self._brain:GetState()
	local navigationStatus, navigationGeneration = self._navigation:GetStatus()
	local targetDistance = if self._lastTarget ~= nil
		then (root.Position - self._lastTarget).Magnitude
		else nil
	local reachedTarget = self._lastTarget ~= nil
		and targetDistance <= self._config.Hunter.CaptureDistance
	local decision = self._brain:Decide(now, {
		visual = if visiblePlayer and visiblePosition
			then { visible = true, position = visiblePosition }
			else nil,
		noises = self:_noiseEvidence(root, now),
		heatSources = self:_heatEvidence(root, now),
		reachedTarget = reachedTarget,
		targetDistance = targetDistance,
		navigationStatus = navigationStatus,
		navigationGeneration = navigationGeneration,
		patrolReturnPosition = self._patrolTarget,
	})
	if decision.state == "CHASE" then
		if previousBrainState ~= "CHASE" then
			self._chaseStartedAt = now
			self._chaseClosestDistance = math.huge
		end
		if visiblePosition ~= nil then
			self._chaseClosestDistance =
				math.min(self._chaseClosestDistance, (root.Position - visiblePosition).Magnitude)
		end
	end
	local humanoid = self._hunter and self._hunter:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.WalkSpeed = if decision.state == "CHASE"
			then self._config.Hunter.ChaseSpeed
			else self._config.Hunter.WalkSpeed
	end
	if self._audio ~= nil then
		self._audio:SetHunterState(decision.state, navigationStatus == "Moving")
	end
	if decision.state == "SEARCH" and string.sub(decision.reason, 1, 13) == "Investigation" then
		if
			navigationStatus ~= "Idle"
			and navigationStatus ~= "Completed"
			and navigationStatus ~= "Failed"
		then
			self._navigation:Cancel()
		end
		self._lastTarget = nil
	end

	if visiblePlayer ~= nil and visiblePosition ~= nil then
		local playerId = tostring(visiblePlayer.UserId)
		if self._lastSeenPlayerId ~= playerId or previousBrainState ~= "CHASE" then
			self._analytics:Emit("hunter_found_player", { playerId = playerId }, now)
		end
		self._lastSeenPlayerId = playerId
		if (root.Position - visiblePosition).Magnitude <= self._config.Hunter.CaptureDistance then
			self._capture:Down(playerId, now, "visual_chase")
		end
	elseif decision.state == "INVESTIGATE" and decision.evidenceId ~= nil then
		self._lastSeenPlayerId = nil
		if self._lastEvidenceId ~= decision.evidenceId or previousBrainState ~= "INVESTIGATE" then
			self._analytics:Emit(
				"hunter_investigated",
				{ evidenceId = decision.evidenceId, evidenceKind = decision.reason },
				now
			)
		end
		self._lastEvidenceId = decision.evidenceId
	else
		self._lastSeenPlayerId = nil
	end
	if decision.state == "SEARCH" and previousBrainState ~= "SEARCH" then
		if self._navigation:GetStatus() ~= "Idle" then
			self._navigation:Cancel()
		end
		self._searchCenter = decision.target or self._lastTarget or root.Position
		self._searchPointsRemaining = self._config.Hunter.SearchPointCount
		self._searchTarget = self:_nextSearchPosition(self._searchCenter)
		if previousBrainState == "CHASE" then
			local chaseDuration = now - (self._chaseStartedAt or now)
			if
				NearMissPolicy.qualifies(self._config, chaseDuration, self._chaseClosestDistance)
			then
				self._analytics:Emit("near_miss", {
					source = decision.reason,
					duration = chaseDuration,
					closestDistance = self._chaseClosestDistance,
				}, now)
			end
			self._chaseStartedAt = nil
			self._chaseClosestDistance = math.huge
		end
	elseif decision.state ~= "SEARCH" then
		self._searchCenter = nil
		self._searchTarget = nil
		self._searchPointsRemaining = 0
	end
	if decision.inspectionReady == true and decision.hidingId ~= nil then
		local heatDiscoverable = self._hiding:GetHeat(decision.hidingId, now)
			>= self._config.Hiding.InspectionHeatThreshold
		local discovered =
			HunterInspection.Inspect(self._hiding, self._capture, decision.hidingId, now)
		if self._audio ~= nil then
			self._audio:Play("ListenerInspect")
		end
		self._analytics:Emit("inspection", {
			hidingId = decision.hidingId,
			found = #discovered,
			heat = self._hiding:GetHeat(decision.hidingId, now),
			exposed = self._hiding:IsExposed(decision.hidingId, now),
		}, now)
		if heatDiscoverable and #discovered > 0 then
			self._analytics:Emit("heat_based_inspection", {
				hidingId = decision.hidingId,
				occupantCount = #discovered,
			}, now)
		end
		for _, playerId in ipairs(discovered) do
			self._analytics:Emit(
				"hunter_found_player",
				{ playerId = playerId, hidingId = decision.hidingId, source = "spot_inspection" },
				now
			)
		end
	end

	local target = decision.target
	if self._doubleTakeRequested and decision.state == "SEARCH" and self._lastTarget ~= nil then
		self._doubleTakeRequested = false
		self._searchCenter = self._lastTarget
		self._searchPointsRemaining = math.min(2, self._config.Hunter.SearchPointCount)
		self._searchTarget = self._lastTarget
	end
	if decision.state == "SEARCH" and self._searchCenter ~= nil then
		local searchReached = self._searchTarget ~= nil
			and (root.Position - self._searchTarget).Magnitude
				<= self._config.Hunter.InvestigationArrivalDistance
		local searchFinished = navigationStatus == "Completed" or navigationStatus == "Failed"
		if (searchReached or searchFinished) and self._searchPointsRemaining > 0 then
			self._searchPointsRemaining -= 1
			self._searchTarget = if self._searchPointsRemaining > 0
				then self:_nextSearchPosition(self._searchCenter)
				else nil
			self._lastTarget = nil
		end
		target = self._searchTarget
	end
	if decision.state == "PATROL" and target == nil then
		if self._patrolTarget == nil or reachedTarget then
			self._patrolTarget = self:_nextPatrolPosition()
		end
		target = self._patrolTarget
	end
	local targetMoved = target ~= nil
		and self._lastTarget ~= nil
		and (target - self._lastTarget).Magnitude
			>= self._config.Hunter.MovingTargetRepathDistance
	local newInvestigation = decision.state == "INVESTIGATE" and previousBrainState ~= "INVESTIGATE"
	local shouldMove = target ~= nil
		and self._searchPointsRemaining >= 0
		and (newInvestigation or self._lastTarget == nil or targetMoved)
		and (newInvestigation or now - self._lastMoveAt >= self._config.Hunter.RepathInterval)
	if shouldMove then
		self._navigation:MoveTo(target)
		if newInvestigation then
			local _, investigationGeneration = self._navigation:GetStatus()
			self._brain:BindInvestigationNavigation(investigationGeneration)
		end
		self._lastTarget = target
		self._lastMoveAt = now
	end
end

return HunterService
