-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local max = math.max
local min = math.min
local unpack = unpack

-- Imports --
local Args = iterators.Args
local CollectArgsInto = var_ops.CollectArgsInto
local GetFields = table_ops.GetFields
local GetSize = user_state.GetSize
local IsType = class.IsType
local New = class.New
local NoOp = func_ops.NoOp
local SetLocalRect = widget_ops.SetLocalRect
local TableCache = cache_ops.TableCache
local WithInterpolator = tasks.WithInterpolator

---
module "transitions"

-- Attachment --
do
	local Cache = TableCache("wipe_range")

	-- ...: Widgets to add
	-- Returns: Batch
	------------------------
	local function MakeBatch (...)
		local args = Cache("pull")

		for _, widget in Args(...) do
			assert(IsType(widget, "Widget"), "Batch elements must be widgets")

			args[#args + 1] = widget
		end

		assert(#args > 0, "Empty batch")

		return args
	end

	-- Builds a task that attaches widgets to a layer
	-- layer: Layer handle
	-- ...: Widgets to attach
	-- Returns: Task
	--------------------------------------------------
	function Attacher (layer, ...)
		assert(IsType(layer, "Widget"), "Non-widget layer")

		local args = MakeBatch(...)

		return function()
			for _, widget in ipairs(args) do
				layer:Attach(widget)
			end

			Cache(args)
		end
	end

	-- Builds a task that detaches widgets
	-- ...: Widgets to detach
	-- Returns: Task
	---------------------------------------
	function Detacher (...)
		local args = MakeBatch(...)

		return function()
			for _, widget in ipairs(args) do
				widget:Detach()
			end

			Cache(args)
		end
	end
end

-- Builds an interpolator task
-- func: Interpolation routine
-- duration: Transition duration
-- options: Options set
-- quit_main: Transition-specific quit logic
-- Returns: Task function
---------------------------------------------
local function InterpolatorTask (func, duration, options, quit_main)
	local interp = New("Interpolator", func, duration)
	local mode, prep, quit

	if options then
		mode = options.mode
		prep = options.prep
		quit = options.quit

		interp:SetMap(options.map)
	end

	interp:Start(mode or "once")

	return WithInterpolator(interp, prep, quit_main and function(arg)
		quit_main();

		(quit or NoOp)(arg)
	end or quit)
end

-- Position --
do
	local Cache = TableCache("wipe_range")

    -- Default interpolation function
    -- cur: Current coordinate
    -- delta: Coordinate delta
    -- t: Current time
    -- Returns: Interpolated coordinate
    ------------------------------------
    local function Linear (cur, delta, t)
        return cur + delta * t
    end

	-- Gets values used for widget motion
	-- widget: Widget handle
	-- desc: Motion descriptor
	-- ddx, ddy: Default motion deltas
	-- Returns: Initial coordinates; motion deltas; position functions
	-------------------------------------------------------------------
	local function GetMoveValues (widget, desc, ddx, ddy)
		local x1, y1, x2, y2, dx, dy, xfunc, yfunc

		if desc then
			x1, y1, x2, y2, dx, dy, xfunc, yfunc = GetFields(desc, "x1", "y1", "x2", "y2", "dx", "dy", "xfunc", "yfunc")
		end

        x1, y1 = x1 or widget:GetX(), y1 or widget:GetY()

        return x1, y1, x2 and x2 - x1 or dx or ddx, y2 and y2 - y1 or dy or ddy, xfunc or Linear, yfunc or Linear
	end

	-- Builds a task to move a widget
	-- widget: Widget handle
	-- duration: Transition duration
	-- how: Move options
	-- options: Transition options
	-- Returns: Task
	----------------------------------
    function MoveWidget (widget, duration, how, options)
		local x, y, dx, dy, xfunc, yfunc = GetMoveValues(widget, how, 0, 0)

        -- Supply an iterator to place widgets at their current positions.
        return InterpolatorTask(function(t)
			assert(widget:IsAttached(), "Attempt to move unattached widget")

            widget:SetX(xfunc(x, dx, t))
            widget:SetY(yfunc(y, dy, t))
        end, duration, options)
    end

    -- Builds a task to move a group of widgets
    -- widgets: Widget table
    -- duration: Transition duration
    -- how: Move options
    -- options: Transition options
    -- Returns: Task
    --------------------------------------------
    function MoveWidgetBatch (widgets, duration, how, options)
        -- Build up a batch of motion tracking information.
        local motion = Cache("pull")
		local ddx, ddy = how.dx or 0, how.dy or 0

        for i, widget in ipairs(widgets) do
            motion[i] = Cache("pull")

            CollectArgsInto(motion[i], widget, GetMoveValues(widget, how[i], ddx, ddy))
        end

        -- Supply an iterator to place widgets at their current positions.
        return InterpolatorTask(function(t)
            for _, item in ipairs(motion) do
                local widget, x, y, dx, dy, xfunc, yfunc = unpack(item)

				assert(widget:IsAttached(), "Attempt to move unattached widget")

                widget:SetX(xfunc(x, dx, t))
                widget:SetY(yfunc(y, dy, t))
            end
        end, duration, options, function()
        	for _, item in ipairs(motion) do
        		Cache(item)
        	end

			Cache(motion)
		end)
    end

	-- Builds a task to place a widget
	-- x, y: Placement coordinates
	-- Returns: Task
	-----------------------------------
    function PlaceWidget (widget, x, y)
		return function()
			widget:SetX(x)
			widget:SetY(y)
		end
    end
end

-- Builds a resize transition task
-- widget: Widget handle
-- duration: Transition duration
-- w1, h1: Initial dimensions
-- w2, h2: Final dimensions
-- how: Expansion type
-- options: Transition options
-- Returns: Task
-----------------------------------
function Resize (widget, duration, w1, h1, w2, h2, how, options)
	return InterpolatorTask(function(t)
		assert(widget:IsAttached(), "Attempt to resize unattached widget")

		-- Given special requests, transform the width and height expansion times.
		local wt, ht = t, t

		if how == "wh" then
			wt, ht = min(2 * t, 1), max(2 * (t - .5), 0)
		elseif how == "hw" then
			wt, ht = max(2 * (t - .5), 0), min(2 * t, 1)
		end

		-- Apply the current positions and dimensions.
		widget:SetRectPolicy("x", "center")
		widget:SetRectPolicy("y", "center")

		SetLocalRect(widget, nil, nil, w1 + (w2 - w1) * wt, h1 + (h2 - h1) * ht)
	end, duration, options)
end

-- View slide-in --
do
	local Update = {
		["h+"] = function(t, widget, vw)
			widget:SetViewOrigin(vw * (1 - t), 0)
		end,
		["h-"] = function(t, widget, vw)
			widget:SetViewOrigin(vw * (t - 1), 0)
		end,
		["v+"] = function(t, widget, _, vh)
			widget:SetViewOrigin(0, vh * (t - 1))
		end,
		["v-"] = function(t, widget, _, vh)
			widget:SetViewOrigin(0, vh * (1 - t))
		end
	}

	-- Builds a view slide-in transition task
	-- widget: Widget handle
	-- duration: Transition duration
	-- how: Slide-in type
	-- options: Transition options
	-- Returns: Task
	------------------------------------------
	function SlideViewIn (widget, duration, how, options)
		return InterpolatorTask(function(t)
			assert(widget:IsAttached(), "Attempt to slide view of unattached widget")

			Update[how](t, widget, GetSize())
		end, duration, options)
	end
end