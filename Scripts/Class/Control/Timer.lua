-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- Instances of this class can be used to check manually whether a timeout has elapsed,
-- either once or periodically.<br><br>
-- Class.
module Timer
]]

-- Standard library imports --
local assert = assert
local modf = math.modf

-- Modules --
local func_ops = require("func_ops")
local var_preds = require("var_preds")

-- Imports --
local IsNonNegative_Number = var_preds.IsNonNegative_Number
local IsPositive_Number = var_preds.IsPositive_Number
local NoOp = func_ops.NoOp

-- Unique member keys --
local _counter = {}
local _duration = {}
local _is_paused = {}
local _offset = {}

-- Timer class definition --
class.Define("Timer", function(Timer)
	--- Checks the timer for timeouts.<br><br>
	-- The counter is divided by the timeout duration. The integer part of this is the
	-- timeout count, and the fraction is the new counter. If the count is greater than
	-- 0, the timer will respond according to the <i>how</i> parameter.
	-- @param how Timeout response.<br><br>
	-- If this is <b>"continue"</b>, all timeouts are reported and the timer continues to
	-- run.<br><br>
	-- If this is <b>"pause"</b>, one timeout is reported, the counter is set to 0, and the
	-- timer is paused.<br><br>
	-- Otherwise, one timeout is reported and the timer is stopped.
	-- @return Timeout count, or 0 if the timer is stopped.
	-- @see Timer:Update
	function Timer:Check (how)
		local count = 0
		local duration = self[_duration]
		local slice

		if duration and not self[_is_paused] and self[_counter] >= duration then
			if how == "continue" then
				count, slice = modf(self[_counter] / duration)

				self[_counter] = slice * duration

			elseif how == "pause" then
				count = 1
				
				self[_counter] = 0
				self[_is_paused] = true

			else
				count = 1

				self[_duration] = nil
			end

			self[_offset] = self[_counter]
		end

		return count
	end

	--- Gets the counter, accumulated during updates.
	-- @param is_fraction If true, the counter is reported as a fraction of the timeout duration.
	-- @return Counter, or 0 if the timer is stopped.
	-- @see Timer:SetCounter
	-- @see Timer:Update
	function Timer:GetCounter (is_fraction)
		local duration = self[_duration]
		local counter

		if duration then
			counter = self[_counter]

			if is_fraction then
				counter = counter / duration
			end
		end

		return counter or 0
	end

	---
	-- @return Timeout duration, or <b>nil</b> if the timer is stopped. 
	function Timer:GetDuration ()
		return self[_duration]
	end

	---
	-- @return If true, the timer is paused.
	-- @see Timer:SetPause
	function Timer:IsPaused ()
		return self[_is_paused]
	end

	--- Sets the counter directly.<br><br>
	-- <b>WithTimeouts</b> will interpret this as the time of the last check.
	-- @param counter Counter to assign.
	-- @param is_fraction If true, the counter is interpreted as a fraction of the timeout
	-- duration.
	-- @see Timer:WithTimeouts
	function Timer:SetCounter (counter, is_fraction)
		assert(IsNonNegative_Number(counter), "Invalid counter")

		local duration = assert(self[_duration], "Timer not running")

		if is_fraction then
			counter = counter * duration
		end

		self[_counter] = counter
		self[_offset] = counter % duration
	end

	--- Pauses or resumes the timer.
	-- @param pause If true, pause the timer.
	-- @see Timer:IsPaused
	function Timer:SetPause (pause)
		self[_is_paused] = not not pause
	end

	--- Starts the timer.
	-- @param duration Timeout duration.
	-- @param t Start counter, or 0 if absent.
	-- @see Timer:Stop
	function Timer:Start (duration, t)
		assert(IsPositive_Number(duration), "Invalid duration")
		assert(t == nil or IsNonNegative_Number(t), "Invalid start time")

		self[_duration] = duration
		self[_is_paused] = false

		self:SetCounter(t or 0)
	end

	--- Stops the timer.
	-- @see Timer:Start
	function Timer:Stop ()
		self[_duration] = nil
	end

	--- Advances the counter.<br><br>
	-- If the timer is stopped or paused, this is a no-op.
	-- @param step Time step.
	-- @see Timer:Check
	-- @see Timer:GetCounter
	function Timer:Update (step)
		if self[_duration] and not self[_is_paused] then
			self[_counter] = self[_counter] + step
		end
	end

	--- Instanced iterator over timeouts.<br><br>
	-- First, this checks the timer (allowing for multiple timeouts).<br><br>
	-- For each timeout that occurred, it reports the current state.<br><br>
	-- Optionally, it will report the final state.
	-- @class function
	-- @name Timer:WithTimeouts
	-- @param with_final If true, conclude with an extra iteration for the end result. The
	-- index of this step will be <b>"final"</b>.
	-- @return Instanced iterator, which returns the following, in order, at each iteration:<br><br>
	-- &nbsp&nbsp- Current iteration index.<br>
	-- &nbsp&nbsp- Timeout count.<br>
	-- &nbsp&nbsp- Time difference from last timeout or last check to this timeout (or final
	-- state).<br>
	-- &nbsp&nbsp- Current tally of time elapsed from last check, including current time
	-- difference.<br>
	-- &nbsp&nbsp- Total time, accrued in updates since last check.
	-- @see Timer:Check
	-- @see ~iterators.InstancedAutocacher
	Timer.WithTimeouts = iterators.InstancedAutocacher(function()
		local count, counter, dt, duration, offset, tally, total

		-- Body --
		return function(_, i)
			local index = i + 1
			local cur_dt = dt

			tally = tally + dt
			dt = index < count and duration or counter

			return index <= count and index or "final", count, cur_dt, tally, total
		end,

		-- Done --
		rawequal,

		-- Setup --
		function(T, with_final)
			duration = T[_duration]

			if duration then
				count = T:Check("continue")
				counter = T[_counter]
				offset = T[_offset]
				tally = 0
				total = count * duration + counter - offset

				if total > 0 then
					dt = (count > 0 and duration or counter) - offset

					return with_final and "final" or count, 0
				end
			end
		end,

		-- Reclaim --
		NoOp
	end)

	--- Class constructor.<br><br>
	-- The timer begins as stopped and unpaused.
	function Timer:__cons ()
		self[_is_paused] = false
	end

	--- Class clone body.
	function Timer:__clone (T)
		self[_counter] = T[_counter]
		self[_duration] = T[_duration]
		self[_is_paused] = T[_is_paused]
		self[_offset] = T[_offset]
	end
end)