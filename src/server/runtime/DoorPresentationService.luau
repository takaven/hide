--!strict

local TweenService = game:GetService("TweenService")

local DoorPresentationService = {}
DoorPresentationService.__index = DoorPresentationService

function DoorPresentationService.new(
	world: any,
	doors: any,
	playerStates: any,
	maxDistance: number,
	audio: any?
)
	local self = setmetatable({
		_world = world,
		_doors = doors,
		_playerStates = playerStates,
		_maxDistance = maxDistance,
		_open = {},
		_holders = {},
		_audio = audio,
	}, DoorPresentationService)
	for doorId, record in pairs(world.Doors) do
		local panel = record.instance:FindFirstChild("DoorPanel", true)
		if panel ~= nil and panel:IsA("BasePart") then
			local closed = panel.CFrame
			local opened = closed + panel.CFrame.RightVector * 5.5
			panel.CFrame = opened
			panel.CanCollide = false
			self._open[doorId] = { panel = panel, closed = closed, opened = opened, braced = false }
		end
	end
	return self
end

function DoorPresentationService:_setBraced(doorId: string, braced: boolean)
	local visual = self._open[doorId]
	if visual == nil or visual.braced == braced then
		return
	end
	visual.braced = braced
	local goal = if braced then visual.closed else visual.opened
	TweenService:Create(visual.panel, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = goal })
		:Play()
	visual.panel.CanCollide = braced
	if braced and self._audio ~= nil then
		self._audio:Play("DoorBrace", visual.panel)
	end
end

function DoorPresentationService:_restoreHolder(playerId: string)
	local saved = self._holders[playerId]
	if saved == nil then
		return
	end
	if saved.humanoid.Parent ~= nil then
		saved.humanoid.WalkSpeed = saved.walkSpeed
		saved.humanoid.JumpPower = saved.jumpPower
	end
	self._holders[playerId] = nil
end

function DoorPresentationService:Tick(now: number)
	local activeHolders = {}
	for doorId in pairs(self._open) do
		local door = self._doors:Get(doorId)
		if door ~= nil and door.heldBy ~= nil then
			activeHolders[door.heldBy] = true
			local player = game:GetService("Players"):GetPlayerByUserId(tonumber(door.heldBy) or 0)
			local position = if player then self._world.GetPlayerPosition(player) else nil
			local state = self._playerStates:Get(door.heldBy)
			if player ~= nil and self._holders[door.heldBy] == nil then
				local humanoid = player.Character
					and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid ~= nil then
					self._holders[door.heldBy] = {
						humanoid = humanoid,
						walkSpeed = humanoid.WalkSpeed,
						jumpPower = humanoid.JumpPower,
					}
					humanoid.WalkSpeed = 0
					humanoid.JumpPower = 0
				end
			end
			if
				position == nil
				or (position - door.position).Magnitude > self._maxDistance + 2
				or (state ~= "Active" and state ~= "Rescued")
			then
				self:_restoreHolder(door.heldBy)
				self._doors:Release(door.heldBy, doorId, now)
			end
		end
		self:_setBraced(doorId, door ~= nil and door.heldBy ~= nil)
	end
	for playerId in pairs(self._holders) do
		if activeHolders[playerId] ~= true then
			self:_restoreHolder(playerId)
		end
	end
end

function DoorPresentationService:ResetRound()
	for doorId in pairs(self._open) do
		self:_setBraced(doorId, false)
	end
	for playerId in pairs(self._holders) do
		self:_restoreHolder(playerId)
	end
end

return DoorPresentationService
