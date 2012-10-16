-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module Grid
]]

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local min = math.min

-- Imports --
local CellToIndex = numeric_ops.CellToIndex
local FitToSlot = numeric_ops.FitToSlot
local GridIter = numeric_ops.GridIter
local Identity = func_ops.Identity
local IsCallableOrNil = var_preds.IsCallableOrNil
local IsPositiveInteger = var_preds.IsPositiveInteger
local New = class.New
local NoOp = func_ops.NoOp
local PointInBox = numeric_ops.PointInBox
local SuperCons = class.SuperCons

-- Unique member keys --
local _cells = {}
local _draw_grid = {}
local _col = {}
local _lock_on_grab = {}
local _row = {}
local _state = {}

--
local function GetSize (O)
	local state = O[_state]

	return state.ncols, state.nrows
end

-- Cell class definition --
local Cell_Key = widget_ops.DefineOwnedWidget("Grid:Cell", function(Cell)
	---
	-- @return
	-- @return
	Cell.GetGridDimensions = GetSize

	---
	-- @return
	-- @return
	function Cell:GetIndices ()
		return self[_col], self[_row]
	end

	-- Stock cell signals --
	local CellSignals = {}

	for _, what in iterators.Args(
		---
		-- @class function
		-- @name CellSignals:drop
		"drop",

		---
		-- @class function
		-- @name CellSignals:enter
		"enter",

		---
		-- @class function
		-- @name CellSignals:grab
		"grab",

		---
		-- @class function
		-- @name CellSignals:leave
		"leave"
	) do
		CellSignals[what] = function(C, group, state)
			(C[_state][what] or NoOp)(C, group, state)
		end
	end

	---
	function CellSignals:render (x, y, w, h, group, state)
		(self[_state].render or NoOp)(self, x, y, w, h, group, state)
	end

	---
	function CellSignals:test (cx, cy, x, y, w, h, group, state)
		return (self[_state].test or Identity)(self, cx, cy, x, y, w, h, group, state)
	end

	---
	function CellSignals:update (dt, group)
		(self[_state].update or NoOp)(self, dt, group)
	end

	--- Class constructor.
	-- @param grid
	-- @param col
	-- @param row
	function Cell:__cons (grid, col, row)
		-- --
		self[_state] = grid[_state]

		-- --
		self[_col] = col
		self[_row] = row

		-- --
		self:SetMultipleSlots(CellSignals)
	end
end)

-- Grid class definition --
class.Define("Grid", function(Grid)
	---
	-- @param col
	-- @param row
	-- @return
	function Grid:GetCell (col, row)
		return self[_cells][CellToIndex(col, row, self[_state].ncols)]
	end

	---
	-- @return
	-- @return
	Grid.GetSize = GetSize

	---
	-- @return
	function Grid:__len ()
		return #self[_cells]
	end

	---
	-- @param lock
	function Grid:LockOnGrab (lock)
		self[_lock_on_grab] = not not lock
	end

	---
	-- @class function
	-- @name Grid:SetDrawGridFunc
	Grid.SetDrawGridFunc = func_ops.FuncSetter(_draw_grid, "Uncallable draw grid function", true)

	--
	local function NewCell (G, col, row)
		return New("Grid:Cell", Cell_Key, G, col, row)
	end

	---
	-- @param ncols
	-- @param nrows
	function Grid:SetSize (ncols, nrows)
		assert(IsPositiveInteger(ncols), "Invalid column count")
		assert(IsPositiveInteger(nrows), "Invalid row count")

		local cur_ncols, cur_nrows = GetSize(self)
		local cells = self[_cells]
		local old_size = #cells
		local new_size = ncols * nrows
		local minr = min(nrows, cur_nrows)

		--
		if cur_ncols < ncols then
			for row = minr, 1, -1 do
				local old_index = CellToIndex(0, row, cur_ncols)
				local new_index = CellToIndex(0, row, ncols)

				for j = cur_ncols, 1, -1 do
					cells[new_index + j] = cells[old_index + j]
				end

				for j = cur_ncols + 1, ncols do
					cells[new_index + j] = NewCell(self, j, row)
				end
			end

		--
		elseif cur_ncols > ncols then
			for row = 1, minr do
				local old_index = CellToIndex(0, row, cur_ncols)
				local new_index = CellToIndex(0, row, ncols)

				for j = 1, ncols do
					cells[new_index + j] = cells[old_index + j]
				end
			end
		end

		--
		for i = old_size, minr * ncols + 1, -1 do
			cells[i] = nil
		end

		--
		for row = cur_nrows + 1, nrows do
			for col = 1, ncols do
				cells[#cells + 1] = NewCell(self, col, row)
			end
		end

		--
		self[_state].ncols = ncols
		self[_state].nrows = nrows
	end

	-- --
	for _, root in iterators.Args(
		---
		-- @class function
		-- @name Grid:SetDropFunc
		"Drop",

		---
		-- @class function
		-- @name Grid:SetEnterFunc
		"Enter",

		---
		-- @class function
		-- @name Grid:SetGrabFunc
		"Grab",

		---
		-- @class function
		-- @name Grid:SetLeaveFunc
		"Leave",

		---
		-- @class function
		-- @name Grid:SetRenderFunc
		"Render",

		---
		-- @class function
		-- @name Grid:SetUpdateFunc
		"Update"
	) do
		local key = string.lower(root)
		local message = "Uncallable " .. key .. " function"

		Grid["Set" .. root .. "Func"] = function(G, func)
			assert(IsCallableOrNil(func), message)

			G[_state][key] = func
		end
	end

	-- --
	local GridSignals = {}

	---
	function GridSignals:render (x, y, w, h, group, state)
		local ncols, nrows = GetSize(self)
		local dw, dh = w / ncols, h / nrows
		local cells = self[_cells]

		self:DrawPicture("main", x, y, w, h)

		for _, index, _, _, cx, cy in GridIter(1, 1, ncols, nrows, dw, dh) do
			cells[index]:Signal("render", x + cx, y + cy, dw, dh, group, state)
		end

		(self[_draw_grid] or NoOp)(x, y, w, h, ncols, nrows, self:GetColor("grid"))
	end

	---
	function GridSignals:test (cx, cy, x, y, w, h, group, state)
		if PointInBox(cx, cy, x, y, w, h) then
			local grabbed = group:GetGrabbed()

			if grabbed and self[_lock_on_grab] and grabbed:GetOwner() == self then
				return grabbed
			else
				local ncols, nrows = GetSize(self)
				local col, row = FitToSlot(cx, x, w / ncols), FitToSlot(cy, y, h / nrows)

				return self:GetCell(col, row):Signal("test", cx, cy, x, y, w, h, group, state) or self
			end
		end
	end

	---
	function GridSignals:update (dt, group)
		for _, cell in ipairs(self[_cells]) do
			cell:Signal("update", dt, group)
		end
	end

	--- Class constructor.
	function Grid:__cons ()
		SuperCons(self, "Widget")

		-- --
		self[_state] = { ncols = 0, nrows = 0 }

		-- --
		self[_cells] = {}

		self:SetSize(1, 1)

		-- Signals --
		self:SetMultipleSlots(GridSignals)
	end
end, { base = "Widget" })