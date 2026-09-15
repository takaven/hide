--!strict

local PlayerLifecycleService = {}
PlayerLifecycleService.__index = PlayerLifecycleService

function PlayerLifecycleService.new(coordinator: any, remotes: any)
	return setmetatable(
		{ _coordinator = coordinator, _remotes = remotes, _connections = {} },
		PlayerLifecycleService
	)
end

function PlayerLifecycleService:_cleanup(player: Player, event: string)
	self._coordinator:Cleanup(tostring(player.UserId), event, workspace:GetServerTimeNow())
	self._remotes.StateSnapshot:FireClient(player, {
		clearContext = true,
		clearEntryRequest = true,
	})
end

function PlayerLifecycleService:Attach(player: Player)
	local playerId = tostring(player.UserId)
	self._connections[playerId] = self._connections[playerId] or {}
	local connections = self._connections[playerId]
	local function attachCharacter(character: Model)
		self:_cleanup(player, "CharacterAdded")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
			or character:WaitForChild("Humanoid", 10)
		if humanoid ~= nil and humanoid:IsA("Humanoid") then
			table.insert(
				connections,
				humanoid.Died:Connect(function()
					if player.Character == character then
						self:_cleanup(player, "CharacterDied")
					end
				end)
			)
		end
	end
	table.insert(connections, player.CharacterAdded:Connect(attachCharacter))
	if player.Character ~= nil then
		attachCharacter(player.Character)
	end
end

function PlayerLifecycleService:Remove(player: Player)
	local playerId = tostring(player.UserId)
	self:_cleanup(player, "PlayerRemoving")
	local connections = self._connections[playerId]
	if connections ~= nil then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
	self._connections[playerId] = nil
end

return PlayerLifecycleService
