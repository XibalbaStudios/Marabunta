-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- This class provides for posting tasks to a queue, after which they can be processed in
-- a batch later.<br><br>
-- Tasks are processed one by one in FIFO order. Additionally, a task can choose to remain
-- in the queue after being called, which can be useful e.g. to spread events across time.<br><br>
-- Class.
module TaskQueue
]]

-- Standard library imports --
local assert = assert
local insert = table.insert
local ipairs = ipairs
local newproxy = newproxy
local wrap = coroutine.wrap

-- Modules --
local coroutine_ex = require("coroutine_ex")
local func_ops = require("func_ops")
local iterators = require("iterators")
local table_ops = require("table_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local Args = iterators.Args
local AssertArg_Pred = var_ops.AssertArg_Pred
local Filter = table_ops.Filter
local IsCallable = var_preds.IsCallable
local Move_WithTable = table_ops.Move_WithTable
local Reverse = table_ops.Reverse
local Try = func_ops.Try
local Wrap = coroutine_ex.Wrap

-- Unique member keys --
local _fetch = {}
local _is_running = {}
local _tasks = {}

-- TaskQueue class definition --
class.Define("TaskQueue", function(TaskQueue)
	-- Cache of task batches --
	local Cache = cache_ops.TableCache()

	-- Task batching helper
	local function CollectAndValidate (op, ...)
		local t = Cache("pull")

		for _, v in op(...) do
			t[#t + 1] = AssertArg_Pred(IsCallable, v, "Uncallable task")
		end

		return t
	end

	do
		-- Helper to add batches of independent tasks
		local function Add (TQ, op, ...)
			local t = CollectAndValidate(op, ...)

			Move_WithTable(TQ[_fetch], t, "append")

			Cache(t)
		end

		--- Adds one or more independent tasks to the queue, in order.
		-- @param ... Tasks to add.
		function TaskQueue:Add (...)
			Add(self, Args, ...)
		end

		--- Array variant of <b>TaskQueue:Add</b>.
		-- @param array Array of tasks to add.
		-- @see TaskQueue:Add
		function TaskQueue:Add_Array (array)
			Add(self, ipairs, array)
		end
	end

	--- Adds a wrapped coroutine task to the queue.
	-- @param task Task to wrap and add.
	-- @param extended_ If false, the task uses <b>coroutine.wrap</b>; otherwise, <b>corourine_ex.Wrap<b>.
	-- In the latter case, if callable, this is passed as the <i>on_reset</i> parameter.
	-- @see ~coroutine_ex.Wrap
	function TaskQueue:AddWrapped (task, extended_)
		assert(IsCallable(task), "Uncallable task")

		if extended_ then
			insert(self[_fetch], Wrap(task, IsCallable(extended_) and extended_ or nil))
		else
			insert(self[_fetch], wrap(task))
		end
	end

	do
		-- Helper to add a set of tasks into a sequence state
		local function AuxAdd (TQ, state, t)
			local turn = state.count

			insert(TQ[_fetch], function(arg)
				if state.turn == turn then
					for i = #t, 1, -1 do
						if t[i](arg) ~= nil then
							return "keep"
						end

						t[i] = nil
					end

					state.turn = state.turn + 1

					Cache(t)
				else
					return "keep"
				end
			end)
		end

		-- Sequences a set of tasks, putting them in reverse order for easy unloading
		local function Sequence (op, ...)
			local t = CollectAndValidate(op, ...)

			Reverse(t)

			return t
		end

		-- Sequence states --
		local States = table_ops.Weak("k")

		-- Adds a set of tasks to a new sequence
		local function Add (TQ, op, ...)
			local t = Sequence(op, ...)
			local handle = newproxy()

			States[handle] = { count = 0, turn = 0 }

			AuxAdd(TQ, States[handle], t)

			return handle
		end

		--- Adds one or more dependent tasks to the queue, in order.<br><br>
		-- If one of these tasks returns <b>"keep"</b> during a run, it remains in the queue as
		-- expected, but none of the subsequent tasks from the sequence are processed (though
		-- they also remain in the queue).<br><br>
		-- Note for gathering: sequenced tasks do not retain their identity once in the queue.
		-- @param ... Tasks to add.
		-- @return Sequence handle.
		-- @see TaskQueue:__call
		-- @see TaskQueue:Gather
		function TaskQueue:AddSequence (...)
			return Add(self, Args, ...)
		end

		--- Array variant of <b>TaskQueue:AddSequence</b>.
		-- @param array Array of tasks to add.
		-- @return Sequence handle.
		-- @see TaskQueue:AddSequence
		function TaskQueue:AddSequence_Array (array)
			return Add(self, ipairs, array)
		end

		-- Adds a set of tasks to a pre-existing sequence.
		local function AddSplice (TQ, handle, op, ...)
			local state = assert(States[handle], "Invalid handle")
			local t = Sequence(op, ...)

			state.count = state.count + 1

			AuxAdd(TQ, state, t)
		end

		--- Adds one or more dependent tasks to the queue, in order.<br><br>
		-- These tasks will be spliced into the sequence identified by <i>handle</i>, and
		-- otherwise behave as per <b>TaskQueue:AddSequence</b>.<br><br>
		-- It is not necessary that the original sequence was added to this queue.
		-- @param handle A sequence handle returned by a previous call to <b>
		-- TaskQueue:AddSequence</b> or <b>TaskQueue:AddSequence_Array</b>.
		-- @param ... Tasks to add.
		-- @see TaskQueue:AddSequence
		-- @see TaskQueue:AddSequence_Array
		function TaskQueue:SpliceSequence (handle, ...)
			AddSplice(self, handle, Args, ...)
		end

		--- Array variant of <b>TaskQueue:SpliceSequence</b>.
		-- @param handle A sequence handle returned by a previous call to <b>
		-- TaskQueue:AddSequence</b> or <b>TaskQueue:AddSequence_Array</b>.
		-- @param array Array of tasks to add.
		-- @see TaskQueue:AddSequence
		-- @see TaskQueue:AddSequence_Array
		-- @see TaskQueue:SpliceSequence
		function TaskQueue:SpliceSequence_Array (handle, array)
			AddSplice(self, handle, ipairs, array)
		end
	end

	-- Queue visitor
	local function OnEach (task, arg)
		return task(arg) == "keep"
	end

	-- Protected run
	local function Run (TQ, arg)
		TQ[_is_running] = true

		-- Fetch recently added tasks.
		Move_WithTable(TQ[_tasks], TQ[_fetch], "append")

		-- Run the tasks; keep ones returning a valid result.
		Filter(TQ[_tasks], OnEach, arg, true)
	end

	-- Run cleanup
	local function RunDone (TQ)
		TQ[_is_running] = false
	end

	--- Metamethod.<br><br>
	-- Performs all pending tasks, in order. If a task returns <b>"keep"</b>, it remains
	-- in the queue afterward, in its same position.<br><br>
	-- New tasks can be added during the run, but will not be processed until the next one.
	-- @param arg Argument passed to each task.
	function TaskQueue:__call (arg)
		assert(not self[_is_running], "Queue already running")

		Try(Run, RunDone, self, arg)
	end

	--- Removes all tasks in the queue.
	function TaskQueue:Clear ()
		assert(not self[_is_running], "Clear forbidden during run")

		self[_fetch] = {}
		self[_tasks] = {}
	end

	--- Gathers all the tasks still in the queue, in order.
	-- @return Task array.
	function TaskQueue:Gather ()
		local t = {}

		for _, set in Args(self[_tasks], self[_fetch]) do
			for _, task in ipairs(set) do
				t[#t + 1] = task
			end
		end

		return t
	end

	--- Metamethod.
	-- @return Task count.
	function TaskQueue:__len ()
		return #self[_tasks] + #self[_fetch]
	end

	--- Class constructor.
	function TaskQueue:__cons ()
		self:Clear()
	end
end)