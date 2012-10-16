-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- An ordered set can be thought of as a doubly-linked list (which can be treated as
-- circular if desired), with its iteration and insertion mechanics, but with unique
-- non-<b>nil</b> entries which can be checked for membership as in a set.<br><br>
-- Note that it is not a sorted set. Entries are ordered by how they are added.<br><br>
-- Class.
module OrderedSet
]]

-- Standard library imports --
local assert = assert
local rawequal = rawequal

-- Unique member keys --
local _back = {}
local _front = {}
local _next = {}
local _prev = {}

-- OrderedSet class definition --
class.Define("OrderedSet", function(OrderedSet)
	---
	-- @param entry Entry.
	-- @return If true, <i>entry</i> is in the set.
	function OrderedSet:Contains (entry)
		return entry ~= nil and (rawequal(entry, self[_front]) or self[_prev][entry] ~= nil or self[_next][entry] ~= nil)
	end

	--- Removes an entry, if present, from a set.
	-- @param entry Entry to remove.
	-- @return If true, <i>entry</i> was in the set.
	function OrderedSet:Remove (entry)
		if entry ~= nil then
			local prev_set = self[_prev]
			local next_set = self[_next]

			-- Check whether the entry is in the set.
			local prev = prev_set[entry]
			local next = next_set[entry]
			local is_front = rawequal(entry, self[_front])

			if is_front or prev ~= nil or next ~= nil then
				-- Remove references to and from the entry.
				if prev ~= nil then
					next_set[prev] = next
					prev_set[entry] = nil
				end

				if next ~= nil then
					prev_set[next] = prev
					next_set[entry] = nil
				end

				-- If the entry is the back of the set, the previous entry becomes the back.
				if rawequal(entry, self[_back]) then
					self[_back] = prev
				end

				-- If the entry is the front of the set, the next entry becomes the front.
				if is_front then
					self[_front] = next
				end

				return true
			end
		end

		return false
	end

	-- Cache methods for internal use.
	local Contains = OrderedSet.Contains
	local Remove = OrderedSet.Remove

	-- Relative placement helper
	-- ref: Referent (i.e. previous or next) entry
	-- rset: Referent set (set to which ref belongs) key
	-- oset: Other set (opposite of rset) key
	-- rend: Referent end (i.e. front or back) key
	-- oend: Other end (opposite of rend) key
	local function Put (S, ref, entry, rset, oset, rend, oend)
		assert(entry ~= nil, "Cannot add nil entries")

		-- Remove the entry if it is already in the set.
		Remove(S, entry)

		-- Bind surrounding entries.
		local ref_set = S[rset]
		local other_set = S[oset]
		local other

		if ref ~= nil then
			other = other_set[ref]

			other_set[ref] = entry
		else
			other = S[rend]
		end

		if other ~= nil then
			ref_set[other] = entry
		end

		ref_set[entry] = ref
		other_set[entry] = other

		-- The entry becomes the front if put before the front, or the back if put after the
		-- back; if the set is empty, it becomes whichever is the other end. 
		if rawequal(ref, S[oend]) then
			S[oend] = entry
		end

		-- The entry becomes the front if put after nil, or the back if put before nil; if
		-- the set is empty, it becomes whichever is the referent end.
		if ref == nil then
			S[rend] = entry
		end
	end

	--- Puts an entry after another in a set.
	-- @param prev Entry after which to insert; if <b>nil</b>, <i>entry</i> will become
	-- the front of the set.
	-- @param entry Entry to add, which cannot be <i>prev</i>.
	function OrderedSet:PutAfter (prev, entry)
		assert(not rawequal(prev, entry), "Cannot put entry after self")
		assert(prev == nil or Contains(self, prev), "prev is not in the set")

		Put(self, prev, entry, _prev, _next, _front, _back)
	end

	--- Puts an entry before another in a set.
	-- @param next Entry before which to insert; if <b>nil</b>, <i>entry</i> will become
	-- the back of the set.
	-- @param entry Entry to add or move, which cannot be <i>next</i>.
	function OrderedSet:PutBefore (next, entry)
		assert(not rawequal(next, entry), "Cannot put entry before self")
		assert(next == nil or Contains(self, next), "next is not in the set")

		Put(self, next, entry, _next, _prev, _back, _front)
	end

	-- Cache methods for internal use.
	local PutAfter = OrderedSet.PutAfter
	local PutBefore = OrderedSet.PutBefore

	---
	-- @param entry Entry to add or move.
	function OrderedSet:PutInBack (entry)
		PutBefore(self, nil, entry)
	end

	---
	-- @param entry Entry to add or move.
	function OrderedSet:PutInFront (entry)
		PutAfter(self, nil, entry)
	end

	---
	-- @return Back entry, or <b>nil</b> if the set is empty.
	function OrderedSet:Back ()
		return self[_back]
	end

	---
	-- @return Front entry, or <b>nil</b> if the set is empty.
	function OrderedSet:Front ()
		return self[_front]
	end

	--- Metamethod.
	-- @return Set size.
	function OrderedSet:__len ()
		local entry = self[_front]
		local nexts = self[_next]
		local count = 0

		while entry ~= nil do
			entry = nexts[entry]
			count = count + 1
		end

		return count
	end

	---
	-- @param entry Entry.
	-- @param loop If true and <i>entry</i> is at the back, loop around to the front.
	-- @return Entry after <i>entry</i>, or <b>nil</b> if <i>entry</i> is not in the set.
	function OrderedSet:Next (entry, loop)
		if rawequal(entry, self[_back]) and loop then
			return self[_front]
		else
			return self[_next][entry]
		end
	end

	---
	-- @param entry Entry.
	-- @param loop If true and <i>entry</i> is at the front, loop around to the back.
	-- @return Entry before <i>entry</i>, or <b>nil</b> if <i>entry</i> is not in the set.
	function OrderedSet:Prev (entry, loop)
		if rawequal(entry, self[_front]) and loop then
			return self[_back]
		else
			return self[_prev][entry]
		end
	end

	do
		-- Iterator body
		local function Iter (S, entry)
			if entry ~= nil then
				return S[_prev][entry]
			end

			return S[_back]
		end

		--- Iterates back-to-front over a set.
		-- @return Iterator, which returns an entry at each iteration.
		-- @see OrderedSet:FrontToBackIter
		function OrderedSet:BackToFrontIter ()
			return Iter, self
		end
	end

	do
		-- Iterator body
		local function Iter (S, entry)
			if entry ~= nil then
				return S[_next][entry]
			end

			return S[_front]
		end

		--- Iterates front-to-back over a set.
		-- @return Iterator, which returns an entry at each iteration.
		-- @see OrderedSet:BackToFrontIter
		function OrderedSet:FrontToBackIter ()
			return Iter, self
		end
	end

	--- Class constructor.
	function OrderedSet:__cons ()
		self[_next] = {}
		self[_prev] = {}
	end
end)