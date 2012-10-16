-- Modules --
local class = require("class")
local coroutine_ex = require("coroutine_ex")
local coroutine_ops = require("coroutine_ops")
local game = require("game")
local graphics_helpers = require("graphics_helpers")
local math = require("math")
local numeric_ops = require("numeric_ops")
local section = require("section")
local ui = require("ui")
local user_state = require("user_state")

-- Imports --
--local EnterCaptureMode = EnterCaptureMode
--local LeaveCaptureMode = LeaveCaptureMode

-- Widgets --
local BugTextures

-- No unload flag --
local NoUnload

-- --
local Frames = { "Textures/GUI/ProgrammerArt/Bug1.png", "Textures/GUI/ProgrammerArt/Bug2.png" }

-- --
local WordIndex, WordX, WordY

-- --
local WordTimer = class.New("Timer")

-- --
local Color = class.New("Color")

-- --
local GlowPulse = .6

-- --
local Interp = class.New("Interpolator", ui.ContextColorInterp, GlowPulse, class.New("Color", 0, 0, 0, 0), "white", Color)

Interp:SetMap(function(t)
	t = 1 - t

	return 1 - t * t
end)

Color = "white"

--
local function GetRandomPos ()
	local w, h = user_state.GetSize()
	local x1, x2 = math.ceil(.125 * w), math.floor(.875 * w)
	local ymax = math.ceil(h / 3)

	return math.random(x1, x2), math.random(ymax)
end

-- Loading coroutine --
local Run = coroutine_ex.Wrap(function(data)
	while true do
		coroutine_ops.Wait(1)

		if false and #BugTextures < 10 then
			local texture = graphics_helpers.AnimTexture(Frames, "perm_rot", math.random(25, 75) / 100)
			local bug = ui.Image(graphics_helpers.Picture(texture))

			bug:SetRectPolicy("y", "reverse")

			data[1]:Attach(bug, GetRandomPos())

			BugTextures[#BugTextures + 1] = texture
		end
	end
end)

--
local function UpdateWord (data)
	local lookup = section.GetLookup(data)

	WordIndex = numeric_ops.RotateIndex(WordIndex + 1, #lookup)

	local x, y = GetRandomPos()

	data.message:SetX(x)
	data.message:SetY(y)
	data.message:SetString(lookup[WordIndex])
end

-- Install the loading screen.
section.Load("Loading", function(state, data, ...)
	-- Load --
	if state == "load" then
		data[1] = ui.Backdrop(false)

		data.icon = ui.Image("Textures/GUI/Loading1.png")
		data.overlay = ui.Image("Textures/GUI/Loading2.png")
		data.message = ui.String()

		data.icon:SetRectPolicy("x", "center")
		data.icon:SetRectPolicy("y", "center")
		data.icon:Attach(data.overlay, 0, 0)
		data.overlay:SetColor("main", Color)

		--
		local old_render = data.overlay:GetSlot("render")

		data.overlay:SetSlot("render", function(O, x, y, w, h, group, state)
			local frac_h = game.GetLoadProgress() * h / 100

			if state("enter")(x, y + h - frac_h, w, frac_h) then
				old_render(O, x, y, w, h, group, state)

				state("leave")()
			end
		end)

	-- About to load --
	elseif state == "about_to_load" then
--		NoUnload = game.WantsToRetry()

	-- Open / Update --
	elseif state == "open" or state == "update" then
		if state == "open" then
			section.SetupScreen(data)

			BugTextures = {}
			WordIndex = 0

--			data[1]:SetPicture("main", graphics_helpers.Picture("Textures/GUI/ProgrammerArt/Background.png"))
--			data[1]:Attach(data.message)
			data[1]:Attach(data.icon)

			Interp:Start("oscillate")
			WordTimer:Start(.3)

			UpdateWord(data)
		else
			local dt = ...

			for _, texture in ipairs(BugTextures) do
				texture:IncPhase(dt)
			end

			if WordTimer:Check("continue") > 0 then
--				UpdateWord(data)
			end

			Interp(dt)
			WordTimer:Update(dt)
		end

		-- Common update logic.
		Run(data)

	-- Close --
	elseif state == "close" then
		-- If the level has been loaded, ditch the character image and state.
		if not NoUnload then
			coroutine_ex.Reset(Run)

		-- Otherwise, cover up the background scene.
		else
--			EnterCaptureMode()
		end

		NoUnload = false
	end
end, {
	english = { "Yeah!", "Yeah!!", "Yeah!!!", "Party time!", "Woo!", "Hoo!" },
	spanish = { "Yeah!", "Yeah!!", "Yeah!!!", "Fiesta!", "Woo!", "Hoo!" }
}--[[, "Loading_lua"]])