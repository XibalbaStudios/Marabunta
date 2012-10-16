-- Install the intro screen.
section.Load("Intro", function(state, data, ...)
	-- Load --
	if state == "load" then
		data[1] = ui.Backdrop(false)

	-- Open --
	elseif state == "open" then
		local lookup = section.SetupScreen(data)
		
		section.GetEventQueue("leave_update"):Add(coroutine.wrap(function()
			local x = 25

			for _, item in ipairs(lookup) do
				local str = ui.String(item .. " ")

				str:SetRectPolicy("y", "center")

				data[1]:Attach(str, x)

				x = x + str:GetW()

				coroutine_ops.Wait(.2)
			end

			coroutine_ops.Wait(.15)

			section.Screen("Play")
		end))
	end
end, {
	english = {
		"Welcome", "To", "The", "Prototype"
	}, spanish = {
		"Bienvenido", "Al", "Prototipo"
	}
})