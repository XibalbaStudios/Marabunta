-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module PushButton
]]

-- Imports --
local ButtonStyleRender = widget_ops.ButtonStyleRender
local DrawString = widget_ops.DrawString
local NoOp = func_ops.NoOp
local SuperCons = class.SuperCons

-- Unique member keys --
local _action = {}
local _style = {}
local _sx = {}
local _sy = {}

-- Stock signals --
local Signals = {}

function Signals:drop (group)
	if self == group:GetEntered() then
		(self[_action] or NoOp)(self)
	end
end

function Signals:render (x, y, w, h, group)
	ButtonStyleRender(self, x, y, w, h, group)

	-- Draw the button string.
	local style, sx, sy = self:GetTextSetup()

	DrawString(self, self:GetString(), style, "center", x + sx, y + sy, w - sx, h - sy)
end

-- PushButton class definition --
class.Define("PushButton", function(PushButton)
	-- Returns: Pushbutton's action
	function PushButton:GetAction()
		return self[_action]
	end
	
	-- Returns: Horizontal text style, offset coordinates
	------------------------------------------------------
	function PushButton:GetTextSetup ()
		return self[_style] or "center", self[_sx] or 0, self[_sy] or 0
	end

	-- action: Action to assign
	----------------------------
	PushButton.SetAction = func_ops.FuncSetter(_action, "Uncallable action", true)
	

	-- style: Horizontal text style to assign
	-- sx, sy: Offset coordinates
	------------------------------------------
	function PushButton:SetTextSetup (style, sx, sy)
		if style == "center" then
			sx = 0
			sy = 0
		end

		self[_style] = style
		self[_sx] = sx
		self[_sy] = sy
	end

	--- Class constructor.
	function PushButton:__cons ()
		SuperCons(self, "Widget")

		-- Signals --
		self:SetMultipleSlots(Signals)
	end
end, { base = "Widget" })