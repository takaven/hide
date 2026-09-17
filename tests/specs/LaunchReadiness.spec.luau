--!strict

local Assert = require("../Assert")
local ActionValidator = require("../../src/shared/ActionValidator")
local AIGuestPopulation = require("../../src/server/domain/AIGuestPopulation")
local AnalyticsBus = require("../../src/server/domain/AnalyticsBus")
local Config = require("../../src/shared/Config")
local ConfigValidator = require("../../src/shared/ConfigValidator")
local EnvironmentConfig = require("../../src/shared/EnvironmentConfig")
local HighlightTracker = require("../../src/server/domain/HighlightTracker")
local ParticipantMetrics = require("../../src/server/domain/ParticipantMetrics")
local RematchCoordinator = require("../../src/server/domain/RematchCoordinator")

return {
	name = "launch readiness keeps AI fill, rematch, recognition, and staging telemetry honest",
	run = function()
		local _, staging = EnvironmentConfig.resolve(Config, "Staging")
		local _, humanOnlyStaging = EnvironmentConfig.resolve(Config, "Staging", true)
		local _, production = EnvironmentConfig.resolve(Config, "Production")
		Assert.equal(AIGuestPopulation.desiredCount(Config, staging, 1), 3)
		Assert.equal(AIGuestPopulation.desiredCount(Config, staging, 2), 2)
		Assert.equal(AIGuestPopulation.desiredCount(Config, staging, 3), 1)
		Assert.equal(AIGuestPopulation.desiredCount(Config, staging, 4), 0)
		Assert.equal(AIGuestPopulation.desiredCount(Config, production, 1), 0)
		Assert.equal(AIGuestPopulation.desiredCount(Config, humanOnlyStaging, 1), 0)
		Assert.truthy(humanOnlyStaging.HumanOnly)
		Assert.falsy(humanOnlyStaging.AIGuestsEnabled)
		Assert.truthy(staging.AIGuestsEnabled)
		Assert.equal(AIGuestPopulation.participantKind("ai-guest-1"), "AI")
		Assert.equal(AIGuestPopulation.participantKind("1234"), "Human")

		local participantStates = {
			humanEscaped = "Escaped",
			humanDowned = "Downed",
			["ai-guest-1"] = "Escaped",
			["ai-guest-2"] = "Eliminated",
		}
		local outcomeCounts = ParticipantMetrics.countResults({
			"humanEscaped",
			"humanDowned",
			"ai-guest-1",
			"ai-guest-2",
		}, function(participantId)
			return participantStates[participantId]
		end)
		Assert.equal(outcomeCounts.escaped, 1)
		Assert.equal(outcomeCounts.survivors, 1)
		Assert.equal(outcomeCounts.eliminated, 0)
		Assert.equal(outcomeCounts.aiEscaped, 1)
		Assert.equal(outcomeCounts.aiEliminated, 1)
		Assert.equal(outcomeCounts.aiSurvivors, 0)

		local rematch = RematchCoordinator.new(Config)
		local request = rematch:Request("p1", 10)
		Assert.truthy(request ~= nil)
		Assert.falsy(rematch:ShouldRestart(12))
		Assert.truthy(rematch:ShouldRestart(12.5))
		Assert.falsy(rematch:Request("p1", 13))
		rematch:ResetRound()
		Assert.equal(rematch:GetRequestCount(), 0)

		local tracker = HighlightTracker.new()
		local bus = AnalyticsBus.new()
		bus:Subscribe(function(envelope)
			tracker:Observe(envelope)
		end)
		Assert.truthy(bus:Emit("brace_door_used", { playerId = "p1" }, 1))
		Assert.truthy(bus:Emit("rescue_completed", { rescuerId = "ai-guest-1" }, 2))
		local moment = tracker:MomentOfRound()
		Assert.equal(moment.label, "Best Rescue")
		Assert.equal(moment.properties.participantKind, "AI")
		Assert.equal(#tracker:BuildAwards(), 2)
		tracker:ResetRound()
		Assert.equal(tracker:MomentOfRound(), nil)

		Assert.truthy(
			ActionValidator.validate(
				{ action = "RequestRematch", requestId = "r1" },
				Config.Security
			)
		)
		Assert.truthy(
			ActionValidator.validate({ action = "InviteFriend", requestId = "r2" }, Config.Security)
		)
		Assert.truthy(
			ActionValidator.validate(
				{ action = "OnboardingStep", requestId = "r3", stepId = "first_hiding" },
				Config.Security
			)
		)
		Assert.falsy(
			ActionValidator.validate(
				{ action = "OnboardingStep", requestId = "r4", stepId = "<unsafe>" },
				Config.Security
			)
		)

		local invalid = table.clone(Config)
		invalid.AIGuests = table.clone(Config.AIGuests)
		invalid.AIGuests.RelocateHeatThreshold = 1.1
		Assert.falsy(ConfigValidator.validate(invalid))
	end,
}
