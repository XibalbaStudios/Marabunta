-- See TacoShell Copyright Notice in main folder of distribution

--[[
---
-- Class. Derives from <b><a href="Widget.html">Widget</a></b>.
module MultiPanel
]]

-- Standard library imports --
local ipairs = ipairs

-- Imports --
local New = class.New
local PurgeAttachList = widget_ops.PurgeAttachList
local RotateIndex = numeric_ops.RotateIndex
local SuperCons = class.SuperCons
local StateSwitch = widget_ops.StateSwitch

-- Unique member keys --
local _index = {}
local _margin = {}
local _pages = {}
local _timer = {}
local _to_left = {}

-- M: Multipane handle
-- index: Index to assign
local function SetIndex (M, index)
	M[_index] = index
end

-- Multipane update signal
-- M: Multipane handle
-- dt: Time lapse
local function Update (M, dt, group)
	if M:IsFlipping() then
		local _, _, w, h = M:GetAbsoluteRect()

		-- On timeout, complete the flip.
		if M[_timer]:Check() > 0 then
			local pages = M[_pages]
			local index = M[_index]
			local next = RotateIndex(index, #pages, M[_to_left])

			-- Detach the transition page. Set the new page and view at the origin.
			local cur = pages[index]
			local new = pages[next]

			group:AddDeferredTask(function()
				cur:Detach()

				M:Attach(new, 0, 0, w, h)
				M:SetViewOrigin(0)
			end)

			-- Switch the page.
			StateSwitch(M, true, false, SetIndex, "flip", next)

		-- Otherwise, slide the view toward the new page.
		else
			local when = M[_timer]:GetCounter(true)

			M:SetViewOrigin((w + M[_margin]) * (M[_to_left] and 1 - when or when))

			M[_timer]:Update(dt)
		end
	end
end

-- MultiPanel class definition --
class.Define("MultiPanel", function(MultiPanel)
	-- Adds a page to the multipane
	-- setup: Page setup routine
	--------------------------------
	function MultiPanel:AddPage (setup)
		local pages = self[_pages]
		local new_page = New("Panel")
		local _, _, w, h = self:GetAbsoluteRect()

		-- Configure and load the page.
		new_page:SetPicture("main", self:GetPicture("page"))

		setup(new_page, w, h)

		pages[#pages + 1] = new_page

		-- If this is the first entry, put the page in view.
		if #pages == 1 then
			self:Attach(new_page, 0, 0, w, h)
			self:SetViewOrigin(0)

			-- Invoke a switch.
			self:Signal("switch_to", "first")
		end
	end

	-- Clears the multipane
	------------------------
	function MultiPanel:Clear ()
		for _, page in ipairs(self[_pages]) do
			PurgeAttachList(page)

			page:Detach()
		end

		self[_pages] = {}
		self[_index] = 1

		self[_timer]:Stop()
	end

	-- Initiates a flip
	-- duration: Flip duration
	-- to_left: If true, flip left
	-------------------------------
	function MultiPanel:Flip (duration, to_left)
		local pages = self[_pages]

		if not self:IsFlipping() and #pages > 1 then
			self[_to_left] = to_left

			self[_timer]:Start(duration)

			-- Put the transition and new page side by side, with some margin. Place the
			-- view on the transition page.
			local index = self[_index]
			local next = RotateIndex(index, #pages, to_left)
			local _, _, w, h = self:GetAbsoluteRect()
			local x2 = w + self[_margin]
			local curx = to_left and x2 or 0

			self:Attach(pages[index], curx, 0, w, h)
			self:Attach(pages[next], to_left and 0 or x2, 0, w, h)
			self:SetViewOrigin(curx)
		end
	end

	-- Returns: Current page
	-------------------------
	function MultiPanel:GetPage ()
		return self[_index]
	end

	-- Returns: If true, multipane is flipping
	-------------------------------------------
	function MultiPanel:IsFlipping ()
		return self[_timer]:GetDuration() ~= nil
	end

	-- Returns: Page count
	-----------------------
	function MultiPanel:__len ()
		return #self[_pages]
	end

	-- margin: Inter-page margin to assign
	---------------------------------------
	function MultiPanel:SetMargin (margin)
		self[_margin] = margin
	end

	--- Class constructor.
	function MultiPanel:__cons ()
		SuperCons(self, "Widget")

		-- Currently referenced page --
		self[_index] = 1

		-- Margin between pages --
		self[_margin] = 0

		-- Page list --
		self[_pages] = {}

		-- Page switch timer --
		self[_timer] = New("Timer")

		-- Signals --
		self:SetSlot("update", Update)
	end
end, { base = "Widget" })