-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- Base class for a family of widgets that have a 1D range of data elements, plus a
-- corresponding range of sub-widgets that provide a view of those elements.<br><br>
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module ArrayView
]]

-- Standard library imports --
local assert = assert
local insert = table.insert
local max = math.max
local min = math.min
local remove = table.remove

-- Imports --
local CallOrGet = func_ops.CallOrGet
local Find = table_ops.Find
local IsPositiveInteger = var_preds.IsPositiveInteger
local New = class.New
local NewArray = class.NewArray
local NoOp = func_ops.NoOp
local PackOrGet = var_ops.PackOrGet
local SuperCons = class.SuperCons
local Type = class.Type
local UnpackOrGet = var_ops.UnpackOrGet

-- Unique member keys --
local _array = {}
local _n = {}
local _offset = {}
local _on_new_part = {}
local _sequence = {}
local _view = {}

-- Part class definition --
local Part_Key = widget_ops.DefineOwnedWidget("ArrayView:Part")

-- Entry cache --
local EntryCache = cache_ops.TableCache("wipe_range")

-- Inserts items into the array
-- ...: Entry members
local function Insert (index, count, array, ...)
	for i = index, index + count - 1 do
		insert(array, i, PackOrGet(EntryCache("pull"), _n, ...))
	end
end

-- Removes items from the array
local function Remove (index, count, array)
	for i = index + count - 1, index, -1 do
		local entry = remove(array, i)
		local count = UnpackOrGet(entry, _n, "count")

		if count > 1 then
			EntryCache(entry, 1, count)
		end
	end
end

-- entry: Entry
-- Returns: Entry members
local function GetEntry (entry)
	return CallOrGet(UnpackOrGet(entry, _n, "first")), UnpackOrGet(entry, _n, "rest")
end

-- Array class definition --
class.Define("ArrayView", function(ArrayView)
	-- Adds an entry
	-- index: Entry index
	-- ...: Entry members
	----------------------
	function ArrayView:AddEntry (index, ...)
		self[_sequence]:Insert(index, 1, self[_array], ...)
	end

	-- Clears all entries
	----------------------
	function ArrayView:Clear ()
		self[_sequence]:Remove(1, #self[_array], self[_array])
	end

	-- Creates an interval on the array.
	-- Returns: Interval handle.
	function ArrayView:CreateInterval ()
		return New("Interval", self[_sequence])
	end

	-- Creates a spot on the array.
	-- is_add_spot: If true, spot can be immediately after the array.
	-- can_migrate: If true, spot can migrate on removal.
	-- Returns: Spot handle.
	function ArrayView:CreateSpot (is_add_spot, can_migrate)
		return New("Spot", self[_sequence], is_add_spot, can_migrate)
	end

	---
	-- @return
	function ArrayView:GetOffset ()
		return self[_offset]:GetIndex()
	end

	---
	-- @param offset
	function ArrayView:SetOffset (offset)
		self[_offset]:Set(offset)
	end

	--
	local GetOffset = ArrayView.GetOffset
	local SetOffset = ArrayView.SetOffset

	---
	-- @param index
	function ArrayView:CorrectOffset (index)
		local offset = GetOffset(self)

		if index < offset then
			SetOffset(self, index)
		elseif index >= offset + #self[_view] then
			SetOffset(self, index - #self[_view] + 1)
		end
	end

	---
	-- @return
	function ArrayView:GetCapacity ()
		return #self[_view]
	end

	-- index: Entry index
	-- Returns: Entry members
	--------------------------
	function ArrayView:GetEntry (index)
		local entry = self[_array][index]

		if entry then
			return GetEntry(entry)
		end
	end

	---
	-- @param part
	-- @return
	function ArrayView:GetViewPartIndex (part)
		return Find(self[_view], part, true)
	end

	--
	local GetViewPartIndex = ArrayView.GetViewPartIndex

	---
	-- @param index
	-- @return
	function ArrayView:GetViewEntryIndex (index)
		if Type(index) == "ArrayView:Part" then
			index = GetViewPartIndex(self, index)
		end

		assert(index, "Invalid index")

		if #self[_array] > 0 then
			return GetOffset(self) + index - 1
		end
	end

	--
	local GetViewEntryIndex = ArrayView.GetViewEntryIndex

	---
	-- @param index
	-- @return
	function ArrayView:GetViewEntry (index)
		return self[_view][GetViewEntryIndex(self, index)]
	end

	---
	-- @param index
	-- @return
	function ArrayView:GetViewPart (index)
		return self[_view][index]
	end

	-- Instanced iterator over the array
	-- start: Start index; if nil, set to 1
	-- count: Range count; if nil, set to entry count
	-- Returns: Iterator instance which returns index, entry members
	-- @see ~iterators.InstancedAutocacher
	--------------------------------------------------------
	ArrayView.Iter = iterators.InstancedAutocacher(function()
		local array, final

		-- Body --
		return function(_, i)
			return i + 1, GetEntry(array[i + 1])
		end,

		-- Done --
		function(_, i)
			return i + 1 >= final or i >= #array
		end,

		-- Setup --
		function(A, start, count)
			array = A[_array]
			start = start or 1
			count = count or #array
			final = start + count

			return nil, start - 1
		end,

		-- Reclaim --
		function()
			array = nil
		end
	end)

	-- Returns: Entry count
	------------------------
	function ArrayView:__len ()
		return #self[_array]
	end

	-- Removes an entry
	-- index: Entry index
	----------------------
	function ArrayView:RemoveEntry (index)
		self[_sequence]:Remove(index, 1, self[_array])
	end

	---
	-- @param capacity
	function ArrayView:SetCapacity (capacity)
		assert(IsPositiveInteger(capacity), "Invalid capacity")

		local on_new_part = self[_on_new_part] or NoOp
		local view = self[_view]
		local cur_capacity = #view

		--
		if cur_capacity <= capacity then
			for i = cur_capacity + 1, capacity do
				view[i] = New("ArrayView:Part", Part_Key, self)

				on_new_part(view[i])
			end

		--
		else
			for i = cur_capacity, capacity, -1 do
				view[i] = nil
			end
		end
	end

	-- Builds an iterator over the viewable items
	-- Returns: Iterator which returns index, entry members
	--------------------------------------------------------
	function ArrayView:View ()
		return self:Iter(GetOffset(self), #self[_view])
	end

	---
	-- @class function
	-- @name Signals:scroll
	-- @param how Scroll behavior
	-- @param frequency Scroll frequency

	--
	local function Scroll (A, how, frequency)
		local count = #A[_array]
		local offset = GetOffset(A)

		if count == 0 then
			return
		elseif how == "up" then
			SetOffset(A, max(offset - frequency, 1))
		elseif how == "down" then
			SetOffset(A, min(offset + frequency, count - frequency + 1))
		end
	end

	--- Class constructor.
	-- @param on_new_part 
	function ArrayView:__cons (on_new_part)
		SuperCons(self, "Widget")

		-- New part setup --
		self[_on_new_part] = on_new_part

		-- Entry array --
		self[_array] = {}

		-- Entry sequence --
		self[_sequence] = New("Sequence", self[_array], Insert, Remove)

		-- Position offset --
		self[_offset] = New("Spot", self[_sequence], false, true)

		-- View array --
		self[_view] = {}

		self:SetCapacity(1)

		-- Signals --
		self:SetSlot("scroll", Scroll)
	end
end, { base = "Widget" })