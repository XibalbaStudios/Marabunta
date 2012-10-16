-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local format = string.format
local getmetatable = getmetatable
local ipairs = ipairs
local newproxy = newproxy
local pairs = pairs
local setmetatable = setmetatable
local tostring = tostring
local type = type

-- Modules --
local func_ops = require("func_ops")
local table_ops = require("table_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local AssertArg = var_ops.AssertArg
local AssertArg_Pred = var_ops.AssertArg_Pred
local Copy_WithTable = table_ops.Copy_WithTable
local IsCallable = var_preds.IsCallable
local IsFunction = var_preds.IsFunction
local IsTable = var_preds.IsTable
local IsTableOrUserdata = var_preds.IsTableOrUserdata
local NoOp = func_ops.NoOp
local Try_Multi = func_ops.Try_Multi
local Weak = table_ops.Weak

-- Cached routines --
local _IsInstance_
local _IsType_
local _New_

-- Instance / type mappings --
local Instances = Weak("k")

-- Class definitions --
local Defs = {}

-- Built-in type set --
local BuiltIn = table_ops.MakeSet{ "boolean", "function", "nil", "number", "string", "table", "thread", "userdata" }

-- Metamethod set --
local Metamethods = table_ops.MakeSet{
	"__index", "__newindex",
	"__eq", "__le", "__lt",
	"__add", "__div", "__mul", "__sub",
	"__mod", "__pow", "__unm",
	"__call", "__concat", "__gc", "__len"
}

--- This module provides a system for class-based object-oriented programming, with some
-- reflection support included.
module "class"

-- Class hierarchy linearizations --
local Linearizations = setmetatable({}, {
    __index = function(t, ctype)
        local types = {}

        local function walker (index)
            if index == nil then
                return #types
            else
                return types[index]
            end
        end

        t[ctype] = walker

        repeat
            types[#types + 1] = ctype

			ctype = Defs[ctype].base
        until ctype == nil

        return walker
    end
})

do
	-- Per-class data for default allocations --
	local ClassData = setmetatable({}, {
		__index = function(t, meta)
			local datum = newproxy(true)

			Copy_WithTable(getmetatable(datum), meta)

			t[meta] = datum

			return datum
		end
	})

	-- Per-instance data for default allocations --
	local InstanceData = Weak("k")

	-- Default instance allocator
	local function DefaultAlloc (meta)
		local I = newproxy(ClassData[meta])

		InstanceData[I] = {}

		return I
	end

	-- Default indirect __index metamethod
	local function DefaultIndex (I, key)
		return InstanceData[I][key]
	end

	-- Default indirect __newindex metamethod
	local function DefaultNewIndex (I, key, value)
		InstanceData[I][key] = value
	end

	-- Common __index body
	local function Index (I, key)
		local defs = Defs[Instances[I]]
		local index = defs.__index

		-- Pass the search along for the value.
		local value

		if IsCallable(index) then
			value = index(I, key)
		else
			value = index[key]
		end

		-- If the value was not found, try the members. Return the final result.
		if value ~= nil then
			return value
		else
			return defs.members[key]
		end
	end

	-- Common __newindex body
	local function NewIndex (I, key, value)
		local newindex = Defs[Instances[I]].__newindex

		-- Pass along the assignment.
		if IsCallable(newindex) then
			newindex(I, key, value)
		else
			newindex[key] = value
		end
	end

	--- Defines a new class.
	-- @param ctype Class type name.
	-- @param members Members to add.<br><br>
	-- This may be a table, in which case each (name, member) pair is read out directly.<br><br>
	-- Alternatively, this can be a function which takes a table as its argument; in that case,
	-- a fresh table is provided to the function, and after it has been called, its (name,
	-- member) entries are loaded.<br><br>
	-- Entries with names corresponding to metamethods will be installed as such.<br><br>
	-- A <b>__cons</b> entry will be installed as the constructor, which is a no-op
	-- otherwise. This should be callable as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>cons(I, ...)</b></i>,<br><br>
	-- where <i>I</i> is the instance and <i>...</i> are any arguments passed to <b>New</b>.<br><br>
	-- A <b>__clone</b> entry will be installed as the clone body, which is an error
	-- otherwise. This should be callable as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>clone(I, ...)</b></i>,<br><br>
	-- where <i>I</i> is the instance to clone and <i>...</i> are any arguments passed to <b>Clone</b>.<br><br>
	-- @param params Configuration parameters table, or <b>nil</b> to use the defaults.<br><br>
	-- If the <b>base</b> key is present, its value should be the type name of a class
	-- previously made with <b>Define</b>. This class will then inherit the members and metamethods
	-- of the base class.<br><br>
	-- If the <b>alloc</b> key is present, its value should be callable as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>alloc(meta)</b></i>,<br><br>
	-- where <i>meta</i> is the class's metatable. An allocator must return a new object
	-- with this metatable associated with it in a way appropriate to its usage patterns.
	-- The metatable's <b>__index</b> points to the members table.<br><br>
	-- If absent, the class will inherit the base class's allocator.<br><br>
	-- Failing that, a default allocator is used. Each instance is an opaque userdata with a
	-- corresponding data table, where arbitrary data can be written and read by indexing the
	-- userdata, using the defaults for <b>__index</b> and <b>__newindex</b>. A member may
	-- be shadowed in an instance by assigning another value to its name, and restored by
	-- setting it to <b>nil</b>.
	-- @see Clone
	-- @see GetMember
	-- @see New
	function Define (ctype, members, params)
		assert(ctype ~= nil, "Define: ctype == nil")
		assert(ctype == ctype, "Define: ctype is NaN")
		assert(not BuiltIn[ctype], "Define: ctype refers to built-in type")
		assert(not Defs[ctype], "Class already defined")
		assert(IsTable(members) or IsFunction(members), "Non-table / function members")

		-- Prepare the definition.
		local def = {
			alloc = DefaultAlloc,
			cons = NoOp,
			members = {},
			meta = {},
			__index = DefaultIndex,
			__newindex = DefaultNewIndex
		}

		-- Configure the definition according to the input parameters.
		if params then
			assert(IsTable(params), "Non-table parameters")

			local alloc = params.alloc

			-- Inherit from base class, if provided.
			if params.base ~= nil then
				local base_info = assert(Defs[params.base], "Base class does not exist")

				-- Inherit base class metamethods.
				Copy_WithTable(def.meta, base_info.meta)

				def.__index = base_info.__index
				def.__newindex = base_info.__newindex

				-- Inherit base class members.
				def.members.__index = base_info.members

				setmetatable(def.members, def.members)

				-- Inherit the allocator if one was not specified.
				if alloc == nil then
					alloc = base_info.alloc
				end

				-- Store the base class name.
				def.base = params.base
			end

			-- Assign any custom allocator.
			if alloc ~= nil then
				assert(IsCallable(alloc), "Uncallable allocator")

				def.alloc = alloc
			end
		end

		-- If the caller loads the members in a function, regularize this to the table case,
		-- using the table that gets filled.
		if IsFunction(members) then
			local results = {}

			members(results)

			members = results
		end

		-- Install constructor, members, and metamethods.
		for k, member in pairs(members) do
			if k == "__cons" then
				def.cons = AssertArg_Pred(IsCallable, member, "Uncallable constructor")
			elseif k == "__clone" then
				def.clone = AssertArg_Pred(IsCallable, member, "Uncallable clone")
			else
				local mtable = def.members

				-- If a metamethod is specified, target that table instead. For __index and
				-- __newindex, target their indirect methods.
				if Metamethods[k] then
					if k == "__index" or k == "__newindex" then
						assert(IsCallable(member) or IsTableOrUserdata(member), "Invalid __index / __newindex")

						mtable = def
					else
						assert(IsCallable(member), "Uncallable metamethod")

						mtable = def.meta
					end
				end

				-- Install the member.
				mtable[k] = member
			end
		end

		-- Install master lookup metamethods and lock the metatable.
		def.meta.__index = Index
		def.meta.__newindex = NewIndex
		def.meta.__metatable = true

		-- Register the class.
		Defs[ctype] = def
	end
end

---
-- @param ctype Type name.
-- @return If true, type exists.
-- @see Define
function Exists (ctype)
	assert(ctype ~= nil, "Exists: ctype == nil")

	return Defs[ctype] ~= nil
end

--- Obtains a value that was registered in the members table (or the table passed to the
-- members function) during type definition.<br><br>
-- Metamethods and the constructor are not included.
-- @param ctype Type name.
-- @param member Member name.
-- @return Member, or <b>nil</b> if absent.
-- @see Define
function GetMember (ctype, member)
	assert(ctype ~= nil, "GetMember: ctype == nil")
	assert(member ~= nil, "GetMember: member == nil")

	return assert(Defs[ctype], "Type not found").members[member]
end

---
-- @param item Item, which may be a class instance.
-- @return If true, item is an made by <b>New</b>.
-- @see New
function IsInstance (item)
	return (item and Instances[item]) ~= nil
end

---
-- @param item Item.
-- @param what Type name or a return value of <b>type</b>.
-- @return If true, <i>item</i> is of the given type or one of its subclasses.
function IsType (item, what)
    assert(what ~= nil, "IsType: what == nil")

    -- Begin with the instance type. Progress upward until a match or the top.
    if _IsInstance_(item) and not BuiltIn[what] then
        local walker = Linearizations[Instances[item]]

        for i = 1, walker(nil) do
            if walker(i) == what then
                return true
            end
        end

        return false	

    -- For non-instances, check the built-in type.
    else
        return type(item) == what
    end
end

--- Gets a type's linearization, i.e. a flattened representation of its superclass hierarchy.
-- @param ctype Type name.
-- @return Linearization walker, which is called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>walker(i)</b></i>,<br><br>
-- where <i>i</i> is the index in the linearization, ranging from 1 (the type itself)
-- to the linearization's size (its least specific base class), which can be obtained
-- by calling <b>walker(nil)</b>.
-- @see Define
function Linearization (ctype)
    assert(ctype ~= nil, "Linearization: ctype == nil")
    assert(Defs[ctype], "Type not found")

    return Linearizations[ctype]
end

do
	-- Stack of instances in construction --
	local ConsStack = {}

	--- Invokes a superclass constructor.<br><br>
	-- This may only be called on an instance within its constructor.
	-- @param I Instance.
	-- @param stype Superclass type name.
	-- @param ... Constructor arguments.
	-- @see Define
	-- @see New
	function SuperCons (I, stype, ...)
		assert(I ~= nil, "SuperCons: I == nil")
		assert(stype ~= nil, "SuperCons: stype == nil")
		assert(ConsStack[#ConsStack] == I, "Invoked outside of constructor")
		assert(Instances[I] ~= stype, "Instance already of superclass type")
		assert(_IsType_(I, stype), "Superclass not found")

		-- Invoke the constructor.
		Defs[stype].cons(I, ...)
	end

	-- Protected construct
	local function Cons (top, cons, I, ctype, ...)
		assert(IsTableOrUserdata(I), "Bad instance allocation")
		assert(Instances[I] == nil, "Instance already exists")

		ConsStack[top] = I

		Instances[I] = ctype

		-- Invoke the constructor.
		cons(I, ...)
	end

	-- Construct done
	local function ConsDone (top)
		ConsStack[top] = nil
	end

	--- Clones a class instance.
	-- @param I instance.
	-- @param ... Clone arguments.
	-- @return Instance clone.
	-- @see Define
	function Clone (I, ...)
		local ctype = assert(Instances[I], "Invalid instance")
		local type_info = Defs[ctype]
		local clone = AssertArg(type_info.clone, "class.Clone: Type \"%s\" does not support cloning", tostring(ctype))
		local CI = type_info.alloc(type_info.meta)

		Try_Multi(Cons, ConsDone, #ConsStack + 1, clone, CI, ctype, I, ...)

		return CI
	end

	--- Builds a callback to instantiate a class.
	-- @param ctype Type name.
	-- @param arg1 Argument #1.
	-- @param arg2 Argument #2.
	-- @return Callback.
	function InstanceMaker (ctype, arg1, arg2)
		return function()
			return _New_(ctype, arg1, arg2)
		end
	end

	--- Instantiates a class.
	-- @param ctype Type name.
	-- @param ... Constructor arguments.
	-- @return Instance.
	-- @see Define
	function New (ctype, ...)
		assert(ctype ~= nil, "New: ctype == nil")

		local type_info = AssertArg(Defs[ctype], "class.New: Type \"%s\" not found", ctype)
		local I = type_info.alloc(type_info.meta)

		Try_Multi(Cons, ConsDone, #ConsStack + 1, type_info.cons, I, ctype, ...)

		return I
	end
end

--- Gets a type's direct superclasses.
-- @param ctype Type name.
-- @return List of superclass type names, or <b>nil</b> if the type has no base classes.
function Supers (ctype)
	assert(ctype ~= nil, "Supers: ctype == nil")

	return assert(Defs[ctype], "Type not found").base
end

--- Gets an arbitrary item's type.
-- @param item Item, which may be a class instance.
-- @return If <i>item</i> was made by <b>New</b>, its type name. Otherwise, the result of
-- <b>type(item)</b>.
-- @return If true, <i>item</i> is an instance made by <b>New</b>.
function Type (item)
	if _IsInstance_(item) then
		return Instances[item], true
	else
		return type(item), false
	end
end

-- Cache some routines.
_IsInstance_ = IsInstance
_IsType_ = IsType
_New_ = New