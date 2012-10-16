-- Standard library imports --
local format = string.format
local tostring = tostring
local type = type

-- Modules --
local em = require("entity_manager")
local iterators = require("iterators")
local lazy_ops = require("lazy_ops")
local mc = require("metacompiler")
local objects_helpers = require("game_objects_helpers")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- --
local Cache = {}

--
local function ProcessArgs (context, ...)
	local count = var_ops.CollectArgsInto(Cache, ...)

	for i = 1, count do
		Cache[i] = objects_helpers.ReadObject(context, Cache[i])
	end

	return var_ops.UnpackAndWipe(Cache, count, false)
end

-- ActionNode_cl reader --
objects_helpers.DefineReader("ActionNode_cl", ProcessArgs)

-- ConditionNode_cl reader --
objects_helpers.DefineReader("ConditionNode_cl", function(context, comp)
	return objects_helpers.ReadObject(context, comp)
end)

-- --
local Connectives = {
	And = "%s and %s",
	Or = "%s or %s",
	NAnd = "not (%s) or not (%s)",
	NOr = "not (%s) and not (%s)",
	Xor = "not (%s) ~= not (%s)",
	Iff = "not (%s) == not (%s)",
	Implies = "not (%s) or %s",
	NImplies = "%s and not (%s)",
	ConverseImplies = "%s or not (%s)",
	NConverseImplies = "not (%s) and %s"
}

-- BinaryConditionNode_cl reader --
objects_helpers.DefineReader("BinaryConditionNode_cl", function(context, a, b, conn)
	return format(Connectives[conn], objects_helpers.ReadObject(context, a), objects_helpers.ReadObject(context, b))
end)

-- CompoundConditionNode_cl reader --
objects_helpers.DefineReader("CompoundConditionNode_cl", function(context, expr, ...)
	return format(expr, ProcessArgs(context, ...))
end)

-- BaseVar reader --
objects_helpers.DefineReader("BaseVar", function(_, bvar, interp)
	local family, name = em.PushBaseVar(bvar)
	local is_family = family ~= "ObjectProperty" and family ~= "GlobalProperty"

	return is_family and format("%sVars", family), interp and mc.InterpVar(name) or format("%q", name), family == "GlobalProperty"
end)

-- Copy_ActionComponent_cl reader --
objects_helpers.DefineReader("Copy_ActionComponent_cl", function(_, var_type, from, to)
	local ffamily, fname = objects_helpers.ReadElement(_, "BaseVar", from, true)
	local tfamily, tname = objects_helpers.ReadElement(_, "BaseVar", to, true)

	return format("%s:Set%s(%s, %s:Get%s(%s))", tfamily, var_type, tname, ffamily, var_type, fname)
end)

--
local function OutputDelegate (delegate)
	if not delegate then
		return "nil"
	else
		return format("Core = %s", tostring(delegate:GetCore()))
	end
end

--
local function OutputNumber (num)
	return format(var_preds.IsInteger(num) and "%i" or "%f", num)
end

--
local function OutputTimer (timer)
	if not timer then
		return "nil"
	elseif timer:GetDuration() then
		return format("Counter = %f, Duration = %f, Paused = %s", timer:GetCounter(), timer:GetDuration(), tostring(timer:IsPaused()))
	else
		return "Stopped"
	end
end

-- OutputVar_ActionComponent_cl reader --
objects_helpers.DefineReader("OutputVar_ActionComponent_cl", function(_, bvar, var_type, op)
	local family, name = objects_helpers.ReadElement(_, "BaseVar", bvar, true)

	if op == "Print" then
		op = mc.Declare("print_var", printf)
	elseif op == "Message" then
		op = mc.Declare("message_var", messagef)
	end

	-- 
	local decl

	if var_type == "Bool" or var_type == "Raw" then
		decl = mc.Declare("tostring", tostring)
	elseif var_type == "Number" then
		decl = mc.Declare("output_number", OutputNumber)
	elseif var_type == "Delegate" then
		decl = mc.Declare("output_delegate", OutputDelegate)
	elseif var_type == "Timer" then
		decl = mc.Declare("output_timer", OutputTimer)
	end

	--
	local prefix = (var_type == "Delegate" or var_type == "Timer") and "Peek" or "Get"

	return format([[%s("%s<%s, " .. %s .. ">: " .. %s(%s:%s%s(%s)))]], op, var_type, family, name, decl, family, prefix, var_type, name)
end)

-- Per-type property lookup functions --
local Lookups = lazy_ops.MakeOnDemand(function(def)
	local kind = type(def)
	local alert = "get_property:" .. kind

	return {
		name = "lookup_" .. kind,
		func = function(object, name)
			local prop = object and em.Alert(object, alert, name)

			if type(prop) == kind then
				return prop
			else
				return def
			end
		end
	}
end)

-- Property reader --
objects_helpers.DefineReader("Property", function(_, name, def, var)
	local lookup = Lookups[def]

	if var == true then
		var = mc.Declare("global_receiver", em.GetGlobalReceiver) .. "()"
	end

	return format("%s(%s, %s)", mc.Declare(lookup.name, lookup.func), var or "object", name)
end)