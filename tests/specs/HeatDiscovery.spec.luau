--!strict

local Assert = require("../Assert")
local ActionValidator = require("../../src/shared/ActionValidator")
local Config = require("../../src/shared/Config")
local RemoteProtocol = require("../../src/shared/RemoteProtocol")
local HidingSystem = require("../../src/server/domain/HidingSystem")
local HunterBrain = require("../../src/server/domain/HunterBrain")
local HunterInspection = require("../../src/server/domain/HunterInspection")

return {
	name = "local inspection discovers hot but not cold silent solo hiding",
	run = function()
		local hiding = HidingSystem.new(Config)
		hiding:Register("quiet-room", 1, { x = 0 }, { x = 2 })
		hiding:RequestEntry("solo", "quiet-room", 0)
		local captured = {}
		local capture = {
			Down = function(_, playerId)
				table.insert(captured, playerId)
				return true
			end,
		}

		Assert.truthy(hiding:GetHeat("quiet-room", 0) < Config.Hiding.InspectionHeatThreshold)
		Assert.falsy(hiding:IsDiscoverable("quiet-room", 0))
		Assert.equal(#HunterInspection.Inspect(hiding, capture, "quiet-room", 0), 0)

		local silence = hiding:Tick("quiet-room", 31, 31, 0)
		Assert.truthy(hiding:GetHeat("quiet-room", 31) >= Config.Hiding.InspectionHeatThreshold)
		Assert.falsy(hiding:IsExposed("quiet-room", 31))
		Assert.truthy(silence.state ~= "Broken")
		Assert.truthy(hiding:IsDiscoverable("quiet-room", 31))
		local brain = HunterBrain.new(Config.Hunter)
		local investigate = brain:Decide(31, {
			noises = {},
			heatSources = {
				{
					hidingId = "quiet-room",
					value = hiding:GetHeat("quiet-room", 31),
					position = { x = 2 },
					distance = 0,
				},
			},
		})
		Assert.equal(investigate.state, "INVESTIGATE")
		brain:BindInvestigationNavigation(1)
		local localInspection = brain:Decide(32, {
			noises = {},
			heatSources = {},
			navigationStatus = "Completed",
			navigationGeneration = 1,
			targetDistance = 0,
		})
		Assert.truthy(localInspection.inspectionReady)
		Assert.equal(localInspection.hidingId, "quiet-room")
		Assert.equal(#HunterInspection.Inspect(hiding, capture, localInspection.hidingId, 32), 1)
		Assert.equal(captured[1], "solo")

		hiding:ResetRound()
		Assert.equal(hiding:GetHeat("quiet-room", 32), 0)
		hiding:RequestEntry("solo", "quiet-room", 32)
		Assert.falsy(hiding:IsDiscoverable("quiet-room", 32))
		Assert.equal(#HunterInspection.Inspect(hiding, capture, "quiet-room", 32), 0)

		Assert.equal(RemoteProtocol.Actions.SetHidingHeat, nil)
		Assert.equal(RemoteProtocol.Actions.SetDiscoverable, nil)
		Assert.equal(RemoteProtocol.Actions.BypassInspectionHeat, nil)
		Assert.equal(RemoteProtocol.Actions.DeclareSafe, nil)
		local forgedHeat = ActionValidator.validate({
			action = "SetHidingHeat",
			requestId = "forged-1",
			hidingId = "quiet-room",
			value = 1,
		}, Config.Security)
		Assert.falsy(forgedHeat)
	end,
}
