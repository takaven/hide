--!strict

local Players = game:GetService("Players")

local PlayerStatePresentationService = {}
PlayerStatePresentationService.__index = PlayerStatePresentationService

function PlayerStatePresentationService.new(playerStates: any, worldRoot: Model)
	return setmetatable({
		_playerStates = playerStates,
		_worldRoot = worldRoot,
		_applied = {},
		_saved = {},
		_characters = {},
	}, PlayerStatePresentationService)
end

function PlayerStatePresentationService:_restore(playerId: string)
	local saved = self._saved[playerId]
	if saved == nil then
		return
	end
	for _, entry in ipairs(saved.parts) do
		if entry.instance.Parent ~= nil then
			entry.instance.Transparency = entry.transparency
			entry.instance.CanCollide = entry.canCollide
			entry.instance.CanTouch = entry.canTouch
			entry.instance.CanQuery = entry.canQuery
			entry.instance.Anchored = entry.anchored
		end
	end
	if saved.humanoid ~= nil and saved.humanoid.instance.Parent ~= nil then
		saved.humanoid.instance.WalkSpeed = saved.humanoid.walkSpeed
		saved.humanoid.instance.JumpPower = saved.humanoid.jumpPower
		saved.humanoid.instance.AutoRotate = saved.humanoid.autoRotate
	end
	if saved.marker ~= nil then
		saved.marker:Destroy()
	end
	self._saved[playerId] = nil
end

function PlayerStatePresentationService:_capture(playerId: string, character: Model): any
	self:_restore(playerId)
	local saved = { parts = {}, humanoid = nil, marker = nil }
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(saved.parts, {
				instance = descendant,
				transparency = descendant.Transparency,
				canCollide = descendant.CanCollide,
				canTouch = descendant.CanTouch,
				canQuery = descendant.CanQuery,
				anchored = descendant.Anchored,
			})
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		saved.humanoid = {
			instance = humanoid,
			walkSpeed = humanoid.WalkSpeed,
			jumpPower = humanoid.JumpPower,
			autoRotate = humanoid.AutoRotate,
		}
	end
	self._saved[playerId] = saved
	return saved
end

function PlayerStatePresentationService:_apply(player: Player, state: string)
	local playerId = tostring(player.UserId)
	local character = player.Character
	if character == nil then
		return
	end
	if state == "Active" or state == "Rescued" or state == "Hiding" then
		self:_restore(playerId)
		return
	end
	local saved = self:_capture(playerId, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if state == "Downed" then
		if humanoid ~= nil then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
			humanoid.AutoRotate = false
		end
		if root ~= nil and root:IsA("BasePart") then
			root.Anchored = true
			local marker = Instance.new("BillboardGui")
			marker.Name = "DownedMarker"
			marker.Size = UDim2.fromOffset(120, 34)
			marker.StudsOffset = Vector3.new(0, 3.5, 0)
			marker.AlwaysOnTop = true
			marker.MaxDistance = 55
			marker.Parent = root
			local label = Instance.new("TextLabel")
			label.BackgroundColor3 = Color3.fromRGB(128, 45, 39)
			label.BackgroundTransparency = 0.15
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GothamBold
			label.Text = "NEEDS RESCUE"
			label.TextColor3 = Color3.fromRGB(255, 239, 214)
			label.TextScaled = true
			label.Parent = marker
			saved.marker = marker
		end
	elseif state == "Eliminated" or state == "Escaped" or state == "Spectating" then
		for _, entry in ipairs(saved.parts) do
			entry.instance.Transparency = 1
			entry.instance.CanCollide = false
			entry.instance.CanTouch = false
			entry.instance.CanQuery = false
		end
		if humanoid ~= nil then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
		if root ~= nil and root:IsA("BasePart") then
			root.Anchored = true
		end
		local spectatorSpawn = self._worldRoot:FindFirstChild("SpectatorSpawn", true)
		if spectatorSpawn ~= nil and spectatorSpawn:IsA("BasePart") then
			character:PivotTo(spectatorSpawn.CFrame + Vector3.new(0, 3, 0))
		end
	end
end

function PlayerStatePresentationService:Tick()
	for _, player in ipairs(Players:GetPlayers()) do
		local playerId = tostring(player.UserId)
		local state = self._playerStates:Get(playerId)
		if
			state ~= nil
			and (self._applied[playerId] ~= state or self._characters[playerId] ~= player.Character)
		then
			self._characters[playerId] = player.Character
			self._applied[playerId] = state
			self:_apply(player, state)
		end
	end
end

function PlayerStatePresentationService:ResetRound()
	for playerId in pairs(self._saved) do
		self:_restore(playerId)
	end
	table.clear(self._applied)
	table.clear(self._characters)
end

return PlayerStatePresentationService
