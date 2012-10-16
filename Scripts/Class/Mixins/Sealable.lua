-- See TacoShell Copyright Notice in main folder of distribution

--[[
--- A sealable object is able to restrict permission to its properties and services, either
-- in the form of a blacklist or whitelist.<br><br>
-- Class.
module Sealable
]]

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local rawequal = rawequal

-- Modules --
local table_ops = require("table_ops")
local var_ops = require("var_ops")
local var_preds = require("var_preds")

-- Imports --
local CollectArgsInto = var_ops.CollectArgsInto
local GetKeys = table_ops.GetKeys
local IsNaN = var_preds.IsNaN
local Weak = table_ops.Weak

-- Unique member keys --
local _forbids = {}
local _is_blacklist = {}
local _key = {}
local _permissions = {}

-- Sealable class definition --
class.Define("Sealable", function(Sealable)
	-- Returns: List, if available
	local function GetPermissionsList (S, id)
		assert(id ~= nil, "id == nil")

		local permissions = S[_permissions]

		return permissions and permissions[id]
	end

	-- Indicates whether a client has a given permission
	-- id: Lookup ID
	-- what: Permission to query
	-- Returns: If true, client has permission
	-----------------------------------------------------
	function Sealable:HasPermission (id, what)
		assert(what ~= nil, "what == nil")

		local permissions = assert(GetPermissionsList(self, id), "Invalid client ID")

		-- If no changes have yet been made, the client has full permissions. Otherwise,
		-- search for the query among the permissions. In blacklist mode, permission is
		-- granted if the query fails; in whitelist mode, the query must succeed.
		return permissions == "" or permissions[_is_blacklist] == not permissions[what]
	end

	---
	-- @param key Candidate key to test.
	-- @return If true, <i>key</i> matches the object's access key.
	function Sealable:MatchesKey (key)
		return rawequal(self[_key], key)
	end

	-- Cache methods for internal use.
	local HasPermission = Sealable.HasPermission
	local MatchesKey = Sealable.MatchesKey

	-- Adds a new client with configurable permissions
	-- key: Access key, for validation
	-- Returns: Lookup ID
	---------------------------------------------------
	function Sealable:AddClient (key)
		assert(MatchesKey(self, key), "Key mismatch")

		-- Install a client list if this is the first one. Generate a unique ID.
		local permissions = self[_permissions] or Weak("k")
		local id = {}

		-- Load the client. Give it full permissions by default.
		self[_permissions] = permissions

		permissions[id] = ""

		return id
	end

	-- Valid permission options --
	local Options = table_ops.MakeSet{ "blacklist", "whitelist", "+", "-" }

	-- Changes a client's permissions
	-- key: Access key, for validation
	-- id: Lookup ID
	-- how: Type of change to apply
	-- ...: Changes to apply
	-----------------------------------
	function Sealable:ChangePermissions (key, id, how, ...)
		assert(MatchesKey(self, key), "Key mismatch")
		assert(how ~= nil and Options[how], "Invalid permission option")

		-- Validate the changes.
		local count, changes = CollectArgsInto(nil, ...)

		for i = 1, count do
			assert(changes[i] ~= nil, "Nil change")
			assert(changes[i] == changes[i], "NaN change")
		end

		-- If a new whitelist or blacklist is requested, build it. New clients have full
		-- permissions, and thus implicitly have empty blacklists; if additions or removals
		-- are to be made, make this explicit.
		local permissions = assert(GetPermissionsList(self, id), "Invalid client ID")

		if permissions == "" or how == "blacklist" or how == "whitelist" then
			permissions = { [_is_blacklist] = how ~= "whitelist" }

			-- Replace the old list.
			self[_permissions][id] = permissions
		end

		-- For additions / removals, the following holds:
		-- > Add: Add to whitelist or remove from blacklist
		-- > Remove: Add to blacklist or remove from whitelist
		local should_add = true

		if how == "+" or how == "-" then
			should_add = (how == "+" ~= permissions[_is_blacklist]) or nil
		end

		-- Apply the changes. A removal will clear an entry.
		for _, change in ipairs(changes) do
			permissions[change] = should_add
		end
	end

	--- Reports client permissions.
	-- @param id Client lookup id.
	-- @return If true, permissions are in blacklist form.
	-- @return List of blacklisted or whitelisted property names.
	function Sealable:GetPermissions (id)
		local permissions = assert(GetPermissionsList(self, id), "Invalid client ID")

		if permissions ~= "" then
			return permissions[_is_blacklist], GetKeys(permissions)
		end

		return true, {}
	end

	---
	-- @param what Non-<b>nil</b> name of property to test.
	-- @return If true, the property is not sealed, i.e. changes and such are allowed.
	function Sealable:IsAllowed (what)
		assert(what ~= nil, "what == nil")

		local forbids = self[_forbids]

		return (forbids and forbids[what]) == nil
	end

	---
	-- @param id Candidate lookup ID.
	-- @return If true, <i>id</i> belongs to one of this object's clients.
	function Sealable:IsClient (id)
		return id ~= nil and GetPermissionsList(self, id) ~= nil
	end

	-- Sets allowance for future changes to a property
	-- @param what Non-<b>nil</b> / NaN name of property to unseal. Clients must have this
	-- permission.
	-- @param id_or_key Client lookup ID or access key, for validation.
	-- @see Sealable:AddClient
	-- @see Sealable:HasPermission
	-- @see Sealable:SetKey
	-- @see Sealable:Unseal
	function Sealable:Seal (what, id_or_key)
		assert(not IsNaN(what), "what is NaN")
		assert(MatchesKey(self, id_or_key) or HasPermission(self, id_or_key, what), "Key mismatch or forbidden client")

		self[_forbids] = self[_forbids] or {}

		self[_forbids][what] = true
	end

	--- Sets this object's access key.
	-- @param new Access key to assign. Since they can be guessed, booleans, numbers, and
	-- strings ought to be avoided.
	-- @param old Current key, for validation. New objects have <b>nil</b> as the key.
	-- @return If true, the new key was set.
	function Sealable:SetKey (new, old)
		assert(MatchesKey(self, old), "Key mismatch")

		self[_key] = new
	end

	---
	-- @param what Non-<b>nil</b> / NaN name of property to unseal. Clients must have this
	-- permission.
	-- @param id_or_key Client lookup ID or access key, for validation.
	-- @see Sealable:AddClient
	-- @see Sealable:HasPermission
	-- @see Sealable:Seal
	-- @see Sealable:SetKey
	function Sealable:Unseal (what, id_or_key)
		assert(not IsNaN(what), "what is NaN")
		assert(MatchesKey(self, id_or_key) or HasPermission(self, id_or_key, what), "Key mismatch or forbidden client")

		if self[_forbids] then
			self[_forbids][what] = nil
		end
	end
end)