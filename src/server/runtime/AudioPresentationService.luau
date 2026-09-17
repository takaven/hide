--!strict

local SoundService = game:GetService("SoundService")

local AudioPresentationService = {}
AudioPresentationService.__index = AudioPresentationService

type SoundDefinition = { id: string, volume: number, looped: boolean, speed: number }

local SAFE_SOUNDS: { [string]: SoundDefinition } = {
	ListenerFootsteps = {
		id = "rbxasset://sounds/action_footsteps_plastic.mp3",
		volume = 0.5,
		looped = true,
		speed = 0.85,
	},
	ListenerPresence = {
		id = "rbxasset://sounds/action_falling.ogg",
		volume = 0.16,
		looped = true,
		speed = 0.32,
	},
	ListenerInspect = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.42,
		looped = false,
		speed = 0.72,
	},
	ListenerStop = {
		id = "rbxasset://sounds/switch.wav",
		volume = 0.72,
		looped = false,
		speed = 0.28,
	},
	ListenerChase = {
		id = "rbxasset://sounds/action_falling.ogg",
		volume = 0.3,
		looped = true,
		speed = 1.15,
	},
	HidingRustle = {
		id = "rbxasset://sounds/switch.wav",
		volume = 0.28,
		looped = false,
		speed = 0.72,
	},
	DoorBrace = { id = "rbxasset://sounds/switch.wav", volume = 0.42, looped = false, speed = 0.68 },
	DecoyClick = { id = "rbxasset://sounds/button.wav", volume = 0.55, looped = false, speed = 1.1 },
	Rescue = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.48,
		looped = false,
		speed = 1.18,
	},
	ExtractionAlarm = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.42,
		looped = true,
		speed = 0.58,
	},
	ReceptionPhone = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.6,
		looped = true,
		speed = 1.35,
	},
	Draw = { id = "rbxasset://sounds/switch.wav", volume = 0.68, looped = false, speed = 0.42 },
	FuseReset = { id = "rbxasset://sounds/switch.wav", volume = 0.8, looped = false, speed = 0.55 },
	Blackout = {
		id = "rbxasset://sounds/electronicpingshort.wav",
		volume = 0.7,
		looped = false,
		speed = 0.28,
	},
	BreathCritical = {
		id = "rbxasset://sounds/action_falling.ogg",
		volume = 0.2,
		looped = true,
		speed = 0.2,
	},
}

local function createSound(name: string, parent: Instance): Sound
	local definition = SAFE_SOUNDS[name]
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = definition.id
	sound.Volume = definition.volume
	sound.Looped = definition.looped
	sound.PlaybackSpeed = definition.speed
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 55
	if string.find(name, "Listener") ~= nil or name == "Blackout" then
		local equalizer = Instance.new("EqualizerSoundEffect")
		equalizer.HighGain = -8
		equalizer.MidGain = if name == "ListenerStop" then 3 else -2
		equalizer.LowGain = 5
		equalizer.Parent = sound
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = 2.4
		reverb.Density = 0.35
		reverb.Diffusion = 0.55
		reverb.DryLevel = -2
		reverb.WetLevel = -12
		reverb.Parent = sound
	end
	sound.Parent = parent
	return sound
end

function AudioPresentationService.new(worldRoot: Model)
	local self = setmetatable({ _worldRoot = worldRoot, _sounds = {} }, AudioPresentationService)
	local hunter = worldRoot:FindFirstChild("TheListener", true)
	local hunterRoot = if hunter then hunter:FindFirstChild("HumanoidRootPart") else nil
	if hunterRoot ~= nil then
		for _, name in ipairs({
			"ListenerFootsteps",
			"ListenerPresence",
			"ListenerInspect",
			"ListenerStop",
			"ListenerChase",
		}) do
			self._sounds[name] = createSound(name, hunterRoot)
		end
		self._sounds.ListenerPresence:Play()
	end
	local alarmParent = worldRoot:FindFirstChild("StormEvacuationGate", true) or SoundService
	self._sounds.ExtractionAlarm = createSound("ExtractionAlarm", alarmParent)
	local phone = worldRoot:FindFirstChild("ReceptionPhone", true)
	if phone ~= nil then
		self._sounds.ReceptionPhone = createSound("ReceptionPhone", phone)
	end
	local ambience = createSound("BreathCritical", SoundService)
	ambience.Volume = 0
	ambience:Play()
	self._sounds.BreathCritical = ambience
	return self
end

function AudioPresentationService:Play(name: string, parent: Instance?)
	local sound = self._sounds[name]
	if sound == nil and parent ~= nil and SAFE_SOUNDS[name] ~= nil then
		sound = createSound(name, parent)
	end
	if sound ~= nil then
		sound:Play()
	end
end

function AudioPresentationService:SetHunterState(state: string, moving: boolean)
	local footsteps = self._sounds.ListenerFootsteps
	local chase = self._sounds.ListenerChase
	if footsteps ~= nil then
		if moving and not footsteps.IsPlaying then
			footsteps:Play()
		end
		if not moving and footsteps.IsPlaying then
			footsteps:Stop()
		end
	end
	if chase ~= nil then
		if state == "CHASE" and not chase.IsPlaying then
			chase:Play()
		end
		if state ~= "CHASE" and chase.IsPlaying then
			chase:Stop()
		end
	end
end

function AudioPresentationService:SetBreathPressure(risk: number)
	local breath = self._sounds.BreathCritical
	if breath ~= nil then
		breath.Volume = math.clamp((risk - 0.65) * 0.5, 0, 0.18)
		breath.PlaybackSpeed = 0.18 + math.clamp(risk, 0, 1) * 0.18
	end
end

function AudioPresentationService:StopMoment(name: string)
	local sound = self._sounds[name]
	if sound ~= nil then
		sound:Stop()
	end
end

return AudioPresentationService
