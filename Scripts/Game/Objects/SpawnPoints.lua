-- Standard library imports --
local match = string.match

-- Modules --
local mc = require("metacompiler")
local objects_helpers = require("game_objects_helpers")

-- Spawn point variable substitutions --
local Subs = mc.NewVarInterpTable()

-- Setup the spawn point type.
local Props = objects_helpers.SetupType("spawn_points", {
	epilogue_builder = function(_, name)
		if name == "OnKill" then
			return "ZoneVars:IncNumber($(KILLER):kill_count)"
-- elseif name == "OnSpawn" and enemy:GetSpawnPoint():USE_POWER_BAR
-- "declare("power_bar", power_bar), Hook up to HUD"
		end
	end,
	subs = Subs
})

-- Body for 'KILLER' substitution
local function AuxKILLER (object)
	return ""
end

-- 'KILLER' variable: substitute identifier for enemy killer.
-- Valid when name is "OnKill".
function Subs.KILLER (name, var)
	if name == "OnKill" then
		mc.Declare("GetKiller", AuxKILLER)

		return "%s", "GetKiller(object)"
	end
end