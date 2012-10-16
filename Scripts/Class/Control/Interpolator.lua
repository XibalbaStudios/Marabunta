-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- An interpolator provides some helpful apparatus for tweening.<br><br>
-- Class.
module Interpolator
]]

-- Standard library imports --
local assert = assert

-- Modules --
local class = require("class")
local func_ops = require("func_ops")
local var_preds = require("var_preds")

-- Imports --
local Identity = func_ops.Identity
local IsPositive_Number = var_preds.IsPositive_Number
local New = class.New

-- Resume commands --
local Commands = table_ops.MakeSet{ "continue", "flip", "forward", "reverse" }

-- Unique member keys --
local _context = {}
local _interp = {}
local _is_decreasing = {}
local _map = {}
local _mode = {}
local _t = {}
local _target1 = {}
local _target2 = {}
local _timer = {}

-- Interpolator class definition --
class.Define("Interpolator", function(Interpolator)
	-- Common body for mode logic
	-- Returns: Interpolation time
	local function Body (I, lapse, is_done)
		local t

		-- Disable interpolation if complete.
		if is_done then
			t = 1

			I[_mode] = nil

			-- Suspend the timer.
			I[_timer]:SetPause(true)

		-- Otherwise, update the time properties.
		else
			t = I[_timer]:GetCounter(true)

			I[_timer]:Update(lapse)
		end

		-- Supply the time, flipping if decreasing.
		return I[_is_decreasing] and 1 - t or t
	end

	-- Oscillation reversal helper
	-- count: Timeout count
	local function DoAnyFlip (I, count)
		if count % 2 == 1 then
			I[_is_decreasing] = not I[_is_decreasing]
		end
	end

	-- Interpolation mode logic --
	local Modes = {}

	-- 0-to-1 and finish --
	function Modes:once (lapse, count)
		return Body(self, lapse, count > 0)
	end

	-- 0-to-1, 1-to-0, and repeat --
	function Modes:oscillate (lapse, count)
		DoAnyFlip(self, count)

		return Body(self, lapse)
	end

	-- 0-to-1, 1-to-0, and finish --
	function Modes:oscillate_once (lapse, count)
		local is_decreasing = self[_is_decreasing]

		DoAnyFlip(self, count)

		return Body(self, lapse, (is_decreasing and 1 or 0) + count >= 2)
	end

	-- Current time --
	function Modes:suspended ()
		return self[_t]
	end

	-- Performs an interpolation
	local function Interpolate (I, lapse)
		-- Find the time in the current mode. This also updates the decreasing boolean.
		I[_t] = Modes[I[_mode] or "suspended"](I, lapse, I[_timer]:Check("continue"))

		-- If a mapping exists, apply it to the current time and use the new result.
		local t = (I[_map] or Identity)(I[_t], I[_is_decreasing])

		-- Perform the interpolation.
		I[_interp](t, I[_target1], I[_target2], I[_context])
	end

	--- Metamethod.<br><br>
	-- Updates the interpolation. If it finishes, the interpolator goes into suspended mode.
	-- @param step Time step.
	function Interpolator:__call (step)
		Interpolate(self, step)
	end

	--- Gets the current interpolation mode.<br><br>
	-- Note that the times mentioned for the "do once" options are reversed if the time is
	-- decreasing.
	-- @return Current interpolation mode, which will be one of the following:<br><br>
	-- &nbsp&nbsp- <b>"once"</b>: interpolates from time 0 to 1 and finishes.<br>
	-- &nbsp&nbsp- <b>"oscillate"</b>: ping-pongs between time 0 and 1 continuously.</b><br>
	-- &nbsp&nbsp- <b>"oscillate_once"</b>: interpolates once from 0 to 1 and back.</b><br>
	-- &nbsp&nbsp- <b>"suspended"</b>: time stays fixed.
	function Interpolator:GetMode ()
		return self[_mode] or "suspended"
	end

	--- Gets the current interpolation state.
	-- @return Interpolation time, in [0, 1].
	-- @return If true, the time is decreasing.
	function Interpolator:GetState ()
		return self[_t], not not self[_is_decreasing]
	end

	--- Runs, from 0, to a given time.
	-- @param t Interpolation time. The final time will be in [0, 1].
	function Interpolator:RunTo (t)
		-- Reset interpolation data.
		self[_is_decreasing] = nil

		-- Find the initial value.
		self[_timer]:SetCounter(t, true)

		Interpolate(self, 0)
	end

	---
	-- @param context User-defined context.
	-- @see Interpolator:SetTargets
	function Interpolator:SetContext (context)
		self[_context] = context
	end

	--- Sets the duration needed to interpolate from t = 0 to t = 1 (or vice versa).
	-- @param duration Duration to assign.
	function Interpolator:SetDuration (duration)
		assert(IsPositive_Number(duration), "Invalid duration")

		-- Set up a new duration, mapping the counter into it. Restore the pause state.
		local is_paused = self[_timer]:IsPaused()

		self[_timer]:Start(duration, self[_t] * duration)
		self[_timer]:SetPause(is_paused)
	end

	--- Sets the time mapping, to be applied during interpolation.<br><br>
	-- When no map is assigned, the raw time and interpolation time are the same.
	-- @param map Map to assign, or <b>nil</b> to remove any mapping.<br><br>
	-- A valid mapping function has signature<br><br>
	-- &nbsp&nbsp&nbsp<i><b>map(t, is_decreasing)</b></i>,<br><br>
	-- where <i>t</i> is the raw interpolation time in [0, 1], and <i>is_decreasing</i>
	-- is true if the time is decreasing. This function must return a new time, also
	-- in [0, 1].
	function Interpolator:SetMap (map)
		self[_map] = map
	end

	---
	-- @param target1 User-defined interpolation target #1.
	-- @param target2 User-defined interpolation target #2.
	-- @see Interpolator:SetContext
	function Interpolator:SetTargets (target1, target2)
		self[_target1] = target1
		self[_target2] = target2
	end

	--- Starts an interpolation.<br><br>
	-- The interpolator must have first been assigned a duration.
	-- @param mode Interpolation mode, as per <b>Interpolator:GetMode</b>.
	-- @param how Resume command.<br><br>
	-- If this is <b>nil</b>, the interpolator is reset, i.e. the interpolation time is
	-- set to 0 and increasing.<br><br>
	-- If this is <b>"flip"</b>, the flow of time is reversed, preserving the current
	-- time.<br><br>
	-- If this is <b>"forward"</b> or <b>"reverse"</b>, the flow of time is set as
	-- increasing or decreasing, respectively, preserving the current time.<br><br>
	-- Finally, if this is <b>"continue"</b>, the interpolation proceeds as it was when
	-- it was created or stopped.
	-- @see Interpolator:GetMode
	-- @see Interpolator:SetDuration
	-- @see Interpolator:Stop
	-- @see Interpolator:__cons
	function Interpolator:Start (mode, how)
		assert(mode ~= nil and mode ~= "suspended" and Modes[mode], "Invalid mode")
		assert(how == nil or Commands[how], "Bad command")

		-- Given no resume commands, reset the interpolator.
		if how == nil then
			self[_t] = 0
			self[_is_decreasing] = false

		-- Otherwise, apply the appropriate resume command.
		elseif how == "flip" then
			self[_is_decreasing] = not self[_is_decreasing]
		elseif how ~= "continue" then
			self[_is_decreasing] = how == "reverse"
		end

		-- Set the interpolation timer.
		self[_timer]:SetCounter(self[_is_decreasing] and 1 - self[_t] or self[_t], true)
		self[_timer]:SetPause(false)

		-- Get the initial value.
		self[_mode] = mode

		Interpolate(self, 0)
	end

	--- Stops the interpolation, placing it in suspended mode.
	-- @param reset If true, the interpolation time is set to 0 and the decreasing flag is
	-- cleared.
	-- @see Interpolator:GetMode
	-- @see Interpolator:GetState
	-- @see Interpolator:Start
	function Interpolator:Stop (reset)
		self[_mode] = nil

		-- On reset, clear state.
		if reset then
			self[_t] = 0
			self[_is_decreasing] = false

			self[_timer]:SetPause(true)
		end
	end

	--- Class constructor.<br><br>
	-- An interpolator begins in suspended mode at time = 0 and with no mapping.
	-- @param interp Interpolate function, which will perform some action, given the current
	-- time. A valid interpolation function has signature<br><br>
	-- &nbsp&nbsp&nbsp<i><b>interp(t, target1, target2, context)</b></i>,<br><br>
	-- where <i>t</i> is the current (mapped) interpolation time, in [0, 1], and the remaining
	-- parameters will take whatever has been assigned as the current targets and context.<br><br>
	-- @param duration Duration to interpolate from t = 0 to t = 1 (or vice versa), or <b>nil</b>
	-- to forgo setting it.
	-- @param target1 Optional user-defined interpolation target.
	-- @param target2 Optional user-defined interpolation target.
	-- @param context Optional user-defined context.
	-- @see Interpolator:SetContext
	-- @see Interpolator:SetDuration
	-- @see Interpolator:SetTargets
	function Interpolator:__cons (interp, duration, target1, target2, context)
		self[_interp] = interp
		self[_timer] = New("Timer")

		self:SetContext(context)
		self:SetTargets(target1, target2)
		self:Stop(true)

		-- Set up any default duration.
		if duration then
			self:SetDuration(duration)
		end
	end
end)