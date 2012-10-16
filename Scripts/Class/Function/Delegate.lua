-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A new delegate begins as a no-op function, and its core can be set and cleared at will.
-- As such, it can be used to place stubs / join points at key points in code, which can be
-- filled in according to the needs of the program.<br><br>
-- A delegate which has core logic can be augmented with "advice", i.e. functionality that
-- is executed before and after the core.<br><br>
-- Optionally, the "before" logic may be used to abort the call before the core is invoked.<br><br>
-- Class.
module Delegate
]]

-- Standard library imports --
local ipairs = ipairs
local remove = table.remove

-- Modules --
local table_ops = require("table_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local AssertArg_Pred = var_ops.AssertArg_Pred
local CollectArgsInto = var_ops.CollectArgsInto
local Copy = table_ops.Copy
local IsCallableOrNil = var_preds.IsCallableOrNil

-- Unique member keys --
local _afters = {}
local _befores = {}
local _can_abort = {}
local _core = {}

-- Delegate class definition --
class.Define("Delegate", function(Delegate)
	--- Appends an "after" function.
	-- @class function
	-- @name Delegate:AddAfter
	-- @param after Function to add.
	-- @see Delegate:PopAfter
	Delegate.AddAfter = func_ops.FuncAppender(_afters, 'Uncallable "after"')

	--- Prepends a "before" function.
	-- @class function
	-- @name Delegate:AddBefore
	-- @param before function to add.
	-- @see Delegate:PopBefore
	Delegate.AddBefore = func_ops.FuncAppender(_befores, 'Uncallable "before"')

	--- Sets whether a "before" function can abort calls.<br><br>
	-- By default, this is disallowed.
	-- @param allow If true, allow aborts.
	function Delegate:AllowAbort (allow)
		self[_can_abort] = allow and true or nil
	end

	-- Cache of core results tables --
	local ResultsCache = cache_ops.TableCache("unpack_and_wipe")

	--- Metamethod.<br><br>
	-- If no core is present, this is a no-op.<br><br>
	-- If any "before" functions have been added, these are called, in most- to least-
	-- recent order, with the call arguments. If any of these returns <b>"abort"</b>,
	-- the call is aborted, provided permission is on.<br><br>
	-- The core is then called with the call arguments.<br><br>
	-- If any "after" functions have been added, these are called, in least- to most-
	-- recent order, with the call arguments.<br><br>
	-- Finally, the results of the core call are returned.
	-- @param ... Arguments to call.
	-- @return Call results.
	-- @see Delegate:AddAfter
	-- @see Delegate:AddBefore
	-- @see Delegate:AllowAbort
	-- @see Delegate:SetCore
	function Delegate:__call (...)
		local core = self[_core]

		if core then
			-- Invoke each before routine, aborting if requested.
			local befores = self[_befores]
			local can_abort = self[_can_abort]

			for i = #befores, 1, -1 do
				if befores[i](...) == "abort" and can_abort then
					return
				end
			end

			-- Invoke the core. If after routines are to be called, cache its results
			-- beforehand. In either case, supply the results.
			if #self[_afters] == 0 then
				return core(...)
			else
				local count, results = CollectArgsInto(ResultsCache("pull"), core(...))

				-- Invoke each after routine.
				for _, after in ipairs(self[_afters]) do
					after(...)
				end

				-- Return the results from the core function.
				return ResultsCache(results, count)
			end
		end
	end

	---
	-- @return Core function, or <b>nil</b> if absent.
	-- @see Delegate:SetCore
	function Delegate:GetCore ()
		return self[_core]
	end

	--- Removes the most-recently added "after" function.
	-- @return Removed function, or <b>nil</b> if none was present.
	-- @see Delegate:AddAfter
	function Delegate:PopAfter ()
		return remove(self[_afters])
	end

	--- Removes the most-recently added "before" function.
	-- @return Removed function, or <b>nil</b> if none was present.
	-- @see Delegate:AddBefore
	function Delegate:PopBefore ()
		return remove(self[_befores])
	end

	---
	-- @param func Core function to assign, or <b>nil</b> to clear the core.
	-- @param should_clear If true, the "before" and "after" functions are cleared.
	-- @see Delegate:AddAfter
	-- @see Delegate:AddBefore
	-- @see Delegate:GetCore
	function Delegate:SetCore (func, should_clear)
		self[_core] = AssertArg_Pred(IsCallableOrNil, func, "Uncallable core")

		-- If requested, reset the function lists at the same time.
		if should_clear then
			self[_afters] = {}
			self[_befores] = {}
		end
	end

	--- Class constructor.
	-- @param func Optional core function.
	-- @see Delegate:SetCore
	function Delegate:__cons (func)
		self:SetCore(func, true)
	end

	--- Class clone body.
	function Delegate:__clone (D)
		self[_can_abort] = D[_can_abort]
		self[_core] = D[_core]

		self[_afters] = Copy(D[_afters])
		self[_befores] = Copy(D[_befores])
	end
end)