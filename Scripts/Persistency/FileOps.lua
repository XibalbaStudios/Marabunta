----------------------------
-- Standard library imports
----------------------------
local assert = assert
local error = error
local format = string.format
local ipairs = ipairs
local loadstring = loadstring
local modf = math.modf
local open = io.open
local pairs = pairs
local pcall = pcall
local setfenv = setfenv
local type = type

-----------
-- Imports
-----------
local GetLanguage = settings.GetLanguage

-------------------
-- Cached routines
-------------------
local Save_
local GetGlobalValue_
local SetGlobalValue_
local GetPlayerValue_
local SetPlayerValue_

-- Export the persistent namespace
module "file_ops"



-- Loads or resets the persistent session
-- Returns: Session info
------------------------------------------
function LoadFile (name, path)
	
	-- pre-pend the path
	path = path .. name
	
	local ifile, session = open(path), {}
	
	if ifile then
		(setfenv(assert(loadstring(ifile:read("*a"))), session))()

		ifile:close()
	end

	return session
end





do
	-- var: Variable to validate
	-- Returns: If true, variable is good
	--------------------------------------
	local function IsGood (var)
		local vtype = type(var)

		-- Restrict non-table variables to easily serializable types.
		if vtype ~= "table" then
			return vtype == "boolean" or vtype == "number" or vtype == "string"
		end

		-- Recursively validate the table. For simplicity, forbid tables as keys.
		for k, v in pairs(var) do
			if not (type(k) ~= "table" and IsGood(k) and IsGood(v)) then
				return false
			end
		end

		return true
	end
	
end

do
	-- Converts a value to a pretty-print string
	-- v: Value to stringify
	-- Returns: Pretty-print string
	---------------------------------------------
	local function Pretty (v)
		local vtype = type(v)

		if vtype == "boolean" then
			v = v and "true" or "false"
		elseif vtype == "number" then
			v = format(modf(v) == v and "%i" or "%f", v)
		elseif vtype == "function" then
			v = "function"
		elseif vtype == "userdata" then
			v = "userdata"
		end

		return v
	end

	-- Converts a table key to a pretty-print string
	-- k: Key to stringify
	-- Returns: Pretty-print string
	-------------------------------------------------
	local function Key (k)
		local bString = type(k) ~= "string"

		return format("%s%s%s", bString and "[" or "", Pretty(k), bString and "]" or "")
	end

	-- Converts a table value to a pretty-print string
	-- v: Value to stringify
	-- indent: Current indentation for tables
	-- Returns: Pretty-print string
	---------------------------------------------------
	local function Value (v, indent, test)
		local vtype = type(v)

		-- Emit non-table values, quoting strings.
		if vtype ~= "table" then
			return format(vtype == "string" and "%q" or "%s", Pretty(v))
		end

		-- Prepare for table indentation and inter-item commas. Bound the entries in braces
		-- when this is not the top-level.
		local asize, str, next, fstr, jstr, jstr2 = 0, "", indent

		if v == Session or v == PlayerSession or test == true then
			fstr, jstr2 = "%s%s", "\n"
		else
			fstr, jstr2, next = "{\n%s\n%s}", ",\n", indent .. "\t"
		end

		jstr, jstr2 = next, jstr2 .. next

		-- List table entries, starting with the array part. After the first item, precede
		-- each entry with a comma and appropriate indentation.
		for i, item in ipairs(v) do
			asize, jstr, str = i, jstr2, str .. format("%s%s", jstr, Value(item, next))
		end

		for k, item in pairs(v) do
			local ktype = type(k)

			if not (ktype == "number" and modf(k) == k and k >= 1 and k <= asize) then
				jstr, str = jstr2, str .. format("%s%s = %s", jstr, Key(k), Value(item, next))
			end
		end

		return format(fstr, str, indent)
	end
	

	function SaveTableToFile( table, FileName, path )
		
		
		path = path .. FileName
		local ofile, message = open(path, "w")
			
		if ofile then
			ofile:write(Value(table, "", true))
			ofile:close()

		else
			error("Unable to save table: " .. message)
		end
	
	end
end

