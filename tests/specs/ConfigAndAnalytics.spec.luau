--!strict

local Assert = require("../Assert")
local AnalyticsBus = require("../../src/server/domain/AnalyticsBus")
local Config = require("../../src/shared/Config")
local ConfigValidator = require("../../src/shared/ConfigValidator")

return {
	name = "configuration and telemetry contracts reject malformed input",
	run = function()
		local valid, errors = ConfigValidator.validate(Config)
		Assert.truthy(valid, table.concat(errors, "; "))
		local malformedValid, malformedErrors = ConfigValidator.validate({ Round = 4 })
		Assert.falsy(malformedValid)
		Assert.truthy(#malformedErrors > 5)
		local invalidExposure = table.clone(Config)
		invalidExposure.Hiding = table.clone(Config.Hiding)
		invalidExposure.Hiding.ExposureDuration = 0
		Assert.falsy(ConfigValidator.validate(invalidExposure))
		local invalidColdThreshold = table.clone(Config)
		invalidColdThreshold.Hiding = table.clone(Config.Hiding)
		invalidColdThreshold.Hiding.InspectionHeatThreshold = 0
		Assert.falsy(ConfigValidator.validate(invalidColdThreshold))
		local invalidHotThreshold = table.clone(Config)
		invalidHotThreshold.Hiding = table.clone(Config.Hiding)
		invalidHotThreshold.Hiding.InspectionHeatThreshold = 1.01
		Assert.falsy(ConfigValidator.validate(invalidHotThreshold))
		local invalidInvestigation = table.clone(Config)
		invalidInvestigation.Hunter = table.clone(Config.Hunter)
		invalidInvestigation.Hunter.InvestigationTimeout = 0
		Assert.falsy(ConfigValidator.validate(invalidInvestigation))
		local invalidRescueGrace = table.clone(Config)
		invalidRescueGrace.Rescue = table.clone(Config.Rescue)
		invalidRescueGrace.Rescue.RangeGraceSeconds = -1
		Assert.falsy(ConfigValidator.validate(invalidRescueGrace))
		local invalidMovementRange = table.clone(Config)
		invalidMovementRange.MovementNoise = table.clone(Config.MovementNoise)
		invalidMovementRange.MovementNoise.SpeedForMaximum = Config.MovementNoise.MinimumSpeed
		Assert.falsy(ConfigValidator.validate(invalidMovementRange))
		local invalidSurface = table.clone(Config)
		invalidSurface.MovementNoise = table.clone(Config.MovementNoise)
		invalidSurface.MovementNoise.SurfaceMultipliers =
			table.clone(Config.MovementNoise.SurfaceMultipliers)
		invalidSurface.MovementNoise.SurfaceMultipliers.Metal = 0
		Assert.falsy(ConfigValidator.validate(invalidSurface))

		local analytics = AnalyticsBus.new()
		Assert.truthy(analytics:Emit("entry_refused", { hidingId = "wardrobe-a" }, 1))
		Assert.equal(#analytics:GetBuffered(), 1)
		Assert.falsy(analytics:Emit("credit_card_captured", {}, 2))
		Assert.equal(#analytics:GetBuffered(), 1)

		local provider = {
			Emit = function()
				error("offline")
			end,
		}
		local providerBus = AnalyticsBus.new(provider)
		local emitted, providerError = providerBus:Emit("round_started", {}, 0)
		Assert.falsy(emitted)
		Assert.contains(providerError, "provider failed")
	end,
}
