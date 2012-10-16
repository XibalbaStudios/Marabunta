-- Standard library imports --
local assert = assert
local max = math.max
local newproxy = newproxy

-- Modules --
local class = require("class")
local coroutine_ops = require("coroutine_ops")
local func_ops = require("func_ops")
local gfx = require("gfx")
local input = require("input")
local iterators = require("iterators")
local var_preds = require("var_preds")

-- Imports --
local GetMousePos = input.GetMousePos
local GetRes = gfx.GetRes
local GetTimeDelta = VisionTimer.GetTimeDelta
local IsMouseButtonPressed = input.IsMouseButtonPressed
local New = class.New
local NoOp = func_ops.NoOp
local PopScissorRect = gfx.PopScissorRect
local PushScissorRect = gfx.PushScissorRect

-- Cached routines --
local _GetFrameID_

-- Mouse mode boolean --
local MouseMode = true

-- Resolve Logic
local ResolveLogic

-- Focus chains --
local Chains = table_ops.Weak("k")

-- Action maps: typically used one per context --
local ActionMaps = {}

for i = 1, 2 do
	ActionMaps[i] = New("ActionMap", i)
end

-- Global section group --
local SG = New("SectionGroup")

-- Global widget group --
local WG = New("WidgetGroup")

local w, h = GetRes()

WG:GetRoot():SetW(w)
WG:GetRoot():SetH(h)

-- Previous confirmation states --
local WasConfirmed = table_ops.Weak("k")

-- Register default time function.
func_ops.SetTimeLapseFunc(nil, VisionTimer.GetFrameDelta)

-- Register coroutine time function.
do
	local func, setter = coroutine_ops.PerCoroutineFunc()

	-- Call helper that instantiates the function if necessary
	local function Call (arg)
		if not setter("exists") then
			local time_left, frame_id

			setter(function(deduct)
				-- If the frame is out-of-sync, get the new time slice and sync up.
				local cur_id = _GetFrameID_()

				if frame_id ~= cur_id then
					frame_id = cur_id
					time_left = GetTimeDelta()
				end

				-- Reduce the time slice or return it.
				if deduct then
					time_left = max(time_left - deduct, 0)
				else
					return time_left
				end
			end)
		end

		return func(arg)
	end

	func_ops.SetTimeLapseFunc("coroutine_ops", function()
		return Call()
	end, function(used)
		assert(var_preds.IsNonNegative_Number(used), "Invalid deduction")

		Call(used)
	end)
end

---
module "user_state"

-- Frame management --
do
	local id = false

	--- Per-frame logic.
	function BeginFrame ()
		id = false
	end

	---
	-- @return ID for this frame.
	function GetFrameID ()
		id = id or newproxy()

		return id
	end
end

--- Action map accessor.
-- @param which Optional action map index; if absent, defaults to 1.
-- @return Action map handle.
function ActionMap (which)
	return ActionMaps[which or 1]
end

---
-- @param group Widget group to execute.
-- @param data Input data.
function Execute (group, data)
	local is_pressed, cx, cy

	-- By default, put the cursor on the item with focus. If unavailable, resort to the
	-- corner of the screen instead.
	local focus = Chains[data] and Chains[data]:GetFocus()

	if focus then
		cx, cy = focus:GetAbsoluteRect()
	end

	cx, cy = cx or 0, cy or 0

	-- Check whether the confirm key is down or at least whether it was down on the last
	-- frame. In that case, the press state is based on whether the key is currently down.
--	local key_down = data.confirm_key and lk.isDown(data.confirm_key)

	if --[[key_down or]] WasConfirmed[group] then
--		is_pressed = key_down

	-- Otherwise, resort to the mouse position and state if possible.
	elseif MouseMode then
		is_pressed = IsMouseButtonPressed("left")
		cx, cy = GetMousePos()
	end

	-- Let the next frame know if the confirm key was down on this frame.
--	WasConfirmed[group] = key_down

	-- Send input to the group.
	group:Execute(cx, cy, is_pressed, nil , nil , ResolveLogic)
end

do
	--- Focus chain accessor.
	-- @param data Section data.
	-- @param no_create If true, do not create missing chain.
	-- @return Section's focus chain handle, or <b>nil</b> if not created when absent.
	function FocusChain (data, no_create)
		local chain = Chains[data]

		if not (chain or no_create) then
			chain = New("FocusChain")

			Chains[data] = chain
		end

		return chain
	end

	local function GetScroll ( actionMap )
		local vertical, horizontal = actionMap:GetAnalogValue( "VerticalScroll" ), actionMap:GetAnalogValue( "HorizontalScroll" )
		
		local horz, vert
		if horizontal ~= 0 then

			horz = horizontal < 0 and "left" or "right"
		end
		if vertical ~= 0 then

			vert = vertical < 0 and "down" or "up"
		end
		return horz, vert
	end
	
	local function ActionState ( actionMap )
		
		for _, action in iterators.Args( "Accept", "Cancel", "Debug") do
			
			if actionMap:GetActionState( action ) then

				return action
			end
		end
		
	end
	
	--- Acts upon the input recieved by <i>actionMap</i>. This function uses widget internal information
	-- obtained via GetChainInfo to navigate with analog values. If there is no info available, the behaviour will go according to the 
	-- <i>movementType</i> parameter or it will be ignored if missing. <br><br> "Accept" and "Cancel" are handled in different ways depending
	-- on the focused widget type.
	-- @param data Section data.
	-- @param actionMap Action Map to use.
	-- @param movementType Optional parameter that indicates how analog values should be handled ( "horizontal" or "vertical" ) 
	function HandleInput ( data, info, movementType )
		local actionMap = ActionMap()
		local chain = FocusChain(data)
		local focus = chain:GetFocus()
		
		local action_state = ActionState( actionMap )
		local horz_action, vert_action = GetScroll( actionMap )
		
		
		if focus  then
			
			if focus.InputHandler and focus:InputHandler( action_state, horz_action, vert_action )then
				return
			end
			
			local new_focus
			
			if horz_action then
				new_focus = focus.GetChainInfo and ( focus:GetChainInfo(horz_action) ) or ( movementType == "horizontal" and ( horz_action == "left" and "-" or "+") )
			elseif vert_action then
				new_focus = focus.GetChainInfo and ( focus:GetChainInfo(vert_action) ) or ( movementType == "vertical" and ( vert_action == "up" and "-" or "+") )
			end
			
			if new_focus then 
				chain:SetFocus ( new_focus )
				return 
			end
		end
		
				
		
		if action_state then
			
			if info and info[action_state] then
				info[action_state]()
				return
			end
			
		end
		
	end
end

---
-- @class function
-- @name GetSize
-- @return Window width
-- @return Window height
GetSize = GetRes

---
-- @return If true, mouse mode is active.
function InMouseMode ()
	return MouseMode == true
end

---
-- @param group Widget group to render.
function Render (group)
	group:Render(PushScissorRect, PopScissorRect)
end

--- Section group accessor.
function SectionGroup ()
	return SG
end

function SetMouseMode( activate )
	MouseMode  = activate
end

-- resolve: Resolve routine to assign
--------------------------------------
function SetResolveLogic (resolve)
	ResolveLogic = resolve
end

--- Switches to and from mouse mode.
function ToggleMouseMode ()
	MouseMode = not MouseMode
end

--- Widget group accessor.
function WidgetGroup ()
	return WG
end

-- Cache some routines.
_GetFrameID_ = GetFrameID