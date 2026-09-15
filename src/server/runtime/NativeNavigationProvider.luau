--!strict

local PathfindingService = game:GetService("PathfindingService")

local NativeNavigationProvider = {}
NativeNavigationProvider.__index = NativeNavigationProvider

function NativeNavigationProvider.new(agentModel: Model, config: any)
	return setmetatable({
		_agent = agentModel,
		_config = config,
		_generation = 0,
		_status = "Idle",
		_statusGeneration = 0,
	}, NativeNavigationProvider)
end

function NativeNavigationProvider:GetStatus(): (string, number)
	return self._status, self._statusGeneration
end

function NativeNavigationProvider:_setStatus(generation: number, status: string): boolean
	if generation ~= self._generation then
		return false
	end
	self._status = status
	self._statusGeneration = generation
	return true
end

function NativeNavigationProvider:Cancel()
	self._generation += 1
	self:_setStatus(self._generation, "Cancelled")
	local humanoid = self._agent:FindFirstChildOfClass("Humanoid")
	local root = self._agent:FindFirstChild("HumanoidRootPart")
	if humanoid and root and root:IsA("BasePart") then
		humanoid:MoveTo(root.Position)
	end
end

function NativeNavigationProvider:MoveTo(goal: Vector3): (boolean, string?)
	self._generation += 1
	local generation = self._generation
	local humanoid = self._agent:FindFirstChildOfClass("Humanoid")
	local root = self._agent:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		self:_setStatus(generation, "Failed")
		return false, "hunter requires Humanoid and HumanoidRootPart"
	end

	self:_setStatus(generation, "Planning")

	task.spawn(function()
		local replans = 0
		while generation == self._generation and replans <= self._config.MaxReplans do
			local path = PathfindingService:CreatePath({ AgentCanJump = true, WaypointSpacing = 4 })
			local computed = pcall(function()
				path:ComputeAsync(root.Position, goal)
			end)
			if generation ~= self._generation then
				return
			end
			if not computed or path.Status ~= Enum.PathStatus.Success then
				replans += 1
				self:_setStatus(generation, "Replanning")
				task.wait(self._config.RepathInterval)
				continue
			end

			self:_setStatus(generation, "Moving")
			local shouldReplan = false
			local blockedConnection = path.Blocked:Connect(function()
				shouldReplan = true
			end)
			for _, waypoint in ipairs(path:GetWaypoints()) do
				if generation ~= self._generation or shouldReplan then
					break
				end
				if waypoint.Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end
				humanoid:MoveTo(waypoint.Position)
				local reached: boolean? = nil
				local moveConnection = humanoid.MoveToFinished:Connect(function(didReach)
					reached = didReach
				end)
				local lastPosition = root.Position
				local lastMovementAt = workspace:GetServerTimeNow()
				while reached == nil and generation == self._generation and not shouldReplan do
					task.wait(0.1)
					if (root.Position - lastPosition).Magnitude >= 0.5 then
						lastPosition = root.Position
						lastMovementAt = workspace:GetServerTimeNow()
					elseif
						workspace:GetServerTimeNow() - lastMovementAt >= self._config.StuckSeconds
					then
						shouldReplan = true
					end
				end
				moveConnection:Disconnect()
				if reached ~= true then
					shouldReplan = true
					break
				end
			end
			blockedConnection:Disconnect()
			if generation ~= self._generation then
				return
			elseif not shouldReplan then
				self:_setStatus(generation, "Completed")
				return
			end
			replans += 1
			self:_setStatus(generation, "Replanning")
			task.wait(self._config.RepathInterval)
		end
		if generation == self._generation then
			self:_setStatus(generation, "Failed")
		end
	end)

	return true, nil
end

return NativeNavigationProvider
