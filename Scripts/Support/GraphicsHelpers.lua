-- Standard library imports --
local ipairs = ipairs
local pairs = pairs

-- Modules --
local class = require("class")
local gfx = require("gfx")
local var_preds = require("var_preds")

-- Imports --
local IsString = var_preds.IsString
local Load2DTexture = gfx.Load2DTexture
local LoadAnimTexture = gfx.LoadAnimTexture
local LoadVideoTexture = gfx.LoadVideoTexture
local LoadFont = gfx.LoadFont
local New = class.New

-- Cached routines --
local _Picture_
local _Texture_

-- Export graphics helpers namespace.
module "graphics_helpers"

--- Helper to load animated textures.
-- @param input Texture name / handle table.
-- @param mode Animation mode.
-- @param phase Animation phase.
-- @param ... Texture flags.
-- @returns Animated texture handle.
function AnimTexture (input, mode, phase, ...)
	for i, entry in ipairs(input) do
		input[i] = _Texture_(entry, ...)
	end

	return LoadAnimTexture(input, mode, phase)
end

--- Helper to load <a href="MultiPicture.html">multipictures</a>.
-- @param input Texture name / handle table.
-- @param mode Multipicture mode.
-- @param thresholds Threshold values.
-- @param props Optional external property set.
-- @param ... Texture flags.
-- @return MultiPicture handle.
function MultiPicture (input, mode, thresholds, props, ...)
	local multi = New("MultiPicture", mode, props)

	for k, v in pairs(thresholds) do
		multi:SetThreshold(k, v)
	end

	for i, entry in ipairs(input) do
		multi:SetPicture(i, _Picture_(entry, nil, ...))
	end

	return multi
end

--- Helper to build <a href="Picture.html">pictures</a>.
-- @param texture Texture name / handle.
-- @param props Optional external property set.
-- @param ... Texture flags.
-- @return Picture handle.
function Picture (texture, props, ...)
	return New("Picture", _Texture_(texture, ...), props)
end

--- Helper to load picture textures.
-- @param input Texture name / handle.
-- @param ... Texture flags.
-- @return Texture handle.
function Texture (input, ...)
	return IsString(input) and Load2DTexture(input, ...) or input
end

--- Helper to load video textures.
-- @param input Video filename.
-- @param w Width.
-- @param h Height.
-- @param loop
-- @return Texture handle ( a 2d texture that gets updated with the video info ).
function VideoTexture( input, w, h, loop, framerate )
	return IsString(input) and LoadVideoTexture( input, w , h, loop, framerate  ) or input
end

-- Cache some routines.
_Picture_ = Picture
_Texture_ = Texture