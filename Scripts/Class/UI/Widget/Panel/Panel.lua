-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- Widget generally intended as a docking point for other widgets, with some layout support.<br><br>
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module Panel
]]

-- Standard library imports --
local assert = assert

-- Imports --
local SuperCons = class.SuperCons
local SwapIf = numeric_ops.SwapIf

-- Unique member keys --
local _alignment = {}
local _layout = {}
local _separation = {}

-- --
local Layouts = { normal = func_ops.NoOp }

--
local function Box (P, align, is_vert)
	--
	local method, coord, ncoord

	if is_vert then
		method, coord, ncoord = "GetH", "x", "y"
	else
		method, coord, ncoord = "GetW", "y", "x"
	end

	--
	local sep = P[_separation] or 0
	local dim = -sep

	for widget in P:AttachListIter() do
		dim = dim + widget[method](widget) + sep
	end

	--
	local _, margin = SwapIf(is_vert, P:GetBorder())
	local pos = ((P[method](P) or 0) - dim) / 2

	for widget in P:AttachListIter() do
		local x, y = SwapIf(is_vert, pos, margin)

		widget:SetX(x)
		widget:SetY(y)

		widget:SetRectPolicy(coord, align)
		widget:SetRectPolicy(ncoord, nil)

		pos = pos + widget[method](widget) + sep
	end
end

--
function Layouts:hbox (align)
	Box(self, align, false)
end

--
function Layouts:vbox (align)
	Box(self, align, true)
end

--
local function Pack (P, get_coord, set_coord, get_other, set_other)
end

--
function Layouts:hpack ()
end

--
function Layouts:vpack ()
end

-- Panel class definition --
class.Define("Panel", function(Panel)
	---
	function Panel:GetLayout ()
		return self[_layout] or "normal"
	end

	--
	local function Update (P)
		local layout = P[_layout] or "normal"

		Layouts[layout](P, P[_alignment])
	end

	-- Valid alignments --
	local Alignments = table_ops.MakeSet{ "center", "normal", "reverse" }

	---
	function Panel:SetAlignment (align)
		assert(align == nil or Alignments[align], "Invalid alignment")

		self[_alignment] = align ~= "normal" and align or nil

		Update(self)
	end

	---
	function Panel:SetLayout (layout)
		assert(Layouts[layout], "Invalid layout")

		self[_layout] = layout

		Update(self)
	end

	---
	function Panel:SetSeparation (sep)
		self[_separation] = sep

		Update(self)
	end

	-- Stock signal table --
	local Signals = {}

	---
	Signals.attached_to = Update

	---
	Signals.leave_attach_list_update = Update

	---
	function Signals:render (x, y, w, h)
		self:DrawPicture("main", x, y, w, h)
		self:DrawPicture("frame", x, y, w, h)
	end

	---
	function Signals:post_render (x, y, w, h)
	end

	--- Class constructor.
	function Panel:__cons ()
		SuperCons(self, "Widget")

		-- Signals --
		self:SetMultipleSlots(Signals)
	end
end, { base = "Widget" })