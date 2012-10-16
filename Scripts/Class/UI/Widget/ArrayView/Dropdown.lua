-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
-- Class. Derives from <b><a href="ArrayView.html">ArrayView</a></b>.
module Dropdown
]]

-- Standard library imports --
local ipairs = ipairs
local max = math.max
local min = math.min
local pairs = pairs

-- Imports --
local DrawString = widget_ops.DrawString
local Find = table_ops.Find
local FitToSlot = numeric_ops.FitToSlot
local PointInBox = numeric_ops.PointInBox
local StateSwitch = widget_ops.StateSwitch
local SuperCons = class.SuperCons

-- Cached methods --
local GetH = class.GetMember("Widget", "GetH")

-- Unique member keys --
local _heading = {}
local _pick = {}
local _scroll_set = {}

-- D: Dropdown handle
-- heading: Heading to assign
local function SetHeading (D, heading)
	D[_heading] = heading
end

-- D: Dropdown handle
-- pick: Pick to assign
local function SetPick (D, pick)
	D[_pick] = pick
end

-- Stock part signals --
local PartSignals = {}

---
function PartSignals:drop ()
	local dropdown = self:GetOwner()
	local heading = dropdown:GetViewEntryIndex(self)

	StateSwitch(dropdown, heading ~= dropdown:GetHeading(), false, SetHeading, "click_item", heading)
end

---
function PartSignals:enter ()
	local dropdown = self:GetOwner()
	local pick = dropdown:GetViewEntryIndex(self)

	StateSwitch(dropdown, pick ~= dropdown[_pick], false, SetPick, "pick", pick)
end

-- Stock signals --
local Signals = {}

---
function Signals:bind_as_scroll_target (targeter, how)
	self[_scroll_set][how] = targeter

	-- Put the targeter into a matching state.
	local is_open = self:IsOpen()

	targeter:Allow("render", is_open)
	targeter:Allow("test", is_open)
end

---
function Signals:grab ()
	self:SetOpen(not self[_pick])
end

---
function Signals:grab_alert (group)
	if self[_pick] or #self == 0 then
		local grabbed = group:GetGrabbed()

		if self ~= grabbed and not Find(self[_scroll_set], grabbed) then
			self:SetOpen(false)
		end
	end
end

---
function Signals:render (x, y, w, h)
	local dh = h
	local size = #self

	-- Partition the dropdown height between the heading and backdrop.
	if self[_pick] then
		dh = dh / (min(size, self:GetCapacity()) + 1)
	end

	-- Draw the dropdown heading.
	self:DrawPicture("heading", x, y, w, dh)

	-- If the dropdown is not empty, draw the heading text.
	if size > 0 then
		DrawString(self, self:GetHeading(), "center", "center", x, y, w, dh)

		-- If the box is open, draw the backdrop below the heading.
		if self[_pick] then
			local backy = y + dh
			local pick = self[_pick]

			self:DrawPicture("backdrop", x, backy, w, h - dh)

			-- Iterate through the visible items. If an item is picked, highlight it.
			-- Draw any string attached to the item and go to the next line.
			for i, text in self:View() do
				if i == pick then
					self:DrawPicture("highlight", x, backy, w, dh)
				end

				DrawString(self, text, "center", "center", x, backy, w, dh)

				backy = backy + dh
			end
		end
	end

	-- Frame the dropdown.
	self:DrawPicture("frame", x, y, w, dh)
end

---
function Signals:test (cx, cy, x, y, w, h)
	if PointInBox(cx, cy, x, y, w, h) then
		local capacity = self:GetCapacity()
		local index = self[_pick] and FitToSlot(cy, y, h / (min(#self, capacity) + 1)) - 1 or 0

		if index == 0 or index > capacity or self:GetViewEntryIndex(index) > #self then
			return self
		else
			return self:GetViewPart(index)
		end
	end
end

---
function Signals:unbind_as_scroll_target (_, how)
	self[_scroll_set][how] = nil
end

-- Dropdown class definition --
class.Define("Dropdown", function(Dropdown)
	-- Adds an entry to the end of the dropdown
	-- text: Text to assign
	-- ...: Entry members
	--------------------------------------------
	function Dropdown:Append (text, ...)
		local old_size = #self

		self:AddEntry(old_size + 1, text, ...)

		-- Handle the first entry.
		if old_size == 0 then
			self:Signal("switch_to", "first")
		end
	end

	-- Returns: Heading entry text, members
	----------------------------------------
	function Dropdown:GetHeading ()
		return self:GetEntry(self:Heading())
	end

	-- GetH override
	-----------------
	function Dropdown:GetH ()
		local offset = self[_pick] and min(#self, self:GetCapacity()) or 0

		return (offset + 1) * GetH(self)
	end

	-- Returns: Pick index
	-----------------------
	function Dropdown:GetPick ()
		return self[_pick]
	end

	-- Returns: Heading index
	--------------------------
	function Dropdown:Heading ()
		return self[_heading] or 1
	end

	-- Returns: If true, the dropdown is open
	------------------------------------------
	function Dropdown:IsOpen ()
		return self[_pick] ~= nil
	end

	-- Picks an entry
	-- index: Command or entry index
	-- always_refresh: If true, refresh on no change
	-------------------------------------------------
	function Dropdown:Pick (index, always_refresh)
		local pick = self[_pick]

		if pick then
			local size = #self

			if index == "-" then
				index = max(pick - 1, 1)
			elseif index == "+" then
				index = min(pick + 1, size)
			end

			assert(index > 0 and index <= size, "Invalid pick")

			StateSwitch(self, index ~= pick, always_refresh, SetPick, "pick", index)

			-- Put the pick in view if it switched while out of view.
			self:CorrectOffset(index)
		end
	end

	-- heading: Heading to assign
	-- always_refresh: If true, refresh on no change
	-------------------------------------------------
	function Dropdown:SetHeading (heading, always_refresh)
		StateSwitch(self, heading ~= self:GetHeading(), always_refresh, SetHeading, "set_heading", heading)
	end

	-- open: Open state to assign
	------------------------------
	function Dropdown:SetOpen (open)
		--
		if not open ~= not self[_pick] then
			if not open then
				self:Signal("switch_from", "open")

				self[_pick] = nil

			--
			elseif #self > 0 then
				-- Prioritize scroll set callbacks within the attach list.
				for _, component in pairs(self[_scroll_set]) do
					component:Promote()
				end

				-- Pick the heading and open the dropdown on it.
				self[_pick] = self:Heading()

				if #self > self:GetCapacity() then
					self:SetOffset(self[_pick])
				end
				-- Report the opening.
				self:Signal("switch_to", "open")
			end
		end

		-- Enable or disable the scroll set as necessary.
		for _, component in pairs(self[_scroll_set]) do
			component:Allow("render", open)
			component:Allow("test", open)
		end
	end

	--
	local function AddPartSignals (P)
		P:SetMultipleSlots(PartSignals)
	end

	--- Class constructor.
	-- @param capacity Dropdown capacity.
	function Dropdown:__cons ()
		SuperCons(self, "ArrayView", AddPartSignals)

		-- Scroll control tracking --
		self[_scroll_set] = {}

		-- Signals --
		self:SetMultipleSlots(Signals)

		-- Subscriptions --
		self:SubscribeTo("grab")
	end
end, { base = "ArrayView" })