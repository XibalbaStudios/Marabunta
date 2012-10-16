-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A basic widget that can be clicked on and off, and queried about its state.<br><br>
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module Checkbox
]]

-- Imports --
local StateSwitch = widget_ops.StateSwitch
local SuperCons = class.SuperCons

-- Unique member keys --
local _is_checked = {}

-- Checkbox class definition --
class.Define("Checkbox", function(Checkbox)
	--- Status.
	-- @return If true, the box is checked.
	function Checkbox:IsChecked ()
		return self[_is_checked] == true
	end

	-- Toggle helper
	local function Toggle (C)
		C[_is_checked] = not C[_is_checked]
	end

	--- Sets the current check state. Toggles will send signals as<br><br>
	-- &nbsp&nbsp&nbsp<b><i>signal(C, "toggle")</i></b>,<br><br>
	-- where <i>signal</i> will be <b>switch_from</b> or <b>switch_to</b>, and <i>C</i>
	-- refers to this checkbox.
	-- @param check Check state to assign.
	-- @param always_refresh If true, receive <b>"switch_to"</b> signals even when the
	-- check state does not toggle.
	function Checkbox:SetCheck (check, always_refresh)
		StateSwitch(self, not check ~= not self[_is_checked], always_refresh, Toggle, "toggle")
	end

	-- Stock signals --
	local Signals = {}

	---
	-- @class function
	-- @name Signals:grab
	-- @see ~WidgetGroup:Execute
	Signals.grab = Toggle

	--- The <b>"checked"</b> or <b>"unchecked"</b> picture is drawn with the render rect, based
	-- on the current state. The <b>"frame"</b> picture is then drawn in the same area.
	-- @class function
	-- @name Signals:render
	-- @see ~WidgetGroup:Render

	--
	function Signals:render (x, y, w, h)
		self:DrawPicture(self[_is_checked] and "checked" or "unchecked", x, y, w, h)

		-- Frame the checkbox.
		self:DrawPicture("frame", x, y, w, h)
	end

	--- Class constructor.
	function Checkbox:__cons ()
		SuperCons(self, "Widget")

		-- Signals --
		self:SetMultipleSlots(Signals)
	end
end, { base = "Widget" })