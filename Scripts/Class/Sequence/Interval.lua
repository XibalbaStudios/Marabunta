-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- This class is used to track an interval on a <a href="Sequence.html">Sequence</a>,
-- which can grow and shrink in response to element insertions and removals.<br><br>
-- Class.
module Interval
]]

-- Standard library imports --
local assert = assert
local max = math.max
local min = math.min

-- Imports --
local RangeOverlap = numeric_ops.RangeOverlap
local IsType = class.IsType

-- Unique member keys --
local _count = {}
local _index = {}
local _start = {}
local _size = {}

-- Export table --
local Export = {}

-- Interval class definition --
class.Define("Interval", function(Interval)
	--- Clears the selection.
	function Interval:Clear ()
		self[_count] = 0
	end

	--- Gets the starting position of the interval.
	-- @return Current start index, or <b>nil</b> if empty.
	function Interval:GetStart ()
		return self[_count] > 0 and self[_start] or nil
	end

	--- Metamethod.
	-- @return Size of selected interval.
	function Interval:__len ()
		return self[_count]
	end

	--- Selects a range. The selection count is clamped against the sequence size.
	-- @param start Current index of start position.
	-- @param count Current size of range to select.
	function Interval:Set (start, count)
		self[_start] = start
		self[_count] = RangeOverlap(start, count, self[_size])
	end

	--- Class constructor.
	-- @param sequence Reference to owner sequence.
	function Interval:__cons (sequence)
		assert(IsType(sequence, "Sequence"), "Invalid sequence")

		-- Current sequence size --
		self[_size] = #sequence

		-- Selection count --
		self[_count] = 0

		-- Register the interval --
		Export.elements[sequence][self] = true
	end
end)

-- Updates the interval in response to a sequence insert
function Export.Insert (I, index, count, new_size)
	if I[_count] > 0 then
		-- If an interval follows the insertion, move ahead by the insert count.
		if index < I[_start] then
			I[_start] = I[_start] + count

		-- If inserting into the interval, augment it by the insert count.
		elseif index < I[_start] + I[_count] then
			I[_count] = I[_count] + count
		end
	end

	I[_size] = new_size
end

-- Updates the interval in response to a sequence remove
function Export.Remove (I, index, count, new_size)
	if I[_count] > 0 then
		-- Reduce the interval count by its overlap with the removal.
		local endr = index + count
		local endi = I[_start] + I[_count]

		if endr > I[_start] and index < endi then
			I[_count] = I[_count] - min(endr, endi) + max(index, I[_start])
		end

		-- If the interval follows the point of removal, it must be moved back. Reduce its
		-- index by the lesser of the count and the point of removal / start distance.
		if I[_start] > index then
			I[_start] = max(I[_start] - count, index)
		end
	end

	I[_size] = new_size
end

-- Export interval to sequence.
table.insert(..., Export)