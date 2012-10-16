-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A section is a callback used to represent current program state, e.g. the current
-- screen or as the procedure for the main window.<br><br>
-- A section group serves as a repository of loaded sections, as well as a basic control
-- center for navigating between them. More powerful functionality can be built atop it.<br><br>
-- Class.
module SectionGroup
]]

-- Standard library imports --
local assert = assert
local pairs = pairs
local remove = table.remove

-- Modules --
local class = require("class")
local table_ops = require("table_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local AssertArg = var_ops.AssertArg
local Find = table_ops.Find
local IsCallable = var_preds.IsCallable
local New = class.New

-- Unique member keys --
local _sections = {}
local _stack = {}

-- Internal proc states --
local Internal = table_ops.MakeSet{
	"load", "unload",
	"move",
	"open", "close",
	"resume", "suspend"
}

-- SectionGroup class definition --
class.Define("SectionGroup", function(SectionGroup)
	-- Calls a section proc
	local function Proc (section, what, ...)
		if section then
			return section(what, ...)
		end
	end

	--- Sends a message to the current section as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>proc(what, ...)</b></i>.<br><br>
	-- If the stack is empty, this is a no-op.
	-- @param what Message, which may be any non-<b>nil</b> value not used by one of
	-- <b>SectionGroup</b>'s methods.
	-- @param ... Message payload.
	-- @see SectionGroup:Send
	function SectionGroup:__call (what, ...)
		assert(what ~= nil, "state == nil")
		assert(not Internal[what], "Cannot call proc with internal message")

		local stack = self[_stack]

		Proc(stack[#stack], what, ...)
	end

	-- Removes a section from the stack
	local function Remove (G, where, type, ...)
		Proc(remove(G[_stack], where), type, ...)
	end

	--- Clears the active section stack.<br><br>
	-- Each section, from top to bottom, is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>proc("close", true)</b></i>,<br><br>
	-- where the <b>true</b> indicates that the close was during a clear.
	function SectionGroup:Clear ()
		local stack = self[_stack]

		while #stack > 0 do
			Remove(self, nil, "close", true)
		end
	end

	-- Section acquire helper
	local function GetSection (G, name)
		return AssertArg(G[_sections][name], "Section \"%s\" does not exist", name)
	end

	--- Closes an active section.<br><br>
	-- The section is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>proc("close", false, ...)</b></i>,<br><br>
	-- where the <b>false</b> indicates that the close was not in <b>SectionGroup:Clear</b>.<br><br>
	-- If the current section is closed, and another is below it on the stack, that section
	-- is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>other_proc("resume")</b></i>.<br><br>
	-- This is a no-op if the stack is empty or the section is not open.
	-- @param name Name of section to close. If <b>nil</b>, uses the current section.
	-- @param ... Close arguments.
	-- @see SectionGroup:Clear
	-- @see SectionGroup:Open
	function SectionGroup:Close (name, ...)
		local stack = self[_stack]

		-- Close the section if it was loaded.
		local where = name == nil and #stack or Find(stack, GetSection(self, name), true)

		if where and where > 0 then
			Remove(self, where, "close", false, ...)

			-- If the section was topmost, resume the lower section, if it exists.
			if where == #stack + 1 then
				Proc(stack[#stack], "resume")
			end
		end
	end

	---
	-- @return Current section name, or <b>nil</b> if the stack is empty.
	function SectionGroup:Current ()
		local stack = self[_stack]

		return Find(self[_sections], stack[#stack])
	end

	---
	-- @param name Section name.
	-- @return If true, the named section is somewhere in the stack.
	function SectionGroup:IsOpen (name)
		assert(name ~= nil)

		return not not Find(self[_stack], self[_sections][name], true)
	end

	--- Metamethod.
	-- @return Number of open sections.
	function SectionGroup:__len ()
		return #self[_stack]
	end

	--- Adds a section to the group.<br><br>
	-- If a section is already registered under <i>name</i>, it is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>old_proc("unload")</b></i><br><br>
	-- and replaced with the new one, which is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>proc("load", ...)</b></i>.
	-- @param name Section name.
	-- @param proc Section procedure, whose first parameter will be the current callback
	-- message; any others are input associated with the message.
	-- @param ... Load arguments.
	function SectionGroup:Load (name, proc, ...)
		assert(name ~= nil)
		assert(IsCallable(proc), "Uncallable proc")

		-- Unload any section already loaded under the given name.
		Proc(self[_sections][name], "unload")

		-- Install the section.
		self[_sections][name] = proc

		-- Load the section.
		proc("load", ...)
	end

	--- Opens a section and makes it current.<br><br>
	-- If another section is already current, it is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>other_proc("suspend")</b></i>.<br><br>
	-- If the new section is already open, it is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>proc("move")</b></i>.<br><br>
	-- The section is moved or pushed to the top of the stack, and finally called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>proc("open", ...)</b></i>.<br><br>
	-- This is a no-op if the section is already open and current.
	-- @param name Name of section to open.
	-- @param ... Open arguments.
	function SectionGroup:Open (name, ...)
		assert(name ~= nil)

		local stack = self[_stack]
		local section = GetSection(self, name)

		-- Proceed if the section is not already topmost, suspending any current section.
		local top = stack[#stack]

		if top ~= section then
			Proc(top, "suspend")

			-- If the section is already loaded, report the move.
			local where = Find(stack, section, true)

			if where then
				Remove(self, where, "move")
			end

			-- Push the section onto the stack.
			stack[#stack + 1] = section

			-- Open the section.
			section("open", ...)
		end
	end

	--- Sends a message to any section directly, called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>proc(what, ...)</b></i>.<br><br>
	-- The section need not be open.
	-- @param name Section name.
	-- @param what Message, which may be any non-<b>nil</b> value not used by
	-- <b>SectionGroup</b>'s methods.
	-- @param ... Message payload.
	-- @return Results of <i>proc</i>, if any.
	-- @see SectionGroup:__call
	function SectionGroup:Send (name, what, ...)
		assert(name ~= nil)
		assert(what ~= nil)
		assert(not Internal[what], "Cannot call proc with internal message")

		return GetSection(self, name)(what, ...)
	end

	--- Unloads all registered sections, removing them from the group in arbitrary order.<br><br>
	-- Each section is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>proc("unload", ...)</b></i>.
	-- @param ... Unload arguments.
	function SectionGroup:Unload (...)
		self[_stack] = {}

		for name, section in pairs(self[_sections]) do
			self[_sections][name] = nil

			section("unload", ...)
		end
	end

	--- Class constructor.
	function SectionGroup:__cons ()
		self[_sections] = {}
		self[_stack] = {}
	end
end)