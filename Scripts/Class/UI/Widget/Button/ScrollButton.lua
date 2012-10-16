-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module ScrollButton
]]

-- Standard library imports --
local assert = assert

-- Modules --
local class = require("class")
local var_preds = require("var_preds")

-- Imports --
local IsPositive_Number = var_preds.IsPositive_Number
local IsType = class.IsType
local New = class.New
local SuperCons = class.SuperCons

-- Unique member keys --
local _frequency = {}
local _how = {}
local _target = {}
local _timeout = {}
local _timer = {}

-- S: Scroll button handle
-- count: Step count
local function Step (S, count)
	local frequency = S:GetFrequency()
	local target, how = S:GetTarget()

	for _ = 1, target and count or 0 do
		target:Signal("scroll", how, frequency)
	end
end

-- Stock signals --
local Signals = {}

---
function Signals:drop ()
	self[_timer]:Stop()
end

---
function Signals:grab ()
	self[_timer]:Start(self[_timeout])

	Step(self, 1)
end

---
Signals.render = widget_ops.ButtonStyleRender

---
function Signals:update (dt)
	Step(self, self[_timer]:Check("continue"))

	self[_timer]:Update(dt)
end

-- ScrollButton class definition --
class.Define("ScrollButton", function(ScrollButton)
	-- Returns: Scroll frequency
	-----------------------------
	function ScrollButton:GetFrequency ()
		return self[_frequency] or 1
	end

	-- Returns: Target, scroll behavior
	------------------------------------
	function ScrollButton:GetTarget ()
		return self[_target], self[_how]
	end

	-- frequency: Scroll frequency to assign
	-----------------------------------------
	function ScrollButton:SetFrequency (frequency)
		self[_frequency] = frequency
	end

	-- target: Target handle to bind
	-- how: Scroll behavior
	---------------------------------
	function ScrollButton:SetTarget (target, how)
		assert(IsType(target, "Signalable"), "Unsignalable scroll target")

		if self[_target] then
			self[_target]:Signal("unbind_as_scroll_target", self, self[_how])
		end

		self[_target] = target
		self[_how] = how

		if target then
			target:Signal("bind_as_scroll_target", self, how)
		end
	end

	-- timeout: Timeout value to assign
	------------------------------------
	function ScrollButton:SetTimeout (timeout)
		assert(timeout == nil or IsPositive_Number(timeout), "Invalid timeout")

		self[_timeout] = timeout
	end

	--- Class constructor.
	function ScrollButton:__cons ()
		SuperCons(self, "Widget")

		-- Scroll timer --
		self[_timer] = New("Timer")

		-- Signals --
		self:SetMultipleSlots(Signals)
	end
end, { base = "Widget" })