-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module Textbox
]]

-- Standard library imports --
local ipairs = ipairs
local yield = coroutine.yield

-- Imports --
local DrawString = widget_ops.DrawString
local GetStringOps = widget_ops.GetStringOps
local New = class.New
local NoOp = func_ops.NoOp
local Reset = coroutine_ex.Reset
local StringGetH = widget_ops.StringGetH
local StringGetW = widget_ops.StringGetW
local SuperCons = class.SuperCons
local SwapIf = numeric_ops.SwapIf
local WipeRange = var_ops.WipeRange
local Wrap = coroutine_ex.Wrap

-- Cached methods --
local SetString = class.GetMember("Widget", "SetString")

-- Unique member keys --
local _emit_rate = {}
local _idle = {}
local _iter = {}
local _lines = {}
local _timer = {}

-- Textbox class definition --
class.Define("Textbox", function(Textbox)
	--- Indicates whether the textbox is still emitting text or is now idle.
	-- @return If true, the box is active.
	function Textbox:IsActive ()
		return self[_iter] ~= NoOp
	end

	-- TODO: SetFont override -> Cache counter, re-emit up to it

	--- Override of <b>Widget:SetString</b>. Resets emission with the new string.
	-- @param str String to assign.
	-- @see ~Widget:SetString
	function Textbox:SetString (str)
		SetString(self, str)

		self[_idle], self[_iter] = SwapIf(self[_iter] == NoOp, self[_idle], self[_iter])

		Reset(self[_iter], self)
	end

	-- Iterator body
	local function Body (T)
		-- Run the character emit timer.
		T[_timer]:Start(T[_emit_rate])

		-- Lay out the description text line by line.
		local gmatch = GetStringOps(T, "gmatch")
		local lines = T[_lines]
		local count = 0
		local _, _, w, _ = T:GetAbsoluteRect()

		for word in gmatch(T:GetString() or "", "[%w%p]+%s*") do
			-- If no lines have yet been added or the current line will run off the border,
			-- start a new line.
			if #lines == 0 or StringGetW(T, lines[#lines] .. word) >= w then
				lines[#lines + 1] = ""
			end

			-- Add each character from the word to the current line. Wait for characters
			-- whenever the count runs out.
			for char in gmatch(word, ".") do		
				-- TODO: Reorganize this slightly to allow for run-to-counter
				while count == 0 do
					count = T[_timer]:Check("continue")

					yield()
				end

				lines[#lines] = lines[#lines] .. char

				count = count - 1
			end
		end

		-- Go idle.
		T[_idle], T[_iter] = T[_iter], T[_idle]
	end

	-- Reset logic
	local function OnReset (T)
		WipeRange(T[_lines])
	end

	-- Stock signals --
	local Signals = {}

	--- The <b>"main"</b> picture is drawn with the render rect. All of the current text is
	-- then drawn. Finally, the <b>"frame"</b> picture is drawn with the render rect.
	-- @class function
	-- @name Signals:render
	-- @see ~WidgetGroup:Render

	--
	function Signals:render (x, y, w, h)
		self:DrawPicture("main", x, y, w, h)

		-- Draw the substrings.
		for _, line in ipairs(self[_lines]) do
			DrawString(self, line, "left", "top", x, y)

			y = y + StringGetH(self, line, true)
		end

		-- Frame the textbox.
		self:DrawPicture("frame", x, y, w, h)
	end

	--- Updates character emissions.
	-- @class function
	-- @name Signals:update
	-- @see ~WidgetGroup:Update

	--
	function Signals:update (dt)
		self[_iter](self)

		self[_timer]:Update(dt)
	end

	--- Class constructor.
	-- @param emit_rate Delay, in seconds, between character emissions.
	function Textbox:__cons (emit_rate)
		SuperCons(self, "Widget")

		-- Character emit delay --
		self[_emit_rate] = emit_rate

		-- Idle behavior --
		self[_idle] = NoOp

		-- Active behavior --
		self[_iter] = Wrap(Body, OnReset)

		-- Current text --
		self[_lines] = {}

		-- Emit timer --
		self[_timer] = New("Timer")

		-- Signals --
		self:SetMultipleSlots(Signals)
	end
end, { base = "Widget" })