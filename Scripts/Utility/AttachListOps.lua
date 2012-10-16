-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert

-- Imports --
local IsType = class.IsType
local New = class.New
local NoOp = func_ops.NoOp
local Weak = table_ops.Weak

--- Utilities to build mixin operations for objects that can be attached, along with other
-- objects, to a parent, where order may be important.<br><br>
-- The parent and neighbor object state is unique to each build, and thus an object type can
-- make several sets of operations if it has more complex membership needs.
module "attach_list_ops"

--- Builds a set of operations that can be set directly, or composed into, member functions
-- of attachable hierarchical objects.
-- @param base Class name of objects' base class.
-- @return Operations table with the following methods:<br><br>
-- - <b>attach</b>: Called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>parent:attach(object, on_attach, ...)</b></i>,<br><br>
-- where any varargs will be passed to <i>on_attach</i>.<br><br>
-- If <i>object</i> is not already attached to <i>parent</i>, it is first detached
-- from its current parent, if it has one, and added to the end of <i>parent</i>'s attach list.<br><br>
-- If provided, the <i>on_attach</i> logic is then called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>on_attach(parent, object, is_new_parent, ...)</b></i>,<br><br>
-- where <i>is_new_parent</i> is true if <i>object</i> was not already attached to <i>parent</i>.<br><br>
-- - <b>chain_iter</b>: Iterator, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>object:chain_iter()</b></i>,<br><br>
-- will traverse up the hierarchy, returning each object along the way, starting with <i>
-- object</i> itself.<br><br>
-- - <b>detach</b>: Called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>object:detach(on_detach, ...)</b></i>,<br><br>
-- where any varargs will be passed to <i>on_detach</i>.<br><br>
-- If <i>object</i> has no parent, this is a no-op.<br><br>
-- If provided, the <i>on_detach</i> logic is first called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>on_detach(object, parent, ...)</b></i>.<br><br>
-- Following this, <i>object</i> is removed from its parent's attach list.<br><br>
-- - <b>get_back</b>: Called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>parent:get_back()</b></i>,<br><br>
-- will return the last object in <i>parent</i>'s attach list, or <b>nil</b> if it is empty.<br><br>
-- - <b>get_head</b>: Called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>parent:get_head()</b></i>,<br><br>
-- will return the first object in <i>parent</i>'s attach list, or <b>nil</b> if it is empty.<br><br>
-- - <b>get_parent</b>: Called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>object:get_parent()</b></i>,<br><br>
-- will return <i>object</i>'s parent, or <b>nil</b> if <i>object</i> is unattached.<br><br>
-- - <b>is_attached</b>: Predicate, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>object:is_attached()</b></i>.<br><br>
-- - <b>list_iter</b>: Iterator, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>parent:list_iter(reverse)</b></i>,<br><br>
-- will iterate over <i>parent</i>'s attach list, returning each object along the way.<br><br>
-- If <i>reverse</i>is true, it will traverse back-to-front, otherwise front-to-back.<br><br>
-- - <b>promote</b>: Called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>object:promote()</b></i>,<br><br>
-- will move <i>object</i> to the front of its parent's attach list, if attached.<br><br>
-- @return Unique member key for an object's attach list, of type <a href="OrderedSet.html">
-- OrderedSet</a>. An object will not be given a list until necessary.
-- @return Parents weak table, keyed by child objects.
-- @see ~class.Define
function Build (base)
	-- Unique member keys --
	local _attach_list = {}

	-- List operations --
	local Ops = {}

	-- Parent list --
	local Parents = Weak("k")

	-- Attach op --
	function Ops:attach (object, on_attach, ...)
		assert(IsType(object, base), "Cannot attach object: wrong base type")
		assert(self ~= object, "Cannot attach object to self")

		-- If the object is being assigned a new parent, attach it.
		local is_new_parent = Parents[object] ~= self

		if is_new_parent then
			object:Detach()

			-- Lazily build a list if necessary.
			self[_attach_list] = self[_attach_list] or New("OrderedSet")

			-- Attach the object and link its parent.
			self[_attach_list]:PutInBack(object)

			Parents[object] = self
		end

		-- Apply attach logic.
		(on_attach or NoOp)(self, object, is_new_parent, ...)
	end

	do
		-- Chain iteration body
		local function Iter (O, object)
			if object then
				return Parents[object]
			end

			return O
		end

		-- Chain iteration op --
		function Ops:chain_iter ()
			return Iter, self
		end
	end

	-- Detach op --
	function Ops:detach (on_detach, ...)
		local parent = Parents[self]

		if parent then
			(on_detach or NoOp)(self, parent, ...)

			parent[_attach_list]:Remove(self)

			Parents[self] = nil
		end
	end

	-- Back element op --
	function Ops:get_back ()
		local attach_list = self[_attach_list]

		if attach_list then
			return attach_list:Back()
		end
	end

	-- Head element op --
	function Ops:get_head ()
		local attach_list = self[_attach_list]

		if attach_list then
			return attach_list:Front()
		end
	end

	-- Parent op --
	function Ops:get_parent ()
		return Parents[self]
	end

	-- Attach predicate op --
	function Ops:is_attached ()
		return Parents[self] ~= nil
	end

	-- List iteration op --
	function Ops:list_iter (reverse)
		local attach_list = self[_attach_list]

		if not attach_list then
			return NoOp
		elseif reverse then
			return attach_list:BackToFrontIter()
		else
			return attach_list:FrontToBackIter()
		end
	end

	-- Promote op --
	function Ops:promote ()
		local parent = Parents[self]

		if parent then 
			parent[_attach_list]:PutInFront(self)
		end
	end

	return Ops, _attach_list, Parents
end