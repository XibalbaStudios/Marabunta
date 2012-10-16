-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module Image
]]

-- Standard library imports --
local type = type

-- Imports --
local IsInstance = class.IsInstance
local SuperCons = class.SuperCons

-- Cached methods --
local GetH = class.GetMember("Widget", "GetH")
local GetW = class.GetMember("Widget", "GetW")

-- Image class definition --
class.Define("Image", function(Image)
	-- Gets a dimensional amount
	local function GetDim (I, method, gmethod)
		local picture = I:GetPicture("main")
		local dim = method(I)

		if not dim and picture then
			local graphic = picture:GetGraphic()

			if type(graphic) == "table" or IsInstance(graphic) then
				local method = graphic[gmethod]

				if method then
					dim = method(graphic)
				end
			end
		end

		return dim or 0
	end

	--- Override of <b>Widget:GetH</b>.<br><br>
	-- If <b>Widget:SetH</b> has been called with a non-<b>nil</b> value, that value is
	-- used.<br><br>
	-- Otherwise, returns the height of the <b>"main"</b> picture, or 0 if absent.
	-- <br><br>TODO: Improve constraints on pictures
	-- @return Height.
	-- @see ~Widget:GetH
	-- @see ~Widget:SetH
	function Image:GetH ()
		return GetDim(self, GetH, "GetHeight")
	end

	--- Override of <b>Widget:GetW</b>.<br><br>
	-- If <b>Widget:SetW</b> has been called with a non-<b>nil</b> value, that value is 
	-- used.<br><br>
	-- Otherwise, returns the width of the <b>"main"</b> picture, or 0 if absent.
	-- <br><br>TODO: Improve constraints on pictures
	-- @return Width.
	-- @see ~Widget:GetW
	-- @see ~Widget:SetW
	function Image:GetW ()
		return GetDim(self, GetW, "GetWidth")
	end

	--- Class constructor.
	function Image:__cons ()
		SuperCons(self, "Widget")
	end
end, { base = "Widget" })