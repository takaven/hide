--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local HunterBrain = require("../../src/server/domain/HunterBrain")
local NavigationProvider = require("../../src/server/runtime/NavigationProvider")

local function evidence(id: string): any
	return { id = id, score = 1, origin = { x = 10 }, distance = 0, hidingId = "wardrobe" }
end

return {
	name = "Listener investigation handles arrival, path outcomes, timeout, and reset",
	run = function()
		local providerMethods = {
			MoveTo = function() end,
			Cancel = function() end,
			GetStatus = function()
				return "Completed", 7
			end,
		}
		Assert.truthy(NavigationProvider.validate(providerMethods))
		local noGeneration = table.clone(providerMethods)
		noGeneration.GetStatus = function()
			return "Completed"
		end
		Assert.falsy(NavigationProvider.validate(noGeneration))

		local brain = HunterBrain.new(Config.Hunter)
		brain:Decide(0, { noises = { evidence("failed") }, heatSources = {} })
		brain:BindInvestigationNavigation(1)
		local failed = brain:Decide(1, {
			noises = { evidence("failed") },
			heatSources = {},
			navigationStatus = "Failed",
			navigationGeneration = 1,
		})
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
		arrived:BindInvestigationNavigation(2)
		local inspection = arrived:Decide(
			1,
			{ noises = {}, heatSources = {}, reachedTarget = true, navigationGeneration = 2 }
		)
		Assert.equal(inspection.state, "SEARCH")
		Assert.truthy(inspection.inspectionReady)
		Assert.equal(inspection.hidingId, "wardrobe")

		local near = HunterBrain.new(Config.Hunter)
		near:Decide(0, { noises = { evidence("near") }, heatSources = {} })
		near:BindInvestigationNavigation(3)
		local completedNear = near:Decide(1, {
			noises = {},
			heatSources = {},
			navigationStatus = "Completed",
			navigationGeneration = 3,
			targetDistance = Config.Hunter.InvestigationArrivalDistance,
		})
		Assert.truthy(completedNear.inspectionReady)
		Assert.equal(completedNear.reason, "InvestigationCompletedNearTarget")

		local far = HunterBrain.new(Config.Hunter)
		far:Decide(0, { noises = { evidence("far") }, heatSources = {} })
		far:BindInvestigationNavigation(4)
		local completedFar = far:Decide(1, {
			noises = {},
			heatSources = {},
			navigationStatus = "Completed",
			navigationGeneration = 4,
			targetDistance = 100,
		})
		Assert.falsy(completedFar.inspectionReady)
		Assert.equal(completedFar.reason, "InvestigationIncompleteArrival")

		local timed = HunterBrain.new(Config.Hunter)
		timed:Decide(0, { noises = { evidence("timeout") }, heatSources = {} })
		timed:BindInvestigationNavigation(5)
		local timeout = timed:Decide(Config.Hunter.InvestigationTimeout, {
			noises = {},
			heatSources = {},
			navigationStatus = "Moving",
			navigationGeneration = 5,
		})
		Assert.equal(timeout.state, "SEARCH")
		Assert.equal(timeout.reason, "InvestigationTimeout")

		local cancelled = HunterBrain.new(Config.Hunter)
		cancelled:Decide(0, { noises = { evidence("cancelled") }, heatSources = {} })
		cancelled:BindInvestigationNavigation(6)
		local cancelResult = cancelled:Decide(1, {
			noises = {},
			heatSources = {},
			navigationStatus = "Cancelled",
			navigationGeneration = 6,
		})
		Assert.equal(cancelResult.state, "SEARCH")
		Assert.equal(cancelResult.reason, "InvestigationCancelled")

		local stale = HunterBrain.new(Config.Hunter)
		stale:Decide(0, {
			noises = { evidence("new-target") },
			heatSources = {},
			navigationStatus = "Completed",
			navigationGeneration = 40,
		})
		stale:BindInvestigationNavigation(41)
		local ignoredCompletion = stale:Decide(1, {
			noises = {},
			heatSources = {},
			reachedTarget = true,
			targetDistance = 0,
			navigationStatus = "Completed",
			navigationGeneration = 40,
		})
		Assert.equal(ignoredCompletion.state, "INVESTIGATE")
		Assert.falsy(ignoredCompletion.inspectionReady)
		local currentCompletion = stale:Decide(2, {
			noises = {},
			heatSources = {},
			targetDistance = 0,
			navigationStatus = "Completed",
			navigationGeneration = 41,
		})
		Assert.equal(currentCompletion.state, "SEARCH")
		Assert.truthy(currentCompletion.inspectionReady)

		local reset = HunterBrain.new(Config.Hunter)
		reset:Decide(0, { noises = { evidence("round-reset") }, heatSources = {} })
		Assert.equal(reset:GetState(), "INVESTIGATE")
		reset:Reset()
		Assert.equal(reset:GetState(), "PATROL")
	end,
}
