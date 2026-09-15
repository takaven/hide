--!strict

local Assert = require("../Assert")
local Config = require("../../src/shared/Config")
local RescueSystem = require("../../src/server/domain/RescueSystem")

local function connected(_attempt: any): any
	return {
		rescuerConnected = true,
		targetConnected = true,
		rescuerState = "Active",
		targetState = "Downed",
		distance = 1,
	}
end

return {
	name = "rescue ownership expires on abandonment, state loss, removal, and reset",
	run = function()
		local rescue = RescueSystem.new(Config)
		local abandoned = rescue:Start("r1", "target", 0, 1, "Active", "Downed")
		rescue:Tick(1, function(attempt)
			local context = connected(attempt)
			context.distance = 100
			return context
		end)
		local cancelled = rescue:Tick(1 + Config.Rescue.RangeGraceSeconds, function(attempt)
			local context = connected(attempt)
			context.distance = 100
			return context
		end)
		Assert.equal(#cancelled, 1)
		Assert.equal(abandoned.status, "Cancelled")
		local replacement = rescue:Start("r2", "target", 3, 1, "Active", "Downed")
		Assert.truthy(replacement)
		local done =
			rescue:Complete("r2", replacement.id, 3 + Config.Rescue.Duration, 1, "Active", "Downed")
		Assert.equal(done.status, "Completed")
		Assert.equal(rescue:Complete("r2", replacement.id, 20, 1, "Active", "Downed"), nil)

		local disconnected = rescue:Start("r1", "target2", 20, 1, "Active", "Downed")
		rescue:Tick(21, function(attempt)
			local context = connected(attempt)
			context.rescuerConnected = false
			return context
		end)
		Assert.equal(disconnected.status, "Cancelled")
		local targetRemoved = rescue:Start("r1", "removed-target", 22, 1, "Active", "Downed")
		rescue:Tick(23, function(attempt)
			local context = connected(attempt)
			if attempt.id == targetRemoved.id then
				context.targetConnected = false
			end
			return context
		end)
		Assert.equal(targetRemoved.status, "Cancelled")

		for _, state in ipairs({ "Downed", "Eliminated", "Spectating" }) do
			local attempt =
				rescue:Start(`rescuer-{state}`, `target-{state}`, 30, 1, "Active", "Downed")
			rescue:Tick(31, function(item)
				local context = connected(item)
				if item.id == attempt.id then
					context.rescuerState = state
				end
				return context
			end)
			Assert.equal(attempt.status, "Cancelled")
		end

		local recovered = rescue:Start("r3", "recovered", 40, 1, "Active", "Downed")
		rescue:Tick(41, function(attempt)
			local context = connected(attempt)
			if attempt.id == recovered.id then
				context.targetState = "Rescued"
			end
			return context
		end)
		Assert.equal(recovered.status, "Cancelled")

		local stale = rescue:Start("r4", "stale", 50, 1, "Active", "Downed")
		rescue:Tick(stale.expiresAt + 0.1, connected)
		Assert.equal(stale.status, "Cancelled")
		Assert.truthy(rescue:Start("r5", "stale", stale.expiresAt + 1, 1, "Active", "Downed"))
		rescue:ResetRound()
		Assert.equal(rescue:Get(stale.id), nil)
	end,
}
