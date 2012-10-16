-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local _G = _G
local getfenv = getfenv
local getmetatable = getmetatable
local loaded = package.loaded
local setfenv = setfenv
local setmetatable = setmetatable
local type = type

-- Overload module to allow for easy use of some globals in other modules.
local old_module = module

function module (name, ...)
	old_module(name, ...)

	local mtable = loaded[name]
	local meta = getmetatable(mtable) or {}
	local index = meta.__index
	local itype = type(index)

	function meta.__index (t, k)
		if k == "messagef" or k == "printf" or k == "var_dump" then
			return _G[k]
		elseif itype == "function" then
			return index(t, k)
		elseif itype == "table" then
			return index[k]
		end
	end

	setmetatable(mtable, meta)
	setfenv(2, getfenv())
end