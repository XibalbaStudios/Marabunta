-- Modules --
local mc = require("metacompiler")
local objects_helpers = require("game_objects_helpers")
local screen_effects = require("screen_effects")

-- Setup the scroll barrier type.
local Props = objects_helpers.SetupType("scroll_barriers", {
	epilogue_builder = function(_, name)
		-- Inject a warning when the wave begins.
		if name == "OnLock" then
			mc.Declare("HereComesAWave", screen_effects.HereComesAWave)

			return "HereComesAWave(object)"

		-- Inject a go signal when the wave ends.
		elseif name == "OnUnlock" then
			mc.Declare("GoGoGo", screen_effects.GoGoGo)

			return "GoGoGo(object)"
		end
	end
})