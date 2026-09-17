--!strict

local DoorSystem = {}
DoorSystem.__index = DoorSystem

function DoorSystem.new(config: any)
	local self: any = setmetatable({ _config = config, _doors = {}, _lastHeld = {} }, DoorSystem)
	return self
end

function DoorSystem:ResetRound()
	for _, door in pairs(self._doors) do
		door.heldBy = nil
		door.heldUntil = nil
	end
	self._lastHeld = {}
end

function DoorSystem:Register(doorId: string, position: any): (boolean, string?)
	if type(doorId) ~= "string" or doorId == "" then
		return false, "invalid door id"
	end
	if self._doors[doorId] ~= nil then
		return false, "door already registered"
	end
	self._doors[doorId] = { id = doorId, position = position, heldBy = nil, heldUntil = nil }
	return true, nil
end

function DoorSystem:Hold(playerId: string, doorId: string, now: number): (any?, string?)
	local door = self._doors[doorId]
	if door == nil then
		return nil, "unknown door"
	end
	if door.heldBy ~= nil and door.heldUntil > now and door.heldBy ~= playerId then
		return nil, "door is already held"
	end
	local lastHeld = self._lastHeld[playerId]
	if lastHeld ~= nil and now - lastHeld < self._config.Door.Cooldown then
		return nil, "door hold is on cooldown"
	end

	door.heldBy = playerId
	door.heldUntil = now + self._config.Door.HoldDuration
	self._lastHeld[playerId] = now
	return {
		status = "Held",
		doorId = doorId,
		heldBy = playerId,
		heldUntil = door.heldUntil,
		exposedUntil = door.heldUntil,
		noiseMagnitude = self._config.Door.HoldNoise,
	},
		nil
end

function DoorSystem:Release(playerId: string, doorId: string, now: number): (any?, string?)
	local door = self._doors[doorId]
	if door == nil or door.heldBy ~= playerId then
		return nil, "player is not holding that door"
	end
	door.heldBy = nil
	door.heldUntil = nil
	return { status = "Released", doorId = doorId, releasedAt = now }, nil
end

function DoorSystem:Tick(now: number): { string }
	local released = {}
	for doorId, door in pairs(self._doors) do
		if door.heldBy ~= nil and door.heldUntil <= now then
			door.heldBy = nil
			door.heldUntil = nil
			table.insert(released, doorId)
		end
	end
	return released
end

function DoorSystem:ReleaseByPlayer(playerId: string, _now: number): { string }
	local released = {}
	for doorId, door in pairs(self._doors) do
		if door.heldBy == playerId then
			door.heldBy = nil
			door.heldUntil = nil
			table.insert(released, doorId)
		end
	end
	return released
end

function DoorSystem:Get(doorId: string): any?
	return self._doors[doorId]
end

function DoorSystem:GetHeldByPlayer(playerId: string): string?
	for doorId, door in pairs(self._doors) do
		if door.heldBy == playerId then
			return doorId
		end
	end
	return nil
end

return DoorSystem
