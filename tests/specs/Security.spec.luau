--!strict

local Assert = require("../Assert")
local ActionValidator = require("../../src/server/domain/ActionValidator")
local Config = require("../../src/shared/Config")
local RateLimiter = require("../../src/server/domain/RateLimiter")
local ReplayGuard = require("../../src/server/domain/ReplayGuard")

return {
	name = "remote schemas, replay defense, and per-action limits fail closed",
	run = function()
		local valid = ActionValidator.validate({
			action = "ResolveEntryRequest",
			requestId = "req-1",
			entryRequestId = "entry-1",
			accepted = false,
		}, Config.Security)
		Assert.truthy(valid)
		Assert.falsy(
			ActionValidator.validate(
				{ action = "Teleport", requestId = "1", target = "x" },
				Config.Security
			)
		)
		Assert.falsy(ActionValidator.validate({
			action = "HoldDoor",
			requestId = "req-2",
			doorId = "door-1",
			reward = 999999,
		}, Config.Security))
		Assert.falsy(ActionValidator.validate({
			action = "ResolveEntryRequest",
			requestId = "req-3",
			entryRequestId = "entry-1",
			accepted = "yes",
		}, Config.Security))

		local limiter = RateLimiter.new({ Ping = { Limit = 2, WindowSeconds = 5 } })
		Assert.truthy(limiter:Allow("p1", "Ping", 0))
		Assert.truthy(limiter:Allow("p1", "Ping", 1))
		Assert.falsy(limiter:Allow("p1", "Ping", 2))
		Assert.truthy(limiter:Allow("p1", "Ping", 6))
		Assert.falsy(limiter:Allow("p1", "Unknown", 6))

		local replay = ReplayGuard.new(10)
		Assert.truthy(replay:Accept("p1", "request-1", 0))
		Assert.falsy(replay:Accept("p1", "request-1", 1))
		Assert.truthy(replay:Accept("p1", "request-1", 11))
		Assert.truthy(replay:Accept("p2", "request-1", 1))
	end,
}
