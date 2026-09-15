--!strict

local HidingHeat = {}
HidingHeat.__index = HidingHeat

function HidingHeat.new(config: any)
	return setmetatable({ _config = config, _records = {} }, HidingHeat)
end

function HidingHeat:_valueAt(record: any, now: number): number
	local elapsed = math.max(0, now - record.updatedAt)
	return math.max(0, record.value - elapsed * self._config.DecayPerSecond)
end

function HidingHeat:Get(hidingId: string, now: number): number
	local record = self._records[hidingId]
	if record == nil then
		return 0
	end
	return self:_valueAt(record, now)
end

function HidingHeat:RecordUse(hidingId: string, now: number): number
	local current = self:Get(hidingId, now)
	local value = math.min(self._config.Maximum, current + self._config.UseIncrease)
	self._records[hidingId] = { value = value, updatedAt = now }
	return value
end

function HidingHeat:TickOccupied(
	hidingId: string,
	occupancy: number,
	elapsed: number,
	now: number
): number
	local current = self:Get(hidingId, now - elapsed)
	local value = math.min(
		self._config.Maximum,
		current
			+ math.max(0, occupancy)
				* math.max(0, elapsed)
				* self._config.OccupancyIncreasePerSecond
	)
	self._records[hidingId] = { value = value, updatedAt = now }
	return value
end

return HidingHeat
