-- Standard library imports --
local format = string.format
local setmetatable = setmetatable

-- Modules --
local em = require("entity_manager")
local func_ops = require("func_ops")
local mc = require("metacompiler")
local objects_helpers = require("game_objects_helpers")

-- Functions called on absence failure --
local FailFuncs = { [true] = func_ops.True, [false] = func_ops.False, [0] = func_ops.Zero, [1] = func_ops.One }

-- Type of failure --
local FailHow

-- Dummy object used as stand-in, in absence of timer --
local NullTimer = setmetatable({}, {
	__index = function()
		return FailFuncs[FailHow]
	end
})

-- Helper to prepare the stand-in
local function Null (how)
	FailHow = how

	return NullTimer
end

-- Timer_ActionComponent_cl reader --
objects_helpers.DefineReader("Timer_ActionComponent_cl", function(_, bvar, nvar, op)
	local family, name = em.PushBaseVar(bvar)
	local arg = ""

	if op == "Start" then
		arg = objects_helpers.ReadElement(_, "NumVar", nvar, true)
	elseif op == "Pause" or op == "Unpause" then
		arg = op == "Pause" and "true" or "false"
		op = "SetPause"
	end

	return format("%s:GetTimer(%s):%s(%s)", family, name, op, arg)
end)

-- Timer_ConditionComponent_cl reader --
objects_helpers.DefineReader("Timer_ConditionComponent_cl", function(_, bvar, op, absence_as_failure, negate)
	local family, name = objects_helpers.ReadElement(_, "BaseVar", bvar, true)
	local get

	if op == "Exists" then
		get = format("%s:PeekTimer(%s)", family, name)
	else
		--
		if absence_as_failure then
			mc.Declare("timer_null", Null)

			local how

			if op == "Elapsed" or op == "Done" then
				how = negate and "1" or "0"
			else
				how = negate and "true" or "false"
			end

			get = format("(%s:PeekTimer(%s) or timer_null(%s))", family, name, how)
		else
			get = format("%s:GetTimer(%s)", family, name)
		end

		--
		if op == "Running" then
			op = "%s:GetDuration()"
		elseif op == "Paused" then
			op = "%s:IsPaused()"
		else
			op = format("(%%s:Check(%s) > 0)", op == "Elapsed" and "\"continue\"" or "")
		end

		get = format(op, get)
	end

	return (negate and "not " or "") .. get
end)