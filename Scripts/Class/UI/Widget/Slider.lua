-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- This widget has a part that can slide back and forth, e.g. by being dragged by the
-- mouse, and is useful for adjusting ranged values.<br><br>
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module Slider
]]

-- Imports --
local ButtonStyleRender = widget_ops.ButtonStyleRender
local ClampIn = numeric_ops.ClampIn
local New = class.New
local PointInBox = numeric_ops.PointInBox
local StateSwitch = widget_ops.StateSwitch
local SuperCons = class.SuperCons
local SwapIf = numeric_ops.SwapIf

-- Unique member keys --
local _dist1 = {}
local _dist2 = {}
local _fixed = {}
local _is_vertical = {}
local _off_center = {}
local _offset = {}
local _th = {}
local _thumb = {}
local _tw = {}

-- factor: Offset factor
-- Returns: Computed relative offset
local function CursorOffset (S, factor, state)
	local cx, cy = state("cursor")
	local x, y, w, h = S:GetAbsoluteRect()

	if S[_is_vertical] then
		return (cy - y - factor) / (h - S[_dist2] - S[_dist1])
	else
		return (cx - x - factor) / (w - S[_dist2] - S[_dist1])
	end
end

-- Returns: Thumb offset
local function ThumbOffset (S)
	local _, _, w, h = S:GetAbsoluteRect()
	local dim = S[_is_vertical] and h or w

	return S[_dist1] + S:GetOffset() * (dim - S[_dist2] - S[_dist1])
end

-- Thumb class definition --
local Thumb_Key = widget_ops.DefineOwnedWidget("Slider:Thumb", function(Thumb)
	-- Stock thumb signals --
	local ThumbSignals = {}

	---
	-- @param state Execution state.
	function ThumbSignals:grab (_, state)
		local slider = self:GetOwner()

		self[_off_center] = CursorOffset(slider, ThumbOffset(slider), state)
	end

	---
	-- @param state Execution state.
	function ThumbSignals:leave_upkeep (group, state)
		local slider = self:GetOwner()

		if self == group:GetGrabbed() then
			slider:SetOffset(CursorOffset(slider, slider[_dist1], state) - self[_off_center])
		end
	end

	--- Class constructor.
	function Thumb:__cons ()
		self:SetMultipleSlots(ThumbSignals)
	end
end)

-- Slider class definition --
class.Define("Slider", function(Slider)
	--- Gets the current offset, which begins as 0.
	-- @return Slider offset, in [0, 1].
	-- @see Slider:SetOffset
	function Slider:GetOffset ()
		return self[_offset] or 0
	end

	---
	-- @return Thumb widget.
	function Slider:GetThumb ()
		return self[_thumb]
	end

	-- offset: Offset to assign, in [0, 1]
	local function SetOffset (S, offset)
		S[_offset] = offset
	end

	--- Sets the current offset.<br><br>
	-- Offset changes will send signals as<br><br>
	-- &nbsp&nbsp&nbsp<b><i>signal(S, "set_offset")</i></b>,<br><br>
	-- where <i>signal</i> will be <b>switch_from</b> or <b>switch_to</b>, and <i>S</i>
	-- refers to this slider.
	-- @param offset Offset to assign.
	-- @param always_refresh If true, send the <b>"switch_to"</b> signal even when the offset
	-- does not change.
	-- @see Slider:GetOffset
	function Slider:SetOffset (offset, always_refresh)
		offset = ClampIn(offset, 0, 1)

		StateSwitch(self, offset ~= self:GetOffset(), always_refresh, SetOffset, "set_offset", offset)
	end

	-- Returns: Thumb coordinates, dimensions
	local function ThumbBox (S, x, y)
		local tx, ty = SwapIf(S[_is_vertical], ThumbOffset(S), S[_fixed])

		return x + tx, y + ty, S[_tw], S[_th]
	end

	-- Stock signals --
	local Signals = {}

	---
	-- @param state Execution state.
	function Signals:grab (_, state)
		self:SetOffset(CursorOffset(self, self[_dist1], state))
	end

	--- Draws the slider background with picture <b>"main"</b> in (x, y, w, h).<br><br>
	-- The slider is then drawn at its current offset with the picture matching its cursor state:
	-- <b>"main"</b>, <b>"entered"</b>, or <b>"grabbed"</b>. Note that these pictures belong to
	-- the thumb widget and not the slider.
	-- @param x Rect x-coordinate.
	-- @param y Rect y-coordinate.
	-- @param w Rect width.
	-- @param h Rect height.
	-- @param group
	function Signals:render (x, y, w, h, group)
		self:DrawPicture("main", x, y, w, h)

		-- Draw the thumb.
		local tx, ty, tw, th = ThumbBox(self, x, y)

		ButtonStyleRender(self[_thumb], tx, ty, tw, th, group)
	end

	--- Succeeds if (cx, cy) is inside (x, y, w, h) or the thumb box, inside this rect.
	-- @param cx Cursor x-coordinate.
	-- @param cy Cursor y-coordinate.
	-- @param x Bounding rect x-coordinate.
	-- @param y Bounding rect y-coordinate.
	-- @param w Bounding rect width.
	-- @param h Bounding rect height.
	-- @return On a successful test, returns the slider or thumb.
	function Signals:test (cx, cy, x, y, w, h)
		if PointInBox(cx, cy, x, y, w, h) then
			return PointInBox(cx, cy, ThumbBox(self, x, y)) and self[_thumb] or self
		end
	end

	--- Class constructor.
	-- @param dist1 Thumb distance to left or top edge.
	-- @param dist2 Thumb distance to right or bottom edge.
	-- @param fixed Fixed distance in other coordinate.
	-- @param tw Thumb width.
	-- @param th Thumb height.
	-- @param is_vertical If true, this is a vertical slider.
	function Slider:__cons (dist1, dist2, fixed, tw, th, is_vertical)
		SuperCons(self, "Widget")

		-- Distances between slide range and attach box edges --
		self[_dist1] = dist1
		self[_dist2] = dist2

		-- Distance between thumb and attach box edges perpendicular to slider bar --
		self[_fixed] = fixed

		-- Thumb dimensions --
		self[_tw] = tw
		self[_th] = th

		-- Slider orientation flag --
		self[_is_vertical] = not not is_vertical

		-- Thumb widget --
		self[_thumb] = New("Slider:Thumb", Thumb_Key, self)

		-- Signals --
		self:SetMultipleSlots(Signals)
	end
end, { base = "Widget" })