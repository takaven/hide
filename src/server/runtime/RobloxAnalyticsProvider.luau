--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

local RobloxAnalyticsProvider = {}
RobloxAnalyticsProvider.__index = RobloxAnalyticsProvider

local function fieldValue(properties: any, keys: { string }): string?
	for _, key in ipairs(keys) do
		local value = properties[key]
		if value ~= nil then
			return string.sub(tostring(value), 1, 50)
		end
	end
	return nil
end

function RobloxAnalyticsProvider.new(mapId: string)
	return setmetatable({ _mapId = mapId }, RobloxAnalyticsProvider)
end

function RobloxAnalyticsProvider:Emit(envelope: any)
	local properties = envelope.properties
	local playerId = fieldValue(properties, { "playerId", "rescuerId", "targetId" })
	local recipients = {}
	if playerId ~= nil then
		local player = Players:GetPlayerByUserId(tonumber(playerId) or 0)
		if player ~= nil then
			table.insert(recipients, player)
		end
	else
		recipients = Players:GetPlayers()
	end
	local customFields = {
		[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = self._mapId,
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name] = fieldValue(
			properties,
			{ "hidingId", "extractionId", "doorId", "source", "reason" }
		) or "none",
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name] = fieldValue(
			properties,
			{ "phase", "state", "evidenceKind" }
		) or "none",
	}
	local value = tonumber(properties.duration or properties.risk or properties.playerCount) or 1
	for _, player in ipairs(recipients) do
		AnalyticsService:LogCustomEvent(player, envelope.name, value, customFields)
	end
end

return RobloxAnalyticsProvider
