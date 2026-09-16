--!strict

local specs = {
	require("./specs/StateMachines.spec"),
	require("./specs/SharedSilence.spec"),
	require("./specs/HidingSystem.spec"),
	require("./specs/NoiseAndHeat.spec"),
	require("./specs/CooperationSystems.spec"),
	require("./specs/HunterAndDecoy.spec"),
	require("./specs/Security.spec"),
	require("./specs/ConfigAndAnalytics.spec"),
	require("./specs/HidingExposure.spec"),
	require("./specs/HeatDiscovery.spec"),
	require("./specs/RescueLifecycle.spec"),
	require("./specs/HunterInvestigation.spec"),
	require("./specs/LifecycleAndAtomicity.spec"),
	require("./specs/PlayableRemediation.spec"),
	require("./specs/StagingGate.spec"),
	require("./specs/LaunchReadiness.spec"),
}

local passed = 0
for _, spec in ipairs(specs) do
	local ok, err = pcall(spec.run)
	if ok then
		passed += 1
		print(`PASS {spec.name}`)
	else
		warn(`FAIL {spec.name}\n{tostring(err)}`)
	end
end

if passed ~= #specs then
	error(`test run failed: {passed}/{#specs} specs passed`)
end

print(`All {passed} specs passed.`)
