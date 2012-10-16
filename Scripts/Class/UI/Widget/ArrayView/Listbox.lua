-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
-- Class. Derives from <b><a href="ArrayView.html">ArrayView</a></b>.
module Listbox
]]

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local max = math.max
local min = math.min

-- Imports --
local DrawString = widget_ops.DrawString
local FitToSlot = numeric_ops.FitToSlot
local PointInBox = numeric_ops.PointInBox
local StateSwitch = widget_ops.StateSwitch
local SuperCons = class.SuperCons

-- Cached methods --
local AddEntry = class.GetMember("ArrayView", "AddEntry")
local RemoveEntry = class.GetMember("ArrayView", "RemoveEntry")

-- Unique member keys --
local _selection = {}

-- Stock signals --
local Signals = {}

---
function Signals:render (x, y, w, h)
	self:DrawPicture("main", x, y, w, h)

	-- Draw each visible item and its string, highlighting any selection.
	local dh = h / self:GetCapacity()
	local selection = self[_selection]:GetIndex()

	for i, text in self:View() do
		if i == selection then
			self:DrawPicture("highlight", x, y, w, dh)
		end

		DrawString(self, text, "center", "center", x, y, w, dh)

		y = y + dh
	end

	-- Frame the listbox.
	self:DrawPicture("frame", x, y, w, h)
end

---
function Signals:test (cx, cy, x, y, w, h)
	if PointInBox(cx, cy, x, y, w, h) then
		local capacity = self:GetCapacity() 
		local index = FitToSlot(cy, y, h / capacity)
		local size = #self

		if index > capacity or size == 0 or self:GetViewEntryIndex(index) > size then
			return self
		else
			return self:GetViewPart(index)
		end
	end
end

-- Listbox class definition --
class.Define("Listbox", function(Listbox)
	-- L: Listbox handle
	-- index: Index to assign
	local function Select (L, index)
		L[_selection]:Set(index)
	end

	-- Adds an entry
	-- index: Entry index
	-- text: Text to assign
	-- ...: Entry members
	------------------------
	function Listbox:AddEntry (index, text, ...)
		AddEntry(self, index, text, ...)

		-- Make a selection if there is none.
		if #self == 1 then
			Select(self, 1)

			self:Signal("switch_to", "first")
		end
	end

	-- Appends an entry
	-- text: Text to assign
	-- ...: Entry members
	------------------------
	function Listbox:Append (text, ...)
		self:AddEntry(#self + 1, text, ...)
	end

	-- L: Listbox handle
	-- Returns: Selection index
	local function Selection (L)
		return L[_selection]:GetIndex()
	end

	-- Returns: Selection entry text, members
	------------------------------------------
	function Listbox:GetSelection ()
		local selection = Selection(self)

		if selection then
			return self:GetEntry(selection)
		end
	end

	-- Removes an entry
	-- index: Entry index
	----------------------
	function Listbox:RemoveEntry (index)
		assert(index > 0 and index <= #self, "Invalid removal")

		-- If the selection is being removed, alert the listbox.
		local is_selection = index == Selection(self)

		if is_selection then
			self:Signal("switch_from", "remove_selection")
		end

		-- Perform the removal.
		RemoveEntry(self, index)

		-- If the selection moved, respond to the switch.
		if is_selection and #self > 0 then
			self:Signal("switch_to", "remove_selection")
		end
	end

	-- Selects an entry
	-- index: Command or entry index
	-- always_refresh: If true, refresh on no change
	-------------------------------------------------
	function Listbox:Select (index, always_refresh)
		local selection = assert(Selection(self), "No selections available")
		local size = #self

		if index == "-" then
			index = max(selection - 1, 1)
		elseif index == "+" then
			index = min(selection + 1, size)
		end

		assert(index > 0 and index <= size, "Invalid selection")

		StateSwitch(self, index ~= selection, always_refresh, Select, "select", index)

		-- Put the selection in view if it switched while out of view.
		self:CorrectOffset(index)
	end

	--- Current selection
	Listbox.Selection = Selection

	-- P: Part handle
	local function PartGrab (P)
		local listbox = P:GetOwner()

		listbox:Select(listbox:GetViewEntryIndex(P))
	end

	--
	local function AddPartSignals (P)
		P:SetSlot("grab", PartGrab)
	end

	--- Class constructor.
	function Listbox:__cons ()
		SuperCons(self, "ArrayView", AddPartSignals)

		-- Selection offset --
		self[_selection] = self:CreateSpot(false, true)

		-- Signals --
		self:SetMultipleSlots(Signals)
	end
end, { base = "ArrayView" })