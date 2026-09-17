--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local ListenerStopPolicy = require("../../src/server/domain/ListenerStopPolicy")
local PrototypeRecap = require("../../src/server/domain/PrototypeRecap")
local StationaryPressure = require("../../src/server/domain/StationaryPressure")

local function stopInput(overrides: any?): any
	local input = {
		brainState = "INVESTIGATE",
		now = 20,
		drawCommitUntil = 0,
		occupancy = 1,
		distance = 12,
		radius = 30,
		cooldownUntil = 0,
	}
	for key, value in pairs(overrides or {}) do
		input[key] = value
	end
	return input
end

return {
	name = "Runtime remediation keeps pressure visible and Listener stops reliable",
	run = function()
		Assert.truthy(ListenerStopPolicy.canStart(stopInput()))
		Assert.falsy(ListenerStopPolicy.canStart(stopInput({ brainState = "CHASE" })))
		Assert.falsy(ListenerStopPolicy.canStart(stopInput({ occupancy = 0 })))
		Assert.falsy(ListenerStopPolicy.canStart(stopInput({ distance = 31 })))
		Assert.falsy(ListenerStopPolicy.canStart(stopInput({ cooldownUntil = 21 })))
		Assert.falsy(ListenerStopPolicy.canStart(stopInput({ drawCommitUntil = 21 })))

		local pressure = StationaryPressure.new(Config.FreeformPressure)
		Assert.equal(pressure:Observe("p1", 0, true, false).stage, "Settling")
		local exposed = pressure:Observe("p1", Config.FreeformPressure.CueSeconds, true, false)
		Assert.equal(exposed.stage, "Exposed")
		Assert.falsy(exposed.emitEvidence)
		local danger = pressure:Observe("p1", Config.FreeformPressure.GraceSeconds, true, false)
		Assert.equal(danger.stage, "Danger")
		Assert.truthy(danger.emitEvidence)
		local clear = pressure:Observe("p1", Config.FreeformPressure.GraceSeconds + 1, true, true)
		Assert.equal(clear.stage, "Clear")

		local recap = PrototypeRecap.new()
		recap:Observe({ name = "breath_broken", properties = {} })
		recap:Observe({ name = "breath_broken", properties = { timeToFirstBreak = 0 } })
		Assert.equal(recap:BuildLines()[1], "The shelters held. This time.")
		recap:Observe({ name = "breath_broken", properties = { timeToFirstBreak = 18.9 } })
		Assert.contains(recap:BuildLines()[1], "18 seconds")
	end,
}
