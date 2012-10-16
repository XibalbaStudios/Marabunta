-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local pairs = pairs
local setmetatable = setmetatable
local type = type

-- Modules --
local cache_ops = require("cache_ops")
local class = require("class")
local coroutine_ops = require("coroutine_ops")
local func_ops = require("func_ops")
local iterators = require("iterators")
local localization = require("localization")
local settings = require("settings")
local table_ops = require("table_ops")
local user_state = require("user_state")
local var_ops = require("var_ops")
local var_preds = require("var_preds")
local widget_ops = require("widget_ops")

-- Imports --
local Args = iterators.Args
local CallOrGet = func_ops.CallOrGet
local CollectArgsInto = var_ops.CollectArgsInto
local Execute = user_state.Execute
local Filter = table_ops.Filter
local FocusChain = user_state.FocusChain
local GetDictionary = localization.GetDictionary
local GetLanguage = settings.GetLanguage
local GetSize = user_state.GetSize
local IsCallable = var_preds.IsCallable
local IsCallableOrNil = var_preds.IsCallableOrNil
local IsString = var_preds.IsString
local New = class.New
local NoOp = func_ops.NoOp
local PurgeAttachList = widget_ops.PurgeAttachList
local Render = user_state.Render
local SectionGroup = user_state.SectionGroup
local WaitUntil = coroutine_ops.WaitUntil
local WidgetGroup = user_state.WidgetGroup

-- Cached routines --
local _CleanupEventQueues_
local _GetEventQueue_
local _GetLookup_
local _SetLookupTable_

-- Event queues --
local Queues = {}

for _, when in Args("enter_render", "leave_render", "enter_trap", "leave_trap", "enter_update", "leave_update", "between_frames") do
	Queues[when] = {}
end

---
module "section"

-- Section lookup tables --
local Lookups = {}

do
	-- Cleanup argument --
	local Arg

	-- Cleanup descriptor --
	local How

	-- Default function for unmarked tasks --
	local DefFunc

	-- Task marks --
	local Marks = setmetatable({}, {
		__index = function()
			return DefFunc
		end,
		__mode = "k"
	})

	-- Queue cleanup helper
	local function Cleanup (task)
		return Marks[task](task, How, Arg)
	end

	-- Cleanup iterator helper
	local function GetIterator (queues, all_groups)
		if all_groups then
			return pairs(queues)
		else
			local queue = queues[SectionGroup()]

			if queue then
				return Args(queue)
			else
				return NoOp
			end
		end
	end

	-- Cleans up event queues before major switches
	-- how: Event cleanup descriptor
	-- all_groups: If true, cleanup queues in all section groups
	-- def_func: Optional function to call on unmarked tasks
	-- omit: Optional queue to ignore during cleanup
	-- arg: Cleanup argument
	--------------------------------------------------------------
	function CleanupEventQueues (how, all_groups, def_func, omit, arg)
		assert(IsCallableOrNil(def_func), "Invalid default function")

		Arg = arg
		How = how
		DefFunc = def_func ~= nil and def_func or NoOp

		for name, queues in pairs(Queues) do
			if name ~= omit then
				for _, queue in GetIterator(queues, all_groups) do
					if #queue > 0 then
						local tasks = queue:Gather(true)

						Filter(tasks, Cleanup)

						queue:Clear()
						queue:Add_Array(tasks)
					end
				end
			end
		end
	end

	-- Marks a task with a function to call on cleanup
	-- task: Task to mark
	-- cleanup: Cleanup function
	---------------------------------------------------
	function MarkTask (task, cleanup)
		assert(IsCallable(task), "Uncallable task")
		assert(IsCallable(cleanup), "Uncallable cleanup function")

		Marks[task] = cleanup
	end
end

--- blocks or unblocks a section.
-- @param data Section data
-- @paran block block state, true or false
function Block( data, block )
	data.blocked = block	
end

-- Cache for close / open arguments --
local ArgsCache = cache_ops.TableCache("unpack_and_wipe")

-- Unpack helper
local function Unpack (args, count)
	return ArgsCache(args, count, false)
end

--
local function AddToQueue (func)
	_GetEventQueue_("between_frames"):Add(func)
end

--
local function WrapBuilder (func)
	return function(name, no_delay, extra_arg, ...)
		local count, args = CollectArgsInto(ArgsCache("pull"), ...)

		local function Wrapper ()
			func(name, count, args, extra_arg)
		end

		if no_delay then
			return Wrapper
		else
			return function()
				AddToQueue(Wrapper)
			end
		end
	end
end

-- Helper to close a section
local CloseSection = WrapBuilder(function(name, count, args)
	SectionGroup():Close(CallOrGet(name), Unpack(args, count))
end)

-- Shorthand for CloseSection
local function CS (name, no_delay, ...)
	return CloseSection(name, no_delay, nil, ...)
end

--- Closes a section.
-- @param name Section name.
-- @param ... Arguments to section close.
function Close (name, ...)
	AddToQueue(CS(name, true, ...))
end

-- Builds a section close routine
-- name: Section name
-- ...: Arguments to section close
-- Returns: Closure to close section
-------------------------------------
function Closer (name, ...)
	return CS(name, false, ...)
end

--- 
function Close_Direct (name, ...)
	return CS(name, true, ...)
end

-- Gets a section group's event queue
-- event: Event name
-- index: Optional group index
-- Returns: Queue handle
---------------------------------------
function GetEventQueue (event, index)
	local sg = SectionGroup(index)
	local set = assert(Queues[event], "Invalid event queue")

	set[sg] = set[sg] or New("TaskQueue")

	return set[sg]
end

-- Gets a section's lookup set
-- data: Section data
-- Returns: Lookup set in the current language
-----------------------------------------------
function GetLookup (data)
	local t

	if IsString(Lookups[data]) then
		t = GetDictionary( Lookups[data] )
	else
		t = Lookups[data]
		t = t and t[GetLanguage()] or nil
	end

	return t
end

-- Loads a section, handling common functionality
-- name: Section name
-- proc: Section procedure
-- lookup: Optional lookup table
-- ...: Load arguments
--------------------------------------------------
function Load (name, proc, lookup, ...)
	local sg = SectionGroup()
	local wg = WidgetGroup()
	local data = {}
	
	-- Wrap the procedure in a routine that handles common logic. Load the section.
	sg:Load(name, function(state, arg1, ...)
		-- On close, detach the pane.
		if state == "close" then
			for _, layer in ipairs(data) do
				PurgeAttachList(layer)

				layer:Detach()
			end

			-- Remove current focus items.
			local chain = FocusChain(data, true)

			if chain then
				chain:Clear()
			end

			-- Sift out section-specific messages.
			_CleanupEventQueues_("close_section", false, nil, "between_frames", name)

		-- On load, register any lookup table.
		elseif state == "load" then
			_SetLookupTable_(data, lookup)

		-- On render, draw the UI.
		elseif state == "render" then
			(Queues.enter_render[sg] or NoOp)(data)

			Render(wg);

			(Queues.leave_render[sg] or NoOp)(data)

		-- On trap, direct input to the UI.
		elseif state == "trap" then
			(Queues.enter_trap[sg] or NoOp)(data)
			if data.blocked then
			--messagef("BLOCK " .. (data.blocked and "true" or "false") )
			end
			if not data.blocked then
				Execute(wg, data)
			end

			(Queues.leave_trap[sg] or NoOp)(data)

		-- On update, update the UI. (arg1: time lapse)
		elseif state == "update" then
			(Queues.enter_update[sg] or NoOp)(data)

			wg:Update(arg1);

			(Queues.leave_update[sg] or NoOp)(data)
		end

		-- Do section-specific logic.
		if state ~= "trap" or not data.blocked then
			return proc(state, data, arg1, ...)
		end
	end, ...)
end

-- Helper to open a section
local OpenSection = WrapBuilder(function(name, count, args, clear_sections)
	WidgetGroup():Clear()

	local sg = SectionGroup()
	local from = sg:Current()
	local to = CallOrGet(name)

	if from then
		sg:Send(from, "message:going_to", to)
	end

	if clear_sections then
		sg:Clear()
	end

	sg:Send(to, "message:coming_from", from)
	sg:Open(to, Unpack(args, count))
end)

-- Shorthand for OpenSection, dialog version
local function OSD (name, no_delay, ...)
	return OpenSection(name, no_delay, false, ...)
end

-- Opens a section dialog and waits for it to close
-- name: Section name
-- ...: Arguments to section enter
----------------------------------------------------
function OpenAndWait (name, ...)
	local is_done

	AddToQueue(OSD(name, true, function()
		is_done = true
	end, ...))

    WaitUntil(function()
        return is_done
    end)
end

-- Opens a section dialog
-- name: Section name
-- ...: Arguments to section enter
-----------------------------------
function Dialog (name, ...)
	AddToQueue(OSD(name, true, ...))
end

-- Builds a section dialog open routine
-- name: Section name
-- ...: Arguments to section enter
-- Returns: Closure to open dialog
----------------------------------------
function DialogOpener (name, ...)
	return OSD(name, false, ...)
end

-- 
----------------------------------------
function Dialog_Direct (name, ...)
	return OSD(name, true, ...)
end

-- Shorthand for OpenSection, screen version
local function OSS (name, no_delay, ...)
	return OpenSection(name, no_delay, true, ...)
end

-- Opens a single-layer section; closes other sections
-- name: Section name
-- ...: Arguments to section enter
-------------------------------------------------------
function Screen (name, ...)
	AddToQueue(OSS(name, true, ...))
end

-- Builds a section screen open routine
-- name: Section name
-- ...: Arguments to section enter
-- Returns: Closure to open screen
----------------------------------------
function ScreenOpener (name, ...)
	return OSS(name, false, ...)
end

-- 
-------------------------------------------------------
function Screen_Direct (name, ...)
	return OSS(name, true, ...)
end

-- Sets the section's lookup table
-- data: Section data
-- lookup: Lookup table
-----------------------------------
function SetLookupTable (data, lookup)
	Lookups[data] = lookup
end

-- Does standard setup for screen sections
-- data: Section data
-- focus_items: Optional focus chain items
-- Returns: Lookup set in the current language
-----------------------------------------------
function SetupScreen (data, focus_items)
	local root = WidgetGroup():GetRoot()

	for _, layer in ipairs(data) do
		root:Attach(layer, 0, 0, GetSize())

		layer:Promote()
	end

	if focus_items then
		FocusChain(data):Load(focus_items)
	end

	return _GetLookup_(data)
end

-- Cache some routines.
_CleanupEventQueues_ = CleanupEventQueues
_GetEventQueue_ = GetEventQueue
_GetLookup_ = GetLookup
_SetLookupTable_ = SetLookupTable