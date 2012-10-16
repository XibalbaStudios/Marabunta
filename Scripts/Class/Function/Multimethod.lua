-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A multimethod / generic function is called like a regular function, but delegates to
-- whichever of its definitions best matches against its arguments.<br><br>
-- This allows for breaking up complicated monolithic functions into components, as well
-- as defining relationships between objects where it makes little sense for the logic to
-- belong to the objects themselves.<br><br>
-- In the one-argument case this can be thought of like C++ virtual functions or Smalltalk
-- message sending.<br><br>
-- Class. Derives from <a href="Sealable.html">Sealable</a>.
module Multimethod
]]

-- Standard library imports --
local assert = assert
local insert = table.insert
local ipairs = ipairs
local remove = table.remove

-- Modules --
local cache_ops = require("cache_ops")
local class = require("class")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local CollectArgsInto = var_ops.CollectArgsInto
local IsCallable = var_preds.IsCallable
local IsPositiveInteger = var_preds.IsPositiveInteger
local IsType = class.IsType
local Linearization = class.Linearization
local SuperCons = class.SuperCons
local TableCache = cache_ops.TableCache
local Type = class.Type
local WipeRange = var_ops.WipeRange

-- Unique member keys --
local _args_cache = {}
local _funcs = {}
local _key = {}
local _last = {}
local _paramc = {}

-- Multimethod class definition --
class.Define("Multimethod", function(Multimethod)
	-- Cache of function list tables --
	local FuncsCache = TableCache()

	--- Metamethod.<br><br>
	-- The arguments are checked against the multimethod's specializations, up to the
	-- dispatch-relevant parameter count. From the pool of functions that will successfully
	-- fit the arguments, the ones that most completely match the first argument are chosen.
	-- From those in turn, the ones that best match the second argument are chosen, and so
	-- on until one function remains, which is then called.<br><br>
	-- If no function matches the arguments, an error is thrown.
	-- @param ... Call arguments.
	-- @return Call results.
	function Multimethod:__call (...)
		local funcs = FuncsCache("pull")
		local source = self[_funcs]

		-- Gather the arguments.
		local args_cache = self[_args_cache]
		local argc, args = CollectArgsInto(args_cache("pull"), ...)

		-- Winnow out inapplicable functions: Untyped parameters permit any value; arguments
		-- must be of / derived from the parameter type otherwise.
		for i = 1, self[_paramc] do
			local arg = args[i]
			local atype, is_instance = Type(arg)
			local count = 0

			for _, func in ipairs(source) do
				local ptype = func[i]

				if ptype == nil or atype == ptype or (is_instance and IsType(arg, ptype)) then
					funcs[count + 1] = func

					count = count + 1
				end
			end

			-- Remove excess functions.
			WipeRange(funcs, count + 1)

			-- After the first loop, the function set is the source.
			source = funcs
		end

		assert(funcs[1], "Missing applicable function")

		-- Iterate left to right through the arguments until one function remains.
		local index = 1

		while funcs[2] do
			local ctype, is_instance = Type(args[index])
			local top = 0
			local supers

			-- For instance arguments, acquire the linearization.
			if is_instance then
                supers = Linearization(ctype)
                top = supers(nil)
			end

			-- Reduce the function set on the current argument.
			local use_nil = true
			local is_match = false
			local kept = 0

			for _, func in ipairs(funcs) do
				local ptype = func[index]
				local should_keep

				-- A match has already been found: only keep other matches.
				if is_match then
					should_keep = ptype == ctype

				-- Argument and parameter types match: dump all earlier candidates and
				-- insist that future candidates match as well.
				elseif ptype == ctype then
					kept = 0
					is_match = true
					should_keep = true

				-- Typed parameter has yet to be found: accept any argument.
				elseif ptype == nil then
					should_keep = use_nil

				-- Parameter is typed: if the argument is of or derived from the type, dump
				-- all earlier candidates with wildcard parameters; also, remove candidates
				-- of less specific types, and remove any such type from consideration.
				elseif top > 0 then
                    for i = top, 1, -1 do
                        if supers(i) == ptype then
							kept = (use_nil or i < top) and 0 or kept
							top = i
							use_nil = false
							should_keep = true
 
                            break
                        end
                    end
				end

				-- Put keepers back into the set.
				if should_keep then
					funcs[kept + 1] = func

					kept = kept + 1
				end
			end

			-- Remove functions that failed to satisfy this argument.
			WipeRange(funcs, kept + 1)

			-- Move to the next argument.
			index = index + 1
		end

		-- Clear and cache the lists.
		local func = remove(funcs).func

		args_cache(args, 1, argc)
		FuncsCache(funcs)

		-- Save and invoke the remaining function.
		self[_last] = func

		return func(...)
	end

	--- Defines a function specialized on its relevant parameters.<br><br>
	-- If a function already matches the specification, it is overwritten.<br><br>
	-- If the <b>"definitions"</b> permission is not available, an error is thrown.
	-- @param func Function to assign.
	-- @param ... Parameter types.<br><br>
	-- A type of <b>nil</b> will accept anything.<br><br>
	-- Otherwise, the type should either be a built-in value, e.g. <b>"number"</b>, or a
	-- name that was passed to <b>class.Define</b>.
	-- @see ~class.Define
	function Multimethod:Define (func, ...)
		assert(IsCallable(func), "Uncallable function")
		assert(self:IsAllowed("definitions"), "Further definitions forbidden")

		-- For each entry, compare the parameter list against the input list.
		local count, params = CollectArgsInto(nil, ...)

		assert(count <= self[_paramc])

		for _, entry in ipairs(self[_funcs]) do
			local index = 0

			repeat
				index = index + 1

				-- If the definition matches another entry, replace the old entry.
				if index > self[_paramc] then
					entry.func = func

					return
				end
			until entry[index] ~= params[index]
		end

		-- Given no matches, add the function to the set.
		params.func = func

		insert(self[_funcs], params)
	end

	--- Accessor.
	-- @return Function last called by the multimethod.
	function Multimethod:GetLastCalledFunc ()
		return self[_last]
	end

	--- Accessor.
	-- Gets the count of dispatch-relevant parameters.
	-- @return Parameter count.
	function Multimethod:GetParamCount ()
		return self[_paramc]
	end

	--- Metamethod.
	-- @return Function count.
	function Multimethod:__len ()
		return #self[_funcs]
	end

	--- Class constructor.
	-- @param paramc The number of parameters relevant to determining dispatch.
	function Multimethod:__cons (paramc)
		assert(IsPositiveInteger(paramc), "Invalid parameter count")

		SuperCons(self, "Sealable")

		-- Argument table cache --
		self[_args_cache] = TableCache("wipe_range")

		-- Function definitions --
		self[_funcs] = {}
		
		-- Parameter count --
		self[_paramc] = paramc
	end
end, { base = "Sealable" })