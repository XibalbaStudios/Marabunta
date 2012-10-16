return {
	function()
		require("strict")

		debug.sethook()
	end,

	-- Debugging --
	{ name = "DebugHelpers", boot = "Boot" },

	-- Base functionality --
	{ name = "Base", boot = "Boot" },

	-- Enhance debugging support --
	function ()
		var_dump.SetDefaultOutf(printf)
	end,

	-- Primitive classes --
	{ name = "Class", boot = "PrimitivesBoot" }
}, ...