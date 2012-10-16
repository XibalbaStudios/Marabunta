-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- Debug utility for dumping formatted strings to an array.
module aprintf
]]

-- Standard library imports --
local assert = assert
local format = string.format
local type = type

-- Current array --
local Array = {}

--- Appends formatted output strings to an array.
-- @class function
-- @name aprintf
-- @param str Format string.
-- @param ... Format parameters.
aprintf = setmetatable({}, {
	__call = function(_, str, ...)
		Array[#Array + 1] = format(str, ...)
	end,
	__metatable = true
})

---
-- @return Current array used by <b>aprintf</a>.
-- @see aprintf
-- @see aprintf:SetArray
function aprintf:GetArray ()
	return Array
end

--- Sets the current array used by <a>aprintf</a>.
-- @param array Table to assign as current array.
-- @see aprintf
-- @see aprintf:GetArray
function aprintf:SetArray (array)
	assert(type(array) == "table", "SetArray: invalid array")

	Array = array
end