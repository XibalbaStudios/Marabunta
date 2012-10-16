-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- Widget for display of scrolling text.<br><br>
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module Marquee
]]

-- Imports --
local DrawString = widget_ops.DrawString
local StringGetW = widget_ops.StringGetW
local SuperCons = class.SuperCons

-- Unique member keys --
local _dx = {}
local _is_looping = {}
local _pos = {}
local _right_to_left = {}
local _speed = {}

-- Marquee class definition --
class.Define("Marquee", function(Marquee)
	--- Status.
	-- @return If true, the marquee is scrolling.
	function Marquee:IsScrolling ()
		return self[_speed] ~= nil
	end

	--- Plays the marquee.
	-- @param speed Scroll speed.
	-- @param is_looping If true, the marquee will loop.
	function Marquee:Play (speed, is_looping)
		self[_is_looping] = not not is_looping
		self[_dx] = 0
		self[_pos] = 0
		self[_speed] = speed
	end

	--- Stops the marquee.
	function Marquee:Stop ()
		self[_speed] = nil
	end

	-- Stock signals --
	local Signals = {}

	--- Draws the marquee background with picture <b>"main"</b> in the render rect.<br><br>
	-- In the second phase, the enter logic is first called; if it passes, the marquee text
	-- is drawn. The leave logic is called afterward.<br><br>
	-- At the end, the <b>"frame"</b> picture is drawn with the render rect.
	-- @class function
	-- @name Signals:render
	-- @see ~WidgetGroup:Render

	--
	function Signals:render (x, y, w, h, _, state)
		self:DrawPicture("main", x, y, w, h)

		-- If the marquee is active, clip its border region and draw the offset string.
		if self:IsScrolling() then
			local bw, bh = self:GetBorder()

			if state("enter")(x + bw, y + bw, w - bw * 2, h - bh * 2) then
				local offset = self[_dx] + bw * 2
				local str = self:GetString()

				DrawString(self, str, nil, "center", x + (self[_right_to_left] and w - offset or offset - StringGetW(self, str)), y, w, h)

				state("leave")()
			end
		end

		-- Frame the marquee.
		self:DrawPicture("frame", x, y, w, h)
	end

	--- Updates scrolling.
	-- @class function
	-- @name Signals:update
	-- @see ~WidgetGroup:Update

	--
	function Signals:update (dt)
		if self:IsScrolling() then
			self[_dx] = self[_pos]
			self[_pos] = self[_pos] + self[_speed] * dt

			-- If the string has left the marquee body, stop or loop it.
			local _, _, w, _ = self:GetAbsoluteRect()
			local sum = w - self:GetBorder() * 2 + StringGetW(self, self:GetString())

			if self[_dx] > sum then
				if self[_is_looping] then
					self[_dx] = self[_dx] % sum
					self[_pos] = self[_pos] % sum
				else
					self[_speed] = nil
				end
			end
		end
	end

	--- Class constructor.
	-- @param right_to_left If true, the marquee scrolls right-to-left.
	function Marquee:__cons (right_to_left)
		SuperCons(self, "Widget")

		-- Scroll direction --
		self[_right_to_left] = not not right_to_left

		-- Signals --
		self:SetMultipleSlots(Signals)
	end
end, { base = "Widget" })