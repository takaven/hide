--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local HidingSystem = require("../../src/server/domain/HidingSystem")

return {
	name = "Let Me In preserves capacity, occupancy, authorization, and expiry",
	run = function()
		local hiding = HidingSystem.new(Config)
		Assert.truthy(hiding:Register("wardrobe-a", 2, { x = 0, y = 0, z = 0 }))
		Assert.falsy(hiding:Register("wardrobe-a", 2, {}))

		local first = hiding:RequestEntry("p1", "wardrobe-a", 0)
		Assert.equal(first.status, "Entered")
		Assert.equal(hiding:GetOccupancy("wardrobe-a"), 1)

		local request = hiding:RequestEntry("p2", "wardrobe-a", 1)
		Assert.equal(request.status, "Pending")
		local unauthorized, unauthorizedError = hiding:ResolveEntry("intruder", request.id, true, 2)
		Assert.equal(unauthorized, nil)
		Assert.contains(unauthorizedError, "occupant")

		local accepted = hiding:ResolveEntry("p1", request.id, true, 2)
		Assert.equal(accepted.status, "Entered")
		Assert.equal(hiding:GetOccupancy("wardrobe-a"), 2)
		Assert.equal(hiding:GetPlayerSpot("p2"), "wardrobe-a")
		local full, fullError = hiding:RequestEntry("p3", "wardrobe-a", 3)
		Assert.equal(full, nil)
		Assert.contains(fullError, "full")

		Assert.truthy(hiding:Exit("p2", "wardrobe-a"))
		local request2 = hiding:RequestEntry("p3", "wardrobe-a", 4)
		local expired, expiredError = hiding:ResolveEntry("p1", request2.id, true, 20)
		Assert.equal(expired, nil)
		Assert.contains(expiredError, "expired")
		Assert.equal(hiding:GetOccupancy("wardrobe-a"), 1)
		local retry = hiding:RequestEntry("p3", "wardrobe-a", 21)
		Assert.equal(retry.status, "Pending")
	end,
}
