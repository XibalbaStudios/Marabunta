-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local format = string.format
local gsub = string.gsub
local ipairs = ipairs
local loadstring = loadstring
local rawget = rawget
local rep = string.rep
local select = select
local tostring = tostring
local unpack = unpack

-- Modules --
local var_preds = require("var_preds")

-- Imports --
local IsInteger = var_preds.IsInteger
local IsTable = var_preds.IsTable

-- Collect count for code generator --
local CollectCount = ...

-- Cached routines --
local _AssertArg_
local _WipeRange_

--- This module defines some primitive operations for variables.
module "var_ops"

--- Assert with formatted error message support.
-- @param cond Condition to validate, as per <b>assert</b>.
-- @param str Format string, which can contain one <b>%s</b> specifier.
-- @param arg Argument, used by <i>str</i> after having <b>tostring</b> applied.
-- @return <i>cond</i>, if no error was thrown.
function AssertArg (cond, str, arg)
	if not cond then
		assert(false, format(str, tostring(arg)))
	end

	return cond
end

--- Predicate variant of <b>AssertArg</b>.
-- @param pred Unary predicate to test, as per <b>assert</b>.
-- @param pred_arg Argument to <i>pred</i>.
-- @param str Format string, which can contain one <b>%s</b> specifier.
-- @param arg Argument, used by <i>str</i> after having <b>tostring</b> applied.
-- @return <i>pred_arg</i>, if no error was thrown.
-- @see AssertArg
function AssertArg_Pred (pred, pred_arg, str, arg)
	_AssertArg_(pred(pred_arg), str, arg)

	return pred_arg
end

-- Collect helper --
local Collect

-- Helper to accumulate arguments
-- acc: Accumulator
-- i: Index of last added item
-- count: Total item count
-- v(*), ...: Items to collect on this pass, remainder
-- Returns: Argument count, filled accumulator when done; otherwise tail calls to next pass
if CollectCount then
	assert(IsInteger(CollectCount) and CollectCount > 0, "Invalid collect count")
	assert(loadstring, "Code generator not present")

	-- Generate the Collect call for the per-pass collect count.
	local Form = "_" .. rep(", _", CollectCount - 1)
	local Subs = { "acc[i + %i]", "v%i" }

	for i, pat in ipairs(Subs) do
		local index = 0

		Subs[i] = gsub(Form, "_", function()
			index = index + 1

			return format(Subs[i], index)
		end)
	end

	Collect = loadstring(format([[
		local function Collect (acc, i, count, %s, ...)
			if i <= count then
				%s = %s

				return Collect(acc, i + %i, count, ...)
			end

			return count, acc
		end

		return Collect
	]], Subs[2], Subs[1], Subs[2], CollectCount))()

-- This is a standard collect, specialized for five element loads at once. The above
-- code was generated for several collect counts, and several combinations of nil and
-- non-nil values in small and large doses were loaded into a table one million times
-- each. The sweet spot seems to be somewhere around five loads per pass. 
else
	function Collect (acc, i, count, v1, v2, v3, v4, v5, ...)
		if i <= count then
			acc[i + 1], acc[i + 2], acc[i + 3], acc[i + 4], acc[i + 5] = v1, v2, v3, v4, v5

			return Collect(acc, i + 5, count, ...)
		end

		return count, acc
	end
end

--- Collects arguments, including <b>nil</b>s, into an object.
-- @param acc Accumulator object; if false, a table is supplied.
-- @param ... Arguments to collect.
-- @return Argument count.
-- @return Filled accumulator.
function CollectArgsInto (acc, ...)
	local count = select("#", ...)

	if acc then
		return Collect(acc, 0, count, ...)
	else
		return count, { ... }
	end
end

--- Variant of <b>CollectArgsInto</b> that is a no-op when given no arguments.
-- @param acc Accumulator object; if false and there are arguments, a table is supplied.
-- @param ... Arguments to collect.
-- @return Argument count.
-- @return Filled accumulator, or <i>acc</i> if no arguments were supplied.
-- @see CollectArgsInto
function CollectArgsInto_IfAny (acc, ...)
	local count = select("#", ...)

	if count == 0 then
		return 0, acc
	elseif acc then
		return Collect(acc, 0, count, ...)
	else
		return count, { ... }
	end
end

--- Swaps a new value into a field.
-- @param cont Container.
-- @param key Field key.
-- @param new New value.
-- @return Old value.
function SwapField (cont, key, new)
	local cur = cont[key]

	cont[key] =  new

	return cur
end

do
	-- Helper for nil array argument --
	local Empty = {}

	-- count: Value count
	-- ...: Array values
	local function AuxUnpackAndWipeRange (array, first, last, wipe, ...)
		_WipeRange_(array, first, last, wipe)

		return ...
	end

	--- Wipes an array, returning the overwritten values.
	-- @param array Array to wipe. May be <b>nil</b>, though <i>count</i> must then be 0.
	-- @param count Size of array; by default, #<i>array</i>.
	-- @param wipe Value used to wipe over entries.
	-- @return Array values (number of return values = <i>count</i>).
	function UnpackAndWipe (array, count, wipe)
		return AuxUnpackAndWipeRange(array, 1, count, wipe, unpack(array or Empty, 1, count))
	end

	--- Wipes a range in an array, returning the overwritten values.
	-- @param array Array to wipe. May be <b>nil</b>, though <i>last</i> must resolve to 0.
	-- @param first Index of first entry; by default, 1.
	-- @param last Index of last entry; by default, #<i>array</i>.
	-- @param wipe Value used to wipe over entries.
	-- @return Array values (number of return values = <i>last</i> - <i>first</i> + 1).
	function UnpackAndWipeRange (array, first, last, wipe)
		return AuxUnpackAndWipeRange(array, first, last, wipe, unpack(array or Empty, first, last))
	end

	--- Wipes a range in an array.
	-- @param array Array to wipe. May be <b>nil</b>, though <i>last</i> must resolve to 0.
	-- @param first Index of first entry; by default, 1.
	-- @param last Index of last entry; by default, #<i>array</i>.
	-- @param wipe Value used to wipe over entries.
	-- @return Array.
	function WipeRange (array, first, last, wipe)
		for i = first or 1, last or #(array or Empty) do
			array[i] = wipe
		end

		return array
	end
end

--- Resolves its input as a single result, packing it into a table when there are multiple
-- arguments, useful when input may vary between single and multiple values.
-- @param t Table to store multiple arguments; if <b>nil</b>, a fresh table is supplied.
-- @param key Key under which to store the argument count in the table.
-- @param ... Arguments.
-- @return Given zero arguments, returns <b>nil</b>. Given one, returns the value. Otherwise,
-- returns the storage table.
-- @see UnpackOrGet
function PackOrGet (t, key, ...)
	local count = select("#", ...)

	if count > 1 then
		t = t or {}

		t[key] = Collect(t, 0, count, ...)

		return t
	else
		return (...)
	end
end

--- Companion to <b>PackOrGet</b>, offering some options on its result.
-- @param var Variable as returned by <b>UnpackOrGet</b>.
-- @param key If <i>var</i> is a table with this key, it is interpreted as a packed argument
-- table, and the value as its argument count.
-- @param how Operation to request on <i>var</i>.
-- @return Returns as follows, in order of priority:<br><br>
-- &nbsp&nbsp- <i>var</i> is not a packed argument table: Returns <i>var</i>, or 1 if <i>how</i>
-- is <b>"count"</b>.<br><br>
-- &nbsp&nbsp- <i>how</i> is <b>"count"</b>: Returns the argument count.<br><br>
-- &nbsp&nbsp- <i>how</i> is <b>"first"</b>: Returns the first packed argument.<br><br>
-- &nbsp&nbsp- <i>how</i> is <b>"rest"</b>: Returns all packed arguments after the first.<br><br>
-- &nbsp&nbsp- Otherwise: Returns all packed arguments.
-- @see PackOrGet
function UnpackOrGet (var, key, how)
	local count = IsTable(var) and rawget(var, key)

	if how == "count" then
		return count or 1
	elseif not count then
		return var
	elseif how == "first" then
		return rawget(var, 1)
	else
		return unpack(var, how == "rest" and 2 or 1, count)
	end
end

-- Cache some routines.
_AssertArg_ = AssertArg
_WipeRange_ = WipeRange