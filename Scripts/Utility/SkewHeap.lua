-- See TacoShell Copyright Notice in main folder of distribution

-- Adapted from Lua mailing list code by Gé Weijers.

-- Standard library imports --
local assert = assert

-- Heap keys --
local _L = {}
local _R = {}

---
module "skew_heap"

-- Merge function implementing a skew heap; outputs the root to r[_R]
-- a, b: Heaps to merge
-- r: Output heap
-- order: Heap order function
local function SkewMerge (a, b, r, order)
	assert(order, "Missing order function")

	if b then
		while a do
			if order(a, b) then
				r[_R], r = a, a
				a[_L], a = a[_R], a[_L]
			else
				r[_R], r = b, b
				b[_L], a, b = b[_R], b[_L], a
			end
		end
    end

	r[_R] = b or a
end

-- Empties the heap
--------------------
function Clear (H)
	H[_R] = nil
end

-- Adds a value to the heap
-- v: Value to add
-- order: Heap order function; if nil, uses function in heap
-------------------------------------------------------------
function Insert (H, v, order)
	SkewMerge(H[_R], v, H, order or H.order)
end

-- Returns: If true, heap is empty
-----------------------------------
function IsEmpty (H)
	return H[_R] == nil
end

-- Removes the root from the heap
-- order: Heap order function; if nil, uses function in heap
-- Returns: Removed value
-------------------------------------------------------------
function Remove (H, order)
	local r = H[_R]

	assert(r ~= nil, "Remove called on empty queue")

	SkewMerge(r[_L], r[_R], H, order or H.order)

	r[_L] = nil
	r[_R] = nil

	return r
end

-- Returns: Root value, or nil
-------------------------------
function Root (H)
	return H[_R]
end