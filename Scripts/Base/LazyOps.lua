-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local setmetatable = setmetatable

-- Modules --
local var_preds = require("var_preds")

-- Imports --
local IsCallable = var_preds.IsCallable

-- Cached routines --
local _MakeOnDemand_Meta_
local _MakeOnDemand_Meta_Nullary_

---
module "lazy_ops"

--- Builds a new table. If one of the table's keys is missing, it will be filled in
-- automatically when indexed with a new object.<br><br>
-- The table's metatable is fixed.
-- @param make Routine called when a key is missing, that may take the key as argument and
-- returns a value to be assigned.
-- @param is_nullary If true, <i>make</i> receives no argument.
-- @return Table.
function MakeOnDemand (make, is_nullary)
	return setmetatable({}, (is_nullary and _MakeOnDemand_Meta_Nullary_ or _MakeOnDemand_Meta_)(make))
end

--- Builds a metatable, as per that assigned to <b>MakeOnDemand</b>'s new table.
-- @param make Routine called when a key is missing, that takes the key as argument and
-- returns a value to be assigned.
-- @return Metatable.
function MakeOnDemand_Meta (make)
	assert(IsCallable(make), "Uncallable make")

	return {
		__index = function(t, k)
			t[k] = make(k)

			return t[k]
		end
	}
end

--- Variant of <b>MakeOnDemand_Meta</b> that takes a nullary make routine.
-- @param make Routine called when a key is missing, that takes no arguments and returns
-- a value to be assigned.
-- @return Metatable.
function MakeOnDemand_Meta_Nullary (make)
	assert(IsCallable(make), "Uncallable make")

	return {
		__index = function(t, k)
			t[k] = make()

			return t[k]
		end
	}
end

--- Gets an object's member. If the member does not exist, a new table is first created
-- and assigned as the member.<br><br>
-- Note that if the member already exists it may not be a table.
-- @param object Object to query.
-- @param name Member name.
-- @return Member.
function MemberTable (object, name)
	local t = object[name] or {}

	object[name] = t

	return t
end

-- Cache some routines.
_MakeOnDemand_Meta_ = MakeOnDemand_Meta
_MakeOnDemand_Meta_Nullary_ = MakeOnDemand_Meta_Nullary