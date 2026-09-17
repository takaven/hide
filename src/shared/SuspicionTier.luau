--!strict

local SuspicionTier = {}

function SuspicionTier.fromValues(config: any, heat: number, exposed: boolean): string
	if exposed then
		return "EXPOSED"
	elseif heat >= config.Hiding.InspectionHeatThreshold then
		return "HOT"
	elseif heat >= config.Hiding.WarmHeatThreshold then
		return "WARM"
	end
	return "SAFE"
end

return SuspicionTier
