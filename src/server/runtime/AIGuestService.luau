--!strict

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

local AIGuestPopulation = require(script.Parent.Parent.domain.AIGuestPopulation)

local AIGuestService = {}
AIGuestService.__index = AIGuestService

local function setVisible(model: Model, visible: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.Transparency = if visible then 0 else 1
			descendant.CanCollide = visible
			descendant.CanTouch = visible
			descendant.CanQuery = visible
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
		end
	end
end

local function buildGuest(index: number, parent: Instance, spawnCFrame: CFrame): Model
	local model = Instance.new("Model")
	model.Name = `AI Resort Guest {index}`
	model:SetAttribute("ParticipantKind", "AI")
	model:SetAttribute("ClearlyLabelledNPC", true)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model

	local function bodyPart(name: string, size: Vector3, color: Color3, offset: CFrame): Part
		local created = Instance.new("Part")
		created.Name = name
		created.Size = size
		created.Color = color
		created.CanCollide = name == "Torso"
		created.CFrame = spawnCFrame * offset
		created.Parent = model
		return created
	end
	local cloth = Color3.fromRGB(52, 123, 122)
	local skin = Color3.fromRGB(166, 119, 82)
	local torso = bodyPart("Torso", Vector3.new(2, 2, 1), cloth, CFrame.new())
	local head = bodyPart("Head", Vector3.new(2, 1, 1), skin, CFrame.new(0, 1.5, 0))
	local leftArm = bodyPart("Left Arm", Vector3.new(1, 2, 1), skin, CFrame.new(-1.5, 0, 0))
	local rightArm = bodyPart("Right Arm", Vector3.new(1, 2, 1), skin, CFrame.new(1.5, 0, 0))
	local leftLeg = bodyPart("Left Leg", Vector3.new(1, 2, 1), cloth, CFrame.new(-0.5, -2, 0))
	local rightLeg = bodyPart("Right Leg", Vector3.new(1, 2, 1), cloth, CFrame.new(0.5, -2, 0))
	root.CFrame = spawnCFrame

	local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame)
		local joint = Instance.new("Motor6D")
		joint.Name = name
		joint.Part0 = part0
		joint.Part1 = part1
		joint.C0 = c0
		joint.C1 = c1
		joint.Parent = part0
	end
	motor("RootJoint", root, torso, CFrame.new(), CFrame.new())
	motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Parent = model
	model.PrimaryPart = root

	local label = Instance.new("BillboardGui")
	label.Name = "GuestLabel"
	label.Size = UDim2.fromOffset(140, 34)
	label.StudsOffset = Vector3.new(0, 2.2, 0)
	label.AlwaysOnTop = true
	label.Parent = head
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(13, 28, 31)
	text.BackgroundTransparency = 0.15
	text.TextColor3 = Color3.fromRGB(160, 231, 216)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Text = "AI RESORT GUEST"
	text.Parent = label
	model.Parent = parent
	root:SetNetworkOwner(nil)
	return model
end

function AIGuestService.new(dependencies: any)
	dependencies._guests = {}
	dependencies._lastThink = 0
	dependencies._folder = nil
	return setmetatable(dependencies, AIGuestService)
end

function AIGuestService:_spawnCFrame(): CFrame
	local worldRoot = workspace:FindFirstChild("LeMorneStormResort")
	local spawn = if worldRoot then worldRoot:FindFirstChild("ArrivalSpawn", true) else nil
	return if spawn and spawn:IsA("BasePart")
		then spawn.CFrame + Vector3.new(0, 3, 0)
		else CFrame.new(0, 6, 0)
end

function AIGuestService:_ensureFolder(): Folder
	if self._folder ~= nil and self._folder.Parent ~= nil then
		return self._folder
	end
	local folder = Instance.new("Folder")
	folder.Name = "AIResortGuests"
	folder.Parent = workspace
	self._folder = folder
	return folder
end

function AIGuestService:_add(now: number)
	local index = #self._guests + 1
	local id = `ai-guest-{index}`
	local model =
		buildGuest(index, self:_ensureFolder(), self:_spawnCFrame() * CFrame.new(index * 2, 0, 0))
	model:SetAttribute("AIState", "SEEK_SAFETY")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = self.Config.AIGuests.WalkSpeed
	end
	self.PlayerStates:Add(id, true)
	table.insert(self._guests, {
		id = id,
		model = model,
		state = "SEEK_SAFETY",
		target = nil,
		finalTarget = nil,
		waypoints = nil,
		waypointIndex = 1,
		lastPosition = model:GetPivot().Position,
		lastProgressAt = now,
		replans = 0,
		failedTargets = {},
		rescueId = nil,
	})
	self.Analytics:Emit("ai_guest_added", { playerId = id, participantKind = "AI" }, now)
end

function AIGuestService:_remove(guest: any, now: number)
	self.Hiding:RemovePlayer(guest.id)
	self.Rescue:CancelByPlayer(guest.id, "AI guest population reduced", now)
	self.PlayerStates:Remove(guest.id)
	guest.model:Destroy()
	self.Analytics:Emit("ai_guest_removed", { playerId = guest.id, participantKind = "AI" }, now)
end

function AIGuestService:Reconcile(now: number)
	local desired = AIGuestPopulation.desiredCount(self.Config, self.Profile, #Players:GetPlayers())
	while #self._guests < desired do
		self:_add(now)
	end
	while #self._guests > desired do
		local guest = table.remove(self._guests)
		self:_remove(guest, now)
	end
end

function AIGuestService:GetParticipantIds(): { string }
	local ids = {}
	for _, player in ipairs(Players:GetPlayers()) do
		table.insert(ids, tostring(player.UserId))
	end
	for _, guest in ipairs(self._guests) do
		table.insert(ids, guest.id)
	end
	return ids
end

function AIGuestService:GetPosition(participantId: string): Vector3?
	for _, guest in ipairs(self._guests) do
		if guest.id == participantId and guest.model.Parent ~= nil then
			return guest.model:GetPivot().Position
		end
	end
	return nil
end

function AIGuestService:_move(guest: any, position: Vector3, now: number): boolean
	local humanoid = guest.model:FindFirstChildOfClass("Humanoid")
	local origin = guest.model:GetPivot().Position
	if (origin - guest.lastPosition).Magnitude >= 0.75 then
		guest.lastPosition = origin
		guest.lastProgressAt = now
	elseif now - guest.lastProgressAt >= self.Config.Hunter.StuckSeconds then
		guest.replans += 1
		guest.finalTarget = nil
		guest.waypoints = nil
		guest.lastProgressAt = now
		guest.model:SetAttribute("StuckReplans", guest.replans)
		if guest.replans > self.Config.Hunter.MaxReplans then
			return false
		end
	end
	if guest.finalTarget == nil or (guest.finalTarget - position).Magnitude >= 4 then
		if guest.finalTarget ~= nil and (guest.finalTarget - position).Magnitude >= 4 then
			guest.replans = 0
		end
		local path = PathfindingService:CreatePath({ AgentRadius = 1.5, AgentHeight = 5 })
		local computed = pcall(path.ComputeAsync, path, origin, position)
		if computed and path.Status == Enum.PathStatus.Success then
			guest.waypoints = path:GetWaypoints()
			guest.waypointIndex = math.min(2, #guest.waypoints)
			guest.model:SetAttribute("LastPathStatus", "Success")
			guest.model:SetAttribute("LastPathWaypointCount", #guest.waypoints)
		else
			guest.waypoints = nil
			guest.waypointIndex = 1
			guest.model:SetAttribute("LastPathStatus", tostring(path.Status))
			guest.model:SetAttribute("LastPathWaypointCount", 0)
			guest.replans += 1
			if guest.replans > self.Config.Hunter.MaxReplans then
				return false
			end
		end
		guest.finalTarget = position
	end
	local waypoint = if guest.waypoints then guest.waypoints[guest.waypointIndex] else nil
	if
		waypoint ~= nil
		and (origin - waypoint.Position).Magnitude <= self.Config.AIGuests.ArrivalDistance
	then
		guest.waypointIndex = math.min(guest.waypointIndex + 1, #guest.waypoints)
		waypoint = guest.waypoints[guest.waypointIndex]
	end
	if humanoid and waypoint ~= nil then
		if waypoint ~= nil and waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
		humanoid:MoveTo(waypoint.Position)
	end
	guest.target = position
	self.Noise:Add({
		category = "Footstep",
		magnitude = self.Config.MovementNoise.BaseMagnitude,
		origin = guest.model:GetPivot().Position,
		sourcePlayerId = guest.id,
		sourceId = "ai-movement",
		hunterRelevant = true,
	}, workspace:GetServerTimeNow())
	return waypoint ~= nil
end

function AIGuestService:_chooseSpot(guest: any, now: number): any?
	local best = nil
	for _, hidingId in ipairs(self.Hiding:GetSpotIds()) do
		local spot = self.Hiding:GetSpot(hidingId)
		if
			self.Hiding:GetOccupancy(hidingId) == 0
			and (guest.failedTargets[hidingId] == nil or now >= guest.failedTargets[hidingId])
		then
			local heat = self.Hiding:GetHeat(hidingId, now)
			if best == nil or heat < best.heat then
				best = { spot = spot, heat = heat }
			end
		end
	end
	return if best then best.spot else nil
end

function AIGuestService:_hide(guest: any, spot: any, now: number)
	local result = self.Hiding:RequestEntry(guest.id, spot.id, now, function()
		return self.PlayerStates:Transition(guest.id, "Hiding", "AI sought safety", now)
	end)
	if result ~= nil then
		setVisible(guest.model, false)
		guest.model:PivotTo(CFrame.new(spot.position))
		guest.state = "HIDE"
		guest.model:SetAttribute("AIState", "HIDE")
		guest.replans = 0
		guest.finalTarget = nil
		guest.waypoints = nil
		self.Noise:Add({
			category = "HidingEntry",
			magnitude = result.noiseMagnitude,
			origin = spot.position,
			sourcePlayerId = guest.id,
			sourceId = spot.id,
			hunterRelevant = true,
		}, now)
		self.Analytics:Emit(
			"player_hid",
			{ playerId = guest.id, hidingId = spot.id, participantKind = "AI" },
			now
		)
	end
end

function AIGuestService:_exit(guest: any, now: number)
	local hidingId = self.Hiding:GetPlayerSpot(guest.id)
	if hidingId ~= nil then
		local spot = self.Hiding:GetSpot(hidingId)
		self.Hiding:Exit(guest.id, hidingId, now)
		self.PlayerStates:Transition(guest.id, "Active", "AI relocated", now)
		setVisible(guest.model, true)
		guest.model:PivotTo(CFrame.new(spot.approachPosition + Vector3.new(0, 2, 0)))
	end
end

function AIGuestService:_tickGuest(guest: any, now: number, phase: string)
	local state = self.PlayerStates:Get(guest.id)
	if state == "Eliminated" or state == "Escaped" or state == "Downed" then
		return
	end
	if state == "Active" or state == "Rescued" then
		local hunter = self.World.Hunters[1]
		if hunter ~= nil and hunter:IsA("Model") then
			local hunterDistance = (guest.model:GetPivot().Position - hunter:GetPivot().Position).Magnitude
			if hunterDistance <= self.Config.Hunter.CaptureDistance then
				self.Capture:Down(guest.id, now, "AI local hunter contact")
				return
			end
		end
	end
	if phase == "Extraction" then
		self:_exit(guest, now)
		guest.state = "ESCAPE"
		guest.model:SetAttribute("AIState", "ESCAPE")
		local extractionId = self.Extraction:GetActiveId()
		local extraction = if extractionId then self.Extraction:Get(extractionId) else nil
		if extraction ~= nil then
			local distance = (guest.model:GetPivot().Position - extraction.position).Magnitude
			if distance <= self.Config.Extraction.MaxDistance then
				local escaped = self.Extraction:Escape(
					guest.id,
					extractionId,
					now,
					distance,
					self.PlayerStates:Get(guest.id)
				)
				if escaped ~= nil then
					self.PlayerStates:Transition(guest.id, "Escaped", "AI extraction", now)
					self.Analytics:Emit(
						"player_escaped",
						{ playerId = guest.id, extractionId = extractionId, participantKind = "AI" },
						now
					)
				end
			else
				self:_move(guest, extraction.position, now)
			end
		end
		return
	end
	local hidingId = self.Hiding:GetPlayerSpot(guest.id)
	if hidingId ~= nil then
		for _, request in ipairs(self.Hiding:GetPendingRequests(hidingId)) do
			local requesterState = self.PlayerStates:Get(request.playerId)
			if requesterState == "Active" or requesterState == "Rescued" then
				local result = self.Hiding:ResolveEntry(guest.id, request.id, true, now, function()
					return self.PlayerStates:Transition(
						request.playerId,
						"Hiding",
						"AI guest admitted survivor",
						now
					)
				end)
				if result ~= nil then
					local player = Players:GetPlayerByUserId(tonumber(request.playerId) or 0)
					if player ~= nil then
						self.Presentation:Hide(player, hidingId)
						self.Remotes.StateSnapshot:FireClient(player, {
							state = "Hiding",
							contextAction = {
								action = "ExitHiding",
								targetField = "hidingId",
								targetId = hidingId,
								label = "EXIT",
							},
							peekAction = { hidingId = hidingId },
						})
					end
					local spot = self.Hiding:GetSpot(hidingId)
					self.Noise:Add({
						category = "HidingEntry",
						magnitude = result.noiseMagnitude,
						origin = spot.position,
						sourcePlayerId = request.playerId,
						sourceId = hidingId,
						hunterRelevant = true,
					}, now)
					self.Analytics:Emit(
						"entry_accepted",
						{ playerId = request.playerId, hidingId = hidingId, acceptedByKind = "AI" },
						now
					)
				end
			end
		end
		if self.Hiding:GetHeat(hidingId, now) >= self.Config.AIGuests.RelocateHeatThreshold then
			self:_exit(guest, now)
			guest.state = "RELOCATE"
			guest.model:SetAttribute("AIState", "RELOCATE")
		else
			guest.state = "HIDE"
			guest.model:SetAttribute("AIState", "HIDE")
		end
		return
	end
	local nearestDowned = nil
	local nearestDistance = math.huge
	for _, player in ipairs(Players:GetPlayers()) do
		local playerId = tostring(player.UserId)
		local position = self.World.GetPlayerPosition(player)
		if self.PlayerStates:Get(playerId) == "Downed" and position ~= nil then
			local distance = (guest.model:GetPivot().Position - position).Magnitude
			if
				distance < nearestDistance
				and distance <= self.Config.AIGuests.RescuePerceptionDistance
			then
				nearestDowned = { id = playerId, position = position }
				nearestDistance = distance
			end
		end
	end
	if nearestDowned ~= nil then
		guest.state = "RESCUE"
		guest.model:SetAttribute("AIState", "RESCUE")
		if nearestDistance > self.Config.Rescue.MaxDistance then
			self:_move(guest, nearestDowned.position, now)
			return
		end
		if guest.rescueId == nil then
			local attempt = self.Rescue:Start(
				guest.id,
				nearestDowned.id,
				now,
				nearestDistance,
				self.PlayerStates:Get(guest.id),
				"Downed"
			)
			if attempt ~= nil then
				guest.rescueId = attempt.id
				self.Analytics:Emit(
					"rescue_attempted",
					{ rescuerId = guest.id, targetId = nearestDowned.id, participantKind = "AI" },
					now
				)
			end
		else
			local attempt = self.Rescue:Get(guest.rescueId)
			if attempt == nil or attempt.status ~= "InProgress" then
				guest.rescueId = nil
			elseif now >= attempt.readyAt then
				local result = self.Rescue:Complete(
					guest.id,
					attempt.id,
					now,
					nearestDistance,
					self.PlayerStates:Get(guest.id),
					"Downed"
				)
				if result ~= nil then
					self.PlayerStates:ResolveDowned(
						nearestDowned.id,
						self.Config.Rescue.CapturesBeforeElimination,
						true,
						now
					)
					self.Capture:Clear(nearestDowned.id)
					self.Analytics:Emit("rescue_completed", {
						rescuerId = guest.id,
						targetId = nearestDowned.id,
						participantKind = "AI",
					}, now)
					self.Remotes.StateSnapshot:FireAllClients({
						playerId = nearestDowned.id,
						state = "Rescued",
					})
					guest.rescueId = nil
				end
			end
		end
		return
	end
	local spot = self:_chooseSpot(guest, now)
	if spot == nil then
		return
	end
	guest.state = if guest.state == "RELOCATE" then "RELOCATE" else "SEEK_SAFETY"
	guest.model:SetAttribute("AIState", guest.state)
	local distance = (guest.model:GetPivot().Position - spot.approachPosition).Magnitude
	if distance <= self.Config.AIGuests.ArrivalDistance then
		self:_hide(guest, spot, now)
	else
		if not self:_move(guest, spot.approachPosition, now) then
			guest.failedTargets[spot.id] = now + self.Config.Hunter.EvidenceMemorySeconds
			guest.replans = 0
			guest.finalTarget = nil
			guest.waypoints = nil
		end
	end
end

function AIGuestService:Tick(now: number, phase: string)
	if now - self._lastThink < self.Config.AIGuests.ThinkInterval then
		return
	end
	self._lastThink = now
	if phase == "Lobby" or phase == "Results" then
		self:Reconcile(now)
		return
	end
	for _, guest in ipairs(self._guests) do
		self:_tickGuest(guest, now, phase)
	end
end

function AIGuestService:ResetRound()
	for _, guest in ipairs(self._guests) do
		setVisible(guest.model, true)
		guest.model:PivotTo(self:_spawnCFrame())
		guest.state = "SEEK_SAFETY"
		guest.model:SetAttribute("AIState", "SEEK_SAFETY")
		guest.target = nil
		guest.finalTarget = nil
		guest.waypoints = nil
		guest.lastPosition = guest.model:GetPivot().Position
		guest.lastProgressAt = workspace:GetServerTimeNow()
		guest.replans = 0
		guest.failedTargets = {}
		guest.rescueId = nil
	end
end

return AIGuestService
