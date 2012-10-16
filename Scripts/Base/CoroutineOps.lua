-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local max = math.max
local min = math.min
local running = coroutine.running
local yield = coroutine.yield

-- Modules --
local func_ops = require("func_ops")
local table_ops = require("table_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local AssertArg_Pred = var_ops.AssertArg_Pred
local Call = func_ops.Call
local GetTimeLapseFunc = func_ops.GetTimeLapseFunc
local HasField = var_preds.HasField
local IsCallableOrNil = var_preds.IsCallableOrNil
local NoOp = func_ops.NoOp
local Weak = table_ops.Weak

-- Cached routines --
local _Body_
local _Body_Timed_

--- This module defines some control-flow operations for use inside coroutines, as well
-- as some support for events that can be tailored to their host coroutine.
module "coroutine_ops"

do
	-- Builds the part common to all argument counts
	local function GetListAndSetter ()
		local funcs = Weak("k")

		local function setter (func)
			if func ~= "exists" then
				funcs[running()] = AssertArg_Pred(IsCallableOrNil, func, "Uncallable function")
			else
				return not not funcs[running()]
			end
		end

		return funcs, setter
	end

	--- Builds a function that can assume different behavior for each coroutine.
	-- @return Function which takes a single argument and passes it to the logic registered
	-- for the current coroutine, returning any results. If no behavior is assigned, or this
	-- is called from outside any coroutine, this is a no-op.
	-- @return Setter function, which must be called within a coroutine. The function
	-- passed as its argument is assigned as the coroutine's behavior; it may be cleared
	-- by passing <b>nil</b>.<br><br>
	-- It is also possible to pass <b>"exists"</b> as argument, which will return true if a
	-- function is assigned to the current coroutine.
	function PerCoroutineFunc ()
		local funcs, setter = GetListAndSetter()

		return function(arg)
			return (funcs[running()] or NoOp)(arg)
		end, setter
	end

	--- Multiple-argument variant of <b>PerCoroutineFunc</b>.
	-- @return Function which takes multiple arguments and passes them to the logic registered
	-- for the current coroutine, returning any results. If no behavior is assigned, or this
	-- is called from outside any coroutine, this is a no-op.
	-- @return Setter function, as per <b>PerCoroutineFunc</b>.
	-- @see PerCoroutineFunc
	function PerCoroutineFunc_Multi ()
		local funcs, setter = GetListAndSetter()

		return function(...)
			return (funcs[running()] or NoOp)(...)
		end, setter
	end
end

-- Helper to process config info
local function Process (config)
	return config.yvalue == nil and "keep" or config.yvalue, not config.negate_done, config.use_time
end

--- Body for control-flow operations.<br><br>
-- Once invoked, this will spin on a test / update loop until told to terminate. On each
-- iteration, if it did not terminate, it will yield.
-- @param update Update logic, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>update(arg1, arg2, arg3)</b></i>.<br><br>
-- Called after <i>done</i>. If <b>nil</b>, this is a no-op.<br><br>
-- This may return <b>"done"</b> to terminate early.<br><br>
-- @param done Test, with same signature as <i>update</i>, called on each iteration. If it
-- resolves to true, the loop terminates.
-- @param config Table of configuration parameters.<br><br>
-- If the <b>negate_done</b> field is true, the result from <i>done</i> is negated, i.e.
-- instead of "until test passes" the loop is interpreted as "while test passes", and vice
-- versa.<br><br>
-- If a <b>yvalue</b> field is present, this value is yielded after each iteration. If
-- absent, this defaults to <b>"keep"</b>, as a convenience for coroutine-based <a href=
-- "TaskQueue.html">tasks</a>.<br><br>
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return If true, operation completed normally, i.e. <i>done</i> resolved true.
function Body (update, done, config, arg1, arg2, arg3)
	update = update or NoOp

	local yvalue, test_done = Process(config)

	while true do
		local is_done = not done(arg1, arg2, arg3) ~= test_done

		-- Update any user-defined logic, quitting on an early exit or if already done.
		if is_done or update(arg1, arg2, arg3) == "done" then
			return is_done
		end

		-- Yield, using any provided value.
		yield(yvalue)
	end
end

-- Helper to constrain lapses
local function Clamp (alapse, lapse)
	return max(0, min(alapse, lapse))
end

--- Timed variant of <b>Body</b>.<br><br>
-- This asks for the time lapse function under category <b>"coroutine_ops"</b>, <i>lapse_func
-- </i>, and starts a time counter, <i>time</i>, off at 0. On each iteration, <i>lapse_func</i>
-- is polled for a time lapse. If the operation has not yet concluded, this lapse is added to
-- <i>time</i>, after the test / update and before yielding.<br><br>
-- The time lapse is deducted from <i>lapse_func</i>'s "time bank" on each iteration, before
-- yielding or returning. This deduction can be reduced on the last iteration, q.v. <i>update
-- </i> and <i>done</i>, when the operation takes less than the full time lapse to conclude.<br><br>
-- Since no unit of time is enforced, it is up to users of this function or others built on
-- it to ensure its agreement with the time lapse function.
-- @param update As per <b>Body</b>, but called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>update(time, lapse, arg1, arg2, arg3)</b></i>.<br><br>
-- If it returns <b>"done"</b>, the second return value is also considered. This indicates
-- how much of the time lapse actually passed before the update terminated, clamped to [0,
-- time lapse], defaulting to the full time lapse if false.<br><br>
-- @param done Test called on each iteration. If it resolves to true, the loop is ready to
-- terminate.<br><br>
-- If that is the case, the second return value is also considered, as per <i>update</i>,
-- but defaulting to 0, i.e. the loop terminated instantly. If greater than 0, <i>update</i>
-- will still be called, using this narrowed time lapse.<br><br>
-- @param config As per <b>Body</b>, though a <b>use_time</b> field is also examined. If
-- this is true, <i>done</i> has the same signature as <i>update</i>; otherwise, it takes
-- only the three arguments.
-- @param arg1 Argument #1.
-- @param arg2 Argument #2.
-- @param arg3 Argument #3.
-- @return If true, operation concluded normally.
-- @see Body, ~func_ops.GetTimeLapseFunc
function Body_Timed (update, done, config, arg1, arg2, arg3)
	update = update or NoOp

	local yvalue, test_done, use_time = Process(config)
	local lapse_func, deduct = GetTimeLapseFunc("coroutine_ops")
	local time = 0

	while true do
		local lapse = lapse_func()

		--
		local done_result, alapse_done

		if use_time then
			done_result, alapse_done = done(time, lapse, arg1, arg2, arg3)
		else
			done_result = done(arg1, arg2, arg3)
		end

		local is_done = not done_result ~= test_done

		-- If the done logic worked, the loop is ready to terminate. In this case, find
		-- out how much time passed on this iteration, erring toward none.
		alapse_done = is_done and Clamp(alapse_done or 0, lapse)

		-- If the loop is not ready to terminate, or it is but it took some time, update
		-- any user-defined logic with however much time is now available. If there was an
		-- early exit there, find out how much of this time passed, erring toward all of it.
		local elapse_result, alapse_update

		if not is_done or alapse_done > 0 then
			elapse_result, alapse_update = update(time, alapse_done or lapse, arg1, arg2, arg3)

			alapse_update = elapse_result == "done" and Clamp(alapse_update or lapse, alapse_done or lapse)
		end

		-- Deduct however much time passed on this iteration from the store. If ready, quit.
		if is_done or elapse_result == "done" then
			deduct(alapse_update or alapse_done)

			return elapse_result ~= "done"
		else
			deduct(lapse)
		end

		time = time + lapse

		-- Yield, using any provided value.
		yield(yvalue)
	end
end

do
	-- Wait config --
	local Config = { use_time = true }

	-- Wait helper
	local function AuxWait (time, lapse, duration)
		return time + lapse >= duration, duration - time
	end

	--- Waits for some time to pass.<br><br>
	-- Built on top of <b>Body_Timed</b>.
	-- @param duration Time to wait.
	-- @param update Optional update logic, called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>update(time, duration, arg)</b></i>,<br><br>
	-- with <i>time</i> as per <b>Body_Timed</b>.<br><br>
	-- @param arg Argument.
	-- @param yvalue Optional value to yield.
	-- @return If true, the wait completed.
	-- @see Body_Timed
	function Wait (duration, update, arg, yvalue)
		Config.yvalue = yvalue

		return _Body_Timed_(update, AuxWait, Config, duration, arg)
	end
end

do
	-- WaitForMultipleSignals* config --
	local Config = {}

	-- Signal predicates --
	local Predicates = {
		-- All signals set --
		all = var_preds.All,

		-- Some signals set --
		any = var_preds.Any,

		-- No signal set --
		none = var_preds.All
	}

	-- Config setup helper
	local function Setup (config, pred)
		config.negate_done = pred == "none"

		return assert(Predicates[pred], "Invalid predicate")
	end

	--- Waits for a group of signals to reach a certain state.<br><br>
	-- Built on top of <b>Body</b>.
	-- @param signals Callable or read-indexable signal object. For i = 1 to <i>count</i>,
	-- the corresponding test is performed: <i>signals</i>(i) or <i>signals</i>[i].<br><br>
	-- A test passes if the return or lookup result is true.
	-- @param count Signal count.
	-- @param pred Predicate name, which may be any of the following:<br><br>
	-- &nbsp&nbsp- <b>"all"</b>: All tests must pass.<br><br>
	-- &nbsp&nbsp- <b>"any"</b>: At least one test must pass.<br><br>
	-- &nbsp&nbsp- <b>"none"</b>: No test may pass.<br><br>
	-- @param update Optional update logic, called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>update(signals, count, arg)</b></i>.<br><br>
	-- @param arg Argument.
	-- @param yvalue Optional value to yield.
	-- @return If true, the signals satisfied the predicate.
	-- @see Body, ~var_ops.All, ~var_ops.Any
	function WaitForMultipleSignals (signals, count, pred, update, arg, yvalue)
		local pred_op = Setup(Config, pred)

		return _Body_(update, pred_op, Config, signals, count, arg)
	end

	--- Timed variant of <b>WaitForMultipleSignals</b>, built on top of <b>Body_Timed</b>.
	-- @param signals Callable or read-indexable signal object.
	-- @param count Signal count.
	-- @param pred Predicate name, as per <b>WaitForMultipleSignals</b>.
	-- @param update Optional update logic, called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>update(time, signals, count, arg)</b></i>,<br><br>
	-- with <i>time</i> as per <b>Body_Timed</b>.<br><br>
	-- @param arg Argument.
	-- @param yvalue Optional value to yield.
	-- @return If true, the signals satisfied the predicate.
	-- @see Body_Timed, WaitForMultipleSignals
	function WaitForMultipleSignals_Timed (signals, count, pred, update, arg, yvalue)
		local pred_op = Setup(Config, pred)

		return _Body_Timed_(update, pred_op, Config, signals, count, arg)
	end
end

do
	-- WaitForSignal* config --
	local Config = {}

	-- Gets operation according to signals type
	local function GetOp (signals)
		return IsCallable(signals) and Call or HasField
	end

	--- Waits for a single signal to fire.<br><br>
	-- Built on top of <b>Body</b>.
	-- @param signals Callable or read-indexable signal object. A signal has fired if
	-- <i>signals</i>(<i>what</i>) or <i>signals</i>[<i>what</i>] is true.
	-- @param what Signal to watch.
	-- @param update Optional update logic, called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>update(signals, what, arg)</b></i>.<br><br>
	-- @param arg Argument.
	-- @param yvalue Optional value to yield.
	-- @return If true, the signal fired.
	-- @see Body
	function WaitForSignal (signals, what, update, arg, yvalue)
		Config.yvalue = yvalue

		return _Body_(update, GetOp(signals), Config, signals, what, arg)
	end

	--- Timed variant of <b>WaitForSignal</b>, built on top of <b>Body_Timed</b>.
	-- @param signals Callable or read-indexable signal object.
	-- @param what Signal to watch.
	-- @param update Optional update logic, called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>update(time, signals, what, arg)</b></i>,<br><br>
	-- with <i>time</i> as per <b>Body_Timed</b>.<br><br>
	-- @param arg Argument.
	-- @param yvalue Optional value to yield.
	-- @return If true, the signal fired.
	-- @see Body_Timed, WaitForSignal
	function WaitForSignal_Timed (signals, what, update, arg, yvalue)
		Config.yvalue = yvalue

		return _Body_Timed_(update, GetOp(signals), Config, signals, what, arg)
	end
end

do
	-- Helper to build ops that wait against a test
	local function WaitPair (what, config)
		_M["Wait" .. what] = function(test, update, arg, yvalue)
			config.yvalue = yvalue

			return _Body_(update, test, config, arg)
		end

		_M["Wait" .. what .. "_Timed"] = function(test, update, arg, use_time, yvalue)
			config.yvalue = yvalue
			config.use_time = not not use_time

			return _Body_Timed_(update, test, config, arg)
		end
	end

	--- Waits for a test to pass.<br><br>
	-- Built on top of <b>Body</b>.
	-- @class function
	-- @name WaitUntil
	-- @param test Test function, with the same signature as <i>update</i>. If it returns
	-- true, the wait terminates.
	-- @param update Optional update logic, called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>update(arg)</b></i>.<br><br>
	-- @param arg Argument.
	-- @param yvalue Optional value to yield.
	-- @return If true, the test passed.
	-- @see Body

	--- Timed variant of <b>WaitUntil</b>, built on top of <b>Body_Timed</b>.
	-- @class function
	-- @name WaitUntil_Timed
	-- @param test Test function. If it returns true, the wait terminates.
	-- @param update Optional update logic, called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>update(time, arg)</b></i>,<br><br>
	-- with <i>time</i> as per <b>Body_Timed</b>.<br><br>
	-- @param arg Argument.
	-- @param use_time If true, <i>test</i> has the same signature as <i>update</i>.
	-- Otherwise, the <i>time</i> argument is omitted.
	-- @param yvalue Optional value to yield.
	-- @return If true, the test passed.
	-- @see Body_Timed, WaitUntil

	WaitPair("Until", {})

	--- Waits for a test to fail.<br><br>
	-- Built on top of <b>Body</b>.
	-- @class function
	-- @name WaitWhile
	-- @param test Test function, with the same signature as <i>update</i>. If it returns
	-- false, the wait terminates.
	-- @param update Optional update logic, called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>update(arg)</b></i>.<br><br>
	-- @param arg Argument.
	-- @param yvalue Optional value to yield.
	-- @return If true, the test failed.
	-- @see Body

	--- Timed variant of <b>WaitWhile</b>, built on top of <b>Body_Timed</b>.
	-- @class function
	-- @name WaitWhile_Timed
	-- @param test Test function. If it returns false, the wait terminates.
	-- @param update Optional update logic, called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>update(time, arg)</b></i>,<br><br>
	-- with <i>time</i> as per <b>Body_Timed</b>.<br><br>
	-- @param arg Argument.
	-- @param use_time If true, <i>test</i> has the same signature as <i>update</i>.
	-- Otherwise, the <i>time</i> argument is omitted.
	-- @param yvalue Optional value to yield.
	-- @return If true, the test failed.
	-- @see Body_Timed, WaitWhile

	WaitPair("While", { negate_done = true })
end

-- Cache some routines.
_Body_ = Body
_Body_Timed_ = Body_Timed