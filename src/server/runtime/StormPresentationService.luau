--!strict

local Lighting = game:GetService("Lighting")

local StormPresentationService = {}
StormPresentationService.__index = StormPresentationService

function StormPresentationService.new(worldRoot: Model)
	return setmetatable({ _root = worldRoot, _running = false }, StormPresentationService)
end

function StormPresentationService:Start()
	if self._running then
		return
	end
	self._running = true
	local rainVolume = Instance.new("Part")
	rainVolume.Name = "CycloneRainVolume"
	rainVolume.Anchored = true
	rainVolume.CanCollide = false
	rainVolume.Transparency = 1
	rainVolume.Size = Vector3.new(205, 1, 155)
	rainVolume.Position = Vector3.new(0, 65, 0)
	rainVolume.Parent = self._root
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "CycloneRain"
	rain.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	rain.Color = ColorSequence.new(Color3.fromRGB(181, 211, 220))
	rain.LightEmission = 0.15
	rain.LightInfluence = 0.55
	rain.Rate = 420
	rain.Lifetime = NumberRange.new(1.1, 1.5)
	rain.Speed = NumberRange.new(62, 76)
	rain.Acceleration = Vector3.new(18, -26, 6)
	rain.Drag = 1
	rain.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.09),
		NumberSequenceKeypoint.new(1, 0.04),
	})
	rain.Squash = NumberSequence.new(-0.8)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(5, 5)
	rain.Parent = rainVolume
	local wind = Instance.new("Sound")
	wind.Name = "CycloneWind"
	wind.SoundId = "rbxasset://sounds/action_falling.ogg"
	wind.Looped = true
	wind.Volume = 0.12
	wind.PlaybackSpeed = 0.38
	wind.RollOffMaxDistance = 260
	wind.Parent = rainVolume
	wind:Play()
	local thunder = Instance.new("Sound")
	thunder.Name = "CycloneThunder"
	thunder.SoundId = "rbxasset://sounds/impact_explosion_03.mp3"
	thunder.Volume = 0.32
	thunder.PlaybackSpeed = 0.48
	thunder.RollOffMaxDistance = 280
	thunder.Parent = rainVolume

	task.spawn(function()
		local baseline = Lighting.ExposureCompensation
		while self._running do
			task.wait(math.random(7, 16))
			thunder:Play()
			Lighting.ExposureCompensation = baseline + 1.1
			task.wait(0.08)
			Lighting.ExposureCompensation = baseline - 0.15
			task.wait(0.08)
			Lighting.ExposureCompensation = baseline + 0.65
			task.wait(0.06)
			Lighting.ExposureCompensation = baseline
		end
	end)
end

return StormPresentationService
