--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local HidingHeat = require("../../src/server/domain/HidingHeat")
local NoiseLedger = require("../../src/server/domain/NoiseLedger")

return {
	name = "noise decays, decoys share evidence, and hiding heat cools",
	run = function()
		local ledger = NoiseLedger.new(Config.Noise)
		local event = ledger:Add({
			origin = { x = 1, y = 2, z = 3 },
			magnitude = 0.8,
			category = "Decoy",
			decaySeconds = 10,
			falseEvidence = true,
		}, 0)
		Assert.truthy(event)
		local evidence = ledger:GetEvidence(5)
		Assert.equal(#evidence, 1)
		Assert.near(evidence[1].magnitude, 0.4, 0.0001)
		Assert.truthy(evidence[1].falseEvidence)
		Assert.equal(#ledger:GetEvidence(11), 0)
		local invalid, err = ledger:Add({ origin = {}, magnitude = 1, category = "Magic" }, 0)
		Assert.equal(invalid, nil)
		Assert.contains(err, "unknown")
		ledger:ResetRound()
		Assert.equal(#ledger:GetEvidence(12), 0)

		local heat = HidingHeat.new(Config.HidingHeat)
		local used = heat:RecordUse("wardrobe-a", 0)
		local reused = heat:RecordUse("wardrobe-a", 1)
		Assert.truthy(reused > used)
		local cooled = heat:Get("wardrobe-a", 20)
		Assert.truthy(cooled < reused)
		Assert.truthy(heat:TickOccupied("wardrobe-a", 3, 5, 25) > cooled)
	end,
}
