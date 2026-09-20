--!strict

local SoakMetricsService = {}
SoakMetricsService.__index = SoakMetricsService

function SoakMetricsService.new(hiding: any, noise: any, analytics: any)
	return setmetatable({
		_hiding = hiding,
		_noise = noise,
		_analytics = analytics,
		_lastSample = -math.huge,
		_samples = 0,
		_occupancyTotal = 0,
		_peakNoise = 0,
	}, SoakMetricsService)
end

function SoakMetricsService:Tick(now: number)
	if now - self._lastSample < 1 then
		return
	end
	self._lastSample = now
	local occupancy = 0
	for _, hidingId in ipairs(self._hiding:GetSpotIds()) do
		occupancy += self._hiding:GetOccupancy(hidingId)
	end
	self._samples += 1
	self._occupancyTotal += occupancy
	self._peakNoise = math.max(self._peakNoise, self._noise:GetEventCount(now))
end

function SoakMetricsService:GetReport(): any
	local events = {}
	for _, envelope in ipairs(self._analytics:GetBuffered()) do
		events[envelope.name] = (events[envelope.name] or 0) + 1
	end
	return {
		events = events,
		averageHidingOccupancy = if self._samples > 0
			then self._occupancyTotal / self._samples
			else 0,
		peakNoiseLedgerSize = self._peakNoise,
		samples = self._samples,
	}
end

function SoakMetricsService:ResetRound()
	self._lastSample = -math.huge
	self._samples = 0
	self._occupancyTotal = 0
	self._peakNoise = 0
end

return SoakMetricsService
