-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A picture provides a common front-end for disparate graphics operations, e.g. texture
-- blits, filled or outline quads, gradient fills, etc., which can be switched out on demand.<br><br>
-- It satisfies the interface for <a href="Widget.html#Widget:SetPicture">widget pictures</a>.<br><br>
-- Class.
module Picture
]]

-- Standard library imports --
local assert = assert

-- Imports --
local NoOp = func_ops.NoOp

-- Unique member keys --
local _graphic = {}
local _props = {}

-- Picture class definition --
class.Define("Picture", function(Picture)
	--- Draws the picture in the given rect, delegating to the current graphic. If none is
	-- assigned, this is a no-op.
	-- @param x Rect x-coordinate.
	-- @param y Rect y-coordinate.
	-- @param w Rect width.
	-- @param h Rect height.
	-- @param props If provided, the set that is passed to the graphic; otherwise, the
	-- picture's property set is used.
	-- @see Picture:SetGraphic
	-- @see Picture:__cons
	function Picture:Draw (x, y, w, h, props)
		(self[_graphic] or NoOp)(x, y, w, h, props or self[_props])
	end

	---
	-- @return Picture graphic, or <b>nil</b> if absent.
	-- @see Picture:SetGraphic
	function Picture:GetGraphic ()
		return self[_graphic]
	end

	---
	-- @param name Non-<b>nil</b> name of property to get.
	-- @return Property value.
	function Picture:GetProperty (name)
		assert(name ~= nil, "name == nil")

		return self[_props][name]
	end

	---
	-- @param graphic Graphic to assign, or <b>nil</b> to remove the graphic.<br><br>
	-- A valid graphic is callable as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>graphic(x, y, w, h, props)</b></i>,<br><br>
	-- and will draw in the provided rect, customizing according to the options in <i>props</i>,
	-- which should be treated as read-only.
	-- @see Picture:__cons
	Picture.SetGraphic = func_ops.FuncSetter(_graphic, "Uncallable graphic", true)

	---
	-- @param name Non-<b>nil</b> name of property to set.
	-- @param value Value to assign to property.
	function Picture:SetProperty (name, value)
		assert(name ~= nil, "name == nil")

		self[_props][name] = value
	end

	--- Class constructor.
	-- @param graphic Graphic handle.
	-- @param props Reference to a property set, which is a collection of (name, value)
	-- pairs describing how to draw the graphic. If absent, a table is created internally.
	-- @see Picture:GetProperty
	-- @see Picture:SetGraphic
	-- @see Picture:SetProperty
	function Picture:__cons (graphic, props)
		self[_props] = props or {}

		self:SetGraphic(graphic)
	end
end)