--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local RemoteProtocol = require("../../src/shared/RemoteProtocol")
local HidingSystem = require("../../src/server/domain/HidingSystem")
local HunterInspection = require("../../src/server/domain/HunterInspection")

return {
	name = "Shared Silence breach creates bounded server-owned discovery",
	run = function()
		local hiding = HidingSystem.new(Config)
		Assert.truthy(hiding:Register("wardrobe", 3, { x = 0 }, { x = 4 }))
		hiding:RequestEntry("solo", "wardrobe", 0)
		local solo = hiding:Tick("wardrobe", 0, 0, 0)
		local request2 = hiding:RequestEntry("second", "wardrobe", 1)
		hiding:ResolveEntry("solo", request2.id, true, 1)
		local pair = hiding:Tick("wardrobe", 0, 1, 0)
		local request3 = hiding:RequestEntry("third", "wardrobe", 2)
		hiding:ResolveEntry("solo", request3.id, true, 2)
		local crowd = hiding:Tick("wardrobe", 0, 2, 0)
		Assert.truthy(pair.risk > solo.risk)
		Assert.truthy(crowd.risk > pair.risk)

		local broken = hiding:Tick("wardrobe", 0, 3, 1)
		Assert.equal(broken.state, "Broken")
		hiding:ApplySilenceState("wardrobe", broken.state, "Unstable", 3)
		Assert.truthy(hiding:IsExposed("wardrobe", 3))
		local firstExpiry = hiding:GetSpot("wardrobe").exposedUntil
		hiding:ApplySilenceState("wardrobe", "Broken", "Unstable", 4)
		Assert.truthy(hiding:GetSpot("wardrobe").exposedUntil > firstExpiry)

		local captured = {}
		local capture = {
			Down = function(_, playerId)
				table.insert(captured, playerId)
				return true
			end,
		}
		local discovered = HunterInspection.Inspect(hiding, capture, "wardrobe", 4)
		Assert.equal(#discovered, 3)
		Assert.equal(#captured, 3)
		Assert.equal(#HunterInspection.Inspect(hiding, capture, "wardrobe", 20), 0)
		Assert.falsy(hiding:IsExposed("wardrobe", 20))
		Assert.equal(RemoteProtocol.Actions.ExposeHiding, nil)
		Assert.equal(RemoteProtocol.Actions.ClearHidingExposure, nil)

		hiding:Expose("wardrobe", 21)
		hiding:ResetRound()
		Assert.falsy(hiding:IsExposed("wardrobe", 21))
		Assert.equal(hiding:GetOccupancy("wardrobe"), 0)
	end,
}
