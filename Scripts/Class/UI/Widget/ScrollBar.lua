-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- NYI
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module ScrollBar
]]

-- Imports --
local New = class.New
local SuperCons = class.SuperCons

-- Unique member keys --
local _active_on_full = {}
local _bar = {}
local _frequency = {}
local _hi = {}
local _is_vertical = {}
local _lo = {}
local _min = {}
local _off_center = {}
local _offset = {}
local _target = {}
local _timer = {}

-- Bar class definition --
local Bar_Key = widget_ops.DefineOwnedWidget("ScrollBar:Bar", function(Bar)
	-- Stock bar signals --
	local BarSignals = {}

	---
	-- @param state Execution state.
	function BarSignals:grab (_, state)
		local scroll_bar = self:GetOwner()

--		self[_off_center] = CursorOffset(slider, ThumbOffset(slider), state)
	end

	---
	-- @param state Execution state.
	function BarSignals:leave_upkeep (group, state)
		local scroll_bar = self:GetOwner()

		if self == group:GetGrabbed() then
--			slider:SetOffset(CursorOffset(slider, slider[_dist1], state) - self[_off_center])
		end
	end

	--- Class constructor.
	function Bar:__cons ()
		self:SetMultipleSlots(BarSignals)
	end
end)

-- EndPart class definition --
local EndPart_Key = widget_ops.DefineOwnedWidget("ScrollBar:EndPart", function(EndPart)
	---
	function EndPart:SetFrequency (frequency)
	end

	-- Stock end part signals --
	local EndPartSignals = {}

	---
	-- @param state Execution state.
	function EndPartSignals:grab (_, state)
	--	local slider = self:GetOwner()

--		self[_off_center] = CursorOffset(slider, ThumbOffset(slider), state)
	end

	---
	-- @param state Execution state.
	function EndPartSignals:leave_upkeep (group, state)
	--	local slider = self:GetOwner()

		--if self == group:GetGrabbed() then
	--		slider:SetOffset(CursorOffset(slider, slider[_dist1], state) - self[_off_center])
	--	end
	end

	--- Class constructor.
	function EndPart:__cons ()
		self:SetMultipleSlots(EndPartSignals)
	end
end)

-- ScrollBar class definition --
class.Define("ScrollBar", function(ScrollBar)

	---
	function ScrollBar:GetBar ()
	end

	---
	function ScrollBar:GetEndParts ()
	end

	---
	function ScrollBar:SetTimeout (timeout)
	end

	---
	function ScrollBar:SetTarget (target)
	end

	-- Stock signal table --
	local ScrollBarSignals = {}

	---
	function ScrollBarSignals:drop ()
	end

	---
	function ScrollBarSignals:grab ()
	end

	---
	function ScrollBarSignals:update (dt)
	end

	--- Class constructor.
	function ScrollBar:__cons (min_bar, is_vertical)
		SuperCons(self, "Widget")

		-- --
-- target("scroll_pos")
-- target("size")
		-- Scroll timer --
		self[_timer] = New("Timer")

		-- Signals --
		self:SetMultipleSlots(ScrollBarSignals)
	end
end, { base = "Widget" })

-- Gets the scroll bar part rectangle
-- S: Scroll bar handle
-- bVert: If true, scroll bar is vertical
-- Returns: Bar rectangle
------------------------------------------
local function GetBarRect (S, bVert)
	local offset = S:GetOffset()
--	local bx, by = 
--	return offset
end
--[[
-- Constructor
-- group: Group handle
-- as: Arrow size
-- ms: Minimum bar size
------------------------
function(S, group, as, ms)
	SuperCons(S, "Widget", group)
	
	-- Assign format parameters.
	S.as, S.ms = as, ms

	-- Bar used to manipulate scroll bar.
	S.bar = S:CreatePart()
	
	-- Arrows used to manipulate scroll bar.
	S.garrow, S.larrow = S:CreatePart(), S:CreatePart()

	-- Key press timer.
	S.press = class.New("Timer", function()
		if S:IsPressed() and S:IsEntered() then
			-- Approach snap point
		elseif S.larrow:IsPressed() and S.larrow:IsEntered() then
			-- Scroll up/left
		elseif S.garrow:IsPressed() and S.garrow:IsEntered() then
			-- Scroll down/right
		end
	end)
			
	-- Signals --
	S:SetMultipleSlots{
		event = function(event)
			-- On grabs, cue the snap timer.
			if event == WE.Grab then
			--	
						
			-- Get the off-center position on bar grabs. Cue the scroll timer otherwise.
			elseif event == WE.GrabPart then
				if S.bar:IsGrabbed() then
--					S.dOffset = Offset(S, GetThumbPosition(S, bVert, false), bVert)
				else
				--	
				end
	
			-- Fit the offset to account for drags.
			elseif event == WE.PostUpkeep and S.bar:IsGrabbed() then
--				S:SetOffset(Offset(S, S.sc, bVert) - S.dOffset)
			end		
		end,
		test = function(cx, cy, x, y, w, h)
			-- If the cursor hits the slider, find the box centered at the current offset. If
			-- the cursor hits this box as well, it is over the thumb.
--			local tx, ty = GetThumbPosition(S, bVert, true)
--			if PointInBox(cx, cy, x + tx * w, y + ty * h, S.tw * w, S.th * h) then
--				return S.thumb
--			end
			return S
		end,
		update = function(x, y, w, h)
			S:DrawPicture("B", x, y, w, h)
			
			-- Draw the part graphics.
			for _, part in ipairs{ "bar", "larrow", "garrow" } do
				local bG, bE, suffix = S[part]:IsGrabbed(), S[part]:IsEntered(), "D"
				if bG and bE then
					suffix = "G"
				elseif bG or bE then
					suffix = "E"
				end
--				S:DrawPicture(part .. suffix, x + tx * w, y + ty * h, S.tw * w, S.th * h)
			end
		end
]]