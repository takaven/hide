--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local DoorSystem = require("../../src/server/domain/DoorSystem")
local ExtractionSystem = require("../../src/server/domain/ExtractionSystem")
local RescueSystem = require("../../src/server/domain/RescueSystem")

return {
	name = "Hold the Door, rescue, and extraction enforce time, distance, and state",
	run = function()
		local doors = DoorSystem.new(Config)
		Assert.truthy(doors:Register("service-door", { x = 0 }))
		local held = doors:Hold("p1", "service-door", 0)
		Assert.equal(held.status, "Held")
		Assert.truthy(held.exposedUntil > 0)
		local stolen, stolenError = doors:Hold("p2", "service-door", 1)
		Assert.equal(stolen, nil)
		Assert.contains(stolenError, "already held")
		Assert.equal(#doors:Tick(Config.Door.HoldDuration + 0.1), 1)
		Assert.truthy(doors:Hold("p2", "service-door", 5))

		local rescue = RescueSystem.new(Config)
		local attempt = rescue:Start("p1", "p2", 0, 5, "Active", "Downed")
		Assert.truthy(attempt)
		local early, earlyError = rescue:Complete("p1", attempt.id, 1, 5, "Active", "Downed")
		Assert.equal(early, nil)
		Assert.contains(earlyError, "not elapsed")
		local completed =
			rescue:Complete("p1", attempt.id, Config.Rescue.Duration, 5, "Active", "Downed")
		Assert.equal(completed.status, "Completed")
		Assert.truthy(completed.noiseMagnitude > 0)
		local selfRescue = rescue:Start("p1", "p1", 10, 0, "Active", "Downed")
		Assert.equal(selfRescue, nil)

		local extraction = ExtractionSystem.new(Config)
		Assert.truthy(extraction:Register("lobby-exit", { x = 0 }))
		Assert.equal(extraction:Escape("p1", "lobby-exit", 0, 1, "Active"), nil)
		extraction:Open(10)
		Assert.equal(extraction:Escape("p1", "lobby-exit", 11, 1, "Hiding"), nil)
		local escaped = extraction:Escape("p1", "lobby-exit", 11, 1, "Active")
		Assert.equal(escaped.status, "Escaped")
		Assert.equal(extraction:Escape("p2", "lobby-exit", 11, 100, "Active"), nil)
	end,
}
