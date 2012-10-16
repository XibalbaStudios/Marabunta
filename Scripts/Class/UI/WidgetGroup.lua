-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- Instances of this class serve as the control center for a group of widgets, organized
-- as a hierarchy with the root widget, owned by the group, at the top.<br><br>
-- Class.
module WidgetGroup
]]

-- Standard library imports --
local assert = assert
local insert = table.insert
local ipairs = ipairs
local pairs = pairs
local rawget = rawget
local rawequal = rawequal
local remove = table.remove
local type = type

-- Imports --
local Identity = func_ops.Identity
local IsCallableOrNil = var_preds.IsCallableOrNil
local MemberTable = lazy_ops.MemberTable
local New = class.New
local NoOp = func_ops.NoOp
local SetLocalRect = widget_ops.SetLocalRect
local SubTablesOnDemand = table_ops.SubTablesOnDemand
local SuperCons = class.SuperCons
local Try_Multi = func_ops.Try_Multi
local Weak = table_ops.Weak
local WipeRange = var_ops.WipeRange

-- Unique member keys --
local _choice = {}
local _deferred = {}
local _entered = {}
local _grabbed = {}
local _mode = {}
local _root = {}

-- WidgetGroup class definition --
class.Define("WidgetGroup", function(WidgetGroup)
	--- Accessor.
	-- @return Current mode, which is one of: <b>"normal"</b>, <b>"rendering"</b>, <b>
	-- "testing"</b>, <b>"updating"</b>, or <b>"issuing_events"</b>.
	function WidgetGroup:GetMode ()
		return self[_mode]()
	end

	--- Indicates whether the group is in an execute call, i.e. its mode is <b>"testing"</b>
	-- or <b>"issuing_events"</b>.
	-- @return If true, group is executing.
	-- @see WidgetGroup:Execute
	-- @see WidgetGroup:GetMode
	function WidgetGroup:IsExecuting ()
		return self[_mode]("is_executing")
	end

	-- Cache methods for internal use.
	local GetMode = WidgetGroup.GetMode
    local IsExecuting = WidgetGroup.IsExecuting

	--- Indicates whether the group is running in a callback, i.e. its mode is <b>
	-- "rendering"</b>, <b>"testing"</b>, or <b>"updating"</b>.
	-- @return If true, group is running callbacks.
	-- @see WidgetGroup:GetMode
	function WidgetGroup:IsRunningCallbacks ()
		return self[_mode]("is_running_callbacks")
	end

	--- Adds a task to call once the group has returned to normal mode. These tasks will be
	-- called, without arguments, in the order they were added. Return values are ignored.<br><br>
	-- If the group is already in normal mode, the task is called immediately.
	-- @param task Task to add.
	function WidgetGroup:AddDeferredTask (task)
		if GetMode(self) ~= "normal" then
			insert(MemberTable(self, _deferred), task)
		else
			task()
		end
	end

	--- Accessor.
	-- @return Reference to chosen widget, or <b>nil</b> if absent.
	function WidgetGroup:GetChoice ()
		return self[_choice]
	end

	--- Accessor.
	-- @return Reference to entered widget, or <b>nil</b> if absent.
	function WidgetGroup:GetEntered ()
		return self[_entered]
	end

	--- Accessor.
	-- @return Reference to grabbed widget, or <b>nil</b> if absent.
	function WidgetGroup:GetGrabbed ()
		return self[_grabbed]
	end

    --- Accessor.
	-- @return Reference to root widget.
    function WidgetGroup:GetRoot ()
        return self[_root]
    end

	-- Mode set helper
	local function SetMode (WG, mode)
		WG[_mode](mode, _mode)
	end

    -- Protected action
    local function AuxAction (WG, action, mode, ...)
        assert(GetMode(WG) == "normal", "Callbacks forbidden from other callbacks or event issues")

        -- Freshen the deferred list if necessary.
        WipeRange(MemberTable(WG, _deferred))

        -- Enter the callback mode.
		SetMode(WG, mode)

        -- Perform the mode action.
        action(WG, ...)
    end

    -- Action cleanup
    local function ActionDone (WG)
		SetMode(WG, nil)
    end

    -- Performs a mode action
    local function Action (WG, action, mode, ...)
        Try_Multi(AuxAction, ActionDone, WG, action, mode, ...)

        -- Perform any deferred actions.
        for _, func in ipairs(WG[_deferred]) do
            func()
        end
    end

    -- Execute --
    do
        -- Signals a widget and alerts signal listeners
        local function Alert (WG, widget, slot, subscribers, state)
            widget:Signal(slot, WG, state)

            -- Alert any subscribers.
            local list = rawget(subscribers, slot)

            if list then
				local alert = list.alert or slot .. "_alert"

				for _, v in ipairs(list) do
					v:Signal(alert, WG, state)
				end

				list.alert = alert
            end
        end

        -- Abandon signal logic
        local function Abandon (WG, subscribers, state)
            Alert(WG, WG[_choice], "abandon", subscribers, state)

            WG[_choice] = nil
        end

        -- Drop signal logic
        local function Drop (WG, subscribers, state)
            Alert(WG, WG[_grabbed], "drop", subscribers, state)

            WG[_grabbed] = nil
        end

        -- Enter signal logic
        local function Enter (WG, candidate, subscribers, state)
            WG[_entered] = candidate

			Alert(WG, WG[_entered], "enter", subscribers, state)
		end

		-- Grab state logic
		local function Grab (WG, subscribers, state)
            if state("is_pressed") and not WG[_grabbed] then
                WG[_grabbed] = WG[_choice]

                Alert(WG, WG[_grabbed], "grab", subscribers, state)
            end
        end

        -- Leave signal logic
        local function Leave (WG, subscribers, state)
            Alert(WG, WG[_entered], "leave", subscribers, state)

            WG[_entered] = nil
        end

		-- Subscribers cache --
		local Cache = {}

		-- Subscribers enumeration helper
		local function Enumerate (W, subscribers)
			subscribers = subscribers or remove(Cache) or SubTablesOnDemand()

			for k in W:SubscriptionsIter() do
				insert(subscribers[k], W)
			end

			for widget in W:AttachListIter() do
				Enumerate(widget, subscribers)
			end

			return subscribers
		end

		-- Subscribers cleanup helper
		local function Cleanup (subscribers)
			for _, v in pairs(subscribers) do
				WipeRange(v)
			end

			Cache[#Cache + 1] = subscribers
		end

        --- Clears the group state. Cannot be called during execution.<br><br>
        -- Each of the following is cleared, if set, in this order: the entered widget, the
		-- grabbed widget, and the choice widget. Also, each widget thus cleared is signaled,
		-- in that same order, as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>signal(widget, group)</b></i>,<br><br>
        -- where <i>signal</i> is <b>leave</b>, <b>drop</b>, or <b>abandon</b> respectively.<br><br>
		-- Any listeners to these signals are alerted.<br><br>
		-- Note that during a clear, the execution state parameter that would otherwise
		-- be passed to these slots is <b>nil</b>.
		-- @see WidgetGroup:Execute
        function WidgetGroup:Clear ()
            assert(not IsExecuting(self), "Clearing input forbidden during execution")

            -- Alert any special widgets about the clear.
            local subscribers = Enumerate(self[_root])

            if self[_entered] then
                Leave(self, subscribers)
            end

            if self[_grabbed] then
                Drop(self, subscribers)
            end

            if self[_choice] then
                Abandon(self, subscribers)
            end

            Cleanup(subscribers)
        end

        -- Issues events to the choice and / or candidate
        local function IssueEvents (WG, candidate, state)
			SetMode(WG, "issuing_events")

            -- If there is a choice, begin upkeep on it.
            local subscribers = Enumerate(WG[_root])
            local choice = WG[_choice]

            if choice then
                -- Pre-process the widget.
                Alert(WG, choice, "enter_upkeep", subscribers, state)

                -- Perform leave logic.
                if WG[_entered] and WG[_entered] ~= candidate then
                    Leave(WG, subscribers, state)
                end
			end

			-- If there is a candidate, try to enter it.
			if candidate and WG[_entered] ~= candidate then
				Enter(WG, candidate, subscribers, state)
			end

			-- If there is a choice, continue upkeep on it.
			if choice then
                -- If the chosen widget is the candidate, perform grab logic.
                if candidate == choice then
                    Grab(WG, subscribers, state)
                end

                -- If there is no press, perform drop logic.
                if not state("is_pressed") and WG[_grabbed] then
                    Drop(WG, subscribers, state)
                end

                -- If the widget remains chosen, post-process it; otherwise, abandon it.
                if candidate ~= choice and WG:GetGrabbed() ~= choice then
                    Abandon(WG, subscribers, state)
                else
                    Alert(WG, choice, "leave_upkeep", subscribers, state)
                end
            end

            -- If there is a candidate but no choice, choose it.
            if candidate and not WG[_choice] then
                WG[_choice] = candidate

                -- Pre-process the widget.
                Alert(WG, candidate, "enter_choose", subscribers, state)

                -- Perform enter and grab logic.
                Enter(WG, candidate, subscribers, state)
				Grab(WG, subscribers, state)

                -- Post-process the widget.
                Alert(WG, candidate, "leave_choose", subscribers, state)
            end

			Cleanup(subscribers)
        end

        -- Runs a test on the widget and through its attach list
        -- Returns: Candidate or nil
        local function Test (WG, widget, gx, gy, gw, gh, cx, cy, state)
            local x, y, w, h = widget:GetRect(gw, gh)
			local candidate

            x, y = x + gx, y + gy

            if widget:GetAttachListHead() and widget:IsAllowed("attach_list_test") then
                widget:Signal("enter_attach_list_test")

                local vx, vy = widget:GetViewOrigin()

                x, y = x - vx, y - vy

                for aw in widget:AttachListIter() do
                    candidate = Test(WG, aw, x, y, w, h, cx, cy, state)

                    if candidate ~= nil then
                        break
                    end
                end

                widget:Signal("leave_attach_list_test")
            end

            -- Perform the test.
            if candidate == nil and widget:IsAllowed("test") then
               candidate = widget:Signal("test", cx, cy, x, y, w, h, WG, state)
            end

            -- Supply any candidate or the abort flag.
            return candidate
        end

        -- Execute body for resource usage
        local function ExecuteBody (WG, cx, cy, state, resolve)
            resolve(WG, Test(WG, WG[_root], 0, 0, 0, 0, cx, cy, state), state)
        end

		-- Execution state --
		local States = Weak("k")

        --- Executes the group and resolves events generated during execution.<br><br>
        -- In what follows, <i>state</i> refers to a single-argument function that can be
		-- called to retrieve some state that remains immutable during execution.<br><br>
        -- <b>DETAILED DESCRIPTION:</b><br><br>
		-- Up to this point, the group will be in <b>testing</b> mode.<br><br>
		-- Starting from the root, the execution proceeds through each widget's attach
		-- list, recursively testing each widget along the way.<br><br>
        -- If a widget has a non-empty attach list and has <b>attach_list_test</b> allowance,
        -- the attach list is tested. The widget is first signaled as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>enter_attach_list_test(widget)</b></i>.<br><br>
        -- Each item in the attach list, in order (i.e. items at the front of the attach
		-- list are tested before items at the back), is then recursively tested. The widget
		-- is then signaled as<br><br>
		-- &nbsp&nbsp&nbsp<i><b>leave_attach_list_test(widget)</b></i>.<br><br>
        -- If a widget has <b>test</b> allowance, then it is signaled as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>test(widget, cx, cy, x, y, w, h, group, state)</b></i>,<br><br>
        -- where <i>cx</i> and <i>cy</i> are the cursor coordinates. The test rect will be in
		-- absolute coordinates.<br><br>
		-- A test indicates success by returning a reference to a widget. Note that this may
		-- be another widget than itself, e.g. for sub-widgets. Once a widget has passed the
		-- test, testing stops, and this "candidate" is kept around for event resolution.<br><br>
		-- If a custom resolve is used, it is called and the group stays in testing
		-- mode.<br><br>
		-- Otherwise, the group switches to <b>issuing_events</b> mode.<br><br>
		-- Event issuing follows one of two paths:<br><br>
		-- <b>GROUP HAS A CHOSEN WIDGET</b><br><br>
		-- The chosen widget is first sent an <b>enter_upkeep</b> signal.<br><br>
		-- If the group has an entered widget and the cursor has left it, it is sent a
		-- <b>leave</b> signal.<br><br>
		-- If the group did not have an entered widget, on the other hand, and the chosen
		-- widget has been entered, it is sent an <b>enter</b> signal and the widget
		-- becomes the entered widget.<br><br>
		-- If the group did not have a grabbed widget, and the cursor has been pressed over
		-- the chosen widget, it is sent a <b>grab</b> signal and the widget becomes the
		-- grabbed widget.<br><br>
		-- If the group did have a grabbed widget, on the other hand, and the cursor is now
		-- released, it is sent a <b>drop</b> signal.<br><br>
		-- If the group does not have a grabbed widget and the candidate is not the chosen
		-- widget, the chosen widget is sent an <b>abandon</b> signal. Otherwise it is
		-- sent a <b>leave_upkeep</b> signal.<br><br>
		-- <b>GROUP DOES NOT HAVE A CHOSEN WIDGET</b><br><br>
		-- The candidate becomes the chosen widget.<br><br>
		-- The candidate is sent an <b>enter_choose</b> signal.<br><br>
		-- The entered / grabbed widget decisions (and attendant <b>enter</b> and <b>
		-- grab</b> signals) from the "has a chosen widget" logic is repeated here.<br><br>
		-- The candidate is sent a <b>leave_choose</b> signal.<br><br>
		-- All signals sent during event issuing have signature<br><br>
		-- &nbsp&nbsp&nbsp<i><b>signal(widget, group, state)</b></i>.<br><br>
		-- Any listeners to these signals are alerted.<br><br>
        -- @param cx Cursor x-coordinate. This can be retrieved as <b>state("cx")</b>.
		-- @param cy Cursor y-coordinate. This can be retrieved as <b>state("cy")</b>.
        -- @param is_pressed If true, a press occurred at the cursor position. This can be
		-- retrieved as <b>state("is_pressed")</b>.
        -- @param enter Clip region enter logic.<br><br>
        -- This can be retrieved as <b>state("enter")</b> and called as <b>enter(x, y, w, h)</b>.
		-- If this returns a true result, the enter is successful.<br><br>
		-- By default, this is a no-op that always succeeds.<br><br>
        -- @param leave Clip region leave logic.<br><br>
        -- This can be retrieved as <b>state("leave")</b> and called as <b>leave()</b>.
		-- In general, it will undo anything done by the <i>enter</i> logic and should only
		-- be called if that was successful.<br><br>
        -- @param resolve Event resolution logic.<br><br>
		-- If absent, the built-in logic is used. Otherwise, this must be callable as<br><br>
		-- &nbsp&nbsp&nbsp<i><b>resolve(group, candidate, state)</b></i>,<br><br>
		-- where <i>candidate</i> is the widget that passed a test during execution, or
		-- <b>nil</b> if none passed.
		-- @see ~Widget:Allow
		-- @see ~Widget:GetAbsoluteRect
        function WidgetGroup:Execute (cx, cy, is_pressed, enter, leave, resolve)
        	assert(type(cx) == "number", "Invalid cursor x")
        	assert(type(cy) == "number", "Invalid cursor y")
        	assert(IsCallableOrNil(enter), "Uncallable enter")
        	assert(IsCallableOrNil(leave), "Uncallable leave")
        	assert(IsCallableOrNil(resolve), "Uncallable resolve")

			-- Bind the execution state, creating it if necessary.
			local state = States[self]

			if not state then
				local vars = {}

				function state (what, ...)
					if rawequal(what, States) then
						vars.cx, vars.cy, vars.is_pressed, vars.enter, vars.leave = ...
					elseif what == "cursor" then
						return vars.cx, vars.cy
					else
						return vars[what]
					end
				end

				States[self] = state
			end

			state(States, cx, cy, not not is_pressed, enter or Identity, leave or NoOp) 

			-- Execute the group.
            Action(self, ExecuteBody, "testing", cx, cy, state, resolve or IssueEvents)
        end
    end

    -- Render --
    do
        -- Performs a render on the widget and through its attach list
        -- gx, gy: Parent coordinates
        local function Render (WG, widget, gx, gy, gw, gh, state)
            local x, y, w, h = widget:GetRect(gw, gh)

            x, y = x + gx, y + gy

            if widget:IsAllowed("render") then
                widget:Signal("render", x, y, w, h, WG, state)
            end

            if widget:GetAttachListHead() and widget:IsAllowed("attach_list_render") then
                widget:Signal("enter_attach_list_render")

                local vx, vy = widget:GetViewOrigin()

                x, y = x - vx, y - vy

                for aw in widget:AttachListIter(true) do
                    Render(WG, aw, x, y, w, h, state)
                end

                widget:Signal("leave_attach_list_render")
            end

            if widget:IsAllowed("render") then
                widget:Signal("post_render", x, y, w, h, WG, state)
            end
        end

		-- Render state --
		local States = Weak("k")

        --- Renders the group.<br><br>
        -- In what follows, <i>state</i> refers to a single-argument function that can be
		-- called to retrieve some state that remains immutable during rendering.<br><br>
        -- <b>DETAILED DESCRIPTION:</b><br><br>
        -- Starting from the root, the render proceeds through each widget's attach list,
        -- recursively rendering each widget along the way.<br><br>
        -- If a widget has <b>render</b> allowance, then it is signaled as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>render(widget, x, y, w, h, group, state)</b></i>.<br><br>
        -- where <i>W</i> is the rendered widget, <i>x</i>, <i>y</i>, <i>w</i>, <i>h</i>
		-- The render rect will be in absolute coordinates.<br><br>
        -- If a widget has a non-empty attach list and <b>attach_list_render</b> allowance,
        -- the attach list is rendered. The widget is signaled as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>enter_attach_list_render(widget)</b></i>.<br><br>
        -- Each item in the attach list, in reverse order (i.e. items at the front of the
		-- attach list are in front of items at the back), is then recursively rendered.
		-- The widget is then signaled as<br><br>
		-- &nbsp&nbsp&nbsp<i><b>leave_attach_list_render(widget)</b></i>.<br><br>
		-- During this call, the group will be in <b>rendering</b> mode.
        -- @param enter Clip region enter logic.<br><br>
        -- This can be retrieved as <b>state("enter")</b> and called as <b>enter(x, y, w, h)</b>.
		-- If this returns a true result, the enter is successful.<br><br>
		-- By default, this is a no-op that always succeeds.<br><br>
        -- @param leave Clip region leave logic.<br><br>
        -- This can be retrieved as <b>state("leave")</b> and called as <b>leave()</b>. In
		-- general, it will undo anything done by the <i>enter</i> logic and should only be
		-- called if that was successful.<br><br>
		-- By default, this is a no-op.
        -- @see WidgetGroup:GetMode
        -- @see ~Widget:Allow
        -- @see ~Widget:GetAbsoluteRect
        function WidgetGroup:Render (enter, leave)
        	assert(IsCallableOrNil(enter), "Uncallable enter")
        	assert(IsCallableOrNil(leave), "Uncallable leave")

			-- Bind the render state, creating it if necessary.
			local state = States[self]

			if not state then
				local vars = {}

				function state (what, ...)
					if rawequal(what, States) then
						vars.enter, vars.leave = ...
					else
						return vars[what]
					end
				end

				States[self] = state
			end

			state(States, enter or Identity, leave or NoOp)

			-- Render the group.
            Action(self, Render, "rendering", self[_root], 0, 0, 0, 0, state)
        end
    end

    -- Update --
    do
        -- Performs an update on the widget and through its attach list
        -- dt: Time lapse
        local function Update (WG, widget, dt)
            if widget:IsAllowed("update") then
                widget:Signal("update", dt, WG)
            end

            if widget:GetAttachListHead() and widget:IsAllowed("attach_list_update") then
                widget:Signal("enter_attach_list_update")

                for aw in widget:AttachListIter(true) do
                    Update(WG, aw, dt)
                end

                widget:Signal("leave_attach_list_update")
            end

            if widget:IsAllowed("update") then
                widget:Signal("post_update", dt, WG)
            end
        end

        --- Updates the group.<br><br>
        -- <b>DETAILED DESCRIPTION:</b><br><br>
        -- Starting from the root, the update proceeds through each widget's attach list,
        -- recursively updating each widget along the way.<br><br>
        -- If a widget has <b>update</b> allowance, then it is signaled as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>update(widget, dt, group)</b></i>.<br><br>
        -- If a widget has a non-empty attach list and <b>attach_list_update</b> allowance,
        -- the attach list is updated. The widget is first signaled as<br><br>
        -- &nbsp&nbsp&nbsp<i><b>enter_attach_list_update(widget)</b></i>.<br><br>
        -- Each item in the attach list, in reverse order (to correspond to <b>WidgetGroup:Render</b>),
		-- is then recursively updated. The widget is then signaled as<br><br>
		-- &nbsp&nbsp&nbsp<i><b>leave_attach_list_update(widget)</b></i>.<br><br>
		-- During this call, the group will be in <b>updating</b> mode.
        -- @param dt Time lapse.
        -- @see WidgetGroup:GetMode
        -- @see WidgetGroup:Render
        -- @see ~Widget:Allow
        function WidgetGroup:Update (dt)
			assert(type(dt) == "number" and dt >= 0, "Invalid time lapse")

            Action(self, Update, "updating", self[_root], dt)
        end
    end

	--- Class constructor.
	function WidgetGroup:__cons ()
		-- Deferred events --
		self[_deferred] = {}

		-- Current mode --
		local mode

		self[_mode] = function(what, check)
			if what == "is_executing" then
				return mode == "testing" or mode == "issuing_events"
			elseif what == "is_running_callbacks" then
				return mode == "rendering" or mode == "testing" or mode == "updating"
			elseif rawequal(check, _mode) then
				mode = what
			else
				return mode or "normal"
			end
		end

		-- Root widget --
		self[_root] = New("Widget", self, self[_mode])

		self[_root]:SetX(0)
		self[_root]:SetY(0)

		-- Signals --
		self[_root]:SetSlot("test", Identity)
	end
end)