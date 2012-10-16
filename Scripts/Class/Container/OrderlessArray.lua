-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
-- Class.
module OrderlessArray
]]

-- Standard library imports --
local assert = assert
local insert = table.insert
local max = math.max
local pairs = pairs
local rawequal = rawequal
local remove = table.remove

-- Imports --
local Type = class.Type
local Weak = table_ops.Weak

-- Unique member keys --
local _cache = {}
local _elements = {}
local _running = {}

-- Cookies --
local _nil = {}

-- OrderlessArray class definition --
class.Define("OrderlessArray", function(OrderlessArray)
	-- element: Element to add
	---------------------------
	function OrderlessArray:Add (element)
		insert(self[_elements], element == nil and _nil or element)
	end

	-- Maps an array element
	local function Map (element)
		if not rawequal(element, _nil) then
			return element
		end
	end

	-- Returns: Indexed element
	----------------------------
	function OrderlessArray:Get (index)
		return Map(self[_elements][index])
	end

	-- Instanced iterator over the array
	-- Returns: Iterator which supplies index, element
	-- @see ~iterators.InstancedAutocacher
	---------------------------------------------------
	OrderlessArray.Ipairs = iterators.InstancedAutocacher(function()
		local cur

		local function Adjust (i)
			if i <= cur then
				cur = max(cur - 1, 0)
			end
		end

		-- Body --
		return function(A)
			local index = cur

			cur = cur + 1

			return index, Map(A[_elements][index])
		end,

		-- Done --
		function(A)
			return cur > #A[_elements]
		end,

		-- Setup --
		function(A)
			A[_running][Adjust], cur = true, 1

			return A
		end,

		-- Reclaim --
		function(A)
			assert(Type(A) == "OrderlessArray", "Invalid reclaim")

			A[_running][Adjust] = nil
		end
	end)

	-- Returns: Array length
	-------------------------
	function OrderlessArray:__len ()
		return #self[_elements]
	end

	-- Removes and returns an extra element, if any
	-- Returns: Element
	------------------------------------------------
	function OrderlessArray:PopExtra ()
		return Map(remove(self[_cache]))
	end

	-- Removes an element from the array
	-- index: Array index
	-- clear: If true, the element is not dropped into the extras
	--------------------------------------------------------------
	function OrderlessArray:Remove (index, clear)
		local array = self[_elements]

		if array[index] ~= nil then
			local element = array[index]

			-- Move the last element into the vacancy, if the array has not yet become
			-- empty. The removed element becomes extra.
			if index < #array then
				array[index] = array[#array]
			end

			array[#array] = nil

			-- Cache the removed element if desired.
			if not (clear or rawequal(element, _nil)) then
				insert(self[_cache], element)
			end

			-- Correct running iterators.
			for adjust in pairs(self[_running]) do
				adjust(index)
			end
		end
	end

	-- Constructor
	---------------
	function OrderlessArray:__cons ()
		-- Unordered elements --
		self[_elements] = {}

		-- Used elements --
		self[_cache] = {}

		-- Running iterators --
		self[_running] = Weak("k")
	end
end)