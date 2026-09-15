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
	HoldDoor = true,
	ReleaseDoor = true,
	StartRescue = true,
	CompleteRescue = true,
	UseDecoy = true,
	Escape = true,
	PeekHiding = true,
}

RemoteProtocol.TargetField = {
	RequestHideEntry = "hidingId",
	ResolveEntryRequest = "entryRequestId",
	ExitHiding = "hidingId",
	HoldDoor = "doorId",
	ReleaseDoor = "doorId",
	StartRescue = "targetPlayerId",
	CompleteRescue = "rescueId",
	UseDecoy = "decoyId",
	Escape = "extractionId",
	PeekHiding = "hidingId",
}

return RemoteProtocol
