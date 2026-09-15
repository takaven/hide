--!strict

local Assert = require("../Assert")
local AnalyticsBus = require("../../src/server/domain/AnalyticsBus")
local Config = require("../../src/shared/Config")
local DoorSystem = require("../../src/server/domain/DoorSystem")
local HidingSystem = require("../../src/server/domain/HidingSystem")
local PlayerLifecycle = require("../../src/server/domain/PlayerLifecycle")
local PlayerStates = require("../../src/server/domain/PlayerStates")
local RescueSystem = require("../../src/server/domain/RescueSystem")

return {
	name = "entry commit and character lifecycle leave no ghost interaction state",
	run = function()
		local states = PlayerStates.new()
		states:Add("occupant", true)
		states:Add("requester", true)
		local hiding = HidingSystem.new(Config)
		hiding:Register("spot", 3, { x = 0 })
		hiding:RequestEntry("occupant", "spot", 0)
		states:Transition("occupant", "Hiding", "test", 0)
		local request = hiding:RequestEntry("requester", "spot", 1)
		states:Transition("requester", "Downed", "captured while waiting", 2)
		local heatBefore = hiding:GetHeat("spot", 2)
		local noiseBefore = hiding:GetSpot("spot").recentNoise
		local analytics = AnalyticsBus.new()
		local accepted = hiding:ResolveEntry("occupant", request.id, true, 2, function()
			if states:Get("requester") ~= "Active" and states:Get("requester") ~= "Rescued" then
				return false, "requester is downed"
			end
			return states:Transition("requester", "Hiding", "accepted", 2)
		end)
		if accepted then
			analytics:Emit("entry_accepted", {}, 2)
		end
		Assert.equal(accepted, nil)
		Assert.equal(hiding:GetPlayerSpot("requester"), nil)
		Assert.equal(hiding:GetOccupancy("spot"), 1)
		Assert.equal(hiding:GetHeat("spot", 2), heatBefore)
		Assert.equal(hiding:GetSpot("spot").recentNoise, noiseBefore)
		Assert.equal(#analytics:GetBuffered(), 0)

		local doors = DoorSystem.new(Config)
		doors:Register("door", { x = 0 })
		doors:Hold("occupant", "door", 3)
		local rescue = RescueSystem.new(Config)
		rescue:Start("occupant", "requester", 3, 1, "Active", "Downed")
		local capture = {
			Clear = function() end,
			Down = function()
				return true
			end,
		}
		local lifecycle = PlayerLifecycle.new({
			PlayerStates = states,
			Hiding = hiding,
			Doors = doors,
			Rescue = rescue,
			Capture = capture,
		})
		local cleaned = lifecycle:Cleanup("occupant", "CharacterAdded", 4)
		Assert.equal(cleaned.hidingId, "spot")
		Assert.equal(states:Get("occupant"), "Active")
		Assert.equal(hiding:GetOccupancy("spot"), 0)
		Assert.equal(doors:Get("door").heldBy, nil)
		Assert.equal(#cleaned.cancelledRescues, 1)

		hiding:RequestEntry("occupant", "spot", 5)
		states:Transition("occupant", "Hiding", "test", 5)
		lifecycle:Cleanup("occupant", "PlayerRemoving", 6)
		Assert.equal(hiding:GetPlayerSpot("occupant"), nil)
		Assert.equal(states:Get("occupant"), "Spectating")
		local downedRemoval = lifecycle:Cleanup("requester", "PlayerRemoving", 6)
		Assert.equal(downedRemoval.stateAfter, "Spectating")
	end,
}
