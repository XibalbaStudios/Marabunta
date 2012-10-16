-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local create = coroutine.create
local error = error
local pcall = pcall
local resume = coroutine.resume
local running = coroutine.running
local status = coroutine.status
local yield = coroutine.yield

-- Modules --
local func_ops = require("func_ops")
local iterators = require("iterators")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local CollectArgsInto_IfAny = var_ops.CollectArgsInto_IfAny
local GetLastTraceback = func_ops.GetLastTraceback
local InstancedAutocacher = iterators.InstancedAutocacher
local IsCallable = var_preds.IsCallable
local NoOp = func_ops.NoOp
local StoreTraceback = func_ops.StoreTraceback
local UnpackAndWipe = var_ops.UnpackAndWipe
local WipeRange = var_ops.WipeRange

-- Cached routines --
local _IsIterationDone_
local _Reset_
local _Wrap_

-- List of running extended coroutines --
local Running = table_ops.Weak("kv")

-- Coroutine wrappers --
local Wrappers = table_ops.Weak("k")

-- Cookies --
local _is_done = {}
local _reset = {}

--- An extended coroutine wrapper behaves like a function returned by <b>coroutine.wrap</b>,
-- though as a loop and not a one-shot call. Once the body has completed, it will "rewind"
-- and thus be back in its original state, excepting any side effects. It is also possible
-- to query if the body has just rewound.<br><br>
-- In addition, a coroutine created with this function can be reset, i.e. the body function
-- is explicitly rewound while active. To accommodate this, reset logic can be attached to
-- clean up any important state.
module "coroutine_ex"

--- Builds an instanced autocaching coroutine-based iterator.
-- @param func Iterator body.
-- @param on_reset Function called on reset; if <b>nil</b>, this is a no-op.
-- @return Instanced iterator.
-- @see Wrap
-- @see ~iterators.InstancedAutocacher
function Iterator (func, on_reset)
	return InstancedAutocacher(function()
		local args, count, is_clear

		local coro = _Wrap_(function()
			is_clear = true

			return func(UnpackAndWipe(args, count))
		end, on_reset)

		-- Body --
		return coro,

		-- Done --
		function()
			return _IsIterationDone_(coro)
		end,

		-- Setup --
		function(...)
			is_clear = false

			count, args = CollectArgsInto_IfAny(args, ...)
		end,

		-- Reclaim --
		function()
			if not is_clear then
				WipeRange(args, 1, count)
			end

			if not _IsIterationDone_(coro) then
				_Reset_(coro)
			end
		end
	end)
end

--- Queries a coroutine made by <b>Wrap</b> about whether its body just ended an iteration.
-- @param coro Wrapper for coroutine to query.
-- @return If true, the body finished, and the wrapper has not since been resumed or reset.
-- @see Wrap
function IsIterationDone (coro)
	assert(Wrappers[coro], "Argument was not made with Wrap")

	return coro(_is_done)
end

--- Resets a coroutine made by <b>Wrap</b>.<br><br>
-- If the coroutine is already reset, this is a no-op.
-- @param coro Optional wrapper for coroutine to reset; if absent, uses the running coroutine.
-- @param ... Reset arguments.
-- @see Wrap
function Reset (coro, ...)
	-- Figure out how to perform the reset. If the wrapper was specified or it corresponds
	-- to the running coroutine, the reset cookie is yielded to the wrapper. Otherwise, do
	-- a dummy resume with the cookie, which will fall through to the same logic.
	local running_coro = Running[running()]
	local is_suspended = coro and coro ~= running_coro
	local wrapper, call

	if is_suspended then
		wrapper, call = assert(Wrappers[coro] and coro, "Cannot reset argument not made with Wrap"), coro
	else
		wrapper, call = assert(running_coro, "Invalid reset"), yield
	end

	-- If it will have any effect, trigger the reset.
	if not wrapper(_is_done) then
		call(_reset, ...)
	end
end

--- Creates an extended coroutine, exposed by a wrapper function.
-- @param func Coroutine body.
-- @param on_reset Function called on reset; if <b>nil</b>, this is a no-op.<br><br>
-- Note that this will be executed in a protected call, within the context of the resetter.<br>
-- @return Wrapper function.
-- @see Reset
function Wrap (func, on_reset)
	on_reset = on_reset or NoOp

	-- Validate arguments and options.
	assert(IsCallable(func), "Uncallable producer")
	assert(IsCallable(on_reset), "Uncallable reset response")

	-- Wrapper loop
	local return_count, return_results = -1

	local function Func (func)
		while true do
			return_count, return_results = CollectArgsInto_IfAny(return_results, func(yield()))
		end
	end

	-- Handles a coroutine resume, propagating any error
	-- success: If true, resume was successful
	-- res_: First result of resume, or error message
	-- ...: Remaining resume results
	-- Returns: On success, any results
	local coro

	local function Resume (success, res_, ...)
		Running[coro] = nil

		-- On a reset, invalidate the coroutine and trigger any response.
		if res_ == _reset then
			coro = false

			success, res_ = pcall(on_reset, ...)

			coro = nil
		end

		-- Propagate any error.
		if not success then
			if coro then
				StoreTraceback(coro, res_, 2)

				res_ = GetLastTraceback(true)
			end

			error(res_, 3)

		-- Otherwise, return results if the body returned anything.
		elseif return_count > 0 then
			return UnpackAndWipe(return_results, return_count)

		-- Otherwise, return yield (or empty return) results if no reset occurred.
		elseif coro then
			return res_, ...
		end
	end

	-- Supply a wrapped coroutine.
	local function wrapper (arg_, ...)
		-- If queried, indicate whether the body finished an iteration and no resume /
		-- reset has since occurred.
		if arg_ == _is_done then
			return return_count >= 0
		end

		-- Validate the coroutine.
		assert(coro ~= false, "Cannot resume during reset")
		assert(not coro or status(coro) ~= "dead", "Dead coroutine")
		assert(not Running[coro], "Coroutine already running")

		-- On the first run or after / on a reset, build a fresh coroutine and put it into
		-- a ready-and-waiting state.
		return_count = -1

		if coro == nil or arg_ == _reset then
			coro = create(Func)

			resume(coro, func)

			-- On a forced reset, bypass running.
			if arg_ == _reset then
				return Resume(true, _reset, ...)
			end
		end

		-- Run the coroutine and return its results.
		Running[coro] = wrapper

		return Resume(resume(coro, arg_, ...))
	end

	-- Register and return the wrapper.
	Wrappers[wrapper] = true

	return wrapper
end

-- Cache some routines.
_IsIterationDone_ = IsIterationDone
_Reset_ = Reset
_Wrap_ = Wrap