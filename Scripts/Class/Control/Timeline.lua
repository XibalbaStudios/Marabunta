-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A timeline can be used to schedule one or more events to go off at certain points in
-- time. In addition to updating regularly, the current time can be rewound or advanced
-- manually.<br><br>
-- Class.
module Timeline
]]

-- Standard library imports --
local assert = assert
local insert = table.insert
local ipairs = ipairs
local sort = table.sort

-- Modules --
local func_ops = require("func_ops")
local table_ops = require("table_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local AssertArg_Pred = var_ops.AssertArg_Pred
local DeepCopy = table_ops.DeepCopy
local IsCallable = var_preds.IsCallable
local IsNonNegative_Number = var_preds.IsNonNegative_Number
local Move_WithTable = table_ops.Move_WithTable
local Try = func_ops.Try

-- Unique member keys --
local _events = {}
local _fetch = {}
local _is_updating = {}
local _queue = {}
local _time = {}

-- Timeline class definition --
class.Define("Timeline", function(Timeline)
	--- Adds an event to the timeline.<br><br>
	-- Events are placed in a fetch list, and thus will not take effect during an update.
	-- @param when Time when event occurs.
	-- @param event Event function, which is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>event(when, arg)</b></i>,<br><br>
	-- where <i>when</i> matches the event time and <i>arg</i> is the argument to <b>
	-- Timeline:__call</b>.
	-- @see Timeline:__call
	function Timeline:Add (when, event)
		local event_to_add = {}

		event_to_add.when = AssertArg_Pred(IsNonNegative_Number, when, "Invalid time")
		event_to_add.event = AssertArg_Pred(IsCallable, event, "Uncallable event")

		insert(self[_fetch], event_to_add)
	end

	-- Returns: If true, event1 is later than event2
	local function EventCompare (event1, event2)
		return event1.when > event2.when
	end

	-- Enqueues future events
	local function BuildQueue (T)
		local begin = T[_time]
		local queue = {}

		for i, event in ipairs(T[_events]) do
			if event.when < begin then
				break
			end

			queue[i] = event
		end

		T[_queue] = queue
	end

	-- Protected update
	local function Update (T, step, arg)
		T[_is_updating] = true

		-- Merge in any new events.
		if #T[_fetch] > 0 then
			sort(Move_WithTable(T[_events], T[_fetch], "append"), EventCompare)

			-- Rebuild the queue with the new events.
			BuildQueue(T)
		end

		-- Issue all events, in order. The queue is reacquired on each pass, since events
		-- may rebuild it via gotos.
		while true do
			local after = T[_time] + step
			local queue = T[_queue]

			-- Acquire the next event. If there is none or it comes too late, quit.
			local event = queue[#queue]

			if not event or event.when >= after then
				break
			end

			local when = event.when

			-- Advance the time to the event and diminish the time step.
			T[_time] = when

			step = after - when

			-- Issue the event and move on to the next one.
			event.func(when, arg)

			queue[#queue] = nil
		end

		-- Issue the final time advancement.
		T[_time] = T[_time] + step
	end

	-- Update cleanup
	local function UpdateDone (T)
		T[_is_updating] = false
	end

	--- Metamethod.<br><br>
	-- Updates the timeline, issuing in order any events scheduled during the step.<br><br>
	-- Before the update, any events in the fetch list are first merged into the event
	-- list.<br><br>
	-- If an event calls <b>Timeline:GoTo</b> on this timeline, updating will resume
	-- at the new time and 
	-- @param step Time step.
	-- @param arg Argument to event functions.
	-- @see Timeline:GoTo
	function Timeline:__call (step, arg)
		assert(not self[_is_updating], "Timeline already updating")

		Try(Update, UpdateDone, self, step, arg)
	end

	--- Clears the timeline's fetch and event lists.<br><br>
	-- It is an error to call this during an update.
	function Timeline:Clear ()
		assert(not self[_is_updating], "Clear forbidden during update")

		self[_events] = {}
		self[_fetch] = {}
		self[_queue] = {}
	end

	---
	-- @return Current time.
	function Timeline:GetTime ()
		return self[_time]
	end

	--- Sets the timeline to a given time.
	-- @param when Time to assign.
	-- @see Timeline:GetTime
	function Timeline:GoTo (when)
		self[_time] = AssertArg_Pred(IsNonNegative_Number, when, "Invalid time")

		BuildQueue(self)
	end

	--- Metamethod.
	-- @return Event count.
	function Timeline:__len ()
		return #self[_events] + #self[_fetch]
	end

	--- Class constructor.
	function Timeline:__cons ()
		self[_time] = 0

		self:Clear()
	end

	--- Class clone body.
	function Timeline:__clone (T)
		self[_events] = DeepCopy(T[_events])
		self[_fetch] = DeepCopy(T[_fetch])
		self[_is_updating] = T[_is_updating]
		self[_time] = T[_time]

		BuildQueue(self)
	end
end)