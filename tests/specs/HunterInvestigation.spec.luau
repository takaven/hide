--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local HunterBrain = require("../../src/server/domain/HunterBrain")

local function evidence(id: string): any
	return { id = id, score = 1, origin = { x = 10 }, distance = 0, hidingId = "wardrobe" }
end

return {
	name = "Listener investigation handles arrival, path outcomes, timeout, and reset",
	run = function()
		local brain = HunterBrain.new(Config.Hunter)
		brain:Decide(0, { noises = { evidence("failed") }, heatSources = {} })
		local failed = brain:Decide(
			1,
			{ noises = { evidence("failed") }, heatSources = {}, navigationStatus = "Failed" }
		)
		Assert.equal(failed.state, "SEARCH")
		Assert.equal(failed.reason, "InvestigationUnreachable")
		Assert.falsy(failed.inspectionReady)
		local noLoop = brain:Decide(2, { noises = { evidence("failed") }, heatSources = {} })
		Assert.equal(noLoop.state, "SEARCH")
		local noHeatLoop = brain:Decide(3, {
			noises = {},
			heatSources = {
				{ hidingId = "wardrobe", value = 1, position = { x = 10 }, distance = 0 },
			},
		})
		Assert.equal(noHeatLoop.state, "SEARCH")

		local arrived = HunterBrain.new(Config.Hunter)
		arrived:Decide(0, { noises = { evidence("arrived") }, heatSources = {} })
		local inspection =
			arrived:Decide(1, { noises = {}, heatSources = {}, reachedTarget = true })
		Assert.equal(inspection.state, "SEARCH")
		Assert.truthy(inspection.inspectionReady)
		Assert.equal(inspection.hidingId, "wardrobe")

		local near = HunterBrain.new(Config.Hunter)
		near:Decide(0, { noises = { evidence("near") }, heatSources = {} })
		local completedNear = near:Decide(1, {
			noises = {},
			heatSources = {},
			navigationStatus = "Completed",
			targetDistance = Config.Hunter.InvestigationArrivalDistance,
		})
		Assert.truthy(completedNear.inspectionReady)
		Assert.equal(completedNear.reason, "InvestigationCompletedNearTarget")

		local far = HunterBrain.new(Config.Hunter)
		far:Decide(0, { noises = { evidence("far") }, heatSources = {} })
		local completedFar = far:Decide(1, {
			noises = {},
			heatSources = {},
			navigationStatus = "Completed",
			targetDistance = 100,
		})
		Assert.falsy(completedFar.inspectionReady)
		Assert.equal(completedFar.reason, "InvestigationIncompleteArrival")

		local timed = HunterBrain.new(Config.Hunter)
		timed:Decide(0, { noises = { evidence("timeout") }, heatSources = {} })
		local timeout = timed:Decide(Config.Hunter.InvestigationTimeout, {
			noises = {},
			heatSources = {},
			navigationStatus = "Moving",
		})
		Assert.equal(timeout.state, "SEARCH")
		Assert.equal(timeout.reason, "InvestigationTimeout")

		local cancelled = HunterBrain.new(Config.Hunter)
		cancelled:Decide(0, { noises = { evidence("cancelled") }, heatSources = {} })
		local cancelResult = cancelled:Decide(1, {
			noises = {},
			heatSources = {},
			navigationStatus = "Cancelled",
		})
		Assert.equal(cancelResult.state, "SEARCH")
		Assert.equal(cancelResult.reason, "InvestigationCancelled")

		local reset = HunterBrain.new(Config.Hunter)
		reset:Decide(0, { noises = { evidence("round-reset") }, heatSources = {} })
		Assert.equal(reset:GetState(), "INVESTIGATE")
		reset:Reset()
		Assert.equal(reset:GetState(), "PATROL")
	end,
}
