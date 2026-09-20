--!strict

local RemoteProtocol = {}

RemoteProtocol.RequestEventName = "ActionRequest"
RemoteProtocol.ResultEventName = "ActionResult"
RemoteProtocol.SnapshotEventName = "StateSnapshot"
RemoteProtocol.SnapshotFunctionName = "GetStateSnapshot"

RemoteProtocol.Actions = {
	RequestHideEntry = true,
	ResolveEntryRequest = true,
	ExitHiding = true,
	VolunteerOut = true,
	Evict = true,
	UseDraw = true,
	HoldDoor = true,
	ReleaseDoor = true,
	StartRescue = true,
	CompleteRescue = true,
	UseDecoy = true,
	Escape = true,
	PeekHiding = true,
	RequestRematch = true,
	InviteFriend = true,
	OnboardingStep = true,
	SetCrouch = true,
}

RemoteProtocol.TargetField = {
	RequestHideEntry = "hidingId",
	ResolveEntryRequest = "entryRequestId",
	ExitHiding = "hidingId",
	VolunteerOut = "hidingId",
	Evict = "targetPlayerId",
	UseDraw = false,
	HoldDoor = "doorId",
	ReleaseDoor = "doorId",
	StartRescue = "targetPlayerId",
	CompleteRescue = "rescueId",
	UseDecoy = "decoyId",
	Escape = "extractionId",
	PeekHiding = "hidingId",
	RequestRematch = false,
	InviteFriend = false,
	OnboardingStep = "stepId",
	SetCrouch = false,
}

return RemoteProtocol
