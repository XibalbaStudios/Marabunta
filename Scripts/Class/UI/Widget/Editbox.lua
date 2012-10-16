-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module Editbox
]]

-- Standard library imports --
local assert = assert
local max = math.max
local min = math.min

-- Modules --
local class = require("class")
local numeric_ops = require("numeric_ops")
local var_preds = require("var_preds")
local widget_ops = require("widget_ops")

-- Imports --
local ClampIn = numeric_ops.ClampIn
local DrawString = widget_ops.DrawString
local GetStringOps = widget_ops.GetStringOps
local IsPositive_Number = var_preds.IsPositive_Number
local New = class.New
local StateSwitch = widget_ops.StateSwitch
local StringGetW = widget_ops.StringGetW
local SuperCons = class.SuperCons
local SwapIf = numeric_ops.SwapIf

-- Cached methods --
local SetString = class.GetMember("Widget", "SetString")

-- Unique member keys --
local _blink = {}
local _chain = {}
local _cursor = {}
local _filter = {}
local _grabbed = {}
local _has_varied = {}
local _offset = {}
local _over = {}
local _selection = {}
local _sequence = {}

-- Count helper
local function StrLen (E)
	local str = E:GetString()

	if str ~= "" then
		return GetStringOps(E, "len")(str)
	end
end

-- Cursor fit helper
-- Returns: Index of best-fit character
local function Fit (E, len, sub, cx, cy)
	local font = E:GetFont()
	local string = E:GetString()

	if font and string ~= "" then
		local offset = E[_offset]:GetIndex()
		local x = E:GetAbsoluteRect()

		return ClampIn(font:GetIndexAtOffset(sub(string, offset - 1), cx - x) + 1, offset, len(string) + 1, false)
	end
end

-- Focus predicate
local function IsFocused (E)
	return not E[_chain] or E[_chain]:GetFocus() == E
end

-- Inserts items into the editbox
local function Insert (index, _, E, string)
	local curstr = E:GetString()
	local sub = GetStringOps(E, "sub")

	SetString(E, sub(curstr, 1, index - 1) .. string .. sub(curstr, index))
end

-- Removes items from the editbox
local function Remove (index, count, E)
	local curstr = E:GetString()
	local sub = GetStringOps(E, "sub")

	SetString(E, sub(curstr, 1, index - 1) .. sub(curstr, index + count))
end

-- Cursor set helper
local function SetCursor (E, index)
	E[_cursor]:Set(index)
end

-- Stock signals --
local Signals = {}

---
-- @param chain Reference to focus chain.
function Signals:add_to_focus_chain (chain)
	assert(self[_chain] == nil, "Editbox already in focus chain")

	self[_chain] = chain
end

---
function Signals:drop ()
	self[_grabbed]:Clear()
end

--- If the grabbed position is different from the cursor, sends signals as<br><br>
-- &nbsp&nbsp&nbsp<b><i>signal(E, "grab_cursor")</i></b>,<br><br>
-- where <i>signal</i> will be <b>"switch_from"</b> or <b>"switch_to"</b>, and <i>E</i>
-- refers to the signaled editbox.
-- @param state Execution state.
function Signals:grab (_, state)
	-- Get the best-fit character. Indicate that drag has yet to occur.
	local len, sub = GetStringOps(self, "len", "sub")
	local fit = Fit(self, len, sub, state("cursor"))

	if fit then
		self[_over] = fit
		self[_has_varied] = false

		-- Remove any selection.
		self[_selection]:Clear()

		-- Place the cursor over and grab the appropriate character.
		StateSwitch(self, fit ~= self[_cursor]:GetIndex(), false, SetCursor, "grab_cursor", fit)

		self[_grabbed]:Set(min(fit, StrLen(self, len)))

		-- If the editbox is in a focus chain, give it the focus.
		if self[_chain] then
			self[_chain]:SetFocus(self)
		end
	end
end

---
-- @param state Execution state.
function Signals:leave_upkeep (_, state)
	-- If the editbox is in a focus chain but has lost focus, quit. Otherwise, given a
	-- grab, select the drag range if the cursor fits to a character other than the grabbed
	-- one, or has done so already.
	local grabbed = self[_grabbed]:GetIndex()

	if grabbed and IsFocused(self) then
		local len, sub = GetStringOps(self, "len", "sub")
		local fit = min(Fit(self, len, sub, state("cursor")), StrLen(self, len))

		if self[_has_varied] or fit ~= grabbed then
			self[_has_varied] = true

			fit, grabbed = SwapIf(fit < grabbed, fit, grabbed)

			self[_selection]:Set(grabbed, fit - grabbed + 1)
		end
	end
end

---
function Signals:lose_focus ()
	self[_selection]:Clear()
end

---
function Signals:remove_from_focus_chain ()
	self[_chain] = nil
end

--- The <b>"main"</b> picture is drawn with rect (x, y, w, h).<br><br>
-- In the second phase, the enter logic passed to <b>WidgetGroup:Render</b> is first called.
-- If this returns a true value, the following is done: If there is a selection, it is drawn
-- using the <b>"highlight"</b> picture, stretched to fit the selected region. The visible
-- part of the string is drawn. If there is not a selection, and blinking is enabled, the
-- cursor is drawn using the <b>"cursor"</b> picture. Last of all, <b>WidgetGroup:Render
-- </b>'s leave logic is called.<br><br>
-- At the end, the <b>"frame"</b> picture is drawn with rect (x, y, w, h).
-- @param x Rect x-coordinate.
-- @param y Rect y-coordinate.
-- @param w Rect width.
-- @param h Rect height.
-- @param state Render state.
function Signals:render (x, y, w, h, _, state)
	self:DrawPicture("main", x, y, w, h)

	-- Clip the editbox's border region and draw its contents over the background.
	local len, sub = GetStringOps(self, "len", "sub")
	local bw, bh = self:GetBorder()
	local cx, cy, cw, ch = x + bw, y + bw, w - bw * 2, h - bh * 2

	if state("enter")(cx, cy, cw, ch) then
		local string = self:GetString()
		local offset = self[_offset]:GetIndex()
		local start = self[_selection]:GetStart()

		if string ~= "" then
			local count = #self[_selection]

			if start and start + count > offset then
				-- If the selection begins after the offset, find the text width leading
				-- up to it, and move ahead that far. Otherwise, reduce the selection to
				-- account for entries before the offset.
				local begin = 0
				local sx = cx

				if start > offset then
					begin = start - offset

					sx = sx + StringGetW(self, sub(string, 1, begin))

				else
					count = count + start - offset
				end

				-- If the selection begins within the visible region, get the clipped
				-- width of the selected text and draw a box.
				self:DrawPicture("highlight", sx, cy, StringGetW(self, sub(string, begin + 1, begin + count)), ch)
			end
		end

		-- Draw the visible portion of the string.
		DrawString(self, string, "left", "center", cx, cy, cw, ch)

		-- Draw the cursor if and when it is visible and there is no selection.
		local cursor = self[_cursor]:GetIndex() or 0
		local duration = self[_blink]:GetDuration()

		if IsFocused(self) and not start and duration and cursor >= (offset or 0) and self[_blink]:GetCounter() < duration / 2 then
			self:DrawPicture("cursor", cx + StringGetW(self, sub(string, 1, cursor - 1)), cy, StringGetW(self, " "), ch)
		end

		-- Exit the clipping area.
		state("leave")()
	end

	-- Frame the editbox.
	self:DrawPicture("frame", x, y, w, h)
end

--- Updates cursor blinking.
-- @param dt Time lapse.
function Signals:update (dt)
	self[_blink]:Update(dt)
	self[_blink]:Check("continue")
end

-- Editbox class definition --
class.Define("Editbox", function(Editbox)
	--- Adds text to the editbox.<br><br>
	-- If a selection is active, it is overwritten by the new text, and the selection is
	-- removed.<br><br>
	-- Otherwise, the text is inserted at the cursor location.<br><br>
	-- In either case, the cursor is then placed at the end of the new text. The string is
	-- first passed through the filter, if present.
	-- @param text Text string to add.
	-- @see Editbox:SetFilter
	function Editbox:AddText (text)
		if #self[_selection] > 0 then
			self:RemoveText(false)
		end

		local filter = self[_filter]

		if filter then
			text = filter(self, text) or ""
		end

		local count = GetStringOps(self, "len")(text)

		if count > 0 then
			local cursor = self[_cursor]:GetIndex()

			self[_sequence]:Insert(cursor, count, self, text)

			self[_cursor]:Set(cursor + count)
		end
	end

	--- Creates an <a href="Interval.html">Interval</a> on the editbox.
	-- @return <b>Interval</b> instance.
	function Editbox:CreateInterval ()
		return New("Interval", self[_sequence])
	end

	--- Creates a <a href="Spot.html">Spot</a> on the editbox.
	-- @param is_add_spot If true, spot can be immediately after the editbox.
	-- @param can_migrate If true, spot can migrate on removal.
	-- @return <b>Spot</b> instance.
	function Editbox:CreateSpot (is_add_spot, can_migrate)
		return New("Spot", self[_sequence], is_add_spot, can_migrate)
	end

	--- Gets the current location of the cursor.
	-- @return Cursor offset.
	function Editbox:GetCursor ()
		if #self[_selection] == 0 then
			return self[_cursor]:GetIndex()
		end
	end

	--- Gets information about the currently selected text.
	-- @return Selection string; if there is no selection, this is the empty string.
	-- @return If there is a selection, its starting location.
	-- @return If there is a selection, the number of selected characters.
	function Editbox:GetSelection ()
		local start = self[_selection]:GetStart()

		if start then
			local count = #self[_selection]

			return GetStringOps("sub")(self:GetString(), start, start + count - 1), start, count
		end

		return ""
	end

	--- Removes text from the editbox.<br><br>
	-- If any text is selected, it will be removed and the cursor placed at the start
	-- location.<br><br>
	-- Otherwise, the character at the cursor is removed. If "backspace" is requested, the
	-- cursor is first moved back one spot.
	-- @param back If true, perform a backspace-style deletion.
	function Editbox:RemoveText (back)
		local start = self[_selection]:GetStart()

		if start then
			local count = #self[_selection]

			self[_sequence]:Remove(start, count, self)

			self[_cursor]:Set(start)

		else
			local cursor = self[_cursor]:GetIndex() + (back and -1 or 0)

			if cursor >= 1 then
				self[_sequence]:Remove(cursor, 1, self)
			end
		end
	end
	
	function Editbox:SelectAllText()
		self[_selection]:Set(1, StrLen(self))
	end

	--- Sets the current cursor position. Any selection is cleared. If there was a selection,
	-- and a move command was specified, the cursor will be placed either before or after the
	-- selection range.<br><br>
	-- Position changes will send signals as<br><br>
	-- &nbsp&nbsp&nbsp<b><i>signal(E, "set_cursor")</i></b>,<br><br>
	-- where <i>signal</i> will be <b>"switch_from"</b> or <b>"switch_to"</b>, and <i>E</i>
	-- refers to this editbox.
	-- <br><br>TODO: Handle setting the cursor while it isn't in view
	-- @param index Command or entry index to assign; this may be a number between 1 and the
	-- string length + 1, or one of the strings <b>"-"</b> or <b>"+"</b>, which will move the
	-- cursor one spot backward or forward, respectively (clamped at the ends).
	-- @param always_refresh If true, receive <b>"switch_to"</b> signals even when the cursor
	-- index does not change.
	function Editbox:SetCursor (index, always_refresh)
		-- Cache the selection interval and clear it.
		local start = self[_selection]:GetStart()
		local count = #self[_selection]

		self[_selection]:Clear()

		-- On a command, move the cursor according to whether a selection was cleared.
		-- Update the cursor index.
		local cursor = self[_cursor]:GetIndex()
		local size = StrLen(self) + 1

		if index == "-" then
			index = max(start or cursor - 1, 1)
		elseif index == "+" then
			index = min(start and start + count or cursor + 1, size)
		end

		assert(index > 0 and index <= size, "Invalid cursor")

		StateSwitch(self, index ~= cursor, always_refresh, SetCursor, "set_cursor", index)

		-- Put the selection in view if it switched while out of view.
--[[
		local offset = self[_offset]:GetIndex()
		if index < offset then
			self[_offset]:Set(index)
		elseif index >= offset + #L.view then
			self[_offset]:Set(index - #L.view + 1)
		end
]]
	end

	--- Sets the current filter function. A filter should be a function with signature:<br><br>
	-- &nbsp&nbsp&nbsp<b><i>filter(E, text)</i></b>,<br><br>
	-- where <i>E</i> refers to this editbox and <i>text</i> to the unfiltered string to add.
	-- Its return value is the filtered text; <b>nil</b> can be returned for the empty string.
	-- @class function
	-- @name Editbox:SetFilter
	-- @param filter Filter to assign; if <b>nil</b>, filtering is disabled.
	-- @see Editbox:AddText
	-- @see Editbox:SetString
	Editbox.SetFilter = func_ops.FuncSetter(_filter, "Uncallable filter", true)

	--- Override of <b>Widget:SetString</b>. The current string is overwritten, affecting
	-- any spots or intervals watching the sequence. Any selection is removed. The cursor
	-- is placed after the new string.<br><br>
	-- The string is first passed through the filter, if present.
	-- @param string String to assign.
	-- @see Editbox:SetFilter
	-- @see ~Widget:SetString
	function Editbox:SetString (string)
		self[_selection]:Set(1, StrLen(self))

		self:AddText(string or "")
	end

	--- Sets the cursor blink timeout.
	-- @param timeout Timeout value to assign, in fraction of seconds; if <b>nil</b>, the
	-- cursor is disabled (the default).
	function Editbox:SetTimeout (timeout)
		assert(timeout == nil or IsPositive_Number(timeout), "Invalid timeout")

		if timeout then
			self[_blink]:Start(timeout)
		else
			self[_blink]:Stop()
		end
	end

	--- Class constructor.
	function Editbox:__cons ()
		SuperCons(self, "Widget")

		-- Character sequence --
		self[_sequence] = New("Sequence", self, Insert, Remove, StrLen)

		SetString(self, "")

		-- Cursor position --
		self[_cursor] = New("Spot", self[_sequence], true, true)

		-- Offset where editbox is grabbed --
		self[_grabbed] = New("Spot", self[_sequence], true, false)

		self[_grabbed]:Clear()

		-- Offset from which to begin rendering --
		self[_offset] = New("Spot", self[_sequence], false, true)

		-- Selected text --
		self[_selection] = New("Interval", self[_sequence])

		-- Blink timer --
		self[_blink] = New("Timer")

		-- Signals --
		self:SetMultipleSlots(Signals)
	end
end, { base = "Widget" })