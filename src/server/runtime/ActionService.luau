--!strict

local Players = game:GetService("Players")

local ActionService = {}
ActionService.__index = ActionService

function ActionService.new(dependencies: any)
	dependencies._lastPeek = {}
	return setmetatable(dependencies, ActionService)
end

function ActionService:_isNear(
	player: Player,
	position: Vector3,
	maxDistance: number
): (boolean, number?)
	local distance = self.WorldRegistry.DistanceFromPlayer(player, position)
	return distance ~= nil and distance <= maxDistance, distance
end

function ActionService:_noise(
	category: string,
	magnitude: number,
	origin: Vector3,
	playerId: string,
	sourceId: string,
	now: number,
	falseEvidence: boolean?
)
	return self.Noise:Add({
		category = category,
		magnitude = magnitude,
		origin = origin,
		sourcePlayerId = playerId,
		sourceId = sourceId,
		falseEvidence = falseEvidence == true,
		hunterRelevant = true,
	}, now)
end

function ActionService:Handle(player: Player, payload: any, now: number): (any?, string?)
	local playerId = tostring(player.UserId)
	local state = self.PlayerStates:Get(playerId)
	if state == nil then
		return nil, "player is not registered"
	end
	if payload.action == "RequestRematch" then
		if self.Round:GetState() ~= "Results" then
			return nil, "rematch is only available during Results"
		end
		local result, err = self.Rematch:Request(playerId, now)
		if result ~= nil then
			self.Analytics:Emit("rematch_requested", { playerId = playerId }, now)
		end
		return result, err
	elseif payload.action == "InviteFriend" then
		if self.Round:GetState() ~= "Results" then
			return nil, "friend invites are only available during Results"
		end
		self.Analytics:Emit("invite_initiated", { playerId = playerId }, now)
		return { status = "Recorded" }, nil
	elseif payload.action == "OnboardingStep" then
		self.Analytics:Emit(
			"onboarding_step",
			{ playerId = playerId, stepId = payload.stepId },
			now
		)
		return { status = "Recorded" }, nil
	end
	if self.PlayerStates:IsSpectatorOnly(playerId) then
		return nil, "spectators cannot perform gameplay actions"
	end
	local roundState = self.Round:GetState()
	if roundState ~= "Hunt" and roundState ~= "Relocation" and roundState ~= "Extraction" then
		return nil, "gameplay actions are closed in the current round phase"
	end

	if payload.action == "RequestHideEntry" then
		if self.Doors:GetHeldByPlayer(playerId) ~= nil then
			return nil, "release the door before hiding"
		end
		local spot = self.Hiding:GetSpot(payload.hidingId)
		if spot == nil then
			return nil, "unknown hiding spot"
		end
		local near = self:_isNear(player, spot.position, self.Config.Interaction.MaxDistance)
		if not near then
			return nil, "hiding spot is too far away"
		end
		if state ~= "Active" and state ~= "Rescued" then
			return nil, "player cannot hide from current state"
		end
		local result, err = self.Hiding:RequestEntry(playerId, payload.hidingId, now, function()
			local current = self.PlayerStates:Get(playerId)
			if current ~= "Active" and current ~= "Rescued" then
				return false, "player state changed before entry"
			end
			return self.PlayerStates:Transition(playerId, "Hiding", "entered hiding spot", now)
		end)
		if result == nil then
			return nil, err
		end
		if result.status == "Entered" then
			local presented = true
			local presentationError = nil
			if self.Presentation ~= nil then
				presented, presentationError = self.Presentation:Hide(player, spot.id)
			end
			if not presented then
				self.Hiding:Exit(playerId, spot.id)
				self.PlayerStates:Transition(playerId, "Active", "hiding presentation failed", now)
				return nil, presentationError or "hiding presentation failed"
			end
			self:_noise("HidingEntry", result.noiseMagnitude, spot.position, playerId, spot.id, now)
			if self.Audio ~= nil then
				self.Audio:Play("HidingRustle", self.WorldRegistry.Hiding[spot.id].instance)
			end
			self.Analytics:Emit("player_hid", { playerId = playerId, hidingId = spot.id }, now)
			self.Remotes.StateSnapshot:FireClient(player, {
				state = "Hiding",
				contextAction = {
					action = "ExitHiding",
					targetField = "hidingId",
					targetId = spot.id,
					label = "EXIT",
				},
				peekAction = { hidingId = spot.id },
			})
			if self.Hiding:GetOccupancy(spot.id) > 1 then
				self.Analytics:Emit("shared_hiding_started", { hidingId = spot.id }, now)
			end
		else
			self.Analytics:Emit("entry_requested", { playerId = playerId, hidingId = spot.id }, now)
			for _, occupantId in ipairs(self.Hiding:GetOccupants(spot.id)) do
				local userId = tonumber(occupantId)
				local occupant = if userId then Players:GetPlayerByUserId(userId) else nil
				if occupant ~= nil then
					self.Remotes.StateSnapshot:FireClient(occupant, {
						entryRequest = {
							id = result.id,
							requesterId = playerId,
							hidingId = spot.id,
							expiresAt = result.expiresAt,
						},
					})
				end
			end
		end
		return result, nil
	elseif payload.action == "ResolveEntryRequest" then
		local request = self.Hiding:GetRequest(payload.entryRequestId)
		if request == nil then
			return nil, "unknown entry request"
		end
		local spot = self.Hiding:GetSpot(request.hidingId)
		if spot == nil then
			return nil, "unknown hiding spot"
		end
		local near = self:_isNear(player, spot.position, self.Config.Interaction.MaxDistance)
		if not near then
			return nil, "hiding spot is too far away"
		end
		local requesterUserId = tonumber(request.playerId)
		local requester = if requesterUserId
			then Players:GetPlayerByUserId(requesterUserId)
			else nil
		if requester == nil then
			return nil, "requesting player is unavailable"
		end
		local requesterState = self.PlayerStates:Get(request.playerId)
		if requesterState ~= "Active" and requesterState ~= "Rescued" then
			return nil, "requesting player can no longer enter"
		end
		local requesterNear =
			self:_isNear(requester, spot.position, self.Config.Interaction.MaxDistance)
		if not requesterNear then
			return nil, "requesting player moved too far away"
		end
		local result, err = self.Hiding:ResolveEntry(
			playerId,
			payload.entryRequestId,
			payload.accepted,
			now,
			function()
				local current = self.PlayerStates:Get(request.playerId)
				if current ~= "Active" and current ~= "Rescued" then
					return false, "requesting player state changed"
				end
				return self.PlayerStates:Transition(
					request.playerId,
					"Hiding",
					"entry accepted",
					now
				)
			end
		)
		if result == nil then
			return nil, err
		end
		if payload.accepted then
			local presented = true
			local presentationError = nil
			if self.Presentation ~= nil then
				presented, presentationError = self.Presentation:Hide(requester, spot.id)
			end
			if not presented then
				self.Hiding:Exit(request.playerId, spot.id)
				self.PlayerStates:Transition(
					request.playerId,
					"Active",
					"hiding presentation failed",
					now
				)
				return nil, presentationError or "hiding presentation failed"
			end
			self.Analytics:Emit("entry_accepted", { hidingId = spot.id }, now)
			self:_noise(
				"HidingEntry",
				result.noiseMagnitude,
				spot.position,
				request.playerId,
				spot.id,
				now
			)
			self.Analytics:Emit(
				"player_hid",
				{ playerId = request.playerId, hidingId = spot.id },
				now
			)
			self.Analytics:Emit("shared_hiding_started", { hidingId = spot.id }, now)
			self.Remotes.StateSnapshot:FireClient(requester, {
				state = "Hiding",
				contextAction = {
					action = "ExitHiding",
					targetField = "hidingId",
					targetId = spot.id,
					label = "EXIT",
				},
				peekAction = { hidingId = spot.id },
			})
		else
			self.Analytics:Emit("entry_refused", {
				hidingId = spot.id,
				playerId = request.playerId,
				refusedBy = playerId,
			}, now)
			self:_noise("Environment", result.noiseMagnitude, spot.position, playerId, spot.id, now)
		end
		for _, occupantId in ipairs(self.Hiding:GetOccupants(spot.id)) do
			local userId = tonumber(occupantId)
			local occupant = if userId then Players:GetPlayerByUserId(userId) else nil
			if occupant ~= nil then
				self.Remotes.StateSnapshot:FireClient(occupant, { clearEntryRequest = true })
			end
		end
		return result, nil
	elseif payload.action == "ExitHiding" then
		if state ~= "Hiding" then
			return nil, "player is not hiding"
		end
		local spot = self.Hiding:GetSpot(payload.hidingId)
		if spot == nil then
			return nil, "unknown hiding spot"
		end
		local result, err = self.Hiding:Exit(playerId, payload.hidingId, now)
		if result == nil then
			return nil, err
		end
		if self.Presentation ~= nil then
			self.Presentation:Reveal(player, payload.hidingId)
		end
		self.PlayerStates:Transition(playerId, "Active", "left hiding spot", now)
		self.Remotes.StateSnapshot:FireClient(player, {
			state = "Active",
			clearContext = true,
			clearPeek = true,
		})
		self:_noise("HidingExit", result.noiseMagnitude, spot.position, playerId, spot.id, now)
		if self.Audio ~= nil then
			self.Audio:Play("HidingRustle", self.WorldRegistry.Hiding[spot.id].instance)
		end
		self.Analytics:Emit("hiding_exited", {
			playerId = playerId,
			hidingId = spot.id,
			duration = result.duration,
			occupancy = result.occupancyAfter,
		}, now)
		return result, nil
	elseif payload.action == "PeekHiding" then
		if state ~= "Hiding" or self.Hiding:GetPlayerSpot(playerId) ~= payload.hidingId then
			return nil, "player is not hiding there"
		end
		local record = self.WorldRegistry.Hiding[payload.hidingId]
		if record == nil or record.peekCFrame == nil then
			return nil, "hiding view is unavailable"
		end
		local lastPeek = self._lastPeek[playerId] or -math.huge
		if payload.enabled and now - lastPeek < self.Config.Hiding.PeekCooldown then
			return nil, "peek is cooling down"
		end
		if payload.enabled then
			self._lastPeek[playerId] = now
			self.Hiding:AddRecentNoise(payload.hidingId, self.Config.Hiding.PeekNoise)
			self:_noise(
				"HidingEntry",
				self.Config.Hiding.PeekNoise,
				record.position,
				playerId,
				record.id,
				now
			)
		end
		self.Remotes.StateSnapshot:FireClient(player, {
			peek = { enabled = payload.enabled, cframe = record.peekCFrame },
		})
		return { status = if payload.enabled then "Peeking" else "Hidden" }, nil
	elseif payload.action == "HoldDoor" or payload.action == "ReleaseDoor" then
		if state ~= "Active" and state ~= "Rescued" then
			return nil, "player cannot operate a door from current state"
		end
		local door = self.Doors:Get(payload.doorId)
		if door == nil then
			return nil, "unknown door"
		end
		local near = self:_isNear(player, door.position, self.Config.Interaction.MaxDistance)
		if not near then
			return nil, "door is too far away"
		end
		if payload.action == "HoldDoor" then
			local result, err = self.Doors:Hold(playerId, payload.doorId, now)
			if result then
				self:_noise("Door", result.noiseMagnitude, door.position, playerId, door.id, now)
				self.Analytics:Emit(
					"brace_door_used",
					{ playerId = playerId, doorId = door.id },
					now
				)
				self.Remotes.StateSnapshot:FireClient(player, {
					contextAction = {
						action = "ReleaseDoor",
						targetField = "doorId",
						targetId = door.id,
						label = "LET GO",
					},
					doorHolding = { doorId = door.id, exposedUntil = result.exposedUntil },
				})
			end
			return result, err
		end
		local result, err = self.Doors:Release(playerId, payload.doorId, now)
		if result then
			self.Remotes.StateSnapshot:FireClient(
				player,
				{ clearContext = true, clearDoorHolding = true }
			)
		end
		return result, err
	elseif payload.action == "StartRescue" then
		local targetUserId = tonumber(payload.targetPlayerId)
		local target = if targetUserId then Players:GetPlayerByUserId(targetUserId) else nil
		if target == nil then
			return nil, "target player is unavailable"
		end
		local rescuerPosition = self.WorldRegistry.GetPlayerPosition(player)
		local targetPosition = self.WorldRegistry.GetPlayerPosition(target)
		if rescuerPosition == nil or targetPosition == nil then
			return nil, "player position is unavailable"
		end
		local distance = (rescuerPosition - targetPosition).Magnitude
		local result, err = self.Rescue:Start(
			playerId,
			payload.targetPlayerId,
			now,
			distance,
			state,
			self.PlayerStates:Get(payload.targetPlayerId)
		)
		if result then
			self.Analytics:Emit(
				"rescue_attempted",
				{ rescuerId = playerId, targetId = payload.targetPlayerId },
				now
			)
			if self.Audio ~= nil then
				self.Audio:Play("Rescue", target.Character)
			end
		end
		return result, err
	elseif payload.action == "CompleteRescue" then
		local attempt = self.Rescue:Get(payload.rescueId)
		if attempt == nil then
			return nil, "unknown rescue"
		end
		local targetUserId = tonumber(attempt.targetId)
		local target = if targetUserId then Players:GetPlayerByUserId(targetUserId) else nil
		if target == nil then
			return nil, "target player is unavailable"
		end
		local rescuerPosition = self.WorldRegistry.GetPlayerPosition(player)
		local targetPosition = self.WorldRegistry.GetPlayerPosition(target)
		if rescuerPosition == nil or targetPosition == nil then
			return nil, "player position is unavailable"
		end
		local distance = (rescuerPosition - targetPosition).Magnitude
		local result, err = self.Rescue:Complete(
			playerId,
			payload.rescueId,
			now,
			distance,
			state,
			self.PlayerStates:Get(attempt.targetId)
		)
		if result then
			self.PlayerStates:ResolveDowned(
				attempt.targetId,
				self.Config.Rescue.CapturesBeforeElimination,
				true,
				now
			)
			self.Capture:Clear(attempt.targetId)
			self.Remotes.StateSnapshot:FireAllClients({
				playerId = attempt.targetId,
				state = "Rescued",
			})
			self:_noise(
				"Rescue",
				result.noiseMagnitude,
				targetPosition,
				playerId,
				result.rescueId,
				now
			)
			self.Analytics:Emit(
				"rescue_completed",
				{ rescuerId = playerId, targetId = attempt.targetId },
				now
			)
		end
		return result, err
	elseif payload.action == "UseDecoy" then
		local origin = self.WorldRegistry.GetPlayerPosition(player)
		if origin == nil then
			return nil, "player position is unavailable"
		end
		local noiseInput, err = self.Decoys:Use(playerId, payload.decoyId, origin, now, state)
		if noiseInput == nil then
			return nil, err
		end
		local event = self.Noise:Add(noiseInput, now)
		if self.Audio ~= nil then
			self.Audio:Play("DecoyClick", player.Character)
		end
		self.Analytics:Emit("decoy_used", { playerId = playerId, decoyId = payload.decoyId }, now)
		return { status = "Used", evidenceId = event and event.id }, nil
	elseif payload.action == "Escape" then
		local point = self.Extraction:Get(payload.extractionId)
		if point == nil then
			return nil, "unknown extraction point"
		end
		local near, distance =
			self:_isNear(player, point.position, self.Config.Extraction.MaxDistance)
		if not near or distance == nil then
			return nil, "extraction point is too far away"
		end
		local result, err =
			self.Extraction:Escape(playerId, payload.extractionId, now, distance, state)
		if result then
			self.PlayerStates:Transition(playerId, "Escaped", "extracted", now)
			self.Remotes.StateSnapshot:FireClient(
				player,
				{ state = "Escaped", clearContext = true }
			)
			self.Analytics:Emit(
				"player_escaped",
				{ playerId = playerId, extractionId = payload.extractionId },
				now
			)
		end
		return result, err
	end

	return nil, "action is not implemented"
end

return ActionService
