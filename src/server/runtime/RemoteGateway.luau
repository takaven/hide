--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ActionValidator = require(ReplicatedStorage.Hide.Shared.ActionValidator)
local RateLimiter = require(script.Parent.Parent.domain.RateLimiter)
local ReplayGuard = require(script.Parent.Parent.domain.ReplayGuard)

local RemoteGateway = {}
RemoteGateway.__index = RemoteGateway

function RemoteGateway.new(config: any, remotes: any, actionService: any)
	return setmetatable({
		_config = config,
		_remotes = remotes,
		_actionService = actionService,
		_rateLimiter = RateLimiter.new(config.Security.RateLimits),
		_replayGuard = ReplayGuard.new(config.Security.ReplayWindowSeconds),
		_connection = nil,
	}, RemoteGateway)
end

function RemoteGateway:_respond(
	player: Player,
	requestId: any,
	ok: boolean,
	result: any?,
	err: string?
)
	self._remotes.ActionResult:FireClient(player, {
		requestId = if type(requestId) == "string" then requestId else "invalid",
		ok = ok,
		result = result,
		error = err,
	})
end

function RemoteGateway:Start()
	assert(self._connection == nil, "RemoteGateway already started")
	self._connection = self._remotes.ActionRequest.OnServerEvent:Connect(
		function(player: Player, payload: any)
			self:Submit(player, payload)
		end
	)
end

function RemoteGateway:Submit(player: Player, payload: any)
	local valid, validationError = ActionValidator.validate(payload, self._config.Security)
	if not valid then
		self:_respond(
			player,
			if type(payload) == "table" then payload.requestId else nil,
			false,
			nil,
			validationError
		)
		return
	end

	local now = workspace:GetServerTimeNow()
	local playerId = tostring(player.UserId)
	local allowed, rateError = self._rateLimiter:Allow(playerId, payload.action, now)
	if not allowed then
		self:_respond(player, payload.requestId, false, nil, rateError)
		return
	end
	local fresh, replayError = self._replayGuard:Accept(playerId, payload.requestId, now)
	if not fresh then
		self:_respond(player, payload.requestId, false, nil, replayError)
		return
	end

	local called, result, actionError =
		pcall(self._actionService.Handle, self._actionService, player, payload, now)
	if not called then
		warn(`[HIDE] action handler failed for {payload.action}`)
		self:_respond(player, payload.requestId, false, nil, "server action failed")
	elseif result == nil then
		self:_respond(player, payload.requestId, false, nil, actionError)
	else
		self:_respond(player, payload.requestId, true, result, nil)
	end
end

return RemoteGateway
