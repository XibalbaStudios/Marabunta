-- See TacoShell Copyright Notice in main folder of distribution

return function(prefix, env, _, ext, loader)
	return {
		"Interval",
		"Spot",
		"Sequence"
	}, prefix, env, {}, ext, loader
end, ...