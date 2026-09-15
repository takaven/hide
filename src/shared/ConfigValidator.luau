--!strict

local ConfigValidator = {}

local function field(parent: any, key: string): any
	return if type(parent) == "table" then parent[key] else nil
end

local function positive(errors: { string }, path: string, value: any, allowZero: boolean?)
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		table.insert(errors, `{path} must be a finite number`)
	elseif (allowZero and value < 0) or (not allowZero and value <= 0) then
		table.insert(errors, `{path} must be {if allowZero then "non-negative" else "positive"}`)
	end
end

function ConfigValidator.validate(config: any): (boolean, { string })
	local errors = {}

	if type(config) ~= "table" then
		return false, { "config must be a table" }
	end

	local maxPlayers = field(config, "MaxPlayers")
	local round = field(config, "Round")
	local minimumPlayers = field(round, "MinimumPlayers")
	local durations = field(round, "Durations")
	positive(errors, "MaxPlayers", maxPlayers)
	positive(errors, "Round.MinimumPlayers", minimumPlayers)
	if
		type(minimumPlayers) == "number"
		and type(maxPlayers) == "number"
		and minimumPlayers > maxPlayers
	then
		table.insert(errors, "Round.MinimumPlayers cannot exceed MaxPlayers")
	end

	for _, phase in ipairs({ "Lobby", "Prepare", "Hunt", "Relocation", "Extraction", "Results" }) do
		positive(errors, `Round.Durations.{phase}`, field(durations, phase))
	end

	local interaction = field(config, "Interaction")
	local hiding = field(config, "Hiding")
	positive(errors, "Interaction.MaxDistance", field(interaction, "MaxDistance"))
	positive(errors, "Interaction.RequestLifetime", field(interaction, "RequestLifetime"))
	positive(errors, "Hiding.DefaultCapacity", field(hiding, "DefaultCapacity"))
	positive(errors, "Hiding.ExposureDuration", field(hiding, "ExposureDuration"))
	positive(errors, "Hiding.InspectionHeatThreshold", field(hiding, "InspectionHeatThreshold"))

	for _, key in ipairs({
		"BaseRisk",
		"AdditionalOccupantRisk",
		"RecentNoiseWeight",
		"MovementRisk",
		"HeatWeight",
	}) do
		positive(errors, `Hiding.{key}`, field(hiding, key), true)
	end

	if type(hiding) == "table" then
		local warning = field(hiding, "WarningThreshold")
		local unstable = field(hiding, "UnstableThreshold")
		local broken = field(hiding, "BreakThreshold")
		if
			type(warning) ~= "number"
			or type(unstable) ~= "number"
			or type(broken) ~= "number"
			or not (warning < unstable and unstable < broken)
		then
			table.insert(errors, "Hiding thresholds must increase: Warning < Unstable < Break")
		end
		if type(broken) == "number" and broken > 1 then
			table.insert(errors, "Hiding.BreakThreshold cannot exceed 1")
		end
		local inspectionHeat = field(hiding, "InspectionHeatThreshold")
		if type(inspectionHeat) == "number" and inspectionHeat > 1 then
			table.insert(errors, "Hiding.InspectionHeatThreshold cannot exceed 1")
		end
	end

	local noise = field(config, "Noise")
	positive(errors, "Noise.DefaultDecaySeconds", field(noise, "DefaultDecaySeconds"))
	positive(errors, "Noise.MaxAgeSeconds", field(noise, "MaxAgeSeconds"))
	local categories = field(noise, "Categories")
	if type(categories) ~= "table" then
		table.insert(errors, "Noise.Categories must be a table")
	else
		for category, weight in pairs(categories) do
			positive(errors, `Noise.Categories.{category}`, weight, true)
		end
	end

	local positiveFields = {
		HidingHeat = { "UseIncrease", "OccupancyIncreasePerSecond", "DecayPerSecond", "Maximum" },
		Rescue = { "Duration", "DownedDuration", "MaxDistance", "CapturesBeforeElimination" },
		Door = { "HoldDuration", "Cooldown" },
		Decoy = { "UsesPerRound", "Cooldown", "Magnitude", "DecaySeconds" },
		Extraction = { "OpenDuration", "MaxDistance" },
		Hunter = {
			"WalkSpeed",
			"ChaseSpeed",
			"VisionDistance",
			"CaptureDistance",
			"CaptureCooldown",
			"VisualScore",
			"NoiseScoreScale",
			"HeatScoreScale",
			"InvestigateThreshold",
			"SearchDuration",
			"EvidenceMemorySeconds",
			"RepathInterval",
			"MovingTargetRepathDistance",
			"StuckSeconds",
			"MaxReplans",
			"InvestigationTimeout",
			"InvestigationArrivalDistance",
		},
	}
	for sectionName, fields in pairs(positiveFields) do
		local section = field(config, sectionName)
		for _, key in ipairs(fields) do
			positive(errors, `{sectionName}.{key}`, field(section, key))
		end
	end
	local hidingHeat = field(config, "HidingHeat")
	local inspectionHeat = field(hiding, "InspectionHeatThreshold")
	local maximumHeat = field(hidingHeat, "Maximum")
	if
		type(inspectionHeat) == "number"
		and type(maximumHeat) == "number"
		and inspectionHeat > maximumHeat
	then
		table.insert(errors, "Hiding.InspectionHeatThreshold cannot exceed HidingHeat.Maximum")
	end
	local rescue = field(config, "Rescue")
	positive(errors, "Rescue.RangeGraceSeconds", field(rescue, "RangeGraceSeconds"), true)
	positive(errors, "Rescue.CompletionGraceSeconds", field(rescue, "CompletionGraceSeconds"), true)
	local security = field(config, "Security")
	positive(errors, "Security.ReplayWindowSeconds", field(security, "ReplayWindowSeconds"))
	positive(errors, "Security.MaxRequestIdLength", field(security, "MaxRequestIdLength"))
	positive(errors, "Security.MaxTargetIdLength", field(security, "MaxTargetIdLength"))

	local rateLimits = field(security, "RateLimits")
	if type(rateLimits) ~= "table" then
		table.insert(errors, "Security.RateLimits must be a table")
	else
		for action, rule in pairs(rateLimits) do
			positive(errors, `Security.RateLimits.{action}.Limit`, field(rule, "Limit"))
			positive(
				errors,
				`Security.RateLimits.{action}.WindowSeconds`,
				field(rule, "WindowSeconds")
			)
		end
	end

	return #errors == 0, errors
end

return ConfigValidator
