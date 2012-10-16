-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local pairs = pairs
local select = select
local messagef = messagef

-- Modules --
local class = require("class")
local func_ops = require("func_ops")
local table_ops = require("table_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local AssertArg_Pred = var_ops.AssertArg_Pred
local Copy = table_ops.Copy
local Define = class.Define
local IsCallable = var_preds.IsCallable
local IsTable = var_preds.IsTable
local New = class.New
local NoOp = func_ops.NoOp
local SuperCons = class.SuperCons
local Type = class.Type
local Weak = table_ops.Weak

--- An assortment of primitives useful in building widgets.
module "widget_ops"


--- Apply a rect policy.
-- @param policy Policy to apply ( unit, unit_reverse, center, reverse )
-- @param value Widget's coordinate (or dimention) to apply the policy to.
-- @param ref Reference value ( usually the parent's dimention ) 
-- @param dim widget's dimention ( h o w )
-- @return Value with the policy applied.
function ApplyPolicy( policy, value, ref, dim )
	if policy == "unit" or policy == "unit_reverse" then
		value = value * ref
	elseif policy == "center" then
		return ((ref - dim) / 2)
	elseif policy == "center_offset" then
		return ((ref - dim) / 2) + (value or 0 )
	elseif policy ~= "reverse" then
		return value
	end

	if policy ~= "unit" then
		value = ref - (value + dim)
	end

	return value
end

--- Reverse-Apply a rect policy. The function recieves the result value of a policy and returns the
-- original
-- @param policy Policy to apply ( unit, unit_reverse, reverse, center ).
-- @param value Widget's coordinate (or dimention) that has a policy aplied to.
-- @param ref Reference value ( usually the parent's dimention ) 
-- @param dim widget's dimention ( h o w )
-- @return Original value.
function ApplyReversePolicy( policy, value, ref, dim )
	if policy == "unit_reverse" or policy == "reverse" then
		value = ref - ( value + dim )
	end
	if policy == "unit" or policy == "unit_reverse" then
		value = value / ref
	elseif policy == "center_offset" then
		value = value - ( ( ref - dim ) / 2 )
	end

	return value
end

-- Augments a signal handler
-- O: Signalable object
-- how: Augmentation style
-- signal: Signal to augment
-- func: Function to add
-- defcore: Optional default core
-- Returns: Augmented function handle
-- TODO: Move this into Support??
function AugmentSignal (O, how, signal, func, defcore)
	local slot = O:GetSlot(signal) or defcore or NoOp

	-- If the slot is not yet augmented, make it so.
	if Type(slot) ~= "Delegate" then
		slot = New("Delegate", slot)
	end

	-- Attach the new function as appropriate.
	assert(how == "after" or how == "before", "Unsupported augmentation style")

	if how == "after" then
		slot:AddAfter(func)
	else
		slot:AddBefore(func)
	end

	-- Install the slot.
	O:SetSlot(signal, slot)

	-- Supply the function in case more is to be done with it.
	return slot
end

--- Renders a widget that behaves like a button. This will draw one of these pictures with
-- rect (x, y, w, h), based on the current widget state: <b>"main"</b>, <b>"grabbed"</b>,
-- or <b>"entered"</b>.
-- @param W Widget handle.
-- @param x Rect x-coordinate.
-- @param y Rect y-coordinate.
-- @param w Rect width.
-- @param h Rect height.
-- @param group Current group.
function ButtonStyleRender (W, x, y, w, h, group)
	local picture = "main"
	local is_grabbed = W == group:GetGrabbed()
	local is_entered = W == group:GetEntered()
	local is_focused = W.IsFocused ~= nil and W:IsFocused()

	if is_grabbed and is_entered then
		picture = "grabbed"
	elseif is_entered then
		picture = "entered"
	elseif is_focused then
		-- TODO: maybe add a focused picture as something standard
		picture = "entered"
	end
	W:DrawPicture(picture, x, y, w, h)
end

do
	-- Owners of owned widgets --
	local Owners = Weak("v")

	-- Returns: Owner handle
	local function GetOwner (W)
		return Owners[W]
	end

	--
	local function Decorate (t, type_key)
		local cons = NoOp

		t.GetOwner = GetOwner

		if t.__cons ~= nil then
			cons = AssertArg_Pred(IsCallable, t.__cons, "Uncallable constructor")
		end

		function t:__cons (key, owner, ...)
			assert(key == type_key, "Invalid key: instantiation forbidden")

			SuperCons(self, "Widget")

			-- Perform type-specific construction.
			cons(self, owner, ...)

			-- Bind owner.
			Owners[self] = owner
		end

		return t
	end

	--- Defines an owned proxy widget class.
	-- @param name Class name.
	-- @param members Members table; will be a dummy table if absent.<br><br>
	-- If provided, a constructor will follow some boilerplate logic.
	-- @param params Non-default params; will be a dummy table if absent.
	-- @return Type name.
	function DefineOwnedWidget (name, members, params)
		assert(name ~= nil, "Invalid class name")
		assert(members == nil or IsTable(members) or IsCallable(members), "Invalid members")
		assert(params == nil or IsTable(params), "Invalid params")

		-- Create a local copy of the params and set necessary values.
		params = params and Copy(params) or {}

		params.base = "Widget"

		--
		local type_key = {}

		if IsCallable(members) then
			Define(name, function(ow)
				members(ow)

				Decorate(ow, type_key)
			end, params)

		else
			Define(name, Decorate(members and Copy(members) or {}, type_key), params)
		end

		return type_key
	end
end

do
	local function FindInChildrenByName( parent , name )
		for child in parent:AttachListIter() do
			if child:GetName() == name then
				return child
			else
				local w = FindInChildrenByName( child , name )
				if w then
					return w
				end
			end
		end 
	end

	function FindByName( widgetGroup, name )
		local root = widgetGroup:GetRoot()
		if root:GetName() and root:GetName() == name then
			return root
		else
			local w = FindInChildrenByName( root, name )
			if w then
				return w
			end
		end

	end
end

function GetRawCoords( widget, x, y, w, h , pw, ph )
	local pol_x, pol_y, pol_w, pol_h = widget:GetRectPolicies ()		
	x =  pol_x ~= "normal" and ApplyReversePolicy( pol_x, x, pw, w ) or x
	y =  pol_y ~= "normal" and ApplyReversePolicy( pol_y, y, ph, h ) or y
	w =  pol_w ~= "normal" and ApplyReversePolicy( pol_w, w, pw ) or w
	h =  pol_h ~= "normal" and ApplyReversePolicy( pol_h, h, ph ) or h
	return x, y, w, h
end

-- Detach all children from a widget.
-- W: Widget handle.
-- TODO: Move to Support??
function PurgeAttachList (W)
	repeat
		local widget = W:GetAttachListHead()

		if widget then
			widget:Detach()
		end
	until not widget
end

--- Assigns local rect fields.
-- @param W Widget handle.
-- @param x Local x-coordinate to assign.
-- @param y Local y-coordinate to assign.
-- @param w Width to assign.
-- @param h Height to assign.
function SetLocalRect (W, x, y, w, h)
	W:SetX(x)
	W:SetY(y)
	W:SetW(w)
	W:SetH(h)
end

--- Performs a state switch, with an optional in-between action.<br><br>
-- On a switch, the widget will be sent a signal as<br><br>
-- &nbsp&nbsp&nbsp<b><i>switch_from(W, what)</i></b>,<br><br>
-- where <i>W</i> will refer to the current widget and <i>what</i> is
-- some value related to the switch. The action is then performed. Then, the widget will
-- be sent a signal as<br><br>
-- &nbsp&nbsp&nbsp<b><i>switch_to(W, what)</i></b>,<br><br>
-- with <i>W</i> and <i>what</i> the same as before.<br><br>
-- @param W Widget handle.
-- @param do_switch If true, perform the switch.
-- @param always_refresh If true, the <b>"switch_to"</b> logic is still performed even
-- if the state did not change.
-- @param action Embedded action; this will be a no-op if absent.
-- @param what Action description.
-- @param arg Action argument.
function StateSwitch (W, do_switch, always_refresh, action, what, arg)
	if do_switch then
		W:Signal("switch_from", what)

		;(action or NoOp)(W, arg)

		W:Signal("switch_to", what)

	elseif always_refresh then
		W:Signal("switch_to", what)
	end
end

do
	-- Enumeration helper
	local function NextOp (ops, count, name, ...)
		if count > 0 then
			return AssertArg_Pred(IsCallable, ops[name], "Invalid operation"), NextOp(ops, count - 1, ...)
		end
	end

	---
	-- @param W
	-- @param ...
	-- @return
	function GetStringOps (W, ...)
		local font = W:GetFont()

		return NextOp(font and font:GetOps() or string, select("#", ...), ...)
	end

	-- Intermediate properties --
	local Props = {}

	-- Helper for common string operation
	-- func: Internal function
	-- W: Widget handle
	-- str: String to process
	-- ...: Operation arguments
	-- Returns: Function return values
	local function WithFontAndStr (func, W, str, ...)
		local font = W:GetFont()
		local ret1, ret2

		if font and str then
			font:SetLookupKey(W)

			ret1, ret2 = func(W, str, font, ...)

			font:SetLookupKey(nil)
		end

		return ret1, ret2
	end

	-- Draw string helper
	local function AuxDrawString (W, str, font, halign, valign, x, y, w, h, color, shadow_color)
		-- Adjust the coordinates to match the alignment.
		local dx, dy = font:GetAlignmentOffsets(str, w, h, halign, valign)

		x, y = x + dx, y + dy

		-- Draw any shadow string.
		local sx, sy = W:GetShadowOffsets()

		if sx ~= 0 or sy ~= 0 then
			Props.color = W:GetColor(shadow_color or "shadow")

			font(str, x + sx, y + sy, Props)
		end

		-- Draw the main string.
		Props.color = W:GetColor(color or "string")

		font(str, x, y, Props)

		-- Clear the settings.
		Props.color = nil
	end

	--- Renders a string, with optional shadowing.
	-- @param W Widget handle.
	-- @param str String to draw.
	-- @param halign Horizontal alignment, which may be one of the following: <b>"left"</b>,
	-- <b>"center"</b>, or <b>"right"</b>; if absent, <b>"left"</b> is assumed.
	-- @param valign Vertical alignment, which may be one of the following: <b>"top"</b>,
	-- <b>"center"</b>, or <b>"bottom"</b>; if absent, <b>"top"</b> is assumed.
	-- @param x Draw position x-coordinate.
	-- @param y Draw position y-coordinate.
	-- @param w Width, used for non-<b>"left"</b> alignment.
	-- @param h Height, used for non-<b>"top"</b> alignment.
	-- @param color Name of string color; if <b>nil</b>, <b>"string"</b> is used.
	-- @param shadow_color Name of shadow color; if <b>nil</b>, <b>"shadow"</b> is used.
	function DrawString (W, str, halign, valign, x, y, w, h, color, shadow_color)
		WithFontAndStr(AuxDrawString, W, str, halign, valign, x, y, w, h, color, shadow_color)
	end

	-- Height helper
	local function AuxGetH (_, str, font, with_padding)
		return font:GetHeight(str, with_padding)
	end

	--- Information.
	-- @param W Widget handle.
	-- @param str String to measure.
	-- @param with_padding If true, include line padding.
	-- @return String height.
	function StringGetH (W, str, with_padding)
		return WithFontAndStr(AuxGetH, W, str, with_padding) or 0
	end

	-- Size helper
	local function AuxGetSize (_, str, font, with_padding)
		return font:GetWidth(str), font:GetHeight(str, with_padding)
	end

	--- Information.
	-- @param W Widget handle.
	-- @param str String to measure.
	-- @param with_padding If true, include line padding.
	-- @return String dimensions.
	function StringSize (W, str, with_padding)
		local w, h = WithFontAndStr(AuxGetSize, W, str, with_padding)

		return w or 0, h or 0
	end

	-- Width helper
	local function AuxGetW (_, str, font)
		return font:GetWidth(str)
	end

	--- Information.
	-- @param W Widget handle.
	-- @param str String to measure.
	-- @return String width.
	function StringGetW (W, str)
		return WithFontAndStr(AuxGetW, W, str) or 0
	end
end