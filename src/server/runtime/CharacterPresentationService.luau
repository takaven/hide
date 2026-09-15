--!strict

local CharacterPresentationService = {}
CharacterPresentationService.__index = CharacterPresentationService

local function findPoint(record: any, name: string): BasePart?
	local instance = record and record.instance
	if instance == nil then
		return nil
	end
	local point = instance:FindFirstChild(name, true)
	return if point and point:IsA("BasePart") then point else nil
end

function CharacterPresentationService.new(world: any)
	return setmetatable({ _world = world, _hidden = {} }, CharacterPresentationService)
end

function CharacterPresentationService:Hide(player: Player, hidingId: string): (boolean, string?)
	local character = player.Character
	local record = self._world.Hiding[hidingId]
	local hiddenPoint = findPoint(record, "HiddenPoint")
	if character == nil or hiddenPoint == nil then
		return false, "hiding presentation point is unavailable"
	end
	self:Reveal(player)
	local saved = {
		pivot = character:GetPivot(),
		parts = {},
		appearances = {},
		humanoid = nil,
		connection = nil,
		seen = {},
	}
	local function conceal(descendant: Instance)
		if saved.seen[descendant] then
			return
		end
		saved.seen[descendant] = true
		if descendant:IsA("BasePart") then
			table.insert(saved.parts, {
				instance = descendant,
				transparency = descendant.Transparency,
				canCollide = descendant.CanCollide,
				canTouch = descendant.CanTouch,
				canQuery = descendant.CanQuery,
				castShadow = descendant.CastShadow,
				anchored = descendant.Anchored,
			})
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			table.insert(saved.appearances, {
				instance = descendant,
				transparency = descendant.Transparency,
			})
			descendant.Transparency = 1
		end
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		conceal(descendant)
	end
	saved.connection = character.DescendantAdded:Connect(conceal)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		saved.humanoid = {
			instance = humanoid,
			walkSpeed = humanoid.WalkSpeed,
			jumpPower = humanoid.JumpPower,
			autoRotate = humanoid.AutoRotate,
			displayDistanceType = humanoid.DisplayDistanceType,
		}
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	character:PivotTo(hiddenPoint.CFrame)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		root.Anchored = true
	end
	self._hidden[tostring(player.UserId)] = saved
	return true, nil
end

function CharacterPresentationService:Reveal(player: Player, hidingId: string?): boolean
	local playerId = tostring(player.UserId)
	local saved = self._hidden[playerId]
	local character = player.Character
	if saved == nil or character == nil then
		return false
	end
	if saved.connection ~= nil then
		saved.connection:Disconnect()
	end
	for _, entry in ipairs(saved.parts) do
		local instance = entry.instance
		if instance ~= nil and instance.Parent ~= nil then
			instance.Transparency = entry.transparency
			instance.CanCollide = entry.canCollide
			instance.CanTouch = entry.canTouch
			instance.CanQuery = entry.canQuery
			instance.CastShadow = entry.castShadow
			instance.Anchored = entry.anchored
		end
	end
	for _, entry in ipairs(saved.appearances) do
		local instance = entry.instance
		if instance ~= nil and instance.Parent ~= nil then
			instance.Transparency = entry.transparency
		end
	end
	local humanoidState = saved.humanoid
	if humanoidState ~= nil and humanoidState.instance.Parent ~= nil then
		humanoidState.instance.WalkSpeed = humanoidState.walkSpeed
		humanoidState.instance.JumpPower = humanoidState.jumpPower
		humanoidState.instance.AutoRotate = humanoidState.autoRotate
		humanoidState.instance.DisplayDistanceType = humanoidState.displayDistanceType
	end
	local record = if hidingId then self._world.Hiding[hidingId] else nil
	local exitPoint = findPoint(record, "HunterApproach")
	character:PivotTo(if exitPoint then exitPoint.CFrame + Vector3.new(0, 2, 0) else saved.pivot)
	self._hidden[playerId] = nil
	return true
end

function CharacterPresentationService:RevealById(playerId: string, hidingId: string?): boolean
	local player = game:GetService("Players"):GetPlayerByUserId(tonumber(playerId) or 0)
	return player ~= nil and self:Reveal(player, hidingId)
end

function CharacterPresentationService:ResetRound()
	for playerId in pairs(self._hidden) do
		local player = game:GetService("Players"):GetPlayerByUserId(tonumber(playerId) or 0)
		if player ~= nil then
			self:Reveal(player)
		end
	end
	table.clear(self._hidden)
end

return CharacterPresentationService
