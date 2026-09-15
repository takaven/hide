--!strict

local SharedSilence = if script
	then require(script.Parent.SharedSilence)
	else require("./SharedSilence")
local HidingHeat = if script then require(script.Parent.HidingHeat) else require("./HidingHeat")

local HidingSystem = {}
HidingSystem.__index = HidingSystem

local function count(dictionary: { [string]: boolean }): number
	local total = 0
	for _ in pairs(dictionary) do
		total += 1
	end
	return total
end

function HidingSystem.new(config: any)
	return setmetatable({
		_config = config,
		_spots = {},
		_playerSpot = {},
		_requests = {},
		_nextRequestId = 0,
		_heat = HidingHeat.new(config.HidingHeat),
	}, HidingSystem)
end

function HidingSystem:Register(
	hidingId: string,
	capacity: number?,
	position: any
): (boolean, string?)
	if type(hidingId) ~= "string" or hidingId == "" then
		return false, "invalid hiding id"
	end
	if self._spots[hidingId] ~= nil then
		return false, "hiding spot already registered"
	end
	local resolvedCapacity = capacity or self._config.Hiding.DefaultCapacity
	if type(resolvedCapacity) ~= "number" or resolvedCapacity < 1 or resolvedCapacity % 1 ~= 0 then
		return false, "capacity must be a positive integer"
	end

	self._spots[hidingId] = {
		id = hidingId,
		capacity = resolvedCapacity,
		position = position,
		occupants = {},
		recentNoise = 0,
		movementFactor = 0,
	}
	return true, nil
end

function HidingSystem:GetSpot(hidingId: string): any?
	return self._spots[hidingId]
end

function HidingSystem:GetPlayerSpot(playerId: string): string?
	return self._playerSpot[playerId]
end

function HidingSystem:GetRequest(requestId: string): any?
	return self._requests[requestId]
end

function HidingSystem:GetOccupancy(hidingId: string): number
	local spot = self._spots[hidingId]
	return if spot then count(spot.occupants) else 0
end

function HidingSystem:GetSpotIds(): { string }
	local ids = {}
	for hidingId in pairs(self._spots) do
		table.insert(ids, hidingId)
	end
	table.sort(ids)
	return ids
end

function HidingSystem:GetOccupants(hidingId: string): { string }
	local occupants = {}
	local spot = self._spots[hidingId]
	if spot ~= nil then
		for playerId in pairs(spot.occupants) do
			table.insert(occupants, playerId)
		end
	end
	return occupants
end

function HidingSystem:_enter(playerId: string, spot: any, now: number): any
	spot.occupants[playerId] = true
	self._playerSpot[playerId] = spot.id
	self._heat:RecordUse(spot.id, now)
	spot.recentNoise = math.min(1, spot.recentNoise + self._config.Hiding.EntryNoise)
	return {
		status = "Entered",
		hidingId = spot.id,
		noiseMagnitude = self._config.Hiding.EntryNoise,
	}
end

function HidingSystem:_expireRequests(now: number)
	for _, request in pairs(self._requests) do
		if request.status == "Pending" and now > request.expiresAt then
			request.status = "Expired"
		end
	end
end

function HidingSystem:RequestEntry(playerId: string, hidingId: string, now: number): (any?, string?)
	self:_expireRequests(now)
	local spot = self._spots[hidingId]
	if spot == nil then
		return nil, "unknown hiding spot"
	end
	if self._playerSpot[playerId] ~= nil then
		return nil, "player is already hiding"
	end
	local occupancy = count(spot.occupants)
	if occupancy >= spot.capacity then
		return nil, "hiding spot is full"
	end
	if occupancy == 0 then
		return self:_enter(playerId, spot, now), nil
	end

	for _, request in pairs(self._requests) do
		if request.playerId == playerId and request.status == "Pending" then
			return nil, "player already has a pending entry request"
		end
	end

	self._nextRequestId += 1
	local request = {
		id = `entry-{self._nextRequestId}`,
		playerId = playerId,
		hidingId = hidingId,
		createdAt = now,
		expiresAt = now + self._config.Interaction.RequestLifetime,
		status = "Pending",
	}
	self._requests[request.id] = request
	return request, nil
end

function HidingSystem:ResolveEntry(
	occupantPlayerId: string,
	requestId: string,
	accepted: boolean,
	now: number
): (any?, string?)
	self:_expireRequests(now)
	local request = self._requests[requestId]
	if request == nil then
		return nil, "entry request is not pending"
	end
	if request.status == "Expired" then
		return nil, "entry request expired"
	end
	if request.status ~= "Pending" then
		return nil, "entry request is not pending"
	end
	local spot = self._spots[request.hidingId]
	if spot == nil or spot.occupants[occupantPlayerId] ~= true then
		return nil, "only a current occupant can resolve this request"
	end

	if not accepted then
		request.status = "Refused"
		spot.recentNoise = math.min(1, spot.recentNoise + self._config.Hiding.RefusalNoise)
		return {
			status = "Refused",
			requestId = requestId,
			noiseMagnitude = self._config.Hiding.RefusalNoise,
		},
			nil
	end

	if self._playerSpot[request.playerId] ~= nil then
		request.status = "Cancelled"
		return nil, "requesting player is already hiding"
	end
	if count(spot.occupants) >= spot.capacity then
		request.status = "RejectedFull"
		return nil, "hiding spot became full"
	end

	request.status = "Accepted"
	local result = self:_enter(request.playerId, spot, now)
	result.requestId = requestId
	return result, nil
end

function HidingSystem:Exit(playerId: string, hidingId: string): (any?, string?)
	local spot = self._spots[hidingId]
	if
		spot == nil
		or self._playerSpot[playerId] ~= hidingId
		or spot.occupants[playerId] ~= true
	then
		return nil, "player is not in that hiding spot"
	end
	spot.occupants[playerId] = nil
	self._playerSpot[playerId] = nil
	spot.recentNoise = math.min(1, spot.recentNoise + self._config.Hiding.ExitNoise)
	return {
		status = "Exited",
		hidingId = hidingId,
		noiseMagnitude = self._config.Hiding.ExitNoise,
	},
		nil
end

function HidingSystem:Tick(
	hidingId: string,
	elapsed: number,
	now: number,
	movementFactor: number?
): any?
	local spot = self._spots[hidingId]
	if spot == nil then
		return nil
	end
	spot.recentNoise =
		math.max(0, spot.recentNoise - elapsed / self._config.Noise.DefaultDecaySeconds)
	spot.movementFactor = math.max(0, math.min(1, movementFactor or 0))
	local occupancy = count(spot.occupants)
	local heat = if occupancy > 0
		then self._heat:TickOccupied(hidingId, occupancy, elapsed, now)
		else self._heat:Get(hidingId, now)
	return SharedSilence.evaluate(
		occupancy,
		spot.recentNoise,
		spot.movementFactor,
		heat,
		self._config.Hiding
	)
end

function HidingSystem:GetHeat(hidingId: string, now: number): number
	return self._heat:Get(hidingId, now)
end

return HidingSystem
