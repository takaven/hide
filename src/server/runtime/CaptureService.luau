--!strict

local CaptureService = {}
CaptureService.__index = CaptureService

function CaptureService.new(
	config: any,
	playerStates: any,
	hiding: any,
	analytics: any,
	remotes: any,
	presentation: any?
)
	return setmetatable({
		_config = config,
		_playerStates = playerStates,
		_hiding = hiding,
		_analytics = analytics,
		_remotes = remotes,
		_presentation = presentation,
		_deadlines = {},
		_lastCapture = {},
	}, CaptureService)
end

function CaptureService:ResetRound()
	self._deadlines = {}
	self._lastCapture = {}
end

function CaptureService:Down(playerId: string, now: number): (boolean, string?)
	local lastCapture = self._lastCapture[playerId]
	if lastCapture ~= nil and now - lastCapture < self._config.Hunter.CaptureCooldown then
		return false, "capture is on cooldown"
	end
	local hidingId = self._hiding:GetPlayerSpot(playerId)
	if hidingId ~= nil then
		if self._presentation ~= nil then
			self._presentation:RevealById(playerId, hidingId)
		end
		self._hiding:Exit(playerId, hidingId)
	end
	local ok, err =
		self._playerStates:Capture(playerId, self._config.Rescue.CapturesBeforeElimination, now)
	if not ok then
		return false, err
	end
	self._lastCapture[playerId] = now
	local captureCount = self._playerStates:GetCaptureCount(playerId)
	if captureCount >= self._config.Rescue.CapturesBeforeElimination then
		self._playerStates:ResolveDowned(
			playerId,
			self._config.Rescue.CapturesBeforeElimination,
			false,
			now
		)
		self._analytics:Emit(
			"player_eliminated",
			{ playerId = playerId, reason = "capture_limit" },
			now
		)
	else
		self._deadlines[playerId] = now + self._config.Rescue.DownedDuration
		self._analytics:Emit(
			"player_downed",
			{ playerId = playerId, captureCount = captureCount },
			now
		)
	end
	self._remotes.StateSnapshot:FireAllClients({
		playerId = playerId,
		state = self._playerStates:Get(playerId),
	})
	local userId = tonumber(playerId)
	local player = if userId then game:GetService("Players"):GetPlayerByUserId(userId) else nil
	if player ~= nil then
		self._remotes.StateSnapshot:FireClient(player, {
			clearContext = true,
			clearEntryRequest = true,
		})
	end
	return true, nil
end

function CaptureService:Clear(playerId: string)
	self._deadlines[playerId] = nil
end

function CaptureService:Tick(now: number)
	for playerId, deadline in pairs(self._deadlines) do
		if now >= deadline and self._playerStates:Get(playerId) == "Downed" then
			self._playerStates:ResolveDowned(
				playerId,
				self._config.Rescue.CapturesBeforeElimination,
				false,
				now
			)
			self._analytics:Emit(
				"player_eliminated",
				{ playerId = playerId, reason = "downed_timeout" },
				now
			)
			self._remotes.StateSnapshot:FireAllClients({ playerId = playerId, state = "Eliminated" })
			self._deadlines[playerId] = nil
		end
	end
end

return CaptureService
