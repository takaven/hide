--!strict

local fs = require("@lune/fs")

local requiredFiles = {
	"README.md",
	"LICENSE",
	"THIRD_PARTY_NOTICES.md",
	"default.project.json",
	"rokit.toml",
	"wally.toml",
	"selene.toml",
	"stylua.toml",
	"docs/ARCHITECTURE.md",
	"docs/GAMEPLAY_SYSTEMS.md",
	"docs/SECURITY.md",
	"docs/OPEN_SOURCE_REUSE.md",
	"docs/PHASE1_HANDOFF.md",
	"docs/PHASE2_BUILD.md",
	"src/client/ClientMain.client.luau",
	"src/server/GameServer.server.luau",
	"src/server/domain/HidingSystem.luau",
	"src/server/domain/HunterBrain.luau",
	"src/server/runtime/NativeNavigationProvider.luau",
	"src/server/runtime/WorldBuilder.luau",
	"src/server/runtime/MovementNoiseService.luau",
	"src/server/runtime/CharacterPresentationService.luau",
	"src/shared/Config.luau",
	"tests/run.luau",
}

local missing = {}
for _, path in ipairs(requiredFiles) do
	if not fs.isFile(path) then
		table.insert(missing, path)
	end
end

if #missing > 0 then
	error(`missing required Phase-1 files:\n- {table.concat(missing, "\n- ")}`)
end

local envExample = fs.readFile(".env.example")
for _, placeholder in ipairs({ "ROBLOX_API_KEY", "ROBLOX_UNIVERSE_ID", "ROBLOX_PLACE_ID" }) do
	if string.find(envExample, placeholder, 1, true) == nil then
		error(`.env.example is missing {placeholder}`)
	end
end

print(`Structural validation passed ({#requiredFiles} required files).`)
