--!strict

local ActionValidator = require("../../src/shared/ActionValidator")
local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local ConfigValidator = require("../../src/shared/ConfigValidator")
local ExtractionSystem = require("../../src/server/domain/ExtractionSystem")
local HidingSystem = require("../../src/server/domain/HidingSystem")

return {
	name = "playable remediation keeps peek, scarcity pressure, extraction, and timing server-owned",
	run = function()
		Assert.truthy(ActionValidator.validate({
			action = "PeekHiding",
			requestId = "peek-1",
			hidingId = "wardrobe",
			enabled = true,
		}, Config.Security))
		Assert.falsy(ActionValidator.validate({
			action = "PeekHiding",
			requestId = "peek-2",
			hidingId = "wardrobe",
			enabled = "yes",
		}, Config.Security))

		local hiding = HidingSystem.new(Config)
		Assert.truthy(hiding:Register("wardrobe", 2, { x = 0 }))
		Assert.truthy(hiding:RequestEntry("p1", "wardrobe", 2))
		local exited = hiding:Exit("p1", "wardrobe", 9)
		Assert.equal(exited.duration, 7)
		Assert.equal(exited.occupancyAfter, 0)
		Assert.truthy(hiding:RequestEntry("owner", "wardrobe", 10))
		Assert.truthy(hiding:RequestEntry("requester", "wardrobe", 11))
		Assert.equal(#hiding:PruneExpired(11 + Config.Interaction.RequestLifetime + 0.1), 1)

		local extraction = ExtractionSystem.new(Config)
		Assert.truthy(extraction:Register("arrival", { x = 0 }))
		Assert.truthy(extraction:Register("service", { x = 1 }))
		local first = extraction:Open(20)
		local inactive = if first == "arrival" then "service" else "arrival"
		Assert.equal(extraction:Escape("p1", inactive, 21, 1, "Active"), nil)
		Assert.equal(extraction:SwitchActive(), inactive)
		Assert.truthy(extraction:Escape("p1", inactive, 21, 1, "Active"))

		local invalid = table.clone(Config)
		invalid.Hunter = table.clone(Config.Hunter)
		invalid.Hunter.LastKnownPursuitSeconds = 0
		Assert.falsy(ConfigValidator.validate(invalid))

		local invalidPeek = table.clone(Config)
		invalidPeek.Hiding = table.clone(Config.Hiding)
		invalidPeek.Hiding.PeekCooldown = 0
		Assert.falsy(ConfigValidator.validate(invalidPeek))

		local invalidDownedEvidence = table.clone(Config)
		invalidDownedEvidence.Rescue = table.clone(Config.Rescue)
		invalidDownedEvidence.Rescue.DownedEvidenceInterval = 0
		Assert.falsy(ConfigValidator.validate(invalidDownedEvidence))

		local invalidSearch = table.clone(Config)
		invalidSearch.Hunter = table.clone(Config.Hunter)
		invalidSearch.Hunter.SearchPointCount = 0
		Assert.falsy(ConfigValidator.validate(invalidSearch))

		local invalidMoments = table.clone(Config)
		invalidMoments.MovieMoments = table.clone(Config.MovieMoments)
		invalidMoments.MovieMoments.MaxPerRound = 3
		Assert.falsy(ConfigValidator.validate(invalidMoments))

		local invalidWindow = table.clone(Config)
		invalidWindow.MovieMoments = table.clone(Config.MovieMoments)
		invalidWindow.MovieMoments.HuntMaximumDelay = Config.MovieMoments.HuntMinimumDelay - 1
		Assert.falsy(ConfigValidator.validate(invalidWindow))

		local invalidGateJam = table.clone(Config)
		invalidGateJam.MovieMoments = table.clone(Config.MovieMoments)
		invalidGateJam.MovieMoments.GateJamChance = 1.1
		Assert.falsy(ConfigValidator.validate(invalidGateJam))

		local invalidMomentWeight = table.clone(Config)
		invalidMomentWeight.MovieMoments = table.clone(Config.MovieMoments)
		invalidMomentWeight.MovieMoments.Weights = table.clone(Config.MovieMoments.Weights)
		invalidMomentWeight.MovieMoments.Weights.DOUBLE_TAKE = 0
		Assert.falsy(ConfigValidator.validate(invalidMomentWeight))

		local invalidNearMiss = table.clone(Config)
		invalidNearMiss.Hunter = table.clone(Config.Hunter)
		invalidNearMiss.Hunter.NearMissMinimumChaseDuration = 0
		Assert.falsy(ConfigValidator.validate(invalidNearMiss))
	end,
}
