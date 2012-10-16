-- Standard library imports --
local format = string.format
local type = type

-- Modules --
local objects_helpers = require("game_objects_helpers")

--
local function ReadBool (_, bvar, op, interp, extra)
	local family, name, global = objects_helpers.ReadElement(_, "BaseVar", bvar, interp)

	if family then
		return format("%s:%s(%s%s)", family, op, name, extra or "")
	else
		return objects_helpers.ReadElement(_, "Property", name, false, global)
	end
end

-- AssignBool_ActionComponent_cl reader --
objects_helpers.DefineReader("AssignBool_ActionComponent_cl", function(_, bvar, op, ref_key, node)
	local extra

	if op == "SetFromCondition" then
		op = "SetBool"
		extra = format(", %s", objects_helpers.ReadObject(_, node))
-- TODO: Use ref_key... how???
	end

	return ReadBool(_, bvar, op, false, extra)
end)

-- Bool_ConditionComponent_cl reader --
objects_helpers.DefineReader("Bool_ConditionComponent_cl", function(_, bvar, op)
	return ReadBool(_, bvar, op, true)
end)