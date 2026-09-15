--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Protocol = require(ReplicatedStorage.Hide.Shared.RemoteProtocol)

local Remotes = {}

local function getOrCreate(folder: Folder, className: string, name: string): Instance
	local existing = folder:FindFirstChild(name)
	if existing ~= nil then
		assert(existing:IsA(className), `{name} has unexpected class {existing.ClassName}`)
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

function Remotes.create(): any
	local folder = ReplicatedStorage:FindFirstChild("HideRemotes")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "HideRemotes"
		folder.Parent = ReplicatedStorage
	end
	assert(folder:IsA("Folder"), "HideRemotes must be a Folder")

	return {
		ActionRequest = getOrCreate(folder, "RemoteEvent", Protocol.RequestEventName) :: RemoteEvent,
		ActionResult = getOrCreate(folder, "RemoteEvent", Protocol.ResultEventName) :: RemoteEvent,
		StateSnapshot = getOrCreate(folder, "RemoteEvent", Protocol.SnapshotEventName) :: RemoteEvent,
	}
end

return Remotes
