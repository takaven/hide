--!strict

local Protocol
if script then
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	Protocol = require(ReplicatedStorage.Hide.Shared.RemoteProtocol)
else
	Protocol = require("../../shared/RemoteProtocol")
end

local ActionValidator = {}

local function validId(value: any, maximumLength: number): boolean
	return type(value) == "string"
		and #value > 0
		and #value <= maximumLength
		and string.match(value, "^[%w_-]+$") ~= nil
end

function ActionValidator.validate(payload: any, securityConfig: any): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "payload must be a table"
	end
	if type(payload.action) ~= "string" or Protocol.Actions[payload.action] ~= true then
		return false, "unknown action"
	end
	if not validId(payload.requestId, securityConfig.MaxRequestIdLength) then
		return false, "invalid request id"
	end

	local targetField = Protocol.TargetField[payload.action]
	if not validId(payload[targetField], securityConfig.MaxTargetIdLength) then
		return false, `invalid {targetField}`
	end
	if payload.action == "ResolveEntryRequest" and type(payload.accepted) ~= "boolean" then
		return false, "accepted must be a boolean"
	end

	local allowedKeys = { action = true, requestId = true, [targetField] = true }
	if payload.action == "ResolveEntryRequest" then
		allowedKeys.accepted = true
	end
	for key in pairs(payload) do
		if type(key) ~= "string" or allowedKeys[key] ~= true then
			return false, "payload contains unsupported fields"
		end
	end

	return true, nil
end

return ActionValidator
