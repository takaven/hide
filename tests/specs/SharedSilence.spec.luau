--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local SharedSilence = require("../../src/server/domain/SharedSilence")

return {
	name = "Shared Silence makes crowding and movement materially dangerous",
	run = function()
		local empty = SharedSilence.evaluate(0, 0, 0, 0, Config.Hiding)
		local solo = SharedSilence.evaluate(1, 0, 0, 0, Config.Hiding)
		local pair = SharedSilence.evaluate(2, 0, 0, 0, Config.Hiding)
		local crowd = SharedSilence.evaluate(3, 0, 0.5, 0, Config.Hiding)
		Assert.equal(empty.risk, 0)
		Assert.equal(solo.state, "Safe")
		Assert.truthy(pair.risk > solo.risk)
		Assert.equal(crowd.state, "Unstable")

		local broken = SharedSilence.evaluate(3, 1, 1, 1, Config.Hiding)
		Assert.equal(broken.state, "Broken")
		Assert.equal(broken.risk, 1)
		Assert.near(
			broken.occupancyRisk,
			Config.Hiding.BaseRisk + 2 * Config.Hiding.AdditionalOccupantRisk,
			0.0001
		)
	end,
}
