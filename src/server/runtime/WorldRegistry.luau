--!strict

local CollectionService = game:GetService("CollectionService")

local WorldRegistry = {}
WorldRegistry.__index = WorldRegistry

WorldRegistry.Tags = {
	Hiding = "HideHidingSpot",
	Door = "HideDoor",
	Extraction = "HideExtraction",
	Hunter = "HideHunter",
	PatrolPoint = "HidePatrolPoint",
}

local function resolvePosition(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

local function readId(instance: Instance, attributeName: string): string?
	local value = instance:GetAttribute(attributeName)
	if type(value) == "string" and value ~= "" and #value <= 64 then
		return value
	end
	return nil
end

function WorldRegistry.new()
	return setmetatable(
		{ Hiding = {}, Doors = {}, Extractions = {}, Hunters = {}, PatrolPoints = {} },
		WorldRegistry
	)
end

function WorldRegistry:Scan(): { string }
	local errors = {}
	self.Hiding = {}
	self.Doors = {}
	self.Extractions = {}
	self.Hunters = {}
	self.PatrolPoints = {}

	for _, instance in ipairs(CollectionService:GetTagged(WorldRegistry.Tags.Hiding)) do
		local id = readId(instance, "HidingId")
		local position = resolvePosition(instance)
		local capacity = instance:GetAttribute("Capacity")
		if
			id == nil
			or position == nil
			or type(capacity) ~= "number"
			or capacity < 1
			or capacity % 1 ~= 0
		then
			table.insert(errors, `{instance:GetFullName()} has invalid hiding attributes`)
		elseif self.Hiding[id] ~= nil then
			table.insert(errors, `duplicate HidingId {id}`)
		else
			self.Hiding[id] =
				{ id = id, instance = instance, position = position, capacity = capacity }
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(WorldRegistry.Tags.Door)) do
		local id = readId(instance, "DoorId")
		local position = resolvePosition(instance)
		if id == nil or position == nil then
			table.insert(errors, `{instance:GetFullName()} has invalid door attributes`)
		elseif self.Doors[id] ~= nil then
			table.insert(errors, `duplicate DoorId {id}`)
		else
			self.Doors[id] = { id = id, instance = instance, position = position }
		end
	end

	for _, instance in ipairs(CollectionService:GetTagged(WorldRegistry.Tags.Extraction)) do
		local id = readId(instance, "ExtractionId")
		local position = resolvePosition(instance)
		if id == nil or position == nil then
			table.insert(errors, `{instance:GetFullName()} has invalid extraction attributes`)
		elseif self.Extractions[id] ~= nil then
			table.insert(errors, `duplicate ExtractionId {id}`)
		else
			self.Extractions[id] = { id = id, instance = instance, position = position }
		end
	end

	self.Hunters = CollectionService:GetTagged(WorldRegistry.Tags.Hunter)
	self.PatrolPoints = CollectionService:GetTagged(WorldRegistry.Tags.PatrolPoint)
	return errors
end

function WorldRegistry.GetPlayerPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	return character:GetPivot().Position
end

function WorldRegistry.DistanceFromPlayer(player: Player, position: Vector3): number?
	local playerPosition = WorldRegistry.GetPlayerPosition(player)
	return if playerPosition then (playerPosition - position).Magnitude else nil
end

return WorldRegistry
