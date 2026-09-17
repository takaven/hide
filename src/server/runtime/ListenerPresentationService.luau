--!strict

local RunService = game:GetService("RunService")

local ListenerPresentationService = {}
ListenerPresentationService.__index = ListenerPresentationService

local function motor(model: Model, name: string): Motor6D?
	local item = model:FindFirstChild(name, true)
	return if item and item:IsA("Motor6D") then item else nil
end

function ListenerPresentationService.new(model: Model)
	local self = setmetatable({
		_model = model,
		_time = 0,
		_connection = nil,
		_motors = {
			neck = motor(model, "ListenerNeck"),
			leftShoulder = motor(model, "ListenerLeftShoulder"),
			rightShoulder = motor(model, "ListenerRightShoulder"),
			leftHip = motor(model, "ListenerLeftHip"),
			rightHip = motor(model, "ListenerRightHip"),
		},
	}, ListenerPresentationService)
	self._connection = RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
	return self
end

function ListenerPresentationService:_step(dt: number)
	self._time += dt
	local state = self._model:GetAttribute("BrainState") or "PATROL"
	local listening = self._model:GetAttribute("Listening") == true
	local humanoid = self._model:FindFirstChildOfClass("Humanoid")
	local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.05
	local speed = if state == "CHASE" then 10 else 5
	local stride = if moving then math.sin(self._time * speed) else 0
	local reach = if state == "CHASE" then 0.82 else 0.34
	local motors = self._motors
	if motors.leftShoulder then
		motors.leftShoulder.Transform =
			CFrame.Angles(stride * reach, 0, if listening then -0.25 else -0.06)
	end
	if motors.rightShoulder then
		motors.rightShoulder.Transform =
			CFrame.Angles(-stride * reach, 0, if listening then 0.25 else 0.06)
	end
	if motors.leftHip then
		motors.leftHip.Transform = CFrame.Angles(-stride * reach * 0.7, 0, 0)
	end
	if motors.rightHip then
		motors.rightHip.Transform = CFrame.Angles(stride * reach * 0.7, 0, 0)
	end
	if motors.neck then
		if listening then
			motors.neck.Transform = CFrame.Angles(-0.16, math.sin(self._time * 1.7) * 0.34, -0.22)
		elseif state == "INVESTIGATE" or state == "SEARCH" then
			motors.neck.Transform = CFrame.Angles(0.08, math.sin(self._time * 1.4) * 0.18, 0)
		elseif state == "CHASE" then
			motors.neck.Transform = CFrame.Angles(-0.22, 0, 0)
		else
			motors.neck.Transform = CFrame.Angles(0, math.sin(self._time * 0.55) * 0.08, 0)
		end
	end
end

function ListenerPresentationService:ResetRound()
	self._model:SetAttribute("BrainState", "PATROL")
	self._model:SetAttribute("Listening", false)
end

return ListenerPresentationService
