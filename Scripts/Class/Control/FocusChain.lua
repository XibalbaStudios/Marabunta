-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A focus chain provides some convenient apparatus for grouping together signalable items,
-- in order, where one item at once is the focus of some sort of input, e.g. the <a href=
-- "Widget.html">widget</a> which currently receives keystrokes.<br><br>
-- Class.
module FocusChain
]]

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local type = type

-- Modules --
local class = require("class")
local numeric_ops = require("numeric_ops")
local table_ops = require("table_ops")
local var_ops = require("var_ops")

-- Imports --
local Copy_WithTable = table_ops.Copy_WithTable
local Find = table_ops.Find
local IsType = class.IsType
local RotateIndex = numeric_ops.RotateIndex
local WipeRange = var_ops.WipeRange

-- Unique member keys --
local _chain = {}
local _index = {}

-- FocusChain class definition --
class.Define("FocusChain", function(FocusChain)
	-- Clear helper
	local function AuxClear (FC, arg)
		-- Remove the focus. Indicate that this is during a clear.
		local focus = FC:GetFocus()

		if focus then
			focus:Signal("lose_focus", FC, arg)
		end

		-- Detach focus items.
		local chain = FC[_chain]

		for _, item in ipairs(FC[_chain]) do
			item:Signal("remove_from_focus_chain", FC)
		end
	end

	--- Removes all items in the chain.<br><br>
	-- If the chain is not empty, the item with focus is signaled as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>lose_focus(item, chain)</b></i>.<br><br>
	-- Likewise, each item in the chain is then signaled as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>remove_from_focus_chain(item, chain)</b></i>.
	function FocusChain:Clear ()
		AuxClear(self)

		WipeRange(self[_chain])
	end

	---
	-- @param item Item to seek.
	-- @return If true, <i>item</i> is in the chain.
	function FocusChain:Contains (item)
		return Find(self[_chain], item, true) ~= nil
	end

	---
	-- @return Focus item, or <b>nil</b> if the chain is empty.
	-- @see FocusChain:GetIndex
	-- @see FocusChain:SetFocus
	function FocusChain:GetFocus ()
		if #self[_chain] > 0 then
			return self[_chain][self[_index]]
		end
	end

	---
	-- @return Focus index, or <b>nil</b> if the chain is empty.
	function FocusChain:GetIndex ()
		if #self[_chain] > 0 then
			return self[_index]
		end
	end

	-- Iteration helper
	local function AuxIter (FC, i)
		local item = FC[_chain][i + 1]

		if item then
			return i + 1, item
		end
	end

	--- Iterator over the focus chain.
	-- @return Iterator, which returns index and item at each iteration.
	function FocusChain:Iter ()
		return AuxIter, self, 0
	end

	--- Metamethod.
	-- @return Number of items in the chain.
	function FocusChain:__len ()
		return #self[_chain]
	end
	
	--- Loads the focus chain with items.<br><br>
	-- These items must derive from <b>Signalable</b>.<br><br>
	-- Any items already in the chain are first cleared and signaled as per
	-- <b>FocusChain:Clear</b>, except <i>lose_focus</i>, if invoked, is passed a third
	-- argument of <b>"during_load"</b>.<br><br>
	-- Each item added to the chain is signaled as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>add_to_focus_chain(item, chain)</b></i>.<br><br>
	-- If any items were added, the first item will become the focus. It is signaled as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>gain_focus(item, chain, "during_load")</b></i>.
	-- @param items Ordered array of items to install.
	-- @see FocusChain:Clear
	function FocusChain:Load (items)
		-- Validate the new items.
		for _, item in ipairs(items) do
			assert(IsType(item, "Signalable"), "Unsignalable focus chain item")
		end

		-- Remove current items.
		AuxClear(self, "during_load")

		-- Install the focus chain.
		local chain = self[_chain]

		Copy_WithTable(chain, items, "overwrite_trim", nil, #chain)

		self[_index] = 1

		-- Attach focus items.
		for _, item in ipairs(chain) do
			item:Signal("add_to_focus_chain", self)
		end

		-- Give the first item focus.
		if #chain > 0 then
			chain[1]:Signal("gain_focus", self, "during_load")
		end
	end

	--- Sets the current focus.<br><br>
	-- Focus changes will send two signals: The item losing focus will be signaled as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>lose_focus(item, chain)</b></i>.<br><br>
	-- Likewise, the item gaining focus will then be signaled as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>gain_focus(item, chain)</b></i>.
	-- @param focus Command or entry to assign.<br><br>
	-- If this is a number, it must be an integer between 1 and the item count, inclusive.
	-- This index will be assigned.<br><br>
	-- If it is one of the strings <b>"-"</b> or <b>"+"</b>, the index will be rotated one
	-- step backward or forward, respectively.<br><br>
	-- If neither of the above is the case, <i>focus</i> is assumed to be an item in the
	-- chain. In this case, the index is moved to that item. This is an error if the item
	-- is not present.
	-- @see FocusChain:GetFocus
	function FocusChain:SetFocus (focus)
		local cur = self:GetFocus()

		if cur then
			local index = self[_index]

			-- If a command is passed instead of a name, get the item index.
			if focus == "-" or focus == "+" then
				focus = RotateIndex(index, #self[_chain], focus == "-")

			-- Otherwise, find the index of the new focus.	
			else
				if type(focus) ~= "number" then
					focus = Find(self[_chain], focus, true)
				end

				assert(self[_chain][focus], "Invalid focus entry")
			end

			-- On a switch, indicate that the old focus is lost and the new focus gained.
			if index ~= focus then
				cur:Signal("lose_focus", self)

				self[_index] = focus

				self[_chain][focus]:Signal("gain_focus", self)
			end
		end
	end

	--- Class constructor.
	function FocusChain:__cons ()
		self[_chain] = {}
	end
end)