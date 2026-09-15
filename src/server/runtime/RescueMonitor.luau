--!strict

local Players = game:GetService("Players")

local RescueMonitor = {}
RescueMonitor.__index = RescueMonitor

function RescueMonitor.new(rescue: any, playerStates: any, world: any, analytics: any?)
	return setmetatable(
		{ _rescue = rescue, _playerStates = playerStates, _world = world, _analytics = analytics },
		RescueMonitor
	)
end

function RescueMonitor:Tick(now: number): { any }
	local cancelled = self._rescue:Tick(now, function(attempt)
		local rescuerUserId = tonumber(attempt.rescuerId)
		local targetUserId = tonumber(attempt.targetId)
		local rescuer = if rescuerUserId then Players:GetPlayerByUserId(rescuerUserId) else nil
		local target = if targetUserId then Players:GetPlayerByUserId(targetUserId) else nil
		local rescuerPosition = if rescuer then self._world.GetPlayerPosition(rescuer) else nil
		local targetPosition = if target then self._world.GetPlayerPosition(target) else nil
		return {
			rescuerConnected = rescuer ~= nil,
			targetConnected = target ~= nil,
			rescuerState = self._playerStates:Get(attempt.rescuerId),
			targetState = self._playerStates:Get(attempt.targetId),
			distance = if rescuerPosition and targetPosition
				then (rescuerPosition - targetPosition).Magnitude
				else nil,
		}
	end)
	if self._analytics ~= nil then
		for _, attempt in ipairs(cancelled) do
			self._analytics:Emit("rescue_cancelled", {
				rescuerId = attempt.rescuerId,
				targetId = attempt.targetId,
				reason = attempt.cancelReason,
			}, now)
		end
	end
	return cancelled
end

return RescueMonitor
