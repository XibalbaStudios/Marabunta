-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local yield = coroutine.yield

-- Modules --
local cache_ops = require("cache_ops")
local coroutine_ex = require("coroutine_ex")
local func_ops = require("func_ops")
local var_preds = require("var_preds")

-- Imports --
local Call_Multi = func_ops.Call_Multi
local IsCallable = var_preds.IsCallable
local IsIterationDone = coroutine_ex.IsIterationDone
local IsTable = var_preds.IsTable
local Reset = coroutine_ex.Reset
local Wrap = coroutine_ex.Wrap

--- Defines some operations on <a href="coroutine_ex.html">extended coroutines</a> for
-- the non-deterministic choice (AKA ambiguous) operator, i.e. operations that are able
-- to short-circuit even from deep down (so long as control has not passed into another
-- coroutine) and thus, given a set of choices, always "choose" correctly.<br><br>
-- As a caveat, the logic passed to these operations should be conservative in its side
-- effects, as these will not be undone on a wrong guess.
module "nondeterminism_ops"

do
	-- Wrapper cache --
	local Cache = cache_ops.SimpleCache()

	-- Helper to try each guess and supply one if the iterator does not reset / abort
	local function AuxChoose (iter, guesses, func, arg)
		for _, choice in ipairs(guesses) do
			local extra_ = iter(func, choice, arg)

			if IsIterationDone(iter) and extra_ ~= "abort" then
				return choice, extra_
			else
				Reset(iter)
			end
		end
	end

	--- Implements a single-choice nondeterministic choose.<br><br>
	-- The guesses are iterated, in order, each being passed as argument to the callback.
	-- The callback is run inside the body of an extended coroutine; it can be aborted by
	-- calling <b>coroutine.yield</b> or <b>coroutine_ex.Reset</b>, or by returning <b>
	-- "abort"</b> (the latter is cheaper, as it permits coroutine recycling, but is
	-- inconvenient deep in the call stack).<br><br>
	-- If the callback finishes, the guess is returned as the choice.<br><br>
	-- If no choice is made, the fail logic is called, without arguments.
	-- @param guesses Array of guesses.
	-- @param func Callback on guesses.
	-- @param fail Fail logic.
	-- @param arg Optional second argument to <i>func</i>.
	-- @return Choice, if available. Otherwise, nothing.
	-- @return If there was a choice, <i>func</i>'s first return value, or <b>nil</b> if
	-- it returned nothing.
	-- @see ~coroutine_ex.Reset
	function Choose (guesses, func, fail, arg)
		assert(IsTable(guesses), "Invalid guess set")
		assert(IsCallable(func), "Uncallable function")
		assert(IsCallable(fail), "Uncallable fail")

		-- Grab an iterator, try the guesses, and restore the iterator.
		local iter = Cache("pull") or Wrap(Call_Multi)
		local guess, extra = AuxChoose(iter, guesses, func, arg)

		Cache(iter)

		-- If a choice was found, return it and any extra info. Otherwise, fail.
		if guess ~= nil then
			return guess, extra
		else
			fail()
		end
	end
end

do
	-- Wrapper cache --
	local Cache = cache_ops.SimpleCache()

	-- ChooseMulti body that accumulates a guess if the iterator does not reset / abort
	local function Body (func, choice, results, arg)
		if func(choice, arg) ~= "abort" then
			results[#results + 1] = choice
		end
	end

	--- Multi-choice variant of <b>Choose</b>.<br><br>
	-- Instead of returning, as in <b>Choose</b>, choices are added to an array that
	-- is returned at the end.
	-- @param guesses Array of guesses.
	-- @param func Callback on choices.
	-- @param fail Fail logic.
	-- @param arg Optional second argument to <i>func</i>.
	-- @return Array of choices, if any were available. Otherwise, nothing.
	-- @see Choose
	function ChooseMulti (guesses, func, fail, arg)
		assert(IsTable(guesses), "Invalid guess set")
		assert(IsCallable(func), "Uncallable function")
		assert(IsCallable(fail), "Uncallable fail")

		-- Grab an iterator, try the guesses, and restore the iterator.
		local iter = Cache("pull") or Wrap(Body)
		local results = {}

		for _, choice in ipairs(guesses) do
			iter(func, choice, results, arg)

			Reset(iter)
		end

		Cache(iter)

		-- Return any choices. If none are available, fail. 
		if #results > 0 then
			return results
		else
			fail()
		end
	end
end