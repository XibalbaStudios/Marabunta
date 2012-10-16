-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local getmetatable = getmetatable
local ipairs = ipairs
local next = next
local pairs = pairs
local rawequal = rawequal
local rawget = rawget
local rawset = rawset
local setmetatable = setmetatable
local sort = table.sort
local type = type
local unpack = unpack

-- Modules --
local cache_ops = require("cache_ops")
local func_ops = require("func_ops")
local iterators = require("iterators")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local Args = iterators.Args
local CollectArgsInto = var_ops.CollectArgsInto
local Identity = func_ops.Identity
local IsBoolean = var_preds.IsBoolean
local IsCallable = var_preds.IsCallable
local IsNaN = var_preds.IsNaN
local IsTable = var_preds.IsTable
local TableCache = cache_ops.TableCache
local WipeRange = var_ops.WipeRange

-- Cached routines --
local _Map_
local _Map_WithTable_

-- Cookies --
local _self = {}

---
module "table_ops"

-- One-deep bound-table cache --
local BoundTableCache = TableCache()

-- Helper to build "with table" companion functions
local function WithBoundTable (func)
	return function(dt, a, b, c, d, e)
		assert(IsTable(dt), "Non-table destination")

		BoundTableCache(dt)

		return func(a, b, c, d, e)
	end
end

-- Helper to fix copy case where a table was its own key
local function FixSelfKey (t, dt)
	if rawget(t, t) ~= nil and not rawequal(t, dt) then
		rawset(dt, dt, rawget(dt, t))
		rawset(dt, t, nil)
	end
end

--- Builds a new array, each of whose <i>count</i> elements is a table.
-- @param count Number of elements.
-- @return Array.
function ArrayOfTables (count)
	local dt = BoundTableCache("pull")

	for i = 1, count do
		dt[i] = {}
	end

	return dt
end

--- Bound-table variant of <b>ArrayOfTables</b>.
-- @class function
-- @name ArrayOfTables_WithTable
-- @param dt Destination table.
-- @param ... Arguments to <b>ArrayOfTables</b>.
-- @return Array.
-- @see ArrayOfTables
ArrayOfTables_WithTable = WithBoundTable(ArrayOfTables)

--- Shallow-copies a table.<br><br>
-- TODO: Account for cycles, table as key
-- @param t Table to copy.
-- @param how Copy behavior, as per <b>Map</b>.
-- @param how_arg Copy behavior, as per <b>Map</b>.
-- @return Copy.
-- @see Map
function Copy (t, how, how_arg)
    return _Map_(t, Identity, how, nil, how_arg)
end

--- Bound-table variant of <b>Copy</b>.
-- @class function
-- @name Copy_WithTable
-- @param dt Destination table.
-- @param ... Arguments to <b>Copy</b>.
-- @return Copy.
-- @see Copy
Copy_WithTable = WithBoundTable(Copy)

--- Copies all values with the given keys into a second table with those keys.
-- @param t Table to copy.
-- @param keys Key array.
-- @return Copy.
function CopyK (t, keys)
    local dt = BoundTableCache("pull")

    for _, k in ipairs(keys) do
        dt[k] = t[k]
    end

    return dt
end

--- Bound-table variant of <b>CopyK</b>.
-- @class function
-- @name CopyK_WithTable
-- @param dt Destination table.
-- @param ... Arguments to <b>CopyK</b>.
-- @return Copy.
-- @see CopyK
CopyK_WithTable = WithBoundTable(CopyK)

do
	-- Forward reference --
	local AuxDeepCopy

	-- Maps a table value during copies
	local function Mapping (v, guard)
		if IsTable(v) then
			return AuxDeepCopy(v, guard)
		else
			return v
		end
	end

	-- DeepCopy helper
	function AuxDeepCopy (t, guard)
		local dt = guard[t]

		if dt then
			return dt
		else
			dt = BoundTableCache("pull")

			guard[t] = dt

			_Map_WithTable_(dt, t, Mapping, nil, guard, _self)

			return setmetatable(dt, getmetatable(t))
		end
	end

	--- Deep-copies a table.<br><br>
	-- This will also copy metatables, and thus assumes these are accessible.<br><br>
	-- TODO: Account for cycles, table as key
	-- @param t Table to copy.
	-- @return Copy.
	function DeepCopy (t)
		local dt = BoundTableCache("pull")

		if not rawequal(t, dt) then
			BoundTableCache(dt)

			AuxDeepCopy(t, {})

			FixSelfKey(t, dt)
		end

		return dt
	end

	--- Bound-table variant of <b>DeepCopy</b>.<br><br>
	-- This is a no-op if <i>t</i> = <i>dt</i>.
	-- @class function
	-- @name DeepCopy_WithTable
	-- @param dt Destination table.
	-- @param ... Arguments to <b>DeepCopy</b>.
	-- @return Copy.
	-- @see DeepCopy
	DeepCopy_WithTable = WithBoundTable(DeepCopy)
end

do
	-- Equality helper
	local function AuxEqual (t1, t2)
		-- Iterate the tables in parallel. If equal, both tables will run out on the same
		-- iteration and the keys will then each be nil.
		local k1, k2, v1

		repeat
			-- The traversal order of next is unspecified, and thus at a given iteration
			-- the table values may not match. Thus, the value from the second table is
			-- discarded, and instead fetched with the first table's key.
			k2 = next(t2, k2)
			k1, v1 = next(t1, k1)

			local vtype = type(v1)
			local v2 = rawget(t2, k1)

			-- Proceed if the types match. As an exception, quit on nil, since matching
			-- nils means the table has been exhausted.
			local should_continue = vtype == type(v2) and k1 ~= nil

			if should_continue then
				-- Recurse on subtables.
				if vtype == "table" then
					should_continue = AuxEqual(v1, v2)

				-- For other values, do a basic compare, with special handling in the "not
				-- a number" case.
				else
					should_continue = v1 == v2 or (IsNaN(v1) and IsNaN(v2))
				end
			end
		until not should_continue

		return k1 == nil and k2 == nil
	end

	--- Compares two tables for equality, recursing into subtables. The comparison respects
	-- the <b>__eq</b> metamethod of non-table elements.<br><br>
	-- TODO: Account for cycles
	-- @param t1 Table to compare.
	-- @param t2 Table to compare.
	-- @return If true, the tables are equal.
	function Equal (t1, t2)
		assert(IsTable(t1), "t1 not a table")
		assert(IsTable(t2), "t2 not a table")

		return AuxEqual(t1, t2)
	end
end

--- Visits each entry of an array in order, removing unwanted entries. Entries are moved
-- down to fill in gaps.
-- @param t Table to cull.
-- @param func Visitor function called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>func(entry, arg)</b></i>,<br><br>
-- where <i>entry</i> is the current element and <i>arg</i> is the parameter.<br><br>
-- If the function returns a true result, this entry is kept. As a special case, if the
-- result is 0, all entries kept thus far are removed beforehand.
-- @param arg Argument to <i>func</i>.
-- @param clear_dead If true, clear trailing dead entries.<br><br>
-- Otherwise, a <b>nil</b> is inserted after the last live entry.
-- @return Size of table after culling.
function Filter (t, func, arg, clear_dead)
	local kept = 0
	local size = 0

	for i, v in ipairs(t) do
		size = i

		-- Put keepers back into the table. If desired, empty the table first.
		local result = func(v, arg)

		if result then
			kept = (result ~= 0 and kept or 0) + 1

			t[kept] = v
		end
	end

	-- Wipe dead entries or place a sentinel nil.
	WipeRange(t, kept + 1, clear_dead and size or kept + 1)

	-- Report the new size.
	return kept
end

--- Finds a match for a value in the table. The <b>__eq</b> metamethod is respected by
-- the search.
-- @param t Table to search.
-- @param value Value to find.
-- @param is_array If true, search only the array part, up to a <b>nil</b>, in order.
-- @return Key belonging to a match, or <b>nil</b> if the value was not found.
function Find (t, value, is_array)
	for k, v in (is_array and ipairs or pairs)(t) do
		if v == value then
			return k
		end
	end
end

--- Array variant of <b>Find</b>, which searches each entry up to the first <b>nil</b>,
-- quitting if the index exceeds <i>n</i>.
-- @param t Table to search.
-- @param value Value to find.
-- @param n Limiting size.
-- @return Index of first match, or <b>nil</b> if the value was not found in the range.
-- @see Find
function Find_N (t, value, n)
	for i, v in ipairs(t) do
		if i > n then
			return
		elseif v == value then
			return i
		end
	end
end

--- Finds a non-match for a value in the table. The <b>__eq</b> metamethod is respected
-- by the search.
-- @param t Table to search.
-- @param value_not Value to reject.
-- @param is_array If true, search only the array part, up to a <b>nil</b>, in order.
-- @return Key belonging to a non-match, or <b>nil</b> if only matches were found.
-- @see Find
function FindNot (t, value_not, is_array)
	for k, v in (is_array and ipairs or pairs)(t) do
		if v ~= value_not then
			return k
		end
	end
end

--- Performs an action on each item of the table.
-- @param t Table to iterate.
-- @param func Visitor function, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>func(v, arg)</b></i>,<br><br>
-- where <i>v</i> is the current value and <i>arg</i> is the parameter. If the return value
-- is not <b>nil</b>, iteration is interrupted and quits.
-- @param is_array If true, traverse only the array part, up to a <b>nil</b>, in order.
-- @param arg Argument to <i>func</i>.
-- @return Interruption result, or <b>nil</b> if the iteration completed.
function ForEach (t, func, is_array, arg)
	for _, v in (is_array and ipairs or pairs)(t) do
		local result = func(v, arg)

		if result ~= nil then
			return result
		end
	end
end

--- Key-value variant of <b>ForEach</b>.
-- @param t Table to iterate.
-- @param func Visitor function, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>func(k, v, arg)</b></i>,<br><br>
-- where <i>k</i> is the current key, <i>v</i> is the current value, and <i>arg</i> is the
-- parameter. If the return value is not <b>nil</b>, iteration is interrupted and quits.
-- @param is_array If true, traverse only the array part, up to a <b>nil</b>, in order.
-- @param arg Argument to <i>func</i>.
-- @return Interruption result, or <b>nil</b> if the iteration completed.
-- @see ForEach
function ForEachKV (t, func, is_array, arg)
	for k, v in (is_array and ipairs or pairs)(t) do
		local result = func(k, v, arg)

		if result ~= nil then
			return result
		end
	end
end

--- Array variant of <b>ForEach</b>, allowing sections of the iteration to be conditionally
-- ignored.<br><br>
-- Iteration begins in the active state.<br><br>
-- If a value matches the "check value", iteration continues over the next value, which must
-- either be of type <b>"boolean"</b> or a callable value. If the former, the active state
-- is set to active for <b>true</b> or inactive for <b>false</b>. If instead the value is
-- callable, it is called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>v(active, arg)</b></i>,<br><br>
-- where <i>active</i> is <b>true</b> or <b>false</b> according to the state and <i>arg</i>
-- is the parameter. The state will be set to active or inactive according to whether this
-- returns a true result or not, respectively.<br><br>
-- When the state is active, the current value is visited as per <b>ForEach</b>. Otherwise,
-- the value is ignored and iteration continues.
-- @param t Table to iterate.
-- @param check_value Value indicating that the subsequent value is a condition.
-- @param func Visitor function, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>func(v, arg)</b></i>,<br><br>
-- where <i>v</i> is the current value and <i>arg</i> is the parameter. If the return value
-- is not <b>nil</b>, iteration is interrupted and quits.
-- @param arg Argument to <i>func</i> and callable values.
-- @return Interruption result, or <b>nil</b> if the iteration completed.
function ForEachI_Cond (t, check_value, func, arg)
	local active = true
	local check = false

	for _, v in ipairs(t) do
		-- In the checking
		if check then
			assert(IsBoolean(v) or IsCallable(v), "Invalid check active condition")

			if IsBoolean(v) then
				active = v
			else
				active = not not v(active, arg)
			end

			check = false

		-- Otherwise, if this is the check value, enter the checking state.
		elseif rawequal(v, check_value) then
			check = true

		-- Otherwise, visit or ignore the current value.
		elseif active then
			local result = func(v, arg)

			if result ~= nil then
				return result
			end
		end
	end

	assert(not check, "Dangling check value")
end

do
	-- Field array cache --
	local Cache = TableCache("unpack_and_wipe")

	-- Gets multiple table fields
	-- ...: Fields to get
	-- Returns: Values, in order
	------------------------------
	function GetFields (t, ...)
		local count, keys = CollectArgsInto(Cache("pull"), ...)

		for i = 1, count do
			local key = keys[i]

			assert(key ~= nil, "Nil table key")

			keys[i] = t[key]
		end

		return Cache(keys, count)
	end
end

--- Collects all keys, arbitrarily ordered, into an array.
-- @param t Table from which to read keys.
-- @return Key array.
function GetKeys (t)
    local dt = BoundTableCache("pull")

	for k in pairs(t) do
		dt[#dt + 1] = k
	end

	return dt
end

--- Bound-table variant of <b>GetKeys</b>.
-- @class function
-- @name GetKeys_WithTable
-- @param dt Destination table.
-- @param ... Arguments to <b>GetKeys</b>.
-- @return Key array.
-- @see GetKeys
GetKeys_WithTable = WithBoundTable(GetKeys)

--- Builds a table's inverse, i.e. a table with the original keys as values and vice versa.<br><br>
-- Where the same value maps to many keys, no guarantee is provided about which key becomes
-- the new value.
-- @param t Table to invert.
-- @return Inverse table.
function Invert (t)
	local dt = BoundTableCache("pull")

	assert(t ~= dt, "Invert: Table cannot be its own destination")

	for k, v in pairs(t) do
		dt[v] = k
	end

	return dt
end

--- Bound-table variant of <b>Invert</b>.<br><br>
-- The destination table cannot be the original table.
-- @class function
-- @name Invert_WithTable
-- @param dt Destination table.
-- @return Inverse table.
-- @see Invert
Invert_WithTable = WithBoundTable(Invert)

--- Makes a set, i.e. a table where each element has value <b>true</b>. For each value in
-- <i>t</i>, an element is added to the set, with the value instead as the key.
-- @param t Key array.
-- @return Set constructed from array.
function MakeSet (t)
	local dt = BoundTableCache("pull")

	for _, v in ipairs(t) do
		dt[v] = true
	end

	return dt
end

--- Bound-table variant of <b>MakeSet</b>.
-- @class function
-- @name MakeSet_WithTable
-- @param dt Destination table.
-- @param ... Arguments to <b>MakeSet</b>.
-- @return Set constructed from array.
-- @see MakeSet
MakeSet_WithTable = WithBoundTable(MakeSet)

-- how: Table operation behavior
-- Returns: Offset pertinent to the behavior
local function GetOffset (t, how)
	return (how == "append" and #t or 0) + 1
end

-- Resolves a table operation
-- how: Table operation behavior
-- offset: Offset reached by operation
-- how_arg: Argument specific to behavior
local function Resolve (t, how, offset, how_arg)
	if how == "overwrite_trim" then
		WipeRange(t, offset, how_arg)
	end
end

-- Maps input items to output items
-- map: Mapping function
-- how: Mapping behavior
-- arg: Mapping argument
-- how_arg: Argument specific to mapping behavior
-- Returns: Mapped table
--------------------------------------------------
function Map (t, map, how, arg, how_arg)
	local dt = BoundTableCache("pull")

	if how then
		local offset = GetOffset(dt, how)

		for _, v in ipairs(t) do
			dt[offset] = map(v, arg)

			offset = offset + 1
		end

		Resolve(dt, how, offset, how_arg)

	else
		for k, v in pairs(t) do
			dt[k] = map(v, arg)
		end
	end

	return dt
end

--- Bound-table variant of <b>Map</b>.
-- @class function
-- @name Map_WithTable
-- @param dt Destination table.
-- @param ... Arguments to <b>Map</b>.
-- @return Mapped table.
-- @see Map
Map_WithTable = WithBoundTable(Map)

-- Key array Map variant
-- ka: Key array
-- map: Mapping function
-- arg: Mapping argument
-- Returns: Mapped table
-------------------------
function MapK (ka, map, arg)
	local dt = BoundTableCache("pull")

	for _, k in ipairs(ka) do
		dt[k] = map(k, arg)
	end

	return dt
end

--- Bound-table variant of <b>MapK</b>.
-- @class function
-- @name MapK_WithTable
-- @param dt Destination table.
-- @param ... Arguments to <b>MapK</b>.
-- @return Mapped table.
-- @see MapK
MapK_WithTable = WithBoundTable(MapK)

-- Key-value Map variant
-- map: Mapping function
-- how: Mapping behavior
-- arg: Mapping argument
-- how_arg: Argument specific to mapping behavior
-- Returns: Mapped table
--------------------------------------------------
function MapKV (t, map, how, arg, how_arg)
	local dt = BoundTableCache("pull")

	if how then
		local offset = GetOffset(dt, how)

		for i, v in ipairs(t) do
			dt[offset] = map(i, v, arg)

			offset = offset + 1
		end

		Resolve(dt, how, offset, how_arg)

	else
		for k, v in pairs(t) do
			dt[k] = map(k, v, arg)
		end
	end

	return dt
end

--- Bound-table variant of <b>MapKV</b>.
-- @class function
-- @name MapKV_WithTable
-- @param dt Destination table.
-- @param ... Arguments to <b>MapKV</b>.
-- @return Mapped table.
-- @see MapKV
MapKV_WithTable = WithBoundTable(MapKV)

-- Moves items into a second table
-- how, how_arg: Move behavior, argument
-- Returns: Destination table
-----------------------------------------
function Move (t, how, how_arg)
	local dt = BoundTableCache("pull")

	if t ~= dt then
		if how then
			local offset = GetOffset(dt, how)

			for i, v in ipairs(t) do
				dt[offset], offset, t[i] = v, offset + 1
			end

			Resolve(dt, how, offset, how_arg)

		else
			for k, v in pairs(t) do
				dt[k], t[k] = v
			end
		end
	end

	return dt
end

--- Bound-table variant of <b>Move</b>.
-- @class function
-- @name Move_WithTable
-- @param dt Destination table.
-- @param ... Arguments to <b>Move</b>.
-- @return Destination table.
-- @see Move
Move_WithTable = WithBoundTable(Move)

--- Reverses table elements in-place, in the range [1, <i>count</i>].
-- @param t Table to reverse.
-- @param count Range to reverse; if <b>nil</b>, #<i>t</i> is used.
function Reverse (t, count)
	local i, j = 1, count or #t

	while i < j do
		t[i], t[j] = t[j], t[i]

		i = i + 1
		j = j - 1
	end
end

do
	-- Weak table choices --
	local Choices = {}

	-- On-demand metatable --
	local OnDemand = {}

	-- Initialize the tables --
	for _, key in Args("k", "v", "kv", false) do
		OnDemand[key] = { __metatable = true }

		if key then
			Choices[key] = { __metatable = true, __mode = key }
			OnDemand[key].__mode = key
		end
	end

	-- Optional caches to supply tables --
	local Caches = setmetatable({}, Choices.k)

	-- Helper metatable to build weak on-demand subtables --
	local Options = setmetatable({}, Choices.k)

	-- Index helper
	local function Index (t, k)
		local cache = Caches[t]

		t[k] = setmetatable(cache and cache("pull") or {}, Options[t])

		return t[k]
	end

	-- Install the on-demand __index metamethod --
	for _, v in pairs(OnDemand) do
		v.__index = Index
	end

	-- Subtable helper
	local function SubTable (t, mt, wt, cache)
		setmetatable(t, wt)

		Caches[t] = cache
		Options[t] = mt

		return t
	end

	--- Builds a new table. If one of the table's keys is missing, it will be filled in
	-- automatically with a subtable when indexed.<br><br>
	-- Note that this effect is not propagated to the subtables.<br><br>
	-- The table's metatable is fixed.
	-- @param choice If <b>nil</b>, subtables will be normal tables.<br><br>
	-- Otherwise, the weak option, as per <b>Weak</b>, to assign a new subtable.
	-- @param weakness The weak option, as per <b>Weak</b>, to apply to the table itself.<br><br>
	-- If <b>nil</b>, it will be a normal table.
	-- @param cache Optional cache from which to pull subtables.<br><br>
	-- If <b>nil</b>, fresh tables will always be supplied.
	-- @return Table.
	-- @see Weak
	function SubTablesOnDemand (choice, weakness, cache)
		local dt = BoundTableCache("pull")
		local mt = Choices[choice]

		assert(choice == nil or mt, "Invalid choice")
		assert(weakness == nil or Choices[weakness], "Invalid weakness")
		assert(cache == nil or IsCallable(cache), "Uncallable cache function")

		return SubTable(dt, mt, OnDemand[weakness or false], cache)
	end

	--- Bound-table variant of <b>SubTablesOnDemand</b>.
	-- @class function
	-- @name SubTablesOnDemand_WithTable
	-- @param dt Destination table.
	-- @param ... Arguments to <b>SubTablesOnDemand</b>.
	-- @return Table.
	-- @see SubTablesOnDemand
	SubTablesOnDemand_WithTable = WithBoundTable(SubTablesOnDemand)

	--- Builds a new weak table.<br><br>
	-- The table's metatable is fixed.
	-- @param choice Weak option, which is one of <b>"k"</b>, <b>"v"</b>, or <b>"kv"</b>,
	-- and will assign that behavior to the <b>"__mode"</b> key of the table's metatable.
	-- @return Table.
	function Weak (choice)
		local dt = BoundTableCache("pull")

		return setmetatable(dt, assert(Choices[choice], "Invalid weak option"))
	end

	--- Bound-table variant of <b>Weak</b>.
	-- @class function
	-- @name Weak_WithTable
	-- @param dt Destination table.
	-- @param ... Arguments to <b>Weak</b>.
	-- @return Table.
	-- @see Weak
	Weak_WithTable = WithBoundTable(Weak)
end

-- Cache some routines.
_Map_ = Map
_Map_WithTable_ = Map_WithTable