-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A multipicture provides for 3- and 9-slice graphics, which given suitable art can be
-- stretched without visual artifacts.<br><br>
-- It satisfies the interface for <a href="Widget.html#Widget:SetPicture">widget pictures</a>.<br><br>
-- Class.
module MultiPicture
]]

-- Standard library imports --
local assert = assert
local yield = coroutine.yield

-- Imports --
local IsPositiveInteger = var_preds.IsPositiveInteger

-- Unique member keys --
local _array = {}
local _iter = {}
local _props = {}
local _thresholds = {}

-- MultiPicture class definition --
class.Define("MultiPicture", function(MultiPicture)
	-- Threshold options --
	local Thresholds = table_ops.MakeSet{ "left", "right", "top", "bottom" }

	-- thresholds: Scale thresholds
	-- total: Total size in coordinate
	-- kb, ke: Begin, end lookup keys
	-- Returns: Begin, middle, end size
	local function GetSizes (thresholds, total, kb, ke)
		local bsize = thresholds[kb] or 0
		local esize = thresholds[ke] or 0
		local extra = total - (bsize + esize)
		local scale = 1

		if extra <= 0 then
			extra = 0
			scale = total / (bsize + esize)
		end

		return bsize * scale, extra, esize * scale
	end

	-- Iterator modes --
	local Modes = {}

	function Modes:grid (x1, y1, w, h)
		local thresholds = self[_thresholds]

		local lw, mw, rw = GetSizes(thresholds, w, "left", "right")
		local th, mh, bh = GetSizes(thresholds, h, "top", "bottom")

		local x2, y2 = x1 + lw, y1 + th
		local x3, y3 = x2 + mw, y2 + mh

		-- Supply the corners.
		yield(1, x1, y1, lw, th)
		yield(3, x3, y1, rw, th)
		yield(7, x1, y3, lw, bh)
		yield(9, x3, y3, rw, bh)

		-- Supply the top and bottom sides.
		if mw > 0 then
			yield(2, x2, y1, mw, th)
			yield(8, x2, y3, mw, bh)
		end

		-- Supply the left and right sides.
		if mh > 0 then
			yield(4, x1, y2, lw, mh)
			yield(6, x3, y2, rw, mh)
		end

		-- Supply the middle.
		if mw > 0 and mh > 0 then
			yield(5, x2, y2, mw, mh)
		end
	end

	function Modes:hline (x, y, w, h)
		local lw, mw, rw = GetSizes(self[_thresholds], w, "left", "right")

		-- Supply the sides.
		yield(1, x, y, lw, h)
		yield(3, x + lw + mw, y, rw, h)

		-- Supply the middle.
		if mw > 0 then
			yield(2, x + lw, y, mw, h)
		end
	end

	function Modes:vline (x, y, w, h)
		local th, mh, bh = GetSizes(self[_thresholds], h, "top", "bottom")

		-- Supply the sides.
		yield(1, x, y, w, th)
		yield(3, x, y + mh + th, w, bh)

		-- Supply the middle.
		if mh > 0 then
			yield(2, x, y + th, w, mh)
		end
	end

	-- Picture iterator --
	local Iter = coroutine_ex.Iterator(function(P, x, y, w, h)
		P[_iter](P, x, y, w, h)
	end)

	--- Draws the multipicture in the given rect.<br><br>
	-- For a row, the width is measured against the <b>left</b> and <b>right</b> thresholds.
	-- The left and right pictures are each allocated an equal portion of the width; if one
	-- has reached its threshold, the excess is given to the other. If both pictures have
	-- reached the threshold, they no longer scale, and the middle picture is drawn with
	-- the remaining width (in <b>grid</b> mode, picture #5 must also have non-0 height).<br><br>
	-- A column is similar, using the <b>top</b> and <b>bottom</b> thresholds instead.<br><br>
	-- In <b>grid</b> mode, there are three rows, from top to bottom, using pictures 1-3,
	-- 4-6, and 7-9, and all thresholds are considered. Pictures #2 and 8 should scale
	-- width-wise, #4 and 6 height-wise, and #5 both width- and height-wise.<br><br>
	-- In <b>hline</b> mode, pictures 1-3 are used and follow the row logic. Picture #2
	-- should scale width-wise.<br><br>
	-- In <b>vline</b> mode, pictures 1-3 are used and follow the column logic. Picture #2
	-- should scale height-wise.
	-- @param x Rect x-coordinate.
	-- @param y Rect y-coordinate.
	-- @param w Rect width.
	-- @param h Rect height.
	-- @param props If provided, the set that is passed on to the sub-pictures; otherwise,
	-- the multipicture's property set is used.
	-- @see MultiPicture:SetPicture
	-- @see MultiPicture:__cons
	function MultiPicture:Draw (x, y, w, h, props)
		props = props or self[_props]

		-- Draw each component picture.
		local array = self[_array]

		for i, px, py, pw, ph in Iter(self, x, y, w, h) do
			if array[i] then
				array[i]:Draw(px, py, pw, ph, props)
			end
		end
	end

	---
	-- @param name Non-<b>nil</b> name of property to get.
	-- @return Property value.
	function MultiPicture:GetProperty (name)
		assert(name ~= nil, "name == nil")

		return self[_props][name]
	end

	---
	-- @param name Threshold name.
	-- @return Threshold value, 0 by default.
	-- @see MultiPicture:SetThreshold
	function MultiPicture:GetThreshold (name)
		assert(Thresholds[name], "Invalid threshold")

		return self[_thresholds][name] or 0
	end

	---
	-- @param mode Draw mode to assign, which may be <b>"grid"</b>, <b>"hline"</b>, or
	-- <b>"vline"</b>.
	function MultiPicture:SetMode (mode)
		self[_iter] = assert(Modes[mode], "Invalid mode")
		self[_array] = {}
	end

	---
	-- @param slot Integer index in [1, 9].
	-- @param picture Picture to assign, which must have at least a <b>Draw</b> method
	-- that conforms to <b>Picture:Draw</b>. If <b>nil</b>, the picture is cleared.
	-- @see ~Picture:Draw
	function MultiPicture:SetPicture (slot, picture)
		assert(IsPositiveInteger(slot) and slot <= 9, "Invalid slot")

		self[_array][slot] = picture
	end

	---
	-- @param name Non-<b>nil</b> name of property to set.
	-- @param value Value to assign to property.
	function MultiPicture:SetProperty (name, value)
		assert(name ~= nil, "name == nil")

		self[_props][name] = value
	end

	---
	-- @param name Threshold name, which must be <b>"left"</b>, <b>"right"</b>, <b>"top"</b>,
	-- or <b>"bottom"</b>.
	-- @param value Non-negative value to assign.
	function MultiPicture:SetThreshold (name, value)
		assert(Thresholds[name], "Invalid threshold")

		self[_thresholds][name] = value
	end

	--- Class constructor.
	-- @param mode Default mode, or <b>"grid"</b> if absent.
	-- @param props Reference to a property set, which is a collection of (name, value)
	-- pairs passed to the sub-pictures. If absent, a table is created internally.
	-- @see MultiPicture:SetMode
	function MultiPicture:__cons (mode, props)
		self[_props] = props or {}
		self[_thresholds] = {}

		self:SetMode(mode or "grid")
	end
end)