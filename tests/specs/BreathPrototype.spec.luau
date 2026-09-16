--!strict

local Assert = require("../Assert")
local ActionValidator = require("../../src/shared/ActionValidator")
local BreathPressure = require("../../src/server/domain/BreathPressure")
local Config = require("../../src/shared/Config")
local ConfigValidator = require("../../src/shared/ConfigValidator")
local HidingSystem = require("../../src/server/domain/HidingSystem")
local StationaryPressure = require("../../src/server/domain/StationaryPressure")

local function timeToBreak(occupancy: number): (number, number)
	local level = 0
	local now = 0
	local obviousAt = 0
	while level < Config.Breath.Maximum and now < 90 do
		local multiplier = if now >= 15 and now < 21
			then Config.ListenerStop.BreathMultiplier
			else 1
		local result = BreathPressure.advance(level, occupancy, 0.25, multiplier, Config.Breath)
		level = result.level
		now += 0.25
		if obviousAt == 0 and level >= Config.Breath.WarningThreshold then
			obviousAt = now
		end
	end
	return now, obviousAt
end

return {
	name = "Breath and The Stop force an occupancy-scaled break-and-run decision",
	run = function()
		local priorRate = 0
		local priorBreak = math.huge
		for occupancy = 1, 4 do
			local rate = BreathPressure.rateForOccupancy(occupancy, Config.Breath)
			local breaksAt, obviousAt = timeToBreak(occupancy)
			Assert.truthy(rate > priorRate)
			Assert.truthy(breaksAt < priorBreak)
			Assert.truthy(obviousAt > 0 and obviousAt < breaksAt)
			Assert.truthy(breaksAt <= 60, `occupancy {occupancy} broke at {breaksAt}`)
			priorRate = rate
			priorBreak = breaksAt
		end

		local normal = BreathPressure.advance(0, 1, 6, 1, Config.Breath)
		local stopped =
			BreathPressure.advance(0, 1, 6, Config.ListenerStop.BreathMultiplier, Config.Breath)
		Assert.near(stopped.level, normal.level * 3, 0.0001)

		local hiding = HidingSystem.new(Config)
		hiding:Register("proof-shelter", 4, { x = 0 })
		hiding:RequestEntry("p1", "proof-shelter", 0)
		hiding:Tick("proof-shelter", 20, 20, 0)
		local beforeExit = hiding:GetBreath("proof-shelter")
		hiding:Exit("p1", "proof-shelter", 20)
		Assert.truthy(beforeExit > 0)
		Assert.equal(hiding:GetBreath("proof-shelter"), 0)

		local pressure = StationaryPressure.new(Config.FreeformPressure)
		Assert.equal(pressure:Observe("runner", 0, true, false), nil)
		Assert.equal(pressure:Observe("runner", 11.9, true, false), nil)
		local evidence = pressure:Observe("runner", 12, true, false)
		Assert.truthy(evidence ~= nil)
		Assert.equal(pressure:Observe("runner", 12.1, true, true), nil)

		local invalid = table.clone(Config)
		invalid.Breath = table.clone(Config.Breath)
		invalid.Breath.OccupancyMultipliers = { 1, 1, 2, 3 }
		Assert.falsy(ConfigValidator.validate(invalid))
		local invalidStop = table.clone(Config)
		invalidStop.ListenerStop = table.clone(Config.ListenerStop)
		invalidStop.ListenerStop.BreathMultiplier = 1
		Assert.falsy(ConfigValidator.validate(invalidStop))

		for _, action in ipairs({ "SetBreath", "SetSafe", "ForceStop", "BypassBreak" }) do
			local valid = ActionValidator.validate({
				action = action,
				requestId = `forged-{action}`,
			}, Config.Security)
			Assert.falsy(valid)
		end
		Assert.falsy(Config.Prototype.EvictEnabled)
		Assert.falsy(Config.Prototype.VoicePressureEnabled)
		Assert.falsy(Config.Prototype.AIGuestsEnabled)
		Assert.falsy(Config.Prototype.MovieMomentsEnabled)
	end,
}
