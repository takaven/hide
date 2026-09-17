--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local ConfigValidator = require("../../src/shared/ConfigValidator")
local ActionValidator = require("../../src/shared/ActionValidator")
local PowerObjective = require("../../src/server/domain/PowerObjective")

local function run()
	local objective = PowerObjective.new(Config)
	Assert.equal(objective:GetState(), "Stable", "power begins stable")
	Assert.truthy(objective:BeginBlackout(), "blackout starts once")
	Assert.falsy(objective:BeginBlackout(), "blackout cannot overlap")
	local result = objective:Complete("player-1", 10)
	Assert.equal(result.state, "Emergency", "fuse restores emergency power")
	Assert.equal(result.noiseMagnitude, Config.Fuse.NoiseMagnitude, "fuse uses configured noise")
	local duplicate, duplicateError = objective:Complete("player-2", 11)
	Assert.equal(duplicate, nil, "duplicate fuse completion is rejected")
	Assert.equal(duplicateError, "fuse is not active", "duplicate has explicit reason")
	objective:ResetRound()
	Assert.equal(objective:GetState(), "Stable", "round reset restores power state")
	Assert.equal(objective:GetCompletion(), nil, "round reset clears attribution")

	local invalid = table.clone(Config)
	invalid.Fuse = table.clone(Config.Fuse)
	invalid.Fuse.InteractionDuration = 0
	local valid, errors = ConfigValidator.validate(invalid)
	Assert.falsy(valid, "zero fuse duration is rejected")
	Assert.truthy(#errors > 0, "invalid fuse config explains failure")

	local crouchValid = ActionValidator.validate({
		action = "SetCrouch",
		requestId = "movement-1",
		enabled = true,
	}, Config.Security)
	Assert.truthy(crouchValid, "crouch accepts only an explicit boolean")
	local crouchInvalid = ActionValidator.validate({
		action = "SetCrouch",
		requestId = "movement-2",
		enabled = "yes",
	}, Config.Security)
	Assert.falsy(crouchInvalid, "crouch rejects client-coerced values")
end

return { name = "Vertical slice power objective", run = run }
