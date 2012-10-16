-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- Basic widget convenient for drawing a string. It is not necessary to specify its
-- dimensions when attaching, as these can be deduced from the string itself.<br><br>
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module String
]]

-- Imports --
local DrawString = widget_ops.DrawString
local SuperCons = class.SuperCons

-- String class definition --
class.Define("String", function(String)
	-- Dimension getters --
	for _, what, func in iterators.ArgsByN(2,
		--- Accessor, override of <b>Widget:GetH</b>.<br><br>
		-- The string widget will report its height based on its current string and font.
		-- @class function
		-- @name String:GetH
		-- @return Height.
		-- @see ~Widget:GetH
		"GetH", widget_ops.StringGetH,

		--- Accessor.
		-- @class function
		-- @name String:GetSize
		-- @return Width.
		-- @return Height.
		"GetSize", widget_ops.StringSize,

		--- Accessor, override of <b>Widget:GetW</b>.<br><br>
		-- The string widget will report its width based on its current string and font.
		-- @name String:GetW
		-- @class function
		-- @return Width.
		-- @see ~Widget:GetW
		"GetW", widget_ops.StringGetW
	) do
		String[what] = function(S)
			return func(S, S:GetString())
		end
	end

	--- Draws the string in the render rect.
	-- @class function
	-- @name Signals:render
	-- @see ~WidgetGroup:Render

	--
	local function Render (S, x, y, w, h)
		DrawString(S, S:GetString(), nil, nil, x, y, w, h)
	end

	--- Class constructor.
	function String:__cons ()
		SuperCons(self, "Widget")

		-- Signals --
		self:SetSlot("render", Render)
	end
end, { base = "Widget" })