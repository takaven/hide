--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local PlayerStates = require("../../src/server/domain/PlayerStates")
local RoundState = require("../../src/server/domain/RoundState")

return {
	name = "round and player state machines reject invalid transitions",
	run = function()
		local round = RoundState.new(Config.Round, 0)
		Assert.equal(round:GetState(), "Lobby")
		local enough, err = round:Advance("Prepare", 20, 1)
		Assert.falsy(enough)
		Assert.contains(err, "not enough")
		Assert.truthy(round:Advance("Prepare", 20, 2))
		Assert.truthy(round:Advance("Hunt", 35, 2))
		local skipped, skipError = round:Advance("Results", 36, 2)
		Assert.truthy(skipped, skipError)
		Assert.falsy(round:Advance("Extraction", 37, 2))

		local players = PlayerStates.new()
		Assert.truthy(players:Add("101", true))
		Assert.equal(players:Get("101"), "Active")
		Assert.truthy(players:Transition("101", "Escaped", "round complete", 1))
		Assert.equal(players:Get("101"), "Escaped")
		local invalid, invalidError = players:Transition("101", "Active", "cannot rejoin", 2)
		Assert.falsy(invalid)
		Assert.contains(invalidError, "invalid transition")
		Assert.truthy(players:Transition("101", "Spectating", "observe", 3))
		Assert.truthy(players:IsSpectatorOnly("101"))

		players:ResetForRound({ "101" }, 4)
		Assert.equal(players:Get("101"), "Active")
		Assert.truthy(players:Capture("101", 2, 5))
		Assert.equal(players:Get("101"), "Downed")
		Assert.truthy(players:ResolveDowned("101", 2, true, 6))
		Assert.equal(players:Get("101"), "Rescued")
	end,
}
