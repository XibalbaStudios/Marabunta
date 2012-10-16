-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
module Load
]]

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local loadfile = loadfile
local setfenv = setfenv
local type = type

-- Forward reference --
local Load

-- Get and validate directory separator.
local Separator = ...

assert(type(Separator) == "string", "Invalid separator")

-- Reinvokes the loader on a set of results
local function LoadAgainOnItemResult (item, env, arg, ext, loader, prefix)
	if item ~= nil then
		Load(item, env, arg, ext, loader, prefix)
	end
end

-- Loads a file in a given environment
-- file: File name
-- prefix: Current base prefix for files; if present, propagate all parameters
-- Returns: If propagating, chunk results
local function LoadFile (file, env, arg, ext, loader, prefix)
	local chunk = assert(loader(file .. "." .. ext))

	setfenv(chunk, env)

	if prefix then
		return chunk(prefix, env, arg, ext, loader, Load)
	end

	chunk(arg)
end

-- Load helper
local function AuxLoad (item, prefix, env, arg, ext, loader)
	local itype = type(item)

	assert(itype == "function" or itype == "string" or itype == "table", "Bad load unit type")

	-- If an item is a function, evaluate it.
	if itype == "function" then
		LoadAgainOnItemResult(item(prefix, env, arg, ext, loader, Load))

	-- If an item is a string, load the script it names.
	elseif itype == "string" then
		LoadFile(prefix .. item, env, arg, ext, loader)

	-- If an item is a table, recursively read it. Process any internal boot.
	else
		local name = item.name
        local boot = item.boot

		assert(name == nil or type(name) == "string", "Invalid directory name")
		assert(boot == nil or type(boot) == "string", "Invalid boot string")

		if name and name ~= "" then
			prefix = prefix .. name .. Separator
		end

		if boot then
			LoadAgainOnItemResult(LoadFile(prefix .. boot, env, arg, ext, loader, prefix))
		end

		for _, entry in ipairs(item) do
			AuxLoad(entry, prefix, env, arg, ext, loader)
		end
	end
end

--- General purpose batch loader.
-- TODO: Summarize
-- @param item Item table to read.
-- @param prefix Current base prefix for files.
-- @param env Function environment table.
-- @param arg Argument.
-- @param ext File extension, or <b>"lua"</b> if <b>nil</b>.
-- @param loader Loader, or <b>loadfile</b> if <b>nil</b>.
function Load (item, prefix, env, arg, ext, loader)
	assert(type(prefix) == "string", "Invalid prefix")
	assert(type(env) == "table", "Invalid environment")
	assert(ext == nil or type(ext) == "string", "Invalid extension")
	assert(loader == nil or type(loader) == "function", "Invalid loader")

	AuxLoad(item, prefix, env, arg, ext or "lua", loader or loadfile)
end

-- Export the loader.
return Load