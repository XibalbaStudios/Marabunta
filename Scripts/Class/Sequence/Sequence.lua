-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- This class provides some apparatus for dealing with sequential data, where elements
-- may be inserted and removed often and observors dependent on the positioning must be
-- alerted.<br><br>
-- Class.
module Sequence
]]

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local pairs = pairs

-- Imports --
local IsCallable = var_preds.IsCallable
local IsCountable = var_preds.IsCountable
local IndexInRange = numeric_ops.IndexInRange
local New = class.New
local RangeOverlap = numeric_ops.RangeOverlap
local Weak = table_ops.Weak

-- Unique member keys --
local _insert = {}
local _object = {}
local _remove = {}
local _size = {}

-- Sequence state --
local Groups = ...

for _, v in ipairs(Groups) do
	v.elements = table_ops.SubTablesOnDemand()
end

-- Sequence class definition --
class.Define("Sequence", function(Sequence)
	-- Element update helper
	local function UpdateElements (S, op_key, index, count, new_size)
		for _, group in ipairs(Groups) do
			local op = group[op_key]

			for element in pairs(group.elements[S]) do
				op(element, index, count, new_size)
			end
		end
	end

	-- Inserts new items
	-- index: Insertion index
	-- count: Count of items to add
	-- ...: Insertion arguments
	--------------------------------
	function Sequence:Insert (index, count, ...)
		assert(self:IsItemValid(index, true) and count > 0)

		UpdateElements(self, "Insert", index, count, #self + count)

		self[_insert](index, count, ...)
	end

	-- index: Index of item in sequence
	-- is_addable: If true, the end of the sequence is valid
	-- Returns: If true, the item is valid
	---------------------------------------------------------
	function Sequence:IsItemValid (index, is_addable)
		return IndexInRange(index, #self, is_addable)
	end

	-- Returns: Item count
	-----------------------
	function Sequence:__len ()
		local size = self[_size]

		if size then
			return size(self[_object]) or 0
		else
			return #self[_object]
		end
	end

	-- Removes a series of items
	-- index: Removal index
	-- count: Count of items to remove
	-- ...: Removal arguments
	-- Returns: Count of items removed
	-----------------------------------
	function Sequence:Remove (index, count, ...)
		local cur_size = #self

		count = RangeOverlap(index, count, cur_size)

		if count > 0 then
			UpdateElements(self, "Remove", index, count, cur_size - count)

			self[_remove](index, count, ...)
		end

		return count
	end

	--- Class constructor.
	-- @param object Sequenced object.
	-- @param insert Insert routine.
	-- @param remove Remove routine.
	-- @param size Optional size routine.
	function Sequence:__cons (object, insert, remove, size)
		assert(IsCallable(size) or (size == nil and IsCountable(object)), "Invalid sequence parameters")

		-- Sequenced object --
		self[_object] = object

		-- Sequence operations --
		self[_insert] = insert
		self[_remove] = remove
		self[_size] = size
	end
end)