-- Standard library imports --
local format = string.format
local tostring = tostring

-- Modules --
local em = require("entity_manager")
local mc = require("metacompiler")
local objects_helpers = require("game_objects_helpers")

-- 
local function GlobalAlert (alert, payload)
	-- TODO: Logic!!
end

--
local function ReadAlert (_, avar, var)
	local alert, type, global, pstring = em.PushAlertVar(avar)
	local extra = ""

	-- String payload --
	if pstring then
		extra = format(", %q", pstring)

	-- Boolean payload --
	elseif type ~= "None" then
		extra = format(", %s", tostring(type == "True"))
	end

	--
	if global then
		mc.Declare("global_receiver", em.GetGlobalReceiver)

		var = "global_receiver()"
	end

	mc.Declare("em_alert", em.Alert)

	return format("em_alert(%s, %q%s)", var or "object", alert, extra)
end

-- Alert_ActionComponent_cl reader --
objects_helpers.DefineReader("Alert_ActionComponent_cl", ReadAlert)

-- Alert_ConditionComponent_cl reader --
objects_helpers.DefineReader("Alert_ConditionComponent_cl", function(_, avar, negate, var)
	return (negate and "not " or "") .. ReadAlert(_, avar, var)
end)