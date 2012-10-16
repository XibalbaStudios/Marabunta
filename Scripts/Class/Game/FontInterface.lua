-- See TacoShell Copyright Notice in main folder of distribution

--  Standard library imports --
local assert = assert
local ipairs = ipairs
local pairs = pairs

-- Modules --
local class = require("class")
local table_ops = require("table_ops")
local unicode = require("unicode")
local var_preds = require("var_preds")

local utf8 = unicode.utf8

-- Imports --
local Copy = table_ops.Copy
local IsNumber = var_preds.IsNumber
local IsString = var_preds.IsString
local IsTable = var_preds.IsTable
local Type = class.Type

-- Unique member keys --
local _anim_chars = {}
local _font = {}
local _key = {}
local _ops = {}
local _parse_delimiter = {}
local _parse_words = {}

-- Active fonts --
local Fonts = table_ops.Weak("k")

-- FontInterface class definition --
class.Define("FontInterface", function(FontInterface)
	-- String mapping cache --
	local Caches = table_ops.SubTablesOnDemand("k")

	-- Binds a character to the font
	-- char: Character to bind
	-- graphic: Character graphic
	-- texels: Texture rectangle
	-- screen: Screen rectangle
	-- advance: Pixels to advance
	---------------------------------
	function FontInterface:AddCharacter (char, graphic, texels, screen, advance)
		local font, texture = assert(self[_font], "Missing font object"), graphic

		-- If this is animated, store its state in the update list. Otherwise, make sure it is clear.
		if Type(graphic) == "AnimatedTexture" then
			self[_anim_chars][char], texture = { graphic = graphic, texels = texels and Copy(texels), screen = screen, advance = advance }, graphic:GetCurrentFrame()
		else
			self[_anim_chars][char] = nil
		end

		-- Add the character.
		font:AddCharacter(char, texture, texels, screen, advance)

		-- Invalidate the cache.
		Caches[self] = nil
	end

	-- Parse helper
	local function Parse (ops, str, parse_words, delimiter)
		return ops.gsub(str, ops.format("%s(.-)%s", delimiter, delimiter), parse_words)
	end

	-- Looks up a string, possibly parsing and mapping it
	-- Returns: Mapped string, mapping
	local function LookupString (F, str)
		assert(IsString(str), "Invalid string")

		local font = assert(F[_font], "Missing font object")
		local key = F[_key]
		local parse_words = F[_parse_words]

		if parse_words and key ~= nil then
			local cache = Caches[F]
			local mapping = cache[key] or {}

			if mapping.source ~= str then
				local mapped = Parse(F[_ops], str, parse_words, F[_parse_delimiter])

				mapping.source = str
				mapping.mapped = mapped
				mapping.w, mapping.h = font:GetSize(str)

				str = mapped
			end

			cache[key] = mapping

			return mapping.mapped, mapping
		end

		return str
	end

	-- str: String to draw
	-- x, y: String position
	-- props: Optional draw properties
	-----------------------------------
	function FontInterface:__call (str, x, y, props)
		self[_font]:PrintText(LookupString(self, str), x, y, props, self[_ops] == utf8)
	end

	function FontInterface:GetIndexAtOffset (str, offset)
		assert(IsString(str), "Invalid string")
		assert(IsNumber(offset), "Invalid position")

		local font = self[_font]

		if offset < 0 or not font then
			return 0 
		end

		return font:GetIndexAtOffset(str, offset)
	end

	-- Height helper
	local function GetHeight (F, str)
		local _, mapping = LookupString(F, str)

		if mapping then
			return mapping.h
		else
			local _, h = F[_font]:GetSize(str)

			return h
		end
	end

	-- Size helper
	local function GetSize (F, str)
		local _, mapping = LookupString(F, str)

		if mapping then
			return mapping.w, mapping.h
		else
			return F[_font]:GetSize(str)
		end	
	end

	-- Width helper
	local function GetWidth (F, str)
		local _, mapping = LookupString(F, str)

		if mapping then
			return mapping.w
		else
			return (F[_font]:GetSize(str))
		end
	end

	-- Dimensions --
	FontInterface.GetHeight = GetHeight
	FontInterface.GetSize = GetSize
	FontInterface.GetWidth = GetWidth

	-- Coordinate adjustment helper
	local function Align (dim, sdim, how)
		if how == "center" then
			return (dim - sdim) / 2
		elseif how then
			return dim - sdim
		else
			return 0
		end
	end

	-- Gets a string's alignment-based offsets
	-- str: String to align
	-- w, h: Extents of alignment box
	-- halign, valign: Alignment options
	-- Returns: Coordinate deltas
	-------------------------------------------
	function FontInterface:GetAlignmentOffsets (str, w, h, halign, valign)
		local sw, sh = GetSize(self, str)

		local dx = Align(w, sw, halign ~= "left" and halign)
		local dy = Align(h, sh, valign ~= "top" and valign)

		return dx, dy
	end

	--
	function FontInterface:GetOps ()
		return self[_ops]
	end

	-- font: Font to assign
	------------------------
	function FontInterface:SetFont (font)
		assert(font == nil or Type(font) == "Font", "Non-font object")

		-- Assign the font and dump any animated character tracking.
		self[_anim_chars] = {}
		self[_font] = font

		-- Invalidate the cache.
		Caches[self] = nil
	end

	-- key: Key to assign
	----------------------
	function FontInterface:SetLookupKey (key)
		self[_key] = key
	end

	-- 
	function FontInterface:SetOps (ops)
		assert(IsTable(ops), "Ops must be a table")

		self[_ops] = ops
	end

	-- delimiter: Delimiter to assign
	----------------------------------
	function FontInterface:SetParseDelimiter (delimiter)
		assert(delimiter == nil or IsString(delimiter), "Invalid delimiter")

		-- Install the delimiter, or a default.
		self[_parse_delimiter] = delimiter or "%$"

		-- Invalidate the cache.
		Caches[self] = nil
	end

	-- word_pairs: Word pairs to assign
	------------------------------------
	function FontInterface:SetParseWordPairs (word_pairs)
		assert(word_pairs == nil or IsTable(word_pairs), "Invalid word pair set")

		-- If requested, clear the word pairs.
		if word_pairs == nil then
			self[_parse_words] = nil

		-- Otherwise, vet and install the pairs.
		else
			for k, v in pairs(word_pairs) do
				assert(IsString(k), "Invalid word key")
				assert(IsString(v), "Invalid word value")
			end

			self[_parse_words] = Copy(word_pairs)		
		end

		-- Invalidate the cache.
		Caches[self] = nil
	end

	--- Class constructor.
	-- @param ops Font operations table.
	-- @param object Font object to set.
	-- @param word_pairs Parse word pairs.
	-- @param delimiter Parse delimiter.
	function FontInterface:__cons (ops, object, word_pairs, delimiter)
		self[_anim_chars] = {}

		self:SetOps(ops)
		self:SetFont(object)
		self:SetParseWordPairs(word_pairs)
		self:SetParseDelimiter(delimiter)

		Fonts[self] = true
	end
end)

-- Register an updater for animated custom font characters.
gfx.RegisterUpdateFunction(function()
	for font in pairs(Fonts) do
		local object = font[_font]

		for char, anim in pairs(font[_anim_chars]) do
			object:AddCharacter(char, anim.graphic:GetCurrentFrame(), anim.texels, anim.screen, anim.advance)
		end
	end
end)