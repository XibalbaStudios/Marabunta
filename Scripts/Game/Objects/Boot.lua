return {
	"ObjectsHelpers",
	"CoreReaders",
	"ScrollBarriers",
	"SpawnPoints",

	-- Setup for types too simple to merit dedicated files --
	function()
		local objects_helpers = require("game_objects_helpers")

		for _, type, params in require("iterators").ArgsByN(2,
			"condition_observers", nil,
			"entrances", { is_scene_based = true },
			"exits", nil
		) do
			objects_helpers.SetupType(type, params)
		end
	end,

	{ name = "Vars", boot = "Boot" }
}, ...