-- Standard library imports --
local format = string.format

-- Modules --
local em = require("entity_manager")
local mc = require("metacompiler")
local objects_helpers = require("game_objects_helpers")
local var_preds = require("var_preds")

--
local function Call (func, object, gvars, svars, zvars)
	if var_preds.IsCallable(func) then
		return func(object, gvars, svars, zvars)
	end
end

--
local function GetFamilyFunc (family, name)
	return family:PeekDelegate(name) or family:GetRaw(name)
end

--
local function CallFunc (object, family, name, gvars, svars, zvars)
	return Call(GetFamilyFunc(family, name), object, gvars, svars, zvars)
end

--
local function ScriptFunc (object, name, gvars, svars, zvars)
	return Call(em.GetScriptFunc(object, name), object, gvars, svars, zvars)
end

-- --
local CallInstance = 0

--
local function ReadCall (context, cvar)
	local from_script, arg, bake = em.PushCallVar(cvar)

	--
	if bake then
		local func

		-- --
		-- arg: name
		if from_script then
			func = em.GetScriptFunc(context, arg)

		-- --
		-- arg: bvar
		else
			func = GetFamilyFunc(em.PushBaseVar(arg))
		end

		--
		if func then
			local name = format("call%i", CallInstance)

			CallInstance = CallInstance + 1

			return format("%s(object, GlobalVars, SceneVars, ZoneVars)", mc.Declare(name, func))
		end

		--
		return "false"

	--
	else
		-- --
		-- arg: name
		if from_script then
			mc.Declare("script_func", ScriptFunc)

			return format("script_func(object, %q, GlobalVars, SceneVars, ZoneVars)", arg)

		-- --
		-- arg: bvar
		else
			local family, name = em.PushBaseVar(arg)

			mc.Declare("call_func", CallFunc)

			return format("call_func(object, %s, %s, GlobalVars, SceneVars, ZoneVars)", family, name)
		end
	end
end

-- Call_ActionComponent_cl reader --
objects_helpers.DefineReader("Call_ActionComponent_cl", ReadCall)

-- Call_ConditionComponent_cl reader --
objects_helpers.DefineReader("Call_ConditionComponent_cl", function(context, cvar, negate)
	return (negate and "not " or "") .. ReadCall(context, cvar)
end)