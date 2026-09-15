--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HunterBrain = require(script.Parent.Parent.domain.HunterBrain)
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
	round: any
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
	}, HunterService)
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

	for _, player in ipairs(Players:GetPlayers()) do
		local state = self._playerStates:Get(tostring(player.UserId))
		if state == "Active" or state == "Rescued" then
			local character = player.Character
			local position = self._world.GetPlayerPosition(player)
			if character ~= nil and position ~= nil then
				local offset = position - root.Position
				local distance = offset.Magnitude
				if distance > 0 and distance <= self._config.Hunter.VisionDistance then
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

function HunterService:_noiseEvidence(root: BasePart, now: number): { any }
	local evidence = self._noise:GetEvidence(now)
	for _, item in ipairs(evidence) do
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
				position = spot.position,
				value = self._hiding:GetHeat(hidingId, now),
				distance = (root.Position - spot.position).Magnitude,
			})
		end
	end
	return evidence
end

function HunterService:_nextPatrolPosition(): Vector3?
	local points = self._world.PatrolPoints
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
	self._navigation = NativeNavigationProvider.new(candidate, self._config.Hunter)
	local valid, err = NavigationProvider.validate(self._navigation)
	if not valid then
		return false, err
	end
	return true, nil
end

function HunterService:Tick(now: number)
	local phase = self._round:GetState()
	local active = phase == "Hunt" or phase == "Relocation" or phase == "Extraction"
	if not active then
		if self._lastRoundPhase ~= phase then
			if self._navigation ~= nil and self._navigation:GetStatus() ~= "Idle" then
				self._navigation:Cancel()
			end
			self._brain = HunterBrain.new(self._config.Hunter)
			self._lastTarget = nil
			self._patrolTarget = nil
			self._lastEvidenceId = nil
			self._lastSeenPlayerId = nil
		end
		self._lastRoundPhase = phase
		return
	end
	self._lastRoundPhase = phase

	local root = self:_root()
	if root == nil or self._navigation == nil then
		return
	end
	local visiblePlayer, visiblePosition = self:_visiblePlayer(root)
	local previousBrainState = self._brain:GetState()
	local reachedTarget = self._lastTarget ~= nil
		and (root.Position - self._lastTarget).Magnitude <= self._config.Hunter.CaptureDistance
	local decision = self._brain:Decide(now, {
		visual = if visiblePlayer and visiblePosition
			then { visible = true, position = visiblePosition }
			else nil,
		noises = self:_noiseEvidence(root, now),
		heatSources = self:_heatEvidence(root, now),
		reachedTarget = reachedTarget,
		patrolReturnPosition = self._patrolTarget,
	})

	if visiblePlayer ~= nil and visiblePosition ~= nil then
		local playerId = tostring(visiblePlayer.UserId)
		if self._lastSeenPlayerId ~= playerId or previousBrainState ~= "CHASE" then
			self._analytics:Emit("hunter_found_player", { playerId = playerId }, now)
		end
		self._lastSeenPlayerId = playerId
		if (root.Position - visiblePosition).Magnitude <= self._config.Hunter.CaptureDistance then
			self._capture:Down(playerId, now)
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

	local target = decision.target
	if decision.state == "PATROL" and target == nil then
		if self._patrolTarget == nil or reachedTarget then
			self._patrolTarget = self:_nextPatrolPosition()
		end
		target = self._patrolTarget
	end
	local navigationStatus = self._navigation:GetStatus()
	local targetMoved = target ~= nil
		and self._lastTarget ~= nil
		and (target - self._lastTarget).Magnitude
			>= self._config.Hunter.MovingTargetRepathDistance
	local shouldMove = target ~= nil
		and (self._lastTarget == nil or targetMoved or navigationStatus == "Failed")
		and now - self._lastMoveAt >= self._config.Hunter.RepathInterval
	if shouldMove then
		self._navigation:MoveTo(target)
		self._lastTarget = target
		self._lastMoveAt = now
	end
end

return HunterService
