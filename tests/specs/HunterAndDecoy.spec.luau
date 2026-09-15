--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local DecoySystem = require("../../src/server/domain/DecoySystem")
local HunterBrain = require("../../src/server/domain/HunterBrain")

return {
	name = "The Listener prioritizes sight, then real-or-false evidence, then search",
	run = function()
		local decoys = DecoySystem.new(Config)
		local decoy = decoys:Use("p1", "decoy-1", { x = 12 }, 0, "Active")
		Assert.truthy(decoy.falseEvidence)
		Assert.equal(decoy.category, "Decoy")
		local second, secondError = decoys:Use("p1", "decoy-2", { x = 1 }, 20, "Active")
		Assert.equal(second, nil)
		Assert.contains(secondError, "remaining")
		decoys:ResetRound()
		Assert.truthy(decoys:Use("p1", "decoy-3", { x = 2 }, 21, "Active"))
		Assert.equal(decoys:Use("downed", "decoy-4", {}, 0, "Downed"), nil)

		local brain = HunterBrain.new(Config.Hunter)
		Assert.equal(brain:GetState(), "PATROL")
		local investigated = brain:Decide(0, {
			noises = { { id = "noise-1", score = 1, origin = { x = 10 }, distance = 0 } },
			heatSources = {},
		})
		Assert.equal(investigated.state, "INVESTIGATE")
		Assert.equal(investigated.reason, "Noise")

		local searching = brain:Decide(1, { noises = {}, heatSources = {}, reachedTarget = true })
		Assert.equal(searching.state, "SEARCH")
		local returning =
			brain:Decide(20, { noises = {}, heatSources = {}, patrolReturnPosition = { x = 0 } })
		Assert.equal(returning.state, "RETURN")
		local patrol = brain:Decide(21, { noises = {}, heatSources = {}, reachedTarget = true })
		Assert.equal(patrol.state, "PATROL")

		local chase = brain:Decide(22, {
			visual = { visible = true, position = { x = 4 } },
			noises = {},
			heatSources = {},
		})
		Assert.equal(chase.state, "CHASE")
		Assert.equal(chase.reason, "Visual")
		local lost = brain:Decide(23, { noises = {}, heatSources = {} })
		Assert.equal(lost.state, "SEARCH")
	end,
}
