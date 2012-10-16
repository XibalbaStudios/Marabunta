-- Standard library imports --
local assert = assert
local format = string.format
local insert = table.insert
local tostring = tostring

-- Modules --
local em = require("entity_manager")
local func_ops = require("func_ops")
local game_state = require("game_state")
local iterators = require("iterators")
local mc = require("metacompiler")
local table_ops = require("table_ops")
local var_preds = require("var_preds")

-- Cached routines --
local _ReadElement_

---
--
module "game_objects_helpers"

-- Control state vars --
local ControlVars = game_state.GetStateVars("control")

-- Global substitions for variable interpolation --
do
	-- Helper to generate the current gensym
	local function Gensym ()
		local index = ControlVars:GetNumber("gensym")

		return format("\a!%i!\a", index)
	end

	-- 'GENSYM' variable
	mc.AddGlobalVarInterpolation("GENSYM", function()
		ControlVars:IncNumber("gensym")

		return Gensym()
	end)

	-- 'ID' variable
	mc.AddGlobalVarInterpolation("ID", function()
		mc.Declare("get_unique_id_string", em.GetUniqueIdString)

		return "%s", "get_unique_id_string(object)"
	end)

	-- 'LAST_GENSYM' variable
	mc.AddGlobalVarInterpolation("LAST_GENSYM", function()
		return Gensym()
	end)
end

do
	-- Enter scene / zone function lists --
	local EnterSceneFuncs = {}
	local EnterZoneFuncs = {}

	-- Free resources function list --
	local FreeResourcesFuncs = {}

	-- --
	local Contexts = {}

	--- 
	-- @param what
	-- @param type
	function BindTypeAsContextID (what, type)
		local options = Contexts[what]

		assert(options ~= nil, "Type never set up")
		assert(options ~= true, "Type context already registered")

		if options then
			mc.RegisterCompileContext(type, options.subs, options.prologue_builder, options.epilogue_builder)
		end

		Contexts[what] = true
	end

	---
	-- @param what
	-- @param options
	function SetupType (what, options)
		assert(what ~= nil, "Nil type")
		assert(Contexts[what] == nil, "Type already set up")
		assert(var_preds.IsTableOrNil(options), "Invalid options table")

		--
		Contexts[what] = options and table_ops.Copy(options) or false
	end

	-- Commit objects on entering a scene or zone.
	ControlVars:GetDelegate("on_enter_scene"):AddAfter(function()
game_state.GetStateVars("scene"):SetNumber("Twee", 3)
game_state.GetStateVars("zone"):SetNumber("Mirble", 4)
game_state.GetStateVars("scene"):GetTimer("meep!")
game_state.GetStateVars("scene"):GetTimer("meep!"):Start(3)
		em.CommitObjects(false)
	end)

	ControlVars:GetDelegate("on_enter_zone"):AddAfter(function()
		em.CommitObjects(true)
	end)

	-- Free resources on leaving a scene or zone.
	ControlVars:GetDelegate("on_free_scene_resources"):AddAfter(function()
		em.CleanUpObjects(false)
	end)

	ControlVars:GetDelegate("on_free_zone_resources"):AddAfter(function()
		em.CleanUpObjects(true)

		-- Clean up metacompiler state.
		mc.CleanUp()
	end)
end

-- Element readers --
do
	local Readers = {}

	---
	-- @param what
	-- @param reader
	function DefineReader (what, reader)
		assert(var_preds.IsCallable(reader), "Uncallable reader")

		Readers[what] = reader
	end

	---
	-- @param context
	-- @param what
	-- @param ...
	-- @return
	function ReadElement (context, what, ...)
		return assert(Readers[what], "Invalid reader")(context, ...)
	end

	---
	-- @param context
	-- @param object
	function ReadObject (context, object)
		return _ReadElement_(context, em.GetClassName(object), em.Push(object))
	end

	--
	-- Annotates an object for debug info
	mc.SetAnnotateFunc(function(object, type, name, key)
		type = name and format("%s: ", type) or type
		name = name or ""

		if key then
			return format("%s = %s, key = %s; %s%q", em.GetClassName(object), tostring(object), tostring(key), type, name)
		else
			return format("%s; %s%s", em.GetTypeName(object), type, name)
		end
	end)

	--
	mc.SetReadObjectFunc(ReadObject)
end

-- Cache some routines.
_ReadElement_ = ReadElement