-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- TODO: Summarize
-- Class.
module ActionMap
]]

-- Standard library imports --
local abs = math.abs
local assert = assert
local ceil = math.ceil
local ipairs = ipairs
local pairs = pairs

-- Imports --
local AnalogValue = input.AnalogValue
local ActionStatus = input.ActionStatus
local ClampIn = numeric_ops.ClampIn

-- Unique member keys --
local _analogs = {}
local _digitals = {}
local _current = {}
local _device = {}
local _modes = {}

-- ActionMap class definition --
class.Define("ActionMap", function(ActionMap)
	---
	--[[ @param what Button action.
	-- @return If true, action button is pressed.
	function ActionMap:ButtonIsPressed (what)
		local state = self[_buttons][what]

		return state == "pressed" or state == "justpressed"
	end]]

	---
	-- @param what Analog action.
	-- @return Action value, or 0 if action is absent.
	function ActionMap:GetAnalogValue (what)
		assert(what ~= nil, "nil action")

        local value = self[_analogs][what]

		return value or 0
	end

	---
	-- @param what Action to query
	-- @return true if Action was triggered, false if not
	function ActionMap:GetActionState (what)
		assert(what ~= nil, "nil action")

		return (self[_digitals][what] and self[_digitals][what] ~= "wait") and true or false
	end

	---
	-- @returns Device.
	-- @see ActionMap:SetDevice
	function ActionMap:GetDevice ()
		return self[_device]
	end

	---
	-- @returns Current mode name, or <b>nil</b> if no mode is set.
	-- @see ActionMap:SetMode
	function ActionMap:GetMode ()
		return self[_current]
	end

	-- Current mode data helper
	local function GetModeData (A)
		local current = A[_current]

		return current ~= nil and A[_modes][current] or nil
	end

	-- Invokes a function within the current mode, group, and item
	local function InItem (A, group, action, func, ...)
		local mode = GetModeData(A)

		if mode then
			for _, item in pairs(mode[group]) do
				if item.action == action then
					return func(item, ...)
				end
			end
		end
	end

	-- Get repeat delay logic body
	local function AuxGetRepeatDelay (item)
		return item.delay
	end

	--- TODO: Tidy this up
	-- action: Action to query on delay
	-- name: Name of action's group
	-- Returns: Repeat delay
	------------------------------------
	function ActionMap:GetRepeatDelay (action, name)
		return InItem(self, name, action, AuxGetRepeatDelay) or 0
	end

	--- TODO: Tidy this up
	-- Maps an item to an action
	-- item: Value of item
	-- name: Name of action's group
	-- action: Action to map to item
	---------------------------------
	function ActionMap:Map (item, name, action)
		local mode = GetModeData(self)

		if mode then
			mode[name][item] = { action = action }
		end
	end

	-- Quantization logic body
	local function AuxQuantize (item, count, low)
		item.cuts = count
		item.low = count and low or nil
	end

	--- TODO: Tidy this up
	-- Discretizes an analog action
	-- action: Action to discretize
	-- count: Number of cuts in (0, 1) (nil = undiscretize)
	-- low: Value at which to begin discretization
	--------------------------------------------------------
	function ActionMap:Quantize (action, count, low)
		InItem(self, "analog", action, AuxQuantize, count, low)
	end

	---
	-- @param device Device to assign.
	function ActionMap:SetDevice (device)
		self[_device] = device
	end

	--- TODO: Tidy this up
	-- name: Mode name to assign
	-----------------------------
	function ActionMap:SetMode (name)
		if name ~= nil and name ~= self[_current] then
			self[_analogs] = {}
			self[_digitals] = {}

			-- If not present, prepare the mode.
			self[_modes][name] = self[_modes][name] or { analog = {}, digital = {} }

			-- Do item setup.
			for _, analog in pairs(self[_modes][name].analog) do
				analog.time = nil
			end

			for _, button in pairs(self[_modes][name].digital) do
				button.time = nil
			end
		end

		self[_current] = name
	end

	-- Set repeat delay logic body
	local function AuxSetRepeatDelay (item, delay)
		item.delay = delay
	end

	--- TODO: Tidy this up
	-- action: Action to delay
	-- name: Name of action's group
	-- delay: Repeat delay to assign (nil = 0)
	-------------------------------------------
	function ActionMap:SetRepeatDelay (action, name, delay)
		InItem(self, name, action, AuxSetRepeatDelay, delay)
	end

	-- Updates an item against a repeat delay
	local function UpdateDelay (item, step)
		item.time = (item.time or 0) + step

		if item.time >= item.delay then
			item.time = nil
		end
	end

	-- Update logic body
	local function AuxUpdate (A, mode, device, step)
		-- Update controller analog states.
		local analogs = A[_analogs]

		for item, analog in pairs(mode.analog) do
			local value = AnalogValue(device, item)

			-- If no analog value is dead, cancel any delay.
			if value == 0 then
				analog.time = nil

			-- Otherwise, check whether a delay is in effect. If so, cancel any motion.
			-- Update any delay.
			else
				if analog.time then
					value = 0
				end

				if analog.delay then
					UpdateDelay(analog, step)
				end
			end

			-- Apply any discretization to the analog value.
			local cuts = analog.cuts

			if value ~= 0 and cuts then
				local is_negative, low = value < 0, analog.low
				local rest = 1 - low

				value = low + ceil(cuts * (ClampIn(abs(value), low, 1) - low) / rest) * rest / cuts

				if is_negative then
					value = -value
				end
			end

			-- Assign the analog action value.
			analogs[analog.action] = value
		end

		-- Update controller button states.
		local buttons = A[_digitals]

		for item, button in pairs(mode.digital) do
			local value = ActionStatus(device, item)

			-- Reset delays if the button is released.
			if not value then
				button.time = nil

			-- During a press, check whether a delay is in effect. If so, issue a wait;
			-- otherwise, issue a normal press. Update any delay.
			else
				if button.time then
					value = "wait"
				end

				if button.delay then
					UpdateDelay(button, step)
				end
			end

			-- Assign the button action value.
			buttons[button.action] = value
		end
	end

	---
	-- @param step Time step.
	function ActionMap:Update (step)
		-- Update the action map if it has a device and valid mode.
		local device = self[_device]
		local mode = GetModeData(self)

		if device and mode then
			AuxUpdate(self, mode, device, step)
		end
	end

	--- Class constructor.
	-- @param device Device to use with map.
	-- @see ActionMap:SetDevice
	function ActionMap:__cons (device)
		self[_analogs] = {}
		self[_digitals] = {}
		self[_modes] = {}

		self:SetDevice(device)
	end
end)