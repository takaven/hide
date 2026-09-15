--!strict

return {
	Round = {
		Initial = "Lobby",
		Transitions = {
			Lobby = { Prepare = true },
			Prepare = { Hunt = true },
			Hunt = { Relocation = true, Extraction = true, Results = true },
			Relocation = { Hunt = true, Extraction = true, Results = true },
			Extraction = { Results = true },
			Results = { Lobby = true },
		},
	},
	Player = {
		Initial = "Spectating",
		Transitions = {
			Active = { Hiding = true, Downed = true, Escaped = true, Spectating = true },
			Hiding = { Active = true, Downed = true, Spectating = true },
			Downed = { Rescued = true, Eliminated = true, Spectating = true },
			Rescued = { Active = true, Hiding = true, Downed = true, Escaped = true },
			Eliminated = { Spectating = true },
			Escaped = { Spectating = true },
			Spectating = { Active = true },
		},
	},
	Hunter = {
		Initial = "PATROL",
		Transitions = {
			PATROL = { INVESTIGATE = true, CHASE = true },
			INVESTIGATE = { SEARCH = true, CHASE = true, RETURN = true },
			SEARCH = { INVESTIGATE = true, CHASE = true, RETURN = true },
			CHASE = { SEARCH = true, RETURN = true },
			RETURN = { PATROL = true, INVESTIGATE = true, CHASE = true },
		},
	},
}
