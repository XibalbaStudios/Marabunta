-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A variable family provides a minimal database for variables, with special support
-- for various types. In addition, a family has several "tiers" of these variables to
-- allow rollback if the current set should become invalid.<br><br>
-- Class.
module VarFamily
]]

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local max = math.max
local min = math.min
local pairs = pairs
local rawget = rawget
local setmetatable = setmetatable

-- Modules --
local bit = require("bit")
local cache_ops = require("cache_ops")
local class = require("class")
local coroutine_ops = require("coroutine_ops")
local func_ops = require("func_ops")
local iterators = require("iterators")
local table_ops = require("table_ops")
local var_preds = require("var_preds")

-- Imports --
local band = bit.band
local bor = bit.bor
local lshift = bit.lshift
local rshift = bit.rshift

-- Unique member keys --
local _auto_propagate = {}
local _fetch = {}
local _groups = {}
local _is_updating = {}
local _tier_count = {}

-- Cookies --
local _set_name = {}

-- VarFamily class definition --
class.Define("VarFamily", function(VarFamily)
	-- Lookup metatables --
	local Metas = {}

	-- Variable lookup builder
	local function MakeMeta (what, def, is_prim)
		local meta

		if is_prim then
			meta = { __index = def, is_prim = true }
		else
			meta = lazy_ops.MakeOnDemand_Meta(def)
		end

		function meta:set_current (VF, group_cur)
			VF[self] = setmetatable(group_cur, self)
		end

		Metas[what] = meta

		-- Group's current variables access
		return function(VF)
			return VF[meta]
		end,

		-- Helper to build callbacks over iterators for arrays and varargs
		function(name, aux)
			VarFamily[name .. "_Array"] = function(VF, array) return aux(VF[meta], ipairs(array)) end
			VarFamily[name .. "_Varargs"] = function(VF, ...) return aux(VF[meta], iterators.Args(...)) end
		end,

		-- Helper variant with an injected extra argument, for setting
		function(name, aux)
			VarFamily[name .. "_Array"] = function(VF, extra, array) aux(VF[meta], extra, ipairs(array)) end
			VarFamily[name .. "_Varargs"] = function(VF, extra, ...) aux(VF[meta], extra, iterators.Args(...)) end
		end
	end

	-- Helper to establish working set of variables
	local function SetupWorkingSet (VF)
		for what, group in pairs(VF[_groups]) do
			Metas[what]:set_current(VF, group[1])
		end
	end

	do
		-- Boolean variable helpers --
		local Bools, Pair, PairSet = MakeMeta("bools", func_ops.False, true)

		--- 
		-- @class function
		-- @name VarFamily:AllTrue_Array
		-- @param array Array of bool variable names.
		-- @return If true, all bools were true (or array was empty).
		-- @see VarFamily:IsTrue

		--- Vararg variant of <b>VarFamily:AllTrue_Array</b>.
		-- @class function
		-- @name VarFamily:AllTrue_Varargs
		-- @param ... Bool variable names.
		-- @return If true, all bools were true (or argument list was empty).
		-- @see VarFamily:AllTrue_Array, VarFamily:IsTrue

		Pair("AllTrue", function(bools, iter, s, v0, cleanup)
			for _, name in iter, s, v0 do
				if not bools[name] then
					(cleanup or func_ops.NoOp)()

					return false
				end
			end

			return true
		end)

		--- 
		-- @class function
		-- @name VarFamily:AnyTrue_Array
		-- @param array Array of bool variable names.
		-- @return If true, at least one bool was true.
		-- @see VarFamily:IsTrue

		--- Vararg variant of <b>VarFamily:AnyTrue_Array</b>.
		-- @class function
		-- @name VarFamily:AnyTrue_Varargs
		-- @param ... Bool variable names.
		-- @return If true, at least one bool was true.
		-- @see VarFamily:AnyTrue_Array, VarFamily:IsTrue

		Pair("AnyTrue", function(bools, iter, s, v0, cleanup)
			for _, name in iter, s, v0 do
				if bools[name] then
					(cleanup or func_ops.NoOp)()

					return true
				end
			end

			return false
		end)

		--- 
		-- @class function
		-- @name VarFamily:AllFalse_Array
		-- @param array Array of bool variable names.
		-- @return If true, all bools were false (or array was empty).
		-- @see VarFamily:AllTrue_Array, VarFamily:IsFalse

		--- Vararg variant of <b>VarFamily:AllFalse_Array</b>.
		-- @class function
		-- @name VarFamily:AllFalse_Varargs
		-- @param ... Bool variable names.
		-- @return If true, all bools were false (or argument list was empty).
		-- @see VarFamily:AllFalse_Array, VarFamily:IsFalse

		--- 
		-- @class function
		-- @name VarFamily:AnyFalse_Array
		-- @param array Array of bool variable names.
		-- @return If true, at least one bool was false.
		-- @see VarFamily:AnyTrue_Array, VarFamily:IsFalse

		--- Vararg variant of <b>VarFamily:AnyFalse_Array</b>.
		-- @class function
		-- @name VarFamily:AnyFalse_Varargs
		-- @param ... Bool variable names.
		-- @return If true, at least one bool was false.
		-- @see VarFamily:AnyFalse_Array, VarFamily:IsFalse

		for _, name, ref in iterators.ArgsByN(2,
			"AllFalse", "AnyTrue",
			"AnyFalse", "AllTrue"
		) do
			for _, suffix in iterators.Args("_Array", "_Varargs") do
				VarFamily[name .. suffix] = func_ops.Negater_Multi(VarFamily[ref .. suffix])
			end
		end

		-- Helper to flip a bool variable
		local function FlipIf (bools, name, ref)
			local bool = bools[name]

			if bool == ref then
				bools[name] = not ref
			end

			return bool
		end

		---
		-- @param name Bool variable name.
		-- @return If true, the bool is false.
		-- @see VarFamily:IsTrue
		function VarFamily:IsFalse (name)
			return not Bools(self)[name]
		end

		--- Variant of <b>VarFamily:IsFalse</b> that flips the bool to true if it was false.
		-- @param name Bool variable name.
		-- @return If true, the bool was false.
		-- @see VarFamily:IsFalse
		function VarFamily:IsFalse_Flip (name)
			return FlipIf(Bools(self), name, false)
		end

		---
		-- @param name Bool variable name.
		-- @return If true, the bool is true.
		-- @see VarFamily:IsFalse
		function VarFamily:IsTrue (name)
			return Bools(self)[name]
		end

		--- Variant of <b>VarFamily:IsTrue</b> that flips the bool to false if it was true.
		-- @param name Bool variable name.
		-- @return If true, the bool was true.
		-- @see VarFamily:IsTrue
		function VarFamily:IsTrue_Flip (name)
			return FlipIf(Bools(self), name, true)
		end

		--- Synonym for <b>VarFamily:IsTrue</b>.
		-- @class function
		-- @name VarFamily:GetBool
		-- @see VarFamily:IsTrue
		VarFamily.GetBool = VarFamily.IsTrue

		-- Helper to build Set*, Set*_Array, Set*_Varargs functions for true and false
		local function SetBoolGroup (how)
			local bool = how == "True"
			local name = "Set" .. how

			VarFamily[name] = function(VF, name) Bools(VF)[name] = bool end

			Pair(name, function(bools, iter, s, v0)
				for _, name in iter, s, v0 do
					bools[name] = bool
				end
			end)
		end

		--- Sets a bool variable as false.
		-- @class function
		-- @name VarFamily:SetFalse
		-- @param name Non-<b>nil</b> bool variable name.
		-- @see VarFamily:IsFalse, VarFamily:SetTrue

		--- Array variant of <b>VarFamily:SetFalse</b>.
		-- @class function
		-- @name VarFamily:SetFalse_Array
		-- @param array Array of non-<b>nil</b> bool variable names.
		-- @see VarFamily:IsFalse, VarFamily:SetFalse

		--- Vararg variant of <b>VarFamily:SetFalse</b>.
		-- @class function
		-- @name VarFamily:SetFalse_Varargs
		-- @param ... Non-<b>nil</b> bool variable names.
		-- @see VarFamily:IsFalse, VarFamily:SetFalse

		SetBoolGroup("False")

		--- Sets a bool variable as true.
		-- @class function
		-- @name VarFamily:SetTrue
		-- @param name Non-<b>nil</b> bool variable name.
		-- @see VarFamily:IsTrue, VarFamily:SetFalse

		--- Array variant of <b>VarFamily:SetTrue</b>.
		-- @class function
		-- @name VarFamily:SetTrue_Array
		-- @param array Array of non-<b>nil</b> bool variable names.
		-- @see VarFamily:IsTrue, VarFamily:SetTrue

		--- Vararg variant of <b>VarFamily:SetTrue</b>.
		-- @class function
		-- @name VarFamily:SetTrue_Varargs
		-- @param ... Non-<b>nil</b> bool variable names.
		-- @see VarFamily:IsTrue, VarFamily:SetTrue

		SetBoolGroup("True")

		---
		-- @param name Non-<b>nil</b> bool variable name.
		-- @param bool If true, sets the variable as true; otherwise false.
		-- @see VarFamily:SetFalse, VarFamily:SetTrue
		function VarFamily:SetBool (name, bool)
			Bools(self)[name] = not not bool
		end

		--- Array variant of <b>VarFamily:SetBool</b>.
		-- @class function
		-- @name VarFamily:SetBool_Array
		-- @param bool If true, sets each variable as true; otherwise false.
		-- @param array Array of non-<b>nil</b> bool variable names.
		-- @see VarFamily:SetBool

		--- Vararg variant of <b>VarFamily:SetBool</b>.
		-- @class function
		-- @name VarFamily:SetBool_Varargs
		-- @param bool If true, sets each variable as true; otherwise false.
		-- @param ... Non-<b>nil</b> bool variable names.
		-- @see VarFamily:SetBool

		PairSet("SetBool", function(bools, bool, iter, s, v0)
			bool = not not bool

			for _, name in iter, s, v0 do
				bools[name] = bool
			end
		end)

		--- Table variant of <b>VarFamily:SetBool</b>.
		-- @param t Table of name-value pairs, where each value is true or false, to be
		-- assigned to the associated named bool variable.
		-- @see VarFamily:SetBool
		function VarFamily:SetBool_Table (t)
			local bools = Bools(self)

			for k, v in pairs(t) do
				bools[k] = not not v
			end
		end

		--- Toggles a bool variable from true to false or vice versa.
		-- @param name Non-<b>nil</b> bool variable name.
		-- @see VarFamily:IsFalse, VarFamily:IsTrue, VarFamily:SetFalse, VarFamily:SetTrue
		function VarFamily:ToggleBool (name)
			local bools = Bools(self)

			bools[name] = not bools[name]
		end

		--- Array variant of <b>VarFamily:ToggleBool</b>.
		-- @class function
		-- @name VarFamily:ToggleBool_Array
		-- @param bool
		-- @param array Array of non-<b>nil</b> bool variable names.
		-- @see VarFamily:ToggleBool

		--- Vararg variant of <b>VarFamily:ToggleBool</b>.
		-- @class function
		-- @name VarFamily:ToggleBool_Varargs
		-- @param bool
		-- @param ... Non-<b>nil</b> bool variable names.
		-- @see VarFamily:ToggleBool

		Pair("ToggleBool", function(bools, iter, s, v0)
			for _, name in iter, s, v0 do
				bools[name] = not bools[name]
			end
		end)

		--- Looks up several bool variables and sets each bit of an integer: 1 if the bool
		-- is true and 0 otherwise. The first variable is at bit 0.<br><br>
		-- Any leftover bits are set to 0.
		-- @class function
		-- @name VarFamily:GetBits_Array
		-- @param array Array of bool variable names (up to 32).
		-- @return Integer with bits set.
		-- @see VarFamily:SetFromBits_Array

		--- Vararg variant of <b>VarFamily:GetBits_Array</b>.
		-- @class function
		-- @name VarFamily:GetBits_Varargs
		-- @param ... Bool variable names (up to 32).
		-- @return Integer with bits set.
		-- @see VarFamily:GetBits_Array, VarFamily:SetFromBits_Varargs

		Pair("GetBits", function(bools, iter, s, v0)
			local bits = 0

			for i, name in iter, s, v0 do
				if bools[name] then
					bits = bor(bits, lshift(1, i - 1))
				end
			end

			return bits
		end)

		--- Sets several bool variables based on the bits from an integer: true for a 1 bit
		-- and false otherwise. The first variable uses bit 0.
		-- @class function
		-- @name VarFamily:SetFromBits_Array
		-- @param bits Integer with bits set.
		-- @param array Array of non-<b>nil</b> bool variable names.
		-- @see VarFamily:GetBits_Array

		--- Vararg variant of <b>VarFamily:SetFromBits_Array</b>.
		-- @class function
		-- @name VarFamily:SetFromBits_Varargs
		-- @param bits Integer with bits set.
		-- @param ... Non-<b>nil</b> bool variable names.
		-- @see VarFamily:GetBits_Varargs, VarFamily:SetFromBits_Array

		PairSet("SetFromBits", function(bools, bits, iter, s, v0)
			for _, name in iter, s, v0 do
				bools[name] = band(bits, 0x1) ~= 0

				bits = rshift(bits, 1)
			end
		end)

		-- Lookup / name setter cache --
		local LookupCache = cache_ops.SimpleCache()

		-- Helper to build cached wait operations
		local ToggleBool = VarFamily.ToggleBool

		local function Waiter (op, flip)
			return function(VF, name, update)
				-- Grab or build a lookup operation.
				local lookup = LookupCache("pull") or function(VF_, arg)
					if VF_ == _set_name then
						name = arg
					else
						return Bools(VF_)[name]
					end
				end

				-- Bind the name, do the wait, and toggle the condition if desired.
				lookup(_set_name, name)

				local is_done = op(lookup, update, VF)

				if flip and is_done then
					ToggleBool(VF, name)
				end

				-- Unbind the name and put the operation in the cache. Indicate whether
				-- the operation finished normally.
				lookup(_set_name, nil)

				LookupCache(lookup)

				return is_done
			end
		end

		--- Waits until a bool is false.<br><br>
		-- This must be called within a coroutine.
		-- @class function
		-- @name VarFamily:WaitUntilFalse
		-- @param name Non-<b>nil</b> bool variable name.
		-- @param update Optional update routine, as per <b>coroutine_ops.WaitWhile</b>,
		-- which receives <i>name</i> as its argument.
		-- @return If true, the wait completed.
		-- @see VarFamily:WaitUntilTrue, VarFamily:IsFalse, ~coroutine_ops.WaitWhile

		--- Variant of <b>VarFamily:WaitUntilFalse</b> which flips the bool to true if the
		-- wait completes.
		-- @class function
		-- @name VarFamily:WaitUntilFalse_Flip
		-- @param name Non-<b>nil</b> bool variable name.
		-- @param update Optional update routine.
		-- @return If true, the wait completed.
		-- @see VarFamily:WaitUntilFalse, VarFamily:IsFalse, ~coroutine_ops.WaitWhile

		--- Waits until a bool is true.<br><br>
		-- This must be called within a coroutine.
		-- @class function
		-- @name VarFamily:WaitUntilTrue
		-- @param name Non-<b>nil</b> bool variable name.
		-- @param update Optional update routine, as per <b>coroutine_ops.WaitUntil</b>,
		-- which receives <i>name</i> as its argument.
		-- @return If true, the wait completed.
		-- @see VarFamily:WaitUntilFalse, VarFamily:IsTrue, ~coroutine_ops.WaitUntil

		--- Variant of <b>VarFamily:WaitUntilTrue</b> which flips the bool to false if the
		-- wait completes.
		-- @class function
		-- @name VarFamily:WaitUntilTrue_Flip
		-- @param name Non-<b>nil</b> bool variable name.
		-- @param update Optional update routine.
		-- @return If true, the wait completed.
		-- @see VarFamily:WaitUntilTrue, VarFamily:IsTrue, ~coroutine_ops.WaitUntil

		for i, name in iterators.Args("WaitUntilFalse", "WaitUntilTrue") do
			local op = coroutine_ops[i < 2 and "WaitWhile" or "WaitUntil"]

			VarFamily[name] = Waiter(op)
			VarFamily[name .. "_Flip"] = Waiter(op, true)
		end
	end

	do
		-- Number variable helpers --
		local Nums, Pair = MakeMeta("nums", func_ops.Zero, true)

		---
		-- @param name Number variable name.
		-- @return Value of number, 0 by default.
		-- @see VarFamily:SetNumber
		function VarFamily:GetNumber (name)
			return Nums(self)[name]
		end

		---
		-- @param name Non-<b>nil</b> number variable name.
		-- @param value Value to assign.
		-- @see VarFamily:GetNumber
		function VarFamily:SetNumber (name, value)
			Nums(self)[name] = value
		end

		-- Optional upper-bounding helper
		local function UpperBounded (value, ubound)
			return (ubound and min or func_ops.Identity)(value, ubound)
		end

		--- Gets a number variable and adds to it.
		-- @param name  Non-<b>nil</b> number variable name.
		-- @param amount Amount to add.
		-- @param ubound If present, sum is clamped to this amount.
		-- @see VarFamily:GetNumber, VarFamily:SubNumber
		function VarFamily:AddNumber (name, amount, ubound)
			local nums = Nums(self)

			nums[name] = UpperBounded(nums[name] + amount, ubound)
		end

		--- Gets a number variable and increments it by 1.
		-- @param name Non-<b>nil</b> number variable name.
		-- @param ubound If present, sum is clamped to this amount.
		-- @see VarFamily:DecNumber, VarFamily:GetNumber
		function VarFamily:IncNumber (name, ubound)
			local nums = Nums(self)

			nums[name] = UpperBounded(nums[name] + 1, ubound)
		end

		-- Optional lower-bounding helper
		local function LowerBounded (value, lbound)
			return (lbound and max or func_ops.Identity)(value, lbound)
		end

		--- Gets a number variable and subtracts from it.
		-- Non-<b>nil</b> number variable name.
		-- @param amount Amount to subtract.
		-- @param lbound If present, sum is clamped to this amount.
		-- @see VarFamily:AddNumber, VarFamily:GetNumber
		function VarFamily:SubNumber (name, amount, lbound)
			local nums = Nums(self)

			nums[name] = LowerBounded(nums[name] - amount, lbound)
		end

		--- Gets a number variable and decrements it by 1.
		-- @param Non-<b>nil</b> number variable name.
		-- @param lbound If present, sum is clamped to this amount.
		-- @see VarFamily:GetNumber, VarFamily:IncNumber
		function VarFamily:DecNumber (name, lbound)
			local nums = Nums(self)

			nums[name] = LowerBounded(nums[name] - 1, lbound)
		end

		--- Gets a number variable and divides it.
		-- @param Non-<b>nil</b> number variable name.
		-- @param amount Amount by which number is divided.
		-- @see VarFamily:GetNumber
		function VarFamily:DivNumber (name, amount)
			local nums = Nums(self)

			nums[name] = nums[name] / amount
		end

		--- Gets a number variable and multiplies it.
		-- @param Non-<b>nil</b> number variable name.
		-- @param amount Amount by which number is multiplied.
		-- @see VarFamily:GetNumber
		function VarFamily:MulNumber (name, amount)
			local nums = Nums(self)

			nums[name] = nums[name] * amount
		end

		--- Gets several number variables and multiplies them together.
		-- @class function
		-- @name VarFamily:Product_Array
		-- @param array Array of non-<b>nil</b> number variable names.
		-- @return Product of all numbers (or 0 if the array is empty). Given a single
		-- number, returns its value.
		-- @see VarFamily:GetNumber

		--- Vararg variant of <b>VarFamily:Product_Array</b>.
		-- @class function
		-- @name VarFamily:Product_Varargs
		-- @param ... Non-<b>nil</b> number variable names.
		-- @return Product of all numbers (or 0 if the argument list is empty). Given a
		-- single number, returns its value.
		-- @see VarFamily:GetNumber, VarFamily:Product_Array

		Pair("Product", function(nums, iter, s, v0)
			local product

			for _, name in iter, s, v0 do
				product = (product or 1) * nums[name]
			end

			return product or 0
		end)

		--- Gets several number variables and sums them together.
		-- @class function
		-- @name VarFamily:Sum_Array
		-- @param array Array of non-<b>nil</b> number variable names.
		-- @return Sum of all numbers (or 0 if the array is empty). Given a single number,
		-- returns its value.
		-- @see VarFamily:GetNumber

		--- Vararg variant of <b>VarFamily:Sum_Array</b>.
		-- @class function
		-- @name VarFamily:Sum_Varargs
		-- @param ... Non-<b>nil</b> number variable names.
		-- @return Sum of all numbers (or 0 if the argument list is empty). Given a single
		-- number, returns its value.
		-- @see VarFamily:GetNumber, VarFamily:Sum_Array

		Pair("Sum", function(nums, iter, s, v0)
			local sum = 0

			for _, name in iter, s, v0 do
				sum = sum + nums[name]
			end

			return sum
		end)
	end

	-- Helper to pull instances
	local function Pull (group, name)
		local var = rawget(group, name)

		group[name] = nil

		return var
	end

	do
		-- Raw variable helper --
		local Raw = MakeMeta("raw", func_ops.NoOp, true)

		--- Copies a raw variable into another slot.
		-- @param name_from Source raw variable name.
		-- @param name_to Non-<b>nil</b> target raw variable name.
		-- @see VarFamily:MoveRawTo
		function VarFamily:CopyRawTo (name_from, name_to)
			local raws = Raw(self)

			raws[name_to] = raws[name_from]
		end

		--- Moves a raw variable into another slot.
		-- @param name_from Non-<b>nil</b> source raw variable name.
		-- @param name_to Non-<b>nil</b> target raw variable name.
		-- @see VarFamily:CopyRawTo
		function VarFamily:MoveRawTo (name_from, name_to)
			local raws = Raw(self)

			raws[name_to] = raws[name_from]
			raws[name_from] = nil
		end

		---
		-- @param name Raw variable name.
		-- @return Raw variable, or <b>nil</b> if absent.
		-- @see VarFamily:SetRaw
		function VarFamily:GetRaw (name)
			return Raw(self)[name]
		end

		--- Pulling variant of <b>VarFamily:GetRaw</b>.
		-- @param name Raw variable name.
		-- @return Raw variable, or <b>nil</b> if absent.
		-- @see VarFamily:GetRaw
		function VarFamily:PullRaw (name)
			return Pull(Raw(self), name)
		end

		---
		-- @param name Non-<b>nil</b> raw variable name.
		-- @param value Value to assign, or <b>nil</b> to clear.
		-- @see VarFamily:GetRaw
		function VarFamily:SetRaw (name, value)
			Raw(self)[name] = value
		end

		--- Table variant of <b>VarFamily:SetRaw</b>.
		-- @param t Table of name-value pairs, where each value is assigned to the associated
		-- named raw variable
		-- @see VarFamily:SetRaw
		function VarFamily:SetRaw_Table (t)
			table_ops.Copy_WithTable(Raw(self), t)
		end
	end

	do
		-- Helper to peek for instances of complex types
		local function Peek (group, name)
			return rawget(group, name)
		end

		-- Helper to build types with get / peek / pull behavior
		local function BuildFuncs (name, type, ...)
			local meta = MakeMeta(name, class.InstanceMaker(type, ...))

			VarFamily["Get" .. type] = function(VF, name) return meta(VF)[name] end
			VarFamily["Peek" .. type] = function(VF, name) return Peek(meta(VF), name) end
			VarFamily["Pull" .. type] = function(VF, name) return Pull(meta(VF), name) end

			return meta
		end

		---
		-- @class function
		-- @name VarFamily:GetDelegate
		-- @param name Delegate variable name.
		-- @return <a href="Delegate.html">Delegate</a>, which will be first instantiated if
		-- necessary, with a no-op core.<br><br>
		-- Propagated delegates are cloned for each tier.

		--- Peeking variant of <b>VarFamily:GetDelegate</b>.
		-- @class function
		-- @name VarFamily:PeekDelegate
		-- @param name Delegate variable name.
		-- @return <a href="Delegate.html">Delegate</a>, or <b>nil</b> if <b>GetDelegate</b>
		-- has not yet been called with <i>name</i>.
		-- @see VarFamily:GetDelegate

		--- Pulling variant of <b>VarFamily:GetDelegate</b>.
		-- @class function
		-- @name VarFamily:PullDelegate
		-- @param name Delegate variable name.
		-- @return <a href="Delegate.html">Delegate</a>, or <b>nil</b> if <b>GetDelegate</b>
		-- has not yet been called with <i>name</i>.
		-- @see VarFamily:GetDelegate

		local Delegates = BuildFuncs("delegates", "Delegate", func_ops.NoOp)

		--- Calls delegate, instantiating it first if necessary with a no-op core.
		-- @param Delegate variable name.
		-- @param ... Call arguments.
		-- @return Call results.
		-- @see VarFamily:GetDelegate
		function VarFamily:CallDelegate (name, ...)
			return Delegates(self)[name](...)
		end

		--- Peeking variant of <b>VarFamily:GetTimeline</b>.
		-- @class function
		-- @name VarFamily:PeekTimeline
		-- @param name Timeline variable name.
		-- @return <a href="Timeline.html">Timeline</a>, or <b>nil</b> if <b>GetTimeline</b>
		-- has not yet been called with <i>name</i>.
		-- @see VarFamily:GetTimeline

		--- Pulling variant of <b>VarFamily:GetTimeline</b>.
		-- @class function
		-- @name VarFamily:PullTimeline
		-- @param name Timeline variable name.
		-- @return <a href="Timeline.html">Timeline</a>, or <b>nil</b> if <b>GetTimeline</b>
		-- has not yet been called with <i>name</i>.
		-- @see VarFamily:GetTimeline

		local Timelines = BuildFuncs("timelines", "Timeline")

		---
		-- @param name Timeline variable name.
		-- @return <a href="Timeline.html">Timeline</a>, which will be first instantiated if
		-- necessary.<br><br>
		-- Propagated timelines are cloned for each tier.
		function VarFamily:GetTimeline (name)
			local timelines = Timelines(self)

			if self[_is_updating] then
				return Peek(timelines, name) or self[_fetch][name]
			else
				return timelines[name]
			end
		end

		---
		-- @class function
		-- @name VarFamily:GetTimer
		-- @param name Timer variable name.
		-- @return <a href="Timer.html">Timer</a>, which will be first instantiated if necessary.<br><br>
		-- Propagated timers are cloned for each tier.

		--- Peeking variant of <b>VarFamily:GetTimer</b>.
		-- @class function
		-- @name VarFamily:PeekTimer
		-- @param name Timer variable name.
		-- @return <a href="Timer.html">Timer</a>, or <b>nil</b> if <b>GetTimer</b> has
		-- not yet been called with <i>name</i>.
		-- @see VarFamily:GetTimer

		--- Pulling variant of <b>VarFamily:GetTimer</b>.
		-- @class function
		-- @name VarFamily:PullTimer
		-- @param name Timer variable name.
		-- @return <a href="Timer.html">Timer</a>, or <b>nil</b> if <b>GetTimer</b> has
		-- not yet been called with <i>name</i>.
		-- @see VarFamily:GetTimer

		local Timers = BuildFuncs("timers", "Timer")

		-- Protected update
		local function Update (VF, dt, arg)
			VF[_is_updating] = true

			for _, timeline in pairs(Timelines(VF)) do
				timeline(dt, arg)
			end

			for _, timer in pairs(Timers(VF)) do
				timer:Update(dt)
			end
		end

		-- Update cleanup
		local function UpdateDone (VF)
			table_ops.Move_WithTable(Timelines(VF), VF[_fetch])

			VF[_is_updating] = false
		end

		--- Updates all current timelines and timers.
		-- @param dt Time step.
		-- @param arg Argument to timelines.
		function VarFamily:Update (dt, arg)
			func_ops.Try(Update, UpdateDone, self, dt, arg)
		end
	end

	do
		-- Automatic propagation helper
		local function AutoPropagate (VF)
			for what, list in pairs(VF[_auto_propagate]) do
				local group = VF[_groups][what]
				local op = Metas[what].is_prim and func_ops.Identity or class.Clone

				for name, target in pairs(list) do
					for i = 2, target do
						group[i][name] = op(group[1][name])
					end
				end
			end
		end

		-- Group propagate operations
		local function GetOps (what)
			if Metas[what].is_prim then
				return table_ops.Copy
			else
				return table_ops.Map, class.Clone
			end
		end

		-- Propagates copies of a tier downward into the lower tiers
		local function Propagate (VF, top)
			for what, group in pairs(VF[_groups]) do
				local op, arg = GetOps(what)

				for i = 1, top - 1 do
					group[i] = op(group[top], arg)
				end
			end

			SetupWorkingSet(VF)
		end

		--- Adds a variable to the auto-propagate list; such variables are automatically
		-- shadowed in all tiers up through <i>target</i>.
		-- @param group Variable group, which may be <b>"bools"</b>, <b>"nums"</b>, <b>"raw</b>,
		-- <b>"delegates"</b>, <b>"timers"</b>, or <b>"timelines"</b>.
		-- @param name Non-<b>nil</b> variable name.
		-- @param target Highest tier in propagation. 
		-- @see VarFamily:RemoveFromAutoPropagatedVars, VarFamily:PropagateDownFrom, VarFamily:PropagateUpTo
		function VarFamily:AddToAutoPropagatedVars (group, name, target)
			assert(Metas[group], "Invalid group")
			assert(name ~= nil, "Invalid name")
			assert(var_preds.IsPositiveInteger(target) and target <= self[_tier_count], "Invalid target tier")

			self[_auto_propagate][group][name] = target > 1 and target or nil
		end

		--- Replaces each lower tier with copies of the tier at <i>top</i>, cloning any
		-- non-raw, non-primitive variables.
		-- @param top Tier to be propagated.
		-- @see VarFamily:PropagateUpTo
		function VarFamily:PropagateDownFrom (top)
			assert(var_preds.IsPositiveInteger(top) and top <= self[_tier_count], "Invalid top tier")
			assert(not self[_is_updating], "Cannot wipe while updating")

			if top > 1 then
				AutoPropagate(self)

				Propagate(self, top)
			end
		end

		--- Replaces each tier from 2 to <i>target</i> with copies of the tier at 1 (the
		-- working set), cloning any non-raw, non-primitive variables.
		-- @param target Highest tier in propagation.
		-- @see VarFamily:PropagateDownFrom
		function VarFamily:PropagateUpTo (target)
			assert(var_preds.IsPositiveInteger(target) and target <= self[_tier_count], "Invalid target tier")
			assert(not self[_is_updating], "Cannot commit while updating")

			if target > 1 then
				AutoPropagate(self)

				for what, group in pairs(self[_groups]) do
					local op, arg = GetOps(what)

					group[target] = op(group[1], arg)
				end

				Propagate(self, target)
			end
		end

		--- Removes a variable from the auto-propagation list.
		-- @param group Variable group, as per <b>VarFamily:AddToAutoPropagatedVars</b>.
		-- @param name Non-<b>nil</b> variable name.
		-- @see VarFamily:AddToAutoPropagatedVars, VarFamily:PropagateDownFrom, VarFamily:PropagateUpTo
		function VarFamily:RemoveFromAutoPropagatedVars (group, name)
			assert(Metas[group], "Invalid group")
			assert(name ~= nil, "Invalid name")

			self[_auto_propagate][group][name] = nil
		end
	end

	---
	-- @return Number of variable tiers.
	function VarFamily:GetTierCount ()
		return self[_tier_count]
	end

	---
	-- @param what Variable type, one of <b>"bools"</b>, <b>"nums"</b>, <b>"raw"</b>,
	-- <b>"timers"</b>, <b>"timelines"</b>, <b>"delegates"</b>.
	-- @return Fresh table with variables as (name, value) pairs.<br><br>
	-- Variables that only exist implicitly are not added.<br><br>
	-- Non-primitive types are not cloned.
	function VarFamily:GetVars (what)
		local vars = assert(Metas[what], "Invalid variable type")

		return table_ops.Copy(self[vars])
	end

	--- Class constructor.
	-- @param tier_count Number of variable tiers to maintain, which must be at least 1.
	function VarFamily:__cons (tier_count)
		assert(var_preds.IsPositiveInteger(tier_count), "Invalid tier count")

		-- Automatically propagated variables --
		self[_auto_propagate] = table_ops.SubTablesOnDemand()

		-- Variables groups --
		self[_groups] = {}

		for what in pairs(Metas) do
			self[_groups][what] = table_ops.ArrayOfTables(tier_count)
		end

		SetupWorkingSet(self)

		-- Timeline fetch list --
		self[_fetch] = setmetatable({}, Metas.timelines)

		-- Number of variable tiers --
		self[_tier_count] = tier_count
	end
end)