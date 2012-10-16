-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A spot is used to track a position on or immediately following a <a href="Sequence.html">
-- Sequence</a>, even as its index adapts to element insertions and removals.<br><br>
-- Class.
module Spot
]]

-- Standard library imports --
local assert = assert
local max = math.max

-- Library imports --
local IndexInRange = numeric_ops.IndexInRange
local IsType = class.IsType

-- Unique member keys --
local _can_migrate = {}
local _index = {}
local _is_add_spot = {}
local _size = {}

-- Export table --
local Export = {}

-- Returns: If true, spot is valid
local function IsValid (S, index)
	return IndexInRange(index or S[_index], S[_size], S[_is_add_spot])
end

-- Spot class definition --
class.Define("Spot", function(Spot)
	--- Invalidates the spot.
	function Spot:Clear ()
		self[_index] = 0
	end

	--- Gets the current index of the position watched by the spot.
	-- @return Index, or <b>nil</b> if the spot is invalid.
	-- @see Spot:Set
	function Spot:GetIndex ()
		if IsValid(self) then
			return self[_index]
		end
	end

	--- Assigns the spot a position in the sequence to watch.
	-- @param index Current position index.
	-- @see Spot:GetIndex
	function Spot:Set (index)
		assert(IsValid(self, index), "Invalid index")

		self[_index] = index
	end

	--- Class constructor.
	-- @param sequence Reference to owner sequence.
	-- @param is_add_spot If true, this spot can occupy the position immediately after the
	-- sequence.
	-- @param can_migrate If true, this spot can migrate if the part of the sequence it
	-- monitors is removed.
	function Spot:__cons (sequence, is_add_spot, can_migrate)
		assert(IsType(sequence, "Sequence"), "Invalid sequence")

		-- Current sequence size --
		self[_size] = #sequence

		-- Currently referenced sequence element --
		self[_index] = 1

		-- Flags --
		self[_is_add_spot] = not not is_add_spot
		self[_can_migrate] = not not can_migrate

		-- Register the spot --
		Export.elements[sequence][self] = true
	end
end)

-- Updates the spot in response to a sequence insert
function Export.Insert (S, index, count, new_size)
	if IsValid(S) then
		-- Move the spot ahead if it follows the insertion.
		if S[_index] >= index then
			S[_index] = S[_index] + count
		end

		-- If the sequence was empty, the spot will follow it. Back up if this is illegal.
		if new_size == count and not S[_is_add_spot] then
			S[_index] = S[_index] - 1
		end
	end

	S[_size] = new_size
end

-- Updates the spot in response to a sequence remove
function Export.Remove (S, index, count, new_size)
	if IsValid(S) then
		-- If a spot follows the range, back up by the remove count.
		if S[_index] >= index + count then
			S[_index] = S[_index] - count

		-- Otherwise, handle removes within the range.
		elseif S[_index] >= index then
			if S[_can_migrate] then
				-- Migrate past the range.
				S[_index] = index

				-- If the range was at the end of the items, the spot will now be past the
				-- end. Back it up if this is illegal.
				if index == new_size + 1 and not S[_is_add_spot] then
					S[_index] = max(index - 1, 1)
				end

			-- Clear non-migratory spots.
			else
				S:Clear()
			end
		end
	end

	S[_size] = new_size
end

-- Export spot to sequence.
table.insert(..., Export)