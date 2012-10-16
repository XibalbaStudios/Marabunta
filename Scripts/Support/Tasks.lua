-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local huge = math.huge
local min = math.min
local type = type

-- Imports --
local GetTimeLapseFunc = func_ops.GetTimeLapseFunc
local IsCallable = var_preds.IsCallable
local IsCallableOrNil = var_preds.IsCallableOrNil
local New = class.New
local NoOp = func_ops.NoOp

---
module "tasks"

-- Builds a task that persists until interruption
-- update: Update routine
-- quit: Optional quit routine
-- Returns: Task function
--------------------------------------------------
function PersistUntil (update, quit)
	assert(IsCallable(update), "Uncallable update function")
	assert(IsCallableOrNil(quit), "Uncallable quit function")

	local age = 0
	local diff = GetTimeLapseFunc("tasks")

	-- Build a persistent task.
	return function(arg)
		if not update(age, arg) then
			age = age + diff()

			return "keep"
		end

		(quit or NoOp)(age, arg)
	end
end

-- Builds an interpolating task
-- interpolator: Interpolator handle
-- prep: Optional preparation function
-- quit: Optional function called on quit
-- Returns: Task function
------------------------------------------
function WithInterpolator (interpolator, prep, quit)
	assert(IsCallableOrNil(prep), "Uncallable preparation function")
	assert(IsCallableOrNil(quit), "Uncallable quit function")

 	prep = prep or NoOp

	local diff = GetTimeLapseFunc("tasks")

	return function(arg)
		local lapse = diff()

		prep(interpolator, lapse, arg)

		if interpolator:GetMode() ~= "suspended" then
			interpolator(lapse)

			return "keep"
		end

		(quit or NoOp)(arg)
	end
end

-- Configures a timer according to type
-- timer: Timer handle or task duration
-- Returns: Time lapse routine, timer
local function SetupTimer (timer)
	local diff

	if type(timer) == "number" then
		local duration = timer

		diff = GetTimeLapseFunc("tasks")
		timer = New("Timer")

		timer:Start(duration)
	end

	return diff, timer
end

-- Builds a task that triggers periodically
-- timer: Timer handle or task duration
-- func: Function called on timeout
-- quit: Optional function called on quit
-- just_once: If true, limit timeouts to one per run
-- Returns: Task function
-----------------------------------------------------
function WithPeriod (timer, func, quit, just_once)
	assert(IsCallable(func), "Uncallable function")
	assert(IsCallableOrNil(quit), "Uncallable quit function")

	local diff, timer = SetupTimer(timer)

	return function(arg)
		local duration = timer:GetDuration()

		if duration then
			for _ = 1, min(just_once and 1 or huge, timer:Check("continue")) do
				if func(timer:GetCounter(), duration, arg) then
					(quit or NoOp)(arg)

					return
				end
			end

			if diff then
				timer:Update(diff())
			end

			return "keep"
		end
	end
end

-- Builds a task that persists until a time is passed
-- timeline: Optional timeline handle
-- func: Task function
-- quit: Optional function called when time is passed
-- time: Time value
-- is_absolute: If true, time is absolute
-- Returns: Task function
------------------------------------------------------
function WithTimeline (timeline, func, quit, time, is_absolute)
	assert(IsCallable(func), "Uncallable function")
	assert(IsCallableOrNil(quit), "Uncallable quit function")

	local diff

	-- Build a fresh timeline if one was not provided.
	if not timeline then
		diff = GetTimeLapseFunc("tasks")
		timeline = New("Timeline")
	end

	-- Adjust relative times.
	if not is_absolute then
		time = time + timeline:GetTime()
	end

	return function(arg)
		local when = timeline:GetTime()

		if when < time then
			func(timeline, when, time, arg)

			if diff then
				timeline(diff(), arg)
			end

			return "keep"
		end

		(quit or NoOp)(arg)
	end
end

-- Builds a task that persists while a timer runs
-- timer: Timer handle or task duration
-- func: Task function
-- quit: Optional function called after timeout
-- Returns: Task function
--------------------------------------------------
function WithTimer (timer, func, quit)
	assert(IsCallable(func), "Uncallable function")
	assert(IsCallableOrNil(quit), "Uncallable quit function")

	local diff, timer = SetupTimer(timer)

	return function(arg)
		local duration = timer:GetDuration()

		if duration and timer:Check() == 0 then
			func(timer:GetCounter(), duration, arg)

			if diff then
				timer:Update(diff())
			end

			return "keep"
		end

		(quit or NoOp)(arg)
	end
end