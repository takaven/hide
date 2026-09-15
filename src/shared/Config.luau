--!strict

return {
	MaxPlayers = 12,

	Round = {
		MinimumPlayers = 2,
		Durations = {
			Lobby = 20,
			Prepare = 15,
			Hunt = 120,
			Relocation = 25,
			Extraction = 60,
			Results = 15,
		},
	},

	Interaction = {
		MaxDistance = 12,
		RequestLifetime = 8,
	},

	Hiding = {
		DefaultCapacity = 3,
		BaseRisk = 0.12,
		AdditionalOccupantRisk = 0.22,
		RecentNoiseWeight = 0.55,
		MovementRisk = 0.18,
		HeatWeight = 0.35,
		WarningThreshold = 0.35,
		UnstableThreshold = 0.58,
		BreakThreshold = 0.85,
		EntryNoise = 0.32,
		ExitNoise = 0.22,
		RefusalNoise = 0.04,
	},

	Noise = {
		DefaultDecaySeconds = 12,
		MaxAgeSeconds = 30,
		Categories = {
			Footstep = 0.65,
			HidingEntry = 1.1,
			HidingExit = 0.9,
			Door = 1.15,
			Rescue = 1.2,
			Decoy = 1.0,
			FailedSilence = 1.5,
			Environment = 0.55,
		},
	},

	HidingHeat = {
		UseIncrease = 0.24,
		OccupancyIncreasePerSecond = 0.012,
		DecayPerSecond = 0.006,
		Maximum = 1,
	},

	Door = {
		HoldDuration = 4,
		HoldNoise = 0.28,
		Cooldown = 2,
	},

	Rescue = {
		Duration = 4,
		DownedDuration = 30,
		MaxDistance = 10,
		Noise = 0.4,
		CapturesBeforeElimination = 2,
	},

	Decoy = {
		UsesPerRound = 1,
		Cooldown = 10,
		Magnitude = 0.75,
		DecaySeconds = 10,
	},

	Extraction = {
		OpenDuration = 60,
		MaxDistance = 12,
	},

	Hunter = {
		WalkSpeed = 14,
		ChaseSpeed = 20,
		VisionDistance = 55,
		VisionDotThreshold = 0.35,
		CaptureDistance = 5,
		CaptureCooldown = 2,
		VisualScore = 100,
		NoiseScoreScale = 40,
		HeatScoreScale = 22,
		InvestigateThreshold = 10,
		SearchDuration = 8,
		EvidenceMemorySeconds = 20,
		RepathInterval = 0.5,
		MovingTargetRepathDistance = 4,
		StuckSeconds = 2.5,
		MaxReplans = 4,
	},

	Security = {
		ReplayWindowSeconds = 30,
		MaxRequestIdLength = 64,
		MaxTargetIdLength = 64,
		RateLimits = {
			RequestHideEntry = { Limit = 4, WindowSeconds = 5 },
			ResolveEntryRequest = { Limit = 6, WindowSeconds = 5 },
			ExitHiding = { Limit = 3, WindowSeconds = 5 },
			HoldDoor = { Limit = 3, WindowSeconds = 5 },
			ReleaseDoor = { Limit = 4, WindowSeconds = 5 },
			StartRescue = { Limit = 3, WindowSeconds = 5 },
			CompleteRescue = { Limit = 3, WindowSeconds = 5 },
			UseDecoy = { Limit = 2, WindowSeconds = 10 },
			Escape = { Limit = 3, WindowSeconds = 5 },
		},
	},
}
