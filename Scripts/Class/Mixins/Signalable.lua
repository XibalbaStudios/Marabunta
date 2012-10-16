-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- This class provides an interface for objects that should be able to receive signals
-- and react to them if they have the proper handler.<br><br>
-- Class.
module Signalable
]]

-- Standard imports --
local assert = assert
local rawget = rawget

-- Modules --
local table_ops = require("table_ops")
local var_preds = require("var_preds")

-- Imports --
local IsCallable = var_preds.IsCallable
local IsCallableOrNil = var_preds.IsCallableOrNil
local IsTable = var_preds.IsTable

-- Slot store --
local Slots = table_ops.SubTablesOnDemand("k")

-- Signalable class definition --
class.Define("Signalable", function(Signalable)
	-- Returns: Slot, or nil
	local function GetSlot (S, signal)
		local slot_table = rawget(Slots, signal)

		return slot_table and slot_table[S]
	end

	---
	-- @class function
	-- @name Signalable:GetSlot
	-- @param signal Signal name.
	-- @return Slot, or <b>nil</b> if absent.
	-- @see Signalable:SetSlot
	Signalable.GetSlot = GetSlot

	-- Adds a listener to a signal
	local function Add (S, signal, slot)
		Slots[signal][S] = slot
	end

	--- Multiple-signal variant of <b>Signalable:SetSlot</b>.
	-- @param signals_and_slots Table of (<i>signal</i>, <i>slot</i>) pairs.
	-- @see Signalable:SetSlot
	function Signalable:SetMultipleSlots (signals_and_slots)
		assert(IsTable(signals_and_slots), "Invalid signals / slots table")

		for _, v in pairs(signals_and_slots) do
			assert(IsCallable(v), "Uncallable slot")
		end

		for k, v in pairs(signals_and_slots) do
			Add(self, k, v)
		end
	end

	---
	-- @param signal Non-<b>nil</b> signal name.
	-- @param slot The handler to associate with <i>signal</i>, or <b>nil</b> to clear it.
	-- @see Signalable:GetSlot
	function Signalable:SetSlot (signal, slot)
		assert(signal ~= nil, "Invalid signal")
		assert(IsCallableOrNil(slot), "Uncallable slot")

		Add(self, signal, slot)
	end

	--- Sends a signal to this item. If a slot exists, it is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>slot(item, ...)</b></i>.
	-- @param signal Non-<b>nil</b> signal name.
	-- @param ... Slot arguments.
	-- @return Call results, if the slot existed. Otherwise, nothing.
	function Signalable:Signal (signal, ...)
		assert(signal ~= nil, "Invalid signal")

		local slot = GetSlot(self, signal)

		if slot then
			return slot(self, ...)
		end
	end
end)