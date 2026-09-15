--!strict

local PlayerLifecycle = {}
PlayerLifecycle.__index = PlayerLifecycle

function PlayerLifecycle.new(dependencies: any)
	return setmetatable(dependencies, PlayerLifecycle)
end

function PlayerLifecycle:Cleanup(playerId: string, event: string, now: number): any
	local stateBefore = self.PlayerStates:Get(playerId)
	local hidingId = self.Hiding:GetPlayerSpot(playerId)
	if hidingId ~= nil and self.Presentation ~= nil then
		self.Presentation:RevealById(playerId, hidingId)
	end
	local hidingResult = self.Hiding:RemovePlayer(playerId)
	local releasedDoors = self.Doors:ReleaseByPlayer(playerId, now)
	local cancelledRescues = self.Rescue:CancelByPlayer(playerId, event, now)
	if stateBefore ~= "Downed" or event == "PlayerRemoving" then
		self.Capture:Clear(playerId)
	end

	if stateBefore == "Hiding" then
		self.PlayerStates:Transition(playerId, "Active", `lifecycle cleanup: {event}`, now)
	end
	if event == "CharacterDied" then
		local current = self.PlayerStates:Get(playerId)
		if current == "Active" or current == "Rescued" then
			self.Capture:Down(playerId, now)
		end
	elseif event == "PlayerRemoving" then
		local current = self.PlayerStates:Get(playerId)
		if current ~= nil and current ~= "Spectating" then
			self.PlayerStates:Transition(playerId, "Spectating", "player removed", now)
		end
	end

	return {
		event = event,
		stateBefore = stateBefore,
		stateAfter = self.PlayerStates:Get(playerId),
		hidingId = hidingResult.hidingId,
		releasedDoors = releasedDoors,
		cancelledRescues = cancelledRescues,
	}
end

return PlayerLifecycle
