return {

	-- --
	"State",
	"MetaCompiler",
	"Modes",
	"Transitions",
	"Flow",
	"UI",
	"UICallbacks",

	-- --
	"Callbacks",

	-- --
	"PlayerControl",

	-- --
	{ name = "HUD", boot = "Boot" },
	{ name = "AI", boot = "Boot" },
	{ name = "Objects", boot = "Boot" },

	"Game",

	-- Metacompiler listings --
	function()
		local listings_file = debug_config.listings_file

		if listings_file then
			local open = require("io").open
			local first = true

			require("metacompiler").SetOutputFunc(
---[[
				function(str)
					local file = open(listings_file, first and "w+" or "a")

					if file then
						file:write(first and "" or "\n\n", str)
						file:close()

						first = false
					end
				end, 0	-- No format layers
--]]
--			printf, 2	-- string.format and then Vision formatting
			)
		end
	end
}, ...