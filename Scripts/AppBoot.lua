return {
	-- API utilities --
	{ name = "Utility", boot = "Boot" },

	-- API Classes --
	{ name = "Class", boot = "APIBoot" },

	-- Localization --
	{ name = "Localization", boot = "Boot" },
	
	-- Persistency
	{ name = "Persistency", boot = "Boot"},

	-- Configuration --
	{ name = "Config", boot = "Boot" },

	-- Support utilities --
	{ name = "Support", boot = "Boot" },

	-- Game classes --
	{ name = "Class", boot = "GameBoot" },

	-- Game logic --
	{ name = "Game", boot = "Boot" },
	
	--AI stuff
	
	
	{ name = "UIEditor", boot = "Boot" },

	-- Sections --
	{ name = "Section", boot = "Boot" },

	function()
		user_state.ActionMap():SetMode("UI")
		section.Screen("Play")
	end
}, ...