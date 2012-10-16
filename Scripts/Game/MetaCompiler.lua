-- Standard library imports --
local assert = assert
local concat = table.concat
local format = string.format
local gsub = string.gsub
local ipairs = ipairs
local loadstring = loadstring
local lower = string.lower
local match = string.match
local pairs = pairs
local rep = string.rep
local setmetatable = setmetatable
local sub = string.sub
local tostring = tostring

-- Modules --
local cache_ops = require("cache_ops")
local em = require("entity_manager")
local func_ops = require("func_ops")
local game_state = require("game_state")
local iterators = require("iterators")
local table_ops = require("table_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Cached routines --
local _Declare_
local _InterpVar_

---
--
module "metacompiler"

-- Common signature parameters --
local Params = "GlobalVars, SceneVars, ZoneVars"
local ParamsWithObject = Params .. ", object)\n"

-- Form of some embedded call --
local CallFunc = "%s\t%s%s(" .. ParamsWithObject .. "%s"

-- Form of chunk body; generated function is returned when chunk runs --
local Body = "-- %s\n%sreturn function(" .. Params .. ", object%s)\n%s\nend"

-- Output function --
local OutputFunc

-- Output boolean --
local ShouldListOutput

-- Number of format layers before final output --
local FormatLayerCount

-- Declared names --
local Names = {}

-- Declared values --
local Values = {}

-- Helper to concatenate an intermediate comma-separated string table
local function ConcatAndWipe (t, sep)
	local result = concat(t, sep or ", ")

	var_ops.WipeRange(t)

	return result
end

-- Helper to get concatenated declaration string
local function GetDeclaration ()
	return #Names > 0 and format("local %s = ...\n\n", ConcatAndWipe(Names)) or ""
end

-- Helper to build and initialize chunk
local function PrimeChunk (cstr, ...)
	return assert(loadstring(cstr))(...)
end

-- Helper to list a string
local function List (str)
	if ShouldListOutput and OutputFunc then
		if var_preds.IsPositive(FormatLayerCount) then
			str = gsub(str, "%%", rep("%%", FormatLayerCount * 2))
		end

		OutputFunc(str)
	end
end

-- Builds the final function, given a body and any inner function
local function BuildFunc (body, about, has_choice)
	-- If no body has been built up, return nothing. Otherwise, assemble and run the
	-- chunk, finally binding it to the variable families. If an inner function was
	-- specified, a fourth parameter is added to receive function input.
	if #body > 0 then
		local cstr = format(Body, about, GetDeclaration(), has_choice and ", choice" or "", body)
		local func = PrimeChunk(cstr, var_ops.UnpackAndWipe(Values))

		List(cstr)

		return game_state.BoundStateVarsFunc_Arg(func)
	end
end

--- Declares an upvalue for the function being built.
-- @param name
-- @param value
-- @return @e name, as a convenience
function Declare (name, value)
	assert(var_preds.IsString(name), "Non-string name in declaration")
	assert(value ~= nil, "Nil value")

	local index = table_ops.Find(Names, name, true)

	if index then
		assert(Values[index] == value, "Attempt to redefine value declared with the same name")
	else
		Names[#Names + 1] = name
		Values[#Values + 1] = value
	end

	return name
end

-- Compile contexts --
local Contexts = {}

---
-- @param cid
-- @param subs
-- @param prologue_builder
-- @param epilogue_builder
function RegisterCompileContext (cid, subs, prologue_builder, epilogue_builder)
	assert(cid ~= nil, "Nil context ID")
	assert(not Contexts[cid], "Context already registered under ID")
	assert(var_preds.IsTableOrNil(subs), "Non-table substitutions")
	assert(var_preds.IsCallableOrNil(prologue_builder), "Uncallable prologue builder")
	assert(var_preds.IsCallableOrNil(epilogue_builder), "Uncallable epilogue builder")

	Contexts[cid] = { bookend_cache = {}, subs = subs, prologue_builder = prologue_builder, epilogue_builder = epilogue_builder }
end

--- Sets an output function to which a function body is sent if it compiled.<br><br>
-- The generated code aims at being reasonably formatted. Tabs are used for indentation;
-- the outermost scope is unindented. Also, spaces appear between some lines.
-- @param func Output function which takes a string, or <b>nil</b> to clear the function.
-- @param layer_count Non-negative layer count, 0 by default; this indicates how many format
-- functions the output will pass through, in order to properly sanitize any format specifiers
function SetOutputFunc (func, layer_count)
	assert(var_preds.IsCallableOrNil(func), "Invalid output function")
	assert(layer_count == nil or var_preds.IsNonNegativeInteger(layer_count), "Invalid layer count")

	OutputFunc = func
	FormatLayerCount = layer_count
end

-- Arguments to string_format --
local FormatArgs = {}

-- User-supplied name, passed to substitution attempts --
local Name

-- Current substitions table --
local Subs

-- Variable interpolation --
do
	-- Total size of original variable string --
	local TotalSize

	-- Helper to interpolate a variable
	local function AuxInterpVar (var)
		var = sub(var, 3, -2)

		-- Indicate whether this capture, with delimiters re-added, would comprise the whole name.
		local is_all = TotalSize == #var + 3

		-- Attempt to find a match for the variable as key first, then go one by one through the
		-- array. If one of these returns a result when called, or is already a string, use that
		-- as the substitution.
		local f, s, v0, cleanup = iterators.ItemThenIpairs(Subs[var] or func_ops.NoOp, Subs)

		for _, str_ in f, s, v0 do
			local ret, arg

			if var_preds.IsString(str_) then
				ret = str_
			else
				ret, arg = str_(Name, var, is_all)
			end

			if ret then
				FormatArgs[#FormatArgs + 1] = arg

				cleanup()

				return ret
			end
		end

		-- Failing a match, interpolate to blank.
		return ""
	end

	--- Applies any variable interpolations.
	-- @param var_name
	-- @param no_quote
	-- @return
	function InterpVar (var_name, no_quote)
		TotalSize = #var_name

		if var_name and Subs then
			var_name = gsub(var_name, "%$%b()", AuxInterpVar)

			if #FormatArgs > 0 then
				_Declare_("string_format", format)

				return format("string_format(%q, %s)", var_name, ConcatAndWipe(FormatArgs))

			elseif not no_quote then
				return format("%q", var_name)
			end
		end

		return var_name
	end

	-- Global substitutions table --
	local SubsMeta = { __metatable = true }

	SubsMeta.__index = SubsMeta

	--- Adds a new interpolation to the global substitutions table.
	-- @param name Variable name.
	-- @param value Value or callback to assign.
	-- @return If true, the value was free and got assigned.
	-- @see NewVarInterpTable
	function AddGlobalVarInterpolation (name, value)
		if SubsMeta[name] ~= nil then
			return false
		end

		SubsMeta[name] = value

		return true
	end

	--- Builds a new substitution table that uses the global table as a prototype and
	-- will thus inherit any new interpolations as they are added.
	-- @return Interpolation table.
	-- @see AddGlobalVarInterpolation
	function NewVarInterpTable ()
		return setmetatable({}, SubsMeta)
	end
end

-- Compilation and calls --
do
	-- --
	local Annotate

	--
	local function About (object, type, name, key)
		return (Annotate or func_ops.EmptyString)(object, type, name, key)
	end

	-- --
	local ReadObject

	-- Base substitutions --
	local BaseSubs = NewVarInterpTable()

	-- Control state vars --
	local ControlVars = game_state.GetStateVars("control")

	--
	local function BindCompileContext (context, name)
		assert(not Subs, "Attempt to do nested compile")

		ControlVars:CallDelegate("on_bind_compile_context", name)

		Subs = context and context.subs or BaseSubs
		Name = name
	end

	--
	local function Unbind ()
		Name = nil
		Subs = nil
	end

	-- Helper to use listings
	local function ListOutput (should_list)
		ShouldListOutput = not not should_list
	end

	--
	local function LazyGetFunc (flist, key, aux, arg1, arg2, arg3, arg4, arg5)
		local func = flist[key]

		if not func then
			func = aux(key, arg1, arg2, arg3, arg4, arg5) or func_ops.NoOp

			flist[key] = func
		end

		return func
	end

	-- --
	local Cache = cache_ops.TableCache()

	-- --
	local Actions = table_ops.SubTablesOnDemand(nil, nil, Cache)

	-- --
	local Statements = {}

	--
	local function AuxAction (key, node, name, cid)
		assert(ReadObject, "No object reader installed")

		BindCompileContext(Contexts[cid], name)

		var_ops.CollectArgsInto(Statements, ReadObject(key, node))

		Unbind()

		local about = About(node, "action", name, key)

		if #Statements > 0 then
			return BuildFunc("\t" .. ConcatAndWipe(Statements, "\n\t"), about)
		else
			List(format("-- EMPTY ACTION (no-op)\n-- %s", about))

			return func_ops.NoOp
		end
	end

	---
	-- @param node
	-- @param name
	-- @param object
	-- @param key
	-- @param cid
	-- @param should_list
	function CallAction (node, name, object, key, cid, should_list)
		assert(node, "Nil action node")

		ListOutput(should_list)

		LazyGetFunc(Actions[node], key, AuxAction, node, name, cid)(object)
	end

	--
	local function ParamList (params)
		return format("(%s)", _InterpVar_(sub(params, 2, -2)))
	end

	--
	local function AuxString (str, context, name, cid, what)
		BindCompileContext(context, name)

		local body = format("\t%s", gsub(gsub(str, "%b()", ParamList), "\n", "\n\t"))

		Unbind()

		return BuildFunc(body, About(cid, what, name), true)
	end

	--
	local function AuxBookend (key, funcs_list, name, cid, builder_name, what)
		local context = Contexts[cid]
		local builder = context and context[builder_name]

		if builder then
			local result = builder(key, name)

			--
			if var_preds.IsString(result) then
				return LazyGetFunc(context.bookend_cache, result, AuxString, context, name, cid, what)

			--
			elseif result ~= nil then
				assert(var_preds.IsCallable(result), "Uncallable bookend function")

				return game_state.BoundStateVarsFunc_MultiArg(result)
			end
		end
	end

	--
	local function GetBookendFunc (funcs_list, key, name, cid, builder_name, what)
		return LazyGetFunc(funcs_list, key, AuxBookend, funcs_list, name, cid, builder_name, what)
	end

	-- --
	local Prologues = {}

	---
	-- @param key
	-- @param name
	-- @param object
	-- @param choice
	-- @param cid
	-- @param should_list
	function CallPrologue (key, name, object, choice, cid, should_list)
		ListOutput(should_list)

		GetBookendFunc(Prologues, key, name, cid, "prologue_builder", "prologue")(object, choice)
	end

	-- --
	local Epilogues = {}

	---
	-- @param key
	-- @param name
	-- @param object
	-- @param choice
	-- @param cid
	-- @param should_list
	function CallEpilogue (key, name, object, choice, cid, should_list)
		ListOutput(should_list or true)

		GetBookendFunc(Epilogues, key, name, cid, "epilogue_builder", "epilogue")(object, choice)
	end

	-- --
	local Conditions = table_ops.SubTablesOnDemand(nil, nil, Cache)

	--
	local function AuxCondition (key, node, name, cid)
		assert(ReadObject, "No object reader installed")

		BindCompileContext(Contexts[cid], name)

		local body = ReadObject(key, node)

		Unbind()

		local about = About(node, "condition", name, key)

		if body then
			return BuildFunc("\treturn " .. body, about)
		else
			List(format("-- EMPTY CONDITION (always false)\n-- %s", about))

			return func_ops.False
		end
	end

	---
	-- @param node
	-- @param name
	-- @param object
	-- @param key
	-- @param cid
	-- @param should_list
	-- @return
	function CallCondition (node, name, object, key, cid, should_list)
		assert(node, "Nil condition node")

		ListOutput(should_list)

		return LazyGetFunc(Conditions[node], key, AuxCondition, node, name, cid)(object)
	end

	--
	local function ClearList (list)
		for k in pairs(list) do
			list[k] = nil
		end
	end

	---
	function CleanUp ()
		-- Empty the action bookend lists.
		ClearList(Prologues)
		ClearList(Epilogues)

		-- Empty bookend caches.
		for _, context in pairs(Contexts) do
			ClearList(context.bookend_cache)
		end

		-- Clean up two-layer lists by emptying the subtables and then putting them back
		-- in the cache, then emptying the main list.
		for node, alist in pairs(Actions) do
			ClearList(alist)

			Cache(alist)

			Actions[node] = nil
		end
	end

	---
	-- @param func
	function SetAnnotateFunc (func)
		assert(var_preds.IsCallableOrNil(func), "Uncallable annotate")

		Annotate = func
	end

	---
	-- @param func
	function SetReadObjectFunc (func)
		assert(var_preds.IsCallableOrNil(func), "Uncallable object reader")

		ReadObject = func
	end
end

-- Cache some routines.
_Declare_ = Declare
_InterpVar_ = InterpVar