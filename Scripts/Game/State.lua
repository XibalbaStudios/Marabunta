-- Standard library imports --
local assert = assert
local huge = math.huge
local next = next
local pairs = pairs

-- Modules --
local class = require("class")
local iterators = require("iterators")
local table_ops = require("table_ops")

---
--
--
--
--
module "game_state"

-- Standard variable families --
local Families = {}

-- Core family set --
local Core = {}

-- Build the families.
local NewFamily = class.InstanceMaker("VarFamily", 3)

for i, name in iterators.Args("global", "scene", "zone", "control") do
	Families[name] = NewFamily()
	Core[name] = i <= 3
end

--- Builds a wrapper that, when called, calls <i>func</i> with the current <b>global</b>,
-- <b>scene</b>, and <b>zone</b> variable families as input, plus some context, returning
-- any results.
-- @param func Function to wrap.
-- @param context Function context.
-- @return Wrapper function.
function BoundStateVarsFunc (func, context)
	return function()
		return func(Families.global, Families.scene, Families.zone, context)
	end
end

--- Variant of <b>BoundStateVarsFunc</b> which takes an argument in place of the common
-- context, returning any results.
-- @param func Function to wrap.
-- @return Wrapper function, which takes a single argument.
-- @see BoundStateVarsFunc
function BoundStateVarsFunc_Arg (func)
	return function(arg)
		return func(Families.global, Families.scene, Families.zone, arg)
	end
end

--- Multiple argument variant of <b>BoundStateVarsFunc_Arg</b> which takes varargs in place
-- of the common context, returning any results.
-- @param func Function to wrap.
-- @return Wrapper function, which takes multiple arguments.
-- @see BoundStateVarsFunc_Arg
function BoundStateVarsFunc_MultiArg (func)
	return function(...)
		return func(Families.global, Families.scene, Families.zone, ...)
	end
end

--- Gets the current version of a variable family.<br><br>
-- The global variables always remain intact. However, the scene and zone families are
-- replaced when one enters a new scene or zone, respectively.
-- TODO: Handle soft resets / reloads??
-- @param name Family name; one of <b>"global"</b>, <b>"scene"</b>, <b>"zone"</b>.
-- @return <a href="VarFamily.html">Variable family</a> belonging to <i>name</i>.
function GetStateVars (name)
	return assert(Families[name], "Invalid state vars family")
end

-- Named tiers --
local Tiers = table_ops.Invert{ "current", "checkpoint", "saved" }

-- Control state vars --
local ControlVars = GetStateVars("control")

-- Helper to process just core families
local function CoreFams (_, key)
	local family

	repeat
		key, family = next(Families, key)
	until key == nil or Core[key]

	return key, family
end

-- Promote all variables to "checkpoint" when you cross one.
ControlVars:GetDelegate("on_checkpoint"):AddAfter(function()
	for _, family in CoreFams do
		family:PropagateUpTo(Tiers.checkpoint)
	end
end)

-- Restore all checkpoint variables when you lose a life.
ControlVars:GetDelegate("on_lose_life"):AddAfter(function()
	for _, family in CoreFams do
		family:PropagateDownFrom(Tiers.checkpoint)
	end
end)

-- Restore all saved variables on game over.
ControlVars:GetDelegate("on_game_over"):AddAfter(function()
	for _, family in CoreFams do
		family:PropagateDownFrom(Tiers.saved)
	end
end)

-- Before entering a new scene, start a new variable family.
ControlVars:GetDelegate("on_enter_scene"):AddBefore(function()
	Families.scene = NewFamily()
end)

-- Before entering a new zone, start a new variable family.
ControlVars:GetDelegate("on_entering_zone"):AddAfter(function()
	Families.zone = NewFamily()
end)

-- Promote global variables to "saved" when you enter or leave a scene.
local function SaveGlobals ()
	Families.global:PropagateUpTo(Tiers.saved)
end

ControlVars:GetDelegate("on_enter_scene"):AddAfter(SaveGlobals)
ControlVars:GetDelegate("on_leave_scene"):AddAfter(SaveGlobals)

-- Update all timed variables during the game ticks.
ControlVars:GetDelegate("on_tick"):AddAfter(function(dt)
	for _, family in pairs(Families) do
		family:Update(dt)
	end
end)

-- Make a timer for the game clock that will not roll over in any reasonable amount of time.
ControlVars:GetTimer("clock"):Start(huge)