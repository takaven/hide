--!strict

local RunService = game:GetService("RunService")

local StudioTestOverrides = {}

function StudioTestOverrides.Apply(config: any)
	if not RunService:IsStudio() then
		return
	end
	config.Round.MinimumPlayers = config.Round.StudioMinimumPlayers
	local ok, args = pcall(function()
		return game:GetService("StudioTestService"):GetTestArgs()
	end)
	if not ok or type(args) ~= "table" or args.suite ~= "phase2-smoke" then
		return
	end
	if args.disableHunter == true then
		config.Hunter.WalkSpeed = 0.1
		config.Hunter.ChaseSpeed = 0.1
		config.Hunter.VisionDistance = 0.1
		config.Hunter.CaptureDistance = 0.1
	end
	local minimumPlayers = tonumber(args.minimumPlayers)
	if
		minimumPlayers ~= nil
		and minimumPlayers % 1 == 0
		and minimumPlayers >= 1
		and minimumPlayers <= config.MaxPlayers
	then
		config.Round.MinimumPlayers = minimumPlayers
	end
	local phaseDuration = tonumber(args.phaseDuration)
	if phaseDuration == nil or phaseDuration < 30 or phaseDuration > 900 then
		return
	end
	config.Round.Durations.Lobby = 1
	config.Round.Durations.Prepare = 1
	config.Round.Durations.Hunt = phaseDuration
	config.Round.Durations.Relocation = phaseDuration
	config.Round.Durations.Extraction = phaseDuration
	config.Round.Durations.Results = 1
end

return StudioTestOverrides
