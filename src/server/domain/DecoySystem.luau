--!strict

local DecoySystem = {}
DecoySystem.__index = DecoySystem

function DecoySystem.new(config: any)
	return setmetatable({ _config = config, _usage = {} }, DecoySystem)
end

function DecoySystem:ResetRound()
	self._usage = {}
end

function DecoySystem:Use(
	playerId: string,
	decoyId: string,
	origin: any,
	now: number,
	playerState: string?
): (any?, string?)
	if playerState ~= "Active" and playerState ~= "Rescued" then
		return nil, "player cannot use a decoy from current state"
	end
	local usage = self._usage[playerId] or { count = 0, lastAt = nil }
	if usage.count >= self._config.Decoy.UsesPerRound then
		return nil, "no decoy uses remaining"
	end
	if usage.lastAt ~= nil and now - usage.lastAt < self._config.Decoy.Cooldown then
		return nil, "decoy is on cooldown"
	end
	usage.count += 1
	usage.lastAt = now
	self._usage[playerId] = usage

	return {
		category = "Decoy",
		magnitude = self._config.Decoy.Magnitude,
		decaySeconds = self._config.Decoy.DecaySeconds,
		origin = origin,
		sourcePlayerId = playerId,
		sourceId = decoyId,
		falseEvidence = true,
		hunterRelevant = true,
	},
		nil
end

return DecoySystem
