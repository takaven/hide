--!strict

local SuspicionSnapshotPolicy = {}

function SuspicionSnapshotPolicy.shouldEmit(
	previousState: string?,
	state: string,
	previousRisk: number?,
	risk: number,
	previousTier: string?,
	tier: string
): boolean
	return previousState ~= state
		or previousRisk == nil
		or math.abs(previousRisk - risk) >= 0.04
		or previousTier ~= tier
end

return SuspicionSnapshotPolicy
