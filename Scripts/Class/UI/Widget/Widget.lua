-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- Base class of UI elements.<br><br>
-- A new <b>Widget</b> is given some stock render and text behavior, which can be replaced.<br><br>
-- Class. Derives from <b><a href="Signalable.html">Signalable</a></b>.
module Widget
]]

-- Standard library imports --
local assert = assert
local next = next
local pairs = pairs

-- Imports --
local ApplyPolicy = widget_ops.ApplyPolicy
local CallOrGet = func_ops.CallOrGet
local Identity = func_ops.Identity
local IsType = class.IsType
local MemberTable = lazy_ops.MemberTable
local NoOp = func_ops.NoOp
local PointInBox = numeric_ops.PointInBox
local SetLocalRect = widget_ops.SetLocalRect
local SuperCons = class.SuperCons

-- Callback permissions --
local Permissions = table_ops.MakeSet{ "attach_list_render", "attach_list_test", "attach_list_update", "render", "test", "update" }

-- Unique member keys --
local _bh = {}
local _bw = {}
local _colors = {}
local _font = {}
local _h = {}
local _h_policy = {}
local _is_root = {}
local _mode = {}
local _name = {}
local _pictures = {}
local _string = {}
local _subscriptions = {}
local _sx = {}
local _sy = {}
local _vx = {}
local _vy = {}
local _w = {}
local _w_policy = {}
local _x = {}
local _x_policy = {}
local _y = {}
local _y_policy = {}

-- Widget class definition --
class.Define("Widget", function(Widget)
	--- Assigns widget callback permissions. These determine whether widgets or their attach
	-- lists are run during <b>WidgetGroup:Execute</b>, <b>WidgetGroup:Render</b>, and <b>
	-- WidgetGroup:Update</b>.<br><br>
	-- Note that, if only the regular permission is disabled for a given operation, the
	-- attach list will still be run.
	-- @param what Permission type, which may be one of the following:<br><br>
	-- <b>"attach_list_render"</b>, <b>"attach_list_test"</b>, <b>"attach_list_update"</b>,
	-- <b>"render"</b>, <b>"test"</b>, <b>"update"</b>.
	-- @param allow If true, allow callback.
	-- @see Widget:IsAllowed
	function Widget:Allow (what, allow)
		if Permissions[what] then
			self[what] = not allow and true or nil
		end
	end

	-- Widget-specific attach list ops --
	local AttachListOps = attach_list_ops.Build("Widget")

	--
	local function PropagateMode (W, mode)
		for widget in AttachListOps.list_iter(W) do
			PropagateMode(widget, mode)
		end

		W[_mode] = mode
	end

	-- Attach helper
	local function AuxAttach (parent, widget, is_new_parent, x, y, w, h)
		SetLocalRect(widget, x, y, w, h)

		if is_new_parent then
			widget:Signal("attach")
			parent:Signal("attached_to")

			PropagateMode(widget, parent[_mode])
		end
	end

	--- Adds a widget to this widget's attach list, and sets its local rect as a
	-- convenience.<br><br>
	-- If the widget is already attached to another parent, it is first detached, with the
	-- associated behavior.<br><br>
	-- If the widget is not already in the attach list, it is appended.<br><br>
	-- The widget's local rect is then assigned, using the passed input.<br><br>
	-- If the widget was not already in the attach list, it gets sent an <b>"attach"</b>
	-- signal with no arguments, and this widget gets sent an <b>"attached_to"</b> signal,
	-- also without arguments.
	-- @param widget Widget to attach.
	-- @param x Local x-coordinate to assign.
	-- @param y Local y-coordinate to assign.
	-- @param w Width to assign.
	-- @param h Height to assign.
	-- @see Widget:Detach
	-- @see Widget:IsAttached
	function Widget:Attach (widget, x, y, w, h)
	    assert(not self[_mode] or self[_mode]() == "normal", "Attaching forbidden from callbacks / event issues")
		assert(not widget[_is_root], "Cannot attach root widget")

		AttachListOps.attach(self, widget, AuxAttach, x, y, w, h)
	end

	--- Iterates across the widget's attach list.
	-- @param reverse If true, iterate back-to-front.
	-- @return Iterator, which returns a widget per iteration.
	-- @see Widget:GetAttachListBack
	-- @see Widget:GetAttachListHead
	Widget.AttachListIter = AttachListOps.list_iter

	--- Iterates from this widget up the chain of parents.
	-- @return Iterator, which returns a widget handle at each iteration.
	Widget.ChainIter = AttachListOps.chain_iter

	-- Detach helper
	local function AuxDetach (widget, parent)
		parent:Signal("detached_from", widget)
		widget:Signal("detach")

		PropagateMode(widget, nil)
	end

	--- Detaches the widget from its parent.<br><br>
	-- If the widget is not attached, this is a no-op.<br><br>
	-- Otherwise, the parent widget is first sent a <b>"detached_from"</b> signal, with
	-- this widget as its argument, and this widget receives a <b>"detach"</b> signal
	-- with no arguments. The widget is then removed from the parent's attach list.
	-- @see Widget:Attach
	-- @see Widget:IsAttached
	function Widget:Detach ()
		assert(not (self[_mode] or NoOp)("is_running_callbacks"), "Detaching forbidden from callbacks")

		AttachListOps.detach(self, AuxDetach)
	end

	--- Draws a widget picture with rect (x, y, w, h).<br><br>
	-- If the widget has a color associated with the picture name, this is assigned to the
	-- picture's <b>"color"</b> property during the draw call.<br><br>
	-- This is a no-op if the picture does not exist.
	-- @param name Picture name.
	-- @param x Rect x-coordinate.
	-- @param y Rect y-coordinate.
	-- @param w Rect width.
	-- @param h Rect height.
	-- @see Widget:GetPicture
	-- @see Widget:SetPicture
	function Widget:DrawPicture (name, x, y, w, h)
		local pictures = self[_pictures]

		if pictures then
			local picture = CallOrGet(pictures[name])

			if picture then
				-- If a color override is specified, cache the picture's current color property
				-- and apply the override.
				local color = self:GetColor(name)
				local save

				if color then
					save = picture:GetProperty("color")

					picture:SetProperty("color", color)
				end

				-- Render the picture.
				picture:Draw(x, y, w, h)

				-- Restore original color if it was overridden.
				if color then
					picture:SetProperty("color", save)
				end
			end
		end
	end



	-- Widget rectangle helper
	local function GetRect (W, pw, ph)
		local w = ApplyPolicy(W[_w_policy], W:GetW(), pw)
		local h = ApplyPolicy(W[_h_policy], W:GetH(), ph)
		local x = ApplyPolicy(W[_x_policy], W:GetX(), pw, w)
		local y = ApplyPolicy(W[_y_policy], W:GetY(), ph, h)

		return x, y, w, h
	end

	-- Helper to accumulate relative positions up the chain
	local function GetParentRect (W, bottom)
		--
		local parent = AttachListOps.get_parent(W)

		if parent then
			local px, py, pw, ph = GetParentRect(parent)
			local wx, wy, ww, wh = GetRect(W, pw, ph)

			if not bottom then
				local vx, vy = W:GetViewOrigin()

				wx, wy = wx - vx, wy - vy
			end

			return px + wx, py + wy, ww, wh

		--
		else
			return W:GetX(), W:GetY(), W:GetW() or 0, W:GetH() or 0
		end
	end

	--- Gets the widget's absolute rectangle, taking view origins into account. This is
	-- computed from the <b>GetX</b>, <b>GetY</b>, <b>GetW</b>, and <b>GetH</b> methods
	-- of the widgets along the chain of parents.<br><br>
	--
	-- @return x, y, w, h of final rectangle.
	-- @see Widget:ChainIter
	-- @see Widget:GetX
	-- @see Widget:GetY
	-- @see Widget:GetW
	-- @see Widget:GetH
	-- @see Widget:GetRect
	-- @see Widget:SetRectPolicy
	-- @see Widget:SetViewOrigin
	function Widget:GetAbsoluteRect ()
		assert(self[_mode], "Widget must be rooted")

		return GetParentRect(self, true)
	end

	---
	-- @return Widget handle, or <b>nil</b> if the attach list is empty.
	-- @see Widget:GetAttachListHead
	Widget.GetAttachListBack = AttachListOps.get_back

	---
	-- @return Widget handle, or <b>nil</b> if the attach list is empty.
	-- @see Widget:GetAttachListBack
	Widget.GetAttachListHead = AttachListOps.get_head

	---
	-- @return Border width; 0 by default.
	-- @return Border height; 0 by default.
	function Widget:GetBorder ()
		return self[_bw] or 0, self[_bh] or 0
	end

	-- Getter choice helper
	local function Getter (raw)
		return raw and Identity or CallOrGet
	end

	-- Getter helper
	local function LazyGet (W, member, k, raw)
		return (Getter(raw)(MemberTable(W, member)[k]))
	end

	--- Gets a widget color.<br><br>
	-- If a color is a function or callable object, it will be called and the result will
	-- be returned as the color.
	-- @param name Color name.
	-- @param raw If true, get the object passed to <b>Widget:SetColor</b>.
	-- @return Color, or <b>nil</b> if not available.
	-- @see Widget:SetColor
	function Widget:GetColor (name, raw)
		return LazyGet(self, _colors, name, raw)
	end

	---
	-- @return Font handle, or <b>nil</b> if absent.
	-- @see Widget:SetFont
	function Widget:GetFont ()
		return self[_font]
	end

	---
	-- @return Raw height.
	-- @see Widget:SetH
	function Widget:GetH ()
		return self[_h]
	end
	
	function Widget:GetName()
		return self[_name]
	end

	--- Dummy ownership (a no-op), to be overridden by widgets that need it.
	-- @class function
	-- @name Widget:GetOwner
	Widget.GetOwner = func_ops.NoOp

	---
	-- @return Parent widget handle, or <b>nil</b> if the widget is unattached.
	-- @see Widget:Attach
	-- @see Widget:IsAttached
	Widget.GetParent = AttachListOps.get_parent

	--- Gets a widget picture.<br><br>
	-- If a picture is a function or callable object, it will be called and the result will
	-- be returned as the picture.
	-- @param name Picture name.
	-- @param raw If true, get the object passed to <b>Widget:SetPicture</b>.
	-- @return Picture, or <b>nil</b> if not available.
	-- @see Widget:DrawPicture
	-- @see Widget:SetPicture
	function Widget:GetPicture (name, raw)
		return LazyGet(self, _pictures, name, raw)
	end

	--- Gets the widget's local rectangle. This is computed from the <b>GetX</b>, <b>GetY
	-- </b>, <b>GetW</b>, and <b>GetH</b> methods.
	-- @class function
	-- @name Widget:GetRect
	-- @return x, y, w, h of rectangle.
	-- @see Widget:GetAbsoluteRect
	-- @see Widget:GetX
	-- @see Widget:GetY
	-- @see Widget:GetW
	-- @see Widget:GetH
	-- @see Widget:SetRectPolicy
	Widget.GetRect = GetRect

	---
	-- @return x, y, width, height policies.
	-- @see Widget:SetRectPolicy
	function Widget:GetRectPolicies ()
		return self[_x_policy] or "normal", self[_y_policy] or "normal", self[_w_policy] or "normal", self[_h_policy] or "normal"
	end

	---
	-- @return Shadow x-offset; 0 by default.
	-- @return Shadow y-offset; 0 by default.
	-- @see Widget:SetShadowOffsets
	function Widget:GetShadowOffsets ()
		return self[_sx] or 0, self[_sy] or 0
	end

	--- Gets the widget's string.<br><br>
	-- If this is a function or callable object, it will be called as <b>get(font)</b>,
	-- where <i>font</i> is the widget's font (or <b>nil</b> if absent), and the result
	-- will be returned as the string.
	-- @param raw If true, get the object passed to <b>Widget:SetString</b>.
 	-- @return Widget string, or <b>nil</b> if absent.
	-- @see Widget:SetString
	function Widget:GetString (raw)
		return (Getter(raw)(self[_string], self[_font]))
	end

	---
	-- @return View origin x-coordinate; 0 by default.
	-- @return View origin y-coordinate; 0 by default.
	-- @see Widget:SetViewOrigin
	function Widget:GetViewOrigin ()
		return self[_vx] or 0, self[_vy] or 0
	end

	---
	-- @return Raw width.
	-- @see Widget:SetW
	function Widget:GetW ()
		return self[_w]
	end

	---
	-- @return Raw local x-coordinate.
	-- @see Widget:SetX
	function Widget:GetX ()
		return self[_x]
	end

	---
	-- @return Raw local y-coordinate.
	-- @see Widget:SetY
	function Widget:GetY ()
		return self[_y]
	end

	---
	-- @param what Permission to query, which may be one of the following:<br><br>
	-- <b>"attach_list_render"</b>, <b>"attach_list_test"</b>, <b>"attach_list_update"</b>,
	-- <b>"render"</b>, <b>"test"</b>, <b>"update"</b>.
	-- @return If true, the callback will be run.
	-- @see Widget:Allow
	function Widget:IsAllowed (what)
		return Permissions[what] ~= nil and not self[what]
	end

	---
	-- @class function
	-- @name Widget:IsAttached
	-- @return If true, the widget is attached to a parent.
	-- @see Widget:Attach
	-- @see Widget:Detach
	Widget.IsAttached = AttachListOps.is_attached

	---
	-- @return If true, the widget can be traced up the chain to the root.
	function Widget:IsRooted ()
		return self[_mode] ~= nil
	end

	--- Puts the widget at the head of its parent's attach list.<br><br>
	-- It is an error to call this if a root widget at the top of the chain is running a
	-- callback.
	-- @see Widget:GetAttachListHead
	function Widget:Promote ()
		assert(not (self[_mode] or NoOp)("is_running_callbacks"), "Promotion forbidden from callbacks")

		AttachListOps.promote(self)
	end

	--- Assigns border margins for use by various operations.
	-- @param w Width to assign; if <b>nil</b>, keep the current width.
	-- @param h Height to assign; if <b>nil</b>, keep the current height.
	-- @see Widget:GetBorder
	function Widget:SetBorder (w, h)
		self[_bw], self[_bh] = w or self[_bw], h or self[_bh]
	end

	-- Setter helper
	local function LazySet (W, member, k, v)
		MemberTable(W, member)[k] = v
	end

	--- Sets a widget color.
	-- @param name Color name.
	-- @param color Color to assign, or <b>nil</b> to clear the color.
	-- @see Widget:GetColor
	function Widget:SetColor (name, color)
		LazySet(self, _colors, name, color)
	end

	-- font: Font to assign.
	-------------------------
	function Widget:SetFont (font)
		self[_font] = font
	end

	---
	-- @param h Raw height to assign.
	-- @see Widget:GetH
	function Widget:SetH (h)
		self[_h] = h
	end
	
	
	function Widget:SetName ( name )
		self[_name] = name
	end

	--- Sets a widget picture.<br><br>
	-- A valid picture is any object that has at minimum the following methods:<br><br>
	-- &nbsp&nbsp- <b>picture:Draw(x, y, w, h, props)</b>, which draws the picture in the
	-- rect (x, y, w, h). If present, <i>props</i> will be a table of (name, prop) pairs.<br><br>
	-- &nbsp&nbsp- <b>picture:GetProperty(name)</b>, which returns the value of the
	-- requested property, or <b>nil</b> if absent.<br><br>
	-- &nbsp&nbsp- <b>picture:SetProperty(name, value)</b>, which assigns the given property.
	-- The picture is free to disregard this if it has no use for the property.
	-- @param name Picture name.
	-- @param picture Picture to assign, or <b>nil</b> to clear the picture.
	-- @see Widget:DrawPicture
	-- @see Widget:GetPicture
	function Widget:SetPicture (name, picture)
		LazySet(self, _pictures, name, picture)
	end

	-- Policy options --
	local Options = { x = _x_policy, y = _y_policy, w = _w_policy, h = _h_policy }

	-- Rect policies --
	local Policies = { center = false, center_offset = true, normal = true, reverse = false, unit = true, unit_reverse = false }

	---
	--
	-- @param what
	-- @param policy
	-- @see Widget:GetAbsoluteRect
	-- @see Widget:GetRect
	-- @see Widget:GetRectPolicies
	function Widget:SetRectPolicy (what, policy)
		assert(not self[_is_root], "Cannot switch root policies")

		local key = assert(Options[what], "Invalid policy option")

		if what == "x" or what == "y" then
			assert(policy == nil or Policies[policy] ~= nil, "Invalid coordinate policy")
		else
			assert(policy == nil or Policies[policy], "Invalid dimension policy")
		end

		self[key] = policy ~= "normal" and policy or nil
	end

	--- Assigns shadow offsets for use by various render operations.
	-- @param x Shadow x-offset, or <b>nil</b>.
	-- @param y Shadow y-offset, or <b>nil</b>.
	-- @see Widget:GetShadowOffsets
	function Widget:SetShadowOffsets (x, y)
		self[_sx], self[_sy] = x, y
	end

	---
	-- @param string String to assign, or <b>nil</b> to clear the string.
	-- @see Widget:GetString
	function Widget:SetString (string)
		self[_string] = string
	end

	--- Set the corner offset for this widget, relative to its parent. By default, this is
	-- (0, 0).<br><br>
	-- The origin is taken into consideration while computing areas in <b>WidgetGroup:Execute
	-- </b> and <b>WidgetGroup:Render</b>.
	-- @param x View origin x-coordinate; if <b>nil</b>, keep the current x-coordinate.
	-- @param y View origin y-coordinate; if <b>nil</b>, keep the current y-coordinate.
	-- @see Widget:GetRect
	-- @see Widget:GetViewOrigin
	function Widget:SetViewOrigin (x, y)
		self[_vx], self[_vy] = x or self[_vx], y or self[_vy]
	end

	---
	-- @param w Raw width to assign.
	-- @see Widget:GetW
	function Widget:SetW (w)
		self[_w] = w
	end

	---
	-- @param x Raw local x-coordinate to assign.
	-- @see Widget:GetX
	function Widget:SetX (x)
		self[_x] = x
	end

	---
	-- @param y Raw local y-coordinate to assign.
	-- @see Widget:GetY
	function Widget:SetY (y)
		self[_y] = y
	end

	-- Valid alerts --
	local Alerts = table_ops.MakeSet{ "abandon", "drop", "enter", "enter_choose", "enter_upkeep", "grab", "leave", "leave_choose", "leave_upkeep" }

	---
	-- @param what
	function Widget:SubscribeTo (what)
		if Alerts[what] then
			MemberTable(self, _subscriptions)[what] = true
		end
	end

	-- Subscriptions iterator helper
	local function AuxIter (W, key)
		local list = W[_subscriptions]

		repeat
			key = next(Alerts, key)
		until list[key] or key == nil

		return key
	end

	---
	-- @return
	function Widget:SubscriptionsIter ()
		if self[_subscriptions] then
			return AuxIter, self
		else
			return NoOp
		end
	end

	---
	-- @param what
	function Widget:UnsubscribeFrom (what)
		local list = self[_subscriptions]

		if list and list[what] then
			list[what] = nil
		end
	end

	-- Stock signals --
	local Signals = {}

	--- Draws the <b>"main"</b> picture in the render rect.
	-- @class function
	-- @name Signals:render
	-- @see ~WidgetGroup:Render

	--
	function Signals:render (x, y, w, h)
		self:DrawPicture("main", x, y, w, h)
	end

	--- Default test. Returns the widget if the cursor is within the test rect.
	-- @class function
	-- @name Signals:test
	-- @see ~WidgetGroup:Execute

	--
	function Signals:test (cx, cy, x, y, w, h)
		if PointInBox(cx, cy, x, y, w, h) then
			return self
		end
	end

	--- Class constructor.
	-- @class function
	-- @name Widget:__cons

	--
	function Widget:__cons (group, mode)
		SuperCons(self, "Signalable")

		-- Root widget state --
		if IsType(group, "WidgetGroup") and not group:GetRoot() then
			self[_mode] = mode
			self[_is_root] = true
		end

		-- Signals --
		self:SetMultipleSlots(Signals)
	end
end, { base = "Signalable" })