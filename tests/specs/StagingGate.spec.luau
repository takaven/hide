--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local HidingSystem = require("../../src/server/domain/HidingSystem")
local NearMissPolicy = require("../../src/server/domain/NearMissPolicy")
local PlayerStates = require("../../src/server/domain/PlayerStates")
local RoundPlayerReset = require("../../src/server/domain/RoundPlayerReset")
local SuspicionTier = require("../../src/shared/SuspicionTier")
local SuspicionSnapshotPolicy = require("../../src/server/domain/SuspicionSnapshotPolicy")
local WeightedChoice = require("../../src/server/domain/WeightedChoice")

return {
	name = "staging gate protects round reset, live suspicion, peek cost, and moment variety",
	run = function()
		for index, terminalState in ipairs({ "Eliminated", "Escaped", "Spectating" }) do
			local playerId = `terminal-{index}`
			local states = PlayerStates.new()
			states:Add(playerId, true)
			if terminalState == "Eliminated" then
				states:Capture(playerId, Config.Rescue.CapturesBeforeElimination, 1)
				states:ResolveDowned(playerId, 1, false, 2)
			else
				states:Transition(playerId, terminalState, "test terminal", 1)
			end
			local plan = RoundPlayerReset.plan(states:Get(playerId), true)
			Assert.equal(plan.state, "Active")
			Assert.equal(plan.placement, "ArrivalSpawn")
			Assert.truthy(plan.clearTerminalPresentation)
			Assert.falsy(plan.allowCaptureSideEffect)
			states:ResetForRound({ playerId }, 3)
			Assert.equal(states:Get(playerId), "Active")
			Assert.equal(states:GetCaptureCount(playerId), 0)
		end
		Assert.equal(RoundPlayerReset.plan("Spectating", false).placement, "ReloadCharacter")

		Assert.equal(SuspicionTier.fromValues(Config, 0, false), "SAFE")
		Assert.equal(
			SuspicionTier.fromValues(Config, Config.Hiding.WarmHeatThreshold, false),
			"WARM"
		)
		Assert.equal(
			SuspicionTier.fromValues(Config, Config.Hiding.InspectionHeatThreshold, false),
			"HOT"
		)
		Assert.equal(SuspicionTier.fromValues(Config, 0, true), "EXPOSED")
		Assert.truthy(SuspicionSnapshotPolicy.shouldEmit("Safe", "Safe", 0.2, 0.2, "WARM", "HOT"))
		Assert.falsy(SuspicionSnapshotPolicy.shouldEmit("Safe", "Safe", 0.2, 0.2, "WARM", "WARM"))

		local hiding = HidingSystem.new(Config)
		Assert.truthy(hiding:Register("peek-spot", 1, { x = 0 }))
		Assert.truthy(hiding:RequestEntry("p1", "peek-spot", 0))
		local before = hiding:GetSpot("peek-spot").recentNoise
		Assert.truthy(hiding:AddRecentNoise("peek-spot", Config.Hiding.PeekNoise))
		Assert.equal(hiding:GetSpot("peek-spot").recentNoise, before + Config.Hiding.PeekNoise)

		local weights = { A = 1, B = 1, C = 1 }
		Assert.equal(WeightedChoice.select(weights, 0, nil), "A")
		Assert.truthy(WeightedChoice.select(weights, 0, "A") ~= "A")
		Assert.falsy(NearMissPolicy.qualifies(Config, 0.5, 4))
		Assert.falsy(NearMissPolicy.qualifies(Config, 5, 30))
		Assert.truthy(NearMissPolicy.qualifies(Config, 5, 8))
	end,
}
