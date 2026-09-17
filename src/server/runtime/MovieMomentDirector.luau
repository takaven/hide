--!strict

local MovieMomentDirector = {}
MovieMomentDirector.__index = MovieMomentDirector
local WeightedChoice = require(script.Parent.Parent.domain.WeightedChoice)

function MovieMomentDirector.new(dependencies: any)
	dependencies._count = 0
	dependencies._lastAt = -math.huge
	dependencies._phase = nil
	dependencies._phaseStartedAt = 0
	dependencies._huntMomentAt = math.huge
	dependencies._blackoutGeneration = 0
	dependencies._random = Random.new()
	dependencies._lastHuntMoment = nil
	dependencies._gateJamPlanned = false
	return setmetatable(dependencies, MovieMomentDirector)
end

function MovieMomentDirector:_announce(kind: string, message: string, now: number)
	self.WorldRoot:SetAttribute("LastMovieMoment", kind)
	self.WorldRoot:SetAttribute("MovieMomentCount", self._count + 1)
	self.Remotes.StateSnapshot:FireAllClients({
		movieMoment = { type = kind, message = message },
	})
	self.Analytics:Emit("movie_moment", { source = kind }, now)
end

function MovieMomentDirector:_blackout(now: number)
	self._blackoutGeneration += 1
	local generation = self._blackoutGeneration
	self.WorldRoot:SetAttribute(
		"HunterVisionMultiplier",
		self.Config.MovieMoments.BlackoutVisionMultiplier
	)
	self.WorldRoot:SetAttribute(
		"MovementNoiseMultiplier",
		self.Config.MovieMoments.BlackoutMovementNoiseMultiplier
	)
	for _, descendant in ipairs(self.WorldRoot:GetDescendants()) do
		if descendant:IsA("PointLight") and descendant.Parent.Name ~= "EmergencyLight" then
			descendant.Enabled = false
		end
	end
	self:_announce("CYCLONE_BLACKOUT", "BLACKOUT — MOVE CAREFULLY", now)
	task.delay(self.Config.MovieMoments.BlackoutDuration, function()
		if self._blackoutGeneration ~= generation then
			return
		end
		self.WorldRoot:SetAttribute("HunterVisionMultiplier", 1)
		self.WorldRoot:SetAttribute("MovementNoiseMultiplier", 1)
		for _, descendant in ipairs(self.WorldRoot:GetDescendants()) do
			if descendant:IsA("PointLight") then
				descendant.Enabled = true
			end
		end
	end)
end

function MovieMomentDirector:Trigger(kind: string, now: number): boolean
	if self.Config.Prototype ~= nil and self.Config.Prototype.MovieMomentsEnabled ~= true then
		return false
	end
	if self._count >= self.Config.MovieMoments.MaxPerRound then
		return false
	end
	if self._count > 0 and now - self._lastAt < self.Config.MovieMoments.MinimumSpacing then
		return false
	end
	if kind == "CYCLONE_BLACKOUT" then
		self:_blackout(now)
	elseif kind == "RECEPTION_PHONE" then
		local phone = self.WorldRoot:FindFirstChild("ReceptionPhone", true)
		if phone == nil or not phone:IsA("BasePart") then
			return false
		end
		self.Noise:Add({
			origin = phone.Position,
			magnitude = self.Config.MovieMoments.ReceptionPhoneMagnitude,
			category = "Environment",
			sourceId = "reception-phone",
			hunterRelevant = true,
		}, now)
		self.Audio:Play("ReceptionPhone")
		self:_announce(kind, "THE RECEPTION PHONE IS RINGING", now)
		task.delay(6, function()
			self.Audio:StopMoment("ReceptionPhone")
		end)
	elseif kind == "GENERATOR_RESTART" then
		local point = self.WorldRoot:FindFirstChild("GeneratorEventPoint", true)
		if point == nil or not point:IsA("BasePart") then
			return false
		end
		self.Noise:Add({
			origin = point.Position,
			magnitude = self.Config.MovieMoments.GeneratorMagnitude,
			category = "Environment",
			sourceId = "generator-restart",
			hunterRelevant = true,
		}, now)
		self:_announce(kind, "THE GENERATOR IS RESTARTING", now)
	elseif kind == "DOUBLE_TAKE" then
		if not self.Hunter:RequestDoubleTake() then
			return false
		end
		self:_announce(kind, "THE LISTENER STOPPED — DID IT HEAR THAT?", now)
	elseif kind == "FINAL_ESCAPE_EVENT" then
		self.Audio:Play("ExtractionAlarm")
		self:_announce(kind, "EVACUATION GATE JAMMED — ROUTE CHANGING", now)
		task.delay(self.Config.Extraction.GateJamDuration, function()
			local activeId = self.Extraction:SwitchActive()
			self.Remotes.StateSnapshot:FireAllClients({
				activeExtractionId = activeId,
				movieMoment = { type = kind, message = "ALTERNATE SERVICE EXIT OPEN" },
			})
		end)
	else
		return false
	end
	self._count += 1
	self._lastAt = now
	if type(self.Config.MovieMoments.Weights[kind]) == "number" then
		self._lastHuntMoment = kind
	end
	return true
end

function MovieMomentDirector:Tick(now: number, phase: string)
	if self.Config.Prototype ~= nil and self.Config.Prototype.MovieMomentsEnabled ~= true then
		return
	end
	if phase ~= self._phase then
		self._phase = phase
		self._phaseStartedAt = now
		if phase == "Hunt" and self._count == 0 then
			self._huntMomentAt = now
				+ self._random:NextNumber(
					self.Config.MovieMoments.HuntMinimumDelay,
					self.Config.MovieMoments.HuntMaximumDelay
				)
		end
	end
	if self._count >= self.Config.MovieMoments.MaxPerRound then
		return
	end
	if phase == "Hunt" and self._count == 0 and now >= self._huntMomentAt then
		local selected = WeightedChoice.select(
			self.Config.MovieMoments.Weights,
			self._random:NextNumber(),
			self._lastHuntMoment
		)
		if selected ~= nil and not self:Trigger(selected, now) then
			-- A rejected Double Take is silent; schedule a fresh authored choice.
			self._huntMomentAt = now + 1
		end
	elseif
		phase == "Extraction"
		and self._count == 1
		and self._gateJamPlanned
		and now - self._phaseStartedAt >= self.Config.Extraction.GateJamDelay
	then
		self:Trigger("FINAL_ESCAPE_EVENT", now)
	end
end

function MovieMomentDirector:ResetRound()
	self._count = 0
	self._lastAt = -math.huge
	self._phase = nil
	self._huntMomentAt = math.huge
	self._gateJamPlanned = self._random:NextNumber() < self.Config.MovieMoments.GateJamChance
	self._blackoutGeneration += 1
	self.WorldRoot:SetAttribute("HunterVisionMultiplier", 1)
	self.WorldRoot:SetAttribute("MovementNoiseMultiplier", 1)
	self.WorldRoot:SetAttribute("MovieMomentCount", 0)
	self.Audio:StopMoment("ReceptionPhone")
	self.Audio:StopMoment("ExtractionAlarm")
	for _, descendant in ipairs(self.WorldRoot:GetDescendants()) do
		if descendant:IsA("PointLight") then
			descendant.Enabled = true
		end
	end
end

return MovieMomentDirector
