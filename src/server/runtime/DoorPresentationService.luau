--!strict

local TweenService = game:GetService("TweenService")

local DoorPresentationService = {}
DoorPresentationService.__index = DoorPresentationService

function DoorPresentationService.new(world: any, doors: any, playerStates: any, maxDistance: number)
	local self = setmetatable({
		_world = world,
		_doors = doors,
		_playerStates = playerStates,
		_maxDistance = maxDistance,
		_open = {},
	}, DoorPresentationService)
	for doorId, record in pairs(world.Doors) do
		local panel = record.instance:FindFirstChild("DoorPanel", true)
		if panel ~= nil and panel:IsA("BasePart") then
			self._open[doorId] = { panel = panel, closed = panel.CFrame, isOpen = false }
		end
	end
	return self
end

function DoorPresentationService:_setOpen(doorId: string, shouldOpen: boolean)
	local visual = self._open[doorId]
	if visual == nil or visual.isOpen == shouldOpen then
		return
	end
	visual.isOpen = shouldOpen
	local goal = if shouldOpen
		then visual.closed + visual.panel.CFrame.RightVector * 5.5
		else visual.closed
	TweenService:Create(visual.panel, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = goal })
		:Play()
	visual.panel.CanCollide = not shouldOpen
end

function DoorPresentationService:Tick(now: number)
	for doorId in pairs(self._open) do
		local door = self._doors:Get(doorId)
		if door ~= nil and door.heldBy ~= nil then
			local player = game:GetService("Players"):GetPlayerByUserId(tonumber(door.heldBy) or 0)
			local position = if player then self._world.GetPlayerPosition(player) else nil
			local state = self._playerStates:Get(door.heldBy)
			if
				position == nil
				or (position - door.position).Magnitude > self._maxDistance + 2
				or (state ~= "Active" and state ~= "Rescued")
			then
				self._doors:Release(door.heldBy, doorId, now)
			end
		end
		self:_setOpen(doorId, door ~= nil and door.heldBy ~= nil)
	end
end

function DoorPresentationService:ResetRound()
	for doorId in pairs(self._open) do
		self:_setOpen(doorId, false)
	end
end

return DoorPresentationService
